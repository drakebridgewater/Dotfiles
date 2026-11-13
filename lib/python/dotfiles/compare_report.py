"""
Scanning, comparison and HTML rendering for compare_tree.

Each side of a comparison is scanned into {relative path: Entry}. Common files are
classified (text vs binary), binary files get an MD5, and the merged result is
rendered as a collapsible folder-tree HTML report.
"""

import codecs
import difflib
import hashlib
import html
import os
import stat
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, List, Optional, Tuple

SNIFF_BYTES = 8192
HASH_CHUNK = 1 << 20
DEFAULT_WORKERS = min(32, (os.cpu_count() or 4) * 4)
MAX_DIFF_BYTES = 512 * 1024
MAX_DIFF_LINES = 400

# File/dir comparison outcomes, in the order they appear in the report legend.
STATUS_LABELS = {
    "same": "Identical",
    "changed": "Content differs",
    "mode": "Permissions differ",
    "type": "Type differs",
    "unreadable": "Unreadable",
    "left": "Only in left",
    "right": "Only in right",
}


@dataclass
class Entry:
    """One filesystem object found while scanning a tree."""

    kind: str  # 'file', 'dir', 'link' or 'other'
    size: int = 0
    mode: int = 0
    target: str = ""
    error: str = ""
    binary: bool = False
    md5: str = ""


@dataclass
class Node:
    """A path in the merged tree of both sides."""

    name: str
    rel: str
    left: Optional[Entry] = None
    right: Optional[Entry] = None
    status: str = "same"
    diff: str = ""
    children: Dict[str, "Node"] = field(default_factory=dict)


def scan_tree(root: str) -> Dict[str, Entry]:
    """Walk root without following symlinks; keys are '/'-separated relative paths."""
    entries: Dict[str, Entry] = {}
    pending: List[Tuple[str, str]] = [(root, "")]
    while pending:
        current, prefix = pending.pop()
        try:
            with os.scandir(current) as it:
                children = list(it)
        except OSError as exc:
            if prefix:
                entries[prefix.rstrip("/")].error = str(exc)
            continue
        for child in children:
            rel = prefix + child.name
            try:
                st = child.stat(follow_symlinks=False)
            except OSError as exc:
                entries[rel] = Entry("other", error=str(exc))
                continue
            if stat.S_ISLNK(st.st_mode):
                try:
                    target = os.readlink(child.path)
                except OSError:
                    target = "?"
                entries[rel] = Entry("link", st.st_size, st.st_mode, target)
            elif stat.S_ISDIR(st.st_mode):
                entries[rel] = Entry("dir", 0, st.st_mode)
                pending.append((child.path, rel + "/"))
            elif stat.S_ISREG(st.st_mode):
                entries[rel] = Entry("file", st.st_size, st.st_mode)
            else:
                entries[rel] = Entry("other", st.st_size, st.st_mode)
    return entries


def inspect_file(path: str, entry: Entry, need_md5: bool) -> None:
    """Classify a file as text/binary and compute its MD5 when binary or requested."""
    try:
        with open(path, "rb") as fh:
            head = fh.read(SNIFF_BYTES)
            entry.binary = looks_binary(head)
            if not (entry.binary or need_md5):
                return
            digest = hashlib.md5(head)
            for chunk in iter(lambda: fh.read(HASH_CHUNK), b""):
                digest.update(chunk)
            entry.md5 = digest.hexdigest()
    except OSError as exc:
        entry.error = str(exc)


def looks_binary(head: bytes) -> bool:
    if b"\0" in head:
        return True
    try:
        codecs.getincrementaldecoder("utf-8")().decode(head, final=False)
    except UnicodeDecodeError:
        return True
    return False


