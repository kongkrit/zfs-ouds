#!/bin/bash

if [ $USER != "root" ]; then
        echo "must run as root"
        exit -1
fi

echo "=== 5.3/5.4 editing grub file"
echo "    Set: GRUB_CMDLINE_LINUX=\"root=ZFS=rpool/ROOT/ubuntu\""
echo "    Comment out: GRUB_TIMEOUT_STYLE=hidden"
echo "    Set: GRUB_TIMEOUT=5"
echo "    Below GRUB_TIMEOUT, add: GRUB_RECORDFAIL_TIMEOUT=5"
echo "    Remove quiet and splash from: GRUB_CMDLINE_LINUX_DEFAULT"
echo "    Uncomment: GRUB_TERMINAL=console"
cat /etc/default/grub | \
sed -E 's/(^GRUB_CMDLINE_LINUX=")/\1root=ZFS=rpool\/ROOT\/ubuntu /g' | \
sed -E 's/(^GRUB_CMDLINE_LINUX=")(.*)([ tab]+)(")/\1\2\4/g' | \
sed -E 's/(^GRUB_TIMEOUT_STYLE=hidden)/#\1/g' | \
sed -E 's/(^GRUB_TIMEOUT=)[0-9]+$/\15\nGRUB_RECORDFAIL_TIMEOUT=5/g' | \
sed -E 's/(^GRUB_CMDLINE_LINUX_DEFAULT=")(.*)(quiet)(.*)(")/\1\2\4\5/g' | \
sed -E 's/(^GRUB_CMDLINE_LINUX_DEFAULT=")(.*)(splash)(.*)(")/\1\2\4\5/g' | \
sed -E 's/(^GRUB_CMDLINE_LINUX_DEFAULT=")([ tab]+)(.*)(")/\1\3\4/g' | \
sed -E 's/(^GRUB_CMDLINE_LINUX_DEFAULT=")(.*)([ tab]+)(")/\1\2\4/g' | \
sed -E 's/^(#)(GRUB_TERMINAL=console)/\2/g' \
 > /etc/default/grub

echo "=== 5.5 update grub"
update-grub
echo "=== 5.5 Ignore errors from osprober, if present."

echo "=== 5.6b install grub (UEFI)"
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
    --bootloader-id=ubuntu --recheck --no-floppy

echo "=== 5.7 Verify that the ZFS module is installed:"
echo "    ls /boot/grub/*/zfs.mod" 
ls /boot/grub/*/zfs.mod
read -p "=== result above. press enter:" DUMMYV

echo "=== 5.8 Fix filesystem mount ordering"
echo "    umount /boot/efi (for UEFI)"
umount /boot/efi

echo "=== 5.8 set mountpoint for bpool/BOOT/ubuntu"
zfs set mountpoint=legacy bpool/BOOT/ubuntu
echo bpool/BOOT/ubuntu /boot zfs \
    nodev,relatime,x-systemd.requires=zfs-import-bpool.service 0 0 >> /etc/fstab
echo "=== 5.8 set mountpoint for rpool/var/log"
zfs set mountpoint=legacy rpool/var/log
echo rpool/var/log /var/log zfs nodev,relatime 0 0 >> /etc/fstab
echo "=== 5.8 set mountpoint for rpool/var/spool"
zfs set mountpoint=legacy rpool/var/spool
echo rpool/var/spool /var/spool zfs nodev,relatime 0 0 >> /etc/fstab

echo "=== 5.8 set mountpoint for /var/tmp dataset:"
zfs set mountpoint=legacy rpool/var/tmp
echo rpool/var/tmp /var/tmp zfs nodev,relatime 0 0 >> /etc/fstab
echo "=== 5.8 set mountpoint for /tmp dataset:"
zfs set mountpoint=legacy rpool/tmp
echo rpool/tmp /tmp zfs nodev,relatime 0 0 >> /etc/fstab

echo "=== 6.1 snapshot initial installation"
zfs snapshot bpool/BOOT/ubuntu@install
zfs snapshot rpool/ROOT/ubuntu@install

echo "=== done!"
echo "=== type exit to leave the chroot environment"
