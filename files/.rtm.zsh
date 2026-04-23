__rtm_reset_terminal() {
  # Disable mouse-reporting modes left enabled by remote TUIs (tmux, vim, etc.)
  # when the connection drops uncleanly (e.g. after hibernate).
  printf '\033[?1000l\033[?1002l\033[?1003l\033[?1006l'
}

__rtm_generate_name() {
  local -a adjectives nouns
  adjectives=(bold swift calm bright dark wild quick quiet sharp deep clear warm cold fast keen wise brave true fair strong)
  nouns=(canyon ember forge river stone ridge storm frost coast peak field grove shore vale creek mist dusk dawn tide gale)
  local adj noun
  adj=${adjectives[$((RANDOM % ${#adjectives[@]} + 1))]}
  noun=${nouns[$((RANDOM % ${#nouns[@]} + 1))]}
  echo "${adj}-${noun}"
}

rtm() {
  local host=""
  local session_name=""
  local transport="et"
  local list_sessions=false

  for arg in "$@"; do
    case "$arg" in
      --ssh)           transport="ssh" ;;
      --mosh)          transport="mosh" ;;
      --et)            transport="et" ;;
      --list-sessions) list_sessions=true ;;
      --help)
        cat <<'EOF'
Usage: rtm <host> [session] [options]

Connect to a named tmux session on a remote host.
Attaches to an existing session or creates a new one.
New sessions start in ~/workspace.

Arguments:
  host                 Remote host to connect to (required).
                       For --et, append ":port" to override the default (2022).
                       For --ssh/--mosh, configure non-default ports in ~/.ssh/config.
  session              Session name to attach or create.
                       If omitted, a friendly name is auto-generated.

Options:
  --et                 Use EternalTerminal (default).
  --ssh                Use SSH as the transport.
  --mosh               Use mosh as the transport.
  --list-sessions      List active tmux sessions on the host.
  --help               Show this help message.

Examples:
  rtm studio.foo                    Auto-create a session via et
  rtm studio.foo my-project         Attach to or create "my-project" via et
  rtm studio.foo --ssh              Use SSH instead
  rtm studio.foo proj --mosh        Attach to "proj" via mosh
  rtm studio.foo --list-sessions    List all active sessions
EOF
        return 0
        ;;
      -*)
        echo "rtm: unknown option: $arg" >&2
        return 1
        ;;
      *)
        if [[ -z "$host" ]]; then
          host="$arg"
        elif [[ -z "$session_name" ]]; then
          session_name="$arg"
        fi
        ;;
    esac
  done

  if [[ -z "$host" ]]; then
    echo "rtm: missing host. Try: rtm --help" >&2
    return 1
  fi

  local bare_host="${host%%:*}"
  local is_local=false
  [[ "$(hostname -s)" == "${bare_host%%.*}" ]] && is_local=true

  if [[ "$list_sessions" == "true" ]]; then
    if [[ "$is_local" == "true" ]]; then
      tmux ls 2>/dev/null || echo "No active tmux sessions."
    else
      ssh "$bare_host" "tmux ls 2>/dev/null || echo 'No active tmux sessions.'" 2>/dev/null
    fi
    return
  fi

  if [[ -z "$session_name" ]]; then
    session_name=$(__rtm_generate_name)
  fi

  printf '\033]1;%s\007' "$session_name"

  local tmux_cmd="tmux attach-session -t '${session_name}' 2>/dev/null || tmux new-session -s '${session_name}' -c ~/workspace"

  if [[ "$is_local" == "true" ]]; then
    tmux attach-session -t "$session_name" 2>/dev/null || tmux new-session -s "$session_name" -c ~/workspace
    return
  fi

  case "$transport" in
    ssh)
      TERM=xterm-256color ssh -t "$bare_host" "$tmux_cmd"
      __rtm_reset_terminal
      ;;
    mosh)
      TERM=xterm-256color mosh "$bare_host" -- sh -c "$tmux_cmd"
      __rtm_reset_terminal
      ;;
    et)
      TERM=xterm-256color et "$host" -c "$tmux_cmd"
      __rtm_reset_terminal
      ;;
  esac
}
