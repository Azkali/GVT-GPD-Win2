#!/usr/bin/env bash
[[ "$(whoami)" != "root" ]] && echo "Launch this script as root/sudo !" && exit

source ./helpers/env.sh

[[ ! $1 ]] && echo 'Please provide a LiveCD iso/image of your OS.' && exit 1
[[ ! $2 ]] || [[ ! "${2%?}" =~ ^[0-9]+$ ]]; echo "Please provide a size for the VM disk filesystem ( minimum for Windows 10 1909: 30G )" && exit 1

iso-basename="basename ${1%.*}"
mv ./gvt-g.xml ./${iso-basename}-gvt-g.xml

### Dependency installation
install_dependencies()

### HOST Setup
echo "Copying system services scripts and configs"
cp -av ./configs/hooks/* /etc/libvirt/hooks/

wget "${virtio}" "${libvirt-dir}/images"
wget "${vbios}" "${libvirt-dir}/boot"


echo "Adding hugepages mount in /etc/fstab"
echo "hugetlbfs /dev/hugepages hugetlbfs mode=1770,gid="$(cat /etc/group | grep kvm | cut -d ':' -f3)" 0 0"  >> /etc/fstab
echo "Done!"

echo "Copying qemu hook needed to allocate hugepages dynamically and cleanly !"
[[ ! -f "/etc/udev/rules.d/10-qemu.rules" ]] && echo 'SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"' > /etc/udev/rules.d/10-qemu.rules

[[ ! -f "/etc/modprobe.d/kvm.conf" ]] && echo -e "options kvm ignore_msrs=1\noptions kvm report_ignored_msrs=0" > /etc/modprobe.d/kvm.conf
echo "Done!"

echo "Creating VGPU service in /etc/systemd/system/gvtvgpu.service for passthrough"
echo "[Unit]
Description=Create Intel GVT-g vGPU

[Service]
Type=oneshot
ExecStart=/bin/sh -c \"echo '${GPU_UUID}' > /sys/bus/pci/devices/0000:00:02.0/mdev_supported_types/i915-GVTg_V5_4/create\"
ExecStop=/bin/sh -c \"echo '1' > /sys/bus/pci/devices/0000:"$(lspci | grep 'Intel' | grep 'Graphics' | cut -d ' ' -f1)"/${GPU_UUID}/remove\"
RemainAfterExit=yes

[Install]
WantedBy=graphical.target" > /etc/systemd/system/gvtvgpu.service
echo "Done!"

echo "Enabling all services"
systemctl enable --now gvgvgpu.service
systemctl enable --now ksmtuned.service
systemctl enable --now ksm.service
systemctl enable --now tuned.service 
systemctl enable --now numad.service
usermod -aG kvm,libvirt "${user}"
echo "Done!"

echo "Adapting configs to your environement"
echo "Modifying /etc/libvirt/qemu.conf for user ${user}, setting up audio and hugepages in qemu"
sed -ie 's/#user = "root"/user = "'"$user"'"/' /etc/libvirt/qemu.conf
sed -ie '/^#.* nographics_allow_host_audio /s/^#//' /etc/libvirt/qemu.conf
sed -ie '/^#.* hugetlbfs_mount = " /s/^#//' /etc/libvirt/qemu.conf

echo "Editing XML using display "${DISPLAY}""
sed -ie 's/\":1\"/\"'"$DISPLAY"'\"/' ${iso-basename}-gvt-g.xml
sed -ie 's/ISO_FILE/'"$1"'/' ${iso-basename}-gvt-g.xml
sed -ie 's/DISKNAME/'"${iso-basename}"'/' ${iso-basename}-gvt-g.xml
sed -ie 's/RAM_KiB/'"${ram-in-kib}"'/' ${iso-basename}-gvt-g.xml
sed -ie 's/GPU_UUID/'"${GPU_UUID}"'/' ${iso-basename}-gvt-g.xml
echo "Done!"

echo "Compiling capstone from source"
git clone https://github.com/aquynh/capstone/
cd capstone
./make.sh
echo "Done!"

echo "Compiling and installing custom qemu"
git clone https://git.qemu.org/git/qemu.git
cd qemu
sed -ire 's/(INTERVAL_DEFAULT\s+)[^=]*$/\117/' include/ui/console.h
git submodule update --init roms/seabios
./configure --prefix=/usr \
    --enable-kvm \
    --disable-xen \
    --enable-libusb \
    --enable-debug-info \
    --enable-debug \
    --enable-sdl \
    --enable-vhost-net \
    --enable-spice \
    --disable-debug-tcg \
    --enable-opengl \
    --enable-gtk \
    --target-list=x86_64-softmmu
make -j$((`nproc`/2)) ### or `make -j${nproc}` to use all core
cd roms/seabios
make -j$((`nproc`/2)) ### or `make -j${nproc}` to use all core
cd ../../
make install
cp roms/seabios/out/bios.bin /usr/bin/bios.bin
cd ..
echo "Done!"

echo "Creating "${vm-disk-size}"G qcow2 image"
qemu-img create -f qcow2 "${libvirt-dir}/filesystems"/"${iso-basename}".qcow2 "${vm-disk-size}"
echo "Done!"

echo "Defining VM config inside libvirt"
virsh define --file ${iso-basename}-gvt-g.xml
echo -e "Done!\nYou can now run :\n\t./start.sh '"${iso-basename}"' \n to launch the created VM"