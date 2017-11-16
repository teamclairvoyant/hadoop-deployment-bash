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

# ARGV:
# 1 - SCM agent version - optional

# We assume that the CM Services have been previously shut down.
# We assume that the CM server is also running the CM agent.
# We assume that the CM server and CM database have been previously shut down.
# If CM server or CM database are found, they will be re-started.

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

PROXY=`egrep -h '^ *http_proxy=http|^ *https_proxy=http' /etc/profile.d/*`
eval $PROXY
export http_proxy
export https_proxy
if [ -z "$http_proxy" ]; then
  PROXY=`egrep -l 'http_proxy=|https_proxy=' /etc/profile.d/*`
  if [ -n "$PROXY" ]; then
    . $PROXY
  fi
fi

echo "Upgrading Cloudera Manager..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  if rpm -q cloudera-manager-agent; then
    SCMVERSION=$1
    if [ -z "$SCMVERSION" ]; then
      echo "ERROR: Missing SCM version."
      exit 1
    fi

    # Because it may have been put there by some other process.
    if [ ! -f /etc/yum.repos.d/cloudera-manager.repo ]; then
      wget -q https://archive.cloudera.com/cm5/redhat/${OSREL}/x86_64/cm/cloudera-manager.repo -O /etc/yum.repos.d/cloudera-manager.repo
      chown root:root /etc/yum.repos.d/cloudera-manager.repo
      chmod 0644 /etc/yum.repos.d/cloudera-manager.repo
    fi
    sed -e "s|/cm/5[0-9.]*/|/cm/${SCMVERSION}/|" -i /etc/yum.repos.d/cloudera-manager.repo

    service cloudera-scm-agent stop
    # This should update the -daemons and -server packages as well if they are present.
    yum -y -e1 -d1 update cloudera-manager-agent
    if rpm -q cloudera-manager-server-db-2 >/dev/null; then
      service cloudera-scm-server-db start
    fi
    if rpm -q cloudera-manager-server >/dev/null; then
      service cloudera-scm-server start
    fi
    service cloudera-scm-agent start
  fi
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  if dpkg -l cloudera-manager-agent >/dev/null; then
    SCMVERSION=$1
    if [ -z "$SCMVERSION" ]; then
      echo "ERROR: Missing SCM version."
      exit 1
    fi

    # Because it may have been put there by some other process.
    if [ ! -f /etc/apt/sources.list.d/cloudera-manager.list ]; then
      if [ "$OS" == Debian ]; then
        OS_LOWER=debian
      elif [ "$OS" == Ubuntu ]; then
        OS_LOWER=ubuntu
      fi
      wget -q https://archive.cloudera.com/cm5/${OS_LOWER}/${OSNAME}/amd64/cm/cloudera.list -O /etc/apt/sources.list.d/cloudera-manager.list
      chown root:root /etc/apt/sources.list.d/cloudera-manager.list
      chmod 0644 /etc/apt/sources.list.d/cloudera-manager.list
      curl -s http://archive.cloudera.com/cm5/${OS_LOWER}/${OSNAME}/amd64/cm/archive.key | apt-key add -
    fi
    sed -e "s|-cm5 |-cm${SCMVERSION} |" -i /etc/apt/sources.list.d/cloudera-manager.list
    export DEBIAN_FRONTEND=noninteractive
    apt-get -y -qq update

    service cloudera-scm-agent stop
    # This should update the -daemons and -server packages as well if they are present.
    apt-get -y -qq install cloudera-manager-agent
    if dpkg -l cloudera-manager-server-db-2 >/dev/null; then
      service cloudera-scm-server-db start
      update-rc.d cloudera-scm-server-db defaults
    fi
    if dpkg -l cloudera-manager-server >/dev/null; then
      service cloudera-scm-server start
      update-rc.d cloudera-scm-server defaults
    fi
    service cloudera-scm-agent start
    update-rc.d cloudera-scm-agent defaults
  fi
fi

