#!/usr/bin/env python3
"""Weekly Work Report Generator.

Collects git activity, Jira issues, and Confluence pages from the past N days,
generates an Obsidian markdown note and a static HTML page with copy-to-clipboard
buttons and paste-back textareas for Copilot summaries.

Usage:
    generate_work_report.py [--config PATH] [--days N] [--no-roadmap] [--no-jira] [--no-confluence] [--serve] [--open]
"""

import argparse
import html
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import webbrowser
from datetime import datetime, timedelta, timezone
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urljoin

try:
    import yaml
except ImportError:
    sys.exit("ERROR: PyYAML is required. Install with: pip install pyyaml")

try:
    import requests
    from urllib3.exceptions import InsecureRequestWarning
    requests.packages.urllib3.disable_warnings(InsecureRequestWarning)
except ImportError:
    requests = None  # Jira/Confluence will be skipped gracefully


# ═══════════════════════════════════════════════════════════════════════════════
# Config
# ═══════════════════════════════════════════════════════════════════════════════

DEFAULT_CONFIG_PATH = Path.home() / ".config" / "work-report" / "config.yaml"
DEFAULT_OUTPUT_DIR = Path("/tmp/work-report")
COPILOT_PROMPT = (
    "Do not embellish on what's changed in the last week in this repository. "
    "This should be 3 parts, executive summary, details and a bulleted list of changes (why and how are great, but DO NOT make assumptions or add info not in the log/diff)."
    "Most of this will be used in my Obsidian notes, but the executive summary should be suitable for sharing externally to my manager and their manager (they're both technical)."
)


def expand_env_vars(value):
    """Expand ${ENV_VAR} references in string values."""
    if not isinstance(value, str):
        return value
    return re.sub(r'\$\{([^}]+)\}', lambda m: os.environ.get(m.group(1), m.group(0)), value)


