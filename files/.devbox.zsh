DEVBOX_HOST="dev-vm.fitzy.foo"

__devbox_list_worktrees() {
  local repo_name="$1"
  local prefix
  prefix=$(ssh $DEVBOX_HOST "echo ~/workspace/${repo_name}/" 2>/dev/null)
  ssh $DEVBOX_HOST "git -C ~/workspace/${repo_name}/.bare worktree list" 2>/dev/null \
    | awk '{print $1}' \
    | while read -r wt_path; do
        [[ "$wt_path" == */".bare" ]] && continue
        echo "${wt_path#$prefix}"
      done
}

__devbox_cleanup_worktrees() {
  local repo_name="$1"
  local force="$2"
  local debug="$3"
  local fuck_it="$4"
  local bare="~/workspace/${repo_name}/.bare"

  # Verify bare repo exists
  if ! ssh $DEVBOX_HOST "test -d ${bare}" 2>/dev/null; then
    echo "Error: bare repo not found for '${repo_name}'." >&2
    return 1
  fi

  # Detect default branch
  local default_branch
  default_branch=$(ssh $DEVBOX_HOST "git -C ${bare} symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'")
  [[ -z "$default_branch" ]] && default_branch="main"

  # Fetch latest with prune
  echo "Fetching latest from origin..."
  ssh $DEVBOX_HOST "git -C ${bare} fetch origin --prune" 2>/dev/null

  echo "Cleaning up worktrees for ${repo_name} (default branch: ${default_branch})"
  echo ""

  local worktrees
  worktrees=$(__devbox_list_worktrees "$repo_name")

  if [[ -z "$worktrees" ]]; then
    echo "No worktrees found."
    return 0
  fi

  local removed=0
  local skipped=0

  while read -r wt; do
    [[ -z "$wt" ]] && continue
    [[ "$wt" == "$default_branch" ]] && continue

    local wt_path="~/workspace/${repo_name}/${wt}"
    local session_name="${repo_name}-${wt}"
    local skip_reasons=()

    # Check for active tmux connection (idle > 1h is considered stale)
    local active_clients=$(ssh $DEVBOX_HOST "
      now=\$(date +%s)
      tmux list-clients -t '${session_name}' -F '#{client_activity}' 2>/dev/null \
        | while read -r ts; do
            [ \$(( now - ts )) -lt 3600 ] && echo active
          done
    " </dev/null 2>/dev/null)
    [[ "$debug" == "true" ]] && echo "  [debug] ${wt}: active_clients=${active_clients:-none}"
    if [[ "$fuck_it" != "true" && -n "$active_clients" ]]; then
      skip_reasons+=("active session")
    fi

    if [[ "$force" != "true" && "$fuck_it" != "true" ]]; then
      # Check dirty working tree
      local status_output=$(ssh $DEVBOX_HOST "git -C ${wt_path} status --porcelain" </dev/null 2>/dev/null)
      [[ "$debug" == "true" && -n "$status_output" ]] && echo "  [debug] ${wt}: dirty files:\n${status_output}"
      if [[ -n "$status_output" ]]; then
        skip_reasons+=("uncommitted changes")
      fi

      # Check for unpushed commits (git cherry handles squash merges)
      local unpushed=$(ssh $DEVBOX_HOST "git -C ${bare} cherry origin/${default_branch} ${wt} 2>/dev/null | grep '^+'" </dev/null 2>/dev/null)
      if [[ "$debug" == "true" && -n "$unpushed" ]]; then
        local unpushed_log=$(ssh $DEVBOX_HOST "git -C ${bare} cherry origin/${default_branch} ${wt} 2>/dev/null | grep '^+' | cut -d' ' -f2 | xargs -I{} git -C ${bare} log -1 --format='%h %s' {}" </dev/null 2>/dev/null)
        echo "  [debug] ${wt}: unpushed:\n${unpushed_log}"
      fi
      if [[ -n "$unpushed" ]]; then
        skip_reasons+=("unpushed commits")
      fi
    fi

    if [[ ${#skip_reasons[@]} -gt 0 ]]; then
      printf "  %-8s %s (%s)\n" "SKIP" "$wt" "${(j:, :)skip_reasons}"
      ((skipped++))
    else
      ssh $DEVBOX_HOST "tmux kill-session -t '${session_name}'" </dev/null 2>/dev/null
      local force_flag=""
      [[ "$force" == "true" || "$fuck_it" == "true" ]] && force_flag="--force"
      ssh $DEVBOX_HOST "cd ${bare} && git worktree remove ${force_flag} ../${wt}" </dev/null 2>/dev/null
      ssh $DEVBOX_HOST "git -C ${bare} branch -D ${wt}" </dev/null &>/dev/null
      printf "  %-8s %s\n" "REMOVED" "$wt"
      ((removed++))
    fi
  done <<< "$worktrees"

  echo ""
  echo "Done: ${removed} removed, ${skipped} skipped."
}

__devbox_init_bare_repo() {
  local repo_name="$1"

  echo -n "Git remote URL for ${repo_name}: " >&2
  local git_url
  read -r git_url
  if [[ -z "$git_url" ]]; then
    echo "Aborted: no URL provided." >&2
    return 1
  fi

  echo "Cloning bare repo..." >&2
  ssh $DEVBOX_HOST "git clone --bare '${git_url}' ~/workspace/${repo_name}/.bare" || return 1

  echo "Configuring fetch refspec..." >&2
  ssh $DEVBOX_HOST "git -C ~/workspace/${repo_name}/.bare config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'"
  ssh $DEVBOX_HOST "git -C ~/workspace/${repo_name}/.bare fetch origin" >&2

  local default_branch
  default_branch=$(ssh $DEVBOX_HOST "git -C ~/workspace/${repo_name}/.bare symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'")
  [[ -z "$default_branch" ]] && default_branch="main"

  echo "Creating initial worktree: ${default_branch}" >&2
  ssh $DEVBOX_HOST "cd ~/workspace/${repo_name}/.bare && git worktree add ../${default_branch} ${default_branch}" >&2

  echo "$default_branch"
}

__devbox_create_worktree() {
  local repo_name="$1"
  local worktree_name="$2"
  local bare="~/workspace/${repo_name}/.bare"

  local wt_dir="~/workspace/${repo_name}/${worktree_name}"

  if ssh $DEVBOX_HOST "git -C ${bare} show-ref --verify --quiet refs/remotes/origin/${worktree_name}" 2>/dev/null; then
    echo "Creating worktree from remote branch: ${worktree_name}" >&2
    ssh $DEVBOX_HOST "cd ${bare} && git worktree add ../${worktree_name} ${worktree_name}" >&2
    ssh $DEVBOX_HOST "git -C ${wt_dir} branch --set-upstream-to=origin/${worktree_name} ${worktree_name}" >&2
    echo "Pulling latest changes..." >&2
    ssh $DEVBOX_HOST "git -C ${wt_dir} pull --rebase" >&2
  elif ssh $DEVBOX_HOST "git -C ${bare} show-ref --verify --quiet refs/heads/${worktree_name}" 2>/dev/null; then
    echo "Creating worktree from local branch: ${worktree_name}" >&2
    ssh $DEVBOX_HOST "cd ${bare} && git worktree add ../${worktree_name} ${worktree_name}" >&2
    echo "Pushing branch to origin..." >&2
    ssh $DEVBOX_HOST "git -C ${wt_dir} push --set-upstream origin ${worktree_name}" >&2
  else
    local default_branch
    default_branch=$(ssh $DEVBOX_HOST "git -C ${bare} symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'")
    [[ -z "$default_branch" ]] && default_branch="main"
    echo "Creating new branch '${worktree_name}' from '${default_branch}'" >&2
    ssh $DEVBOX_HOST "cd ${bare} && git worktree add -b ${worktree_name} ../${worktree_name} ${default_branch}" >&2
    echo "Pushing branch to origin..." >&2
    ssh $DEVBOX_HOST "git -C ${wt_dir} push --set-upstream origin ${worktree_name}" >&2
  fi

  # Initialize submodules if present
  if ! ssh $DEVBOX_HOST "git -C ${wt_dir} submodule update --init --recursive" >&2 2>&1; then
    echo "Warning: submodule init failed — continuing without submodules." >&2
  fi
}

__devbox_pick_worktree() {
  local repo_name="$1"

  if ! command -v fzf >/dev/null; then
    echo "Error: fzf is required for interactive worktree selection." >&2
    return 1
  fi

  local worktrees
  worktrees=$(__devbox_list_worktrees "$repo_name")

  local selection
  selection=$(printf '%s\n%s' "$worktrees" "+ Create new worktree" \
    | fzf --prompt="Select worktree: " --height=~50% --reverse)

  if [[ -z "$selection" ]]; then
    echo "Aborted." >&2
    return 1
  fi

  if [[ "$selection" == "+ Create new worktree" ]]; then
    echo -n "New worktree name: " >&2
    local new_name
    read -r new_name
    if [[ -z "$new_name" ]]; then
      echo "Aborted: no name provided." >&2
      return 1
    fi
    __devbox_create_worktree "$repo_name" "$new_name" || return 1
    echo "$new_name"
  else
    echo "$selection"
  fi
}

__devbox_connect() {
  local session_name="$1"
  local workspace_dir="$2"
  local use_ssh="$3"

  printf '\033]1;%s\007' "$session_name"

  if [[ "$use_ssh" == "true" ]]; then
    if ssh $DEVBOX_HOST "tmux has-session -t '$session_name'" 2>/dev/null; then
      ssh -t $DEVBOX_HOST "tmux attach -t '$session_name'"
    else
      ssh -t $DEVBOX_HOST "cd $workspace_dir && tmux new -s '$session_name' \; split-window -v"
    fi
  else
    if ssh $DEVBOX_HOST "tmux has-session -t '$session_name'" 2>/dev/null; then
      et $DEVBOX_HOST:2022 -c "tmux attach -t '$session_name'"
    else
      et $DEVBOX_HOST:2022 -c "cd $workspace_dir && tmux new -s '$session_name' \; split-window -v"
    fi
  fi
}

devbox() {
  local repo_name=""
  local worktree_name=""
  local cleanup=false
  local force=false
  local fuck_it=false
  local debug=false
  local use_ssh=false

  for arg in "$@"; do
    case "$arg" in
      --cleanup) cleanup=true ;;
      --force)   force=true ;;
      --fuck-it) fuck_it=true ;;
      --debug)   debug=true ;;
      --ssh)     use_ssh=true ;;
      *)
        if [[ -z "$repo_name" ]]; then
          repo_name="$arg"
        elif [[ -z "$worktree_name" ]]; then
          worktree_name="$arg"
        fi
        ;;
    esac
  done

  if [[ "$force" == "true" && "$cleanup" != "true" ]]; then
    echo "Error: --force can only be used with --cleanup." >&2
    return 1
  fi

  if [[ "$fuck_it" == "true" && "$cleanup" != "true" ]]; then
    echo "Error: --fuck-it can only be used with --cleanup." >&2
    return 1
  fi

  if [[ "$debug" == "true" && "$cleanup" != "true" ]]; then
    echo "Error: --debug can only be used with --cleanup." >&2
    return 1
  fi

  if [[ "$cleanup" == "true" && -z "$repo_name" ]]; then
    echo "Error: --cleanup requires a repo name." >&2
    return 1
  fi

  if [[ "$cleanup" == "true" ]]; then
    __devbox_cleanup_worktrees "$repo_name" "$force" "$debug" "$fuck_it"
    return
  fi

  if [[ -z "$repo_name" ]]; then
    printf '\033]1;devbox\007'
    if [[ "$use_ssh" == "true" ]]; then
      ssh -t $DEVBOX_HOST "cd ~/workspace && tmux new \; split-window -v"
    else
      et $DEVBOX_HOST:2022 -c "cd ~/workspace && tmux new \; split-window -v"
    fi
    return
  fi

  # Ensure bare repo exists
  if ! ssh $DEVBOX_HOST "test -d ~/workspace/${repo_name}/.bare" 2>/dev/null; then
    worktree_name=$(__devbox_init_bare_repo "$repo_name") || return 1
  fi

  # Select worktree
  if [[ -z "$worktree_name" ]]; then
    worktree_name=$(__devbox_pick_worktree "$repo_name") || return 1
  fi

  # Ensure worktree directory exists
  if ! ssh $DEVBOX_HOST "test -d ~/workspace/${repo_name}/${worktree_name}" 2>/dev/null; then
    __devbox_create_worktree "$repo_name" "$worktree_name" || return 1
  fi

  __devbox_connect "${repo_name}-${worktree_name}" "~/workspace/${repo_name}/${worktree_name}" "$use_ssh"
}

