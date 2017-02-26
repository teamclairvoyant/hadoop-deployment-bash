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

VAL=1

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
        OS=RedHat
      fi
      OSVER=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n" | awk -F. '{print $1"."$2}'`
      OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
    fi
  fi
}

# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHat -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

sysctl -w vm.swappiness=$VAL

if [ "$OS" == RedHat -o "$OS" == CentOS ]; then
  if [ $OSREL == 6 ]; then
    if grep -q vm.swappiness /etc/sysctl.conf; then
      sed -i -e "/^vm.swappiness/s|=.*|= $VAL|" /etc/sysctl.conf
    else
      echo "vm.swappiness = $VAL" >>/etc/sysctl.conf
    fi
  else
    if grep -q vm.swappiness /etc/sysctl.conf; then
      sed -i -e '/^vm.swappiness/d' /etc/sysctl.conf
    fi
    echo "# Tuning for Hadoop installation." >/etc/sysctl.d/cloudera.conf
    echo "vm.swappiness = $VAL" >>/etc/sysctl.d/cloudera.conf
  fi
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  if grep -q vm.swappiness /etc/sysctl.conf; then
    sed -i -e '/^vm.swappiness/d' /etc/sysctl.conf
  fi
  echo "# Tuning for Hadoop installation." >/etc/sysctl.d/cloudera.conf
  echo "vm.swappiness = $VAL" >>/etc/sysctl.d/cloudera.conf
fi

