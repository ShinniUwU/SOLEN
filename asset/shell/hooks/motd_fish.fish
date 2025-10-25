# >>> SOLEN MOTD_FISH (do not edit) >>>
if status is-interactive
    if test -z "$SOLEN_NO_TUI" -a "$TERM" != "dumb"
        if type -q serverutils
            serverutils run motd/solen-motd -- --plain
        end
    end
end
# <<< SOLEN MOTD_FISH (managed) <<<
