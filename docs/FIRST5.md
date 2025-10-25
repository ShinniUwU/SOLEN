# SOLEN — First 5 Minutes

1. Install the runner and optional polish (plan first)
   - `serverutils install --show-plan --with-motd --with-zsh --with-starship --copy-shell-assets --units user --user`
   - Apply: `serverutils install --with-motd --with-zsh --with-starship --copy-shell-assets --units user --user --yes`

2. Enable a services panel (optional)
   - Copy `config/motd/services.example` to `~/.config/solen/services` and adjust (e.g., `SSHD;ssh.service`, `NGINX;nginx`).
   - Try the full MOTD: `serverutils run motd/solen-motd -- --full`

3. Verify backups
   - Dry-run: `serverutils run backups/run -- verify --profile etc --json`
   - All profiles (if listed in config): `serverutils run backups/run -- verify --all --json`

4. Firewall and SSH harden (plan → apply)
   - Firewall plan: `serverutils run security/firewall-apply -- --ssh-port 22 --service web --egress deny --persist --plan fw.plan`
   - Review `fw.plan`, then apply: `serverutils run security/firewall-apply -- --commit fw.plan --yes`
   - SSH harden (dry-run first): `serverutils run security/ssh-harden -- --permit-root no --password-auth no --restart --dry-run`
   - Apply: `serverutils run security/ssh-harden -- --permit-root no --password-auth no --restart --yes`

5. Quick health check
   - `serverutils run doctor -- --json`

Notes
- Non-interactive shells should suppress MOTD unless `--json` is passed. CI includes a smoke for that.
- All SOLEN scripts default to dry-run unless `--yes` is provided.

