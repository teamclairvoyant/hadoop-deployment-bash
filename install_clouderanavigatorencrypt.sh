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

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

# ARGV:
# 1 - YUM repository hostname - required

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
      if [ -f /etc/almalinux-release ]; then
        # shellcheck disable=SC2034
        OS=AlmaLinux
        # 8.6
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/almalinux-release --qf='%{VERSION}\n')
        # shellcheck disable=SC2034
        OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
      elif [ -f /etc/centos-release ]; then
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
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != AlmaLinux ]; then
#if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != AlmaLinux ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Installing Cloudera Navigator Encrypt..."
if [ "$OS" == AlmaLinux ]; then
  YUMHOST=$1
  if [ -z "$YUMHOST" ]; then
    echo "ERROR: Missing YUM hostname."
    exit 1
  fi

  echo "** Find the correct kernel-headers and kernel-devel that match the running kernel."
  yum -y -e1 -d1 install kernel-headers-"$(uname -r)" kernel-devel-"$(uname -r)"

  yum -y -e1 -d1 install epel-release
  wget -q "http://${YUMHOST}/navigator-encrypt/latest/el${OSREL}/cloudera-navencrypt.repo" -O /etc/yum.repos.d/cloudera-navencrypt.repo
  RETVAL=$?
  if [ "$RETVAL" -ne 0 ]; then
    echo "** ERROR: Could not download http://${YUMHOST}/navigator-encrypt/latest/el${OSREL}/cloudera-navencrypt.repo"
    exit 4
  fi
  chown root:root /etc/yum.repos.d/cloudera-navencrypt.repo
  chmod 0644 /etc/yum.repos.d/cloudera-navencrypt.repo
  yum -y -e1 -d1 install navencrypt
  chkconfig navencrypt-mount on
elif [ "$OS" == CentOS ]; then
  YUMHOST=$1
  if [ -z "$YUMHOST" ]; then
    echo "ERROR: Missing YUM hostname."
    exit 1
  fi

  echo "** Find the correct kernel-headers and kernel-devel that match the running kernel."
  echo "** DON'T PANIC."
  echo "** This might look scary..."
  if ! yum -y -e1 -d1 install kernel-headers-"$(uname -r)" kernel-devel-"$(uname -r)"; then
    cp -p /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo-orig
    sed -e "s|\$releasever|$OSVER|" -i /etc/yum.repos.d/CentOS-Base.repo
    yum clean metadata
    if ! yum -y -e1 -d1 install kernel-headers-"$(uname -r)" kernel-devel-"$(uname -r)"; then
      sed -e '/^mirrorlist/s|^|#|' -e '/#baseurl/s|^#||' -e '/^baseurl/s|mirror.centos.org/centos|vault.centos.org|' -i /etc/yum.repos.d/CentOS-Base.repo
      yum clean metadata
      yum -y -e1 -d1 install kernel-headers-"$(uname -r)" kernel-devel-"$(uname -r)"
    fi
    mv /etc/yum.repos.d/CentOS-Base.repo-orig /etc/yum.repos.d/CentOS-Base.repo
    yum clean metadata
  fi
  echo "** End of possible errors."

  yum -y -e1 -d1 install epel-release
  wget -q "http://${YUMHOST}/navigator-encrypt/latest/el${OSREL}/cloudera-navencrypt.repo" -O /etc/yum.repos.d/cloudera-navencrypt.repo
  RETVAL=$?
  if [ "$RETVAL" -ne 0 ]; then
    echo "** ERROR: Could not download http://${YUMHOST}/navigator-encrypt/latest/el${OSREL}/cloudera-navencrypt.repo"
    exit 4
  fi
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

  subscription-manager repos --enable="rhel-${OSREL}-server-optional-rpms"
  echo "** Find the correct kernel-headers and kernel-devel that match the running kernel."
  yum -y -e1 -d1 install kernel-headers-"$(uname -r)" kernel-devel-"$(uname -r)"

  yum -y -e1 -d1 install epel-release
  if ! rpm -q epel-release; then
    rpm -Uvh "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSREL}.noarch.rpm"
  fi
  wget -q "http://${YUMHOST}/navigator-encrypt/latest/el${OSREL}/cloudera-navencrypt.repo" -O /etc/yum.repos.d/cloudera-navencrypt.repo
  RETVAL=$?
  if [ "$RETVAL" -ne 0 ]; then
    echo "** ERROR: Could not download http://${YUMHOST}/navigator-encrypt/latest/el${OSREL}/cloudera-navencrypt.repo"
    exit 4
  fi
  chown root:root /etc/yum.repos.d/cloudera-navencrypt.repo
  chmod 0644 /etc/yum.repos.d/cloudera-navencrypt.repo
  yum -y -e1 -d1 install navencrypt
  chkconfig navencrypt-mount on
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  :
fi

