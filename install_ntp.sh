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

DATE=`date +'%Y%m%d%H%M%S'`

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=`lsb_release -is`
    # 7.2.1511, 14.04
    OSVER=`lsb_release -rs`
    # 7, 14
    OSREL=`echo $OSVER | awk -F. '{print $1}'`
    # trusty, wheezy, Final
    OSNAME=`lsb_release -cs`
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n"`
      OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}'`
    fi
  fi
}

is_virtual () {
  egrep -qi 'VirtualBox|VMware|Parallel|Xen|innotek|QEMU|Virtual Machine' /sys/devices/virtual/dmi/id/*
  return $?
}

tinker_ntp.conf () {
  cp -p /etc/ntp.conf /etc/ntp.conf.${DATE}
  sed -e '/# CLAIRVOYANT$/d' -i /etc/ntp.conf
  sed -e '1i\
# Keep ntpd from panicking in the event of a large clock skew when # CLAIRVOYANT\
# a VM guest is suspended and resumed.                             # CLAIRVOYANT\
tinker panic 0                                                     # CLAIRVOYANT' \
      -i /etc/ntp.conf
}

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Installing Network Time Protocol..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  if [ $OSREL == 7 ]; then
    # https://www.centos.org/forums/viewtopic.php?f=47&t=47626
    systemctl disable chronyd.service
  fi
  yum -y -e1 -d1 install ntp
  if is_virtual; then
    tinker_ntp.conf
  fi
  service ntpd start
  chkconfig ntpd on
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y -q install ntp
  if is_virtual; then
    tinker_ntp.conf
  fi
  service ntp start
  update-rc.d ntp defaults
fi

