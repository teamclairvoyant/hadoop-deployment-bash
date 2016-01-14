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

INSTALLDB=$1
if [ -z "$INSTALLDB" ]; then
  INSTALLDB=yes
fi
if rpm -q redhat-lsb-core; then
  OSREL=`lsb_release -rs | awk -F. '{print $1}'`
else
  OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
fi
wget -q http://archive.cloudera.com/cm5/redhat/${OSREL}/x86_64/cm/cloudera-manager.repo -O /etc/yum.repos.d/cloudera-manager.repo
if [ "$INSTALLDB" = yes ]; then
  yum -y -e1 -d1 install cloudera-manager-server-db-2
  service cloudera-scm-server-db start
  chkconfig cloudera-scm-server-db on
fi
yum -y -e1 -d1 install cloudera-manager-server openldap-clients
if [ "$INSTALLDB" = yes ]; then
  service cloudera-scm-server start
  chkconfig cloudera-scm-server on
else
  #yum -y -e1 -d1 install mysql-connector-java postgresql-jdbc
  echo "** Now you must configure the Cloudera Manager server to connect to the external"
  echo "** database.  Please edit /etc/cloudera-scm-server/db.properties , then run:"
  echo "** EITHER"
  echo "yum -y -e1 -d1 install mysql-connector-java"
  echo "** OR"
  echo "yum -y -e1 -d1 install postgresql-jdbc"
  echo "** AND then"
  echo "service cloudera-scm-server start"
  echo "chkconfig cloudera-scm-server on"
fi

