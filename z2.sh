#!/bin/bash

if [ $USER != "root" ]; then
        echo "must run as root"
        exit -1
fi

# add-apt-repository --yes ppa:jonathonf/zfs
apt install --yes debootstrap gdisk zfs-initramfs

# apt update
# echo === installing jonathonf/zfs 
# apt install --yes libelf-dev zfs-dkms
# systemctl stop zfs-zed
# modprobe -r zfs
# modprobe zfs
# systemctl start zfs-zed
# zfs --version

echo === list disks
ll /dev/disk/by-id/
echo ===
read -p "=== enter full path of disk1 of 2:" DISK
read -p "=== enter full path of disk2 of 2:" DISK2
read -p "=== enter capital Y to format both disks" CONFIRM

if [ $CONFIRM != "Y" ]
  echo "=== not Y, exiting"
  exit -1
fi
