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
USECLOUDERA=$1
if [ -z "$USECLOUDERA" ]; then
  USECLOUDERA=yes
fi
SCMVERSION=$2
if rpm -q redhat-lsb-core; then
  OSREL=`lsb_release -rs | awk -F. '{print $1}'`
else
  OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
fi
PROXY=`egrep -h '^ *http_proxy=http|^ *https_proxy=http' /etc/profile.d/*`
eval $PROXY
export http_proxy
export https_proxy
if [ "$USECLOUDERA" = yes ]; then
  if [ ! -f /etc/yum.repos.d/cloudera-manager.repo ]; then
    wget -q https://archive.cloudera.com/cm5/redhat/${OSREL}/x86_64/cm/cloudera-manager.repo -O /etc/yum.repos.d/cloudera-manager.repo
    if [ -n "$SCMVERSION" ]; then
      sed -e "s|/cm/5/|/cm/${SCMVERSION}/|" -i /etc/yum.repos.d/cloudera-manager.repo
    fi
  fi
  yum -y -e1 -d1 install oracle-j2sdk1.7
  DIRNAME=`rpm -ql oracle-j2sdk1.7|head -1`
  TARGET=`basename $DIRNAME`
  ln -s $TARGET /usr/java/default
elif [ "$USECLOUDERA" = 7 ]; then
  pushd /tmp
  wget -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
    http://download.oracle.com/otn/java/jdk/7u80-b15/jdk-7u80-linux-x64.rpm -O jdk-7u80-linux-x64.rpm
  rpm -Uvh jdk-7u80-linux-x64.rpm
  popd
elif [ "$USECLOUDERA" = 8 ]; then
  pushd /tmp
  wget -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
    http://download.oracle.com/otn-pub/java/jdk/8u91-b14/jdk-8u91-linux-x64.rpm -O jdk-8u91-linux-x64.rpm
  rpm -Uvh jdk-8u91-linux-x64.rpm
  popd
else
  echo "ERROR: Unknown Java version.  Please choose 7 or 8."
  exit 10
fi