def expand_config(obj):
    """Recursively expand env vars in config values."""
    if isinstance(obj, dict):
        return {k: expand_config(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [expand_config(item) for item in obj]
    elif isinstance(obj, str):
        return expand_env_vars(obj)
    return obj


def load_config(config_path: Path) -> dict:
    """Load and validate config YAML."""
    if not config_path.exists():
        sys.exit(f"ERROR: Config not found: {config_path}\n"
                 f"Create it with default values or run with --config PATH")

    with open(config_path, 'r') as f:
        raw = yaml.safe_load(f)

    if not raw:
        sys.exit(f"ERROR: Config file is empty: {config_path}")

    config = expand_config(raw)

    # Defaults
    config.setdefault('days', 7)
    config.setdefault('repos', [])
    config.setdefault('output_dir', str(DEFAULT_OUTPUT_DIR))
    config.setdefault('obsidian_vault', '')
    config.setdefault('obsidian_folder', 'Weekly Reports')
    config.setdefault('atlassian', {})
    config['atlassian'].setdefault('ssl_verify', True)
    config.setdefault('jira', {})
    config['jira'].setdefault('show_comments_column', True)
    config.setdefault('confluence', {'enabled': False})
    config.setdefault('roadmap', None)
    config.setdefault('gitlab', {})
    config['gitlab'].setdefault('ssl_verify', True)

    return config


# ═══════════════════════════════════════════════════════════════════════════════
# Phase 1: GitLab MR Data Collection
# ═══════════════════════════════════════════════════════════════════════════════

def normalize_repo_entry(entry) -> dict:
    """Normalize a repo config entry to dict format.

    Supports:
      - "/path/to/repo" (string)
      - {path: "/path/to/repo", roadmap: {json_path: ..., output_path: ...}} (dict)
    """
    if isinstance(entry, str):
        return {'path': entry}
    if isinstance(entry, dict):
        return entry
    return {}


def _parse_gitlab_project_path(git_url: str) -> str:
    """Extract namespace/project path from a GitLab git URL.

    Handles:
      - git@host:namespace/project.git  (SSH)
      - https://host/namespace/project.git  (HTTPS)
    """
    if not git_url:
        return ''
    ssh_match = re.match(r'^[^@]+@[^:]+:(.+?)(?:\.git)?$', git_url)
    if ssh_match:
        return ssh_match.group(1)
    https_match = re.match(r'^https?://[^/]+/(.+?)(?:\.git)?$', git_url)
    if https_match:
        return https_match.group(1)
    return ''


def _parse_gitlab_timestamp(raw_timestamp: str):
    """Parse GitLab timestamp strings into timezone-aware UTC datetimes."""
    if not isinstance(raw_timestamp, str) or not raw_timestamp:
        return None

    try:
        parsed = datetime.fromisoformat(raw_timestamp.replace('Z', '+00:00'))
    except ValueError:
        return None

    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)

    return parsed.astimezone(timezone.utc)


def collect_repo_configs(repos: list) -> list:
    """Collect repo metadata (roadmap, epics, gitlab_path) without running git."""
    results = []
    for entry in repos:
        repo_entry = normalize_repo_entry(entry)
        repo_path_str = repo_entry.get('path', '')
        if not repo_path_str:
            continue
        repo_path = Path(repo_path_str).expanduser()
        repo_name = repo_path.name
        gitlab_url = repo_entry.get('git', '')
        gitlab_path = _parse_gitlab_project_path(gitlab_url)
        results.append({
            'name': repo_name,
            'path': str(repo_path),
            'gitlab_path': gitlab_path,
            'roadmap': repo_entry.get('roadmap'),
            'epics': repo_entry.get('epics', []),
            '_epics_detail': [],
        })
    return results


def _fetch_mr_notes(base_url: str, headers: dict, ssl_verify: bool, project_id: int, mr_iid: int) -> list:
    """Fetch user-visible comments/notes for a merge request (excludes system notes)."""
    url = urljoin(base_url.rstrip('/') + '/', f'api/v4/projects/{project_id}/merge_requests/{mr_iid}/notes')
    params = {'per_page': 100, 'sort': 'asc'}
    notes = []

    while url:
        try:
            resp = requests.get(url, headers=headers, params=params, timeout=30, verify=ssl_verify)
            resp.raise_for_status()
        except Exception as e:
            print(f"  WARNING: Could not fetch MR notes for !{mr_iid}: {e}", file=sys.stderr)
            break

        page_notes = resp.json()
        if isinstance(page_notes, list):
            notes.extend([n for n in page_notes if not n.get('system', False)])

        next_url = resp.links.get('next', {}).get('url', '')
        url = next_url if next_url else None
        params = {}

    return notes


def _fetch_commit_diff(base_url: str, headers: dict, ssl_verify: bool, project_id: int, sha: str) -> list:
    """Fetch the per-file diffs for a single commit. Returns a list of diff dicts."""
    url = urljoin(base_url.rstrip('/') + '/', f'api/v4/projects/{project_id}/repository/commits/{sha}/diff')
    params = {'per_page': 100}
    all_diffs = []

    while url:
        try:
            resp = requests.get(url, headers=headers, params=params, timeout=60, verify=ssl_verify)
            resp.raise_for_status()
        except Exception as e:
            print(f"  WARNING: Could not fetch commit diff for {sha[:8]}: {e}", file=sys.stderr)
            break

        page_diffs = resp.json()
        if isinstance(page_diffs, list):
            all_diffs.extend(page_diffs)

        next_url = resp.links.get('next', {}).get('url', '')
        url = next_url if next_url else None
        params = {}

    return all_diffs


def _fetch_mr_commit_changes(
    base_url: str, headers: dict, ssl_verify: bool, project_id: int, mr_iid: int, cutoff
) -> tuple:
    """Fetch per-commit changes and diffs for a merge request.

    Only commits authored/committed on or after ``cutoff`` are included, so that
    diffs reflect just the work done in the requested window rather than the
    entire branch history.

    Returns (changes_summary: list, diff_content: str, commits: list).
    """
    # 1. Fetch all commits on the MR (paginated).
    url = urljoin(base_url.rstrip('/') + '/', f'api/v4/projects/{project_id}/merge_requests/{mr_iid}/commits')
    params = {'per_page': 100}
    all_commits = []

    while url:
        try:
            resp = requests.get(url, headers=headers, params=params, timeout=30, verify=ssl_verify)
            resp.raise_for_status()
        except Exception as e:
            print(f"  WARNING: Could not fetch MR commits for !{mr_iid}: {e}", file=sys.stderr)
            break

        page_commits = resp.json()
        if isinstance(page_commits, list):
            all_commits.extend(page_commits)

        next_url = resp.links.get('next', {}).get('url', '')
        url = next_url if next_url else None
        params = {}

    # 2. Keep only commits within the --days window.
    recent_commits = []
    for commit in all_commits:
        ts = _parse_gitlab_timestamp(
            commit.get('committed_date') or commit.get('created_at') or commit.get('authored_date')
        )
        if cutoff is not None and (ts is None or ts < cutoff):
            continue
        recent_commits.append((commit, ts))

    # Oldest first so the assembled diff reads chronologically (like git log).
    recent_commits.sort(key=lambda item: item[1] or datetime.min.replace(tzinfo=timezone.utc))

    # 3. Fetch the diff for each retained commit and aggregate file stats.
    file_totals = {}  # path -> changes_summary entry (aggregated across commits)
    diff_parts = []
    commits_detail = []

    for commit, ts in recent_commits:
        sha = commit.get('id', '')
        if not sha:
            continue
        message = (commit.get('message') or commit.get('title') or '').strip()
        author = commit.get('author_name', '')
        date = (commit.get('committed_date') or commit.get('created_at') or '')[:10]

        commit_diffs = _fetch_commit_diff(base_url, headers, ssl_verify, project_id, sha)

        commit_file_count = 0
        commit_diff_text_parts = []
        for diff in commit_diffs:
            old_path = diff.get('old_path', '')
            new_path = diff.get('new_path', '')
            diff_text = diff.get('diff', '')

            added = sum(1 for line in diff_text.splitlines() if line.startswith('+') and not line.startswith('+++'))
            removed = sum(1 for line in diff_text.splitlines() if line.startswith('-') and not line.startswith('---'))

            path_key = new_path or old_path
            entry = file_totals.get(path_key)
            if entry is None:
                entry = {
                    'old_path': old_path,
                    'new_path': new_path,
                    'added_lines': 0,
                    'removed_lines': 0,
                    'new_file': False,
                    'deleted_file': False,
                    'renamed_file': False,
                }
                file_totals[path_key] = entry
            entry['added_lines'] += added
            entry['removed_lines'] += removed
            entry['new_file'] = entry['new_file'] or diff.get('new_file', False)
            entry['deleted_file'] = entry['deleted_file'] or diff.get('deleted_file', False)
            entry['renamed_file'] = entry['renamed_file'] or diff.get('renamed_file', False)
            commit_file_count += 1

            if diff_text:
                commit_diff_text_parts.append(f"diff --git a/{old_path} b/{new_path}\n{diff_text}")

        indented_message = '\n'.join('    ' + line for line in message.splitlines()) if message else ''
        commit_section = (
            f"commit {sha}\n"
            f"Author: {author}\n"
            f"Date:   {date}\n\n"
            f"{indented_message}\n\n"
            + '\n'.join(commit_diff_text_parts)
        )
        diff_parts.append(commit_section)

        commits_detail.append({
            'sha': sha,
            'short_id': commit.get('short_id', sha[:8]),
            'message': message,
            'title': commit.get('title', ''),
            'author': author,
            'date': date,
            'file_count': commit_file_count,
        })

    changes_summary = list(file_totals.values())
    diff_content = '\n\n'.join(diff_parts)
    return changes_summary, diff_content, commits_detail


def query_gitlab_mrs(config: dict, days: int, output_dir: Path) -> list:
    """Query GitLab for merge requests with activity in the last N days."""
    if requests is None:
        print("  WARNING: 'requests' not installed, skipping GitLab", file=sys.stderr)
        return []

    gitlab_config = config.get('gitlab', {})
    base_url = gitlab_config.get('base_url', '')
    token = (
        gitlab_config.get('token', '')
        or os.environ.get('GITLAB_TOKEN', '')
        or os.environ.get('GITLAB_PRIVATE_TOKEN', '')
    )
    ssl_verify = gitlab_config.get('ssl_verify', True)

    if not base_url or not token:
        print("  WARNING: GitLab config incomplete (need gitlab.base_url and gitlab.token)", file=sys.stderr)
        return []

    headers = {
        'PRIVATE-TOKEN': token,
        'Content-Type': 'application/json',
    }

    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    updated_after = cutoff.strftime('%Y-%m-%dT%H:%M:%SZ')
    project_paths_filter = [p.strip() for p in gitlab_config.get('projects', []) if p.strip()]

    mrs_by_key = {}  # (project_id, iid) -> mr dict
    stale_skipped = 0

    for scope in ('created_by_me', 'assigned_to_me'):
        url = urljoin(base_url.rstrip('/') + '/', 'api/v4/merge_requests')
        params = {
            'scope': scope,
            'state': 'all',
            'updated_after': updated_after,
            'per_page': 100,
            'order_by': 'updated_at',
            'sort': 'desc',
        }

        page_count = 0
        next_page = 1
        while page_count < 10 and next_page:
            try:
                request_params = dict(params)
                request_params['page'] = next_page
                resp = requests.get(url, headers=headers, params=request_params, timeout=30, verify=ssl_verify)
                resp.raise_for_status()
            except Exception as e:
                print(f"  WARNING: GitLab MR query failed (scope={scope}): {e}", file=sys.stderr)
                break

            page_mrs = resp.json()
            if not isinstance(page_mrs, list):
                break

            for mr in page_mrs:
                project_id = mr.get('project_id')
                iid = mr.get('iid')
                web_url = mr.get('web_url', '')
                updated_at_raw = mr.get('updated_at', '')
                updated_at_dt = _parse_gitlab_timestamp(updated_at_raw)

                # Enforce --days window locally in case API pagination/scope returns extra rows.
                if updated_at_dt is None or updated_at_dt < cutoff:
                    stale_skipped += 1
                    continue

                # Extract project path from web_url
                project_path = ''
                if web_url and base_url:
                    path_match = re.match(
                        rf'^{re.escape(base_url.rstrip("/"))}/(.+?)/-/merge_requests/\d+$',
                        web_url
                    )
                    if path_match:
                        project_path = path_match.group(1)

                # Filter to configured projects if specified
                if project_paths_filter and project_path and not any(
                    project_path == p or project_path.endswith('/' + p) or p == project_path.split('/')[-1]
                    for p in project_paths_filter
                ):
                    continue

                key = (project_id, iid)
                if key in mrs_by_key:
                    if mrs_by_key[key]['scope'] != scope:
                        mrs_by_key[key]['scope'] = 'both'
                else:
                    mrs_by_key[key] = {
                        'id': mr.get('id'),
                        'iid': iid,
                        'project_id': project_id,
                        'project_path': project_path,
                        'project_name': project_path.split('/')[-1] if project_path else '',
                        'title': mr.get('title', ''),
                        'description': mr.get('description', '') or '',
                        'state': mr.get('state', ''),
                        'merged': mr.get('state') == 'merged',
                        'merged_at': (mr.get('merged_at', '') or '')[:10],
                        'created_at': (mr.get('created_at', '') or '')[:10],
                        'updated_at': updated_at_dt.date().isoformat(),
                        'source_branch': mr.get('source_branch', ''),
                        'target_branch': mr.get('target_branch', ''),
                        'web_url': web_url,
                        'author_username': mr.get('author', {}).get('username', ''),
                        'scope': scope,
                        'notes': [],
                        'commits': [],
                        'changes_summary': [],
                        'diff_content': '',
                        'diff_file': '',
                    }

            next_page_raw = str(resp.headers.get('X-Next-Page', '')).strip()
            if next_page_raw.isdigit():
                next_page = int(next_page_raw)
            else:
                next_page = 0
            page_count += 1

    mr_list = sorted(mrs_by_key.values(), key=lambda m: m.get('updated_at', ''), reverse=True)
    if stale_skipped:
        print(f"  Skipped {stale_skipped} MRs older than the last {days} day(s)")
    print(f"  Found {len(mr_list)} unique MRs, fetching details...")

    mrs_with_changes = []
    empty_skipped = 0

    for mr in mr_list:
        project_id = mr['project_id']
        iid = mr['iid']
        print(
            f"    !{iid} [{mr['state']}] updated {mr.get('updated_at', '')} "
            f"({mr['project_path']}): {mr['title'][:60]}"
        )

        mr['notes'] = _fetch_mr_notes(base_url, headers, ssl_verify, project_id, iid)
        mr['changes_summary'], mr['diff_content'], mr['commits'] = _fetch_mr_commit_changes(
            base_url, headers, ssl_verify, project_id, iid, cutoff
        )

        # Ignore MRs with no actual diff in the last --days window.
        if not mr['diff_content'].strip():
            print(f"      (skipped: no diff in the last {days} day(s))")
            empty_skipped += 1
            continue

        diff_file = output_dir / f"mr_{project_id}_{iid}_diff.patch"
        diff_header = f"MR !{iid}: {mr['title']}\n"
        if mr.get('description', '').strip():
            diff_header += f"\n{mr['description'].strip()}\n"
        diff_header += "\n---\n\n"
        diff_file.write_text(diff_header + mr['diff_content'])
        mr['diff_file'] = str(diff_file)
        mrs_with_changes.append(mr)

    if empty_skipped:
        print(f"  Skipped {empty_skipped} MRs with no diff in the last {days} day(s)")

    return mrs_with_changes



# ═══════════════════════════════════════════════════════════════════════════════
# Phase 2: Jira Query
# ═══════════════════════════════════════════════════════════════════════════════

def fetch_epics(epic_keys: list, config: dict) -> list:
    """Fetch epic details from Jira for the given keys.

    Returns list of {key, summary, status, children_in_progress[]} dicts.
    """
    if not epic_keys or requests is None:
        return []

    atlassian = config.get('atlassian', {})
    base_url = atlassian.get('base_url', '')
    pat = atlassian.get('pat', '')
    ssl_verify = atlassian.get('ssl_verify', True)

    if not all([base_url, pat]):
        return []

    headers = {
        'Authorization': f'Bearer {pat}',
        'Content-Type': 'application/json',
    }

    api_url = urljoin(base_url.rstrip('/') + '/', 'rest/api/2/search')
    key_list = ', '.join(f'"{k}"' for k in epic_keys)
    jql = f'key in ({key_list})'
    params = {
        'jql': jql,
        'fields': 'key,summary,status,components',
        'maxResults': len(epic_keys),
    }

    try:
        resp = requests.get(api_url, headers=headers, params=params, timeout=30, verify=ssl_verify)
        resp.raise_for_status()
    except Exception as e:
        print(f"  WARNING: Epic fetch failed: {e}", file=sys.stderr)
        return []

    data = resp.json()
    epics = []

    for issue_data in data.get('issues', []):
        fields = issue_data.get('fields', {})
        epics.append({
            'key': issue_data.get('key', ''),
            'summary': fields.get('summary', ''),
            'status': fields.get('status', {}).get('name', ''),
        })

    return epics


def _extract_user_identities(user_data: dict) -> set:
    """Extract comparable user identity values from Jira user objects."""
    identities = set()
    for field in ('name', 'key', 'accountId', 'emailAddress', 'displayName'):
        value = user_data.get(field, '') if isinstance(user_data, dict) else ''
        if isinstance(value, str) and value.strip():
            identities.add(value.strip().lower())
    return identities


def _resolve_current_user_identities(base_url: str, headers: dict, ssl_verify: bool, configured_username: str) -> set:
    """Resolve current Jira user identities for reliable comment author matching."""
    identities = set()
    if configured_username:
        identities.add(configured_username.strip().lower())

    myself_url = urljoin(base_url.rstrip('/') + '/', 'rest/api/2/myself')
    try:
        resp = requests.get(myself_url, headers=headers, timeout=30, verify=ssl_verify)
        if resp.ok:
            identities.update(_extract_user_identities(resp.json()))
    except Exception as e:
        print(f"  WARNING: Could not resolve Jira current user identity: {e}", file=sys.stderr)

    return identities


def _parse_jira_timestamp(raw_timestamp: str):
    """Parse Jira timestamp values into datetime objects."""
    if not isinstance(raw_timestamp, str) or not raw_timestamp:
        return None

    formats = (
        '%Y-%m-%dT%H:%M:%S.%f%z',
        '%Y-%m-%dT%H:%M:%S%z',
        '%Y-%m-%dT%H:%M:%S.%f',
        '%Y-%m-%dT%H:%M:%S',
    )
    for fmt in formats:
        try:
            return datetime.strptime(raw_timestamp, fmt)
        except ValueError:
            continue

    try:
        return datetime.fromisoformat(raw_timestamp.replace('Z', '+00:00'))
    except ValueError:
        return None


def _extract_comment_body(comment_body) -> str:
    """Extract plain text from Jira comment body (string or Atlassian doc format)."""
    if isinstance(comment_body, str):
        return comment_body.strip()

    parts = []

    def walk(node):
        if isinstance(node, dict):
            text = node.get('text')
            if isinstance(text, str):
                parts.append(text)
            for child in node.get('content', []):
                walk(child)
            if node.get('type') in ('paragraph', 'hardBreak'):
                parts.append('\n')
        elif isinstance(node, list):
            for item in node:
                walk(item)

    walk(comment_body)
    return ''.join(parts).strip()


def _fetch_issue_comments(base_url: str, headers: dict, ssl_verify: bool, issue_key: str, comment_data: dict) -> list:
    """Fetch all comments for an issue if the search payload is truncated."""
    comments = comment_data.get('comments', []) if isinstance(comment_data, dict) else []
    total = comment_data.get('total', len(comments)) if isinstance(comment_data, dict) else len(comments)

    if not isinstance(comments, list):
        comments = []
    if not isinstance(total, int) or total <= len(comments):
        return comments

    issue_comments_url = urljoin(base_url.rstrip('/') + '/', f'rest/api/2/issue/{issue_key}/comment')
    fetched = []
    start_at = 0
    max_results = 100

    while start_at < total:
        params = {
            'startAt': start_at,
            'maxResults': max_results,
        }
        try:
            resp = requests.get(issue_comments_url, headers=headers, params=params, timeout=30, verify=ssl_verify)
            resp.raise_for_status()
        except Exception as e:
            print(f"  WARNING: Could not fetch full comments for {issue_key}: {e}", file=sys.stderr)
            return comments

        page = resp.json()
        page_comments = page.get('comments', [])
        if not isinstance(page_comments, list) or not page_comments:
            break

        fetched.extend(page_comments)

        prev_start = start_at
        start_at = page.get('startAt', start_at) + page.get('maxResults', len(page_comments))
        if start_at <= prev_start:
            break

    return fetched if fetched else comments


def _resolve_jira_epic_field_ids(base_url: str, headers: dict, ssl_verify: bool) -> dict:
    """Resolve Jira field IDs used for linking issues to epics."""
    ids = {
        'epic_link': '',
        'parent_link': '',
    }
    fields_url = urljoin(base_url.rstrip('/') + '/', 'rest/api/2/field')
    try:
        resp = requests.get(fields_url, headers=headers, timeout=30, verify=ssl_verify)
        resp.raise_for_status()
        fields = resp.json()
    except Exception as e:
        print(f"  WARNING: Could not resolve Jira field IDs for epic linking: {e}", file=sys.stderr)
        return ids

    if not isinstance(fields, list):
        return ids

    for field in fields:
        if not isinstance(field, dict):
            continue
        field_name = str(field.get('name', '')).strip().lower()
        field_id = str(field.get('id', '')).strip()
        if not field_id:
            continue

        if field_name == 'epic link' and not ids['epic_link']:
            ids['epic_link'] = field_id
        elif field_name == 'parent link' and not ids['parent_link']:
            ids['parent_link'] = field_id

    return ids


def _extract_epic_key_from_issue_fields(fields: dict, field_ids: dict) -> str:
    """Extract the epic key from Jira issue fields across Jira variants."""
    parent = fields.get('parent', {}) if isinstance(fields, dict) else {}
    if isinstance(parent, dict):
        parent_key = parent.get('key', '')
        parent_type = parent.get('fields', {}).get('issuetype', {}).get('name', '') if isinstance(parent.get('fields', {}), dict) else ''
        if isinstance(parent_key, str) and parent_key.strip() and str(parent_type).strip().lower() == 'epic':
            return parent_key.strip()

    epic_link_field = field_ids.get('epic_link', '')
    if epic_link_field:
        epic_link_value = fields.get(epic_link_field, '')
        if isinstance(epic_link_value, str) and epic_link_value.strip():
            return epic_link_value.strip()

    parent_link_field = field_ids.get('parent_link', '')
    if parent_link_field:
        parent_link_value = fields.get(parent_link_field, '')
        if isinstance(parent_link_value, str):
            match = re.match(r'^[A-Z][A-Z0-9_]+-\d+$', parent_link_value.strip())
            if match:
                return parent_link_value.strip()
        elif isinstance(parent_link_value, dict):
            parent_link_key = parent_link_value.get('key', '')
            if isinstance(parent_link_key, str) and re.match(r'^[A-Z][A-Z0-9_]+-\d+$', parent_link_key.strip()):
                return parent_link_key.strip()

    return ''


def _comment_preview(comments: list, max_comment_len: int = 100) -> str:
    """Return a compact single-line preview of comments for table cells."""
    if not comments:
        return '—'

    entries = []
    for comment in comments:
        if not isinstance(comment, dict):
            continue
        body = str(comment.get('body', '')).replace('\n', ' ').strip()
        created = str(comment.get('created', '')).strip()
        text = f"({created}) {body[:max_comment_len]}" if created else body[:max_comment_len]
        if text:
            entries.append(text)

    return '; '.join(entries) if entries else '—'


def _jira_changes_cell(issue: dict) -> str:
    """Render what changed for an issue this period: the in-window transition chain.

    Falls back to '—' when no status change happened in the window (the issue was
    still touched — e.g. a comment — which is why it appears at all).
    """
    changes = str(issue.get('status_changes', '')).strip()
    if not changes:
        return '—'
    date = str(issue.get('status_changed', '')).strip()
    return f'{changes} ({date})' if date else changes


def _group_jira_issues_by_epic(jira_issues: list) -> list:
    """Group Jira issues by parent epic while preserving issue order."""
    groups = []
    groups_by_id = {}

    for issue in jira_issues:
        epic_key = str(issue.get('epic_key', '')).strip()
        if epic_key:
            group_id = epic_key
            group = groups_by_id.get(group_id)
            if not group:
                group = {
                    'id': group_id,
                    'epic_key': epic_key,
                    'epic_summary': issue.get('epic_summary', ''),
                    'epic_status': issue.get('epic_status', ''),
                    'issues': [],
                }
                groups_by_id[group_id] = group
                groups.append(group)
            else:
                if not group.get('epic_summary') and issue.get('epic_summary'):
                    group['epic_summary'] = issue.get('epic_summary', '')
                if not group.get('epic_status') and issue.get('epic_status'):
                    group['epic_status'] = issue.get('epic_status', '')
        else:
            group_id = '__no_epic__'
            group = groups_by_id.get(group_id)
            if not group:
                group = {
                    'id': group_id,
                    'epic_key': '',
                    'epic_summary': 'Issues without epic',
                    'epic_status': '',
                    'issues': [],
                }
                groups_by_id[group_id] = group
                groups.append(group)

        group['issues'].append(issue)

    return groups


def _extract_current_status_changed_at(issue_data: dict, current_status: str, fallback_timestamp: str = ''):
    """Return when the issue most recently transitioned into its current status."""
    changelog = issue_data.get('changelog', {}) if isinstance(issue_data, dict) else {}
    histories = changelog.get('histories', []) if isinstance(changelog, dict) else []

    if isinstance(histories, list):
        for history in reversed(histories):
            if not isinstance(history, dict):
                continue

            items = history.get('items', [])
            if not isinstance(items, list):
                continue

            for item in items:
                if not isinstance(item, dict):
                    continue
                field_name = str(item.get('field', '')).strip().lower()
                if field_name != 'status':
                    continue
                if item.get('toString', '') != current_status:
                    continue

                changed_at = _parse_jira_timestamp(history.get('created', ''))
                if changed_at:
                    return changed_at

    return _parse_jira_timestamp(fallback_timestamp)


def _extract_status_transitions_in_window(issue_data: dict, cutoff) -> list:
    """Return status transitions that occurred on/after ``cutoff``.

    Each entry is {'from', 'to', 'date'} (oldest first). This captures *what
    changed* during the reporting window rather than just the current status.
    """
    changelog = issue_data.get('changelog', {}) if isinstance(issue_data, dict) else {}
    histories = changelog.get('histories', []) if isinstance(changelog, dict) else []
    if not isinstance(histories, list):
        return []

    transitions = []
    for history in histories:
        if not isinstance(history, dict):
            continue
        changed_at = _parse_jira_timestamp(history.get('created', ''))
        if changed_at is None:
            continue
        if changed_at.tzinfo is None:
            changed_at = changed_at.replace(tzinfo=timezone.utc)
        if cutoff is not None and changed_at < cutoff:
            continue

        for item in history.get('items', []):
            if not isinstance(item, dict):
                continue
            if str(item.get('field', '')).strip().lower() != 'status':
                continue
            transitions.append({
                'from': str(item.get('fromString', '') or '').strip(),
                'to': str(item.get('toString', '') or '').strip(),
                'date': changed_at.date().isoformat(),
            })

    transitions.sort(key=lambda t: t['date'])
    return transitions


def _format_status_transitions(transitions: list) -> str:
    """Render in-window transitions as a compact chain, e.g. 'Opened → Review → Closed'."""
    if not transitions:
        return ''

    chain = []
    first_from = transitions[0].get('from', '')
    if first_from:
        chain.append(first_from)
    for t in transitions:
        to_status = t.get('to', '')
        if to_status and (not chain or chain[-1] != to_status):
            chain.append(to_status)

    return ' → '.join(chain)


def query_jira(config: dict, days: int) -> list:
    """Query Jira for issues the user worked on."""
    if requests is None:
        print("  WARNING: 'requests' not installed, skipping Jira", file=sys.stderr)
        return []

    atlassian = config.get('atlassian', {})
    jira_config = config.get('jira', {})

    base_url = atlassian.get('base_url', '')
    pat = atlassian.get('pat', '')
    username = atlassian.get('username', '')
    ssl_verify = atlassian.get('ssl_verify', True)
    projects = jira_config.get('projects', [])

    if not all([base_url, pat]):
        print("  WARNING: Jira config incomplete (need base_url, pat)", file=sys.stderr)
        return []

    if not projects:
        print("  WARNING: No Jira projects configured", file=sys.stderr)
        return []

    headers = {
        'Authorization': f'Bearer {pat}',
        'Content-Type': 'application/json',
    }

    field_ids = _resolve_jira_epic_field_ids(base_url, headers, ssl_verify)
    query_fields = [
        'key', 'summary', 'status', 'components', 'comment',
        'parent', 'statuscategorychangedate', 'created',
    ]
    if field_ids.get('epic_link'):
        query_fields.append(field_ids['epic_link'])
    if field_ids.get('parent_link'):
        query_fields.append(field_ids['parent_link'])

    project_list = ', '.join(projects)
    jql = (
        f'type not in (epic) AND '
        f'((status in (Opened, Review, "Ready for QA", "In Validation", Closed) '
        f'AND updated >= -{days}d) OR '
        f'(status in (Submitted) AND created >= -{days}d)) '
        f'AND assignee = currentUser() '
        f'AND project in ({project_list}) '
        f'ORDER BY created DESC'
    )

    api_url = urljoin(base_url.rstrip('/') + '/', 'rest/api/2/search')
    params = {
        'jql': jql,
        'fields': ','.join(query_fields),
        'expand': 'changelog',
        'maxResults': 50,
    }

    print(f"  JQL: {jql}")

    current_user_identities = _resolve_current_user_identities(base_url, headers, ssl_verify, username)
    if not current_user_identities:
        print("  WARNING: Could not determine Jira user identity for comment matching", file=sys.stderr)

    try:
        resp = requests.get(api_url, headers=headers, params=params, timeout=30, verify=ssl_verify)
        print(f"  Jira response: {resp.status_code} — total: {resp.json().get('total', '?')}")
        resp.raise_for_status()
    except Exception as e:
        print(f"  WARNING: Jira query failed: {e}", file=sys.stderr)
        return []

    data = resp.json()
    issues = []
    epic_keys = set()
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)

    for issue_data in data.get('issues', []):
        fields = issue_data.get('fields', {})
        key = issue_data.get('key', '')
        summary = fields.get('summary', '')
        status = fields.get('status', {}).get('name', '')
        components = [c.get('name', '') for c in fields.get('components', [])]
        epic_key = _extract_epic_key_from_issue_fields(fields, field_ids)
        if epic_key:
            epic_keys.add(epic_key)
        fallback_status_change = fields.get('statuscategorychangedate', '') or fields.get('created', '')
        status_changed_at = _extract_current_status_changed_at(issue_data, status, fallback_status_change)
        if status_changed_at and status_changed_at.tzinfo is None:
            status_changed_at = status_changed_at.replace(tzinfo=timezone.utc)
        status_transitions = _extract_status_transitions_in_window(issue_data, cutoff)

        # Filter comments by author and date
        my_comments = []
        comment_data = fields.get('comment', {})
        issue_comments = _fetch_issue_comments(base_url, headers, ssl_verify, key, comment_data)
        for comment in issue_comments:
            comment_author_identities = _extract_user_identities(comment.get('author', {}))
            created = comment.get('created', '')
            if not created:
                continue

            if current_user_identities and not (comment_author_identities & current_user_identities):
                continue

            comment_date = _parse_jira_timestamp(created)
            if comment_date is None:
                continue
            if comment_date.tzinfo is None:
                comment_date = comment_date.replace(tzinfo=timezone.utc)

            if comment_date >= cutoff:
                my_comments.append({
                    'body': _extract_comment_body(comment.get('body', '')),
                    'created': comment_date.date().isoformat(),
                })

        issues.append({
            'key': key,
            'summary': summary,
            'status': status,
            'status_changed': status_changed_at.date().isoformat() if status_changed_at else '',
            'status_transitions': status_transitions,
            'status_changes': _format_status_transitions(status_transitions),
            'epic_key': epic_key,
            'epic_summary': '',
            'epic_status': '',
            'components': components,
            'my_comments': my_comments,
        })

    if epic_keys:
        epic_details = fetch_epics(sorted(epic_keys), config)
        epic_map = {epic.get('key', ''): epic for epic in epic_details}
        for issue in issues:
            epic_key = issue.get('epic_key', '')
            epic = epic_map.get(epic_key, {})
            issue['epic_summary'] = epic.get('summary', '')
            issue['epic_status'] = epic.get('status', '')

    return issues


