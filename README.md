# zfs-ouds
OUDS = On-root Ubuntu Dumb Scripts to help install zfs on root filesystem for ubuntu 18.04.3
Based on ZFS on Linux wiki at https://github.com/zfsonlinux/zfs/wiki/Ubuntu-18.04-Root-on-ZFS

- Start "testing" Ubuntu 18.04.3 Live desktop media
- Hit `Ctrl+Alt+F2` to get to text terminal (`F3` and `F4` also works)
- login with user `ubuntu` - no need for password
- `sudo -i` become root
- `apt install -y openssh-server`
- `echo "ubuntu:any" | chpasswd` to change ubuntu user password to "any" (use your own password here)
- `ip a` and note the IP address.
- Now you can SSH into the box via ubuntu@ipaddress and use the password set by echo text into `chpasswd` earlier
- SSH into the box and start the script:
  ```
  sudo -i
  GET https://raw.githubusercontent.com/kongkrit/zfs-ouds/master/a1.sh > a1.sh
  GET https://raw.githubusercontent.com/kongkrit/zfs-ouds/master/a4.sh > a4.sh
  GET https://raw.githubusercontent.com/kongkrit/zfs-ouds/master/a6c.sh > a6c.sh
  chmod +x a*.sh
  ./a1.sh
  ```

### Notes:
- For a pair of nvme drives, **choose the `nvme-eui` set** and not `nvme-<brand>` set for `disks` (otherwise it fails at `a1.sh`  `debootstrap $RELEASE /mnt`)
  ```
  === list disks
  total 0
  drwxr-xr-x 2 root root 200 Feb 25 17:06 ./
  drwxr-xr-x 7 root root 140 Feb 25 17:06 ../
  lrwxrwxrwx 1 root root  13 Feb 25 17:08 nvme-eui.0025385c915033c7 -> ../../nvme0n1
  lrwxrwxrwx 1 root root  13 Feb 25 17:08 nvme-eui.0025385c915033ce -> ../../nvme1n1
  lrwxrwxrwx 1 root root  13 Feb 25 17:08 nvme-Samsung_SSD_970_EVO_Plus_500GB_S4EVNG0MC01712Z -> ../../nvme0n1
  lrwxrwxrwx 1 root root  13 Feb 25 17:08 nvme-Samsung_SSD_970_EVO_Plus_500GB_S4EVNG0MC01719X -> ../../nvme1n1
  === 2.1
  === enter name of disk1 of 2:nvme-eui.0025385c915033c7
  ==> disk1 is /dev/disk/by-id/nvme-eui.0025385c915033c7
  === enter name of disk2 of 2:nvme-eui.0025385c915033ce
  ==> disk2 is /dev/disk/by-id/nvme-eui.0025385c915033ce
  *** enter capital Y to format both disks:Y
  ```
