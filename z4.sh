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
