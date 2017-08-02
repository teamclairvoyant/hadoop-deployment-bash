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

if command -v lsb_release >/dev/null; then
  # CentOS, Ubuntu
  OS=`lsb_release -is`
  # 7.2.1511, 14.04
  OSVER=`lsb_release -rs`
  # 7, 14
  OSREL=`echo $OSVER | awk -F. '{print $1}'`
else
  if [ -f /etc/redhat-release ]; then
    if [ -f /etc/centos-release ]; then
      OS=CentOS
    else
      OS=RedHatEnterpriseServer
    fi
    OSVER=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n"`
    OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}'`
  #elif [ -f /etc/debian_version ]; then
  fi
fi

echo "****************************************"
echo "****************************************"
echo `hostname`
echo "****************************************"
echo "*** OS details"
if [ -f /etc/redhat-release ]; then
  if [ -f /etc/centos-release ]; then
    cat /etc/centos-release
  else
    cat /etc/redhat-release
  fi
fi
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
sudo -n pvs
echo
sudo -n vgs
echo
sudo -n lvs
echo "** Filesystems:"
df -h -t ext2 -t ext3 -t ext4 -t xfs
echo "** Network interfaces:"
ip addr
echo "** Network routes:"
ip route

# A stability bug is especially seen on hosts running kernel versions between
# 2.6.32-491.el6 and 2.6.32-504.16.2.el6(exclusive), and mostly reported on
# machines with Haswell; upgrading kernel version to 2.6.32-504.16.2.el6 or
# later is recommended.
# https://www.cloudera.com/documentation/enterprise/release-notes/topics/cdh_rn_os_ki.html
if [ \( "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS \) -a "$OSREL" == 6 ]; then
  echo "****************************************"
  echo "*** kernel"
  echo "** running config:"
  uname -r
  echo "** startup config:"
  rpm -q kernel
fi

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
if [ \( "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS \) -a "$OSREL" == 6 ]; then
  echo "** running config:"
  service iptables status
  service ip6tables status
  echo "** startup config:"
  chkconfig --list iptables
  chkconfig --list ip6tables
elif [ \( "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS \) -a "$OSREL" == 7 ]; then
  echo "** running config:"
  service firewalld status
  service iptables status
  service ip6tables status
  echo "** startup config:"
  chkconfig --list firewalld
  chkconfig --list iptables
  chkconfig --list ip6tables
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  echo "** running config:"
  service ufw status
  echo "** startup config:"
fi

echo "****************************************"
echo "*** SElinux"
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  echo "** running config:"
  getenforce
  echo "** startup config:"
  grep ^SELINUX= /etc/selinux/config
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  echo "Debian/Ubuntu = None"
fi

echo "****************************************"
echo "*** Transparent Huge Pages defrag"
echo "** running config:"
echo "* defrag:"
cat /sys/kernel/mm/transparent_hugepage/defrag
echo "* enabled:"
cat /sys/kernel/mm/transparent_hugepage/enabled
echo "** startup config:"
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  grep transparent_hugepage /etc/rc.d/rc.local
else
  grep transparent_hugepage /etc/rc.local
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
if [ "$OS" == CentOS -o "$OS" == RedHatEnterpriseServer ]; then
  service rngd status
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  service rng-tools status || ps -o user,pid,command -C rngd
fi
echo "** startup config:"
chkconfig --list rngd
echo "** available entropy:"
cat /proc/sys/kernel/random/entropy_avail

echo "****************************************"
echo "*** JCE"
if [ -d /usr/java/jdk1.6.0_31/jre/lib/security/ ]; then
  ls -l /usr/java/jdk1.6.0_31/jre/lib/security/*.jar
  sha1sum /usr/java/jdk1.6.0_31/jre/lib/security/*.jar
fi
if [ -d /usr/java/jdk1.7.0_67-cloudera/jre/lib/security/ ]; then
  ls -l /usr/java/jdk1.7.0_67-cloudera/jre/lib/security/*.jar
  sha1sum /usr/java/jdk1.7.0_67-cloudera/jre/lib/security/*.jar
fi
if [ -d /usr/java/jdk1.8.0_*/jre/lib/security/ ]; then
  ls -l /usr/java/jdk1.8.0_*/jre/lib/security/*.jar
  sha1sum /usr/java/jdk1.8.0_*/jre/lib/security/*.jar
fi
if [ -d /usr/java/default/jre/lib/security/ ]; then
  ls -l /usr/java/default/jre/lib/security/*.jar
  sha1sum /usr/java/default/jre/lib/security/*.jar
fi
if [ -d /usr/lib/jvm/java-7-openjdk-amd64/jre/lib/security/ ]; then
  ls -l /usr/lib/jvm/java-7-openjdk-amd64/jre/lib/security/*.jar
  sha1sum /usr/lib/jvm/java-7-openjdk-amd64/jre/lib/security/*.jar
fi
if [ -d /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/security/ ]; then
  ls -l /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/security/*.jar
  sha1sum /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/security/*.jar
fi
if [ -d /usr/lib/jvm/default-java/jre/lib/security/ ]; then
  ls -l /usr/lib/jvm/default-java/jre/lib/security/*.jar
  sha1sum /usr/lib/jvm/default-java/jre/lib/security/*.jar
fi
if [ -d /usr/lib/jvm/java-7-oracle/jre/lib/security/ ]; then
  ls -l /usr/lib/jvm/java-7-oracle/jre/lib/security/*.jar
  sha1sum /usr/lib/jvm/java-7-oracle/jre/lib/security/*.jar
fi
if [ -d /usr/lib/jvm/java-8-oracle/jre/lib/security/ ]; then
  ls -l /usr/lib/jvm/java-8-oracle/jre/lib/security/*.jar
  sha1sum /usr/lib/jvm/java-8-oracle/jre/lib/security/*.jar
fi

echo "****************************************"
echo "*** JDBC"
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  rpm -q mysql-connector-java postgresql-jdbc
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  dpkg -l libmysql-java libpostgresql-jdbc-java | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi
ls -l /usr/share/java/mysql-connector-java.jar
ls -l /usr/share/java/oracle-connector-java.jar /usr/share/java/ojdbc?.jar
ls -l /usr/share/java/sqlserver-connector-java.jar /usr/share/java/sqljdbc*.jar

echo "****************************************"
echo "*** Java"
echo "** installed Java(s):"
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  rpm -qa | egrep 'jdk|jre|^java-|j2sdk' | sort
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  #dpkg -l | egrep 'jdk|jre|^java-|j2sdk'
  dpkg -l \*jdk\* \*jre\* java-\* \*j2sdk\* oracle-java\* | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi
echo "** default java version:"
java -version 2>&1
# Which is our standard?
echo "** which java:"
which java

echo "****************************************"
echo "*** Kerberos"
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  rpm -q krb5-workstation kstart k5start
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  dpkg -l krb5-user kstart k5start | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi

echo "****************************************"
echo "*** NSCD"
echo "** running config:"
service nscd status
echo "** startup config:"
chkconfig --list nscd

echo "****************************************"
echo "*** NTP"
echo "** running config:"
if [ "$OS" == CentOS -o "$OS" == RedHatEnterpriseServer ]; then
  service ntpd status
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  service ntp status
fi
echo "** startup config:"
RETVAL=0
chkconfig --list ntpd
if [ \( "$OS" == CentOS -o "$OS" == RedHatEnterpriseServer \) -a "$OSREL" == 7 ]; then
  systemctl status chronyd.service
  RETVAL=$?
  # Do we want to support chrony? Does CM?
fi
echo "** timesync status:"
ntpq -p
if [ \( "$OS" == CentOS -o "$OS" == RedHatEnterpriseServer \) -a \( "$OSREL" == 7 -a "$RETVAL" == 0 \) ]; then
  chronyc sources
fi

echo "****************************************"
echo "*** Timezone"
date +'%Z %z'

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
#python -c 'import socket; print socket.getfqdn(), socket.gethostbyname(socket.getfqdn())'


echo "****************************************"
echo "*** Cloudera Software"
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  rpm -qa ^cloudera\*
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  dpkg -l \*cloudera\* | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi
echo "*** Cloudera Hadoop Packages"
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  rpm -qa ^hadoop\*
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  dpkg -l hadoop | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi

echo "****************************************"
echo "*** Native Code"
hadoop checknative

#echo "****************************************"
#echo "*** "
#echo "** running config:"
#echo "** startup config:"

exit 0

