# Update Scripts

SOLEN self-update mechanism with channel support.

---

## `check.sh`

Check remote channel manifest and cache latest version info (quiet).

### Purpose

Quietly checks for SOLEN updates from the configured channel without producing output unless updates are available. Caches the result for quick subsequent checks.

### Usage

```bash
../../serverutils run update/check -- [--json]
```

**Options**:
- `--json`: Output JSON format
- `--force`: Bypass cache and check remote

### Channels

| Channel | Description |
|---------|-------------|
| `stable` | Production-ready releases |
| `rc` | Release candidates for testing |
| `nightly` | Latest development builds |

Configure channel in `~/.serverutils/config` or via environment:

```bash
export SOLEN_UPDATE_CHANNEL=stable
```

### Cache

Results are cached to `~/.serverutils/update-cache.json` for 1 hour to avoid repeated network calls.

---

## `status.sh`

Show installed version and cached latest (soft reminder).

### Purpose

Displays current installed version alongside the latest available version. Provides a gentle reminder when updates are available without being intrusive.

### Usage

```bash
../../serverutils run update/status -- [--json]
```

### Example Output

```
SOLEN v0.1.0 (installed)
Latest: v0.2.0 (stable channel)
Run 'serverutils run update/apply -- --yes' to update
```

### Example Output (JSON)

```json
{
  "status": "ok",
  "summary": "update available: 0.1.0 -> 0.2.0",
  "ts": "2024-01-15T10:30:00Z",
  "host": "myserver",
  "metrics": {
    "installed": "0.1.0",
    "latest": "0.2.0",
    "channel": "stable",
    "update_available": true
  }
}
```

---

## `apply.sh`

Download and atomically apply an update from the selected channel.

### Purpose

Downloads the latest SOLEN release and atomically replaces the current installation. Keeps a rollback copy of the previous version.

### Usage

```bash
../../serverutils run update/apply -- [options]
```

**Options**:
- `--dry-run`: Preview update (default)
- `--json`: Output JSON format
- `--yes`: Execute update
- `--channel <name>`: Override channel (stable/rc/nightly)

### Update Process

1. **Check**: Fetch manifest from channel
2. **Download**: Retrieve tarball to temp location
3. **Verify**: Check SHA256 checksum (and signature if configured)
4. **Backup**: Copy current installation to rollback location
5. **Apply**: Atomically replace with new version
6. **Verify**: Run basic sanity check

### Rollback

Previous version is saved to:
- User install: `~/.local/share/solen.rollback/`
- Global install: `/opt/solen.rollback/`

To rollback manually:
```bash
cp -a ~/.local/share/solen.rollback/* ~/.local/share/solen/
```

### Signature Verification

If `SOLEN_SIGN_PUBKEY_PEM` is configured, updates are verified against the release signature.

### Examples

```bash
# Check what update would do
serverutils run update/apply -- --dry-run

# Apply update
serverutils run update/apply -- --yes

# Update to release candidate
serverutils run update/apply -- --channel rc --yes
```

### Dependencies

* `curl`: For downloading updates
* `tar`: For extracting archives
* `sha256sum`: For checksum verification
* `openssl`: For signature verification (optional)

---
