# System Maintenance Scripts 🔧

Scripts for general system upkeep, updates, and cleanup on Debian-based systems.

---

## `cleanup-system.sh`

Performs basic system cleanup tasks like clearing apt caches and removing unused dependencies.

### Purpose

Helps free up disk space by removing cached package files and orphaned packages left over from installations or upgrades. Does *not* remove kernels.

### Usage

```bash
sudo ./cleanup-system.sh
```
*Note: Requires `sudo` as it uses `apt` for cleanup operations.*

### Dependencies

* `bash`
* `apt` (Debian package manager)
* `sudo` access

### Example

```bash
# Run the cleanup script
sudo ./cleanup-system.sh

# Sample Output:
# ℹ️  🧹 Starting system cleanup...
# ℹ️     -> Cleaning apt package cache (apt clean)...
# ✅    apt cache cleaned.
# ℹ️     -> Removing obsolete deb-packages (apt autoclean)...
# Reading package lists... Done
# Building dependency tree... Done
# Reading state information... Done
# ✅    Obsolete packages removed.
# ℹ️     -> Removing unused dependencies (apt autoremove)...
# Reading package lists... Done
# Building dependency tree... Done
# Reading state information... Done
# 0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
# ✅    Unused dependencies removed.
#
# ✅ ✨ System cleanup finished!
```

---

## `update-and-report.sh`

Updates the system using `apt`, attempts to fix broken dependencies, and reports recently upgraded packages.

### Purpose

A simple wrapper to perform a full system update (`update` & `upgrade`) and provide a quick look at what packages were just changed.

### Usage

```bash
sudo ./update-and-report.sh
```
*Note: Requires `sudo` as it uses `apt` to update the system.*

### Dependencies

* `bash`
* `apt`
* `grep`
* `awk`
* `sudo` access

### Example

```bash
# Run the update script
sudo ./update-and-report.sh

# Sample Output (shows apt output followed by):
#
# 📦 Recently upgraded packages:
#
# 2025-04-06 01:00:00 systemd:amd64
# 2025-04-06 01:00:01 libc6:amd64
# 2025-04-06 01:00:02 bash:amd64
```

### Notes

* This script runs `apt upgrade -y`, automatically confirming the upgrade. Review the packages to be upgraded if you prefer manual confirmation.
* The report relies on `/var/log/dpkg.log` existing and having the expected format.

---

