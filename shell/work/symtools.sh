#!/bin/bash
# ---------------------------------------------------------------------------
# symtools.sh - linker symbol archaeology (fast paths)
# ---------------------------------------------------------------------------

: "${SYM_JOBS:=$(nproc 2>/dev/null || echo 8)}"
: "${SYM_BATCH:=64}"
: "${SYM_INDEX:=${TMPDIR:-/tmp}/$USER-symindex}"

# Prefer llvm-nm: typically 2-5x faster than GNU nm on large archives.
: "${SYM_NM:=$(command -v llvm-nm || command -v nm)}"

# Directories that never contain build artifacts - pruning these is most of
# the find() cost on a big source tree.
_sym_find() {
  local root="${1:-.}"
  find "$root" -xdev \
    \( -name .git -o -name Isrc -o -name Dsrc -o -name doc \
       -o -name systests -o -name exports -o -name '*.dSYM' \) -prune -o \
    \( -name '*.a' -o -name '*.so' -o -name '*.so.*' \) -type f -print0
}

# ---------------------------------------------------------------------------
# Direct scan: batched + parallel. Note -F (fixed string) and NO -C:
# mangled names contain the identifier literally, so demangling during the
# scan is pure waste. We demangle only the matching lines at the end.
# ---------------------------------------------------------------------------
whodefines() {
  local pat="$1" root="${2:-.}"
  [[ -z "$pat" ]] && { echo "usage: whodefines <symbol> [root]" >&2; return 2; }
  local key; key=$(echo "$root" | md5sum | cut -c1-12)
  # If this root was already indexed, querying it beats rescanning.
  [[ -s "$SYM_INDEX.$key.txt" ]] && { symq "$pat" "$root"; return; }
  _sym_find "$root" \
    | xargs -0 -P"$SYM_JOBS" -n"$SYM_BATCH" \
        "$SYM_NM" -A --defined-only 2>/dev/null \
    | grep -F -- "$pat" \
    | c++filt
}

whoneeds() {
  local pat="$1" root="${2:-.}"
  [[ -z "$pat" ]] && { echo "usage: whoneeds <symbol> [root]" >&2; return 2; }
  local key; key=$(echo "$root" | md5sum | cut -c1-12)
  [[ -s "$SYM_INDEX.$key.needs.txt" ]] && { symn "$pat" "$root"; return; }
  _sym_find "$root" \
    | xargs -0 -P"$SYM_JOBS" -n"$SYM_BATCH" \
        "$SYM_NM" -A -u 2>/dev/null \
    | grep -F -- "$pat" \
    | c++filt
}

# ---------------------------------------------------------------------------
# Index: pay once, query forever. ~seconds to build per GB of archives,
# then every lookup is a grep over a local file. A single un-filtered nm
# pass gives us both defined and undefined symbols; posix format's 3rd
# field is always the type column ("U" = undefined), so we split that one
# pass into a defines index and a needs index for free.
# ---------------------------------------------------------------------------
symindex() {
  local root="${1:-.}"
  local key; key=$(echo "$root" | md5sum | cut -c1-12)
  local idx="$SYM_INDEX.$key.txt"
  local nidx="$SYM_INDEX.$key.needs.txt"

  mkdir -p "$(dirname "$SYM_INDEX")"
  echo "indexing $root -> $idx / $nidx" >&2
  : > "$idx"; : > "$nidx"
  _sym_find "$root" \
    | xargs -0 -P"$SYM_JOBS" -n"$SYM_BATCH" \
        "$SYM_NM" -A --format=posix 2>/dev/null \
    | awk -v idx="$idx" -v nidx="$nidx" \
        '{ if ($3 == "U") print >> nidx; else print >> idx }'
  touch "$SYM_INDEX.$key.stamp"
  printf 'indexed %s definitions, %s references\n' \
    "$(wc -l < "$idx")" "$(wc -l < "$nidx")" >&2
  echo "$idx"
}

# symq <pattern> [root] - query the defines index, building it if absent
symq() {
  local pat="$1" root="${2:-.}"
  local key; key=$(echo "$root" | md5sum | cut -c1-12)
  local idx="$SYM_INDEX.$key.txt"
  [[ -s "$idx" ]] || symindex "$root" >/dev/null
  if command -v rg >/dev/null; then
    rg -F --no-config -- "$pat" "$idx" | c++filt
  else
    grep -F -- "$pat" "$idx" | c++filt
  fi
}

# symn <pattern> [root] - query the needs (undefined-symbol) index
symn() {
  local pat="$1" root="${2:-.}"
  local key; key=$(echo "$root" | md5sum | cut -c1-12)
  local nidx="$SYM_INDEX.$key.needs.txt"
  [[ -s "$nidx" ]] || symindex "$root" >/dev/null
  if command -v rg >/dev/null; then
    rg -F --no-config -- "$pat" "$nidx" | c++filt
  else
    grep -F -- "$pat" "$nidx" | c++filt
  fi
}

# Refresh only archives rebuilt since the last index (incremental)
symindex_update() {
  local root="${1:-.}"
  local key; key=$(echo "$root" | md5sum | cut -c1-12)
  local idx="$SYM_INDEX.$key.txt" nidx="$SYM_INDEX.$key.needs.txt"
  local stamp="$SYM_INDEX.$key.stamp"
  [[ -f "$stamp" ]] || { symindex "$root"; return; }
  
  # verify files exist before attempting incremental update
  [[ -f "$idx" ]] || { symindex "$root"; return; }
  [[ -f "$nidx" ]] || { symindex "$root"; return; }
  [[ -f "$stamp" ]] || { symindex "$root"; return; }

  local changed; changed=$(mktemp)
  find "$root" -xdev \( -name '*.a' -o -name '*.so' \) -type f \
       -newer "$stamp" -print0 > "$changed"
  [[ -s "$changed" ]] || { echo "index up to date" >&2; rm -f "$changed"; return; }

  # drop stale entries for changed libs, then re-scan just those
  local libs; libs=$(tr '\0' '\n' < "$changed")
  grep -v -F -f <(echo "$libs") "$idx" > "$idx.new"
  grep -v -F -f <(echo "$libs") "$nidx" > "$nidx.new"
  xargs -0 -P"$SYM_JOBS" -n"$SYM_BATCH" \
        "$SYM_NM" -A --format=posix < "$changed" 2>/dev/null \
    | awk -v idx="$idx.new" -v nidx="$nidx.new" \
        '{ if ($3 == "U") print >> nidx; else print >> idx }'
  mv "$idx.new" "$idx"
  mv "$nidx.new" "$nidx"
  touch "$stamp"
  rm -f "$changed"
}

# Scan only what a given link command consumed (fastest, most precise)
symlink_scan() {
  local log="$1" target="$2" pat="$3"
  grep -m1 -- "-o $target" "$log" | tr ' ' '\n' | grep -E '\.(a|so)$' \
    | xargs -r "$SYM_NM" -A --defined-only 2>/dev/null \
    | grep -F -- "$pat" | c++filt
}