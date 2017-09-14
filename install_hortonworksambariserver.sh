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
# 1 - Ambari server database type : embedded, postgresql, or mysql - optional
# 2 - Ambari server version - optional
AMBVERSION=2.5.2.0

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=$(lsb_release -is)
    # 7.2.1511, 14.04
    OSVER=$(lsb_release -rs)
    # 7, 14
    OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    # trusty, wheezy, Final
    OSNAME=$(lsb_release -cs)
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=$(rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n")
      OSREL=$(rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}')
    fi
  fi
}

_install_oracle_jdbc() {
  pushd "$(dirname "$0")"
  if [ ! -f ojdbc6.jar ]; then
    echo "** NOTICE: ojdbc6.jar not found.  Please manually download from"
    echo "   http://www.oracle.com/technetwork/database/enterprise-edition/jdbc-112010-090769.html"
    echo "   and place in the same directory as this script."
    exit 1
  else
    cp -p ojdbc6.jar /tmp/ojdbc6.jar
  fi
  if [ ! -d /usr/share/java ]; then
    install -o root -g root -m 0755 -d /usr/share/java
  fi
  install -o root -g root -m 0644 /tmp/ojdbc6.jar /usr/share/java/
  ln -sf ojdbc6.jar /usr/share/java/oracle-connector-java.jar
  ls -l /usr/share/java/oracle-connector-java.jar /usr/share/java/ojdbc6.jar
  popd
}

# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# TODO
INSTALLDB=$1
if [ -z "$INSTALLDB" ]; then
  INSTALLDB=embedded
fi
AMBVERSION=${2:-$AMBVERSION}

PROXY=$(egrep -h '^ *http_proxy=http|^ *https_proxy=http' /etc/profile.d/*)
eval "$PROXY"
export http_proxy
export https_proxy
if [ -z "$http_proxy" ]; then
  PROXY=$(egrep -l 'http_proxy=|https_proxy=' /etc/profile.d/*)
  if [ -n "$PROXY" ]; then
    . "$PROXY"
  fi
fi

OS_LOWER=$(echo "$OS" | tr '[:upper:]' '[:lower:]')
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  # Test to see if JDK 6 is present.
  if rpm -q jdk >/dev/null; then
    HAS_JDK=yes
  else
    HAS_JDK=no
  fi
  # Because it may have been put there by some other process.
  if [ ! -f /etc/yum.repos.d/ambari.repo ]; then
    wget -q http://public-repo-1.hortonworks.com/ambari/${OS_LOWER}${OSREL}/2.x/updates/${AMBVERSION}/ambari.repo -O /etc/yum.repos.d/ambari.repo
    chown root:root /etc/yum.repos.d/ambari.repo
    chmod 0644 /etc/yum.repos.d/ambari.repo
  fi
  yum -y -e1 -d1 install ambari-server
  if [ "$INSTALLDB" == embedded ]; then
    OPTS="--silent"
  else
    if [ "$INSTALLDB" == mysql ]; then
      yum -y -e1 -d1 install mysql-connector-java
      OPTS="$OPTS --jdbc-db mysql --jdbc-driver /usr/share/java/mysql-connector-java.jar"
      # Removes JDK 6 if it snuck onto the system. Tests for the actual RPM
      # named "jdk" to keep virtual packages from causing a JDK 8 uninstall.
      if [ "$HAS_JDK" == no ] && rpm -q jdk >/dev/null; then yum -y -e1 -d1 remove jdk; fi
    elif [ "$INSTALLDB" == postgresql ]; then
      yum -y -e1 -d1 install postgresql-jdbc
      OPTS="$OPTS --jdbc-db postgres --jdbc-driver /usr/share/java/postgresql-jdbc.jar"
    elif [ "$INSTALLDB" == oracle ]; then
      _install_oracle_jdbc
      OPTS="$OPTS --jdbc-db oracle --jdbc-driver /usr/share/java/oracle-connector-java.jar"
    else
      echo "** ERROR: Argument must be either embedded, mysql, postgresql, or oracle."
    fi
  fi
  if [ -f /etc/profile.d/java.sh ]; then
    . /etc/profile.d/java.sh
  fi
  ambari-server setup --java-home "$JAVA_HOME" $OPTS
  service ambari-server start
  chkconfig ambari-server on
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  # Because it may have been put there by some other process.
  if [ ! -f /etc/apt/sources.list.d/ambari.list ]; then
    wget -q http://public-repo-1.hortonworks.com/ambari/${OS_LOWER}${OSREL}/2.x/updates/${AMBVERSION}/ambari.list -O /etc/apt/sources.list.d/ambari.list
    chown root:root /etc/apt/sources.list.d/ambari.list
    chmod 0644 /etc/apt/sources.list.d/ambari.list
    apt-key adv --recv-keys --keyserver keyserver.ubuntu.com B9733A7A07513CAD
  fi
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y -qq update
  apt-get -y -q install ambari-server
  if [ "$INSTALLDB" == embedded ]; then
    OPTS="--silent"
  else
    if [ "$INSTALLDB" == mysql ]; then
      apt-get -y -q install libmysql-java
      OPTS="$OPTS --jdbc-db mysql --jdbc-driver /usr/share/java/mysql-connector-java.jar"
    elif [ "$INSTALLDB" == postgresql ]; then
      apt-get -y -q install libpostgresql-jdbc-java
      OPTS="$OPTS --jdbc-db postgres --jdbc-driver /usr/share/java/postgresql.jar"
    elif [ "$INSTALLDB" == oracle ]; then
      _install_oracle_jdbc
      OPTS="$OPTS --jdbc-db oracle --jdbc-driver /usr/share/java/oracle-connector-java.jar"
    else
      echo "** ERROR: Argument must be either embedded, mysql, or postgresql, or oracle."
    fi
  fi
  if [ -f /etc/profile.d/java.sh ]; then
    . /etc/profile.d/java.sh
  elif [ -f /etc/profile.d/jdk.sh ]; then
    . /etc/profile.d/jdk.sh
  fi
  ambari-server setup --java-home "$JAVA_HOME" $OPTS
  service ambari-server start
  update-rc.d ambari-server defaults
fi
