#!/bin/bash

if [ $USER != "root" ]; then
  echo "must run as root"
  exit -1
fi

NEXT4FILE="a4.sh"
if [[ -f "$NEXT4FILE" ]]; then
    echo "$NEXT4FILE exists. ok"
else
  echo "$NEXT4FILE doesn't exist. get it before running script again"
  exit -1
fi

NEXT6CFILE="a6c.sh"
if [[ -f "$NEXT6CFILE" ]]; then
    echo "$NEXT6CFILE exists. ok"
else
  echo "$NEXT6CFILE doesn't exist. get it before running script again"
  exit -1
fi

echo "********************"
echo "*** IN a1.sh now ***"
echo "********************"

echo "*********************************"
echo "*** REQUIRING USER INPUT HERE ***"
echo "*********************************"

echo "=== 4.1 configure new machine name"
echo "===     current name is [$HOSTNAME]"
read -p "4.1 Enter new hostname:" HOSTNAME
echo "=== 4.1 entered hostname as [$HOSTNAME]"
read -p "4.1 Enter Fully Qualified Domain Name (FQDN) (blank if unsure):" FQDN
echo "=== 4.1 entered FQDN as [$FQDN]"

echo "=== 4.2 Configure the network interface:"
ip addr show
read -p "=== 4.2 enter inface name (excluding colon):" INTF

echo -n "=== Enter root password (1st time):"
read -s ROOTPASS
echo ""
echo -n "=== Enter root password (2nd time):"
read -s ROOTPASS2
echo ""

if [[ -z "$ROOTPASS" ]]; then
  echo "empty password!"
  exit -1
fi

if [[ "$ROOTPASS" == "$ROOTPASS2" ]]; then
  echo "passwords match"
else
  echo "passwords do not match. error."
  exit -1
fi

echo "=== ubuntu mirrors additions"
read -p "   want to add fast mirrors to normal apt mirrors (recommended)? [Y/n]:" CONFIRMIT
FAST_MIRROR="http://mirror.math.princeton.edu/pub/ubuntu"
if [[ $CONFIRMIT == "" || $CONFIRMIT == "Y" || $CONFIRMIT == "y" ]]; then
  echo "=== press enter to add recommended URL to apt sources or enter your own URL:"
  read -p "   enter mirror URL [$FAST_MIRROR]: " MIRROR_URL
  if [[ ! -z "$MIRROR_URL" ]]; then
    FAST_MIRROR=$MIRROR_URL
  fi
  echo "=== using mirror [$FAST_MIRROR]"
  MODAPT=1
else
  MODAPT=0
fi

echo "=== 1.2 adding universe repo and update"
apt-add-repository universe

if [ $MODAPT -eq 1 ]; then
  sed -i.bak -E 's;^deb http[^ \t]+[ \t]+(.*)$;deb '"$FAST_MIRROR"' \1;g' /etc/apt/sources.list
#echo "# ubuntu repos
#deb cdrom:[Ubuntu 18.04.3 LTS _Bionic Beaver_ - Release amd64 (20190805)]/ bionic main restricted
#deb http://mirror.math.princeton.edu/pub/ubuntu bionic main restricted
#deb http://mirror.math.princeton.edu/pub/ubuntu bionic-updates main restricted
#deb http://mirror.math.princeton.edu/pub/ubuntu bionic-security main restricted" \
# > /etc/apt/sources.list
fi

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

echo "*************************************"
echo "*** DONE GATHERING INFO FROM USER ***"
echo "*************************************"

echo "=== adding jonathonf zfs ppa"
echo "zfs-dkms zfs-dkms/note-incompatible-licenses note true" | debconf-set-selections
add-apt-repository --yes ppa:jonathonf/zfs

echo "=== 1.2 apt update"
apt update

echo "=== installing jonathonf/zfs" 
apt install --yes libelf-dev zfs-dkms
echo "=== systemctl stop zfs-zed"
systemctl stop zfs-zed
echo "=== modprobe -r zfs"
modprobe -r zfs
echo "=== modprobe zfs"
modprobe zfs
echo "=== systemctl start zfs-zed"
systemctl start zfs-zed
echo "=== zfs --version"
zfs --version
# read -p "enter to continue:" DUMMYV

echo "=== 1.3 install openssh-server"
apt install -y openssh-server
echo "======================="
echo "=== note IP address ==="
echo "======================="
ip a
# read -p "enter to continue:" DUMMYV

#echo "=== 1.5 install debootstrap gdisk and zfs"
#apt install --yes debootstrap gdisk zfs-initramfs
echo "=== 1.5 install debootstrap gdisk"
apt install --yes debootstrap gdisk

echo "=== 2.2 formatting both disks"
sgdisk --zap-all $DISK
sgdisk --zap-all $DISK2
#wipefs --all $DISK
#wipefs --all $DISK2

