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

# Disable Automatic Upgrades

sudo sed -i 's/APT::Periodic::Unattended-Upgrade "1";/APT::Periodic::Unattended-Upgrade "0";/g' /etc/apt/apt.conf.d/20auto-upgrades

# Change NTP Servers

sudo sed -i 's/NTP=ntp01.arabam.com/NTP=0.tr.pool.ntp.org/g' /etc/systemd/timesyncd.conf
sudo sed -i 's/FallbackNTP=ntp02.arabam.com/FallbackNTP=1.tr.pool.ntp.org/g' /etc/systemd/timesyncd.conf

# Restart Timesync Service On Ubuntu Server

sudo systemctl restart systemd-timesyncd
