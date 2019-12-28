#!/bin/bash

if [ $USER != "root" ]; then
        echo "must run as root"
        exit -1
fi

echo "=== 4.1 configure machine name"
read -p "4.1 Enter hostname:" HOSTNAME
echo "=== 4.1 entered [$HOSTNAME]"
echo $HOSTNAME > /mnt/etc/hostname
echo "=== 4.1 wrote [$HOSTNAME] to /mnt/etc/hostname"
read -p "4.1 Enter Fully Qualified Domain Name (FQDN) (blank if unsure):" FQDN
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

echo "=== 4.4 listing disks"
ls -alF /dev/disk/by-id/
echo "=== 4.4 disks list above"
read -p "=== enter name of disk1 of 2:" DISK
DISK=/dev/disk/by-id/$DISK
echo "==> disk1 is $DISK"
read -p "=== enter name of disk2 of 2:" DISK2
DISK2=/dev/disk/by-id/$DISK2

echo "==="
echo "=== 4.4 doing chroot, when bash prompt comes, execute z4b.sh"
echo "==="
chroot /mnt /usr/bin/env DISK=$DISK DISK2=$DISK2 bash --login
echo "=== 4.4 done chroot"
