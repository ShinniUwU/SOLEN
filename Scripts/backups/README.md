# Backups 💾

This folder contains the SOLEN backups runner. It now supports Kopia for efficient snapshots, with a safe scaffold fallback when Kopia is not installed.

Key script:

- `run.sh`
  - Runs or prunes backups by profile defined in `config/solen-backups.yaml`.
  - Uses Kopia by default if available:
    - Filesystem repo at `<dest>/kopia-repo` (default dest `/var/backups/solen`).
    - Optional S3: set `SOLEN_KOPIA_S3_BUCKET`, `SOLEN_KOPIA_S3_REGION`, and optional `SOLEN_KOPIA_S3_PREFIX`, `SOLEN_KOPIA_S3_ENDPOINT`.
    - Repo password via `KOPIA_PASSWORD` or `KOPIA_PASSWORD_FILE` (defaults to `~/.serverutils/kopia-password`).
    - Optional repo-per-profile: set `SOLEN_KOPIA_REPO_PER_PROFILE=1` to isolate each profile to its own repo.
  - Honors `--dry-run`, `--yes`, and policy tokens `backup-profile:<name>` and `backup-path:<dest>`.

Examples:

```
# Dry-run backups for profile "etc"
../../serverutils run backups/run -- run --profile etc --dry-run --json

# Real run with local filesystem repo under /var/backups/solen/kopia-repo
../../serverutils run backups/run -- run --profile etc --json --yes

# Use S3 (ensure AWS credentials are exported)
export SOLEN_KOPIA_S3_BUCKET=my-bucket
export SOLEN_KOPIA_S3_REGION=us-east-1
export SOLEN_KOPIA_S3_PREFIX=solen-prod
export KOPIA_PASSWORD_FILE=~/.serverutils/kopia-password
# AWS credentials (one of):
export AWS_ACCESS_KEY_ID=AKIAXXXX
export AWS_SECRET_ACCESS_KEY=xxxx
# or use a shared credentials file
export AWS_SHARED_CREDENTIALS_FILE=~/.aws/credentials
../../serverutils run backups/run -- run --profile etc --json --yes

# Prune/maintenance (Kopia maintenance)
../../serverutils run backups/run -- prune --profile etc --json --yes
```

Notes:

- Profiles and sources are read from `config/solen-backups.yaml`.
- Default and per-source excludes are supported for simple YAML shapes.
- The systemd timer `solen-backups@.timer` can be enabled per profile after quickstart.

Install Kopia quickly:

```
../../serverutils run backups/install-kopia -- --dry-run
../../serverutils run backups/install-kopia -- --yes
```

Schedule maintenance:

```
# User scope
./serverutils install-units --user
systemctl --user daemon-reload
systemctl --user enable --now solen-kopia-maintenance.timer

Environment for S3 (units):

- Put credentials and settings in `~/.config/solen/backups.env` (user) or `/etc/solen/backups.env` (system), e.g.:

```
AWS_ACCESS_KEY_ID=AKIAXXXX
AWS_SECRET_ACCESS_KEY=xxxx
SOLEN_KOPIA_S3_BUCKET=my-bucket
SOLEN_KOPIA_S3_REGION=us-east-1
SOLEN_KOPIA_S3_PREFIX=solen-prod
```

Units include `EnvironmentFile` entries for these paths.

System-wide units:

- Provided `solen-backups-system@.service`/`.timer` and `solen-kopia-maintenance-system.service`/`.timer` append logs to `/var/log/solen/*.ndjson`.
- Ensure the runner is installed globally: `sudo ./serverutils install-runner --global`.
- Enable timers:
  - `sudo cp systemd/*.service systemd/*.timer /etc/systemd/system/` (or use `serverutils install-units --global`)
  - `sudo systemctl daemon-reload`
  - `sudo systemctl enable --now solen-kopia-maintenance-system.timer`
  - `sudo systemctl enable --now solen-backups-system@etc.timer`

Log rotation:

- See `docs/LOGGING.md` for a ready logrotate snippet that rotates `/var/log/solen/*.ndjson` and the audit log.
```
