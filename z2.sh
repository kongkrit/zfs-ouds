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
ls -alF /dev/disk/by-id/
echo "=== 2.1"
read -p "=== enter name of disk1 of 2:" DISK
DISK=/dev/disk/by-id/$DISK
echo "==> disk1 is $DISK"
read -p "=== enter name of disk2 of 2:" DISK2
DISK2=/dev/disk/by-id/$DISK2
echo "==> disk2 is $DISK2"
read -p "*** enter capital Y to format both disks:" CONFIRMIT

if [ $CONFIRMIT != "Y" ]; then
  echo "=== not Y, exiting"
  exit -1
fi

echo "=== 2.2 formatting both disks"
sgdisk --zap-all $DISK
sgdisk --zap-all $DISK2
echo "=== 2.3 creating paritions for UEFI booting"
sgdisk -n2:1M:+512M -t2:EF00 $DISK
sgdisk -n2:1M:+512M -t2:EF00 $DISK2
echo "=== 2.3 creating boot partitions (UEFI)"
sgdisk -n3:0:+1G -t3:BF01 $DISK
sgdisk -n3:0:+1G -t3:BF01 $DISK2
echo "=== 2.3a creating root partitions (unencrypted)"
sgdisk     -n4:0:0        -t4:BF01 $DISK
sgdisk     -n4:0:0        -t4:BF01 $DISK2

echo "=== 2.3a done, sleeping for 3 seconds"
sleep 3

echo "=== 2.4 creating boot pool (mirrored)"
zpool create -o ashift=12 -d \
    -o feature@async_destroy=enabled \
    -o feature@bookmarks=enabled \
    -o feature@embedded_data=enabled \
    -o feature@empty_bpobj=enabled \
    -o feature@enabled_txg=enabled \
    -o feature@extensible_dataset=enabled \
    -o feature@filesystem_limits=enabled \
    -o feature@hole_birth=enabled \
    -o feature@large_blocks=enabled \
    -o feature@lz4_compress=enabled \
    -o feature@spacemap_histogram=enabled \
    -o feature@userobj_accounting=enabled \
    -O acltype=posixacl -O canmount=off -O compression=lz4 -O devices=off \
    -O normalization=formD -O relatime=on -O xattr=sa \
    -O mountpoint=/ -R /mnt bpool mirror ${DISK}-part3 ${DISK2}-part3

echo "=== 2.5a creating root pool mirror (unencrypted)"
zpool create -o ashift=12 \
    -O acltype=posixacl -O canmount=off -O compression=lz4 \
    -O dnodesize=auto -O normalization=formD -O relatime=on -O xattr=sa \
    -O mountpoint=/ -R /mnt rpool mirror ${DISK}-part4 ${DISK2}-part4

echo "=== finished step 2.5"
echo "=== run z3.sh as root next"
