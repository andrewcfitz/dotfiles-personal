[[ -f ~/.zshrc.shared ]] && source ~/.zshrc.shared

export PATH="$PATH:$HOME/workspace/dotfiles/bin"

[[ -f ~/.devbox.zsh ]] && source ~/.devbox.zsh
[[ -f ~/.skip.zsh ]] && source ~/.skip.zsh
[[ -f ~/.op_service_account_token ]] && source ~/.op_service_account_token
[[ -f ~/.op-gh-credentials ]] && source ~/.op-gh-credentials