echo "=== 2.3 creating paritions for UEFI booting (EFI partition)"
sgdisk -n1:1M:+512M -t1:EF00 $DISK
sgdisk -n1:1M:+512M -t1:EF00 $DISK2
echo "=== 2.3 creating boot pool"
sgdisk -n2:0:+512M -t2:BF01 $DISK
sgdisk -n2:0:+512M -t2:BF01 $DISK2
echo "=== 2.3a creating root pool (unencrypted)"
sgdisk     -n3:0:0        -t3:BF01 $DISK
sgdisk     -n3:0:0        -t3:BF01 $DISK2

echo "=== 2.3a done, issue udevadm settle"
udevadm settle
echo "=== 2.3a udevadm settle done, sleeping for 3 seconds"
sleep 3

echo "=== 2.3b create FAT for EFI partitions"
mkfs.fat -F 32 -n EFI "${DISK}-part1"
mkfs.fat -F 32 -n EFI "${DISK2}-part1"

echo "=== 2.5a creating root pool mirror (unencrypted)"
#zpool create -o ashift=13 \
#    -O acltype=posixacl -O canmount=off -O compression=lz4 \
#    -O dnodesize=auto -O normalization=formD -O atime=off -O xattr=sa \
#    -O mountpoint=/ -R /mnt rpool mirror ${DISK}-part3 ${DISK2}-part3
zpool create -o ashift=13 \
    -O acltype=posixacl -O compression=lz4 \
    -O dnodesize=auto -O normalization=formD -O atime=off -O xattr=sa \
    -O canmount=noauto -O mountpoint=/ -R /mnt -f \
    rpool mirror ${DISK}-part3 ${DISK2}-part3

echo "=== 2.4 creating boot pool (mirrored)"
#zpool create -o ashift=13 \
#    -O acltype=posixacl -O canmount=off -O compression=lz4 -O atime=off -O xattr=sa \
#    -O mountpoint=/ -R /mnt bpool mirror ${DISK}-part2 ${DISK2}-part2
zpool create -o ashift=13 \
    -O acltype=posixacl -O compression=lz4 -O atime=off -O xattr=sa \
    -O canmount=noauto -O mountpoint=/boot -R /mnt -f \
    bpool mirror ${DISK}-part2 ${DISK2}-part2

#echo "...bashing..."
#bash -
#echo "...done bashing..."

#echo "=== 3.1 Create filesystem datasets to act as containers"
#zfs create -o canmount=off -o mountpoint=none rpool/ROOT
#zfs create -o canmount=off -o mountpoint=none bpool/BOOT

#echo "=== 3.2 Create filesystem datasets for the root and boot filesystems:"
#zfs create -o canmount=noauto -o mountpoint=/ rpool/ROOT/ubuntu
#zfs mount rpool/ROOT/ubuntu
#zfs create -o canmount=noauto -o mountpoint=/boot bpool/BOOT/ubuntu
#zfs mount bpool/BOOT/ubuntu

#echo "=== 3.2X mount bpool and rpool"
#zfs mount bpool
#zfs mount rpool

#echo "=== 3.3 Create datasets:"
#echo "=== 3.3 exclude /var/tmp /var/cache from snapshots"1
#echo "=== 3.3 create /opt /srv /usr /usr/local /var/games"
#echo "===     /var/mail /var/snap /var/www docker nfs tmpfs"

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

echo "=== 4.2 Configure the network interface [${INTF}:]"
# ip addr show
# read -p "=== 4.2 enter inface name (excluding colon):" INTF
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
if [ $MODAPT -eq 1 ]; then
echo "# ubuntu repos
deb http://mirror.math.princeton.edu/pub/ubuntu bionic main restricted universe multiverse
deb http://mirror.math.princeton.edu/pub/ubuntu bionic-updates main restricted universe multiverse
deb http://mirror.math.princeton.edu/pub/ubuntu bionic-backports main restricted universe multiverse
deb http://mirror.math.princeton.edu/pub/ubuntu bionic-security main restricted universe multiverse" \
 > /mnt/etc/apt/sources.list
else
echo "# ubuntu repos
deb http://archive.ubuntu.com/ubuntu bionic main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu bionic main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu bionic-updates main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu bionic-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu bionic-backports main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu bionic-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu bionic-security main restricted universe multiverse" \
 > /mnt/etc/apt/sources.list
fi

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

echo "=== copying $NEXT4FILE to new root"
cp $NEXT4FILE /mnt
echo "=== copying $NEXT6CFILE to new root"
cp $NEXT6CFILE /mnt

echo "==="
#echo "=== 4.4 doing chroot, when bash prompt comes, execute a4.sh"
echo "=== 4.4 doing chroot to /mnt and execute /a4.sh"
echo "==="
#chroot /mnt /usr/bin/env DISK=$DISK DISK2=$DISK2 bash --login
chroot /mnt /usr/bin/env DISK=$DISK DISK2=$DISK2 ROOTPASS=$ROOTPASS bash /a4.sh
echo "=== 4.4 done chroot"

echo "=== 6.3 unmount all filesystems in the LiveCD environment:"
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export -a

echo "=== 6.4 about to reboot, then login as root"
read -p "press enter to reboot:" DUMMYV
reboot
