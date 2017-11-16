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

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Removing OpenJDK..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  rpm -e java-1.6.0-openjdk
  rpm -e java-1.7.0-openjdk
  rpm -e java-1.8.0-openjdk
  rpm -e java-1.8.0-openjdk-headless
  rpm -e java-1.5.0-gcj
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  #apt-get -y -q remove openjdk-6-jre
  #apt-get -y -q remove openjdk-6-jre-headless
  #apt-get -y -q remove openjdk-6-jdk
  #apt-get -y -q remove openjdk-7-jre
  #apt-get -y -q remove openjdk-7-jre-headless
  #apt-get -y -q remove openjdk-7-jdk
  #apt-get -y -q remove openjdk-8-jre
  #apt-get -y -q remove openjdk-8-jre-headless
  #apt-get -y -q remove openjdk-8-jdk
  apt-get -y -q remove openjdk\*
fi

