#!/bin/bash

# Update OS

sudo apt update
sudo apt upgrade -y
sudo apt install vim wget git net-tools telnet curl nload -y
sudo timedatectl set-timezone Europe/Istanbul
sudo hostnamectl set-hostname tenant-opsbridge01

# Extend Default Ubuntu OS Disk Size

sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv

# Install yq Tool

sudo wget https://github.com/mikefarah/yq/releases/download/v4.2.0/yq_linux_amd64.tar.gz -O - | tar xz && mv yq_linux_amd64 /usr/bin/yq

# Disable Automatic Upgrades

sudo sed -i 's/APT::Periodic::Unattended-Upgrade "0";/APT::Periodic::Unattended-Upgrade "1";/g' /etc/apt/apt.conf.d/20auto-upgrades