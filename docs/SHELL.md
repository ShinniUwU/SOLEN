# Optional Shell Experience (Zsh + Starship)

Goals
- Opt‑in, reversible per‑user or system‑wide.
- Keep edits minimal and guarded by comments.

What this includes (when selected)
- Installs `zsh` and `starship` via your package manager when available.
- Places curated configs under `~/.config/solen/` (future; currently optional).
- Suggests a one‑line sourcing stub to add to `~/.zshrc` / `~/.bashrc`.

Install
- Show plan: `serverutils install --show-plan --with-zsh --with-starship`
- Apply: `serverutils install --with-zsh --with-starship --yes`

Uninstall
- Remove the sourcing stub lines from your shell profiles.
- Optional: remove `~/.config/solen/` files you no longer need.

Notes
- If `starship` is not available on your distro, SOLEN will skip it gracefully.
- Nothing is edited automatically; SOLEN prints exact lines to add/remove.

