#!/bin/bash

if [ $USER != "root" ]; then
        echo "must run as root"
        exit -1
fi

echo "=== 6.6 Create a user account:"
read -p "   enter username:" USERNAME
zfs create rpool/home/$USERNAME
adduser $USERNAME
cp -a /etc/skel/. /home/$USERNAME
chown -R $USERNAME:$USERNAME /home/$USERNAME

echo "=== 6.7 Add [$USERNAME] to the default set groups for an administrator:"
usermod -a -G adm,cdrom,dip,lpadmin,plugdev,sambashare,sudo YOURUSERNAME

echo "=== 6.7 done -- continue with z6b.sh -- from ssh ${USERNAME}@ipaddress"
