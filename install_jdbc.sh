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
    yum -y -e1 -d1 install mysql-connector-java postgresql-jdbc
    if [ $HAS_JDK == no ]; then yum -y -e1 -d1 remove jdk; fi
  else
    if [ "$INSTALLDB" == mysql ]; then
      if [ $OSREL == 6 ]; then
        PROXY=`egrep -h '^ *http_proxy=http|^ *https_proxy=http' /etc/profile.d/*`
        eval $PROXY
        export http_proxy
        export https_proxy
        if [ -z $http_proxy ]; then
          PROXY=`egrep -l 'http_proxy=|https_proxy=' /etc/profile.d/*`
          . $PROXY
        fi

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
      yum -y -e1 -d1 install postgresql-jdbc
    else
      echo "** ERROR: Argument must be either mysql or postgresql."
    fi
  fi
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  if [ "$INSTALLDB" == yes ]; then
    apt-get -y -q install libmysql-java libpostgresql-jdbc-java
  else
    if [ "$INSTALLDB" == mysql ]; then
      apt-get -y -q install libmysql-java
    elif [ "$INSTALLDB" == postgresql ]; then
      apt-get -y -q install libpostgresql-jdbc-java
    else
      echo "** ERROR: Argument must be either mysql or postgresql."
    fi
  fi
fi