def inspect_files(
    left_root: str,
    right_root: str,
    left: Dict[str, Entry],
    right: Dict[str, Entry],
    workers: int = DEFAULT_WORKERS,
) -> None:
    """Fill in binary/md5/error for every regular file on both sides (threaded, I/O bound)."""
    jobs = []
    for root, side, other_side in ((left_root, left, right), (right_root, right, left)):
        for rel, entry in side.items():
            if entry.kind == "file":
                other = other_side.get(rel)
                same_size = other is not None and other.kind == "file" and other.size == entry.size
                jobs.append((os.path.join(root, rel), entry, same_size))

    # Biggest files first so one large file isn't left running alone at the end.
    jobs.sort(key=lambda job: job[1].size, reverse=True)

    done = 0
    lock = threading.Lock()
    show_progress = sys.stderr.isatty() and len(jobs) > 200

    def run(job: Tuple[str, Entry, bool]) -> None:
        nonlocal done
        inspect_file(*job)
        if show_progress:
            with lock:
                done += 1
                if done % 50 == 0 or done == len(jobs):
                    print(f"\rHashing/inspecting files: {done}/{len(jobs)}", end="", file=sys.stderr)

    # hashlib releases the GIL on large buffers, so threads scale for hashing too.
    with ThreadPoolExecutor(max_workers=max(1, workers)) as pool:
        list(pool.map(run, jobs))
    if show_progress:
        print(file=sys.stderr)


def text_diff(left_path: str, right_path: str) -> str:
    """Unified diff of two small text files, truncated for display."""
    try:
        with open(left_path, encoding="utf-8", errors="replace") as lf:
            lines1 = lf.read(MAX_DIFF_BYTES).splitlines()
        with open(right_path, encoding="utf-8", errors="replace") as rf:
            lines2 = rf.read(MAX_DIFF_BYTES).splitlines()
    except OSError:
        return ""
    out = list(difflib.unified_diff(lines1, lines2, "left", "right", lineterm="", n=2))
    if len(out) > MAX_DIFF_LINES:
        out = out[:MAX_DIFF_LINES] + [f"... diff truncated at {MAX_DIFF_LINES} lines"]
    return "\n".join(out)


def classify_pair(left: Entry, right: Entry) -> str:
    if left.kind != right.kind:
        return "type"
    if left.kind == "file":
        if left.error or right.error:
            return "unreadable"
        if left.size != right.size:
            content_same = False
        elif left.md5 and right.md5:
            content_same = left.md5 == right.md5
        else:
            content_same = False
        if not content_same:
            return "changed"
    elif left.kind == "link":
        if left.target != right.target:
            return "changed"
    elif left.kind == "other" and (left.error or right.error):
        return "unreadable"
    if stat.S_IMODE(left.mode) != stat.S_IMODE(right.mode):
        return "mode"
    return "same"


def build_tree(
    left_root: str, right_root: str, left: Dict[str, Entry], right: Dict[str, Entry]
) -> Node:
    """Merge both scans into one tree and compute a status for every node."""
    root = Node("", "")
    for rel in sorted(set(left) | set(right)):
        node = root
        parts = rel.split("/")
        for depth, part in enumerate(parts):
            sub = "/".join(parts[: depth + 1])
            node = node.children.setdefault(part, Node(part, sub))
        node.left, node.right = left.get(rel), right.get(rel)

    def settle(node: Node) -> None:
        for child in node.children.values():
            settle(child)
        if node.left is None:
            node.status = "right"
        elif node.right is None:
            node.status = "left"
        else:
            node.status = classify_pair(node.left, node.right)
            if node.status == "changed" and node.left.kind == node.right.kind == "file":
                if not (node.left.binary or node.right.binary):
                    node.diff = text_diff(
                        os.path.join(left_root, node.rel), os.path.join(right_root, node.rel)
                    )
            if node.left.kind == "dir" and node.right.kind == "dir":
                kids = [c.status for c in node.children.values()]
                if any(s != "same" for s in kids):
                    node.status = "changed"

    settle(root)
    return root


def count_statuses(root: Node) -> Dict[str, Dict[str, int]]:
    """Return {'files': {status: n}, 'dirs': {status: n}} over the whole tree."""
    counts: Dict[str, Dict[str, int]] = {"files": {}, "dirs": {}}

    def walk(node: Node) -> None:
        for child in node.children.values():
            entry = child.left or child.right
            bucket = counts["dirs"] if entry and entry.kind == "dir" else counts["files"]
            bucket[child.status] = bucket.get(child.status, 0) + 1
            walk(child)

    walk(root)
    return counts


