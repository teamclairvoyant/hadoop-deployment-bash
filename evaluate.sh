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
echo "****************************************"
echo `hostname`
echo "****************************************"
echo "*** OS details"
if [ -f /etc/redhat-release ]; then cat /etc/redhat-release; fi
if [ -f /etc/centos-release ]; then cat /etc/centos-release; fi
if [ -f /etc/lsb-release ]; then /usr/bin/lsb_release -ds; fi

echo "****************************************"
echo "*** Hardware details"
echo "** system:"
# https://unix.stackexchange.com/questions/75750/how-can-i-find-the-hardware-model-in-linux
pushd /sys/devices/virtual/dmi/id/ >/dev/null
for f in *; do
  if [ $f != power -a $f != subsystem -a $f != modalias -a $f != uevent ]; then
    printf "$f : "
    cat $f 2>/dev/null || echo "***_Unavailable_***"
  fi
done
popd >/dev/null
#echo "** manufacturer:"
#sudo -n dmidecode -s system-manufacturer
#echo "** model:"
#sudo -n dmidecode -s system-product-name
echo "** cpu:"
grep ^processor /proc/cpuinfo |tail -1
grep ^"model name" /proc/cpuinfo |tail -1
echo "** memory:"
echo "memory          : `free -g |awk '/^Mem:/{print $2}'` GiB"
echo "** Disks:"
lsblk -lo NAME,SIZE,TYPE,MOUNTPOINT | egrep 'NAME|disk'
echo "** Logical Volumes:"
pvs
echo
vgs
echo
lvs
echo "** Filesystems:"
df -h -t ext2 -t ext3 -t ext4 -t xfs
echo "** Network:"
ip addr
echo ""
ip route

echo "****************************************"
echo "*** vm.swappiness"
echo "** running config:"
sysctl vm.swappiness
echo "** startup config:"
grep -r vm.swappiness /etc/sysctl.*

echo "****************************************"
echo "*** swap"
echo "** running config:"
swapon -s
echo
if grep -q swap /etc/fstab; then
  lsblk -lo NAME,SIZE,TYPE,MOUNTPOINT `awk '/swap/{print $1}' /etc/fstab`
fi
echo "** startup config:"
grep swap /etc/fstab || echo "none"

echo "****************************************"
echo "*** JAVA_HOME"
echo JAVA_HOME=$JAVA_HOME
echo PATH=$PATH
echo "** default java version:"
java -version 2>&1 || ${JAVA_HOME}/java -version 2>&1

echo "****************************************"
echo "*** Firewall"
if [ "$OSREL" == 6 ]; then
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
if [ "$OSREL" == 6 ]; then
  grep transparent_hugepage /etc/rc.local
else
  grep transparent_hugepage /etc/rc.d/rc.local
fi

echo "****************************************"
echo "*** Filesystems"
echo "** noatime"
echo "** running config:"
mount | grep noatime || echo "none"
echo "** startup config:"
grep noatime /etc/fstab || echo "none"
grep noatime /etc/navencrypt/ztab || echo "none"
#grep noatime /etc/fstab || echo "WARNING: No filesystems mounted with noatime."
#tune2fs -l /dev/sda |grep blah

echo "****************************************"
echo "*** Entropy"
echo "** running config:"
service rngd status
echo "** startup config:"
chkconfig --list rngd
echo "** available entropy:"
cat /proc/sys/kernel/random/entropy_avail

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
echo "** installed Java(s):"
rpm -qa | egrep 'jdk|jre|^java-|j2sdk' | sort
echo "** default java version:"
java -version 2>&1
# Which is our standard?
which java

echo "****************************************"
echo "*** Kerberos"
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
RETVAL=0
chkconfig --list ntpd
if [ "$OSREL" == 7 ]; then
  systemctl status chronyd.service
  RETVAL=$?
  # Do we want to support chrony? Does CM?
fi
echo "** timesync status:"
ntpq -p
if [ "$OSREL" == 7 -a $RETVAL == 0 ]; then
  chronyc sources
fi

echo "****************************************"
echo "*** DNS"
IP=`ip -4 a | awk '/inet/{print $2}' | grep -v 127.0.0.1 | sed -e 's|/[0-9].*||'`
echo -n "** system IP is: "
echo $IP
echo -n "** system hostname is: "
hostname
DNS=$(host `hostname`)
echo "** forward:"
echo $DNS
echo "** reverse:"
host $(echo $DNS | awk '{print $NF}')

echo "****************************************"
echo "*** Cloudera Software"
rpm -qa ^cloudera\*

#echo "****************************************"
#echo "*** "
#echo "** running config:"
#echo "** startup config:"

