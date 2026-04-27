[[ -f ~/.zshrc.shared ]] && source ~/.zshrc.shared

export PATH="$PATH:$HOME/workspace/dotfiles/bin"

[[ -f ~/.devbox.zsh ]] && source ~/.devbox.zsh
[[ -f ~/.skip.zsh ]] && source ~/.skip.zsh
[[ -f ~/.op_service_account_token ]] && source ~/.op_service_account_token
[[ -f ~/.op-gh-credentials ]] && source ~/.op-gh-credentials
[[ -f ~/.op-ssh-key ]] && source ~/.op-ssh-key

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
