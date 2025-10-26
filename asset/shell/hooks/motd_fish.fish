# >>> SOLEN MOTD_FISH (do not edit) >>>
if status is-interactive
    if test -z "$SOLEN_NO_TUI" -a "$TERM" != "dumb"
        if type -q serverutils
            env SOLEN_RUN_QUIET=1 serverutils run motd/solen-motd --
        end
    end
end
# <<< SOLEN MOTD_FISH (managed) <<<
