#!/usr/bin/env bash
sudo apt update && sudo apt --fix-broken install -y && sudo apt upgrade -y && echo -e "\n📦 Recently upgraded packages:\n" && grep "upgrade " /var/log/dpkg.log | awk '{print $1, $2, $4}'