def human_size(size: int) -> str:
    value = float(size)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if value < 1024 or unit == "TB":
            return f"{int(value)} B" if unit == "B" else f"{value:.1f} {unit}"
        value /= 1024
    return f"{size} B"


def render_side(entry: Optional[Entry]) -> str:
    """Size and permission cells for one side."""
    if entry is None:
        return '<span class="size">-</span><span class="perm">-</span>'
    size = "" if entry.kind == "dir" else human_size(entry.size)
    title = f' title="{entry.size:,} bytes"' if entry.kind == "file" else ""
    perm = f"{stat.filemode(entry.mode)} {stat.S_IMODE(entry.mode):04o}" if entry.mode else "?"
    return f'<span class="size"{title}>{size}</span><span class="perm">{perm}</span>'


def render_md5(node: Node) -> str:
    sides = (("L", node.left), ("R", node.right))
    if not any(e is not None and e.binary for _, e in sides):
        return '<span class="md5"></span>'
    parts = [f"<code>{tag} {e.md5}</code>" for tag, e in sides if e is not None and e.md5]
    return f'<span class="md5">{"<br>".join(parts)}</span>'


def render_node(node: Node, depth: int, out: List[str]) -> None:
    entry = node.left or node.right
    assert entry is not None
    esc = html.escape
    is_dir = entry.kind == "dir"
    name = esc(node.name) + ("/" if is_dir else "")
    notes = []
    if entry.kind == "link":
        notes.append(f'<span class="note">&rarr; {esc(entry.target)}</span>')
    if node.left and node.right and node.left.kind == "link" and node.left.target != node.right.target:
        notes = [
            f'<span class="note">&rarr; {esc(node.left.target)} | {esc(node.right.target)}</span>'
        ]
    if node.left and node.right and node.left.kind != node.right.kind:
        notes.append(f'<span class="note">{node.left.kind} vs {node.right.kind}</span>')
    errors = [e.error for e in (node.left, node.right) if e is not None and e.error]
    if errors:
        notes.append(f'<span class="note err">{esc("; ".join(errors))}</span>')
    if not is_dir and any(e.binary for e in (node.left, node.right) if e is not None):
        notes.append('<span class="badge bin">binary</span>')

    row = (
        f'<span class="name" style="--d:{depth}">{name}{"".join(notes)}</span>'
        f'<span class="status s-{node.status}">{status_label(node, is_dir)}</span>'
        f"{render_side(node.left)}{render_side(node.right)}{render_md5(node)}"
    )
    attrs = f'data-status="{node.status}" data-name="{esc(node.rel.lower())}"'
    if is_dir:
        open_attr = " open" if node.status != "same" and depth < 3 else ""
        out.append(f'<details class="dir"{open_attr} {attrs}><summary class="row">{row}</summary>')
        for child in sorted(node.children.values(), key=lambda n: (not is_dir_node(n), n.name)):
            render_node(child, depth + 1, out)
        out.append("</details>")
    elif node.diff:
        out.append(
            f'<details class="file" {attrs}><summary class="row">{row}</summary>'
            f'<pre class="diff">{render_diff(node.diff)}</pre></details>'
        )
    else:
        out.append(f'<div class="row file" {attrs}>{row}</div>')


def status_label(node: Node, is_dir: bool) -> str:
    if is_dir and node.status == "changed":
        return "Contains differences"
    return STATUS_LABELS[node.status]


def is_dir_node(node: Node) -> bool:
    entry = node.left or node.right
    return entry is not None and entry.kind == "dir"


def render_diff(text: str) -> str:
    lines = []
    for line in text.split("\n"):
        cls = ""
        if line.startswith("+") and not line.startswith("+++"):
            cls = "add"
        elif line.startswith("-") and not line.startswith("---"):
            cls = "del"
        elif line.startswith("@@"):
            cls = "hunk"
        lines.append(f'<span class="{cls}">{html.escape(line)}</span>')
    return "\n".join(lines)


