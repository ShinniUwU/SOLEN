case $- in *i*) : ;; *) return ;; esac
if [[ -n "$SOLEN_NO_TUI" || "$TERM" == "dumb" ]]; then
  :
else
  command -v serverutils >/dev/null 2>&1 && SOLEN_RUN_QUIET=1 serverutils run motd/solen-motd -- --full
fi
