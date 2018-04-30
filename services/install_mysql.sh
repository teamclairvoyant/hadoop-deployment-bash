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
# Copyright Clairvoyant 2016

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
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS ]; then
#if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Installing MySQL server..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  if [ $OSREL == 6 ]; then
    yum -y -e1 -d1 install mysql-server
    mkdir -m 0755 /etc/my.cnf.d
  else
    yum -y -e1 -d1 install mariadb-server
  fi

  echo "Tuning config for Cloudera Manager and 4 GiB RAM."
  cat <<EOF >/etc/my.cnf.d/cloudera.cnf
# CLAIRVOYANT
# https://www.cloudera.com/documentation/enterprise/latest/topics/cm_ig_mysql.html
[mysqld]
transaction-isolation = READ-COMMITTED
# Disabling symbolic-links is recommended to prevent assorted security risks;
# to do so, uncomment this line:
# symbolic-links = 0

key_buffer = 32M
key_buffer_size = 32M
max_allowed_packet = 32M
thread_stack = 256K
thread_cache_size = 64
query_cache_limit = 8M
query_cache_size = 64M
query_cache_type = 1

max_connections = 550
#expire_logs_days = 10
#max_binlog_size = 100M

#log_bin should be on a disk with enough free space. Replace '/var/lib/mysql/mysql_binary_log' with an appropriate path for your system
#and chown the specified folder to the mysql user.
#log_bin=/var/lib/mysql/mysql_binary_log

# For MySQL version 5.1.8 or later. Comment out binlog_format for older versions.
binlog_format = mixed

read_buffer_size = 2M
read_rnd_buffer_size = 16M
sort_buffer_size = 8M
join_buffer_size = 8M

# InnoDB settings
innodb_file_per_table = 1
innodb_flush_log_at_trx_commit = 2
innodb_log_buffer_size = 64M
innodb_buffer_pool_size = 4G
innodb_thread_concurrency = 8
innodb_flush_method = O_DIRECT
innodb_log_file_size = 512M

#[mysqld_safe]
#log-error=/var/log/mysqld.log
#pid-file=/var/run/mysqld/mysqld.pid
sql_mode=STRICT_ALL_TABLES
EOF
  chown root:root /etc/my.cnf.d/cloudera.cnf
  chmod 0644 /etc/my.cnf.d/cloudera.cnf

  cat <<EOF >/etc/my.cnf.d/replication.cnf
# CLAIRVOYANT
[mysqld]
# replication config START
#server-id=$(printf "%d\n" 0x`hostid`)
#log-bin=mysql-bin
#relay-log=mysql-relay-bin
#expire_logs_days=10
#sync_binlog=1
# replication config END
#innodb_flush_log_at_trx_commit=1
EOF
  chown root:root /etc/my.cnf.d/replication.cnf
  chmod 0644 /etc/my.cnf.d/replication.cnf

  if [ -f /tmp/director.cnf ]; then
    echo "Found Cloudera Director config.  Using it in place of Cloudera Manager config."
    install -m 0644 -o root -g root /tmp/director.cnf /etc/my.cnf.d/cloudera.cnf
  fi

  if [ $OSREL == 6 ]; then
    service mysql start
    chkconfig mysql on
  else
    service mariadb start
    chkconfig mariadb on
  fi

  _PASS=`apg -a 1 -M NCL -m 20 -x 20 -n 1`
  if [ -z "$_PASS" ]; then
    _PASS=`< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo`
  fi
  echo "****************************************"
  echo "****************************************"
  echo "****************************************"
  echo "*** SAVE THIS PASSWORD"
  echo "root : ${_PASS}"
  echo "****************************************"
  echo "****************************************"
  echo "****************************************"

  mysql_secure_installation <<EOF

y
$_PASS
$_PASS
y
n
y
y
EOF
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  :
fi

