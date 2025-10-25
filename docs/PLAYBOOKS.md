# Playbooks

## Safe update cycle

1. Check for updates
   - `serverutils run pkg/manage -- check --json`
2. Back up important data (Kopia; dry-run first)
   - `serverutils run backups/run -- run --profile etc --dry-run --json`
   - `serverutils run backups/run -- run --profile etc --json --yes`
   - Optional: install Kopia first
     - `serverutils run backups/install-kopia -- --dry-run`
     - `serverutils run backups/install-kopia -- --yes`
3. Apply upgrades
   - `serverutils run system-maintenance/update-and-report -- --json`
4. Health check
   - `serverutils run health/check -- --json`

## Security posture

1. Baseline security review (read-only)
   - `serverutils run security/baseline-check -- --json`
2. Firewall status
   - `serverutils run security/firewall-status -- --json`
3. Apply firewall (dry-run first; allow SSH + web)
   - `serverutils run security/firewall-apply -- --ssh-port 22 --service web --dry-run`
   - `serverutils run security/firewall-apply -- --ssh-port 22 --service web --yes`

3. Schedule Kopia maintenance (user scope)
   - `./serverutils install-units --user`
   - `systemctl --user daemon-reload`
   - `systemctl --user enable --now solen-kopia-maintenance.timer`
4. Harden SSH (dry-run first; disable root + passwords)
   - `serverutils run security/ssh-harden -- --permit-root no --password-auth no --restart --dry-run`
   - `serverutils run security/ssh-harden -- --permit-root no --password-auth no --restart --yes`

## Docker roll (single app)

1. Inspect Docker state
   - `serverutils run docker/list-docker-info -- --json`
2. Update the app (dry-run first if scripted)
   - `serverutils run docker/update-docker-compose-app -- --dry-run /srv/app`
   - `serverutils run docker/update-docker-compose-app -- /srv/app`
3. Health check
   - `serverutils run health/check -- --json`
