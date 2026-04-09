---
name: Use mise exec for bash commands when .mise.toml is present
description: Always use `mise exec` when running bash commands in directories with a .mise.toml file
type: feedback
---

Always use `mise exec` when running commands in directories that have a `.mise.toml` file, not plain tool commands like `npm`/`node`/etc.

**Why:** The Bash tool runs in a non-interactive shell, so mise's shell activation (`eval "$(mise activate zsh)"`) is not loaded and shims are not on PATH. Running managed tools directly results in "command not found".

**How to apply:**
```bash
mise exec --cd /path/to/directory -- npm run <script>
```
Check for a `.mise.toml` in the target directory before running any tool commands. If one exists, use `mise exec`.
