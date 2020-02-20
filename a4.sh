#!/bin/bash

if [ $USER != "root" ]; then
        echo "must run as root"
        exit -1
fi

echo "**************************"
echo "*** STARTING a4.sh NOW ***"
echo "**************************"
echo "=== DISK  is [$DISK]"
echo "=== DISK2 is [$DISK2]"

echo "=== 4.9 setting root password"
echo "root:$ROOTPASS" | chpasswd

echo "=== 4.5 configure basic system environment"
ln -s /proc/self/mounts /etc/mtab
echo "=== 4.5 update the new repos"
apt update

echo "=== 4.5 configure locale--make sure en_US.UTF-8 is checked"
#read -p "enter to start configuring locale:" DUMMYV
#dpkg-reconfigure locales
echo "=== select en_US.UTF-8"
# from https://askubuntu.com/questions/683406/how-to-automate-dpkg-reconfigure-locales-with-one-command
echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections
echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections
rm "/etc/locale.gen"
dpkg-reconfigure --frontend noninteractive locales

echo "=== 4.5 configuring time zone data"
#read -p "enter to start configuring time zone data:" DUMMYV
#dpkg-reconfigure tzdata
echo "=== 4.5 set time zone to [Asia/Bangkok]"
# from https://serverfault.com/questions/84521/automate-dpkg-reconfigure-tzdata
rm -rf /etc/localtime; ln -fs /usr/share/zoneinfo/Asia/Bangkok /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

echo "=== 4.5 install nano and openssh-server"
apt install -y nano openssh-server

#read -p "enter to install linux kernel headers" DUMMYV
#echo "about to install linux kernel headers"
#env DISK=$DISK DISK2=$DISK2 RELEASE=$RELEASE bash

echo "=== 4.6 install linux kernel on disks"
#apt install --yes --no-install-recommends linux-image-generic-hwe-18.04
if [[ $RELEASE == "focal" ]]; then
  apt install --yes --no-install-recommends linux-image-$(uname -r)
else
  apt install --yes --no-install-recommends linux-image-generic
fi  
#apt install --yes linux-image-generic-hwe-18.04

echo "=== 4.6 install linux kernel headers on disks"
#apt install --yes --no-install-recommends linux-headers-generic-hwe-18.04
if [[ $RELEASE == "focal" ]]; then
  apt install --yes --no-install-recommends linux-headers-$(uname -r) linux-modules-$(uname -r)
else
  apt install --yes --no-install-recommends linux-headers-generic
fi

if [[ $RELEASE == "focal" ]]; then
  apt install --reinstall linux-headers-$(uname -r) linux-modules-$(uname -r) linux-image-$(uname -r)
fi

#read -p "installed HWE kernel" DUMMYV
#apt install --yes zfs-initramfs 

echo "=== apt install -y software-properties-common"
apt install -y software-properties-common

echo "zfs-dkms zfs-dkms/note-incompatible-licenses note true" | debconf-set-selections
if [[ "$RELEASE" == "focal" ]]; then
  echo "=== focal needs no jonathonf zfs ppa"
else
  echo "=== adding jonathonf zfs ppa"
  add-apt-repository --yes ppa:jonathonf/zfs
fi

# read -p "enter to install initramfs:" DUMMYV
echo "=== installing (jonathonf)/zfs: zfs-initramfs"
apt install --yes zfs-initramfs
# read -p "enter to install libelf-dev and zfs-dkms:" DUMMYV

echo "=== autoconfig libssl in debconf"
# from https://unix.stackexchange.com/questions/146283/how-to-prevent-prompt-that-ask-to-restart-services-when-installing-libpq-dev
echo 'libssl1.1 libraries/restart-without-asking boolean true' | debconf-set-selections
#echo "libssl1.1:amd64 libssl1.1/restart-services string" | debconf-set-selections

echo "=== installing (jonathonf)/zfs: libelf-dev zfs-dkms"
apt install --yes libelf-dev zfs-dkms
#echo "=== systemctl stop zfs-zed"
#systemctl stop zfs-zed
#echo "=== modprobe -r zfs"
#modprobe -r zfs
#echo "=== modprobe zfs"
#modprobe zfs
#echo "=== systemctl start zfs-zed"
#systemctl start zfs-zed
echo "=== zfs --version"
zfs --version
# read -p "enter to continue:" DUMMYV

if [[ "$RELEASE" == "focal" ]]; then
  echo "=== focal does not need latest HWE kernel"
