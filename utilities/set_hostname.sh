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

# ARGV:
# 1 - Name to set on the local machine - required

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

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

H=$1
if [ -z "$H" ]; then
  echo "ERROR: Missing hostname."
  exit 1
fi

echo "Setting hostname to ${H}..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  if [ $OSREL == 6 ]; then
    sed -e "/^HOSTNAME=/s|=.*|=$H|" -i /etc/sysconfig/network
  else
    hostnamectl set-hostname $H
  fi
  hostname $H

  if rpm -q cloud-init; then
    echo 'preserve_hostname: True' >/etc/cloud/cloud.cfg.d/04_hostname.cfg
    chown root:root /etc/cloud/cloud.cfg.d/04_hostname.cfg
    chmod 0644 /etc/cloud/cloud.cfg.d/04_hostname.cfg
  fi
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  hostnamectl set-hostname $H || \
  echo "$H" >/etc/hostname && hostname $H
fi

