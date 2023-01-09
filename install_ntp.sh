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
# Copyright Clairvoyant 2015

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

DATE=$(date +'%Y%m%d%H%M%S')

# Function to discover basic OS details.
discover_os() {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu, RedHatEnterpriseServer, Debian, SUSE LINUX
    # shellcheck disable=SC2034
    OS=$(lsb_release -is)
    # CentOS= 6.10, 7.2.1511, Ubuntu= 14.04, RHEL= 6.10, 7.5, SLES= 11
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
      if [ -f /etc/almalinux-release ]; then
        # shellcheck disable=SC2034
        OS=AlmaLinux
        # 8.6
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/almalinux-release --qf='%{VERSION}\n')
        # shellcheck disable=SC2034
        OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
      elif [ -f /etc/centos-release ]; then
        # shellcheck disable=SC2034
        OS=CentOS
        # 7.5.1804.4.el7.centos, 6.10.el6.centos.12.3
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/centos-release --qf='%{VERSION}.%{RELEASE}\n' | awk -F. '{print $1"."$2}')
        # shellcheck disable=SC2034
        OSREL=$(rpm -qf /etc/centos-release --qf='%{VERSION}\n')
      else
        # shellcheck disable=SC2034
        OS=RedHatEnterpriseServer
        # 7.5, 6Server
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/redhat-release --qf='%{VERSION}\n')
        if [ "$OSVER" == "6Server" ]; then
          # shellcheck disable=SC2034
          OSVER=$(rpm -qf /etc/redhat-release --qf='%{RELEASE}\n' | awk -F. '{print $1"."$2}')
          # shellcheck disable=SC2034
          OSNAME=Santiago
        else
          # shellcheck disable=SC2034
          OSNAME=Maipo
        fi
        # shellcheck disable=SC2034
        OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
      fi
    elif [ -f /etc/SuSE-release ]; then
      if grep -q "^SUSE Linux Enterprise Server" /etc/SuSE-release; then
        # shellcheck disable=SC2034
        OS="SUSE LINUX"
      fi
      # shellcheck disable=SC2034
      OSVER=$(rpm -qf /etc/SuSE-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
      # shellcheck disable=SC2034
      OSREL=$(rpm -qf /etc/SuSE-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
      # shellcheck disable=SC2034
      OSNAME="n/a"
    fi
  fi
}

is_virtual() {
  grep -Eqi 'VirtualBox|VMware|Parallel|Xen|innotek|QEMU|Virtual Machine|Amazon EC2' /sys/devices/virtual/dmi/id/*
  return $?
}

tinker_ntp.conf() {
  cp -p /etc/ntp.conf /etc/ntp.conf."${DATE}"
  sed -e '/# CLAIRVOYANT$/d' -i /etc/ntp.conf
  # shellcheck disable=SC1004
  sed -e '1i\
# Keep ntpd from panicking in the event of a large clock skew when # CLAIRVOYANT\
# a VM guest is suspended and resumed.                             # CLAIRVOYANT\
tinker panic 0                                                     # CLAIRVOYANT' \
      -i /etc/ntp.conf
}

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] && [ "$OSREL" -ge 8 ]; then
  echo "ERROR: NTP no longer ships with RHEL/CentOS 8. Use chrony instead."
  exit 4
fi

echo "Installing Network Time Protocol..."
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  if [ "$OSREL" == 7 ]; then
    # https://www.centos.org/forums/viewtopic.php?f=47&t=47626
    systemctl disable chronyd.service
  fi
  yum -y -e1 -d1 remove chrony
  yum -y -e1 -d1 install ntp
  if is_virtual; then
    tinker_ntp.conf
  fi
  service ntpdate start
  chkconfig ntpdate on
  service ntpd start
  chkconfig ntpd on
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y -q remove chrony
  apt-get -y -q install ntp
  if is_virtual; then
    tinker_ntp.conf
  fi
  service ntp start
  update-rc.d ntp defaults
fi

