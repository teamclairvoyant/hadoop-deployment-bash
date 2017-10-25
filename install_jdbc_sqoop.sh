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
# Copyright Clairvoyant 2017

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

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Installing JDBC driver(s) for Sqoop..."
if [ -d /var/lib/sqoop ]; then
  if [ -f /usr/share/java/mysql-connector-java.jar ]; then
    ln -sf /usr/share/java/mysql-connector-java.jar /var/lib/sqoop/
  fi
  if [ -f /usr/share/java/oracle-connector-java.jar ]; then
    ln -sf /usr/share/java/oracle-connector-java.jar /var/lib/sqoop/
  fi
  if [ -f /usr/share/java/sqlserver-connector-java.jar ]; then
    ln -sf /usr/share/java/sqlserver-connector-java.jar /var/lib/sqoop/
  fi
  if [ -f /usr/share/java/postgresql-jdbc.jar ]; then
    ln -sf /usr/share/java/postgresql-jdbc.jar /var/lib/sqoop/
  fi
  if [ -f /usr/share/java/postgresql.jar ]; then
    ln -sf /usr/share/java/postgresql.jar /var/lib/sqoop/
  fi
else
  echo "WARNING: /var/lib/sqoop not found."
fi

if [ -d /var/lib/sqoop2 ]; then
  if [ -f /usr/share/java/mysql-connector-java.jar ]; then
    ln -sf /usr/share/java/mysql-connector-java.jar /var/lib/sqoop2/
  fi
  if [ -f /usr/share/java/oracle-connector-java.jar ]; then
    ln -sf /usr/share/java/oracle-connector-java.jar /var/lib/sqoop2/
  fi
  if [ -f /usr/share/java/sqlserver-connector-java.jar ]; then
    ln -sf /usr/share/java/sqlserver-connector-java.jar /var/lib/sqoop2/
  fi
  if [ -f /usr/share/java/postgresql-jdbc.jar ]; then
    ln -sf /usr/share/java/postgresql-jdbc.jar /var/lib/sqoop2/
  fi
  if [ -f /usr/share/java/postgresql.jar ]; then
    ln -sf /usr/share/java/postgresql.jar /var/lib/sqoop2/
  fi
else
  echo "WARNING: /var/lib/sqoop2 not found."
fi

