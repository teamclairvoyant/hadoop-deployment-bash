#!/bin/bash
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Copyright Clairvoyant 2016

DISK=$1
NUM=$2
FS=xfs
LABEL=gpt
LABEL=msdos

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
  parted -s /dev/${DISK} mklabel $LABEL mkpart primary $FS 1 100%
  sleep 2
  mkfs -t $FS /dev/${DISK}1 && \
  sed -i -e '/^\/dev\/${DISK}1/d' /etc/fstab && \
  echo "/dev/${DISK}1 /data/${NUM} $FS defaults,noatime 1 2" >>/etc/fstab && \
  mkdir -p /data/${NUM} && \
  chattr +i /data/${NUM} && \
  mount /data/${NUM}
fi

