[[ -f ~/.zshrc.shared ]] && source ~/.zshrc.shared

export PATH="$PATH:$HOME/workspace/dotfiles/bin"

[[ -f ~/.devbox.zsh ]] && source ~/.devbox.zsh
[[ -f ~/.skip.zsh ]] && source ~/.skip.zsh
[[ -f ~/.rtm.zsh ]] && source ~/.rtm.zsh
[[ -f ~/.op_service_account_token ]] && source ~/.op_service_account_token
[[ -f ~/.op-gh-credentials ]] && source ~/.op-gh-credentials
[[ -f ~/.op-ssh-key ]] && source ~/.op-ssh-key
