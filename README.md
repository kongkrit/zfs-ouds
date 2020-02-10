# zfs-ouds
OUDS = On-root Ubuntu Dumb Scripts to help install zfs on root filesystem for ubuntu 18.04.3
Based on ZFS on Linux wiki at https://github.com/zfsonlinux/zfs/wiki/Ubuntu-18.04-Root-on-ZFS

- Start "testing" Ubuntu 18.04.3 Live desktop media
- Hit `Ctrl+Alt+F2` to get to text terminal (`F3` and `F4` also works)
- `sudo apt install -y openssh-server`
- `sudo -i` and `echo "ubuntu:any" | chpasswd` to change ubuntu user password to "any" (use your own password here)
- `ip a` and note the IP address.
- Now you can SSH into the box via ubuntu@ipaddress and use the 6-char password set earlier
```
sudo -i
GET https://raw.githubusercontent.com/kongkrit/zfs-ouds/master/a1.sh > a1.sh
GET https://raw.githubusercontent.com/kongkrit/zfs-ouds/master/a4.sh > a4.sh
GET https://raw.githubusercontent.com/kongkrit/zfs-ouds/master/a6c.sh > a6c.sh
chmod +x a*.sh
./a1.sh
```
