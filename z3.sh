#!/bin/bash

if [ $USER != "root" ]; then
        echo "must run as root"
        exit -1
fi

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
debootstrap bionic /mnt
zfs set devices=off rpool
