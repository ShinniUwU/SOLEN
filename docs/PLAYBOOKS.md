# Playbooks

## Safe update cycle

1. Check for updates
   - `serverutils run pkg/manage -- check --json`
2. Back up important data (dry-run first)
   - `serverutils run backups/run -- run --profile etc --dry-run --json`
   - `serverutils run backups/run -- run --profile etc --json`
3. Apply upgrades
   - `serverutils run system-maintenance/update-and-report -- --json`
4. Health check
   - `serverutils run health/check -- --json`

## Security posture

1. Baseline security review (read-only)
   - `serverutils run security/baseline-check -- --json`
2. Firewall status
   - `serverutils run security/firewall-status -- --json`

## Docker roll (single app)

1. Inspect Docker state
   - `serverutils run docker/list-docker-info -- --json`
2. Update the app (dry-run first if scripted)
   - `serverutils run docker/update-docker-compose-app -- --dry-run /srv/app`
   - `serverutils run docker/update-docker-compose-app -- /srv/app`
3. Health check
   - `serverutils run health/check -- --json`
