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

PATH=/bin:/sbin:/usr/bin:/usr/sbin

if rpm -q redhat-lsb-core >/dev/null; then
  OSREL=`lsb_release -rs | awk -F. '{print $1}'`
else
  OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
fi

echo "****************************************"
echo "*** vm.swappiness"
echo "** running config:"
sysctl vm.swappiness
echo "** startup config:"
grep vm.swappiness /etc/sysctl.conf

echo "****************************************"
echo "*** JAVA_HOME"
echo $JAVA_HOME
echo $PATH
java -version

echo "****************************************"
echo "*** disable firewall"
if [ $OSREL == 6 ]; then
  echo "** running config:"
  service iptables status
  echo "** startup config:"
  chkconfig --list iptables
else
  echo "** running config:"
  service firewalld status
  service iptables status
  echo "** startup config:"
  chkconfig --list firewalld
  chkconfig --list iptables
fi

echo "****************************************"
echo "*** SElinux"
echo "** running config:"
getenforce
echo "** startup config:"
grep ^SELINUX= /etc/selinux/config

echo "****************************************"
echo "*** Transparent Huge Pages"
echo "** running config:"
cat /sys/kernel/mm/transparent_hugepage/defrag
echo "** startup config:"
if [ $OSREL == 6 ]; then
  grep transparent_hugepage /etc/rc.local
else
  grep transparent_hugepage /etc/rc.d/rc.local
fi

echo "****************************************"
echo "*** Filesystems"
grep noatime /etc/fstab
#tune2fs -l /dev/sda |grep blah

#echo "****************************************"
#echo "*** Entropy"
#echo "** running config:"
#echo "** startup config:"
echo "****************************************"
echo "*** JCE"
if [ -d /usr/java/jdk1.6.0_31/jre/lib/security/ ]; then
  ls -l /usr/java/jdk1.6.0_31/jre/lib/security/*.jar
fi
if [ -d /usr/java/jdk1.7.0_67-cloudera/jre/lib/security/ ]; then
  ls -l /usr/java/jdk1.7.0_67-cloudera/jre/lib/security/*.jar
fi
if [ -d /usr/java/jdk1.8.0_*/jre/lib/security/ ]; then
  ls -l /usr/java/jdk1.8.0_*/jre/lib/security/*.jar
fi

echo "****************************************"
echo "*** JDBC"
rpm -q mysql-connector-java postgresql-jdbc

echo "****************************************"
echo "*** Java"
rpm -q oracle-j2sdk1.7
rpm -qa | egrep 'jdk|jre' | sort
java -version

echo "****************************************"
echo "*** Kerberos"
echo "** running config:"
echo "** startup config:"
rpm -q krb5-workstation kstart k5start

echo "****************************************"
echo "*** NSCD"
echo "** running config:"
service nscd status
echo "** startup config:"
chkconfig --list nscd

echo "****************************************"
echo "*** NTP"
echo "** running config:"
service ntpd status
echo "** startup config:"
chkconfig --list ntpd
if [ $OSREL == 7 ]; then
  systemctl status chronyd.service
  # chronyc sources
fi
ntpq -p

echo "****************************************"
echo "*** DNS"
# TODO

#echo "****************************************"
#echo "*** "
#echo "** running config:"
#echo "** startup config:"

