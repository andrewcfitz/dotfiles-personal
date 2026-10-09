[[ -f ~/.zshrc.shared ]] && source ~/.zshrc.shared

export PATH="$PATH:$HOME/workspace/dotfiles/bin"
[[ -d "$HOME/.darkbloom/bin" ]] && export PATH="$PATH:$HOME/.darkbloom/bin"

[[ -f ~/.devbox.zsh ]] && source ~/.devbox.zsh
[[ -f ~/.skip.zsh ]] && source ~/.skip.zsh
[[ -f ~/.op-gh-credentials ]] && source ~/.op-gh-credentials
[[ -f ~/.op-ssh-key ]] && source ~/.op-ssh-key
# The tmux server is a launchd daemon outside the GUI session, so op can't
# reach the 1Password app from inside it. Use the service account there.
[[ -n $TMUX && -f ~/.cache/op/service-account-token ]] && source op-load-service-token

xcode() {
  local app="${$(xcode-select -p)%/Contents/Developer}"
  if [[ ! -d $app ]]; then
    echo "xcode: could not resolve active Xcode (xcode-select -p = $(xcode-select -p))" >&2
    return 1
  fi
  if (( $# == 0 )); then
    open -a "$app"
  else
    open -a "$app" "$@"
  fi
}
