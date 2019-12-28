#!/bin/bash

if [ $USER != "root" ]; then
        echo "must run as root"
        exit -1
fi

echo "=== 4.5 configure basic system environment"
ln -s /proc/self/mounts /etc/mtab
apt update

echo "=== 4.5 configure locale--make sure en_US.UTF-8 is checked"
#read -p "enter to start configuring locale:" DUMMYV
#dpkg-reconfigure locales
echo "=== select en_US.UTF-8"
echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections
echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections
rm "/etc/locale.gen"
dpkg-reconfigure --frontend noninteractive locales

echo "=== 4.5 configuring time zone data"
#read -p "enter to start configuring time zone data:" DUMMYV
#dpkg-reconfigure tzdata
echo "=== 4.5 set time zone to [Asia/Bangkok]"
ln -fs /usr/share/zoneinfo/Asia/Bangkok /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

echo "=== 4.5 install nano"
apt install -y nano

echo "=== 4.6 install ZFS over HWE kernel on disks"
apt install --yes --no-install-recommends linux-image-generic-hwe-18.04
apt install --yes zfs-initramfs 

echo "=== 4.6 not needed for unencrypted disks"

echo "=== 4.8.0 install dosfstools"
apt install -y dosfstools
echo "=== 4.8.1 make EFI partition"
mkdosfs -F 32 -s 1 -n EFI ${DISK}-part2
echo "=== 4.8.2 make EFI directory"
mkdir /boot/efi
echo "=== 4.8.3 add EFI partition to /etc/fstab"
echo PARTUUID=$(blkid -s PARTUUID -o value ${DISK}-part2) \
    /boot/efi vfat nofail,x-systemd.device-timeout=1 0 1 >> /etc/fstab
echo "=== 4.8.4 mount /boot/efi"
mount /boot/efi
echo "=== 4.8.5 install grub-efi"
apt install --yes grub-efi-amd64-signed shim-signed

echo "=== 4.9 setting root password"
passwd

echo "=== 4.10 enable zfs-import-bpool.service"
echo "[Unit]
DefaultDependencies=no
Before=zfs-import-scan.service
Before=zfs-import-cache.service
    
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/zpool import -N -o cachefile=none bpool
    
[Install]
WantedBy=zfs-import.target" \
 > /etc/systemd/system/zfs-import-bpool.service

echo "=== 4.10 systemctl enable zfs-import-bpool.service"
systemctl enable zfs-import-bpool.service

echo "=== 4.11 Mount a tmpfs to /tmp"
cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount

echo "=== 4.12 Setup system groups:"
addgroup --system lpadmin
addgroup --system sambashare

echo "=== 5.1 verify that zfs boot filesystem is recognized"
echo "=== running grub-probe /boot"
grub-probe /boot
echo "=== result should say [zfs]"
read -p "press enter:"

echo "=== 5.2 Refresh the initrd files:"
update-initramfs -u -k all

echo "=== FINISHED 5.2 - continue in z5"
