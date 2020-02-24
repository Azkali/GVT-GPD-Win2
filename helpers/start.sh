#!/usr/bin/env bash
[[ "$(whoami)" != "root" ]] && echo "Launch this script as root/sudo !" && exit

[[ ! $1 ]] && echo 'Please provide a VM name. Avalaible VM :'&& virsh list --all && exit 1

## Uncomment to start samba server on your HOST
# systemctl start smb nmb

xhost si:localuser:nobody
/etc/libvirt/hooks/qemu $1 release -
sleep 5
/etc/libvirt/hooks/qemu $1 prepare $2 -
sleep 5
virsh start $1
