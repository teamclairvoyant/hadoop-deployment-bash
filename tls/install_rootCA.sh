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
# Copyright Clairvoyant 2015

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

echo "Installing TLS root certificates..."
if [ -f /etc/profile.d/jdk.sh ]; then
  . /etc/profile.d/jdk.sh
elif [ -f /etc/profile.d/java.sh ]; then
  . /etc/profile.d/java.sh
elif [ -d /usr/java/default ]; then
  JAVA_HOME=/usr/java/default
fi

if [ -d /etc/hortonworks ]; then
  _DIR=/etc/hortonworks
elif [ -d /opt/cloudera ]; then
  _DIR=/opt/cloudera
else
  echo "ERROR: Cannot determine if this is Cloudera or Hortonworks."
  exit 11
fi

if [ -z "${JAVA_HOME}" ]; then echo "ERROR: \$JAVA_HOME is not set."; exit 10; fi

if [ ! -f "${JAVA_HOME}"/jre/lib/security/jssecacerts ]; then
  #TODO: On el7: /usr/java/default/jre/lib/security/cacerts -> /etc/pki/java/cacerts
  /bin/cp -p "${JAVA_HOME}/jre/lib/security/cacerts" "${JAVA_HOME}/jre/lib/security/jssecacerts"
fi
# Import ROOT CA certificate (ca.cert.pem) in system truststore file (jssecacerts)
keytool -importcert -file "${_DIR}/security/CAcerts/ca.cert.pem" \
 -alias CAcert -keystore "${JAVA_HOME}/jre/lib/security/jssecacerts" \
 -storepass changeit -noprompt -trustcacerts
# Import Intermediate CA certificate (intermediate.cert.pem) in system truststore file (jssecacerts)
keytool -importcert -file "${_DIR}/security/CAcerts/intermediate.cert.pem" \
 -alias CAcertint -keystore "${JAVA_HOME}/jre/lib/security/jssecacerts" \
 -storepass changeit -noprompt -trustcacerts

if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  if [ "$OS" == RedHatEnterpriseServer ]; then
    subscription-manager repos --enable="rhel-${OSREL}-server-optional-rpms"
  fi
  if ! rpm -q openssl-perl; then yum -y -e1 -d1 install openssl-perl; fi
  c_rehash "${_DIR}/security/CAcerts/"

  if [ -d /etc/pki/ca-trust/source/anchors/ ]; then
    # Lets not enable dynamic certs if the customer has not done it themselves.
    #if [ "$OSREL" == 6 ]; then
    #  update-ca-trust check | grep -q DISABLED && update-ca-trust enable
    #fi
    cp -p "${_DIR}/security/CAcerts/"*.pem /etc/pki/ca-trust/source/anchors/
    update-ca-trust extract
  fi
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  c_rehash "${_DIR}/security/CAcerts/"
  cd "${_DIR}/security/CAcerts/" || exit
  for SRC in *.pem; do
    # shellcheck disable=SC2001
    DST=$(echo "$SRC" | sed 's|pem$|crt|')
    cp -p "${_DIR}/security/CAcerts/${SRC}" "/usr/local/share/ca-certificates/${DST}"
  done
  update-ca-certificates
fi

