#!/usr/bin/env python3
"""MCP server wrapper for the weekly work report generator.

Exposes the data-collection and report-composition functions from
``generate_work_report.py`` as Model Context Protocol tools, so an MCP-capable
client (Copilot, Claude Desktop, etc.) can pull GitLab / Jira / Confluence
activity and summarize it inline — instead of the copy/paste HTML workflow.

The original CLI (``generate_work_report.py``) is unchanged and still handles the
scheduled, on-disk Obsidian/HTML artifact generation. This wrapper only reuses
its collection functions.

Requirements:
    pip install "mcp[cli]" pyyaml requests

Run standalone (stdio transport):
    python3 work_report_mcp.py --config /path/to/config.yaml

Register in an MCP client (example ``mcp.json`` entry):
    {
      "servers": {
        "work-report": {
          "command": "python3",
                    "args": [
                        "/absolute/path/to/sbin/work_report_mcp.py",
                        "--config",
                        "/path/to/config.yaml"
                    ]
        }
      }
    }
"""

import argparse
import contextlib
import importlib.util
import sys
from pathlib import Path

try:
    from mcp.server.fastmcp import FastMCP
except ImportError:
    sys.exit(
        'ERROR: The MCP SDK is required. Install with: pip install "mcp[cli]"'
    )


# ─── Import the sibling CLI module by path (filename is import-safe) ──────────
_MODULE_PATH = Path(__file__).resolve().parent / "generate_work_report.py"
_spec = importlib.util.spec_from_file_location("generate_work_report", _MODULE_PATH)
gwr = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gwr)


mcp = FastMCP("work-report")
SERVER_CONFIG_PATH: str | None = None


@contextlib.contextmanager
def _quiet_stdout():
    """Redirect the collectors' progress prints to stderr.

    The collection functions print progress to stdout; on an MCP stdio transport
    stdout carries the JSON-RPC protocol, so anything else there corrupts it.
    """
    with contextlib.redirect_stdout(sys.stderr):
        yield


def _load(config_path: str | None) -> dict:
    """Load and env-expand the work-report config."""
    path = Path(config_path or SERVER_CONFIG_PATH or gwr.DEFAULT_CONFIG_PATH).expanduser()
    with _quiet_stdout():
        return gwr.load_config(path)


def _output_dir(config: dict) -> Path:
    output_dir = Path(config["output_dir"]).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    return output_dir


@mcp.tool()
def get_config_status(config_path: str | None = None) -> dict:
    """Report which data sources are configured and enabled.

    Args:
        config_path: Optional path to the work-report config YAML. Defaults to
            ``~/.config/work-report/config.yaml``.

    Returns:
        A summary of the default look-back window, output directory, configured
        repos, and which of GitLab / Jira / Confluence are available.
    """
    config = _load(config_path)
    return {
        "days_default": config.get("days", 7),
        "output_dir": str(_output_dir(config)),
        "repos": [r.get("name") for r in config.get("repos", [])],
        "gitlab_configured": bool(config.get("gitlab", {}).get("base_url")),
        "jira_configured": bool(config.get("atlassian", {}).get("base_url")),
        "confluence_enabled": bool(config.get("confluence", {}).get("enabled")),
    }


@mcp.tool()
def get_gitlab_activity(days: int = 7, config_path: str | None = None) -> list:
    """Collect GitLab merge requests, commits, and diffs from the last N days.

    Args:
        days: Number of days to look back (default 7).
        config_path: Optional path to the work-report config YAML.

    Returns:
        A list of merge-request records including title, state, notes, commits,
        and diff content.
    """
    config = _load(config_path)
    if not config.get("gitlab", {}).get("base_url"):
        return []
    with _quiet_stdout():
        return gwr.query_gitlab_mrs(config, days, _output_dir(config))


@mcp.tool()
def get_jira_issues(days: int = 7, config_path: str | None = None) -> list:
    """Collect Jira issues updated in the last N days.

    Args:
        days: Number of days to look back (default 7).
        config_path: Optional path to the work-report config YAML.

    Returns:
        A list of Jira issue records.
    """
    config = _load(config_path)
    if not config.get("atlassian", {}).get("base_url"):
        return []
    with _quiet_stdout():
        return gwr.query_jira(config, days)


@mcp.tool()
def get_confluence_pages(days: int = 7, config_path: str | None = None) -> list:
    """Collect Confluence pages created or updated in the last N days.

    Args:
        days: Number of days to look back (default 7).
        config_path: Optional path to the work-report config YAML.

    Returns:
        A list of Confluence page records.
    """
    config = _load(config_path)
    if not config.get("confluence", {}).get("enabled"):
        return []
    with _quiet_stdout():
        return gwr.query_confluence(config, days)


@mcp.tool()
def generate_report(days: int = 7, config_path: str | None = None) -> str:
    """Collect all configured sources and return the composed report markdown.

    This mirrors the CLI's markdown output but does NOT write to the Obsidian
    vault or serve HTML — it returns the markdown string so the calling model can
    summarize or transform it inline.

    Args:
        days: Number of days to look back (default 7).
        config_path: Optional path to the work-report config YAML.

    Returns:
        The report markdown as a single string.
    """
    config = _load(config_path)
    output_dir = _output_dir(config)

    with _quiet_stdout():
        repo_configs = gwr.collect_repo_configs(config.get("repos", []))

        gitlab_mrs = []
        if config.get("gitlab", {}).get("base_url"):
            gitlab_mrs = gwr.query_gitlab_mrs(config, days, output_dir)

        jira_issues = []
        if config.get("atlassian", {}).get("base_url"):
            jira_issues = gwr.query_jira(config, days)
            for repo in repo_configs:
                if repo.get("epics"):
                    repo["_epics_detail"] = gwr.fetch_epics(repo["epics"], config)

        confluence_pages = []
        if config.get("confluence", {}).get("enabled"):
            confluence_pages = gwr.query_confluence(config, days)

        roadmaps = {}
        has_roadmap = config.get("roadmap") or any(
            r.get("roadmap") for r in repo_configs
        )
        if has_roadmap:
            roadmaps = gwr.regenerate_roadmaps(repo_configs, config, output_dir)

        return gwr.generate_report_markdown(
            repo_configs, gitlab_mrs, jira_issues, confluence_pages,
            roadmaps, config, days,
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run the work-report MCP server.")
    parser.add_argument(
        "--config",
        metavar="PATH",
        help="Default work-report YAML configuration path for all tools.",
    )
    arguments = parser.parse_args()
    SERVER_CONFIG_PATH = arguments.config
    mcp.run()
