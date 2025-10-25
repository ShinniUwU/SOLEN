# /etc/profile.d/solen.sh (managed by SOLEN)
# Only interactive shells
case $- in *i*) : ;; *) return ;; esac 2>/dev/null || true
if [ -n "$SOLEN_NO_TUI" ] || [ "$TERM" = "dumb" ]; then
  :
else
  if command -v serverutils >/dev/null 2>&1; then
    serverutils run motd/solen-motd -- --plain
  fi
fi
