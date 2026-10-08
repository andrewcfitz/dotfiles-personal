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
# work inside it. Only takes effect when launchd starts the server; an already
# running server just gets the session added to it.
TMUX_DAEMON_LABEL="biz.fitz.tmux"
TMUX_DAEMON_PLIST="/Library/LaunchDaemons/$TMUX_DAEMON_LABEL.plist"
TMUX_DAEMON_SESSION="main"
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
        <string>new-session</string>
        <string>-d</string>
        <string>-s</string>
        <string>$TMUX_DAEMON_SESSION</string>
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
    <!-- tmux forks the server and exits; without this launchd kills it. -->
    <key>AbandonProcessGroup</key>
    <true/>
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
    log_info "tmux launchd daemon installed (session '$TMUX_DAEMON_SESSION')"
    log_warn "If a tmux server was already running, it still owns the sessions: run 'tmux kill-server' then 'sudo launchctl kickstart system/$TMUX_DAEMON_LABEL'"
fi
rm -f "$TMUX_DAEMON_TMP"
