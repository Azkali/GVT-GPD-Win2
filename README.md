# GPD WIN2/P2MAX + Intel GVT-G

Although the title state this is for the ***GPD WIN2*** it *should* work with any supported Intel iGPUs.

## GVT-G

***GVT-G*** is an ***Intel*** technology that provides Intel iGPU passthrough in virtual machine using ***KVM***.
It's **only** compatible with Intel's newer CPU.

## My setup

***GPD WIN2*** *with Niluanxy's cooling mod installed* :

iGPU : **HD Graphics 615**
CPU : **M3-7Y30 4Core@2.6GHz**
HOST : **MANJARO-5.5.2-1**
GUEST : **Windows 10 1909**
BIOS: **BIOS**

***GPD P2 MAX*** :

iGPU : **UHD Graphics 615**
CPU : **M3-8100Y 4Core@3.4GHz**
HOST : **MANJARO-5.5.2-1**
GUEST : **Windows 10 1909**
BIOS: **BIOS**

## AutoInstaller

If you don't want to bother configuring the VM yourself I'm providing helper scripts to setup/start the VM.

Use setup.sh once only to setup your host configuration.
Use start.sh each time you want to boot the VM

Setup script usage `./helpers/setup.sh iso_image vm_size in GB`.
Start script usage `./helpers/start.sh vm_name`.

Examples :

`setup.sh` :

```sh
# ./helpers/setup.sh windows.iso 50G
```

`start.sh` :

```sh
# ./helpers/start.sh windows
```

## Pre requisites

- Linux Host with Kernel 5.5
- KVM
- Virtio iso
- UEFI VBIOS
- Windows 10 iso
- CPU Governor

***Use only Linux 5.5*** as Linux 5.4 and *some* previous version don't work for this setup.
\****You should be able download the 5.5.2 kernel from your distro package manager otherwise compile it yourself following intel/gvt gvt-g setup guide, you can use vanilla linux instead of intel's kernel.***

Check if your CPU supports VT-x/VT-d :

```sh
LC_ALL=C lscpu | grep Virtualization
```

Check if KVM is loaded in the kernel :

```sh
zgrep CONFIG_KVM /proc/config.gz
```

## User-Compiled dependencies

### Capstone

You have to use the latest master version of capstone for `qemu` to build properly.

```sh
git clone https://github.com/aquynh/capstone/
```

```sh
cd capstone
```

```sh
# ./make.sh
```

### Patched QEMU