# ═══════════════════════════════════════════════════════════════════════════════
# Phase 3: Confluence Query
# ═══════════════════════════════════════════════════════════════════════════════

def query_confluence(config: dict, days: int) -> list:
    """Query Confluence for pages the user edited recently."""
    if requests is None:
        print("  WARNING: 'requests' not installed, skipping Confluence", file=sys.stderr)
        return []

    atlassian = config.get('atlassian', {})
    confluence_config = config.get('confluence', {})

    if not confluence_config.get('enabled', False):
        return []

    # Confluence can have its own base_url; falls back to atlassian base_url
    base_url = confluence_config.get('base_url', '') or atlassian.get('base_url', '')
    pat = confluence_config.get('pat', '') or atlassian.get('pat', '')
    username = confluence_config.get('username', '') or atlassian.get('username', '')
    ssl_verify = confluence_config.get('ssl_verify', atlassian.get('ssl_verify', True))

    if not all([base_url, pat, username]):
        print("  WARNING: Confluence config incomplete (need base_url, pat, username)", file=sys.stderr)
        return []

    headers = {
        'Authorization': f'Bearer {pat}',
        'Content-Type': 'application/json',
    }

    api_url = urljoin(base_url.rstrip('/') + '/', 'rest/api/content/search')
    cql_candidates = [
        f'type = page AND contributor = currentUser() AND lastModified >= now("-{days}d")',
        f'type = page AND contributor = "{username}" AND lastModified >= now("-{days}d")',
        (
            f'type = page AND (creator = currentUser() OR creator = "{username}") '
            f'AND lastModified >= now("-{days}d")'
        ),
    ]

    def _confluence_search(cql_query: str):
        params = {
            'cql': cql_query,
            'limit': 50,
        }
        resp = requests.get(api_url, headers=headers, params=params, timeout=30, verify=ssl_verify)
        if resp.status_code == 401 and username and pat:
            # Some Confluence deployments reject Bearer PAT and require Basic auth.
            basic_headers = {'Content-Type': 'application/json'}
            resp = requests.get(
                api_url,
                headers=basic_headers,
                params=params,
                timeout=30,
                verify=ssl_verify,
                auth=(username, pat),
            )
        resp.raise_for_status()
        return resp.json()

    data = None
    last_error = None
    for cql in cql_candidates:
        try:
            candidate = _confluence_search(cql)
        except Exception as e:
            last_error = e
            continue

        data = candidate
        total = data.get('totalSize', data.get('size', 0))
        print(f"  Confluence CQL matched {total} results: {cql}")
        if data.get('results'):
            break

    if data is None:
        print(
            "  WARNING: Confluence query failed: "
            f"{last_error}. Check confluence.pat (or atlassian.pat) and confluence.username.",
            file=sys.stderr,
        )
        return []

    pages = []

    for result in data.get('results', []):
        title = result.get('title', '')
        space = result.get('space', {}).get('key', '') if 'space' in result else ''
        # Build URL from _links
        links = result.get('_links', {})
        web_link = links.get('webui', '')
        base_link = data.get('_links', {}).get('base', base_url)
        url = base_link.rstrip('/') + web_link if web_link else ''

        # Get last modified from version or history
        version = result.get('version', {})
        modified = version.get('when', '')[:10] if version.get('when') else ''

        pages.append({
            'title': title,
            'space': space,
            'url': url,
            'modified': modified,
        })

    return pages


