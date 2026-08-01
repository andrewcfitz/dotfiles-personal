#!/bin/bash
# Machine-local bootstrap steps for this repo. Sourced by bootstrap.sh (--local).
# Logging helpers (log_action/log_info/log_skip) come from the caller.

# Global npm packages. Brewfiles can't express these, so they live here.
NPM_GLOBALS=(
    tscircuit
)

for pkg in "${NPM_GLOBALS[@]}"; do
    if npm ls -g --depth=0 "$pkg" &>/dev/null; then
        log_skip "npm $pkg already installed"
    else
        log_action "Installing npm package $pkg..."
        npm install -g "$pkg"
        log_info "npm $pkg installed"
    fi
done
