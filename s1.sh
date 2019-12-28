#!/bin/bash

echo "=== 1.2 adding universe repo and update"
sudo apt-add-repository universe
sudo apt update
echo "=== 1.3 install openssh-server"
sudo apt install -y openssh-server
echo "======================="
echo "=== note IP address ==="
echo "======================="
ip a
echo "=== 1.3changing password for ssh login"
passwd

echo "==="
echo "=== STEP 1.3 finished, run s2.sh as root next"
echo "==="