# ═══════════════════════════════════════════════════════════════════════════════
# Phase 4: Roadmap Regeneration
# ═══════════════════════════════════════════════════════════════════════════════

def regenerate_single_roadmap(roadmap_config: dict, output_dir: Path, label: str = '') -> str:
    """Regenerate a single roadmap SVG. Returns SVG path or empty string."""
    json_path = Path(roadmap_config.get('json_path', '')).expanduser()
    output_path = Path(roadmap_config.get('output_path', '')).expanduser()

    if not json_path.exists():
        print(f"  WARNING: Roadmap JSON not found: {json_path} [{label}]", file=sys.stderr)
        return ''

    # Find generate_roadmap.py relative to this script
    script_dir = Path(__file__).parent
    roadmap_script = script_dir / 'generate_roadmap.py'
    if not roadmap_script.exists():
        print(f"  WARNING: generate_roadmap.py not found at {roadmap_script}", file=sys.stderr)
        return ''

    try:
        result = subprocess.run(
            [sys.executable, str(roadmap_script), str(json_path), '-o', str(output_path)],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            print(f"  WARNING: Roadmap generation failed [{label}]: {result.stderr}", file=sys.stderr)
            return ''
    except Exception as e:
        print(f"  WARNING: Roadmap generation error [{label}]: {e}", file=sys.stderr)
        return ''

    # Copy to output dir
    dest = output_dir / output_path.name
    if output_path.exists():
        shutil.copy2(output_path, dest)
        return str(dest)

    return ''


def regenerate_roadmaps(git_results: list, config: dict, output_dir: Path) -> dict:
    """Regenerate roadmap SVGs for repos that have them configured.

    Returns dict mapping repo name -> SVG path.
    Also handles the global 'roadmap' config as a fallback/global roadmap.
    """
    roadmaps = {}  # repo_name -> svg_path

    # Per-repo roadmaps
    for repo in git_results:
        roadmap_config = repo.get('roadmap')
        if roadmap_config:
            svg_path = regenerate_single_roadmap(roadmap_config, output_dir, label=repo['name'])
            if svg_path:
                roadmaps[repo['name']] = svg_path
                print(f"    {repo['name']}: {svg_path}")

    # Global roadmap (not tied to a specific repo)
    global_roadmap = config.get('roadmap')
    if global_roadmap:
        svg_path = regenerate_single_roadmap(global_roadmap, output_dir, label='global')
        if svg_path:
            roadmaps['__global__'] = svg_path
            print(f"    global: {svg_path}")

    return roadmaps


# ═══════════════════════════════════════════════════════════════════════════════
# Phase 5: Obsidian Markdown Generation
# ═══════════════════════════════════════════════════════════════════════════════

def generate_report_markdown(
    repo_configs: list,
    mr_results: list,
    jira_issues: list,
    confluence_pages: list,
    roadmaps: dict,
    config: dict,
    days: int,
) -> str:
    """Generate the canonical report markdown.

    This is the single source of truth for report structure: it is written to the
    Obsidian vault as-is, and the same string is embedded into the HTML page so the
    browser "Finalize" step only fills MR-summary placeholders — it never re-derives
    the markdown. Keep all layout decisions here.
    """
    today = datetime.now().strftime('%Y-%m-%d')
    show_comments_column = bool(config.get('jira', {}).get('show_comments_column', True))
    lines = []

    # Frontmatter
    lines.append('---')
    lines.append(f'date: {today}')
    lines.append(f'days: {days}')
    mr_projects = sorted({mr.get('project_path', '') for mr in mr_results if mr.get('project_path')})
    if mr_projects:
        lines.append(f'gitlab_projects: [{", ".join(mr_projects)}]')
    jira_projects = config.get('jira', {}).get('projects', [])
    if jira_projects:
        lines.append(f'jira_projects: [{", ".join(jira_projects)}]')
    lines.append('---')
    lines.append('')
    lines.append(f'# Weekly Report — {today}')
    lines.append('')

    # Global roadmap
    global_roadmap = roadmaps.get('__global__', '')
    if global_roadmap:
        lines.append('## Roadmap')
        lines.append(f'![[{Path(global_roadmap).name}]]')
        lines.append('')

    # Repository epics & roadmaps (metadata only)
    repos_with_content = [
        r for r in repo_configs
        if r.get('_epics_detail') or roadmaps.get(r['name'])
    ]
    if repos_with_content:
        lines.append('## Repository Epics & Roadmaps')
        lines.append('')
        for repo in repos_with_content:
            lines.append(f'### {repo["name"]}')
            lines.append('')

            repo_epics = repo.get('_epics_detail', [])
            if repo_epics:
                lines.append('**Epics:**')
                for epic in repo_epics:
                    lines.append(f'- `{epic["key"]}` — {epic["summary"]} [{epic["status"]}]')
                lines.append('')

            repo_roadmap = roadmaps.get(repo['name'], '')
            if repo_roadmap:
                lines.append(f'![[{Path(repo_roadmap).name}]]')
                lines.append('')

    # GitLab MR sections
    if mr_results:
        lines.append('## GitLab Merge Requests')
        lines.append('')

        mrs_by_project = {}
        for mr in mr_results:
            proj = mr.get('project_path', 'Unknown')
            mrs_by_project.setdefault(proj, []).append(mr)

        for project, mrs in mrs_by_project.items():
            lines.append(f'### {project}')
            lines.append('')

            for mr in mrs:
                state = mr.get('state', '')
                if state == 'merged':
                    state_marker = '✓ Merged'
                elif state == 'closed':
                    state_marker = '✗ Closed'
                else:
                    state_marker = '○ Open'

                lines.append(f'#### [{state_marker}] !{mr["iid"]} — {mr["title"]}')
                lines.append('')
                lines.append(
                    f'**Branch:** `{mr["source_branch"]}` → `{mr["target_branch"]}` | '
                    f'**Created:** {mr["created_at"]}' +
                    (f' | **Merged:** {mr["merged_at"]}' if mr.get('merged_at') else '')
                )
                lines.append(f'**URL:** {mr["web_url"]}')
                lines.append('')

                if mr.get('description', '').strip():
                    lines.append('**Description:**')
                    desc = mr['description'].strip()
                    if len(desc) > 600:
                        desc = desc[:600] + '...'
                    lines.append(desc)
                    lines.append('')

                if mr.get('commits'):
                    cn = len(mr['commits'])
                    lines.append(f'**Commits in last {days} day{"s" if days != 1 else ""} ({cn}):**')
                    for commit in mr['commits']:
                        first_line = commit['message'].splitlines()[0] if commit.get('message') else commit.get('title', '')
                        lines.append(f'- `{commit["short_id"]}` ({commit["date"]}) {first_line}')
                    lines.append('')

                if mr.get('changes_summary'):
                    n = len(mr['changes_summary'])
                    lines.append(f'**Changes ({n} file{"s" if n != 1 else ""}):**')
                    lines.append('| File | +Added | −Removed |')
                    lines.append('|------|--------|----------|')
                    for ch in mr['changes_summary'][:20]:
                        fpath = ch['new_path'] or ch['old_path']
                        lines.append(f'| `{fpath}` | +{ch["added_lines"]} | -{ch["removed_lines"]} |')
                    if n > 20:
                        lines.append(f'| _...{n - 20} more files_ | | |')
                    lines.append('')

                if mr.get('notes'):
                    note_count = len(mr['notes'])
                    lines.append(f'**Comments ({note_count}):**')
                    for note in mr['notes'][:5]:
                        author = note.get('author', {}).get('username', 'unknown')
                        created = str(note.get('created_at', ''))[:10]
                        body = str(note.get('body', '')).replace('\n', ' ')[:200]
                        lines.append(f'> ({created}) **{author}**: {body}')
                    if note_count > 5:
                        lines.append(f'> _{note_count - 5} more comments_')
                    lines.append('')

                lines.append(f'<!-- PASTE COPILOT SUMMARY FOR MR !{mr["iid"]} ({project}) HERE -->')
                lines.append('')

    # Jira section
    if jira_issues:
        jira_groups = _group_jira_issues_by_epic(jira_issues)
        lines.append('## Jira Activity')
        lines.append('')

        for group in jira_groups:
            epic_key = group.get('epic_key', '')
            if epic_key:
                epic_summary = group.get('epic_summary', '')
                epic_status = group.get('epic_status', '')
                heading = f'### {epic_key}'
                if epic_summary:
                    heading += f' — {epic_summary}'
                if epic_status:
                    heading += f' [{epic_status}]'
                lines.append(heading)
            else:
                lines.append('### No Epic')
            lines.append('')

            if show_comments_column:
                lines.append('| Key | Summary | Status | Changed This Period | Comments |')
                lines.append('|-----|---------|--------|---------------------|----------|')
            else:
                lines.append('| Key | Summary | Status | Changed This Period |')
                lines.append('|-----|---------|--------|---------------------|')

            for issue in group.get('issues', []):
                summary = str(issue.get('summary', '')).replace('|', '\\|')
                changes_cell = _jira_changes_cell(issue).replace('|', '\\|')
                if show_comments_column:
                    comment_cell = _comment_preview(issue.get('my_comments', []))
                    comment_cell = comment_cell.replace('|', '\\|')
                    lines.append(
                        f'| {issue.get("key", "")} | {summary} | {issue.get("status", "")} '
                        f'| {changes_cell} | {comment_cell} |'
                    )
                else:
                    lines.append(
                        f'| {issue.get("key", "")} | {summary} | {issue.get("status", "")} | {changes_cell} |'
                    )

            lines.append('')

            if not show_comments_column:
                issues_with_comments = [i for i in group.get('issues', []) if i.get('my_comments')]
                if issues_with_comments:
                    lines.append('**My Comments**')
                    lines.append('')
                    for issue in issues_with_comments:
                        lines.append(f'**{issue.get("key", "")}** — {issue.get("summary", "")}')
                        for comment in issue.get('my_comments', []):
                            lines.append(f'> ({comment.get("created", "")}) {str(comment.get("body", ""))[:200]}')
                        lines.append('')

    # Confluence section
    if confluence_pages:
        lines.append('## Confluence Pages Edited')
        lines.append('')
        for page in confluence_pages:
            url_part = f'({page["url"]})' if page['url'] else ''
            space_part = f' [{page["space"]}]' if page['space'] else ''
            lines.append(f'- [{page["title"]}]{url_part}{space_part} — {page["modified"]}')
        lines.append('')

    # Detailed section placeholder
    lines.append('## Detailed Notes')
    lines.append('')
    lines.append('<!-- Paste cleaned-up Copilot output here -->')
    lines.append('')

    return '\n'.join(lines)


def write_obsidian_file(content: str, config: dict) -> str:
    """Write markdown to Obsidian vault. Returns file path."""
    vault = config.get('obsidian_vault', '')
    if not vault:
        return ''

    vault_path = Path(vault).expanduser()
    folder = config.get('obsidian_folder', 'Weekly Reports')
    target_dir = vault_path / folder

    if not vault_path.exists():
        print(f"  WARNING: Obsidian vault path does not exist: {vault_path}", file=sys.stderr)
        return ''

    target_dir.mkdir(parents=True, exist_ok=True)

    today = datetime.now().strftime('%Y-%m-%d')
    filename = f"{today}_weekly_report.md"
    filepath = target_dir / filename
    filepath.write_text(content)

    return str(filepath)


# ═══════════════════════════════════════════════════════════════════════════════
# Phase 6: Static HTML Generation
# ═══════════════════════════════════════════════════════════════════════════════

def generate_html(
    repo_configs: list,
    mr_results: list,
    jira_issues: list,
    confluence_pages: list,
    roadmaps: dict,
    config: dict,
    days: int,
    report_markdown: str = '',
    serve_mode: bool = False,
) -> str:
    """Generate static HTML report with copy buttons and paste-back textareas.

    ``report_markdown`` is the canonical markdown from generate_report_markdown();
    it is embedded verbatim and the browser "Finalize" step only substitutes
    MR-summary placeholders into it (no markdown is rebuilt client-side).
    """
    today = datetime.now().strftime('%Y-%m-%d')
    show_comments_column = bool(config.get('jira', {}).get('show_comments_column', True))
    jira_groups = _group_jira_issues_by_epic(jira_issues)
    mr_ids_json = json.dumps([f"{mr['project_path']}!{mr['iid']}" for mr in mr_results])

    # Build HTML
    h = []
    h.append('<!DOCTYPE html>')
    h.append('<html lang="en"><head><meta charset="UTF-8">')
    h.append(f'<title>Weekly Report — {today}</title>')
    h.append('<meta name="viewport" content="width=device-width, initial-scale=1">')
    h.append('<style>')
    h.append(CSS)
    h.append('</style></head><body>')
    h.append(f'<header><h1>Weekly Work Report — {today}</h1>')
    h.append(f'<p class="subtitle">Last {days} days of activity</p></header>')
    h.append('<main>')

    # Global roadmap
    global_roadmap = roadmaps.get('__global__', '')
    if global_roadmap and Path(global_roadmap).exists():
        h.append('<section class="panel">')
        h.append('<h2>Roadmap</h2>')
        svg_content = Path(global_roadmap).read_text()
        h.append(f'<div class="roadmap-svg">{svg_content}</div>')
        h.append('</section>')

    # Repository epics & roadmaps (metadata only, no git log)
    repos_with_content = [
        r for r in repo_configs
        if r.get('_epics_detail') or roadmaps.get(r['name'])
    ]
    if repos_with_content:
        h.append('<section class="panel">')
        h.append('<h2>Repository Epics &amp; Roadmaps</h2>')
        for repo in repos_with_content:
            h.append(f'<div class="repo-panel">')
            h.append(f'<h3>{html.escape(repo["name"])}</h3>')

            repo_epics = repo.get('_epics_detail', [])
            if repo_epics:
                h.append('<div class="epics-list"><strong>Epics:</strong> ')
                epic_parts = [
                    f'<span class="epic-badge">{html.escape(e["key"])}</span> {html.escape(e["summary"])} '
                    f'<span class="status-badge">{html.escape(e["status"])}</span>'
                    for e in repo_epics
                ]
                h.append(' &middot; '.join(epic_parts))
                h.append('</div>')

            repo_roadmap = roadmaps.get(repo['name'], '')
            if repo_roadmap and Path(repo_roadmap).exists():
                svg_content = Path(repo_roadmap).read_text()
                h.append(f'<div class="roadmap-svg">{svg_content}</div>')

            h.append('</div>')
        h.append('</section>')

    # GitLab Merge Requests
    if mr_results:
        h.append('<section class="panel">')
        h.append('<h2>GitLab Merge Requests</h2>')

        mrs_by_project = {}
        for mr in mr_results:
            proj = mr.get('project_path', 'Unknown')
            mrs_by_project.setdefault(proj, []).append(mr)

        for project, mrs in mrs_by_project.items():
            h.append(f'<h3>{html.escape(project)}</h3>')
            for mr in mrs:
                state = mr.get('state', '')
                state_class = 'mr-merged' if state == 'merged' else ('mr-closed' if state == 'closed' else 'mr-open')
                state_label = {'merged': '✓ Merged', 'closed': '✗ Closed'}.get(state, '○ Open')
                mr_key = f"{mr['project_path']}!{mr['iid']}"
                safe_key = mr_key.replace('/', '_').replace('!', '_')

                h.append(f'<div class="mr-panel {state_class}" data-mr="{html.escape(mr_key)}">')
                h.append(f'<div class="mr-header">')
                h.append(f'<span class="mr-state-badge {state_class}">{state_label}</span> ')
                h.append(f'<strong>!{mr["iid"]}</strong> — ')
                if mr.get('web_url'):
                    h.append(f'<a href="{html.escape(mr["web_url"])}" target="_blank">{html.escape(mr["title"])}</a>')
                else:
                    h.append(html.escape(mr['title']))
                h.append('</div>')

                # Meta info
                meta_parts = [f'<code>{html.escape(mr["source_branch"])}</code> → <code>{html.escape(mr["target_branch"])}</code>']
                if mr.get('created_at'):
                    meta_parts.append(f'Created: {html.escape(mr["created_at"])}')
                if mr.get('merged_at'):
                    meta_parts.append(f'Merged: {html.escape(mr["merged_at"])}')
                h.append(f'<p class="mr-meta">{" &nbsp;|&nbsp; ".join(meta_parts)}</p>')

                # Description
                if mr.get('description', '').strip():
                    h.append(f'<details class="mr-details"><summary>Description</summary>')
                    h.append(f'<pre class="mr-description">{html.escape(mr["description"])}</pre>')
                    h.append('</details>')

                # Commits within the --days window
                if mr.get('commits'):
                    cn = len(mr['commits'])
                    h.append(f'<details class="mr-details"><summary>Commits in last {days} day{"s" if days != 1 else ""} ({cn})</summary>')
                    h.append('<ul class="mr-commits">')
                    for commit in mr['commits']:
                        first_line = commit['message'].splitlines()[0] if commit.get('message') else commit.get('title', '')
                        h.append(
                            f'<li><code>{html.escape(commit["short_id"])}</code> '
                            f'<span class="note-meta">({html.escape(commit["date"])})</span> '
                            f'{html.escape(first_line)}</li>'
                        )
                    h.append('</ul></details>')

                # Changes summary
                if mr.get('changes_summary'):
                    n = len(mr['changes_summary'])
                    h.append(f'<details class="mr-details"><summary>Changes ({n} file{"s" if n != 1 else ""})</summary>')
                    h.append('<table class="changes-table"><thead><tr><th>File</th><th>+Added</th><th>−Removed</th></tr></thead><tbody>')
                    for ch in mr['changes_summary']:
                        fpath = html.escape(ch['new_path'] or ch['old_path'])
                        badge = ''
                        if ch.get('new_file'):
                            badge = ' <span class="file-badge new">new</span>'
                        elif ch.get('deleted_file'):
                            badge = ' <span class="file-badge del">del</span>'
                        elif ch.get('renamed_file'):
                            badge = ' <span class="file-badge ren">ren</span>'
                        h.append(f'<tr><td><code>{fpath}</code>{badge}</td>'
                                 f'<td class="added">+{ch["added_lines"]}</td>'
                                 f'<td class="removed">-{ch["removed_lines"]}</td></tr>')
                    h.append('</tbody></table></details>')

                # Comments/notes
                if mr.get('notes'):
                    note_count = len(mr['notes'])
                    h.append(f'<details class="mr-details"><summary>Comments ({note_count})</summary>')
                    h.append('<div class="mr-notes">')
                    for note in mr['notes']:
                        author = html.escape(note.get('author', {}).get('username', 'unknown'))
                        created = html.escape(str(note.get('created_at', ''))[:10])
                        body = html.escape(str(note.get('body', '')))
                        h.append(f'<div class="note"><span class="note-meta">({created}) <strong>{author}</strong>:</span> {body}</div>')
                    h.append('</div></details>')

                h.append('<details class="mr-details">')
                h.append('<summary>AI Prompt</summary>')
                h.append(f'<pre class="mr-description">{html.escape(COPILOT_PROMPT)}</pre>')
                h.append('</details>')

                # Copilot prompt (AI instructions + description + diff)
                prompt_text = (
                    f"AI Prompt:\n{COPILOT_PROMPT}\n\n"
                    f"GitLab MR !{mr['iid']} — {mr['title']}\n"
                    f"Project: {mr['project_path']}\n"
                    f"Branch: {mr['source_branch']} → {mr['target_branch']}\n"
                    f"State: {mr['state']}\n\n"
                    f"Description:\n{mr.get('description', '(none)').strip()}\n\n"
                    f"--- DIFF ---\n{mr.get('diff_content', '(no diff)')}"
                )
                prompt_id = f'prompt-{safe_key}'
                paste_id = f'paste-{safe_key}'
                h.append('<div class="copy-section">')
                h.append('<label>Copilot Prompt (AI instructions + description + diff):</label>')
                h.append(f'<textarea id="{prompt_id}" class="code-area" rows="5" readonly>{html.escape(prompt_text)}</textarea>')
                h.append(f'<button class="btn copy-btn" onclick="copyText(\'{prompt_id}\')">Copy Prompt</button>')
                h.append('</div>')
                h.append('<div class="paste-section">')
                h.append('<label>Paste Copilot Summary:</label>')
                h.append(f'<textarea id="{paste_id}" class="paste-area" rows="5" '
                         f'placeholder="Paste Copilot\'s summary here..."></textarea>')
                if serve_mode:
                    h.append(f'<button class="btn save-btn" '
                             f'onclick="saveMRSummary({json.dumps(mr_key)}, \'{paste_id}\')">Save to Obsidian</button>')
                h.append('</div>')

                h.append('</div>')  # end mr-panel

        h.append('</section>')

    # Jira
    if jira_groups:
        h.append('<section class="panel">')
        h.append('<h2>Jira Activity</h2>')
        jira_id = 'jira-content'
        h.append(f'<div id="{jira_id}">')
        for group in jira_groups:
            epic_key = group.get('epic_key', '')
            if epic_key:
                epic_heading = html.escape(epic_key)
                epic_summary = group.get('epic_summary', '')
                epic_status = group.get('epic_status', '')
                if epic_summary:
                    epic_heading += f' — {html.escape(epic_summary)}'
                if epic_status:
                    epic_heading += f' <span class="status-badge">{html.escape(epic_status)}</span>'
            else:
                epic_heading = 'No Epic'

            h.append('<div class="jira-epic-group">')
            h.append(f'<h3>{epic_heading}</h3>')
            h.append('<table><thead><tr><th>Key</th><th>Summary</th><th>Status</th><th>Changed This Period</th>')
            if show_comments_column:
                h.append('<th>Comments</th>')
            h.append('</tr></thead><tbody>')

            for issue in group.get('issues', []):
                h.append(f'<tr><td>{html.escape(issue.get("key", ""))}</td>'
                         f'<td>{html.escape(issue.get("summary", ""))}</td>'
                         f'<td><span class="status-badge">{html.escape(issue.get("status", ""))}</span></td>'
                         f'<td>{html.escape(_jira_changes_cell(issue))}</td>')
                if show_comments_column:
                    h.append(f'<td>{html.escape(_comment_preview(issue.get("my_comments", [])))}</td>')
                h.append('</tr>')

            h.append('</tbody></table>')

            if not show_comments_column:
                issues_with_comments = [i for i in group.get('issues', []) if i.get('my_comments')]
                if issues_with_comments:
                    h.append('<div class="jira-group-comments"><strong>My Comments:</strong><ul>')
                    for issue in issues_with_comments:
                        comments_str = _comment_preview(issue.get('my_comments', []), max_comment_len=200)
                        h.append(f'<li><strong>{html.escape(issue.get("key", ""))}</strong> — {html.escape(comments_str)}</li>')
                    h.append('</ul></div>')

            h.append('</div>')

        h.append('</div>')
        h.append(f'<button class="btn copy-btn" onclick="copyElement(\'{jira_id}\')">Copy Jira Section</button>')
        h.append('</section>')

    # Confluence
    if confluence_pages:
        h.append('<section class="panel">')
        h.append('<h2>Confluence Pages Edited</h2>')
        confluence_id = 'confluence-content'
        h.append(f'<div id="{confluence_id}">')
        h.append('<ul>')
        for page in confluence_pages:
            link = f'<a href="{html.escape(page["url"])}">{html.escape(page["title"])}</a>' if page['url'] else html.escape(page['title'])
            h.append(f'<li>{link} [{html.escape(page["space"])}] — {html.escape(page["modified"])}</li>')
        h.append('</ul>')
        h.append('</div>')
        h.append(f'<button class="btn copy-btn" onclick="copyElement(\'{confluence_id}\')">Copy Confluence Section</button>')
        h.append('</section>')

    # Finalize button (always shown if there's any content)
    if mr_results or jira_issues or confluence_pages:
        h.append('<section class="panel save-all-panel">')
        if serve_mode and mr_results:
            h.append('<button class="btn save-all-btn" onclick="saveAllMRSummaries()">Save All MR Summaries</button>')
        h.append('<button class="btn finalize-btn" onclick="finalizeReport()">Finalize Report</button>')
        h.append('<span id="save-status"></span>')
        h.append('</section>')

        h.append('<section id="final-report-panel" class="panel final-report-panel" style="display:none;">')
        h.append('<h2>Finalized Report Output</h2>')
        h.append('<label for="final-report-output">Review and edit before saving:</label>')
        h.append('<textarea id="final-report-output" class="code-area final-report-area" rows="18" '
                 'placeholder="Click Finalize Report to generate output..."></textarea>')
        h.append('<div class="final-report-actions">')
        h.append('<button id="save-final-report-btn" class="btn save-all-btn" style="display:none;" '
                 'onclick="saveFinalReport()">Save Final Report</button>')
        h.append('</div>')
        h.append('</section>')

    # The canonical markdown is the single source of truth for the finalized report.
    # The client only needs the markdown template plus the MR identifiers required to
    # substitute pasted summaries into their placeholders — no diffs, no Jira/Confluence
    # data re-derived in JS.
    mr_keys_for_js = [
        {'project_path': mr.get('project_path', ''), 'iid': mr.get('iid')}
        for mr in mr_results
    ]
    h.append('<script>')
    h.append(f'const REPORT_TEMPLATE = {json.dumps(report_markdown)};')
    h.append(f'const MR_RESULTS = {json.dumps(mr_keys_for_js)};')
    h.append(f'const REPORT_DATE = {json.dumps(today)};')
    h.append(f'const DAYS = {days};')
    h.append(f'const SERVE_MODE = {"true" if serve_mode else "false"};')
    h.append('</script>')

    h.append('</main>')
    h.append('<script>')
    h.append(JS.replace('__MR_IDS_JSON__', mr_ids_json))
    h.append('</script>')
    h.append('</body></html>')

    return '\n'.join(h)


CSS = """
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
       background: #f5f7fa; color: #2d3436; padding: 2rem; max-width: 1200px; margin: 0 auto; }
header { margin-bottom: 2rem; }
h1 { color: #004b50; font-size: 1.8rem; }
.subtitle { color: #6b7c80; margin-top: 0.3rem; }
h2 { color: #007a82; margin-bottom: 1rem; font-size: 1.3rem; border-bottom: 2px solid #dfe6e9; padding-bottom: 0.5rem; }
h3 { color: #2d3436; margin: 1rem 0 0.5rem; font-size: 1.1rem; }
.panel { background: #fff; border-radius: 8px; padding: 1.5rem; margin-bottom: 1.5rem;
         box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
.repo-panel { border-left: 3px solid #00a19a; padding-left: 1rem; margin-bottom: 1.5rem; }
.copy-section, .paste-section { margin: 0.8rem 0; }
label { display: block; font-weight: 600; font-size: 0.85rem; color: #4a5568; margin-bottom: 0.3rem; }
.code-area { width: 100%; font-family: 'JetBrains Mono', monospace; font-size: 0.8rem;
             background: #f8f9fa; border: 1px solid #dfe6e9; border-radius: 4px; padding: 0.5rem; resize: vertical; }
.paste-area { width: 100%; font-family: inherit; font-size: 0.9rem;
              border: 2px dashed #00a19a; border-radius: 4px; padding: 0.5rem; resize: vertical;
              background: #f0fffe; }
.btn { padding: 0.4rem 1rem; border: none; border-radius: 4px; cursor: pointer;
       font-size: 0.85rem; font-weight: 600; margin-top: 0.3rem; transition: all 0.2s; }
.copy-btn { background: #007a82; color: #fff; }
.copy-btn:hover { background: #005f66; }
.save-btn { background: #00a19a; color: #fff; }
.save-btn:hover { background: #007a82; }
.save-all-btn { background: #004b50; color: #fff; padding: 0.8rem 2rem; font-size: 1rem; }
.save-all-btn:hover { background: #003538; }
.finalize-btn { background: #00a19a; color: #fff; padding: 0.8rem 2rem; font-size: 1rem; margin-left: 1rem; }
.finalize-btn:hover { background: #007a82; }
.save-all-panel { text-align: center; }
#save-status { display: block; margin-top: 0.8rem; color: #00a19a; font-weight: 600; }
.muted { color: #8c9ea3; font-style: italic; }
.jira-epic-group { margin-bottom: 1.2rem; }
.jira-group-comments { margin: 0.6rem 0 0.2rem; color: #2d3436; font-size: 0.88rem; }
.final-report-actions { margin-top: 0.8rem; text-align: right; }
.final-report-area { min-height: 20rem; white-space: pre; }
table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
th, td { padding: 0.5rem; text-align: left; border-bottom: 1px solid #e4eaec; }
th { background: #f7f9fa; font-weight: 600; color: #004b50; }
.status-badge { background: #e0f7f5; color: #007a82; padding: 0.15rem 0.5rem;
                border-radius: 10px; font-size: 0.8rem; font-weight: 600; }
ul { padding-left: 1.5rem; }
li { margin: 0.3rem 0; }
a { color: #007a82; text-decoration: none; }
a:hover { text-decoration: underline; }
.roadmap-svg { overflow-x: auto; margin: 1rem 0; }
.roadmap-svg svg { max-width: 100%; height: auto; }
.epics-list { margin: 0.5rem 0 1rem; font-size: 0.9rem; color: #4a5568; }
.epic-badge { background: #004b50; color: #fff; padding: 0.1rem 0.4rem; border-radius: 3px;
              font-size: 0.8rem; font-weight: 600; font-family: monospace; }
.mr-panel { border-left: 3px solid #00a19a; padding: 0.8rem 1rem; margin-bottom: 1.2rem; background: #f8fdfd; border-radius: 0 4px 4px 0; }
.mr-panel.mr-merged { border-left-color: #27ae60; }
.mr-panel.mr-closed { border-left-color: #e74c3c; opacity: 0.8; }
.mr-header { font-size: 1rem; margin-bottom: 0.4rem; }
.mr-meta { font-size: 0.82rem; color: #6b7c80; margin-bottom: 0.5rem; }
.mr-state-badge { padding: 0.15rem 0.5rem; border-radius: 10px; font-size: 0.78rem; font-weight: 700; }
.mr-merged .mr-state-badge { background: #d5f5e3; color: #1e8449; }
.mr-closed .mr-state-badge { background: #fde8e8; color: #c0392b; }
.mr-open .mr-state-badge { background: #eaf4ff; color: #2471a3; }
.mr-details { margin: 0.4rem 0; }
.mr-details summary { cursor: pointer; font-size: 0.85rem; font-weight: 600; color: #007a82; }
.mr-description { white-space: pre-wrap; font-size: 0.85rem; background: #f0f4f8; padding: 0.6rem; border-radius: 4px; margin-top: 0.4rem; max-height: 200px; overflow-y: auto; }
.mr-notes { padding: 0.4rem 0; }
.mr-commits { margin: 0.4rem 0 0.4rem 1.2rem; font-size: 0.85rem; }
.mr-commits code { background: #eef3f3; padding: 0 0.25rem; border-radius: 3px; }
.note { font-size: 0.85rem; padding: 0.3rem 0; border-bottom: 1px solid #eee; }
.note-meta { color: #6b7c80; }
.changes-table { font-size: 0.82rem; }
.changes-table td, .changes-table th { padding: 0.2rem 0.5rem; }
.added { color: #27ae60; font-weight: 600; }
.removed { color: #e74c3c; font-weight: 600; }
.file-badge { font-size: 0.7rem; padding: 0.1rem 0.3rem; border-radius: 3px; font-weight: 700; }
.file-badge.new { background: #d5f5e3; color: #1e8449; }
.file-badge.del { background: #fde8e8; color: #c0392b; }
.file-badge.ren { background: #fef9e7; color: #d68910; }
"""

JS = """
const MR_IDS = __MR_IDS_JSON__;

function copyText(id) {
    const el = document.getElementById(id);
    el.select();
    navigator.clipboard.writeText(el.value).then(() => {
        const btn = el.parentElement.querySelector('.copy-btn');
        const orig = btn.textContent;
        btn.textContent = 'Copied!';
        setTimeout(() => btn.textContent = orig, 2000);
    });
}

function copyElement(id) {
    const el = document.getElementById(id);
    navigator.clipboard.writeText(el.innerText).then(() => {
        const btn = el.parentElement.querySelector('.copy-btn');
        const orig = btn.textContent;
        btn.textContent = 'Copied!';
        setTimeout(() => btn.textContent = orig, 2000);
    });
}

function saveMRSummary(mrKey, textareaId) {
    const text = document.getElementById(textareaId).value;
    if (!text.trim()) { alert('Paste a summary first.'); return; }
    fetch('/save', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({mr_key: mrKey, summary: text})
    }).then(r => r.json()).then(data => {
        if (data.ok) {
            const btn = document.getElementById(textareaId).parentElement.querySelector('.save-btn');
            btn.textContent = 'Saved!';
            btn.style.background = '#2d7a75';
            setTimeout(() => { btn.textContent = 'Save to Obsidian'; btn.style.background = ''; }, 3000);
        } else {
            alert('Save failed: ' + (data.error || 'unknown'));
        }
    }).catch(e => alert('Save failed: ' + e));
}

function saveAllMRSummaries() {
    const status = document.getElementById('save-status');
    const promises = MR_IDS.map(mrKey => {
        const safeKey = mrKey.replace(/\\//g, '_').replace(/!/g, '_');
        const textarea = document.getElementById('paste-' + safeKey);
        if (textarea && textarea.value.trim()) {
            return fetch('/save', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({mr_key: mrKey, summary: textarea.value})
            }).then(r => r.json());
        }
        return Promise.resolve({ok: true, skipped: true});
    });
    Promise.all(promises).then(results => {
        const saved = results.filter(r => r.ok && !r.skipped).length;
        status.textContent = saved > 0 ? `Saved ${saved} MR summaries!` : 'Nothing to save (paste summaries first).';
        setTimeout(() => status.textContent = '', 5000);
    }).catch(e => { status.textContent = 'Error: ' + e; });
}

function buildFinalReport() {
    // The Python side already rendered the full report into REPORT_TEMPLATE, with a
    // placeholder comment per MR. Finalizing just swaps each placeholder for the
    // pasted summary (or leaves it untouched when nothing was pasted). This keeps the
    // Obsidian note and the finalized report structurally identical by construction.
    let md = REPORT_TEMPLATE;
    for (const mr of MR_RESULTS) {
        const placeholder = `<!-- PASTE COPILOT SUMMARY FOR MR !${mr.iid} (${mr.project_path}) HERE -->`;
        const safeKey = (mr.project_path + '!' + mr.iid).replace(/\\//g, '_').replace(/!/g, '_');
        const textarea = document.getElementById('paste-' + safeKey);
        const summary = textarea && textarea.value.trim();
        const replacement = summary ? `**Summary:**\\n${summary}` : placeholder;
        md = md.split(placeholder).join(replacement);
    }
    return md;
}

function toggleSaveFinalReportButton() {
    const output = document.getElementById('final-report-output');
    const saveButton = document.getElementById('save-final-report-btn');
    if (!output || !saveButton) {
        return;
    }

    if (output.value.trim()) {
        saveButton.style.display = 'inline-block';
    } else {
        saveButton.style.display = 'none';
    }
}

function finalizeReport() {
    const status = document.getElementById('save-status');
    const md = buildFinalReport();

    const finalPanel = document.getElementById('final-report-panel');
    const output = document.getElementById('final-report-output');
    if (!finalPanel || !output) {
        status.textContent = 'Finalize output panel is missing from this report page.';
        return;
    }

    output.value = md;
    finalPanel.style.display = 'block';
    toggleSaveFinalReportButton();

    if (md.trim()) {
        status.textContent = 'Final report generated below. Review it, then click Save Final Report.';
    } else {
        status.textContent = 'Final report is empty. Add content before saving.';
    }
}

function saveFinalReport() {
    const status = document.getElementById('save-status');
    const output = document.getElementById('final-report-output');
    if (!output || !output.value.trim()) {
        status.textContent = 'Final report output is empty. Generate or edit it first.';
        return;
    }

    const content = output.value;

    if (SERVE_MODE) {
        fetch('/finalize', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({content})
        }).then(r => r.json()).then(data => {
            if (data.ok) {
                status.textContent = `Final report saved: ${data.path}`;
                setTimeout(() => status.textContent = '', 8000);
            } else {
                status.textContent = 'Save failed: ' + (data.error || 'unknown');
            }
        }).catch(e => { status.textContent = 'Save failed: ' + e; });
    } else {
        const blob = new Blob([content], {type: 'text/markdown'});
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `${REPORT_DATE}_final_report.md`;
        a.click();
        URL.revokeObjectURL(url);
        status.textContent = 'Final report downloaded.';
        setTimeout(() => status.textContent = '', 5000);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    const output = document.getElementById('final-report-output');
    if (output) {
        output.addEventListener('input', toggleSaveFinalReportButton);
        toggleSaveFinalReportButton();
    }
});
"""


# ═══════════════════════════════════════════════════════════════════════════════
# Phase 7: Local HTTP Server (serve mode)
# ═══════════════════════════════════════════════════════════════════════════════

class ReportHandler(SimpleHTTPRequestHandler):
    """HTTP handler that serves report.html and handles save-back POSTs."""

    obsidian_file = ''
    output_dir = ''

    def do_GET(self):
        if self.path == '/' or self.path == '/index.html':
            self.path = '/report.html'
        super().do_GET()

    def do_POST(self):
        if self.path == '/save':
            self._handle_save()
        elif self.path == '/finalize':
            self._handle_finalize()
        else:
            self.send_json(404, {'ok': False, 'error': 'Not found'})

    def _read_post_body(self, max_size=1_000_000) -> bytes:
        content_length = int(self.headers.get('Content-Length', 0))
        if content_length > max_size:
            return None
        return self.rfile.read(content_length)

    def _handle_save(self):
        body = self._read_post_body()
        if body is None:
            self.send_json(400, {'ok': False, 'error': 'Payload too large'})
            return
        try:
            data = json.loads(body)
        except json.JSONDecodeError:
            self.send_json(400, {'ok': False, 'error': 'Invalid JSON'})
            return

        summary = data.get('summary', '')
        mr_key = data.get('mr_key', '')  # e.g. "namespace/project!42"

        if not summary:
            self.send_json(400, {'ok': False, 'error': 'Missing summary'})
            return

        if mr_key:
            # Sanitize: allow alphanum, /, !, -, _
            mr_key = re.sub(r'[^a-zA-Z0-9/_!\-.]', '', mr_key)
            success, error = self.update_obsidian_mr(mr_key, summary)
        else:
            self.send_json(400, {'ok': False, 'error': 'Missing mr_key'})
            return

        if success:
            self.send_json(200, {'ok': True})
        else:
            self.send_json(200, {'ok': False, 'error': error})

    def _handle_finalize(self):
        body = self._read_post_body(max_size=5_000_000)
        if body is None:
            self.send_json(400, {'ok': False, 'error': 'Payload too large'})
            return
        try:
            data = json.loads(body)
        except json.JSONDecodeError:
            self.send_json(400, {'ok': False, 'error': 'Invalid JSON'})
            return

        content = data.get('content', '')
        if not content:
            self.send_json(400, {'ok': False, 'error': 'No content provided'})
            return

        today = datetime.now().strftime('%Y-%m-%d')
        filename = f"{today}_final_report.md"
        filepath = Path(self.output_dir) / filename
        filepath.write_text(content)
        self.send_json(200, {'ok': True, 'path': str(filepath)})

    def update_obsidian_mr(self, mr_key: str, summary: str) -> tuple:
        """Update the Obsidian markdown file with a pasted MR summary.
        mr_key is e.g. 'namespace/project!42'.
        Returns (success: bool, error: str)."""
        obsidian_path = Path(self.obsidian_file)
        if not obsidian_path.exists():
            return False, f'Report file not found: {self.obsidian_file}'

        # Parse project and iid from key like 'ns/project!42'
        match = re.match(r'^(.+)!(\d+)$', mr_key)
        if not match:
            return False, f'Invalid mr_key format: {mr_key}'
        project_path = match.group(1)
        iid = match.group(2)

        content = obsidian_path.read_text()
        placeholder = f'<!-- PASTE COPILOT SUMMARY FOR MR !{iid} ({project_path}) HERE -->'
        if placeholder in content:
            content = content.replace(placeholder, f'**Summary:**\n{summary}')
        else:
            content += f'\n**Summary for MR !{iid} ({project_path}):**\n{summary}\n'

        obsidian_path.write_text(content)
        return True, ''

    def send_json(self, code: int, data: dict):
        response = json.dumps(data).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(response)))
        self.end_headers()
        self.wfile.write(response)

    def log_message(self, format, *args):
        print(f"  [server] {args[0]}")


