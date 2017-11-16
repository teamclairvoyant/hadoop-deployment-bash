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

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
# Only available on EL.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

if ! rpm -q tuned; then
  echo "tuned not installed. Exiting."
  exit 0
fi

echo "Configuring tuned..."
if [ "$OSREL" == 6 ]; then
  PROFILE=`tuned-adm active | awk '{print $NF}' | head -1`
  sed -e '/^vm.swappiness/s|= .*|= 1|' -i /etc/tune-profiles/${PROFILE}/sysctl.ktune
fi
if [ "$OSREL" == 7 ]; then
  PROFILE=`tuned-adm active | awk '{print $NF}'`
  if [ "$OS" == CentOS ] && [ "$PROFILE" == balanced ] && ! is_virtual; then
    PROFILE=throughput-performance
  fi
  mkdir /etc/tuned/${PROFILE}
  sed -e '/^vm.swappiness/s|= .*|= 1|' /usr/lib/tuned/${PROFILE}/tuned.conf >/etc/tuned/${PROFILE}/tuned.conf
  chown root:root /etc/tuned/${PROFILE}/tuned.conf
  chmod 0644 /etc/tuned/${PROFILE}/tuned.conf
fi

