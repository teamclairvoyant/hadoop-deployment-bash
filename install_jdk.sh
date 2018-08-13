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
# 1 - Which major JDK version to install. If empty, install JDK 7 from Cloudera. - optional
# 2 - SCM version - optional

# Note:
# If you do not want to download the JDK multiple times or access to
# download.oracle.com is blocked, you can place the manually downloaded JDK RPM
# in the /tmp directory for RedHat-based systems or the JDK tarball in
# /var/cache/oracle-jdk8-installer for Debian-based systems.

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

# TODO
USECLOUDERA=$1
if [ -z "$USECLOUDERA" ]; then
  USECLOUDERA=yes
fi
SCMVERSION=$2

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

echo "Installing Oracle JDK..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  if [ "$USECLOUDERA" = yes ]; then
    # Because it may have been put there by some other process.
    if [ ! -f /etc/yum.repos.d/cloudera-manager.repo ]; then
      wget -q https://archive.cloudera.com/cm5/redhat/${OSREL}/x86_64/cm/cloudera-manager.repo -O /etc/yum.repos.d/cloudera-manager.repo
      chown root:root /etc/yum.repos.d/cloudera-manager.repo
      chmod 0644 /etc/yum.repos.d/cloudera-manager.repo
      if [ -n "$SCMVERSION" ]; then
        sed -e "s|/cm/5/|/cm/${SCMVERSION}/|" -i /etc/yum.repos.d/cloudera-manager.repo
      fi
    fi
    yum -y -e1 -d1 install oracle-j2sdk1.7
    DIRNAME=`rpm -ql oracle-j2sdk1.7|head -1`
    TARGET=`basename $DIRNAME`
    ln -s $TARGET /usr/java/default
  elif [ "$USECLOUDERA" = 7 ]; then
    pushd /tmp
    echo "*** Downloading Oracle JDK 7u80..."
    wget -nv -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
      http://download.oracle.com/otn/java/jdk/7u80-b15/jdk-7u80-linux-x64.rpm -O jdk-7u80-linux-x64.rpm
    rpm -Uv jdk-7u80-linux-x64.rpm
    popd
  elif [ "$USECLOUDERA" = 8 ]; then
    pushd /tmp
    echo "*** Downloading Oracle JDK 8u181..."
    wget -nv -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
      http://download.oracle.com/otn-pub/java/jdk/8u181-b13/96a7b8442fe848ef90c96a2fad6ed6d1/jdk-8u181-linux-x64.rpm -O jdk-8u181-linux-x64.rpm
    rpm -Uv jdk-8u181-linux-x64.rpm
    popd
  else
    echo "ERROR: Unknown Java version.  Please choose 7 or 8."
    exit 10
  fi
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  if [ "$USECLOUDERA" = yes ]; then
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
      if [ -n "$SCMVERSION" ]; then
        sed -e "s|-cm5 |-cm${SCMVERSION} |" -i /etc/apt/sources.list.d/cloudera-manager.list
      fi
      curl -s http://archive.cloudera.com/cm5/${OS_LOWER}/${OSNAME}/amd64/cm/archive.key | apt-key add -
    fi
    apt-get -y -qq update
    apt-get -y -q install oracle-j2sdk1.7
  elif [ "$USECLOUDERA" = 7 ]; then
    #mkdir -p /var/cache/oracle-jdk7-installer
    #mv jdk-7u*-linux-x64.tar.gz /var/cache/oracle-jdk7-installer/
    add-apt-repository -y ppa:webupd8team/java
    apt-get -y -qq update
    echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
#    apt-get -y -q install oracle-java7-installer=7u80-*
    apt-get -y -q install oracle-java7-installer
    apt-get -y -q install oracle-java7-set-default
  elif [ "$USECLOUDERA" = 8 ]; then
    #mkdir -p /var/cache/oracle-jdk8-installer
    #mv jdk-8u*-linux-x64.tar.gz /var/cache/oracle-jdk8-installer/
    add-apt-repository -y ppa:webupd8team/java
    apt-get -y -qq update
    echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
#    apt-get -y -q install oracle-java8-installer=8u91-*
    apt-get -y -q install oracle-java8-installer
    apt-get -y -q install oracle-java8-set-default
  else
    echo "ERROR: Unknown Java version.  Please choose 7 or 8."
    exit 10
  fi
fi

