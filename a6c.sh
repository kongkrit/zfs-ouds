#!/bin/bash

if [ $USER != "root" ]; then
        echo "must run as root"
        exit -1
fi

echo "=== 6.6 Create a user account:"
read -p "   enter admin username:" USERNAME
#zfs create rpool/home/$USERNAME
adduser $USERNAME --gecos "${USERNAME},,,"
cp -a /etc/skel/. /home/$USERNAME
chown -R $USERNAME:$USERNAME /home/$USERNAME

echo "=== 6.7 Add [$USERNAME] to the default set groups for an administrator:"
usermod -a -G adm,cdrom,dip,lpadmin,plugdev,sambashare,sudo $USERNAME

echo "=== showing ip address ==="
ip addr show

#echo "=== 6.7 done -- continue with b6b.sh -- from ssh ${USERNAME}@ipaddress"

DISK=$(</disk1_name)
DISK2=$(</disk2_name)

#echo "=== 6.8 list disks"
#ls -alF /dev/disk/by-id/
#echo "=== 6.8 mirror grub"
#echo "    disk 1 is where grub is already installed"
#echo "    disk 2 is the mirror"
#echo "=== *** ENTER DISK NAME WITHOUT -partN ***"
#read -p "=== enter name of disk1 of 2:" DISK
#DISK=/dev/disk/by-id/$DISK
echo "==> disk1 is $DISK"
#read -p "=== enter name of disk2 of 2:" DISK2
#DISK2=/dev/disk/by-id/$DISK2
echo "==> disk2 is $DISK2"

echo "=== 8.2 install more software"
echo "    0. don't install anything, run ubuntu-minimal"
echo "    1. install ubuntu-standard"
echo "    2. install ubuntu-server"

read -p "What do you want to install?" UCHOICE
if test $UCHOICE -eq 1; then
    echo "entered 1"
    echo "=== install ubuntu-standard"
else
    if test $UCHOICE -eq 2; then
        echo "entered 2"
        echo "=== install ubuntu-server"
    else
        echo "did not enter 1 or 2"
        echo "=== install nothing"
    fi
fi

echo "=== 6.8b UEFI"
echo "=== 6.8b1 mount /boot/efi /boot/efi2"
mount /boot/efi
mount /boot/efi2

echo "=== 6.8b2 rsync GRUB from disk1 to disk2"
#dd if=${DISK}-part2 \
#   of=${DISK2}-part2
rsync -Rai --stats --human-readable --delete --verbose --progress /boot/efi/./ /boot/efi2

echo "=== 6.8b3 unmount /boot/efi /boot/efi2"
umount /boot/efi
umount /boot/efi2

echo "=== 6.8b install grub to disk2"
efibootmgr -c -g -d $DISK2 \
    -p 2 -L "ubuntu-2" -l '\EFI\ubuntu\grubx64.efi'
echo "=== 6.8b remount /boot/efi /boot/efi2"
mount /boot/efi
mount /boot/efi2

echo "=== 7 configure swap (SKIPPED)"

#echo "=== 8.1 upgrading current minimal system"
#apt dist-upgrade --yes

echo "=== 8.2 install more software"
# echo "    0. don't install anything, run ubuntu-minimal"
# echo "    1. install ubuntu-standard"
# echo "    2. install ubuntu-server"

if test $UCHOICE -eq 1; then
    echo "=== install ubuntu-standard"
    apt install -y ubuntu-standard
else
    if test $UCHOICE -eq 2; then
        echo "=== install ubuntu-server"
        apt install -y ubuntu-server
    else
        echo "=== install nothing (ubuntu-minimal)"
    fi
fi

echo "=== 8.1 upgrading current minimal system"
apt dist-upgrade --yes

echo "=== 8.3 Optional: Disable log compression:"
for file in /etc/logrotate.d/* ; do
    if grep -Eq "(^|[^#y])compress" "$file" ; then
        sed -i -r "s/(^|[^#y])(compress)/\1#\2/" "$file"
    fi
done

echo "=== 9.3 Optional: Disable the root password"
usermod -p '*' root

echo "=== apt autoremove -y && apt autoclean"
apt autoremove -y
apt autoclean

echo "=== 8.4 reboot"
read -p "press enter to reboot:" DUMMYV
reboot
