# Backups v1 (Scaffold)

This is a scaffold for SOLEN backups. It defines the CLI surface, profiles config and outputs without implementing copy or prune yet.

- Entry: `Scripts/backups/run.sh`
- Config: `config/solen-backups.yaml`
- Fixtures: `docs/fixtures/backups/*.ndjson`

## CLI

- `backups run --profile <name> [--dest <path>] [--retention-days N] [--dry-run] [--json]`
- `backups prune --profile <name> [--dest <path>] [--retention-days N] [--dry-run] [--json]`

Env overrides:
- `SOLEN_BACKUPS_CONFIG`, `SOLEN_BACKUPS_DEST`, `SOLEN_BACKUPS_RETENTION_DAYS`

Exit codes: `0 ok`, `1 user error`, `2 env/deps`, `3 partial`, `4 policy refused`, `>=10 specific`.

Policy tokens: `backup-path:<glob>`, `backup-profile:<name>`.

## Profiles config

See `config/solen-backups.yaml`. Defaults: `dest`, `retention_days`, and global `exclude`. Each profile has `sources[]`, optional per-source `exclude`, and `tags`.

Suggested profiles: `etc`, `lxc-configs`, `jellyfin-meta`, `mc-world`.

## Output (NDJSON)

- Begin: `begin: backup <profile> at <dest>`
- Dry-run rollup: `would back up X sources (≈Y planned), would prune Z` + metrics
- Success rollup: `backup complete (A copied, B sets pruned)` + metrics
- Refusal: `policy refused: backup-path:/path` (exit 4)
- Missing deps: `rsync not available; install rsync` (exit 2)

Examples: `docs/fixtures/backups/`.

## Next

Implementation will use `rsync` for copy and dated directories with a `manifest.json`, then retention pruning. All actions will be policy-gated and support `--dry-run/--json` with final rollups.

