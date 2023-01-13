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

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

# ARGV:
# 1 - Name of disk (ie sda) - required
# 2 - Mountpoint number (ie 2 for /data/2) - required

# Function to discover basic OS details.
discover_os() {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu, RedHatEnterpriseServer, RedHatEnterprise, Debian, SUSE LINUX, OracleServer
    # shellcheck disable=SC2034
    OS=$(lsb_release -is)
    # CentOS= 6.10, 7.2.1511, Ubuntu= 14.04, RHEL= 6.10, 7.5, SLES= 11, OEL= 7.6
    # shellcheck disable=SC2034
    OSVER=$(lsb_release -rs)
    # 7, 14
    # shellcheck disable=SC2034
    OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    # Ubuntu= trusty, wheezy, CentOS= Final, RHEL= Santiago, Maipo, SLES= n/a
    # shellcheck disable=SC2034
    OSNAME=$(lsb_release -cs)
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        # shellcheck disable=SC2034
        OS=CentOS
        # shellcheck disable=SC2034
        OSREL=$(rpm -qf /etc/centos-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
        # shellcheck disable=SC2034
        OSNAME=$(awk -F"[()]" '{print $2}' /etc/centos-release | sed 's| ||g')
        if [ -z "$OSNAME" ]; then
          # shellcheck disable=SC2034
          OSNAME="n/a"
        fi
        if [ "$OSREL" -le "6" ]; then
          # 6.10.el6.centos.12.3
          # shellcheck disable=SC2034
          OSVER=$(rpm -qf /etc/centos-release --qf='%{VERSION}.%{RELEASE}\n' | awk -F. '{print $1"."$2}')
        elif [ "$OSREL" == "7" ]; then
          # 7.5.1804.4.el7.centos
          # shellcheck disable=SC2034
          OSVER=$(rpm -qf /etc/centos-release --qf='%{VERSION}.%{RELEASE}\n' | awk -F. '{print $1"."$2"."$3}')
        elif [ "$OSREL" == "8" ]; then
          if [ "$(rpm -qf /etc/centos-release --qf='%{NAME}\n')" == "centos-stream-release" ]; then
            # shellcheck disable=SC2034
            OS=CentOSStream
            # shellcheck disable=SC2034
            OSVER=$(rpm -qf /etc/centos-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
          else
            # shellcheck disable=SC2034
            OSVER=$(rpm -qf /etc/centos-release --qf='%{VERSION}.%{RELEASE}\n' | awk -F. '{print $1"."$2"."$4}')
          fi
        else
          # shellcheck disable=SC2034
          OS=CentOSStream
          # shellcheck disable=SC2034
          OSVER=$(rpm -qf /etc/centos-release --qf='%{VERSION}\n')
        fi
      elif [ -f /etc/oracle-release ]; then
        # shellcheck disable=SC2034
        OS=OracleServer
        # 7.6
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/oracle-release --qf='%{VERSION}\n')
        # shellcheck disable=SC2034
        OSNAME="n/a"
      else
        # shellcheck disable=SC2034
        OS=RedHatEnterpriseServer
        # 8.6, 7.5, 6Server
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/redhat-release --qf='%{VERSION}\n')
        # shellcheck disable=SC2034
        OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
        if [ "$OSVER" == "6Server" ]; then
          # shellcheck disable=SC2034
          OSVER=$(rpm -qf /etc/redhat-release --qf='%{RELEASE}\n' | awk -F. '{print $1"."$2}')
        elif [ "$OSREL" == "8" ]; then
          # shellcheck disable=SC2034
          OS=RedHatEnterprise
        fi
        # shellcheck disable=SC2034
        OSNAME=$(awk -F"[()]" '{print $2}' /etc/redhat-release | sed 's| ||g')
      fi
      # shellcheck disable=SC2034
      OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    elif [ -f /etc/SuSE-release ]; then
      if grep -q "^SUSE Linux Enterprise Server" /etc/SuSE-release; then
        # shellcheck disable=SC2034
        OS="SUSE LINUX"
      fi
      # shellcheck disable=SC2034
      OSVER=$(rpm -qf /etc/SuSE-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
      # shellcheck disable=SC2034
      OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
      # shellcheck disable=SC2034
      OSNAME="n/a"
    fi
  fi
}

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != OracleServer ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

DISK=$1
NUM=$2

if [ -z "$DISK" ]; then
  echo "ERROR: Missing disk argument (ie sdb)."
  exit 1
fi
if [ -z "$NUM" ]; then
  echo "ERROR: Missing mountpoint argument (ie 1)."
  exit 1
fi
if [ ! -b "/dev/${DISK}" ]; then
  echo "ERROR: Disk device /dev/${DISK} does not exist."
  exit 2
fi

SIZE=$(lsblk --all --bytes --list --output NAME,SIZE,TYPE "/dev/${DISK}" | awk '/disk$/{print $2}')
if [ "$SIZE" -ge 2199023255552 ]; then
  LABEL=gpt
else
  LABEL=msdos
fi

if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ]; then
  FS=xfs
  if ! rpm -q parted; then echo "Installing parted. Please wait...";yum -y -d1 -e1 install parted; fi
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  FS=ext4
  export DEBIAN_FRONTEND=noninteractive
  if ! dpkg -l parted >/dev/null; then echo "Installing parted. Please wait...";apt-get -y -q install parted; fi
fi

if [ ! -b "/dev/${DISK}1" ] && [ ! -b "/dev/${DISK}p1" ]; then
  if blkid "/dev/${DISK}" | grep -q '^.*'; then
    echo "WARNING: Data detected on bare disk.  Exiting."
    exit 4
  fi
  echo "Formatting disk /dev/${DISK} as ${FS} ..."
  parted -s "/dev/${DISK}" mklabel "$LABEL" mkpart primary "$FS" 1 100%
  sleep 2
  if [ -b "/dev/${DISK}1" ]; then
    PART="1"
  elif [ -b "/dev/${DISK}p1" ]; then
    PART="p1"
  else
    echo "WARNING: Cannot find partition for /dev/${DISK} .  Exiting."
    exit 5
  fi
  mkfs -t "$FS" "/dev/${DISK}${PART}" && \
  sed -i -e "/^\\/dev\\/${DISK}${PART}/d" /etc/fstab && \
  echo "/dev/${DISK}${PART} /data/${NUM} $FS defaults,noatime 1 2" >>/etc/fstab && \
  mkdir -p "/data/${NUM}" && \
  chattr +i "/data/${NUM}" && \
  mount "/data/${NUM}"
  echo "Disk /dev/${DISK}${PART} mounted at /data/${NUM}"
  if [ "$FS" == ext4 ]; then
    tune2fs -m 0 "/dev/${DISK}${PART}"
  fi
else
  echo "WARNING: Existing partition detected on disk.  Exiting."
  exit 6
fi

