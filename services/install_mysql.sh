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

if rpm -q redhat-lsb-core; then
  OSREL=`lsb_release -rs | awk -F. '{print $1}'`
else
  OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
fi
if [ $OSREL == 6 ]; then
  yum -y -e1 -d1 install mysql-server
  mkdir /etc/my.cnf.d
else
  yum -y -e1 -d1 install mariadb-server
fi

cat <<EOF >/etc/my.cnf.d/cloudera.cnf
[mysqld]
transaction-isolation = READ-COMMITTED
# Disabling symbolic-links is recommended to prevent assorted security risks;
# to do so, uncomment this line:
# symbolic-links = 0

key_buffer = 16M
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
innodb_flush_log_at_trx_commit = 1
innodb_log_buffer_size = 64M
innodb_buffer_pool_size = 4G
innodb_thread_concurrency = 8
innodb_flush_method = O_DIRECT
innodb_log_file_size = 512M


#[mysqld_safe]
#log-error=/var/log/mysqld.log
#pid-file=/var/run/mysqld/mysqld.pid
#sql_mode=STRICT_ALL_TABLES
EOF

cat <<EOF >/etc/my.cnf.d/replication.cnf
[mysqld]
# replication config START
server-id=$(printf "%d\n" 0x`hostid`)
log-bin=mysql-bin
relay-log=mysql-relay-bin
expire_logs_days=10
sync_binlog=1
# replication config END
innodb_flush_log_at_trx_commit=1
EOF

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
echo "root : ${_PASS}"

mysql_secure_installation <<EOF

y
$_PASS
$_PASS
y
n
y
y
EOF

