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

# TODO
INSTALLDB=$1
if [ -z "$INSTALLDB" ]; then
  INSTALLDB=embedded
fi
SCMVERSION=$2
if rpm -q redhat-lsb-core; then
  OSREL=`lsb_release -rs | awk -F. '{print $1}'`
else
  OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
fi
if rpm -q jdk >/dev/null; then
  HAS_JDK=yes
else
  HAS_JDK=no
fi
PROXY=`egrep -h '^ *http_proxy=http|^ *https_proxy=http' /etc/profile.d/*`
eval $PROXY
export http_proxy
export https_proxy
if [ ! -f /etc/yum.repos.d/cloudera-manager.repo ]; then
  wget -q https://archive.cloudera.com/cm5/redhat/${OSREL}/x86_64/cm/cloudera-manager.repo -O /etc/yum.repos.d/cloudera-manager.repo
  if [ -n "$SCMVERSION" ]; then
    sed -e "s|/cm/5/|/cm/${SCMVERSION}/|" -i /etc/yum.repos.d/cloudera-manager.repo
  fi
fi
if [ "$INSTALLDB" = embedded ]; then
  yum -y -e1 -d1 install cloudera-manager-server-db-2
  service cloudera-scm-server-db start
  chkconfig cloudera-scm-server-db on
fi
yum -y -e1 -d1 install cloudera-manager-server openldap-clients
if [ "$INSTALLDB" = embedded ]; then
  service cloudera-scm-server start
  chkconfig cloudera-scm-server on
else
  if [ "$INSTALLDB" = mysql ]; then
    yum -y -e1 -d1 install mysql-connector-java
    if [ $HAS_JDK = no ]; then yum -y -e1 -d1 remove jdk; fi
  elif [ "$INSTALLDB" = postgresql ]; then
    yum -y -e1 -d1 install postgresql-jdbc
  else
    echo "** ERROR: Argument must be either embedded, mysql, or postgresql."
  fi
  echo "** Now you must configure the Cloudera Manager server to connect to the external"
  echo "** database.  Please run:"
  echo "/usr/share/cmf/schema/scm_prepare_database.sh"
  echo "** and then:"
  echo "service cloudera-scm-server start"
  echo "chkconfig cloudera-scm-server on"
fi

