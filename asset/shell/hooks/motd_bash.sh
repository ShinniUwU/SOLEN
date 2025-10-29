# >>> SOLEN MOTD_BASH (do not edit) >>>
# Only run for interactive shells
case $- in *i*) : ;; *) return ;; esac
# Respect CI/non-interactive environments
if [ -n "$SOLEN_NO_TUI" ] || [ "$TERM" = "dumb" ]; then
  :
else
  command -v serverutils >/dev/null 2>&1 && SOLEN_RUN_QUIET=1 serverutils run motd/solen-motd -- --full
fi
# <<< SOLEN MOTD_BASH (managed) <<<
