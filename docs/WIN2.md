# GPD Win2 Fixes

## Screen tearing fix

`/usr/share/X11/xorg.conf.d/20-intel.conf` :

```sh
Section "Device"
Identifier "Intel Graphics"
Driver "Intel"
Option "AccelMethod" "sna"
Option "TearFree" "true"
EndSection
```

## Gamepad switch fix

You should make the following command a systemd service :

```sh
# modprobe xpad ; echo 0x0079 0x18d4 > /sys/bus/usb/drivers/xpad/new_id
```

or apply this [xboxdrv patch]()