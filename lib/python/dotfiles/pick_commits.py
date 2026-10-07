#!/usr/bin/env python3
"""Select and cherry-pick commits from one branch onto another.

Usage:
    pick_commits.py [--source BRANCH] [--destination BRANCH]
                    [--commits SHA[,SHA...]] [--all-authors]
                    [--dry-run] [--no-dedup] [--work-branch BRANCH]

The planning layer is intentionally independent from the optional Textual UI.
"""

from __future__ import annotations

import argparse
import importlib
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any, Callable, Iterable, Optional, Sequence


class GitError(RuntimeError):
    """Raised when a Git command cannot be completed."""

    def __init__(self, args: Sequence[str], message: str) -> None:
        self.args = list(args)
        super().__init__(message)


@dataclass(frozen=True)
class Commit:
    sha: str
    short_sha: str
    subject: str
    author_name: str
    author_email: str
    authored_at: str
    files: tuple[str, ...] = ()


@dataclass
class PickPlan:
    source: str
    destination: str
    base: str
    candidates: list[Commit]
    selected: list[Commit]
    duplicates: dict[str, str] = field(default_factory=dict)
    work_branch: Optional[str] = None
    backup_branch: Optional[str] = None
    limit: Optional[int] = 20


@dataclass(frozen=True)
class ExecutionResult:
    applied: int
    total: int
    work_branch: str
    backup_branch: Optional[str]
    conflicted_sha: Optional[str] = None
    conflicted_files: tuple[str, ...] = ()


