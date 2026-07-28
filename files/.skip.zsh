SKIP_HOST="andrew-mac-studio.fitzy.foo"

__skip_reset_terminal() {
  # Disable mouse-reporting modes left enabled by remote TUIs (tmux, vim, etc.)
  # when the SSH/ET connection drops uncleanly (e.g. after hibernate).
  printf '\033[?1000l\033[?1002l\033[?1003l\033[?1006l'
}

__skip_generate_name() {
  local -a adjectives nouns
  adjectives=(bold swift calm bright dark wild quick quiet sharp deep clear warm cold fast keen wise brave true fair strong)
  nouns=(canyon ember forge river stone ridge storm frost coast peak field grove shore vale creek mist dusk dawn tide gale)
  local adj noun
  adj=${adjectives[$((RANDOM % ${#adjectives[@]} + 1))]}
  noun=${nouns[$((RANDOM % ${#nouns[@]} + 1))]}
  echo "${adj}-${noun}"
}

skip() {
  local session_name=""
  local use_ssh=false
  local list_sessions=false
  local host="$SKIP_HOST"

  while (( $# )); do
    case "$1" in
      --ssh)           use_ssh=true ;;
      --list-sessions) list_sessions=true ;;
      --host)
        if [[ -z "$2" ]]; then
          echo "skip: --host requires a hostname" >&2
          return 1
        fi
        host="$2"
        shift
        ;;
      --host=*)
        host="${1#--host=}"
        if [[ -z "$host" ]]; then
          echo "skip: --host requires a hostname" >&2
          return 1
        fi
        ;;
      --help)
        cat <<EOF
Usage: skip [session] [options]

Connect to a named tmux session on a remote host (default: $SKIP_HOST).
Attaches to an existing session or creates a new one.
New sessions start in ~/workspace.

Arguments:
  session              Session name to attach or create.
                       If omitted, a friendly name is auto-generated.

Options:
  --host HOST          Connect to HOST instead of $SKIP_HOST.
  --list-sessions      List active tmux sessions on the host.
  --ssh                Use SSH instead of EternalTerminal.
  --help               Show this help message.

Examples:
  skip                 Auto-create a session (e.g. swift-ember)
  skip my-project      Attach to or create session "my-project"
  skip --list-sessions List all active sessions
  skip my-project --ssh  Connect via SSH instead of et
  skip --host other.fitzy.foo  Connect to a different machine
EOF
        return 0
        ;;
      *)
        if [[ -z "$session_name" ]]; then
          session_name="$1"
        fi
        ;;
    esac
    shift
  done

  local is_local=false
  [[ "$(hostname -s)" == "${host%%.*}" ]] && is_local=true

  if [[ "$list_sessions" == "true" ]]; then
    if [[ "$is_local" == "true" ]]; then
      tmux ls 2>/dev/null || echo "No active tmux sessions."
    else
      ssh $host "tmux ls 2>/dev/null || echo 'No active tmux sessions.'" 2>/dev/null
    fi
    return
  fi

  if [[ -z "$session_name" ]]; then
    session_name=$(__skip_generate_name)
  fi

  printf '\033]1;%s\007' "$session_name"

  local tmux_cmd="tmux attach-session -t '${session_name}' 2>/dev/null || tmux new-session -s '${session_name}' -c ~/workspace"

  if [[ "$is_local" == "true" ]]; then
    tmux attach-session -t "$session_name" 2>/dev/null || tmux new-session -s "$session_name" -c ~/workspace
  elif [[ "$use_ssh" == "true" ]]; then
    TERM=xterm-256color ssh -t $host "$tmux_cmd"
    __skip_reset_terminal
  else
    TERM=xterm-256color et $host:2022 -c "$tmux_cmd"
    __skip_reset_terminal
  fi
}

_skip() {
  local -a opts sessions
  local host="$SKIP_HOST"

  # Pick up an explicit --host from the words already typed.
  local i
  for (( i = 2; i < CURRENT; i++ )); do
    case "${words[i]}" in
      --host)   [[ -n "${words[i+1]}" ]] && host="${words[i+1]}" ;;
      --host=*) host="${words[i]#--host=}" ;;
    esac
  done

  # The word right after --host is a hostname, not a session.
  if [[ "${words[CURRENT-1]}" == "--host" ]]; then
    _hosts
    return
  fi

  local is_local=false
  [[ "$(hostname -s)" == "${host%%.*}" ]] && is_local=true

  opts=('--host:Connect to a different host' '--list-sessions:List active tmux sessions on the host' '--ssh:Use SSH instead of EternalTerminal' '--help:Show help message')

  if [[ "$words[CURRENT]" == -* ]]; then
    _describe 'option' opts
    return
  fi

  local pos=0 skip_next=false
  for word in "${words[@]:1:$((CURRENT-2))}"; do
    if [[ "$skip_next" == "true" ]]; then
      skip_next=false
      continue
    fi
    [[ "$word" == "--host" ]] && skip_next=true
    [[ "$word" != --* ]] && ((pos++))
  done

  if (( pos == 0 )); then
    if [[ "$is_local" == "true" ]]; then
      sessions=(${(f)"$(tmux ls -F '#{session_name}' 2>/dev/null)"})
    else
      sessions=(${(f)"$(ssh $host "tmux ls -F '#{session_name}' 2>/dev/null" 2>/dev/null)"})
    fi
    _describe 'session' sessions
  fi
}

compdef _skip skip
