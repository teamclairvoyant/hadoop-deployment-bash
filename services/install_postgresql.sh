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

DATE=`date '+%Y%m%d%H%M%S'`

if rpm -q redhat-lsb-core; then
  OSREL=`lsb_release -rs | awk -F. '{print $1}'`
else
  OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
fi
yum -y -e1 -d1 install postgresql-server

postgresql-setup initdb

if [ ! -f /var/lib/pgsql/data/pg_hba.conf-orig ]; then
  cp -p /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf-orig
else
  cp -p /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.${DATE}
fi
sed -e '/# CLAIRVOYANT$/d' \
    -e '/^host\s*all\s*all\s*127.0.0.1\/32\s*\sident$/i\
host    all             all             0.0.0.0/0               md5 # CLAIRVOYANT' \
    -i /var/lib/pgsql/data/pg_hba.conf
#host    all             all             127.0.0.1/32            md5 # CLAIRVOYANT' \

# https://www.cloudera.com/documentation/enterprise/latest/topics/cm_ig_extrnl_pstgrs.html
if [ ! -f /var/lib/pgsql/data/postgresql.conf-orig ]; then
  cp -p /var/lib/pgsql/data/postgresql.conf /var/lib/pgsql/data/postgresql.conf-orig
else
  cp -p /var/lib/pgsql/data/postgresql.conf /var/lib/pgsql/data/postgresql.conf.${DATE}
fi
sed -e '/# CLAIRVOYANT$/d' \
    -e '/^max_connections/d' \
    -e '/^listen_addresses/d' \
    -e '/^shared_buffers/d' \
    -e '/^wal_buffers/d' \
    -e '/^checkpoint_segments/d' \
    -e '/^checkpoint_completion_target/d' \
    -e '/^standard_conforming_strings/d' \
    -i /var/lib/pgsql/data/postgresql.conf
cat <<EOF >>/var/lib/pgsql/data/postgresql.conf
max_connections = 500                                            # CLAIRVOYANT
listen_addresses = '*'                                           # CLAIRVOYANT
shared_buffers = 256MB                                           # CLAIRVOYANT
wal_buffers = 8MB                                                # CLAIRVOYANT
checkpoint_segments = 16                                         # CLAIRVOYANT
checkpoint_completion_target = 0.9                               # CLAIRVOYANT
# This is needed to make Hive work with Postgresql 9.1 and above # CLAIRVOYANT
# See OPSAPS-11795                                               # CLAIRVOYANT
standard_conforming_strings = off                                # CLAIRVOYANT
EOF

service postgresql restart
chkconfig postgresql on

_PASS=`apg -a 1 -M NCL -m 20 -x 20 -n 1`
if [ -z "$_PASS" ]; then
  _PASS=`< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo`
fi
echo "postgres : ${_PASS}"

su - postgres -c 'psql' <<EOF
\password
$_PASS
$_PASS
\q
EOF

