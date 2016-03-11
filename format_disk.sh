#!/bin/bash

DISK=$1
NUM=$2
FS=xfs

if [ -z "$DISK" ]; then
  echo "ERROR: Missing disk argument (ie sdb)."
  exit 1
fi
if [ -z "$NUM" ]; then
  echo "ERROR: Missing mountpoint argument (ie 1)."
  exit 1
fi

if ! rpm -q parted; then echo "Installing parted. Please wait...";yum -y -d1 -e1 install parted; fi

if [ -b /dev/${DISK} -a ! -b /dev/${DISK}1 ]; then
  parted /dev/${DISK} mklabel msdos mkpart primary $FS 1 100%
  mkfs -t $FS /dev/${DISK}1
  sed -i -e '/^\/dev\/${DISK}1/d' /etc/fstab
  echo "/dev/${DISK}1 /data/${NUM} $FS defaults,noatime 1 2" >>/etc/fstab
  mkdir -p /data/${NUM}
  mount /data/${NUM}
fi