def start_server(output_dir: Path, obsidian_file: str, port: int = 8787, timeout: int = 600):
    """Start local HTTP server for save-back. Auto-shuts down after timeout."""
    ReportHandler.obsidian_file = obsidian_file
    ReportHandler.output_dir = str(output_dir)

    os.chdir(output_dir)
    server = HTTPServer(('127.0.0.1', port), ReportHandler)

    # Auto-shutdown timer
    timer = threading.Timer(timeout, server.shutdown)
    timer.daemon = True
    timer.start()

    url = f'http://127.0.0.1:{port}/'
    print(f"\n  Server running at {url}")
    print(f"  Auto-shutdown in {timeout // 60} minutes. Press Ctrl+C to stop.\n")
    webbrowser.open(url)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        timer.cancel()
        server.server_close()
        print("\n  Server stopped.")


# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description='Generate weekly work report from GitLab MRs, Jira, and Confluence activity.'
    )
    parser.add_argument('--config', type=Path, default=DEFAULT_CONFIG_PATH,
                        help=f'Config file path (default: {DEFAULT_CONFIG_PATH})')
    parser.add_argument('--days', type=int, default=None,
                        help='Number of days to look back (default: from config or 7)')
    parser.add_argument('--no-gitlab', action='store_true',
                        help='Skip GitLab MR query')
    parser.add_argument('--no-roadmap', action='store_true',
                        help='Skip roadmap SVG regeneration')
    parser.add_argument('--no-jira', action='store_true',
                        help='Skip Jira query')
    parser.add_argument('--no-confluence', action='store_true',
                        help='Skip Confluence query')
    parser.add_argument('--serve', action='store_true',
                        help='Start local server for save-back to Obsidian')
    parser.add_argument('--open', action='store_true',
                        help='Open HTML report in browser (no server)')
    parser.add_argument('--port', type=int, default=8787,
                        help='Port for local server (default: 8787)')
    args = parser.parse_args()

    # Load config
    print("Loading config...")
    config = load_config(args.config)
    days = args.days if args.days is not None else config.get('days', 7)
    if days < 0:
        parser.error('--days must be >= 0')
    output_dir = Path(config['output_dir']).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    # Phase 1: Repo configs (metadata only — no git operations)
    print(f"\n[Phase 1] Loading repo configs...")
    repo_configs = collect_repo_configs(config.get('repos', []))
    print(f"  Loaded {len(repo_configs)} repo configs")

    # Phase 1b: GitLab MRs
    gitlab_mrs = []
    if not args.no_gitlab and config.get('gitlab', {}).get('base_url'):
        print(f"\n[Phase 1b] Querying GitLab merge requests ({days} days)...")
        gitlab_mrs = query_gitlab_mrs(config, days, output_dir)
        print(f"  Total: {len(gitlab_mrs)} merge requests")
    elif not args.no_gitlab:
        print("\n[Phase 1b] Skipping GitLab (not configured — add gitlab.base_url and gitlab.token to config)")

    # Phase 2: Jira
    jira_issues = []
    if not args.no_jira and config.get('atlassian', {}).get('base_url'):
        print(f"\n[Phase 2] Querying Jira...")
        jira_issues = query_jira(config, days)
        print(f"  Found {len(jira_issues)} issues")

        # Fetch per-repo epic details
        for repo in repo_configs:
            if repo.get('epics'):
                epic_details = fetch_epics(repo['epics'], config)
                repo['_epics_detail'] = epic_details
                if epic_details:
                    print(f"    {repo['name']} epics: {', '.join(e['key'] for e in epic_details)}")
    elif not args.no_jira:
        print("\n[Phase 2] Skipping Jira (not configured)")

    # Phase 3: Confluence
    confluence_pages = []
    if not args.no_confluence and config.get('confluence', {}).get('enabled'):
        print(f"\n[Phase 3] Querying Confluence...")
        confluence_pages = query_confluence(config, days)
        print(f"  Found {len(confluence_pages)} pages")
    elif not args.no_confluence:
        print("\n[Phase 3] Skipping Confluence (not configured/enabled)")

    # Phase 4: Roadmaps (per-repo + global)
    roadmaps = {}
    has_any_roadmap = config.get('roadmap') or any(r.get('roadmap') for r in repo_configs)
    if not args.no_roadmap and has_any_roadmap:
        print(f"\n[Phase 4] Regenerating roadmap SVGs...")
        roadmaps = regenerate_roadmaps(repo_configs, config, output_dir)
        if roadmaps:
            print(f"  Generated {len(roadmaps)} roadmap(s)")
        else:
            print("  No roadmaps generated (check config)")
    else:
        print("\n[Phase 4] Skipping roadmaps")

    # Phase 5: Obsidian markdown
    obsidian_file = ''
    print(f"\n[Phase 5] Generating Obsidian markdown...")
    md_content = generate_report_markdown(
        repo_configs, gitlab_mrs, jira_issues, confluence_pages, roadmaps, config, days
    )

    obsidian_file = write_obsidian_file(md_content, config)
    if obsidian_file:
        print(f"  Written to: {obsidian_file}")
    else:
        # Write to output dir as fallback
        fallback = output_dir / f"{datetime.now().strftime('%Y-%m-%d')}_weekly_report.md"
        fallback.write_text(md_content)
        obsidian_file = str(fallback.resolve())
        print(f"  Written to (fallback): {obsidian_file}")

    # Phase 6: HTML
    print(f"\n[Phase 6] Generating HTML report...")
    html_content = generate_html(
        repo_configs, gitlab_mrs, jira_issues, confluence_pages, roadmaps,
        config, days, report_markdown=md_content, serve_mode=args.serve
    )
    html_path = output_dir / 'report.html'
    html_path.write_text(html_content)
    print(f"  Written to: {html_path}")

    # Phase 7: Serve or open
    if args.serve:
        print(f"\n[Phase 7] Starting local server...")
        start_server(output_dir, obsidian_file, port=args.port)
    elif args.open:
        webbrowser.open(f'file://{html_path}')
        print(f"\n  Opened in browser.")

    print("\nDone!")
    print(f"  Output directory: {output_dir}")
    print(f"  HTML report: {html_path}")
    if obsidian_file:
        print(f"  Obsidian note: {obsidian_file}")


if __name__ == '__main__':
    main()
