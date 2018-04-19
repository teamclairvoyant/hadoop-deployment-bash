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
# 1 - YUM repository hostname - required

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
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS ]; then
#if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Installing Cloudera Navigator Encrypt..."
if [ "$OS" == CentOS ]; then
  YUMHOST=$1
  if [ -z "$YUMHOST" ]; then
    echo "ERROR: Missing YUM hostname."
    exit 1
  fi

  echo "** Find the correct kernel-headers and kernel-devel that match the running kernel."
  echo "** DON'T PANIC."
  echo "** This might look scary..."
  if ! yum -y -e1 -d1 install kernel-headers-$(uname -r) kernel-devel-$(uname -r); then
    cp -p /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo-orig
    sed -e "s|\$releasever|$OSVER|" -i /etc/yum.repos.d/CentOS-Base.repo
    yum clean metadata
    if ! yum -y -e1 -d1 install kernel-headers-$(uname -r) kernel-devel-$(uname -r); then
      sed -e '/^mirrorlist/s|^|#|' -e '/#baseurl/s|^#||' -e '/^baseurl/s|mirror.centos.org/centos|vault.centos.org|' -i /etc/yum.repos.d/CentOS-Base.repo
      yum clean metadata
      yum -y -e1 -d1 install kernel-headers-$(uname -r) kernel-devel-$(uname -r)
    fi
    mv /etc/yum.repos.d/CentOS-Base.repo-orig /etc/yum.repos.d/CentOS-Base.repo
    yum clean metadata
  fi
  echo "** End of possible errors."

  yum -y -e1 -d1 install epel-release
  wget -q http://${YUMHOST}/navigator-encrypt/latest/cloudera-navencrypt.repo -O /etc/yum.repos.d/cloudera-navencrypt.repo
  chown root:root /etc/yum.repos.d/cloudera-navencrypt.repo
  chmod 0644 /etc/yum.repos.d/cloudera-navencrypt.repo
  yum -y -e1 -d1 install navencrypt
  chkconfig navencrypt-mount on
elif [ "$OS" == RedHatEnterpriseServer ]; then
  YUMHOST=$1
  if [ -z "$YUMHOST" ]; then
    echo "ERROR: Missing YUM hostname."
    exit 1
  fi

  subscription-manager repos --enable=rhel-${OSREL}-server-optional-rpms
  echo "** Find the correct kernel-headers and kernel-devel that match the running kernel."
  yum -y -e1 -d1 install kernel-headers-$(uname -r) kernel-devel-$(uname -r)

  yum -y -e1 -d1 install epel-release
  if ! rpm -q epel-release; then
    rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSREL}.noarch.rpm
  fi
  wget -q http://${YUMHOST}/navigator-encrypt/latest/cloudera-navencrypt.repo -O /etc/yum.repos.d/cloudera-navencrypt.repo
  chown root:root /etc/yum.repos.d/cloudera-navencrypt.repo
  chmod 0644 /etc/yum.repos.d/cloudera-navencrypt.repo
  yum -y -e1 -d1 install navencrypt
  chkconfig navencrypt-mount on
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  :
fi

