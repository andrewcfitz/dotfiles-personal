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

# tmux server as a launchd daemon. Local Network Privacy exempts launchd
# daemons (even with UserName set), and a tmux server keeps the attribution of
# whatever started it, so a server born under an unapproved app or a launch
# agent hands "no route to host" to every shell inside it. Cost: the server
# lives outside the GUI session, so pbcopy, open, and keychain prompts don't
# work inside it. -D keeps the server in the foreground so launchd owns it and
# KeepAlive restarts it; otherwise a dead server gets replaced by whichever
# login shell runs tmux next, with that shell's attribution.
TMUX_DAEMON_LABEL="biz.fitz.tmux"
TMUX_DAEMON_PLIST="/Library/LaunchDaemons/$TMUX_DAEMON_LABEL.plist"
TMUX_DAEMON_TMP=$(mktemp)
cat > "$TMUX_DAEMON_TMP" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$TMUX_DAEMON_LABEL</string>
    <key>UserName</key>
    <string>$USER</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(brew --prefix)/bin/tmux</string>
        <string>-D</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$HOME</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>$HOME</string>
        <key>PATH</key>
        <string>$(brew --prefix)/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>LANG</key>
        <string>en_US.UTF-8</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/$TMUX_DAEMON_LABEL.err</string>
</dict>
</plist>
PLIST
if sudo cmp -s "$TMUX_DAEMON_TMP" "$TMUX_DAEMON_PLIST" && sudo launchctl print "system/$TMUX_DAEMON_LABEL" &>/dev/null; then
    log_skip "tmux launchd daemon already installed"
else
    log_action "Installing tmux launchd daemon..."
    sudo launchctl bootout "system/$TMUX_DAEMON_LABEL" &>/dev/null || true
    sudo install -m 644 -o root -g wheel "$TMUX_DAEMON_TMP" "$TMUX_DAEMON_PLIST"
    sudo launchctl bootstrap system "$TMUX_DAEMON_PLIST"
    log_info "tmux launchd daemon installed"
    log_warn "If a tmux server was already running, it owns the socket: run 'tmux kill-server' and launchd will start its own"
fi
rm -f "$TMUX_DAEMON_TMP"
