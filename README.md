# dotfiles

Personal macOS dotfiles for a new machine setup.

## What's included

| Directory / File | Contents |
|---|---|
| `bootstrap.sh` | Main setup script — run this on a fresh machine |
| `bin/` | Shell utility scripts added to `$PATH` |
| `files/` | Dotfiles symlinked to `$HOME` by bootstrap |
| `iterm2/` | iTerm2 preferences |
| `rectangle/` | Rectangle Pro window manager config |

## Prerequisites

- macOS
- git
- A 1Password account (for secrets)

## New machine (cold start)

This repo is private and pulls in a private submodule, so a brand-new machine
can't clone it until git is installed and authenticated. The public
[`dotfiles-bootstrap`](https://github.com/andrewcfitz/dotfiles-bootstrap) repo
handles that chicken-and-egg with a single command — run it on a fresh Mac:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/andrewcfitz/dotfiles-bootstrap/main/cold-start.sh)
```

It installs Command Line Tools and Homebrew, installs `gh` and authenticates
via GitHub's device flow (paste a one-time code in the browser), clones this
repo to `~/workspace/dotfiles` **with submodules**, then runs `bootstrap.sh`
for you. Use `bash <(...)` rather than `curl ... | bash` — the device-code
login needs a real terminal. Re-running it on an existing checkout just pulls
the latest and re-bootstraps.

## Manual bootstrap

If the repo is already on the machine (or git is already authenticated):

```bash
git clone --recurse-submodules git@github.com:andrewcfitz/dotfiles-personal.git ~/workspace/dotfiles
cd ~/workspace/dotfiles
./bootstrap.sh
```

`bootstrap.sh` (run with no flags) initializes the `shared` submodule, installs
Homebrew, installs all packages from `.Brewfile` + `.Brewfile.shared`, symlinks
`files/` (and `shared/files/`) into `$HOME`, and applies the rest of the setup
(Antidote, tmux, Claude Code, iTerm AI, macOS defaults, sshd, Eternal Terminal).
Pass `--help` to see individual section flags.

## Configure secrets

The cold start authenticates git via `gh`, so this is optional. To set up
persistent 1Password-based credentials, sign into the 1Password CLI and run:

```bash
op signin
bin/op-ssh-key          # writes ~/.ssh/id_ed25519 from the fitz-biz vault
bin/op-gh-credentials   # writes ~/.git-credentials + sets credential.helper=store
```