According to [this comment](https://github.com/intel/gvt-linux/issues/35#issuecomment-438149916) modify the display's refresh rate in QEMU :

```sh
git clone https://git.qemu.org/git/qemu.git
```

Edit `qemu/include/ui/console.h` and change `GUI_REFRESH_INTERVAL_DEFAULT = 30` to 16/17 milliseconds for 60Hz refresh rate ( to calcute your refresh rate timing use this formula : ( 1/REFRESH_RATE_IN_HERTZ*1000 ) ) :

```sh
GUI_REFRESH_INTERVAL_DEFAULT = 17
```

Build QEMU :

```sh
git submodule update --init roms/seabios
```

```sh
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
```

```sh
make -j$((`nproc`/2)) ### or `make -j${nproc}` to use all core
```

```sh
cd roms/seabios
```

```sh
make -j$((`nproc`/2)) ### or `make -j${nproc}` to use all core
```

```sh
cd ../..
```

```sh
# make install
```

```sh
# cp roms/seabios/out/bios.bin /usr/bin/bios.bin
```

## Linux host config

These configurations where made using Manjaro, tweak to reflect your distribution config.

### Initramfs

Add the following modules to your be loaded with initramfs :

`MODULES = 'kvmgt vfio_pci vfio vfio-iommu-type1 vfio-mdev vfio_virqfd'`

### GRUB

Append the following to `GRUB_CMDLINE_DEFAULT` inside `/etc/default/grub` :

```sh
GRUB_CMDLINE_DEFAULT="... i915.enable_gvt=1 kvm.ignore_msrs=1 intel_iommu=igfx_off i915.enable_guc=0 ..."
```

And update GRUB :

```sh
# update-grub
```

### QEMU as user

Edit `/etc/libvirt/qemu.conf` :

Uncomment this line and replace `root` by your username if you want to allow a specific user other than `root` to launch qemu :

```sh
user="azkali" ## Replpace with your own username
```

Allow audio playing :

```sh
nographics_allow_host_audio = 1
```

## Libvirt xml config

### CPU

TODO

### RAM

Append the following inside `<domain>` replace RAM_KiB by the amount of RAM to allocate in KiB :

```xml
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  
  ................
  <memory unit='KiB'>RAM_KiB</memory>
  <currentMemory unit='KiB'>RAM_KiB</currentMemory>
  <memoryBacking>
    <hugepages/>
    <nosharepages/>
    <discard/>
  </memoryBacking>
  ................

```

#### Hugepages

Append the following inside `<domain>` under `<currentMemory>` :

```xml
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  
  ................
  <memory unit='KiB'>RAM_KiB</memory>
  <currentMemory unit='KiB'>RAM_KiB</currentMemory>
  <memoryBacking>
    <hugepages/>
    <nosharepages/>
    <discard/>
  </memoryBacking>
  ................

```

### GPU

#### iGPU Passthrough

TODO

##### DMA BUF

```xml
  .........
  </devices>
  <qemu:commandline>
    <qemu:arg value='-set'/>
    <qemu:arg value='device.hostdev0.x-igd-opregion=on'/>
  </qemu:commandline>
</domain>
```

##### RAMFB

```xml
  .........
  </devices>
  <qemu:commandline>
    <qemu:arg value='-set'/>
    <qemu:arg value='device.hostdev0.ramfb=on'/>
  </qemu:commandline>
</domain>
```

###### RAMFB UEFI

```xml
  .........
  </devices>
  <qemu:commandline>
    <qemu:arg value='-set'/>
    <qemu:arg value='device.hostdev0.romfile=/var/lib/libvirt/images/vbios_gvt_uefi.rom'/>
  </qemu:commandline>
</domain>
```

#### Display

At this point you're pretty much setup.
Either configure a SPICE or VNC server as display.

More on [Arch Wiki](https://wiki.archlinux.org/index.php/Intel_GVT-g#Display_vGPU_output).

Or

Append the following to your xml file to use QEMU GTK display :

```xml
  ..........
  </devices>
  <qemu:commandline>
    <qemu:arg value='-set'/>
    <qemu:arg value='device.hostdev0.driver=vfio-pci-nohotplug'/>
    <qemu:arg value='-set'/>
    <qemu:arg value='device.hostdev0.display=on'/>
    <qemu:arg value='-display'/>
    <qemu:arg value='gtk,gl=on'/>
    <qemu:env name='DISPLAY' value=':1'/>
    <qemu:env name='GDK_SCALE' value='1.0'/>
    <qemu:env name='QEMU_AUDIO_DRV' value='pa'/>
    <qemu:env name='QEMU_PA_SERVER' value='/run/user/1000/pulse/native'/>
  </qemu:commandline>
</domain>
```

If using QEMU GTK display, set display in $DISPLAY variable before every launching the VM :

```sh
xhost si:localuser:nobody
```

Your final `<qemu:commandline>` should look like this :

```xml
  ..........
  </devices>
  <qemu:commandline>
    <qemu:arg value='-set'/>
    <qemu:arg value='device.hostdev0.romfile=/var/lib/libvirt/images/vbios_gvt_uefi.rom'/>
    <qemu:arg value='-set'/>
    <qemu:arg value='device.hostdev0.x-igd-opregion=on'/>
    <qemu:arg value='-set'/>
    <qemu:arg value='device.hostdev0.ramfb=on'/>
    <qemu:arg value='-set'/>
    <qemu:arg value='device.hostdev0.driver=vfio-pci-nohotplug'/>
    <qemu:arg value='-set'/>
    <qemu:arg value='device.hostdev0.display=on'/>
    <qemu:arg value='-display'/>
    <qemu:arg value='gtk,gl=on'/>
    <qemu:env name='DISPLAY' value=':1'/>
    <qemu:env name='GDK_SCALE' value='1.0'/>
    <qemu:env name='QEMU_AUDIO_DRV' value='pa'/>
    <qemu:env name='QEMU_PA_SERVER' value='/run/user/1000/pulse/native'/>
  </qemu:commandline>
</domain>
```

#### Storage

Attach a new SATA disk with qcow2 format :

```sh
qemu-img create -f qcow2 Win10.qcow2 50G  ## Set to at least 30G for Windows 10 1909
```

#### Network

TODO

## Guest boot

### Installation

- Add a new CD-ROM device pointing to your `Windows10.iso` file location
- Boot up the VM
- Install Windows 10
- Shutdown Windows 10 as you would normaly
- Remove Windows 10 CD-ROM

### Virtio drivers

- Add a new CD-ROM device pointing to your `virtio.iso` file location
- Boot your VM
- Open the virtio drive ( `My PC -> CD-ROM..` )
- Execute and install the `*_64.exe` file with default options
- Shutdown Windows 10 as you would normaly
- Remove `virtio.iso` CD-ROM

#### Use Virtio drivers

You can now use virtio driver for your storage and network devices.
In `virt-manager` select your disk device and change the driver to `VirtIO`

#### Intel Graphics

- Install the latest [Intel graphics drivers](https://downloadmirror.intel.com/29335/a08/igfx_win10_100.7755.exe) *or let Windows do the job*
- You will see a black screen for a bit, wait until you get back to windows ( it should take under a few minutes )
- Then open your `Device Manager` -> `Display` you should see your iGPU being properly installed, for me `HD Graphics 615`

### Going further

#### CPU Optimizations

##### Pinning

Setting up the CPU topology statically should improve performances.
As both th P2MAX and the WIN2 have only 1 CPU [[[]]], CPU pinning shouldn't be needed.

More on [Arch Wiki](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF#CPU_pinning) and
[RedHat Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html-single/virtualization_tuning_and_optimization_guide/index#sect-option_CPU_topology)

##### Isolating

More on [Arch Wiki](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF#Isolating_pinned_CPUs)

##### Governors

If you intend to play some games or graphical tasks I highly recomand to setup a CPU governor, at least for the GPD devices.
You can use my setup for TLP and Intel-undervolt inside `examples` folder.

#### NUMA

Refer to this [RedHat guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html-single/virtualization_tuning_and_optimization_guide/index) about virtualization tuning and optimization.

#### Guest sleep

Set `suspend-to-mem` and `suspend-to-disk` to yes:

```xml
  <pm>
    <suspend-to-mem enabled='yes'/>
    <suspend-to-disk enabled='yes'/>
  </pm>
```

#### Tuned

Enable `tuned` service to set profile for kvm

## GNOME Tweaks

[Disable trackers](https://gist.github.com/vancluever/d34b41eb77e6d077887c)

`chmod -x /usr/lib/evolution/evolution-calendar-factory` to disable evolution

## TODO

- [x] Audio passthrough - add section
- [x] Samba server - add section
- [x] CPU Pinning
- [x] Static Hugepages
- [x] Guest sleep - add section
- [x] NUMA - add section
- [x] Tuned - add section
- [x] KSM - Kernel Same Page - add section
- [x] ksmtuned enabled - add section
- [x] numactl - add section
- [ ] UEFI - Untested should work
- [ ] Clipboard
- [ ] Using RAW filesystem - add section
- [ ] Virtio Net & Disk drivers - add section
- [ ] Partition as storage - add section
- [ ] SD Card passthrough - not possible requires `reset` capabilities
- [ ] USB passthrough - not possible requires `reset` capabilities

## Sources

Redhat - [Virtualiaztion Tuning and Optimization](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html-single/virtualization_tuning_and_optimization_guide/index)

[Libvirt domain](https://libvirt.org/formatdomain.html)

Arch Wiki - [PCI passthrough via OVMF](https://wiki.archlinux.org/index.php/PCI_passthrough_via_OVMF)
Arch Wiki - [Intel DMA_BUF](https://wiki.archlinux.org/index.php/Intel_GVT-g#Getting_vGPU_display_contents)
Arch Wiki - [Intel RAMFB Display](https://wiki.archlinux.org/index.php/Intel_GVT-g#Using_RAMFB_display)

Reddit - [WIN2 Gamepad fix](https://www.reddit.com/r/gpdwin/comments/8l5vn8/gpd_win_2_gamepad_in_linux/)
Reddit - [WIN2 Fixes](https://www.reddit.com/r/gpdwin/comments/b5dwi5/gpd_win_2_linux_mint_iso_dualboot_scripts_fixes/)

Github - [Intel GVT-G Setup guide](https://github.com/intel/gvt-linux/wiki/GVTg_Setup_Guide)
Github - [Libvirt Hugepage issue](https://github.com/PassthroughPOST/virsh-patcher/issues/5)

[GTK Display - GVT](https://blog.bepbep.co/posts/gvt/)
[Blog VFIO tweaks](https://tripleback.net/post/chasingvfioperformance/)
[QEMU hugepages hook](https://rokups.github.io/#!pages/gaming-vm-performance.md)
