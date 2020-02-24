#!/usr/bin/env bash

#### Replace by any uuid generated with `uuid` command
GPU_UUID=2aee154e-7d0d-11e8-88b8-6f45320c7162

### Tools to download
virtio="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.173-7/virtio-win-0.1.173.iso"
vbios="120.25.59.132:3000/vbios_gvt_uefi.rom"

### Libvirt file location
libvirt-dir="/var/lib/libvirt/"

### Ram Dynamic Allocation
ratio=3
ram-in-kib=$(( $( cat /proc/meminfo | grep MemTotal: | awk {'print $2'}) / 4 * "$ratio" ))
ram-in-mib="${ram-in-kib%*???}"

### Retrieve user 1000 of the system for later setup
user="$(cat /etc/passwd | grep 1000 | cut -d ':' -f1)"

### Dependencies
install_dependencies () {
    packages=["libvirt", "dtc", "ovmf", "intel-gpu-tools", "htop", "ksmtuned-git", "tuned", "numactl", "numatop", "numad-git"]
    
    #### OS detection script
    echo "Trying to detect distribution"
    declare -A osInfo;
    osInfo[/etc/redhat-release]="yum install -y"
    osInfo[/etc/arch-release]="pacman -S --noconfirm"
    osInfo[/etc/debian_version]="apt-get install -y"
    osInfo[/etc/alpine-release]="apk --update add"
    osInfo[/etc/centos-release]="yum install -y"
    osInfo[/etc/fedora-release]="dnf install -y"

    echo "Installing dependencies for ${osInfo[$f]}"
    for f in ${!osInfo[@]}
    do
        if [[ -f $f ]];then
            echo Package manager: ${osInfo[$f]}
        package_manager=${osInfo[$f]}
        fi
    done

    ${package_manager} ${packages}
    echo "Done!"
}

### Don't uncommunt
##### TODO
#### Check if image sizs doesn't exceed disk avalaible space in GB
# [[ "$(( $( df -h --output=avail /var | tail -n 1 | rev | cut -c 2- | rev ) - ${3%?} > 5))" ]]