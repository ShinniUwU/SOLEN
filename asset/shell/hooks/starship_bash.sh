if command -v starship >/dev/null 2>&1; then
  export STARSHIP_CONFIG="${STARSHIP_CONFIG:-$HOME/.config/solen/starship.toml}"
  eval "$(starship init bash)"
fi
