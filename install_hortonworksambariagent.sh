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
# Copyright Clairvoyant 2017

# ARGV:
# 1 - Ambari server hostname - required
# 2 - Ambari agent version - optional
AMBVERSION=2.5.2.0

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=$(lsb_release -is)
    # 7.2.1511, 14.04
    OSVER=$(lsb_release -rs)
    # 7, 14
    OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    # trusty, wheezy, Final
    OSNAME=$(lsb_release -cs)
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=$(rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n")
      OSREL=$(rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}')
    fi
  fi
}

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

AMBHOST=$1
if [ -z "$AMBHOST" ]; then
  echo "ERROR: Missing Ambari server hostname."
  exit 1
fi
AMBVERSION=${2:-$AMBVERSION}

PROXY=$(egrep -h '^ *http_proxy=http|^ *https_proxy=http' /etc/profile.d/*)
eval "$PROXY"
export http_proxy
export https_proxy
if [ -z "$http_proxy" ]; then
  PROXY=$(egrep -l 'http_proxy=|https_proxy=' /etc/profile.d/*)
  if [ -n "$PROXY" ]; then
    . "$PROXY"
  fi
fi

echo "Installing Hortonworks Ambari Agent..."
echo "AMB server is: $AMBHOST"
echo "AMB version is: $AMBVERSION"
OS_LOWER=$(echo "$OS" | tr '[:upper:]' '[:lower:]')
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  # Because it may have been put there by some other process.
  if [ ! -f /etc/yum.repos.d/ambari.repo ]; then
    wget -q http://public-repo-1.hortonworks.com/ambari/${OS_LOWER}${OSREL}/2.x/updates/${AMBVERSION}/ambari.repo -O /etc/yum.repos.d/ambari.repo
    chown root:root /etc/yum.repos.d/ambari.repo
    chmod 0644 /etc/yum.repos.d/ambari.repo
  fi
  yum -y -e1 -d1 install ambari-agent
  sed -i -e "/^hostname/s|=.*|=${AMBHOST}|" /etc/ambari-agent/conf/ambari-agent.ini
  service ambari-agent start
  chkconfig ambari-agent on
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  # Because it may have been put there by some other process.
  if [ ! -f /etc/apt/sources.list.d/ambari.list ]; then
    wget -q http://public-repo-1.hortonworks.com/ambari/${OS_LOWER}${OSREL}/2.x/updates/${AMBVERSION}/ambari.list -O /etc/apt/sources.list.d/ambari.list
    chown root:root /etc/apt/sources.list.d/ambari.list
    chmod 0644 /etc/apt/sources.list.d/ambari.list
    apt-key adv --recv-keys --keyserver keyserver.ubuntu.com B9733A7A07513CAD
  fi
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y -qq update
  apt-get -y -q install ambari-agent
  sed -i -e "/^hostname/s|=.*|=${AMBHOST}|" /etc/ambari-agent/conf/ambari-agent.ini
  service ambari-agent start
  update-rc.d ambari-agent defaults
fi

