#!/usr/bin/env python3
"""
Directory Tree Comparison Tool
Compares two directory trees, prints a terminal summary and writes an HTML
report showing the merged folder tree with sizes, permissions and, for binary
files, MD5 checksums.
"""

import argparse
import os
import sys
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, Set, Tuple

from dotfiles.compare_report import (
    DEFAULT_WORKERS,
    Entry,
    Node,
    STATUS_LABELS,
    build_tree,
    inspect_files,
    render_html,
    scan_tree,
)

class Colors:
    """ANSI color codes for terminal output"""
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

def get_directory_structure(path: str) -> Dict[str, Entry]:
    """Scan a path into {relative path: Entry}; exits if the path does not exist."""
    if not Path(path).is_dir():
        print(f"{Colors.RED}Error: Path '{path}' is not a directory{Colors.RESET}")
        sys.exit(1)
    return scan_tree(path)

def filter_redundant_items(items: Set[str], dirs: Set[str]) -> Set[str]:
    """
    Remove files/subdirs that are already covered by a missing parent directory.
    
    For example, if 'src/' is missing, don't also list 'src/main.py', 'src/utils/', etc.
    """
    def is_covered(item: str) -> bool:
        if item in dirs:
            return True
        parent = os.path.dirname(item)
        while parent:
            if parent in dirs:
                return True
            parent = os.path.dirname(parent)
        return False

    return {item for item in items if not is_covered(item)}

def default_html_path() -> str:
    return f"compare_tree_{datetime.now():%Y%m%d_%H%M%S}.html"


def compare_directories(
    dir1: str, dir2: str, html_path: Optional[str] = None, jobs: int = DEFAULT_WORKERS
) -> bool:
    """
    Compare two directory trees, print the differences and optionally write an
    HTML report to html_path. Returns True when the trees are identical.
    """
    tree = print_comparison(dir1, dir2, jobs)
    if html_path:
        write_html(html_path, render_html(dir1, dir2, tree, "Directory comparison"))
    return is_identical(tree)


def is_identical(tree: Node) -> bool:
    return all(n.status == "same" for n in tree.children.values())


def write_html(html_path: str, content: str) -> None:
    out = Path(html_path)
    out.write_text(content, encoding="utf-8")
    print(f"\n{Colors.BOLD}HTML report:{Colors.RESET} {out.resolve()}")


def print_comparison(dir1: str, dir2: str, jobs: int = DEFAULT_WORKERS) -> Node:
    """Compare two trees, print the differences and return the merged tree."""
    print(f"\n{Colors.BOLD}Comparing Directory Trees{Colors.RESET}")
    print(f"Directory 1: {Colors.BLUE}{dir1}{Colors.RESET}")
    print(f"Directory 2: {Colors.BLUE}{dir2}{Colors.RESET}")
    print("=" * 70)

    # Scan both trees concurrently; the work is I/O bound.
    with ThreadPoolExecutor(max_workers=2) as pool:
        scan1 = pool.submit(get_directory_structure, dir1)
        scan2 = pool.submit(get_directory_structure, dir2)
        entries1, entries2 = scan1.result(), scan2.result()

    inspect_files(dir1, dir2, entries1, entries2, jobs)
    tree = build_tree(dir1, dir2, entries1, entries2)

    def paths(entries: Dict[str, Entry], is_dir: bool) -> Set[str]:
        return {p for p, e in entries.items() if (e.kind == "dir") == is_dir}

    dirs1, dirs2 = paths(entries1, True), paths(entries2, True)
    files1, files2 = paths(entries1, False), paths(entries2, False)

    only_in_dir1_dirs = dirs1 - dirs2
    only_in_dir2_dirs = dirs2 - dirs1
    common_dirs = dirs1 & dirs2
    only_in_dir1_files = files1 - files2
    only_in_dir2_files = files2 - files1
    common_files = files1 & files2

    # Common paths whose type, content or permissions differ, grouped by status.
    # Directories count only for their own permissions; their children are reported separately.
    differing: Dict[str, list] = {}
    stack = list(tree.children.values())
    while stack:
        node = stack.pop()
        stack.extend(node.children.values())
        if node.left and node.right and node.status != "same":
            is_dir = node.left.kind == node.right.kind == "dir"
            if not is_dir or node.left.mode != node.right.mode:
                differing.setdefault(node.status, []).append(node.rel)
    differing = {k: sorted(v) for k, v in differing.items()}

    # Filter out redundant files (those inside missing directories)
    only_in_dir1_files = filter_redundant_items(only_in_dir1_files, only_in_dir1_dirs)
    only_in_dir2_files = filter_redundant_items(only_in_dir2_files, only_in_dir2_dirs)

    print(f"\n{Colors.BOLD}📊 Summary:{Colors.RESET}")
    print(f"  Common files: {len(common_files)}")
    print(f"  Common directories: {len(common_dirs)}")
    print(f"  Unique to dir1: {len(only_in_dir1_files)} files, {len(only_in_dir1_dirs)} directories")
    print(f"  Unique to dir2: {len(only_in_dir2_files)} files, {len(only_in_dir2_dirs)} directories")
    for status, items in differing.items():
        print(f"  {STATUS_LABELS[status]}: {len(items)}")

    if only_in_dir1_dirs:
        print(f"\n{Colors.RED}{Colors.BOLD}📁 Directories only in {dir1}:{Colors.RESET}")
        for directory in sorted(only_in_dir1_dirs):
            print(f"  {Colors.RED}- {directory}/{Colors.RESET}")

    if only_in_dir1_files:
        print(f"\n{Colors.RED}{Colors.BOLD}📄 Files only in {dir1}:{Colors.RESET}")
        for file in sorted(only_in_dir1_files):
            print(f"  {Colors.RED}- {file}{Colors.RESET}")

    if only_in_dir2_dirs:
        print(f"\n{Colors.GREEN}{Colors.BOLD}📁 Directories only in {dir2}:{Colors.RESET}")
        for directory in sorted(only_in_dir2_dirs):
            print(f"  {Colors.GREEN}+ {directory}/{Colors.RESET}")

    if only_in_dir2_files:
        print(f"\n{Colors.GREEN}{Colors.BOLD}📄 Files only in {dir2}:{Colors.RESET}")
        for file in sorted(only_in_dir2_files):
            print(f"  {Colors.GREEN}+ {file}{Colors.RESET}")

    for status, items in differing.items():
        print(f"\n{Colors.YELLOW}{Colors.BOLD}≠ {STATUS_LABELS[status]}:{Colors.RESET}")
        for item in items:
            print(f"  {Colors.YELLOW}~ {item}{Colors.RESET}")

    if is_identical(tree):
        print(f"\n{Colors.GREEN}{Colors.BOLD}✨ Directories are identical!{Colors.RESET}")

    print("\n" + "=" * 70)
    return tree

def add_html_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "-o", "--html", metavar="FILE", help="HTML report path (default: ./compare_tree_<timestamp>.html)"
    )
    parser.add_argument("--no-html", action="store_true", help="Skip writing the HTML report")
    parser.add_argument(
        "-j", "--jobs", type=int, default=DEFAULT_WORKERS,
        help=f"Threads used to read/MD5 files (default: {DEFAULT_WORKERS})",
    )


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser(description="Compare two directory trees.")
    parser.add_argument("dir1")
    parser.add_argument("dir2")
    add_html_args(parser)
    args = parser.parse_args(argv)

    html_path = None if args.no_html else (args.html or default_html_path())
    compare_directories(args.dir1, args.dir2, html_path, args.jobs)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
