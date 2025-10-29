#!/usr/bin/env bash
# Minimal cross-distro package manager helpers

__SOLEN_PM="unknown"

pm_detect() {
  if command -v apt-get >/dev/null 2>&1; then __SOLEN_PM=apt
  elif command -v dnf >/dev/null 2>&1; then __SOLEN_PM=dnf
  elif command -v pacman >/dev/null 2>&1; then __SOLEN_PM=pacman
  elif command -v zypper >/dev/null 2>&1; then __SOLEN_PM=zypper
  else __SOLEN_PM=unknown; fi
  return 0
}

pm_name() { echo "$__SOLEN_PM"; }

# Return a plan string to update package metadata
pm_update_plan() {
  case "$__SOLEN_PM" in
    apt) echo "sudo apt-get update -y" ;;
    dnf) echo "sudo dnf -y makecache" ;;
    pacman) echo "sudo pacman -Sy --noconfirm" ;;
    zypper) echo "sudo zypper -n refresh" ;;
    *) echo "# pm update (unsupported)" ;;
  esac
}

# Return a plan string to install packages: pm_install_plan <pkgs...>
pm_install_plan() {
  case "$__SOLEN_PM" in
    apt) echo "sudo apt-get install -y $*" ;;
    dnf) echo "sudo dnf -y install $*" ;;
    pacman) echo "sudo pacman -S --noconfirm $*" ;;
    zypper) echo "sudo zypper -n install $*" ;;
    *) echo "# pm install $* (unsupported)" ;;
  esac
}

# Optional: count updates available (best-effort; fall back to 0)
pm_check_updates_count() {
  case "$__SOLEN_PM" in
    apt)
      if command -v apt-get >/dev/null 2>&1; then
        (apt-get -s upgrade 2>/dev/null | awk '/^Inst /{c++} END{print c+0}') || echo 0
      else echo 0; fi ;;
    dnf)
      (dnf -q check-update 2>/dev/null | awk 'END{print NR+0}') || echo 0 ;;
    pacman)
      (checkupdates 2>/dev/null | wc -l | tr -d ' ') || echo 0 ;;
    zypper)
      (zypper -q list-updates 2>/dev/null | awk 'NR>2{c++} END{print c+0}') || echo 0 ;;
    *) echo 0 ;;
  esac
}

