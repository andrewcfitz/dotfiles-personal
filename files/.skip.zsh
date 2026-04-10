SKIP_HOST="andrew-mac-studio.fitzy.foo"

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

  for arg in "$@"; do
    case "$arg" in
      --ssh)           use_ssh=true ;;
      --list-sessions) list_sessions=true ;;
      *)
        if [[ -z "$session_name" ]]; then
          session_name="$arg"
        fi
        ;;
    esac
  done

  local is_local=false
  [[ "$(hostname -s)" == "${SKIP_HOST%%.*}" ]] && is_local=true

  if [[ "$list_sessions" == "true" ]]; then
    if [[ "$is_local" == "true" ]]; then
      tmux ls 2>/dev/null || echo "No active tmux sessions."
    else
      ssh $SKIP_HOST "tmux ls 2>/dev/null || echo 'No active tmux sessions.'" 2>/dev/null
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
    ssh -t $SKIP_HOST "$tmux_cmd"
  else
    et $SKIP_HOST:2022 -c "$tmux_cmd"
  fi
}

_skip() {
  local -a opts sessions
  local is_local=false
  [[ "$(hostname -s)" == "${SKIP_HOST%%.*}" ]] && is_local=true

  opts=('--list-sessions:List active tmux sessions on Mac Studio' '--ssh:Use SSH instead of EternalTerminal')

  if [[ "$words[CURRENT]" == -* ]]; then
    _describe 'option' opts
    return
  fi

  local pos=0
  for word in "${words[@]:1:$((CURRENT-2))}"; do
    [[ "$word" != --* ]] && ((pos++))
  done

  if (( pos == 0 )); then
    if [[ "$is_local" == "true" ]]; then
      sessions=(${(f)"$(tmux ls -F '#{session_name}' 2>/dev/null)"})
    else
      sessions=(${(f)"$(ssh $SKIP_HOST "tmux ls -F '#{session_name}' 2>/dev/null" 2>/dev/null)"})
    fi
    _describe 'session' sessions
  fi
}

compdef _skip skip
