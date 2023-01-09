#!/bin/bash
# shellcheck disable=SC1091
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
# Copyright Clairvoyant 2020

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

# A problem has been identified in all JDKs starting with OpenJDK 1.8u242, and
# JDK 11.0.6. The problem is related to changes in the way OpenJDK supports
# Kerberos referrals, specified in JDK-8215032. As a result, the JDK
# implementation of RFC-6806 will break Cloudera, custom and 3rd party
# application's interpretation of Kerberos credentials under certain
# conditions.

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
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != AlmaLinux ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Fixing OpenJDK Kerberos Issue..."
DATE=$(date '+%Y%m%d%H%M%S')
if [ -f /etc/profile.d/jdk.sh ]; then
  . /etc/profile.d/jdk.sh
elif [ -f /etc/profile.d/java.sh ]; then
  . /etc/profile.d/java.sh
elif [ -d /usr/lib/jvm/java ]; then
  JAVA_HOME=/usr/lib/jvm/java
fi

if [ -z "${JAVA_HOME}" ]; then echo "ERROR: \$JAVA_HOME is not set."; exit 10; fi

# https://stackoverflow.com/questions/7334754/correct-way-to-check-java-version-from-bash-script
if type -p java >/dev/null; then
  _JAVA=java
elif [ -n "$JAVA_HOME" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
  _JAVA="${JAVA_HOME}/bin/java"
else
  echo "WARNING: Java not found."
  exit 11
fi
if [ -n "$_JAVA" ]; then
  _JAVA_VERSION=$("$_JAVA" -version 2>&1 | awk -F '"' '/version/ {print $2}')
  _JAVA_VERSION_MAJ=$(echo "${_JAVA_VERSION}" | awk -F. '{print $1}')
  _JAVA_VERSION_MIN=$(echo "${_JAVA_VERSION}" | awk -F. '{print $2}')
  _JAVA_VERSION_PATCH=$(echo "${_JAVA_VERSION}" | awk -F. '{print $3}' | sed -e 's|_.*||')
  _JAVA_VERSION_RELEASE=$(echo "${_JAVA_VERSION}" | awk -F_ '{print $2}')
else
  _JAVA_VERSION_MAJ=0
  _JAVA_VERSION_MIN=0
  _JAVA_VERSION_PATCH=0
  _JAVA_VERSION_RELEASE=0
fi
if { [ "${_JAVA_VERSION_MAJ}" -eq 1 ] && [ "${_JAVA_VERSION_MIN}" -eq 8 ] && [ "${_JAVA_VERSION_RELEASE}" -ge 242 ]; } || { [ "${_JAVA_VERSION_MAJ}" -eq 11 ] && [ "${_JAVA_VERSION_MIN}" -eq 0 ] && [ "${_JAVA_VERSION_PATCH}" -ge 6 ]; }; then
  echo "INFO: OpenJDK Kerberos issue present for JDK version ${_JAVA_VERSION}. Fixing..."
  if [ "${_JAVA_VERSION_MAJ}" -eq 1 ]; then
    _JSECPATH=/jre/lib
  elif [ "${_JAVA_VERSION_MAJ}" -eq 11 ]; then
    _JSECPATH=/conf
  fi
  if [ ! -f ${JAVA_HOME}${_JSECPATH}/security/java.security-orig ]; then
    /bin/cp -p ${JAVA_HOME}${_JSECPATH}/security/java.security ${JAVA_HOME}${_JSECPATH}/security/java.security-orig
  else
    /bin/cp -p ${JAVA_HOME}${_JSECPATH}/security/java.security ${JAVA_HOME}${_JSECPATH}/security/java.security."${DATE}"
  fi
  sed -e '/^sun.security.krb5.disableReferrals=/s|=.*|=true|' -i "${JAVA_HOME}${_JSECPATH}/security/java.security"
  if ! grep -q ^sun.security.krb5.disableReferrals= "${JAVA_HOME}${_JSECPATH}/security/java.security"; then
    echo "sun.security.krb5.disableReferrals=true" >>"${JAVA_HOME}${_JSECPATH}/security/java.security"
  fi
  exit 0
else
  echo "NOTICE: OpenJDK Kerberos issue does not exist for JDK version ${_JAVA_VERSION}. Exiting..."
  exit 0
fi

