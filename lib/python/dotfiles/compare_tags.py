#!/usr/bin/env python3
"""
Compare two WG server tags, e.g. `compare-tags ic/tensorflow@tf_2-17-0_20261018 ic/tensorflow@tf_2-17-0_20261002`.

A tag maps to one version per VCO (aok/aaw/soa/...). Each `project@tag` is resolved via
`cm_tag` to $WG_SERVER/<project>/exports.<version>, and directories are compared per
matching VCO using compare_tree. Plain paths are passed through.
"""

import argparse
import os
import shutil
import subprocess
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from dotfiles.compare_tree import Colors, add_html_args, compare_directories, default_html_path

CM_TAG = "/usr/mgc/bin/cm_tag"


def vco_of(version: str) -> str:
    """'v2.17.0_2026-10-02_engr-aok' -> 'aok'."""
    return version.rsplit("-", 1)[-1]


def resolve_versions(project: str, tag: str) -> Dict[str, str]:
    """Return {vco: version} for a tag in $MGC_SERVER."""
    cm_tag = shutil.which("cm_tag") or CM_TAG
    try:
        result = subprocess.run(
            [cm_tag, "list", tag, project, "-mgc_server"],
            capture_output=True,
            text=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        detail = getattr(exc, "stderr", "") or str(exc)
        raise ValueError(f"cm_tag failed for {project}@{tag}: {detail.strip()}") from exc

    versions: Dict[str, str] = {}
    in_tag = False
    for line in result.stdout.splitlines():
        parts = line.split()
        if not parts or line.startswith("-"):
            continue
        # Extra VCOs for a tag are listed on indented continuation lines with no tag name.
        if len(parts) >= 2:
            in_tag = parts[0] == tag
            version = parts[1]
        else:
            version = parts[0]
        if in_tag:
            versions[vco_of(version)] = version

    if not versions:
        raise ValueError(f"Tag '{tag}' not found for project '{project}'")
    return versions


def resolve_spec(spec: str) -> Dict[Optional[str], str]:
    """Turn `project@tag` into {vco: exports dir}; a plain path becomes {None: path}."""
    if "@" not in spec:
        return {None: spec}

    project, _, tag = spec.rpartition("@")
    if not project or not tag:
        raise ValueError(f"Invalid spec '{spec}', expected <project>@<tag>")

    wg_server = os.environ.get("WG_SERVER")
    if not wg_server:
        raise ValueError("$WG_SERVER is not set")

    dirs: Dict[Optional[str], str] = {}
    for vco, version in resolve_versions(project, tag).items():
        path = Path(wg_server) / project / f"exports.{version}"
        if not path.is_dir():
            raise ValueError(f"{spec} [{vco}] resolved to {path}, which does not exist")
        dirs[vco] = str(path)
    return dirs


def pair_by_vco(
    left: Dict[Optional[str], str],
    right: Dict[Optional[str], str],
    wanted: List[str],
) -> List[Tuple[str, str, str]]:
    """Return [(vco label, left_dir, right_dir)] for VCOs present on both sides."""
    if None in left or None in right:
        # Plain path on one side: the other side must narrow to a single VCO.
        def single(side: Dict[Optional[str], str], name: str) -> str:
            candidates = {v: p for v, p in side.items() if not wanted or v in wanted}
            if len(candidates) != 1:
                raise ValueError(
                    f"{name} resolves to multiple VCOs {sorted(str(v) for v in side)}; pick one with --vco"
                )
            return next(iter(candidates.values()))

        return [("", single(left, "left"), single(right, "right"))]

    common = sorted(set(left) & set(right))
    if wanted:
        missing = [v for v in wanted if v not in common]
        if missing:
            raise ValueError(f"VCO(s) {missing} not present on both sides (common: {common})")
        common = [v for v in common if v in wanted]

    return [(vco, left[vco], right[vco]) for vco in common]


def print_vco_summary(
    left_spec: str,
    right_spec: str,
    left: Dict[Optional[str], str],
    right: Dict[Optional[str], str],
    compared: List[str],
) -> None:
    only_left = sorted(set(left) - set(right))
    only_right = sorted(set(right) - set(left))
    print(f"\n{Colors.BOLD}VCO summary{Colors.RESET}")
    print(f"  Compared: {', '.join(compared) or 'none'}")
    if only_left:
        print(f"  {Colors.RED}Only in {left_spec}: {', '.join(only_left)}{Colors.RESET}")
    if only_right:
        print(f"  {Colors.GREEN}Only in {right_spec}: {', '.join(only_right)}{Colors.RESET}")
    if not (only_left or only_right):
        print(f"  {Colors.GREEN}Both sides define the same VCOs.{Colors.RESET}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare two WG server tags per VCO.")
    parser.add_argument("left", help="<project>@<tag> or directory")
    parser.add_argument("right", help="<project>@<tag> or directory")
    parser.add_argument(
        "--vco", action="append", default=[], help="Only compare this VCO (repeatable), e.g. aok"
    )
    add_html_args(parser)
    args = parser.parse_args()

    try:
        left, right = resolve_spec(args.left), resolve_spec(args.right)
        pairs = pair_by_vco(left, right, args.vco)
    except ValueError as exc:
        print(f"{Colors.RED}Error: {exc}{Colors.RESET}")
        return 1

    base = Path(args.html or default_html_path())
    for vco, dir1, dir2 in pairs:
        if vco:
            print(f"\n{Colors.BOLD}{Colors.YELLOW}##### VCO: {vco} #####{Colors.RESET}")
        # One report per VCO so each tree stays readable.
        html_path = base.with_name(f"{base.stem}_{vco}{base.suffix}") if vco else base
        compare_directories(dir1, dir2, None if args.no_html else str(html_path), args.jobs)

    if None not in left and None not in right:
        print_vco_summary(args.left, args.right, left, right, [p[0] for p in pairs])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
