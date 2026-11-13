# p10k-gitcache: a Powerlevel10k segment that shows *cached* git status.
#
# Unlike the stock `vcs` segment (gitstatusd), this never scans the work tree while
# rendering the prompt. On each prompt it only:
#   - walks up from $PWD looking for `.git` (a few stat calls),
#   - reads `.git/HEAD` for the current branch/commit,
#   - checks for rebase/merge/... marker files in the git dir,
#   - reads the per-repo cache file written by the last refresh.
# The cached counts are shown together with their age, e.g. "+2 !3 ?1 · 5m ago".
#
# The cache is refreshed (one `git status --porcelain=v2`, in the background, without
# taking index.lock) only:
#   - after you run a command line that invokes git (git, tig, lazygit, gitk, or any
#     alias that expands to them), and
#   - when you run `gstr` (synchronous, prints the result).
#
# Cache files live in ${XDG_CACHE_HOME:-~/.cache}/p10k-gitcache and are shared between
# shells (and hosts, if ~/.cache is on a shared home).
#
# Sourced from ~/.p10k.zsh; the segment name is `gitcache`.

zmodload zsh/datetime 2>/dev/null
autoload -Uz add-zsh-hook

typeset -g  _gitcache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/p10k-gitcache
typeset -g  _gitcache_sep=$'\x1f'
typeset -gi _gitcache_want_refresh=0
typeset -gA _gitcache_inflight        # repo root -> fd of the running background refresh
# Rendered state consumed by the segment via `p10k segment -e/-c` at prompt-render time,
# so a finished background refresh can update the prompt with a plain reset-prompt.
typeset -g  _gitcache_state _gitcache_text

