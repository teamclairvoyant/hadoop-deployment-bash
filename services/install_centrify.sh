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
    # CentOS, Ubuntu
    # shellcheck disable=SC2034
    OS=$(lsb_release -is)
    # 7.2.1511, 14.04
    # shellcheck disable=SC2034
    OSVER=$(lsb_release -rs)
    # 7, 14
    # shellcheck disable=SC2034
    OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    # trusty, wheezy, Final
    # shellcheck disable=SC2034
    OSNAME=$(lsb_release -cs)
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        # shellcheck disable=SC2034
        OS=CentOS
      else
        # shellcheck disable=SC2034
        OS=RedHatEnterpriseServer
      fi
      # shellcheck disable=SC2034
      OSVER=$(rpm -qf /etc/redhat-release --qf='%{VERSION}.%{RELEASE}\n')
      # shellcheck disable=SC2034
      OSREL=$(rpm -qf /etc/redhat-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
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

