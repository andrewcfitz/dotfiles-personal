#!/usr/bin/env bash
# Claude Code status line - inspired by Starship/Dracula prompt
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Colors (ANSI)
purple='\033[38;2;189;147;249m'
cyan='\033[38;2;139;233;253m'
pink='\033[38;2;255;121;198m'
green='\033[38;2;80;250;123m'
comment='\033[38;2;98;114;164m'
yellow='\033[38;2;241;250;140m'
orange='\033[38;2;255;184;108m'
coral='\033[38;2;255;110;110m'
reset='\033[0m'

# Shorten path: replace $HOME with ~, truncate to last 3 segments
if [ -n "$cwd" ]; then
  short_dir="${cwd/#$HOME/~}"
  # Keep last 3 path components
  dir_parts=$(echo "$short_dir" | tr '/' '\n' | tail -3 | tr '\n' '/')
  dir_parts="${dir_parts%/}"
  # If path was longer than 3 parts, prefix with …/
  part_count=$(echo "$short_dir" | tr -cd '/' | wc -c)
  [ "$part_count" -gt 3 ] && dir_parts=".../$dir_parts"
else
  dir_parts="~"
fi

# Git branch and status
git_info=""
if git -C "${cwd:-$HOME}" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "${cwd:-$HOME}" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "${cwd:-$HOME}" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    [ ${#branch} -gt 20 ] && branch="${branch:0:20}…"
    git_flags=""
    porcelain=$(git -C "${cwd:-$HOME}" --no-optional-locks status --porcelain 2>/dev/null)
    echo "$porcelain" | grep -q '^[MARC]'   && git_flags="${git_flags}+"   # staged
    echo "$porcelain" | grep -qE '^ M|^.M'  && git_flags="${git_flags}!"   # modified
    echo "$porcelain" | grep -q '^??'        && git_flags="${git_flags}?"   # untracked
    echo "$porcelain" | grep -qE '^ D|^.D'  && git_flags="${git_flags}✘"   # deleted
    git -C "${cwd:-$HOME}" --no-optional-locks stash list 2>/dev/null | grep -q . && git_flags="${git_flags}\$"  # stashed
    ahead=$(git -C "${cwd:-$HOME}" --no-optional-locks rev-list --count @{upstream}..HEAD 2>/dev/null)
    behind=$(git -C "${cwd:-$HOME}" --no-optional-locks rev-list --count HEAD..@{upstream} 2>/dev/null)
    [ "${ahead:-0}" -gt 0 ]  && git_flags="${git_flags}⇡"
    [ "${behind:-0}" -gt 0 ] && git_flags="${git_flags}⇣"
    git_info=" ${pink} ${branch}${git_flags:+ ${git_flags}}${reset}"
  fi
fi

# Context remaining
ctx_info=""
if [ -n "$remaining_pct" ]; then
  remaining_int=$(printf '%.0f' "$remaining_pct")
  if [ "$remaining_int" -le 20 ]; then
    ctx_color='\033[38;2;255;85;85m'
  elif [ "$remaining_int" -le 50 ]; then
    ctx_color='\033[38;2;241;250;140m'
  else
    ctx_color="$green"
  fi
  ctx_info=" ${ctx_color}ctx:${remaining_int}% left${reset}"
fi

# Model
model_info=""
if [ -n "$model" ]; then
  model_info=" ${purple}[${model}]${reset}"
fi

# Claude usage cost (cached, 30 min TTL)
cost_info=""
cost=$(ccusage-today 2>/dev/null)
if [ -n "$cost" ]; then
  cost_info=" ${coral}${cost}${reset}"
fi

# Time
time_str=$(date "+%_I:%M %p")

printf '%b' "${cyan}${dir_parts}${reset} -${git_info} -${ctx_info} -${model_info} -${cost_info} -${orange}${time_str}${reset}"