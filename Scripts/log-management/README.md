# Log Management Scripts 🪵

Scripts for cleaning, rotating, or managing system and application logs.

---

## `clear-logs.sh`

Cleans systemd journald logs based on size and time limits, and can optionally truncate specified log files.

### Purpose

Helps manage disk space used by logs by removing old journald entries and clearing out specified log files.

### Usage

```bash
sudo ./clear-logs.sh
```
*Note: Requires `sudo` as it modifies system logs and uses `journalctl` vacuum options.*

### Configuration (Inside the script)

* `JOURNALD_VACUUM_SIZE`: Sets the maximum disk space journald logs should occupy (e.g., "100M"). Logs are removed if total size exceeds this.
* `JOURNALD_VACUUM_TIME`: Sets the maximum age for journald logs (e.g., "7d"). Logs older than this are removed.
* `TRUNCATE_LOGS`: An array of full paths to specific log files that will be truncated (set to 0 bytes). Uncomment or add paths as needed (e.g., `"/var/log/syslog"`).

### Dependencies

* `bash`
* `journalctl` (from `systemd`)
* `truncate` (from `coreutils`)
* `sudo` access

### Example

```bash
# Run the script with default settings (100M / 7d for journald, maybe some files in TRUNCATE_LOGS)
sudo ./clear-logs.sh

# Sample Output:
# ℹ️  🗑️ Starting log cleanup...
# ℹ️     -> Cleaning journald logs (if older than 7d or total size > 100M)...
# Vacuuming done, freed 50.0M of archived journals on disk.
# ✅    Journald logs cleaned based on size/time limits.
# ℹ️     -> Truncating specific log files (setting size to 0)...
# ℹ️        Truncating /var/log/syslog...
# ✅       /var/log/syslog truncated.
# ✅ ✨ Log cleanup finished!
```

### Notes

* Be careful when adding files to `TRUNCATE_LOGS`. Truncating logs means their contents are lost permanently. Ensure you don't need the old content or that logs are handled correctly by log rotation daemons first.

---