CSS = """
:root { color-scheme: light dark; --bg:#fff; --fg:#1f2328; --muted:#6e7781; --line:#d8dee4;
  --left:#cf222e; --right:#1a7f37; --changed:#9a6700; --mode:#8250df; --same:#6e7781; }
@media (prefers-color-scheme: dark) { :root { --bg:#0d1117; --fg:#e6edf3; --muted:#8b949e;
  --line:#30363d; --left:#ff7b72; --right:#56d364; --changed:#e3b341; --mode:#d2a8ff; --same:#8b949e; } }
body { background:var(--bg); color:var(--fg); margin:0; padding:1rem 1.5rem;
  font:13px/1.4 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; }
h1 { font-size:18px; margin:0 0 .5rem; }
.roots { color:var(--muted); margin-bottom:.75rem; }
.roots b { color:var(--fg); }
.nav { margin:.5rem 0; } .nav a { margin-right:.75rem; }
.section-title { font-size:16px; margin:1.5rem 0 .25rem; padding-top:.5rem; border-top:2px solid var(--line); }
.toolbar { display:flex; flex-wrap:wrap; gap:.5rem 1rem; align-items:center; margin:.75rem 0; }
.toolbar label { cursor:pointer; user-select:none; }
.toolbar input[type=search] { padding:3px 6px; min-width:16rem; background:var(--bg); color:var(--fg);
  border:1px solid var(--line); border-radius:4px; }
.toolbar button { background:none; color:var(--fg); border:1px solid var(--line); border-radius:4px;
  padding:2px 8px; cursor:pointer; }
.summary { display:flex; flex-wrap:wrap; gap:.5rem; margin:.5rem 0; }
.card { border:1px solid var(--line); border-radius:6px; padding:.3rem .7rem; }
.card b { font-size:15px; }
.row { display:grid; align-items:baseline; gap:0 .75rem;
  grid-template-columns:minmax(18rem,1fr) 10rem 5.5rem 11rem 5.5rem 11rem 20rem;
  padding:1px 4px; border-bottom:1px solid transparent; }
.row:hover { background:rgba(128,128,128,.12); }
.head { position:sticky; top:0; background:var(--bg); font-weight:bold; border-bottom:1px solid var(--line);
  padding-top:4px; padding-bottom:4px; z-index:2; }
summary.row { cursor:pointer; list-style:none; }
summary.row::-webkit-details-marker { display:none; }
details.dir > summary .name::before { content:"\\25B8 "; color:var(--muted); }
details.dir[open] > summary .name::before { content:"\\25BE "; }
.name { padding-left:calc(var(--d,0) * 1.4rem); overflow-wrap:anywhere; }
.size { text-align:right; } .perm { color:var(--muted); white-space:nowrap; }
.md5 code { font-size:11px; color:var(--muted); }
.note { color:var(--muted); margin-left:.6rem; } .note.err { color:var(--left); }
.badge { border:1px solid var(--line); border-radius:8px; font-size:10px; padding:0 5px; margin-left:.5rem; }
.status { font-weight:bold; font-size:12px; }
.s-same { color:var(--same); font-weight:normal; } .s-left { color:var(--left); } .s-right { color:var(--right); }
.s-changed,.s-unreadable,.s-type { color:var(--changed); } .s-mode { color:var(--mode); }
[data-status=left] > .row, .row[data-status=left] { background:rgba(207,34,46,.08); }
[data-status=right] > .row, .row[data-status=right] { background:rgba(26,127,55,.08); }
pre.diff { margin:2px 0 6px calc(1.4rem); padding:6px; border:1px solid var(--line); border-radius:4px;
  overflow:auto; max-height:28rem; }
pre.diff .add { color:var(--right); display:block; } pre.diff .del { color:var(--left); display:block; }
pre.diff .hunk { color:var(--mode); display:block; }
.hide-same .row.file[data-status=same], .hide-same details[data-status=same] { display:none; }
.hide-changed .file[data-status=changed], .hide-mode .file[data-status=mode],
.hide-type .file[data-status=type], .hide-unreadable .file[data-status=unreadable],
.hide-left .file[data-status=left], .hide-right .file[data-status=right] { display:none; }
.nomatch { display:none !important; }
"""