else
  echo "=== upgrade to latest HWE kernel"
  apt install --no-install-recommends -y linux-generic-hwe-18.04
fi

echo "=== 4.6 not needed for unencrypted disks"

echo "=== 4.8.0 install dosfstools"
apt install -y dosfstools
echo "=== 4.8.1 make EFI partition"
mkdosfs -F 32 -s 1 -n EFI ${DISK}-part1
mkdosfs -F 32 -s 1 -n EFI ${DISK2}-part1
echo "=== 4.8.2 make EFI directory"
mkdir /boot/efi
mkdir /boot/efi2

echo "=== 4.8.3 add EFI partitions to /etc/fstab"
echo PARTUUID=$(blkid -s PARTUUID -o value ${DISK}-part1) \
    /boot/efi vfat nofail,x-systemd.device-timeout=1 0 1 >> /etc/fstab
echo PARTUUID=$(blkid -s PARTUUID -o value ${DISK2}-part1) \
    /boot/efi2 vfat nofail,x-systemd.device-timeout=1 0 1 >> /etc/fstab

echo "=== 4.8.4 mount /boot/efi and /boot/efi2"
mount /boot/efi
mount /boot/efi2

echo "=== 4.8.5 install grub-efi"
apt install --yes grub-efi-amd64-signed shim-signed

if [[ $RELEASE == "focal" ]]; then
  apt install --reinstall linux-headers-$(uname -r) linux-modules-$(uname -r) linux-image-$(uname -r)
fi

#echo "=== 4.9 setting root password"
#passwd

echo "=== 4.10 enable zfs-import-bpool.service"
echo "[Unit]
DefaultDependencies=no
Before=zfs-import-scan.service
Before=zfs-import-cache.service
    
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/sbin/zpool import -N -o cachefile=none bpool
    
[Install]
WantedBy=zfs-import.target" \
 > /etc/systemd/system/zfs-import-bpool.service

echo "=== 4.10 systemctl enable zfs-import-bpool.service"
systemctl enable zfs-import-bpool.service

echo "=== 4.11 Mount a tmpfs to /tmp"
cp /usr/share/systemd/tmp.mount /etc/systemd/system/
systemctl enable tmp.mount

echo "=== 4.12 Setup system groups:"
addgroup --system lpadmin
addgroup --system sambashare

if [[ $RELEASE == "focal" ]]; then
  apt install --reinstall linux-headers-$(uname -r) linux-modules-$(uname -r) linux-image-$(uname -r)
fi

echo "=== 5.1 verify that zfs boot filesystem is recognized"
echo "=== running grub-probe /boot"
grub-probe /boot
echo "=== result should say [zfs]"
#read -p "press enter:"

echo "=== 5.2 Refresh the initrd files:"
update-initramfs -u -k all

echo "=== 5.3/5.4 editing grub file"
echo "    Set: GRUB_CMDLINE_LINUX=\"root=ZFS=rpool/ROOT/ubuntu\""
echo "    Comment out: GRUB_TIMEOUT_STYLE=hidden"
echo "    Set: GRUB_TIMEOUT=5"
echo "    Below GRUB_TIMEOUT, add: GRUB_RECORDFAIL_TIMEOUT=5"
echo "    Remove quiet and splash from: GRUB_CMDLINE_LINUX_DEFAULT"
echo "    Uncomment: GRUB_TERMINAL=console"
#cat /etc/default/grub | \
#sed -E 's/(^GRUB_CMDLINE_LINUX=")/\1root=ZFS=rpool\/ROOT\/ubuntu /g' | \
#sed -E 's/(^GRUB_CMDLINE_LINUX=")(.*)([ tab]+)(")/\1\2\4/g' | \
#sed -E 's/(^GRUB_TIMEOUT_STYLE=hidden)/#\1/g' | \
#sed -E 's/(^GRUB_TIMEOUT=)[0-9]+$/\15\nGRUB_RECORDFAIL_TIMEOUT=5/g' | \
#sed -E 's/(^GRUB_CMDLINE_LINUX_DEFAULT=")(.*)(quiet)(.*)(")/\1\2\4\5/g' | \
#sed -E 's/(^GRUB_CMDLINE_LINUX_DEFAULT=")(.*)(splash)(.*)(")/\1\2\4\5/g' | \
#sed -E 's/(^GRUB_CMDLINE_LINUX_DEFAULT=")([ tab]+)(.*)(")/\1\3\4/g' | \
#sed -E 's/(^GRUB_CMDLINE_LINUX_DEFAULT=")(.*)([ tab]+)(")/\1\2\4/g' | \
#sed -E 's/^(#)(GRUB_TERMINAL=console)/\2/g' > /tmp/grubby
cat /etc/default/grub | \
sed -E 's/(^GRUB_CMDLINE_LINUX=")/\1root=ZFS=rpool /g' | \
sed -E 's/(^GRUB_CMDLINE_LINUX=")(.*)([ tab]+)(")/\1\2\4/g' | \
sed -E 's/(^GRUB_TIMEOUT_STYLE=hidden)/#\1/g' | \
sed -E 's/(^GRUB_TIMEOUT=)[0-9]+$/\15\nGRUB_RECORDFAIL_TIMEOUT=5/g' | \
sed -E 's/(^GRUB_CMDLINE_LINUX_DEFAULT=")(.*)(quiet)(.*)(")/\1\2\4\5/g' | \
sed -E 's/(^GRUB_CMDLINE_LINUX_DEFAULT=")(.*)(splash)(.*)(")/\1\2\4\5/g' | \
sed -E 's/(^GRUB_CMDLINE_LINUX_DEFAULT=")([ tab]+)(.*)(")/\1\3\4/g' | \
sed -E 's/(^GRUB_CMDLINE_LINUX_DEFAULT=")(.*)([ tab]+)(")/\1\2\4/g' | \
sed -E 's/^(#)(GRUB_TERMINAL=console)/\2/g' > /tmp/grubby
cp /tmp/grubby /etc/default/grub
rm -f /tmp/grubby