_devbox() {
  local -a opts repos worktrees
  local repo_name=""

  # Extract repo_name from existing args (skip flags)
  for word in "${words[@]:1}"; do
    [[ "$word" != --* && "$word" != "$words[CURRENT]" ]] && { repo_name="$word"; break; }
  done

  # Count positional args before cursor
  local pos=0
  for word in "${words[@]:1:$((CURRENT-2))}"; do
    [[ "$word" != --* ]] && ((pos++))
  done

  # Flags - always available
  opts=('--cleanup:Clean up stale worktrees' '--force:Force cleanup, ignore uncommitted/unpushed' '--fuck-it:Nuclear cleanup, even kill active sessions' '--debug:Show debug output during cleanup' '--ssh:Use SSH instead of EternalTerminal')

  if [[ "$words[CURRENT]" == -* ]]; then
    _describe 'option' opts
    return
  fi

  if (( pos == 0 )); then
    # Complete repo names
    repos=(${(f)"$(ssh $DEVBOX_HOST "ls -d ~/workspace/*/.bare 2>/dev/null | xargs -I{} dirname {} | xargs -I{} basename {}" 2>/dev/null)"})
    _describe 'repository' repos
  elif (( pos == 1 )) && [[ -n "$repo_name" ]]; then
    # Complete worktree names
    worktrees=(${(f)"$(__devbox_list_worktrees "$repo_name")"})
    _describe 'worktree' worktrees
  fi
}

compdef _devbox devbox
