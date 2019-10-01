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
# Copyright Clairvoyant 2017

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

# ARGV:
# 1 - Ambari server hostname - required
# 2 - Ambari agent version - optional
AMBVERSION=2.5.2.0

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

echo "********************************************************************************"
echo "*** $(basename "$0")"
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

echo "Installing Hortonworks Ambari Agent..."
echo "AMB server is: $AMBHOST"
echo "AMB version is: $AMBVERSION"
OS_LOWER=$(echo "$OS" | tr '[:upper:]' '[:lower:]')
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  # Because it may have been put there by some other process.
  if [ ! -f /etc/yum.repos.d/ambari.repo ]; then
    wget -q "http://public-repo-1.hortonworks.com/ambari/${OS_LOWER}${OSREL}/2.x/updates/${AMBVERSION}/ambari.repo" -O /etc/yum.repos.d/ambari.repo
    RETVAL=$?
    if [ "$RETVAL" -ne 0 ]; then
      echo "** ERROR: Could not download http://public-repo-1.hortonworks.com/ambari/${OS_LOWER}${OSREL}/2.x/updates/${AMBVERSION}/ambari.repo"
      exit 4
    fi
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
    wget -q "http://public-repo-1.hortonworks.com/ambari/${OS_LOWER}${OSREL}/2.x/updates/${AMBVERSION}/ambari.list" -O /etc/apt/sources.list.d/ambari.list
    RETVAL=$?
    if [ "$RETVAL" -ne 0 ]; then
      echo "** ERROR: Could not download http://public-repo-1.hortonworks.com/ambari/${OS_LOWER}${OSREL}/2.x/updates/${AMBVERSION}/ambari.list"
      exit 5
    fi
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