echo "=== 5.4 showing /etc/default/grub"
cat /etc/default/grub
#read -p "enter to continue:" DUMMYV

echo "=== 5.6b install grub (UEFI)"
grub-install --target=x86_64-efi --efi-directory=/boot/efi \
    --bootloader-id=ubuntu --recheck --no-floppy

echo "=== 5.7 Verify that the ZFS module is installed:"
echo "    ls /boot/grub/*/zfs.mod" 
ls /boot/grub/*/zfs.mod
#read -p "=== result above. press enter:" DUMMYV
echo "=== result above."

echo "=== 5.8 Fix filesystem mount ordering"
echo "    umount /boot/efi and /boot/efi2 (for UEFI)"
sleep 3
umount /boot/efi
umount /boot/efi2

echo "=== 5.8 set mountpoint for bpool"
#zfs set mountpoint=legacy bpool/BOOT/ubuntu
zfs set mountpoint=legacy bpool
#echo bpool/BOOT/ubuntu /boot zfs \
#    nodev,relatime,x-systemd.requires=zfs-import-bpool.service 0 0 >> /etc/fstab
echo bpool /boot zfs \
    nodev,relatime,x-systemd.requires=zfs-import-bpool.service 0 0 >> /etc/fstab
#echo "=== 5.8 set mountpoint for rpool/var/log"
#zfs set mountpoint=legacy rpool/var/log
#echo rpool/var/log /var/log zfs nodev,relatime 0 0 >> /etc/fstab
#echo "=== 5.8 set mountpoint for rpool/var/spool"
#zfs set mountpoint=legacy rpool/var/spool
#echo rpool/var/spool /var/spool zfs nodev,relatime 0 0 >> /etc/fstab

#echo "=== 5.8 set mountpoint for /var/tmp dataset:"
#zfs set mountpoint=legacy rpool/var/tmp
#echo rpool/var/tmp /var/tmp zfs nodev,relatime 0 0 >> /etc/fstab
#echo "=== 5.8 set mountpoint for /tmp dataset:"
#zfs set mountpoint=legacy rpool/tmp
#echo rpool/tmp /tmp zfs nodev,relatime 0 0 >> /etc/fstab

#echo "=== 6.1 (NOT) snapshot initial installation"
#zfs snapshot bpool/BOOT/ubuntu@install
#zfs snapshot rpool/ROOT/ubuntu@install

echo "=== mount bpool as /boot to update grub"
mount /boot

echo "=== 5.5 update grub"
sleep 2
update-grub
echo "=== 5.5 Ignore errors from osprober, if present."

echo "=== saving the name of DISK1 and DISK2 to disk1_name and disk2_name"
echo $DISK > /disk1_name
echo $DISK2 > /disk2_name

echo "=== done!"
echo "=== type \"exit\" to leave the chroot environment"

# read -p "enter to exit chroot environment" DUMMYV
