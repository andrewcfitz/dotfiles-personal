# 1Password CLI

Inside tmux and inside Claude Code, the only supported way to use `op` is the service account token:

```sh
eval "$(op-load-service-token)"
```

Never run `op signin`, `eval "$(op signin)"`, or anything that relies on the 1Password desktop app integration there. The tmux server runs as a launchd daemon outside the GUI session, so `op` can't reach the app and sign-in fails.

If `op` fails with an auth error, check that `OP_SERVICE_ACCOUNT_TOKEN` is set, then load it as above. If the token cache (`~/.cache/op/service-account-token`) is missing, ask me to run `op-save-service-token` from a plain Ghostty tab outside tmux. Don't try to work around it.

The service account only sees the vaults granted to it. If an item isn't visible, say so instead of falling back to a personal sign-in.
