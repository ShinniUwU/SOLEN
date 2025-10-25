# /etc/fish/conf.d/solen.fish (managed by SOLEN)
if status is-interactive
    if test -z "$SOLEN_NO_TUI" -a "$TERM" != "dumb"
        if type -q serverutils
            serverutils run motd/solen-motd -- --plain
        end
    end
end
