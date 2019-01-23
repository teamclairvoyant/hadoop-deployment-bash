#!/bin/bash
# shellcheck disable=SC1090
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
#
# This script installs the Centrify agent.

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
      if [ -f /etc/centos-release ]; then
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

_get_proxy() {
  PROXY=$(grep -Eh '^ *http_proxy=http|^ *https_proxy=http' /etc/profile.d/*)
  eval "$PROXY"
  export http_proxy
  export https_proxy
  if [ -z "$http_proxy" ]; then
    PROXY=$(grep -El 'http_proxy=|https_proxy=' /etc/profile.d/*)
    if [ -n "$PROXY" ]; then
      . "$PROXY"
    fi
  fi
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

echo "Installing Centrify agent..."
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  _get_proxy
  wget -q -c -O /tmp/centrify-suite-2017.3-rhel5-x86_64.tgz https://downloads.centrify.com/products/centrify-suite/2017-update-3/centrify-suite-2017.3-rhel5-x86_64.tgz
  cd /tmp || exit
  tar -xzf centrify-suite-2017.3-rhel5-x86_64.tgz
  yum -y -d1 -e1 install CentrifyDC-openssl-5.4.3-rhel5.x86_64.rpm CentrifyDC-openldap-5.4.3-rhel5.x86_64.rpm CentrifyDC-curl-5.4.3-rhel5.x86_64.rpm CentrifyDC-5.4.3-rhel5.x86_64.rpm
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  _get_proxy
  wget -q -c -O /tmp/centrify-suite-2017.3-deb7-x86_64.tgz https://downloads.centrify.com/products/centrify-suite/2017-update-3/centrify-suite-2017.3-deb7-x86_64.tgz
  cd /tmp || exit
  tar -xzf centrify-suite-2017.3-deb7-x86_64.tgz
  dpkg -i centrifydc-openldap-5.4.3-deb7-x86_64.deb centrifydc-curl-5.4.3-deb7-x86_64.deb centrifydc-openssl-5.4.3-deb7-x86_64.deb centrifydc-5.4.3-deb7-x86_64.deb
fi

