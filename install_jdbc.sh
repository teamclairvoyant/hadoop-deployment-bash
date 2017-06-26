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

VERSION=5.1.31

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

_get_proxy() {
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
}

_jdk_major_version() {
  local JVER MAJ_JVER
  JVER=$(java -version 2>&1 | awk '/java version/{print $NF}' | sed -e 's|"||g')
  MAJ_JVER=$(echo $JVER | awk -F. '{print $2}')
  echo $MAJ_JVER
}

_install_oracle_jdbc() {
  pushd $(dirname $0)
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

_install_sqlserver_jdbc() {
  # https://www.cloudera.com/documentation/enterprise/5-10-x/topics/cdh_ig_jdbc_driver_install.html
  pushd /tmp
  _get_proxy
  SQLSERVER_VERSION=6.0.8112.100
  wget -q -c -O /tmp/sqljdbc_${SQLSERVER_VERSION}_enu.tar.gz https://download.microsoft.com/download/0/2/A/02AAE597-3865-456C-AE7F-613F99F850A8/enu/sqljdbc_${SQLSERVER_VERSION}_enu.tar.gz
  tar xf /tmp/sqljdbc_${SQLSERVER_VERSION}_enu.tar.gz -C /tmp
  if [ ! -d /usr/share/java ]; then
    install -o root -g root -m 0755 -d /usr/share/java
  fi
  JVER=$(_jdk_major_version)
  if [[ "$JVER" == 7 ]]; then
    install -o root -g root -m 0644 sqljdbc_6.0/enu/jre7/sqljdbc41.jar /usr/share/java/
    ls -l /usr/share/java/sqljdbc41.jar
  elif [[ "$JVER" == 8 ]]; then
    install -o root -g root -m 0644 sqljdbc_6.0/enu/jre8/sqljdbc42.jar /usr/share/java/
    ls -l /usr/share/java/sqljdbc42.jar
  else
    echo "ERROR: Java version either not supported or not detected."
  fi
  popd
}

# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

INSTALLDB=$1
if [ -z "$INSTALLDB" ]; then
  INSTALLDB=yes
fi

if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  if rpm -q jdk >/dev/null; then
    HAS_JDK=yes
  else
    HAS_JDK=no
  fi
  if [ "$INSTALLDB" == yes ]; then
    echo "** NOTICE: Installing mysql and postgresql JDBC drivers."
    yum -y -e1 -d1 install mysql-connector-java postgresql-jdbc
    if [ $HAS_JDK == no ]; then yum -y -e1 -d1 remove jdk; fi
  else
    if [ "$INSTALLDB" == mysql ]; then
      echo "** NOTICE: Installing mysql JDBC driver."
      if [ $OSREL == 6 ]; then
        _get_proxy
        wget -q -O /tmp/mysql-connector-java-${VERSION}.tar.gz https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${VERSION}.tar.gz
        tar xf /tmp/mysql-connector-java-${VERSION}.tar.gz -C /tmp
        if [ ! -d /usr/share/java ]; then
          install -o root -g root -m 0755 -d /usr/share/java
        fi
        install -o root -g root -m 0644 /tmp/mysql-connector-java-${VERSION}/mysql-connector-java-${VERSION}-bin.jar /usr/share/java/
        ln -sf mysql-connector-java-${VERSION}-bin.jar /usr/share/java/mysql-connector-java.jar
        ls -l /usr/share/java/*sql*
      else
        yum -y -e1 -d1 install mysql-connector-java
        if [ $HAS_JDK == no ]; then yum -y -e1 -d1 remove jdk; fi
      fi
    elif [ "$INSTALLDB" == postgresql ]; then
      echo "** NOTICE: Installing postgresql JDBC driver."
      yum -y -e1 -d1 install postgresql-jdbc
    elif [ "$INSTALLDB" == oracle ]; then
      echo "** NOTICE: Installing oracle JDBC driver."
      _install_oracle_jdbc
    elif [ "$INSTALLDB" == sqlserver ]; then
      echo "** NOTICE: Installing sqlserver JDBC driver."
      _install_sqlserver_jdbc
    else
      echo "** ERROR: Argument must be either mysql, postgresql, oracle, or sqlserver."
    fi
  fi
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  if [ "$INSTALLDB" == yes ]; then
    echo "** NOTICE: Installing mysql and postgresql JDBC drivers."
    apt-get -y -q install libmysql-java libpostgresql-jdbc-java
  else
    if [ "$INSTALLDB" == mysql ]; then
      echo "** NOTICE: Installing mysql JDBC driver."
      apt-get -y -q install libmysql-java
    elif [ "$INSTALLDB" == postgresql ]; then
      echo "** NOTICE: Installing postgresql JDBC driver."
      apt-get -y -q install libpostgresql-jdbc-java
    elif [ "$INSTALLDB" == oracle ]; then
      echo "** NOTICE: Installing oracle JDBC driver."
      _install_oracle_jdbc
    elif [ "$INSTALLDB" == sqlserver ]; then
      echo "** NOTICE: Installing sqlserver JDBC driver."
      _install_sqlserver_jdbc
    else
      echo "** ERROR: Argument must be either mysql, postgresql, oracle, or sqlserver."
    fi
  fi
fi

