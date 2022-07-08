#!/bin/bash
# shellcheck disable=SC1091
#
# $Id$
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
# Copyright Clairvoyant 2019
#
# No elevated privileges are required to run this script.  However, there are
# several invocations of sudo in order to gather certain pieces of information
# that are not available to unprivileged users.  Only the logical volume,
# iptables, and RHEL subscription-manager commands use sudo.
#
# Sudo is invoked in non-interactive mode and will not prompt for a password.
# This will allow for graceful failure of that command if passwordless sudo is
# not enabled for the user.  Environments that use privilege escalation tools
# different from sudo (like Centrify's dzdo) are not presently supported.

PATH=/bin:/sbin:/usr/bin:/usr/sbin

# Function to discover basic OS details.
discover_os() {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu, RedHatEnterpriseServer, Debian, SUSE LINUX, OracleServer
    # shellcheck disable=SC2034
    OS=$(lsb_release -is)
    # CentOS= 6.10, 7.2.1511, Ubuntu= 14.04, RHEL= 6.10, 7.5, SLES= 11, OEL= 7.6
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
      elif [ -f /etc/oracle-release ]; then
        # shellcheck disable=SC2034
        OS=OracleServer
        # 7.6
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/oracle-release --qf='%{VERSION}\n')
        # shellcheck disable=SC2034
        OSREL=$(rpm -qf /etc/oracle-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
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
discover_os

echo "****************************************"
echo "****************************************"
hostname
# shellcheck disable=SC2016
echo '$Id$'
echo 'Version: 20190924'
echo "****************************************"
echo "*** OS details"
if [ -f /etc/redhat-release ]; then
  if [ -f /etc/centos-release ]; then
    cat /etc/centos-release
  elif [ -f /etc/oracle-release ]; then
    cat /etc/oracle-release
  else
    cat /etc/redhat-release
  fi
elif [ -f /etc/SuSE-release ]; then
  cat /etc/SuSE-release
elif [ -f /etc/os-release ]; then
  cat /etc/os-release
fi
if [ -f /etc/lsb-release ]; then /usr/bin/lsb_release -ds; fi

echo "****************************************"
echo "*** Entropy"
echo "** running config:"
if [ "$OS" == CentOS ] || [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == OracleServer ]; then
  service rngd status
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  service rng-tools status || ps -o user,pid,command -C rngd
elif [ "$OS" == "SUSE LINUX" ]; then
  service rng-tools status
fi
echo "** startup config:"
if [ "$OS" == "SUSE LINUX" ]; then
  chkconfig --list rng-tools
else
  chkconfig --list rngd
fi
echo "** available entropy:"
cat /proc/sys/kernel/random/entropy_avail

echo "****************************************"
echo "*** JCE"
if [ -f /etc/profile.d/jdk.sh ]; then
  . /etc/profile.d/jdk.sh
elif [ -f /etc/profile.d/java.sh ]; then
  . /etc/profile.d/java.sh
elif [ -d /usr/java/default ]; then
  JAVA_HOME=/usr/java/default
fi
#echo "** default java version:"
# https://stackoverflow.com/questions/7334754/correct-way-to-check-java-version-from-bash-script
if type -p java >/dev/null; then
  #echo "Java executable found in PATH."
  _JAVA=java
elif [ -n "$JAVA_HOME" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
  #echo "Java executable found in JAVA_HOME."
  _JAVA="${JAVA_HOME}/bin/java"
else
  echo "Java not found."
fi
if [ -n "$_JAVA" ]; then
  #java -version 2>&1 || ${JAVA_HOME}/java -version 2>&1
  "$_JAVA" -version 2>&1
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
if command -v unzip; then
  UNZIP=true
else
  UNZIP=false
fi
_JCE_FOUND=false
for _DIR in /usr/java/default/jre/lib/security \
            /usr/java/jdk1.6.0_31/jre/lib/security \
            /usr/java/jdk1.7.0_67-cloudera/jre/lib/security \
            /usr/java/jdk1.8.0_*/jre/lib/security \
            /usr/lib/jvm/java-1.8.0-openjdk/jre/lib/security \
            /usr/lib/jvm/adoptopenjdk-8-*/jre/lib/security \
            /usr/lib/jvm/java-7-openjdk-amd64/jre/lib/security \
            /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/security \
            /usr/lib/jvm/default-java/jre/lib/security \
            /usr/lib/jvm/java-7-oracle/jre/lib/security \
            /usr/lib/jvm/java-8-oracle/jre/lib/security; do
  if [ -f "${_DIR}/local_policy.jar" ]; then
    _JCE_FOUND=true
    if [ "$UNZIP" == true ]; then
      # http://harshj.com/checking-if-your-jre-has-the-unlimited-strength-policy-files-in-place/
      unzip -c "${_DIR}"/local_policy.jar default_local.policy | grep -q javax.crypto.CryptoAllPermission && echo -n "unlimited         " || echo -n "vanilla           "
      echo " JCE in $_DIR"
    else
      #ls -l "${_DIR}"/*.jar
      sha1sum "${_DIR}"/*.jar
    fi
  elif [ "${_JAVA_VERSION_MAJ}" -eq 1 ] && [ "${_JAVA_VERSION_MIN}" -eq 8 ] && [ "${_JAVA_VERSION_RELEASE}" -ge 151 ]; then
  # https://www.cloudera.com/documentation/enterprise/release-notes/topics/rn_consolidated_pcm.html#jce
  # Enabling Unlimited Strength Encryption for JDK 1.8.0_151 (and later)
  #
  # As of JDK 1.8.0_151, unlimited strength encryption can be enabled using the
  # java.security file as documented in the JDK 1.8.0_151 release notes. You do
  # not need to install the JCE policy files.
  #
  # As of JDK 1.8.0_161, unlimited strength encryption has been enabled by
  # default. No further action is required.
    _JCE_FOUND=true
    if [ -f "${_DIR}"/java.security ]; then
      if grep -q ^crypto.policy=unlimited "${_DIR}"/java.security; then
        echo "unlimited built-in JCE in $_DIR"
      elif grep -q ^crypto.policy=limited "${_DIR}"/java.security; then
        echo "vanilla   built-in JCE in $_DIR"
      else
        if [ "${_JAVA_VERSION_RELEASE}" -ge 161 ]; then
          echo "unlimited built-in JCE in $_DIR"
        elif [ "${_JAVA_VERSION_RELEASE}" -ge 151 ]; then
          echo "vanilla   built-in JCE in $_DIR"
        fi
      fi
    fi
  fi
done
if [ "$_JCE_FOUND" == "false" ]; then
  echo "JCE not found."
fi

echo "****************************************"
echo "*** JDK TLS"
#grep -A1 ^jdk.tls.disabledAlgorithms= ${JAVA_HOME}/jre/lib/security/java.security ${JAVA_HOME}/conf/security/java.security
sed -ne '/^jdk.tls.disabledAlgorithms=/,/^$/p' ${JAVA_HOME}/jre/lib/security/java.security ${JAVA_HOME}/conf/security/java.security

echo "****************************************"
echo "*** Kerberos"
echo "** running config:"
grep -v ^# /etc/krb5.conf | cat

echo "****************************************"
echo "*** Cloudera Software"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ] || [ "$OS" == "SUSE LINUX" ]; then
  rpm -qa ^cloudera\* ^navencrypt\* \*keytrustee\*
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  dpkg -l \*cloudera\* \*navencrypt\* \*keytrustee\* | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi
echo "*** Cloudera Hadoop Packages"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ] || [ "$OS" == "SUSE LINUX" ]; then
  rpm -qa ^hadoop\*
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  dpkg -l hadoop | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi
echo "*** Cloudera Parcels"
ls -l /opt/cloudera/parcels
echo "*** Cloudera CSDs"
ls -l /opt/cloudera/csd

echo "****************************************"
echo "*** Hortonworks Software"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ] || [ "$OS" == "SUSE LINUX" ]; then
  rpm -qa ^ambari\*
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  dpkg -l \*ambari\* | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi
echo "*** Hortonworks Hadoop Packages"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ] || [ "$OS" == "SUSE LINUX" ]; then
  rpm -qa ^hadoop\*
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  dpkg -l hadoop-?-?-?-?-???? | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi

echo "****************************************"
echo "*** Cloudera Manager Agent"
echo "** default:"
grep -Ev '^#|^$' /etc/default/cloudera-scm-agent
echo "** config:"
grep -Ev '^#|^$' /etc/cloudera-scm-agent/config.ini
_KEYPW=$(awk -F= '/^[::space::]*client_keypw_file=/{print $2}' /etc/cloudera-scm-agent/config.ini)

echo "****************************************"
echo "*** Cloudera Manager Server"
echo "** default:"
grep -Ev '^#|^$' /etc/default/cloudera-scm-server
echo "** config:"
sudo -n grep -Ev '^#|^$' /etc/cloudera-scm-server/db.properties

echo "****************************************"
echo "*** Cloudera Security"
find /opt/cloudera/security/ -ls
if [ -n "${_KEYPW}" ]; then
  find "${_KEYPW}" -ls
fi

#echo "****************************************"
#echo "*** "
#echo "** running config:"
#echo "** startup config:"

echo "****************************************"

exit 0

