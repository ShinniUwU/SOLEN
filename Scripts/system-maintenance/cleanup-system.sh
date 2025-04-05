root@Jellyfin:~# ls
check_updates.sh  cleanup-system.sh
root@Jellyfin:~# chmod +x cleanup-system.sh 
root@Jellyfin:~# ./cleanup-system.sh 
ℹ️  🧹 Starting system cleanup...
ℹ️     -> Cleaning apt package cache (apt clean)...
✅    apt cache cleaned.
ℹ️     -> Removing obsolete deb-packages (apt autoclean)...
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
✅    Obsolete packages removed.
ℹ️     -> Removing unused dependencies (apt autoremove)...
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
✅    Unused dependencies removed.

✅ ✨ System cleanup finished!
root@Jellyfin:~# sudo ./cleanup-system.sh 
ℹ️  🧹 Starting system cleanup...
ℹ️     -> Cleaning apt package cache (apt clean)...
✅    apt cache cleaned.
ℹ️     -> Removing obsolete deb-packages (apt autoclean)...
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
✅    Obsolete packages removed.
ℹ️     -> Removing unused dependencies (apt autoremove)...
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
✅    Unused dependencies removed.

✅ ✨ System cleanup finished!
root@Jellyfin:~# 