JS = """
const body = document.body;
document.querySelectorAll('input[data-filter]').forEach(cb => {
  const apply = () => body.classList.toggle('hide-' + cb.dataset.filter, !cb.checked);
  cb.addEventListener('change', apply); apply();
});
const dirs = () => document.querySelectorAll('details.dir');
document.getElementById('expand').onclick = () => dirs().forEach(d => d.open = true);
document.getElementById('collapse').onclick = () => dirs().forEach(d => d.open = false);
document.getElementById('search').addEventListener('input', e => {
  const q = e.target.value.trim().toLowerCase();
  const items = document.querySelectorAll('[data-name]');
  items.forEach(el => el.classList.remove('nomatch'));
  if (!q) return;
  items.forEach(el => {
    if (el.matches('details.dir')) return;
    el.classList.toggle('nomatch', !el.dataset.name.includes(q));
  });
  Array.from(dirs()).reverse().forEach(d => {
    const hit = d.querySelector('[data-name]:not(.nomatch):not(details.dir)') ||
      d.dataset.name.includes(q);
    d.classList.toggle('nomatch', !hit);
    if (hit) d.open = true;
  });
});
"""


def render_section(left_root: str, right_root: str, root: Node, label: str = "") -> str:
    """Summary cards and merged tree for one comparison; label becomes a section heading."""
    counts = count_statuses(root)
    esc = html.escape
    cards = []
    for key, name in (("files", "files"), ("dirs", "directories")):
        total = sum(counts[key].values())
        detail = ", ".join(
            f"{STATUS_LABELS[s].lower()}: {n}" for s, n in sorted(counts[key].items()) if s != "same"
        )
        same = counts[key].get("same", 0)
        cards.append(
            f'<div class="card"><b>{total}</b> {name} &mdash; identical: {same}'
            f'{"; " + detail if detail else ""}</div>'
        )

    body: List[str] = []
    for child in sorted(root.children.values(), key=lambda n: (not is_dir_node(n), n.name)):
        render_node(child, 0, body)

    heading = f'<h2 class="section-title">{esc(label)}</h2>' if label else ""
    return (
        f'<section class="cmp" id="{esc(_anchor(label))}">{heading}\n'
        f'<div class="roots">Left: <b>{esc(left_root)}</b><br>Right: <b>{esc(right_root)}</b></div>\n'
        f'<div class="summary">{"".join(cards)}</div>\n'
        f'{chr(10).join(body)}\n</section>'
    )


def _anchor(label: str) -> str:
    return "cmp-" + "".join(c if c.isalnum() else "-" for c in label) if label else "cmp"


def render_page(title: str, sections: List[str], labels: Optional[List[str]] = None) -> str:
    """Wrap one or more rendered sections in a single HTML document with shared controls."""
    esc = html.escape
    filters = "".join(
        f'<label><input type="checkbox" data-filter="{key}" checked> '
        f'<span class="status s-{key}">{label}</span></label>'
        for key, label in STATUS_LABELS.items()
    )
    nav = ""
    if labels and len(labels) > 1:
        links = " ".join(f'<a href="#{esc(_anchor(l))}">{esc(l)}</a>' for l in labels)
        nav = f'<div class="nav">Jump to: {links}</div>\n'

    stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    heading = esc(title or "Directory comparison")
    return f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>{heading}</title>
<style>{CSS}</style></head>
<body>
<h1>{heading}</h1>
<div class="roots">Generated {stamp}.
Binary (non-text) files show an MD5 for each side; text files are compared by content.</div>
{nav}<div class="toolbar">{filters}
<input type="search" id="search" placeholder="Filter by path...">
<button id="expand">Expand all</button><button id="collapse">Collapse all</button></div>
<div class="row head"><span class="name">Name</span><span>Status</span>
<span class="size">L size</span><span>L perms</span><span class="size">R size</span><span>R perms</span>
<span>MD5 (binary files)</span></div>
{chr(10).join(sections)}
<script>{JS}</script>
</body></html>
"""


def render_html(left_root: str, right_root: str, root: Node, title: str = "") -> str:
    return render_page(title, [render_section(left_root, right_root, root)])
