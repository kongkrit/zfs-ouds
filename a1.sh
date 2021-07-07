#!/bin/bash

function debug () {
  if [[ ! -z $DEBUG ]]; then
    echo "******** debug: $1 ********"
    echo "******** exit to continue *******"
    bash
  fi
}

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

# install necessary tools and stop zed
apt install -y debootstrap gdisk zfs-initramfs
systemctl stop zed

# get ubuntu release name (bionic, disco, focal, etc.)
RELEASE="$(lsb_release -a | sed -nE '/Codename:/p' | sed -E 's/Codename:[ \t]+//g')"

echo "********************************"
echo "*** UBUNTU Release is [$RELEASE]"
echo "********************************"

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

echo "=== list disks"
ls -alF /dev/disk/by-id/
echo "=== 2.1"
read -p "=== enter name of disk1 of 2:" DISK1
DISK1=/dev/disk/by-id/$DISK1
echo "==> disk1 is $DISK1"
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

debug "after apt-add"

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
# apt install --yes debootstrap gdisk

echo "=== 2.2 formatting both disks"
sgdisk --zap-all $DISK1 ; udevadm settle
sgdisk --zap-all $DISK2 ; udevadm settle
#wipefs --all $DISK1
#wipefs --all $DISK2

echo "=== 2.3 creating paritions for UEFI booting (EFI partition)"
sgdisk -n1:1M:+512M -t1:EF00 $DISK1
sgdisk -n1:1M:+512M -t1:EF00 $DISK2
echo "=== 2.3 creating boot pool"
sgdisk -n2:0:+2G -t2:BE00 $DISK1
sgdisk -n2:0:+2G -t2:BE00 $DISK2
echo "=== 2.3a creating root pool (unencrypted)"
sgdisk     -n3:0:0        -t3:BF00 $DISK1
sgdisk     -n3:0:0        -t3:BF00 $DISK2

echo "=== 2.3a done, issue udevadm settle"
udevadm settle
echo "=== 2.3a udevadm settle done, sleeping for 3 seconds"
sleep 3

echo "=== 2.3b create FAT for EFI partitions"
mkfs.fat -F 32 -n EFI "${DISK1}-part1"
mkfs.fat -F 32 -n EFI "${DISK2}-part1"

echo "=== 2.5a creating root pool mirror (unencrypted)"
#zpool create -o ashift=13 \
#    -O acltype=posixacl -O canmount=off -O compression=lz4 \
#    -O dnodesize=auto -O normalization=formD -O atime=off -O xattr=sa \
#    -O mountpoint=/ -R /mnt rpool mirror ${DISK1}-part3 ${DISK2}-part3
zpool create \
    -o ashift=13 -o autotrim=on \
    -O acltype=posixacl -O canmount=off -O compression=lz4 \
    -O dnodesize=auto -O normalization=formD -O atime=off \
    -O xattr=sa -O mountpoint=/ -R /mnt \
    rpool mirror ${DISK1}-part3 ${DISK2}-part3

echo "=== 2.4 creating boot pool (mirrored)"
#zpool create -o ashift=13 \
#    -O acltype=posixacl -O canmount=off -O compression=lz4 -O atime=off -O xattr=sa \
#    -O mountpoint=/ -R /mnt bpool mirror ${DISK1}-part2 ${DISK2}-part2
zpool create \
    -o cachefile=/etc/zfs/zpool.cache \
    -o ashift=13 -o autotrim=on -d \
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
    -O acltype=posixacl -O canmount=off -O compression=lz4 \
    -O devices=off -O normalization=formD -O atime=off -O xattr=sa \
    -O mountpoint=/boot -R /mnt \
    bpool mirror ${DISK1}-part2 ${DISK2}-part2

# create containers
zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o canmount=off -o mountpoint=none bpool/BOOT

# create filesystem for ROOT and BOOT
#UUID=$(dd if=/dev/urandom bs=1 count=100 2>/dev/null |
#    tr -dc 'a-z0-9' | cut -c-6)
UUID=$(date +%y%m%d)

zfs create -o mountpoint=/ \
    -o com.ubuntu.zsys:bootfs=yes \
    -o com.ubuntu.zsys:last-used=$(date +%s) rpool/ROOT/ubuntu_$UUID

