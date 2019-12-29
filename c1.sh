#!/bin/bash

if [ $USER != "root" ]; then
        echo "must run as root"
        exit -1
fi

echo "********************"
echo "*** IN c1.sh now ***"
echo "********************"

echo "=== 1.2 adding universe repo and update"
apt-add-repository universe
apt update
echo "=== 1.3 install openssh-server"
apt install -y openssh-server
echo "======================="
echo "=== note IP address ==="
echo "======================="
ip a
# read -p "enter to continue:" DUMMYV

echo "=== 1.5 install debootstrap gdisk and zfs"
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

echo "=== 4.1 configure new machine name"
echo "===     current name is [$HOSTNAME]"
read -p "4.1 Enter new hostname:" HOSTNAME
echo "=== 4.1 entered hostname as [$HOSTNAME]"
read -p "4.1 Enter Fully Qualified Domain Name (FQDN) (blank if unsure):" FQDN
echo "=== 4.1 entered FQDN as [$FQDN]"

echo "=== list disks"
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

echo "=== 3.1 Create filesystem datasets to act as containers"
zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o canmount=off -o mountpoint=none bpool/BOOT

echo "=== 3.2 Create filesystem datasets for the root and boot filesystems:"
zfs create -o canmount=noauto -o mountpoint=/ rpool/ROOT/ubuntu
zfs mount rpool/ROOT/ubuntu
zfs create -o canmount=noauto -o mountpoint=/boot bpool/BOOT/ubuntu
zfs mount bpool/BOOT/ubuntu

echo "=== 3.3 Create datasets:"
zfs create  rpool/home
zfs create -o mountpoint=/root rpool/home/root
zfs create -o canmount=off rpool/var
zfs create -o canmount=off rpool/var/lib
zfs create rpool/var/log
zfs create rpool/var/spool

echo "=== 3.3 exclude /var/tmp /var/cache from snapshots"
zfs create -o com.sun:auto-snapshot=false  rpool/var/cache
zfs create -o com.sun:auto-snapshot=false  rpool/var/tmp
chmod 1777 /mnt/var/tmp

echo "=== 3.3 create /opt /srv /usr /usr/local /var/games"
echo "===     /var/mail /var/snap /var/www docker nfs tmpfs"
zfs create                                 rpool/opt
zfs create                                 rpool/srv
zfs create -o canmount=off                 rpool/usr
zfs create                                 rpool/usr/local
zfs create                                 rpool/var/games
#store local email
zfs create                                 rpool/var/mail
zfs create                                 rpool/var/snap
zfs create                                 rpool/var/www
#if you use GNOME
#zfs create                                 rpool/var/lib/AccountsService
zfs create -o com.sun:auto-snapshot=false  rpool/var/lib/docker
zfs create -o com.sun:auto-snapshot=false  rpool/var/lib/nfs
# tmpfs
zfs create -o com.sun:auto-snapshot=false  rpool/tmp
chmod 1777 /mnt/tmp

echo "=== 3.4 Install the minimal system:"
echo "=== 3.4 debootstrap to /mnt"
debootstrap bionic /mnt
echo "=== 3.4 zfs set devices=off rpool"
zfs set devices=off rpool

echo "=== 4.1 configure machine name as [$HOSTNAME]"
echo "=== 4.1 entered [$HOSTNAME]"
echo $HOSTNAME > /mnt/etc/hostname
echo "=== 4.1 wrote [$HOSTNAME] to /mnt/etc/hostname"
HOSTSENTRY="127.0.1.1	$FQDN $HOSTNAME"
echo $HOSTSENTRY >> /mnt/etc/hosts
echo "=== 4.1 appended [$HOSTSENTRY] to /mnt/etc/hosts"

echo "=== 4.2 Configure the network interface:"
ip addr show
read -p "=== 4.2 enter inface name (excluding colon):" INTF
echo "network:
  version: 2
  ethernets:
    ${INTF}:
      dhcp4: true
#      dhcp4: no
#      addresses: [192.168.1.110/24, ]
#      gateway4:  192.168.1.1
#      nameservers:
#              addresses: [8.8.8.8, 8.8.4.4]" >> /mnt/etc/netplan/01-netcfg.yaml
echo "=== 4.2 wrote /mnt/etc/netplan/01-netcfg.yaml"

echo "=== 4.3 Configure the package sources in /mnt/etc/apt/sources.list:"
echo "# ubuntu archives
deb http://archive.ubuntu.com/ubuntu bionic main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu bionic main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu bionic-updates main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu bionic-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu bionic-backports main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu bionic-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu bionic-security main restricted universe multiverse" \
 >> /mnt/etc/apt/sources.list

echo "=== 4.4 Bind the virtual filesystems from the LiveCD environment to the new system"
mount --rbind /dev  /mnt/dev
mount --rbind /proc /mnt/proc
mount --rbind /sys  /mnt/sys

#echo "=== 4.4 listing disks"
#ls -alF /dev/disk/by-id/
#echo "=== 4.4 disks list above"
#read -p "=== enter name of disk1 of 2:" DISK
#DISK=/dev/disk/by-id/$DISK
#echo "==> disk1 is $DISK"
#read -p "=== enter name of disk2 of 2:" DISK2
#DISK2=/dev/disk/by-id/$DISK2

echo "==="
echo "=== 4.4 doing chroot, when bash prompt comes, execute c4.sh"
echo "==="
chroot /mnt /usr/bin/env DISK=$DISK DISK2=$DISK2 bash --login
echo "=== 4.4 done chroot"

echo "=== 6.3 unmount all filesystems in the LiveCD environment:"
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export -a

echo "=== 6.4 about to reboot, then login as root"
read -p "press enter to reboot:" DUMMYV
reboot