# Sets reply=(workdir gitdir) for the repo containing $PWD; returns 1 if none.
function _gitcache_find_repo() {
  emulate -L zsh -o extended_glob
  reply=()
  local dir=${PWD:A} line
  while true; do
    if [[ -d $dir/.git ]]; then
      reply=($dir $dir/.git)
      return 0
    elif [[ -f $dir/.git ]]; then
      # Worktrees and submodules: `.git` is a file containing "gitdir: <path>".
      IFS= read -r line < $dir/.git 2>/dev/null || return 1
      line=${line#gitdir: }
      [[ $line == /* ]] || line=$dir/$line
      reply=($dir ${line:A})
      return 0
    fi
    [[ $dir == / ]] && return 1
    dir=${dir:h}
  done
}

function _gitcache_file() {
  REPLY=$_gitcache_dir/${1//\//%}
}

function _gitcache_age() {
  local -i s=$1
  if   (( s < 60    )); then REPLY="${s}s ago"
  elif (( s < 3600  )); then REPLY="$(( s / 60 ))m ago"
  elif (( s < 86400 )); then REPLY="$(( s / 3600 ))h ago"
  else                       REPLY="$(( s / 86400 ))d ago"
  fi
}

# Runs `git status` for $1 (workdir) and atomically writes the cache file.
# Format (fields separated by $_gitcache_sep):
#   epoch head oid upstream ahead behind staged unstaged untracked conflicted stashes
function _gitcache_refresh_sync() {
  emulate -L zsh
  local root=$1 REPLY
  _gitcache_file $root
  local file=$REPLY tmp=$REPLY.$$.$RANDOM
  local -i now=$EPOCHSECONDS
  local summary
  [[ -d $_gitcache_dir ]] || mkdir -p -- $_gitcache_dir 2>/dev/null || return 1
  summary=$(GIT_OPTIONAL_LOCKS=0 command git -C $root status --porcelain=v2 --branch \
              --show-stash 2>/dev/null | command awk -v OFS=$_gitcache_sep '
    /^# branch\.oid /      { oid = $3 }
    /^# branch\.head /     { head = $3 }
    /^# branch\.upstream / { up = $3 }
    /^# branch\.ab /       { ahead = substr($3, 2); behind = substr($4, 2) }
    /^# stash /            { stash = $3 }
    /^[12] / { if (substr($2, 1, 1) != ".") st++; if (substr($2, 2, 1) != ".") un++ }
    /^u /    { cf++ }
    /^\? /   { ut++ }
    END { if (head == "") exit 1
          print head, oid, up, ahead+0, behind+0, st+0, un+0, ut+0, cf+0, stash+0 }') || return 1
  print -r -- "$now$_gitcache_sep$summary" > $tmp 2>/dev/null && command mv -f -- $tmp $file
}

function _gitcache_refresh_async() {
  emulate -L zsh
  local root=$1 fd
  (( ${+_gitcache_inflight[$root]} )) && return
  exec {fd}< <(_gitcache_refresh_sync $root; print done)
  _gitcache_inflight[$root]=$fd
  zle -F -w $fd _gitcache_on_refresh_done
}

function _gitcache_on_refresh_done() {
  emulate -L zsh
  local -i fd=$1
  local root
  zle -F $fd
  exec {fd}<&-
  for root in ${(k)_gitcache_inflight}; do
    (( _gitcache_inflight[$root] == fd )) && unset "_gitcache_inflight[$root]"
  done
  _gitcache_compute
  zle .reset-prompt
  zle -R
}
zle -N _gitcache_on_refresh_done

# Computes $_gitcache_state (CLEAN|MODIFIED|UNKNOWN or empty = hidden) and $_gitcache_text.
function _gitcache_compute() {
  emulate -L zsh -o extended_glob
  _gitcache_state= _gitcache_text=
  local -a reply
  _gitcache_find_repo || return
  local root=$reply[1] gitdir=$reply[2]
  [[ -n $POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN &&
     ${(D)root} == ${~POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN} ]] && return

  local meta='%7F' fg='%0F' conflicted='%1F' REPLY
  local head_line branch commit res
  IFS= read -r head_line < $gitdir/HEAD 2>/dev/null
  if [[ $head_line == 'ref: refs/heads/'* ]]; then
    branch=${head_line#ref: refs/heads/}
  else
    commit=$head_line
  fi

  if [[ -n $branch ]]; then
    local b=${(V)branch}
    (( $#b > 32 )) && b[13,-13]="…"
    res+="${fg}${(g::)POWERLEVEL9K_VCS_BRANCH_ICON}${b//\%/%%}"
  else
    res+="${meta}@${fg}${commit[1,8]}"
  fi

  # In-progress operation, detected from marker files (no git invocation).
  local action
  if   [[ -d $gitdir/rebase-merge ]];      then action=rebase-i
  elif [[ -d $gitdir/rebase-apply ]];      then action=rebase
  elif [[ -f $gitdir/MERGE_HEAD ]];        then action=merge
  elif [[ -f $gitdir/CHERRY_PICK_HEAD ]];  then action=cherry-pick
  elif [[ -f $gitdir/REVERT_HEAD ]];       then action=revert
  elif [[ -f $gitdir/BISECT_LOG ]];        then action=bisect
  fi

  _gitcache_file $root
  local line
  local -a c
  if [[ -r $REPLY ]] && IFS= read -r line < $REPLY; then
    c=("${(@ps:$_gitcache_sep:)line}")
  fi
  # c: 1=epoch 2=head 3=oid 4=upstream 5=ahead 6=behind 7=staged 8=unstaged
  #    9=untracked 10=conflicted 11=stashes

  [[ -n $action ]] && res+=" ${conflicted}${action}"

  # Cached counts are only trusted if they were taken on the branch/detached HEAD that is
  # checked out now (HEAD can change without our hook seeing a git command, e.g. from an IDE).
  if (( $#c < 11 )); then
    _gitcache_state=UNKNOWN
    res+=" ${meta}· no status (gstr)"
  elif [[ $c[2] != "${branch:-(detached)}" ]]; then
    _gitcache_age $(( EPOCHSECONDS - c[1] ))
    _gitcache_state=UNKNOWN
    res+=" ${meta}· stale: ${(V)c[2]//\%/%%} ${REPLY}"
  else
    # Show the upstream only if its branch name differs from the local one.
    [[ -n $c[4] && $c[4] != */"$branch" ]] && res+="${meta}:${fg}${(V)c[4]//\%/%%}"
    (( c[6] )) && res+=" ${fg}⇣${c[6]}"
    (( c[5] && !c[6] )) && res+=" "
    (( c[5] )) && res+="${fg}⇡${c[5]}"
    (( c[11] )) && res+=" ${fg}*${c[11]}"
    (( c[10] )) && res+=" ${conflicted}~${c[10]}"
    (( c[7]  )) && res+=" ${fg}+${c[7]}"
    (( c[8]  )) && res+=" ${fg}!${c[8]}"
    (( c[9]  )) && res+=" ${fg}${(g::)POWERLEVEL9K_VCS_UNTRACKED_ICON}${c[9]}"
    if (( c[7] || c[8] || c[9] || c[10] )); then
      _gitcache_state=MODIFIED
    else
      _gitcache_state=CLEAN
    fi
    _gitcache_age $(( EPOCHSECONDS - c[1] ))
    res+=" ${meta}· ${REPLY}"
  fi
  (( ${+_gitcache_inflight[$root]} )) && res+=" ${meta}⟳"

  _gitcache_text=$res
}

function prompt_gitcache() {
  if (( _gitcache_want_refresh )); then
    _gitcache_want_refresh=0
    local -a reply
    _gitcache_find_repo && _gitcache_refresh_async $reply[1]
  fi
  _gitcache_compute
  # One segment per state so that colors also update after an async refresh.
  local state bg
  for state bg in CLEAN 2 MODIFIED 3 UNKNOWN 8; do
    p10k segment -s $state -b $bg -f 0 -e -c "\${(M)_gitcache_state:#$state}" \
      -t '${_gitcache_text}'
  done
}

function _gitcache_preexec() {
  emulate -L zsh -o extended_glob
  # $3 is the command line with aliases expanded.
  local -a words=(${(z)3})
  (( ${words[(I)(git|tig|lazygit|gitk|git-*)]} )) && _gitcache_want_refresh=1
}
add-zsh-hook preexec _gitcache_preexec

# Refresh the cached git status for the current repo now (blocking) and print it.
function gstr() {
  emulate -L zsh
  local -a reply
  _gitcache_find_repo || { print -u2 "gstr: not in a git repository"; return 1; }
  _gitcache_refresh_sync $reply[1] || { print -u2 "gstr: git status failed"; return 1; }
  _gitcache_compute
  print -P -- "${_gitcache_text//\%0F/%f}%f"
}
