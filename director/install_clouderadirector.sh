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
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

PROXY=`egrep -h '^ *http_proxy=http|^ *https_proxy=http' /etc/profile.d/*`
eval $PROXY
export http_proxy
export https_proxy
if [ -z "$http_proxy" ]; then
  PROXY=`egrep -l 'http_proxy=|https_proxy=' /etc/profile.d/*`
  if [ -n "$PROXY" ]; then
    . $PROXY
  fi
fi

echo "Installing Cloudera Director..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  # Because it may have been put there by some other process.
  if [ ! -f /etc/yum.repos.d/cloudera-director.repo ]; then
    wget -q https://archive.cloudera.com/director/redhat/${OSREL}/x86_64/director/cloudera-director.repo -O /etc/yum.repos.d/cloudera-director.repo
    chown root:root /etc/yum.repos.d/cloudera-director.repo
    chmod 0644 /etc/yum.repos.d/cloudera-director.repo
  fi
  yum -y -e1 -d1 install cloudera-director-server cloudera-director-client
  chkconfig cloudera-director-server on
elif [ "$OS" == Ubuntu ]; then
  # Because it may have been put there by some other process.
  if [ ! -f /etc/apt/sources.list.d/cloudera-director.list ]; then
    wget -q https://archive.cloudera.com/director/ubuntu/${OSNAME}/amd64/director/cloudera.list -O /etc/apt/sources.list.d/cloudera-director.list
    chown root:root /etc/apt/sources.list.d/cloudera-director.list
    chmod 0644 /etc/apt/sources.list.d/cloudera-director.list
    curl -s http://archive.cloudera.com/director/ubuntu/${OSNAME}/amd64/director/archive.key | apt-key add -
  fi
  apt-get -y -qq update
  apt-get -y -q install cloudera-director-server cloudera-director-client
  update-rc.d cloudera-director-server defaults
fi
if [ ! -f /etc/cloudera-director-server/application.properties-orig ]; then
  cp -p /etc/cloudera-director-server/application.properties /etc/cloudera-director-server/application.properties-orig
else
  cp -p /etc/cloudera-director-server/application.properties /etc/cloudera-director-server/application.properties.`date '+%Y%m%d%H%M%S'`
fi
echo "Setting a random encryption password..."
chgrp cloudera-director /etc/cloudera-director-server/application.properties
chmod 0640 /etc/cloudera-director-server/application.properties
sed -i -e '/lp.encryption.twoWayCipher:/a\
lp.encryption.twoWayCipher: desede' -e "/lp.encryption.twoWayCipherConfig:/a\
lp.encryption.twoWayCipherConfig: `python -c 'import base64, os; print base64.b64encode(os.urandom(24))'`" /etc/cloudera-director-server/application.properties
## https://www.cloudera.com/documentation/director/latest/topics/director_create_java_clusters.html
#echo "Forcing use of JDK 8..."
#sed -e '/^# lp.bootstrap.packages.javaPackage:/a\
#lp.bootstrap.packages.cmJavaPackages: .*=oracle-j2sdk1.8\
#lp.bootstrap.packages.defaultCmJavaPackage: oracle-j2sdk1.8' \
#    -i /etc/cloudera-director-server/application.properties
echo "Starting Director..."
service cloudera-director-server start

echo ""
echo "Now open http://$(hostname -f):7189/ in your web browser."

