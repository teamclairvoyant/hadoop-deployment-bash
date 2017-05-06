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

# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

PROXY=`egrep -h '^ *http_proxy=http|^ *https_proxy=http' /etc/profile.d/*`
eval $PROXY
export http_proxy
export https_proxy
if [ -z $http_proxy ]; then
  PROXY=`egrep -l 'http_proxy=|https_proxy=' /etc/profile.d/*`
  . $PROXY
fi

if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  if rpm -q jdk || test -d /usr/java/jdk1.6.0_*; then
    wget -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
      http://download.oracle.com/otn-pub/java/jce_policy/6/jce_policy-6.zip -O /tmp/jce_policy-6.zip
    unzip -o -j /tmp/jce_policy-6.zip -d /usr/java/jdk1.6.0_31/jre/lib/security/
  fi

  if rpm -q oracle-j2sdk1.7 || test -d /usr/java/jdk1.7.0_*; then
    wget -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
      http://download.oracle.com/otn-pub/java/jce/7/UnlimitedJCEPolicyJDK7.zip -O /tmp/jce_policy-7.zip
    unzip -o -j /tmp/jce_policy-7.zip -d /usr/java/jdk1.7.0_67-cloudera/jre/lib/security/
  fi

  if rpm -q oracle-j2sdk1.8 || test -d /usr/java/jdk1.8.0_*; then
    wget -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
      http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip -O /tmp/jce_policy-8.zip
    unzip -o -j /tmp/jce_policy-8.zip -d /usr/java/jdk1.8.0_*/jre/lib/security/
  fi
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  if dpkg -l oracle-j2sdk1.7 >/dev/null || test -d /usr/lib/jvm/java-7-oracle-cloudera; then
    wget -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
      http://download.oracle.com/otn-pub/java/jce/7/UnlimitedJCEPolicyJDK7.zip -O /tmp/jce_policy-7.zip
    unzip -o -j /tmp/jce_policy-7.zip -d /usr/lib/jvm/java-7-oracle-cloudera/jre/lib/security/
  fi

  if dpkg -l oracle-java7-installer >/dev/null || test -d /usr/lib/jvm/java-7-oracle; then
    apt-get -y -q install oracle-java7-unlimited-jce-policy
  fi

  if dpkg -l oracle-java8-installer >/dev/null || test -d /usr/lib/jvm/java-8-oracle; then
    apt-get -y -q install oracle-java8-unlimited-jce-policy
  fi
fi

