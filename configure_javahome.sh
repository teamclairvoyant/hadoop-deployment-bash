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

# Function to discover basic OS details.
discover_os() {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    # shellcheck disable=SC2034
    OS=$(lsb_release -is)
    # 7.2.1511, 14.04
    # shellcheck disable=SC2034
    OSVER=$(lsb_release -rs)
    # 7, 14
    # shellcheck disable=SC2034
    OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    # trusty, wheezy, Final
    # shellcheck disable=SC2034
    OSNAME=$(lsb_release -cs)
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        # shellcheck disable=SC2034
        OS=CentOS
      else
        # shellcheck disable=SC2034
        OS=RedHatEnterpriseServer
      fi
      # shellcheck disable=SC2034
      OSVER=$(rpm -qf /etc/redhat-release --qf='%{VERSION}.%{RELEASE}\n')
      # shellcheck disable=SC2034
      OSREL=$(rpm -qf /etc/redhat-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
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

echo "Configuring \$JAVA_HOME..."
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  if [ -L /usr/java/default ]; then
    JAVA_HOME=/usr/java/default
  elif [ -f /usr/lib/jvm ]; then
    JAVA_HOME=/usr/lib/jvm
  fi

  cat <<EOF >/etc/profile.d/java.sh
export JAVA_HOME=$JAVA_HOME
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
  chown root:root /etc/profile.d/java.sh
  chmod 0644 /etc/profile.d/java.sh
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  if ! grep -q JAVA_HOME /etc/profile.d/*; then
    JAVA_HOME=$(dpkg -L oracle-j2sdk1.7 2>/dev/null | grep /usr/lib/jvm/java | head -1)
    if [ -z "$JAVA_HOME" ]; then
      JAVA_HOME=$(dpkg -L openjdk-8-jdk 2>/dev/null | grep /usr/lib/jvm/java | head -1)
    fi

    cat <<EOF >/etc/profile.d/java.sh
export JAVA_HOME=$JAVA_HOME
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
  fi
fi