zfs create -o mountpoint=/boot bpool/BOOT/ubuntu_$UUID

#echo "=== 3.3 Create datasets:"
#echo "=== 3.3 exclude /var/tmp /var/cache from snapshots"1
#echo "=== 3.3 create /opt /srv /usr /usr/local /var/games"
#echo "===     /var/mail /var/snap /var/www docker nfs tmpfs"

# create dataset for user
zfs create rpool/ROOT/ubuntu_$UUID/var

# create userdata
zfs create -o canmount=off -o mountpoint=/ \
    rpool/USERDATA
zfs create -o com.ubuntu.zsys:bootfs-datasets=rpool/ROOT/ubuntu_$UUID \
    -o canmount=on -o mountpoint=/root \
    rpool/USERDATA/root_$UUID
chmod 700 /mnt/root

# For a mirror or raidz topology, create a dataset for /boot/grub
zfs create -o com.ubuntu.zsys:bootfs=no bpool/grub

# mount a tmpfs at /run
mkdir /mnt/run
mount -t tmpfs tmpfs /mnt/run
mkdir /mnt/run/lock

# create dataset for /tmp
# zfs create -o com.ubuntu.zsys:bootfs=no \
#     rpool/ROOT/ubuntu_$UUID/tmp
# chmod 1777 /mnt/tmp

echo "=== 3.4 Install the minimal system:"
echo "=== 3.4 debootstrap to /mnt"
debootstrap "$RELEASE" /mnt

echo "=== copy in zpool.cache:"
mkdir /mnt/etc/zfs
cp /etc/zfs/zpool.cache /mnt/etc/zfs/

# echo "=== 3.4 zfs set devices=off rpool"
# zfs set devices=off rpool

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
cat << EOF >> /mnt/etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    ${INTF}:
      dhcp4: true
#      dhcp4: no
#      addresses: [192.168.1.110/24, ]
#      gateway4:  192.168.1.1
#      nameservers:
#              addresses: [8.8.8.8, 8.8.4.4]
EOF
echo "=== 4.2 wrote /mnt/etc/netplan/01-netcfg.yaml"

echo "=== 4.3 Configure the package sources in /mnt/etc/apt/sources.list:"

cat << EOF > /mnt/etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu $RELEASE main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $RELEASE-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $RELEASE-backports main restricted universe multiverse
# deb http://archive.ubuntu.com/ubuntu $RELEASE-proposed main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu $RELEASE-security main restricted universe multiverse
EOF

echo "-------- begin content of /mnt/etc/apt/sources.list --------"
cat /mnt/etc/apt/sources.list
echo "-------- end content of /mnt/etc/apt/sources.list --------"

echo "=== 4.4 Bind the virtual filesystems from the LiveCD environment to the new system"
mount --rbind /dev  /mnt/dev
mount --rbind /proc /mnt/proc
mount --rbind /sys  /mnt/sys

#echo "=== 4.4 listing disks"

echo "=== copying $NEXT4FILE to new root"
cp $NEXT4FILE /mnt
echo "=== copying $NEXT6CFILE to new root"
cp $NEXT6CFILE /mnt

echo "==="
#echo "=== 4.4 doing chroot, when bash prompt comes, execute a4.sh"
echo "=== 4.4 doing chroot to /mnt and execute /a4.sh"
echo "==="
#chroot /mnt /usr/bin/env DISK1=$DISK1 DISK2=$DISK2 bash --login

#echo "=== before chroot"
#echo "=== /usr/bin/env DISK1=$DISK1 DISK2=$DISK2 ROOTPASS=$ROOTPASS RELEASE=$RELEASE bash"
#/usr/bin/env DISK1=$DISK1 DISK2=$DISK2 ROOTPASS=$ROOTPASS RELEASE=$RELEASE bash

chroot /mnt /usr/bin/env DISK1=$DISK1 DISK2=$DISK2 ROOTPASS=$ROOTPASS RELEASE=$RELEASE UUID=$UUID bash /a4.sh
echo "=== 4.4 done chroot"

echo "=== pre 6.3 sleep 3 seconds"
sleep 3
echo "=== 6.3 unmount all filesystems in the LiveCD environment:"
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export -a

echo "=== 6.4 about to reboot, then login as root"
read -p "press enter to reboot:" DUMMYV
reboot
