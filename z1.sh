#!/bin/bash

echo === add universe repo ===
sudo apt-add-repository universe
sudo apt update
sudo apt install -y openssh-server
echo =======================
echo === note IP address ===
echo =======================
ip a
echo === changing password for ssh login
passwd
