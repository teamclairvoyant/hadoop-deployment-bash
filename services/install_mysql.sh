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

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

# Function to print the help screen.
print_help() {
  echo "Usage:  $1 [--password <password>]"
  echo ""
  echo "        [-p|--password  <database root user password>]"
  echo "        [-h|--help]"
  echo "        [-v|--version]"
  echo ""
  echo "   ex.  $1 --password abcdefghij"
  exit 1
}

# Function to discover basic OS details.
discover_os() {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu, RedHatEnterpriseServer, RedHatEnterprise, Debian, SUSE LINUX, OracleServer
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
        # shellcheck disable=SC2034
        OSREL=$(rpm -qf /etc/centos-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
        # shellcheck disable=SC2034
        OSNAME=$(awk -F"[()]" '{print $2}' /etc/centos-release | sed 's| ||g')
        if [ -z "$OSNAME" ]; then
          # shellcheck disable=SC2034
          OSNAME="n/a"
        fi
        if [ "$OSREL" -le "6" ]; then
          # 6.10.el6.centos.12.3
          # shellcheck disable=SC2034
          OSVER=$(rpm -qf /etc/centos-release --qf='%{VERSION}.%{RELEASE}\n' | awk -F. '{print $1"."$2}')
        elif [ "$OSREL" == "7" ]; then
          # 7.5.1804.4.el7.centos
          # shellcheck disable=SC2034
          OSVER=$(rpm -qf /etc/centos-release --qf='%{VERSION}.%{RELEASE}\n' | awk -F. '{print $1"."$2"."$3}')
        elif [ "$OSREL" == "8" ]; then
          if [ "$(rpm -qf /etc/centos-release --qf='%{NAME}\n')" == "centos-stream-release" ]; then
            # shellcheck disable=SC2034
            OS=CentOSStream
            # shellcheck disable=SC2034
            OSVER=$(rpm -qf /etc/centos-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
          else
            # shellcheck disable=SC2034
            OSVER=$(rpm -qf /etc/centos-release --qf='%{VERSION}.%{RELEASE}\n' | awk -F. '{print $1"."$2"."$4}')
          fi
        else
          # shellcheck disable=SC2034
          OS=CentOSStream
          # shellcheck disable=SC2034
          OSVER=$(rpm -qf /etc/centos-release --qf='%{VERSION}\n')
        fi
      elif [ -f /etc/oracle-release ]; then
        # shellcheck disable=SC2034
        OS=OracleServer
        # 7.6
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/oracle-release --qf='%{VERSION}\n')
        # shellcheck disable=SC2034
        OSNAME="n/a"
      else
        # shellcheck disable=SC2034
        OS=RedHatEnterpriseServer
        # 8.6, 7.5, 6Server
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/redhat-release --qf='%{VERSION}\n')
        # shellcheck disable=SC2034
        OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
        if [ "$OSVER" == "6Server" ]; then
          # shellcheck disable=SC2034
          OSVER=$(rpm -qf /etc/redhat-release --qf='%{RELEASE}\n' | awk -F. '{print $1"."$2}')
        elif [ "$OSREL" == "8" ]; then
          # shellcheck disable=SC2034
          OS=RedHatEnterprise
        fi
        # shellcheck disable=SC2034
        OSNAME=$(awk -F"[()]" '{print $2}' /etc/redhat-release | sed 's| ||g')
      fi
      # shellcheck disable=SC2034
      OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    elif [ -f /etc/SuSE-release ]; then
      if grep -q "^SUSE Linux Enterprise Server" /etc/SuSE-release; then
        # shellcheck disable=SC2034
        OS="SUSE LINUX"
      fi
      # shellcheck disable=SC2034
      OSVER=$(rpm -qf /etc/SuSE-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
      # shellcheck disable=SC2034
      OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
      # shellcheck disable=SC2034
      OSNAME="n/a"
    fi
  fi
}

# Process arguments.
while [[ $1 = -* ]]; do
  case $1 in
    -p|--password)
      shift
      _PASS=$1
      ;;
    -h|--help)
      print_help "$(basename "$0")"
      ;;
    -v|--version)
      echo "Install MySQL/MariaDB."
      exit 0
      ;;
    *)
      print_help "$(basename "$0")"
      ;;
  esac
  shift
done

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != AlmaLinux ]; then
#if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != AlmaLinux ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Installing MySQL server..."
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == AlmaLinux ]; then
  if [ "$OSREL" == 6 ]; then
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
#server-id=$(printf '%d\n' "0x$(hostid)")
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

  if [ "$OSREL" == 6 ]; then
    service mysql start
    chkconfig mysql on
  else
    service mariadb start
    chkconfig mariadb on
  fi

  if [ -z "$_PASS" ]; then
    _PASS=$(apg -a 1 -M NCL -m 20 -x 20 -n 1)
    if [ -z "$_PASS" ]; then
      _PASS=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo)
    fi
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "*** SAVE THIS PASSWORD"
    echo "root : ${_PASS}"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
  fi

  mysql_secure_installation <<EOF

y
$_PASS
$_PASS
y
n
y
y
EOF
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  :
fi

