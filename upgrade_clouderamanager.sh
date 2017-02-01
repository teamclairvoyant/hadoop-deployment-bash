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

if rpm -q cloudera-manager-agent; then
  SCMVERSION=$1
  if [ -z "$SCMVERSION" ]; then
    echo "ERROR: Missing SCM version."
    exit 1
  fi
  if rpm -q redhat-lsb-core; then
    OSREL=`lsb_release -rs | awk -F. '{print $1}'`
  else
    OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
  fi
  PROXY=`egrep -h '^ *http_proxy=http|^ *https_proxy=http' /etc/profile.d/*`
  eval $PROXY
  export http_proxy
  export https_proxy

  if [ ! -f /etc/yum.repos.d/cloudera-manager.repo ]; then
    wget -q https://archive.cloudera.com/cm5/redhat/${OSREL}/x86_64/cm/cloudera-manager.repo -O /etc/yum.repos.d/cloudera-manager.repo
  fi
  sed -e "s|/cm/5[0-9.]*/|/cm/${SCMVERSION}/|" -i /etc/yum.repos.d/cloudera-manager.repo

  service cloudera-scm-agent stop
  yum -y -e1 -d1 update cloudera-manager-agent
  if rpm -q cloudera-manager-server-db-2; then
    service cloudera-scm-server-db start
  fi
  if rpm -q cloudera-manager-server; then
    service cloudera-scm-server start
  fi
  service cloudera-scm-agent start
fi

