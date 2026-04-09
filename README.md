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

## Bootstrap a new machine

```bash
git clone git@github.com:andrewcfitz/dotfiles.git ~/workspace/dotfiles
cd ~/workspace/dotfiles
./bootstrap.sh
```

This will:
1. Install Homebrew (if not already installed)
2. Symlink all `files/` dotfiles to `$HOME`
3. Install all Homebrew packages from `.Brewfile`
4. Attempt to configure secrets via 1Password CLI (skips if not yet authenticated)

## Configure secrets

After bootstrap, sign into the 1Password CLI and run the secrets script to write `~/.aws/config`:

```bash
op signin
bin/setup-secrets
```
