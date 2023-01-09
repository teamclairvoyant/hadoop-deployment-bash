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
# Copyright Clairvoyant 2015

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

# The original intent of this script was to install the unlimited strength JCE
# to *all* Oracle JDKs installed on the system.  With the advent of the JCE
# being delivered within the JDK, and the added complexity of trying to
# determine versions, this script *will not* install the JCE at all if it sees
# JDK 1.8.0_151 or newer.  This script *will* configure JDK 1.8.0_151 -
# 1.8.0_160 to enable the unlimited policy.

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
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

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

echo "Installing Oracle Java Cryptography Extentions..."
# https://stackoverflow.com/questions/7334754/correct-way-to-check-java-version-from-bash-script
if type -p java >/dev/null; then
  _JAVA=java
  JAVA_HOME=${JAVA_HOME:-/usr/java/default}
elif [ -n "$JAVA_HOME" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
  _JAVA="${JAVA_HOME}/bin/java"
else
  echo "** WARNING: Java not found."
fi
if [ -n "$_JAVA" ]; then
  _JAVA_VERSION=$("$_JAVA" -version 2>&1 | awk -F '"' '/version/ {print $2}')
  _JAVA_VERSION_MAJ=$(echo "${_JAVA_VERSION}" | awk -F. '{print $1}')
  _JAVA_VERSION_MIN=$(echo "${_JAVA_VERSION}" | awk -F. '{print $2}')
  #_JAVA_VERSION_PATCH=$(echo "${_JAVA_VERSION}" | awk -F. '{print $3}' | sed -e 's|_.*||')
  _JAVA_VERSION_RELEASE=$(echo "${_JAVA_VERSION}" | awk -F_ '{print $2}')
else
  _JAVA_VERSION_MAJ=0
  _JAVA_VERSION_MIN=0
  #_JAVA_VERSION_PATCH=0
  _JAVA_VERSION_RELEASE=0
fi
if [ "${_JAVA_VERSION_MAJ}" -eq 1 ] && [ "${_JAVA_VERSION_MIN}" -eq 8 ] && [ "${_JAVA_VERSION_RELEASE}" -ge 161 ]; then
  echo "NOTICE: Unlimited JCE is built-in for JDK version ${_JAVA_VERSION}. Exiting..."
  exit 0
fi

if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  if rpm -q jdk || test -d /usr/java/jdk1.6.0_*; then
    wget -nv -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
      http://download.oracle.com/otn-pub/java/jce_policy/6/jce_policy-6.zip -O /tmp/jce_policy-6.zip
    unzip -o -j /tmp/jce_policy-6.zip -d /usr/java/jdk1.6.0_31/jre/lib/security/
  fi

  if rpm -q oracle-j2sdk1.7 || rpm -qa | grep jdk1.7.0_ || test -d /usr/java/jdk1.7.0_*; then
    wget -nv -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
      http://download.oracle.com/otn-pub/java/jce/7/UnlimitedJCEPolicyJDK7.zip -O /tmp/jce_policy-7.zip
    for _DIR in /usr/java/jdk1.7.0_*; do
      unzip -o -j /tmp/jce_policy-7.zip -d "${_DIR}/jre/lib/security/"
    done
  fi

  if [ "${_JAVA_VERSION_MAJ}" -eq 1 ] && [ "${_JAVA_VERSION_MIN}" -eq 8 ] && [ "${_JAVA_VERSION_RELEASE}" -ge 151 ]; then
    echo "INFO: Vanilla JCE is built-in for JDK version ${_JAVA_VERSION}. Enabling unlimited policy..."
    sed -e '/^crypto.policy=/d' -i "${JAVA_HOME}/jre/lib/security/java.security"
    echo "crypto.policy=unlimited" >>"${JAVA_HOME}/jre/lib/security/java.security"
    exit 0
  fi
  if rpm -q oracle-j2sdk1.8 || rpm -q jdk1.8 || rpm -qa | grep jdk1.8.0_ || test -d /usr/java/jdk1.8.0_*; then
    wget -nv -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
      http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip -O /tmp/jce_policy-8.zip
    for _DIR in /usr/java/jdk1.8.0_*; do
      unzip -o -j /tmp/jce_policy-8.zip -d "${_DIR}/jre/lib/security/"
    done
  fi
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  if dpkg -l oracle-j2sdk1.7 >/dev/null || test -d /usr/lib/jvm/java-7-oracle-cloudera; then
    wget -nv -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
      http://download.oracle.com/otn-pub/java/jce/7/UnlimitedJCEPolicyJDK7.zip -O /tmp/jce_policy-7.zip
    unzip -o -j /tmp/jce_policy-7.zip -d /usr/lib/jvm/java-7-oracle-cloudera/jre/lib/security/
  fi

  if dpkg -l oracle-java7-installer >/dev/null || test -d /usr/lib/jvm/java-7-oracle; then
    apt-get -y -q install oracle-java7-unlimited-jce-policy
  fi

  if [ "${_JAVA_VERSION_MAJ}" -eq 1 ] && [ "${_JAVA_VERSION_MIN}" -eq 8 ] && [ "${_JAVA_VERSION_RELEASE}" -ge 151 ]; then
    echo "INFO: Vanilla JCE is built-in for JDK version ${_JAVA_VERSION}. Enabling unlimited policy..."
    sed -e '/^crypto.policy=/d' -i "${JAVA_HOME}/jre/lib/security/java.security"
    echo "crypto.policy=unlimited" >>"${JAVA_HOME}/jre/lib/security/java.security"
    exit 0
  fi
  if dpkg -l oracle-java8-installer >/dev/null || test -d /usr/lib/jvm/java-8-oracle; then
    apt-get -y -q install oracle-java8-unlimited-jce-policy
  fi
fi

