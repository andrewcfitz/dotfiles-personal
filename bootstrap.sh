#!/bin/bash

set -e

./init.sh

DOTFILES_DIR=$(dirname "$(realpath "$0")")

# Install Homebrew if not already installed
if ! [ -x "$(command -v /opt/homebrew/bin/brew)" ] > /dev/null; then
    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew is already installed."
fi

defaults write com.apple.dock autohide -bool true && killall Dock

# Remove broken symlinks pointing into dotfiles (shared or local)
cleanup_broken_symlinks() {
    local files_dir="$1"
    while read -r link; do
        target=$(readlink "$link")
        if [[ "$target" == "$files_dir/"* ]] && [ ! -e "$link" ]; then
            read -rp "Remove broken symlink: $link? [y/N] " confirm
            [[ "$confirm" =~ ^[Yy]$ ]] && rm "$link"
        fi
    done < <(find "$HOME" -maxdepth 1 -type l)

    for subdir in "$files_dir"/*/; do
        [ -d "$subdir" ] || continue
        rel="${subdir#"$files_dir/"}"
        rel="${rel%/}"
        home_subdir="$HOME/$rel"
        if [ -d "$home_subdir" ]; then
            while read -r link; do
                target=$(readlink "$link")
                if [[ "$target" == "$files_dir/"* ]] && [ ! -e "$link" ]; then
                    read -rp "Remove broken symlink: $link? [y/N] " confirm
                    [[ "$confirm" =~ ^[Yy]$ ]] && rm "$link"
                fi
            done < <(find "$home_subdir" -type l)
        fi
    done
}

# Symlink all files from a given files directory into $HOME
symlink_files() {
    local files_dir="$1"
    find "$files_dir" -type f -not -name ".keepme" | while read -r src; do
        rel="${src#$files_dir/}"
        dest="$HOME/$rel"
        mkdir -p "$(dirname "$dest")"
        ln -sf "$src" "$dest"
    done
}

if [ -d "$DOTFILES_DIR/shared/files" ]; then
    cleanup_broken_symlinks "$DOTFILES_DIR/shared/files"
fi
cleanup_broken_symlinks "$DOTFILES_DIR/files"

if [ -d "$DOTFILES_DIR/shared/files" ]; then
    symlink_files "$DOTFILES_DIR/shared/files"
fi
symlink_files "$DOTFILES_DIR/files"

if [ ! -d $HOME/.antidote ]; then
  git clone --depth=1 https://github.com/mattmc3/antidote.git ${ZDOTDIR:-~}/.antidote
fi

export PATH="/opt/homebrew/bin:$PATH"

# Install Homebrew packages
brew bundle --file=~/.Brewfile
brew bundle --file=~/.Brewfile.shared

~/.osx

# Install iTerm2 AI plugin
ITERM_AI_DIR="$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch/iTermAI"
if [ ! -d "$ITERM_AI_DIR" ]; then
    echo "Installing iTerm2 AI plugin..."
    curl -L -o /tmp/iTermAI.zip "https://github.com/gnachman/iterm2-website/raw/refs/heads/master/downloads/ai-plugin/iTermAI-1.1.zip"
    mkdir -p "$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch"
    unzip -qo /tmp/iTermAI.zip -d "$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch"
    rm /tmp/iTermAI.zip
    echo "iTerm2 AI plugin installed."
else
    echo "iTerm2 AI plugin is already installed."
fi
