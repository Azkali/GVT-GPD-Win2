#!/usr/bin/env bash
[[ "$(whoami)" != "root" ]] && echo "Please use sudo or run as root" && exit

### Checking if device is a GPD WIN2 or P2MA
device="$(dmidecode | grep -A3 '^System Information' | grep 'Product Name: ' | sed -e 's/Product Name://' | tr -d '[:blank:]')"
[[ "${device}" == "P2MAX" || "${device}" == "WIN2" ]]


[[ ! -f "/usr/share/X11/xorg.conf.d/20-intel.conf" ]] && 
echo "Setting up tear-free screen config" &&
echo 'Section "Device"
Identifier "Intel Graphics"
Driver "Intel"
Option "AccelMethod" "sna"
Option "TearFree" "true"
EndSection' > /usr/share/X11/xorg.conf.d/20-intel.conf

[[ "${device,,}" == "win2" ]] && 
echo "Fixing gamepad toggle" &&
echo "[Unit]
Description=Fix GPD Win2 gamepad toggle

[Service]
ExecStart=modprobe xpad ; echo 0x0079 0x18d4 > /sys/bus/usb/drivers/xpad/new_id


[Install]
WantedBy=default.target" > /etc/systemd/system/gpd-win2-gamepad-probe.service && 
systemctl enable --now gpd-win2-gamepad-probe.service