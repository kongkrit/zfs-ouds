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
