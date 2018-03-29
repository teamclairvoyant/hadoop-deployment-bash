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
# Copyright Clairvoyant 2018

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

is_aws () {
  grep -qi 'amazon' /sys/devices/virtual/dmi/id/*
  return $?
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

echo "Configuring Network Time Protocol..."
# Add in a way to set the "server" lines.
# May need CLI ARG parsing.
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/set-time.html#configure-amazon-time-service
if is_aws; then
  cp -p /etc/ntp.conf /etc/ntp.conf.${DATE}
  sed -e '/# CLAIRVOYANT-AWS$/d' -i /etc/ntp.conf
  sed -e '/^server /s|^server|#server|' \
      -e '/^#server /a\
server 169.254.169.123 prefer iburst                               # CLAIRVOYANT-AWS' \
      -i /etc/ntp.conf
fi
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  service ntpd restart
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  service ntp restart
fi

