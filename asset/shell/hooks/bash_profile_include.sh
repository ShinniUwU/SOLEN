# Ensure interactive config is loaded for login shells
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