class Git:
    """Small, testable wrapper around the Git CLI."""

    def __init__(self, cwd: Optional[Path] = None, verbose: bool = False) -> None:
        self.cwd = cwd
        self.verbose = verbose

    def run(self, *args: str, check: bool = True) -> str:
        command = ["git", *args]
        if self.verbose:
            print("+", " ".join(command), file=sys.stderr)
        result = subprocess.run(
            command,
            cwd=self.cwd,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if check and result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip() or "Git command failed"
            raise GitError(command, f"{detail} ({' '.join(command)})")
        return result.stdout.strip()

    def current_branch(self) -> str:
        branch = self.run("branch", "--show-current")
        if not branch:
            raise GitError(["git", "branch", "--show-current"], "HEAD is detached")
        return branch

    def identity(self) -> tuple[str, str]:
        return self.run("config", "user.name"), self.run("config", "user.email")

    def tracking_branch(self, branch: str) -> Optional[str]:
        value = self.run(
            "rev-parse",
            "--abbrev-ref",
            "--symbolic-full-name",
            f"{branch}@{{upstream}}",
            check=False,
        )
        return value or None

    def branches(self) -> list[str]:
        output = self.run("for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes")
        return [line for line in output.splitlines() if line and not line.endswith("/HEAD")]

    def local_branches(self) -> list[str]:
        output = self.run("for-each-ref", "--format=%(refname:short)", "refs/heads")
        return [line for line in output.splitlines() if line]

    def resolve(self, ref: str) -> str:
        return self.run("rev-parse", "--verify", f"{ref}^{{commit}}")

    def merge_base(self, left: str, right: str) -> str:
        return self.run("merge-base", left, right)

    def is_clean(self) -> bool:
        return not self.run("status", "--porcelain")

    def list_commits(
        self,
        base: str,
        tip: str,
        author: Optional[tuple[str, str]] = None,
        limit: Optional[int] = None,
        skip: int = 0,
    ) -> list[Commit]:
        record_separator = "\x1e"
        field_separator = "\x1f"
        format_string = "%H%x1f%h%x1f%s%x1f%an%x1f%ae%x1f%aI%x1e"
        paging: list[str] = []
        if limit is not None:
            paging.append(f"--max-count={limit}")
        if skip:
            paging.append(f"--skip={skip}")
        output = self.run(
            "log",
            "--no-merges",
            f"--format={format_string}{record_separator}",
            *paging,
            *(self._author_args(author)),
            f"{base}..{tip}",
        )
        commits: list[Commit] = []
        for record in output.split(record_separator):
            fields = record.strip().split(field_separator)
            if len(fields) != 6 or not fields[0]:
                continue
            files = tuple(self.run("diff-tree", "--no-commit-id", "--name-only", "-r", fields[0]).splitlines())
            commits.append(Commit(*fields, files=files))
        commits.reverse()
        return commits

    @staticmethod
    def _author_args(author: Optional[tuple[str, str]]) -> list[str]:
        if not author:
            return []
        name, email = author
        return ["--author=" + name, "--author=" + email]

    def patch_ids(self, revisions: Iterable[str]) -> dict[str, str]:
        result: dict[str, str] = {}
        for sha in revisions:
            patch_id = self.run("show", "--format=", sha, check=False)
            patch_output = subprocess.run(
                ["git", "patch-id", "--stable"],
                cwd=self.cwd,
                input=patch_id,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            if patch_output.returncode == 0 and patch_output.stdout.strip():
                result[sha] = patch_output.stdout.split()[0]
        return result

    def fetch(self, ref: str) -> None:
        remote, branch = ref.split("/", 1)
        self.run("fetch", remote, branch, "--quiet")

    def branch_exists(self, branch: str) -> bool:
        result = subprocess.run(
            ["git", "show-ref", "--verify", "--quiet", f"refs/heads/{branch}"],
            cwd=self.cwd,
        )
        return result.returncode == 0

    def create_branch(self, branch: str, start: str) -> None:
        self.run("branch", branch, start)

    def checkout_new_branch(self, branch: str, start: str) -> None:
        self.run("checkout", "-b", branch, start, "--quiet")

    def cherry_pick(self, sha: str) -> None:
        self.run("cherry-pick", sha)

    def conflicted_files(self) -> tuple[str, ...]:
        return tuple(self.run("diff", "--name-only", "--diff-filter=U", check=False).splitlines())

    def cherry_pick_abort(self) -> None:
        self.run("cherry-pick", "--abort")


def build_plan(
    git: Git,
    source: str,
    destination: str,
    author: Optional[tuple[str, str]],
    deduplicate: bool = True,
    explicit_shas: Optional[Sequence[str]] = None,
    limit: Optional[int] = 20,
) -> PickPlan:
    """Build a non-mutating plan for commits reachable from source but not destination."""
    source_sha = git.resolve(source)
    destination_sha = git.resolve(destination)
    base = git.merge_base(source_sha, destination_sha)
    candidate_limit = None if explicit_shas else limit
    fetched_candidates = git.list_commits(
        base,
        source_sha,
        author,
        candidate_limit + 1 if candidate_limit is not None else None,
    )
    has_more = candidate_limit is not None and len(fetched_candidates) > candidate_limit
    candidates = fetched_candidates[-candidate_limit:] if has_more else fetched_candidates
    destination_commits = git.list_commits(base, destination_sha, None, None)
    destination_pids = git.patch_ids(commit.sha for commit in destination_commits)
    duplicates: dict[str, str] = {}
    available: list[Commit] = []
    for commit in candidates:
        if deduplicate:
            patch_id = git.patch_ids([commit.sha]).get(commit.sha)
            if patch_id and patch_id in destination_pids.values():
                duplicates[commit.sha] = "equivalent patch already exists on destination"
                continue
        available.append(commit)

    if explicit_shas:
        by_sha = {commit.sha: commit for commit in candidates}
        selected = []
        for requested in explicit_shas:
            matches = [sha for sha in by_sha if sha.startswith(requested)]
            if len(matches) != 1:
                raise ValueError(f"Commit is not a unique candidate from {source}: {requested}")
            selected.append(by_sha[matches[0]])
    else:
        selected = available
    return PickPlan(source, destination, base, candidates, selected, duplicates, limit=limit if has_more else None)


def execute_plan(
    git: Git,
    plan: PickPlan,
    work_branch: Optional[str] = None,
    backup: bool = True,
    on_event: Optional[Callable[[str], None]] = None,
) -> ExecutionResult:
    """Create a work branch from destination and cherry-pick the selected commits."""
    if not git.is_clean():
        raise RuntimeError("Working tree is not clean; commit or stash changes first")
    source_name = plan.source.replace("/", "-")
    work_branch = work_branch or f"{source_name}-picked"
    backup_branch = None
    if git.branch_exists(work_branch):
        raise RuntimeError(f"Branch already exists: {work_branch}")
    if backup:
        backup_branch = f"{source_name}-backup-{datetime.now().strftime('%Y%m%d%H%M%S')}"
        git.create_branch(backup_branch, plan.source)
    git.checkout_new_branch(work_branch, plan.destination)
    applied = 0
    for commit in plan.selected:
        if on_event:
            on_event(f"Cherry-picking {commit.short_sha} {commit.subject}")
        try:
            git.cherry_pick(commit.sha)
        except GitError:
            return ExecutionResult(
                applied, len(plan.selected), work_branch, backup_branch,
                commit.sha, git.conflicted_files(),
            )
        applied += 1
    return ExecutionResult(applied, len(plan.selected), work_branch, backup_branch)


def parse_commit_list(value: Optional[str]) -> Optional[list[str]]:
    if not value:
        return None
    return [item for item in (part.strip() for part in value.split(",")) if item]


def current_branch_commits(git: Git, limit: Optional[int]) -> list[Commit]:
    """Return recent commits reachable from the current branch."""
    empty_tree = git.run("hash-object", "-t", "tree", "/dev/null")
    return git.list_commits(empty_tree, "HEAD", None, limit)


def browse_current_branch(git: Git, limit: Optional[int]) -> int:
    """Select current-branch commits, then choose and use a destination branch."""
    branch = git.current_branch()
    commits = current_branch_commits(git, limit)
    root = git.run("rev-list", "--max-parents=0", "HEAD").splitlines()[-1]
    plan = PickPlan(branch, branch, root, commits, list(commits), limit=limit)

    def load_more(new_limit: int) -> PickPlan:
        expanded = current_branch_commits(git, new_limit)
        return PickPlan(branch, branch, root, expanded, list(expanded), limit=new_limit)

    selected = choose_commits_with_tui(plan, load_more)
    if selected is None:
        return 1
    destination = choose_destination_with_tui(git, branch)
    if destination is None:
        return 1
    final_plan = build_plan(
        git,
        branch,
        destination,
        None,
        deduplicate=True,
        explicit_shas=[commit.sha for commit in selected],
        limit=None,
    )
    print_plan(final_plan)
    if not final_plan.selected:
        print("No commits selected.")
        return 0
    result = execute_plan(git, final_plan, backup=True, on_event=print)
    print(f"Applied {result.applied} / {result.total} commit(s) on {result.work_branch}.")
    if result.conflicted_sha:
        print("Cherry-pick stopped on a conflict; resolve it and run 'git cherry-pick --continue'.", file=sys.stderr)
        return 2
    print(f"Push with: git push <remote> {result.work_branch}:{destination}")
    return 0


def print_plan(plan: PickPlan) -> None:
    print(f"Source:      {plan.source}")
    print(f"Destination: {plan.destination}")
    print(f"Candidates:  {len(plan.candidates)}")
    print(f"Selected:    {len(plan.selected)}")
    for commit in plan.candidates:
        marker = "*" if commit in plan.selected else "-"
        reason = f" ({plan.duplicates[commit.sha]})" if commit.sha in plan.duplicates else ""
        print(f" {marker} {commit.short_sha} {commit.subject}{reason}")


def choose_commits_with_tui(
    plan: PickPlan,
    load_more: Callable[[int], PickPlan],
) -> Optional[list[Commit]]:
    """Show the optional commit picker and return commits in display order."""
    try:
        textual_app = importlib.import_module("textual.app")
        textual_widgets = importlib.import_module("textual.widgets")
        textual_selection = importlib.import_module("textual.widgets.selection_list")
    except ImportError:
        print("The Textual UI requires Textual. Install it with: pip install textual", file=sys.stderr)
        return None

    app_base: Any = textual_app.App
    footer: Any = textual_widgets.Footer
    header: Any = textual_widgets.Header
    button: Any = textual_widgets.Button
    selection_list: Any = textual_widgets.SelectionList
    selection: Any = textual_selection.Selection

    class CommitPicker(app_base):
        BINDINGS = [
            ("m", "load_more", "Load 20 more"),
            ("escape", "cancel", "Cancel"),
        ]

        def compose(self) -> Any:
            yield header()
            yield selection_list(
                *(
                    selection(
                        f"{commit.short_sha} {commit.subject}"
                        + (" [already on destination]" if commit.sha in plan.duplicates else ""),
                        commit,
                        False,
                    )
                    for commit in plan.candidates
                )
            )
            yield button("Continue to destination", id="continue")
            yield footer()

        def on_button_pressed(self, event: Any) -> None:
            if event.button.id != "continue":
                return
            selected = list(self.query_one(selection_list).selected)
            if not selected:
                self.notify("Select at least one commit before continuing")
                return
            self.exit(selected)

        def action_load_more(self) -> None:
            if plan.limit is None:
                self.notify("All matching commits are already loaded")
                return
            previous_selection = {commit.sha for commit in self.query_one(selection_list).selected}
            expanded = load_more(len(plan.candidates) + 20)
            plan.candidates = expanded.candidates
            plan.duplicates = expanded.duplicates
            plan.selected = [commit for commit in plan.candidates if commit.sha in previous_selection]
            plan.limit = expanded.limit
            commit_list = self.query_one(selection_list)
            commit_list.clear_options()
            commit_list.add_options(
                selection(
                    f"{commit.short_sha} {commit.subject}"
                    + (" [already on destination]" if commit.sha in plan.duplicates else ""),
                    commit,
                    commit.sha in previous_selection,
                )
                for commit in plan.candidates
            )
            self.notify(f"Loaded {len(plan.candidates)} commits")

        def action_cancel(self) -> None:
            self.exit(None)

    return CommitPicker().run()


def choose_destination_with_tui(git: Git, source: str) -> Optional[str]:
    """Choose a local destination branch after commit selection."""
    try:
        textual_app = importlib.import_module("textual.app")
        textual_widgets = importlib.import_module("textual.widgets")
        textual_selection = importlib.import_module("textual.widgets.selection_list")
    except ImportError:
        print("The Textual UI requires Textual. Install it with: pip install textual", file=sys.stderr)
        return None

    app_base: Any = textual_app.App
    footer: Any = textual_widgets.Footer
    header: Any = textual_widgets.Header
    button: Any = textual_widgets.Button
    selection_list: Any = textual_widgets.SelectionList
    selection: Any = textual_selection.Selection
    branches = [branch for branch in git.local_branches() if branch != source]

    class DestinationPicker(app_base):
        BINDINGS = [("escape", "cancel", "Cancel")]

        def compose(self) -> Any:
            yield header()
            yield selection_list(*(selection(branch, branch, False) for branch in branches))
            yield button("Use selected destination", id="destination")
            yield footer()

        def on_button_pressed(self, event: Any) -> None:
            if event.button.id != "destination":
                return
            selected = list(self.query_one(selection_list).selected)
            if len(selected) != 1:
                self.notify("Select one destination branch")
                return
            self.exit(selected[0])

        def action_cancel(self) -> None:
            self.exit(None)

    if not branches:
        print(f"No destination branches found besides {source}.", file=sys.stderr)
        return None
    return DestinationPicker().run()


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description="Select and cherry-pick commits onto a target branch.")
    result.add_argument("--source", help="Source branch or ref; defaults to the current branch")
    result.add_argument("--destination", "--dest", help="Target branch or ref; defaults to the upstream branch")
    result.add_argument("--commits", help="Comma-separated commit SHAs, in cherry-pick order")
    result.add_argument("--author", help="Author name/email filter; defaults to your Git identity")
    result.add_argument("--all-authors", action="store_true", help="Include commits from every author")
    result.add_argument("--no-dedup", action="store_true", help="Do not skip equivalent patches on the target")
    result.add_argument("--no-backup", action="store_true", help="Do not create a backup branch")
    result.add_argument("--work-branch", help="Branch to create from the destination")
    result.add_argument("--dry-run", action="store_true", help="Show the plan without changing Git state")
    result.add_argument("--tui", action="store_true", help="Choose commits in the optional Textual UI")
    result.add_argument("--limit", type=int, default=20, help="Number of newest commits to load (default: 20)")
    result.add_argument("--all-commits", action="store_true", help="Load every matching commit")
    result.add_argument("--verbose", action="store_true", help="Print Git commands")
    return result


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = parser().parse_args(argv)
    git = Git(verbose=args.verbose)
    try:
        tui_only = args.tui and not any(
            (args.source, args.destination, args.commits, args.author,
             args.all_authors, args.no_dedup, args.no_backup,
             args.work_branch, args.dry_run, args.verbose, args.all_commits)
        ) and args.limit == 20
        if tui_only:
            return browse_current_branch(git, args.limit)
        source = args.source or git.current_branch()
        destination = args.destination or git.tracking_branch(source)
        if not destination:
            raise RuntimeError("No destination supplied and source has no upstream branch")
        author = None
        if not args.all_authors:
            author = (args.author, args.author) if args.author else git.identity()
        limit = None if args.all_commits else args.limit
        if limit is not None and limit < 1:
            raise ValueError("--limit must be greater than zero")
        plan = build_plan(git, source, destination, author, not args.no_dedup, parse_commit_list(args.commits), limit)
        if args.tui:
            def load_more(new_limit: int) -> PickPlan:
                return build_plan(
                    git,
                    source,
                    destination,
                    author,
                    not args.no_dedup,
                    None,
                    new_limit,
                )

            selected = choose_commits_with_tui(plan, load_more)
            if selected is None:
                return 1
            plan.selected = selected
        print_plan(plan)
        if args.dry_run:
            print("Dry run: no changes made.")
            return 0
        if not plan.selected:
            print("No commits selected.")
            return 0
        result = execute_plan(git, plan, args.work_branch, not args.no_backup, print)
        print(f"Applied {result.applied} / {result.total} commit(s) on {result.work_branch}.")
        if result.backup_branch:
            print(f"Backup branch: {result.backup_branch}")
        if result.conflicted_sha:
            print("Cherry-pick stopped on a conflict.", file=sys.stderr)
            print("Resolve files, run 'git add <file>', then 'git cherry-pick --continue'.", file=sys.stderr)
            print("Use 'git cherry-pick --abort' to undo the in-progress pick.", file=sys.stderr)
            return 2
        print(f"Push with: git push <remote> {result.work_branch}:{destination}")
        return 0
    except (GitError, RuntimeError, ValueError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
