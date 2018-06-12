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
# 1 - SCM server database type : embedded, postgresql, mysql, or oracle - optional
# 2 - SCM server version - optional

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

_install_oracle_jdbc() {
  pushd $(dirname $0)
  if [ ! -f ojdbc6.jar ] && [ ! -f ojdbc8.jar ]; then
    echo "** NOTICE: ojdbc6.jar or ojdbc8.jar not found.  Please manually download from"
    echo "   http://www.oracle.com/technetwork/database/enterprise-edition/jdbc-112010-090769.html"
    echo "   or"
    echo "   http://www.oracle.com/technetwork/database/features/jdbc/jdbc-ucp-122-3110062.html"
    echo "   and place in the same directory as this script."
    exit 1
  fi
  if [ ! -d /usr/share/java ]; then
    install -o root -g root -m 0755 -d /usr/share/java
  fi
  if [ -f ojdbc6.jar ]; then
    cp -p ojdbc6.jar /tmp/ojdbc6.jar
    install -o root -g root -m 0644 /tmp/ojdbc6.jar /usr/share/java/
    ln -sf ojdbc6.jar /usr/share/java/oracle-connector-java.jar
    ls -l /usr/share/java/ojdbc6.jar
  fi
  if [ -f ojdbc8.jar ]; then
    cp -p ojdbc8.jar /tmp/ojdbc8.jar
    install -o root -g root -m 0644 /tmp/ojdbc8.jar /usr/share/java/
    ln -sf ojdbc8.jar /usr/share/java/oracle-connector-java.jar
    ls -l /usr/share/java/ojdbc8.jar
  fi
  ls -l /usr/share/java/oracle-connector-java.jar
  popd
}

echo "********************************************************************************"
echo "*** $(basename $0) $@"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# TODO
INSTALLDB=$1
if [ -z "$INSTALLDB" ]; then
  INSTALLDB=embedded
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

echo "Installing Cloudera Manager Server..."
echo "CM database is: $INSTALLDB"
echo "CM version is: $SCMVERSION"
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  # Test to see if JDK 6 is present.
  if rpm -q jdk >/dev/null; then
    HAS_JDK=yes
  else
    HAS_JDK=no
  fi
  # Because it may have been put there by some other process.
  if [ ! -f /etc/yum.repos.d/cloudera-manager.repo ]; then
    wget -q https://archive.cloudera.com/cm5/redhat/${OSREL}/x86_64/cm/cloudera-manager.repo -O /etc/yum.repos.d/cloudera-manager.repo
    chown root:root /etc/yum.repos.d/cloudera-manager.repo
    chmod 0644 /etc/yum.repos.d/cloudera-manager.repo
    if [ -n "$SCMVERSION" ]; then
      sed -e "s|/cm/5/|/cm/${SCMVERSION}/|" -i /etc/yum.repos.d/cloudera-manager.repo
    fi
  fi
  if [ "$INSTALLDB" == embedded ]; then
    yum -y -e1 -d1 install cloudera-manager-server-db-2
    service cloudera-scm-server-db start
    chkconfig cloudera-scm-server-db on
  fi
  yum -y -e1 -d1 install cloudera-manager-server openldap-clients
  if [ "$INSTALLDB" == embedded ]; then
    service cloudera-scm-server start
    chkconfig cloudera-scm-server on
  else
    if [ "$INSTALLDB" == mysql ]; then
      yum -y -e1 -d1 install mysql-connector-java
      # Removes JDK 6 if it snuck onto the system. Tests for the actual RPM
      # named "jdk" to keep virtual packages from causing a JDK 8 uninstall.
      if [ "$HAS_JDK" == no ] && rpm -q jdk >/dev/null; then yum -y -e1 -d1 remove jdk; fi
    elif [ "$INSTALLDB" == postgresql ]; then
      yum -y -e1 -d1 install postgresql-jdbc
    elif [ "$INSTALLDB" == oracle ]; then
      _install_oracle_jdbc
    else
      echo "** ERROR: Argument must be either embedded, mysql, postgresql, or oracle."
    fi
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "** Now you must configure the Cloudera Manager server to connect to the external"
    echo "** database.  Please run:"
    echo "/usr/share/cmf/schema/scm_prepare_database.sh"
    echo "** and then:"
    echo "service cloudera-scm-server start"
    echo "chkconfig cloudera-scm-server on"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
  fi
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
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
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y -qq update
  if [ "$INSTALLDB" == embedded ]; then
    apt-get -y -q install cloudera-manager-server-db-2
    service cloudera-scm-server-db start
    update-rc.d cloudera-scm-server-db defaults
  fi
  apt-get -y -q install cloudera-manager-server ldap-utils
  update-rc.d apache2 disable
  service apache2 stop
  if [ "$INSTALLDB" == embedded ]; then
    service cloudera-scm-server start
    update-rc.d cloudera-scm-server defaults
  else
    if [ "$INSTALLDB" == mysql ]; then
      apt-get -y -q install libmysql-java
    elif [ "$INSTALLDB" == postgresql ]; then
      apt-get -y -q install libpostgresql-jdbc-java
    elif [ "$INSTALLDB" == oracle ]; then
      _install_oracle_jdbc
    else
      echo "** ERROR: Argument must be either embedded, mysql, or postgresql, or oracle."
    fi
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "** Now you must configure the Cloudera Manager server to connect to the external"
    echo "** database.  Please run:"
    echo "/usr/share/cmf/schema/scm_prepare_database.sh"
    echo "** and then:"
    echo "service cloudera-scm-server start"
    echo "update-rc.d cloudera-scm-server-db defaults"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
  fi
fi

