#!/bin/bash
#
# $Id$
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
#
# No elevated privileges are required to run this script.  However, there are
# several invocations of sudo in order to gather certain pieces of information
# that are not available to unprivileged users.  Only the logical volume,
# iptables, and RHEL subscription-manager commands use sudo.
#
# Sudo is invoked in non-interactive mode and will not prompt for a password.
# This will allow for graceful failure of that command if passwordless sudo is
# not enabled for the user.  Environments that use privilege escalation tools
# different from sudo (like Centrify's dzdo) are not presently supported.

PATH=/bin:/sbin:/usr/bin:/usr/sbin

# Function to discover basic OS details.
discover_os() {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu, RedHatEnterpriseServer, Debian, SUSE LINUX, OracleServer
    # shellcheck disable=SC2034
    OS=$(lsb_release -is)
    # CentOS= 6.10, 7.2.1511, Ubuntu= 14.04, RHEL= 6.10, 7.5, SLES= 11, OEL= 7.6
    # shellcheck disable=SC2034
    OSVER=$(lsb_release -rs)
    # 7, 14
    # shellcheck disable=SC2034
    OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    # Ubuntu= trusty, wheezy, CentOS= Final, RHEL= Santiago, Maipo, SLES= n/a
    # shellcheck disable=SC2034
    OSNAME=$(lsb_release -cs)
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        # shellcheck disable=SC2034
        OS=CentOS
        # 7.5.1804.4.el7.centos, 6.10.el6.centos.12.3
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/centos-release --qf='%{VERSION}.%{RELEASE}\n' | awk -F. '{print $1"."$2}')
        # shellcheck disable=SC2034
        OSREL=$(rpm -qf /etc/centos-release --qf='%{VERSION}\n')
      elif [ -f /etc/oracle-release ]; then
        # shellcheck disable=SC2034
        OS=OracleServer
        # 7.6
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/oracle-release --qf='%{VERSION}\n')
        # shellcheck disable=SC2034
        OSREL=$(rpm -qf /etc/oracle-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
      else
        # shellcheck disable=SC2034
        OS=RedHatEnterpriseServer
        # 7.5, 6Server
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/redhat-release --qf='%{VERSION}\n')
        if [ "$OSVER" == "6Server" ]; then
          # shellcheck disable=SC2034
          OSVER=$(rpm -qf /etc/redhat-release --qf='%{RELEASE}\n' | awk -F. '{print $1"."$2}')
          # shellcheck disable=SC2034
          OSNAME=Santiago
        else
          # shellcheck disable=SC2034
          OSNAME=Maipo
        fi
        # shellcheck disable=SC2034
        OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
      fi
    elif [ -f /etc/SuSE-release ]; then
      if grep -q "^SUSE Linux Enterprise Server" /etc/SuSE-release; then
        # shellcheck disable=SC2034
        OS="SUSE LINUX"
      fi
      # shellcheck disable=SC2034
      OSVER=$(rpm -qf /etc/SuSE-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
      # shellcheck disable=SC2034
      OSREL=$(rpm -qf /etc/SuSE-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
      # shellcheck disable=SC2034
      OSNAME="n/a"
    fi
  fi
}
discover_os

echo "****************************************"
echo "****************************************"
hostname
# shellcheck disable=SC2016
echo '$Id$'
echo 'Version: 20190510'
echo "****************************************"
echo "*** OS details"
if [ -f /etc/redhat-release ]; then
  if [ -f /etc/centos-release ]; then
    cat /etc/centos-release
  elif [ -f /etc/oracle-release ]; then
    cat /etc/oracle-release
  else
    cat /etc/redhat-release
  fi
elif [ -f /etc/SuSE-release ]; then
  cat /etc/SuSE-release
elif [ -f /etc/os-release ]; then
  cat /etc/os-release
fi
if [ -f /etc/lsb-release ]; then /usr/bin/lsb_release -ds; fi

echo "****************************************"
echo "*** Hardware details"
echo "** system:"
# https://unix.stackexchange.com/questions/75750/how-can-i-find-the-hardware-model-in-linux
# shellcheck disable=SC2164
pushd /sys/devices/virtual/dmi/id/ >/dev/null
for f in *; do
  if [ "$f" != power ] && [ "$f" != subsystem ] && [ "$f" != modalias ] && [ "$f" != uevent ]; then
    printf '%s : ' "$f"
    cat "$f" 2>/dev/null || echo "***_Unavailable_***"
  fi
done
# shellcheck disable=SC2164
popd >/dev/null
#echo "** manufacturer:"
#sudo -n dmidecode -s system-manufacturer
#echo "** model:"
#sudo -n dmidecode -s system-product-name
echo "** cpu:"
grep ^processor /proc/cpuinfo | tail -1
grep ^"model name" /proc/cpuinfo | tail -1
echo "** memory:"
echo "memory          : $(free -g | awk '/^Mem:/{print $2}') GiB"
echo "** Disks:"
if [ "$OS" == "SUSE LINUX" ] && [ "$OSREL" == 11 ]; then
  lsblk -lo NAME,SIZE,MOUNTPOINT | awk '$1~/^NAME$/; $3~/^\//'
else
  lsblk -lo NAME,SIZE,TYPE,ROTA,MOUNTPOINT | awk '$1~/^NAME$/; $3~/^disk$/'
fi
echo "** Logical Volumes:"
sudo -n pvs
echo
sudo -n vgs
echo
sudo -n lvs
echo "** Filesystems:"
df -hP -t ext2 -t ext3 -t ext4 -t xfs
echo "** Network interfaces (raw):"
ip addr
echo "** Network interfaces:"
# shellcheck disable=SC2164
pushd /sys/class/net/ >/dev/null
shopt -s extglob
for _NIC in !(lo); do
  _IP=$(ip addr show dev "$_NIC")
  # shellcheck disable=SC2086
  echo "$_IP" | awk '/inet/{print "'${_NIC}' : IP:",$2}'
  # shellcheck disable=SC2086
  echo "$_IP" | awk '/mtu/{print "'${_NIC}' : MTU:",$5}'
  ethtool "$_NIC" 2>/dev/null | grep -E 'Speed:|Duplex:|Port:' | sed "s|^[[:space:]]*|${_NIC} : |g"
  #cat "/sys/class/net/${_NIC}/speed"
  #cat "/sys/class/net/${_NIC}/duplex"
done
shopt -u extglob
# shellcheck disable=SC2164
popd >/dev/null
echo "** Network routes:"
ip route
echo "** Network Bonding:"
if [ -f /proc/net/bonding/bond0 ]; then
  for BOND in /proc/net/bonding/bond*; do
    echo "*** $(basename "$BOND")"
    grep -E '^MII Status:|^Slave Interface:|^Bonding Mode:|^Speed:' "$BOND"
  done
fi

# A stability bug is especially seen on hosts running kernel versions between
# 2.6.32-491.el6 and 2.6.32-504.16.2.el6(exclusive), and mostly reported on
# machines with Haswell; upgrading kernel version to 2.6.32-504.16.2.el6 or
# later is recommended. TSB-63
# https://www.cloudera.com/documentation/enterprise/release-notes/topics/cdh_rn_os_ki.html
echo "****************************************"
echo "*** kernel bugs"
echo "** running config:"
uname -r
echo "** installed kernels:"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ]; then
  if [ "$OS" == OracleServer ]; then
    rpm -q kernel kernel-uek
    if uname -r | grep -q uek; then K="uek-"; fi
  else
    rpm -q kernel
  fi
  echo "** running kernel has fix?:"
  if uname -r | grep -Eq '^4\.[0-9].*uek'; then
    echo "Kernel is OK (futex TSB-63)"
  elif rpm -q --changelog "kernel-${K}$(uname -r)" | grep -q 'Ensure get_futex_key_refs() always implies a barrier'; then
    echo "Kernel is OK (futex TSB-63)"
  else
    echo "Kernel is VULNERABLE (futex TSB-63)"
  fi
  if rpm -q --changelog "kernel-${K}$(uname -r)" | grep -Eq 'allow JVM to implement its own stack guard pages|fix new crash in unmapped_area_topdown()'; then
    echo "Kernel is OK (JVM crash TSB-2017-242)"
  elif rpm -q --changelog "kernel-${K}$(uname -r)" | grep -q '^- \[mm\] enlarge stack guard gap (Larry Woodman) .*{CVE-2017-1000364}'; then
    echo "Kernel is VULNERABLE (JVM crash TSB-2017-242)"
  else
    echo "Kernel is OK (JVM crash TSB-2017-242)"
  fi
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  dpkg -l linux-image-[0-9]\* | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
  echo "** running kernel has fix?:"
  _VAL=$(apt-get changelog "linux-image-$(uname -r)")
  RETVAL=$?
  # We could not retreive the changelog.
  if [ "$RETVAL" -ne 0 ]; then
    echo "Kernel is UNKNOWN (futex TSB-63)"
    echo "Kernel is UNKNOWN (JVM crash TSB-2017-242)"
  else
    if uname -r | grep -q '^2\.'; then
      # TODO: The following is unreliable
      echo "The following line is unreliable:"
      if echo "${_VAL}" | grep -q 'futex: Ensure get_futex_key_refs() always implies a barrier'; then
        echo "Kernel is OK (futex TSB-63)"
      else
        echo "Kernel is VULNERABLE (futex TSB-63)"
      fi
    else
      echo "Kernel is OK (futex TSB-63)"
    fi
    if echo "${_VAL}" | grep -q 'fix new crash in unmapped_area_topdown()'; then
      echo "Kernel is OK (JVM crash TSB-2017-242)"
    elif echo "${_VAL}" | grep -q 'CVE-2017-1000364'; then
      echo "Kernel is VULNERABLE (JVM crash TSB-2017-242)"
    else
      echo "Kernel is OK (JVM crash TSB-2017-242)"
    fi
  fi
elif [ "$OS" == "SUSE LINUX" ]; then
  rpm -q kernel-default-base
  echo "** running kernel has fix?:"
  if rpm -q --changelog kernel-default-base | grep -q 'Ensure get_futex_key_refs() always implies a barrier'; then
    echo "Kernel is OK (futex TSB-63)"
  else
    echo "Kernel is VULNERABLE (futex TSB-63)"
  fi
fi
# TODO: TSB-189

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
echo "--"
if grep -q swap /etc/fstab; then
  BDEVICE=""
  SWAPLINES=$(awk '$3~/swap/{print $1}' /etc/fstab)
  # what if fstab has more than one swap entry?
  for SWAPLINE in $SWAPLINES; do
    # what if fstab is ^UUID= ?
    if echo "$SWAPLINE" | grep -q ^UUID=; then
      UUID=$(echo "$SWAPLINE" | awk -F= '{print $2}')
      BDEVICE="$(lsblk -lo KNAME,UUID | awk "/$UUID/"'{print "/dev/"$1}') $BDEVICE"
    else
      BDEVICE="$SWAPLINE $BDEVICE"
    fi
  done
  lsblk -lo NAME,SIZE,TYPE,MOUNTPOINT "$BDEVICE"
fi
echo "** startup config:"
grep swap /etc/fstab || echo "none"

echo "****************************************"
echo "*** Firewall"
echo "** running config:"
IPT=$(sudo -n iptables -nL)
RETVAL=$?
IPTCOUNT=$(echo "$IPT" | grep -cvE '^Chain|^target|^$')
if [ "$RETVAL" -ne 0 ]; then
  echo "There are UNKOWN active iptables rules."
else
  echo "There are $IPTCOUNT active iptables rules."
fi
IP6T=$(sudo -n ip6tables -nL)
IP6TCOUNT=$(echo "$IP6T" | grep -cvE '^Chain|^target|^$')
if [ "$RETVAL" -ne 0 ]; then
  echo "There are UNKOWN active ip6tables rules."
else
  echo "There are $IP6TCOUNT active ip6tables rules."
fi
echo "** startup config:"
# There are multiple other ways for the firewall to be started (ie Shorewall).
# We will not be probing for them.
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ]; then
  if [ "$OSREL" == "7" ]; then
    systemctl --lines 0 status firewalld.service
  fi
  if [ "$OSREL" == "6" ]; then
    chkconfig --list iptables
    chkconfig --list ip6tables
  fi
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  service ufw status
  if [ "$OSVER" == "14.04" ]; then
    initctl show-config ufw
  fi
elif [ "$OS" == "SUSE LINUX" ]; then
  chkconfig --list SuSEfirewall2_init
  chkconfig --list SuSEfirewall2_setup
fi

echo "****************************************"
echo "*** IPv6"
echo "** running config:"
sysctl net.ipv6.conf.all.disable_ipv6
sysctl net.ipv6.conf.default.disable_ipv6
echo "** startup config:"
grep -r net.ipv6.conf.all.disable_ipv6 /etc/sysctl.*
grep -r net.ipv6.conf.default.disable_ipv6 /etc/sysctl.*

echo "****************************************"
echo "*** SElinux"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ]; then
  echo "** running config:"
  getenforce
  echo "** startup config:"
  grep ^SELINUX= /etc/selinux/config
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  echo "Debian/Ubuntu = None"
elif [ "$OS" == "SUSE LINUX" ]; then
  echo "SLES = None"
fi

echo "****************************************"
echo "*** Transparent Huge Pages defrag"
echo "** running config:"
echo "* defrag:"
cat /sys/kernel/mm/transparent_hugepage/defrag
echo "* enabled:"
cat /sys/kernel/mm/transparent_hugepage/enabled
echo "** startup config:"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ]; then
  grep transparent_hugepage /etc/rc.d/rc.local
elif [ "$OS" == "SUSE LINUX" ]; then
  grep transparent_hugepage /etc/init.d/after.local
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
#tune2fs -l /dev/sda | grep blah

echo "****************************************"
echo "*** Entropy"
echo "** running config:"
if [ "$OS" == CentOS ] || [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == OracleServer ]; then
  service rngd status
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  service rng-tools status || ps -o user,pid,command -C rngd
elif [ "$OS" == "SUSE LINUX" ]; then
  service rng-tools status
fi
echo "** startup config:"
if [ "$OS" == "SUSE LINUX" ]; then
  chkconfig --list rng-tools
else
  chkconfig --list rngd
fi
echo "** available entropy:"
cat /proc/sys/kernel/random/entropy_avail

echo "****************************************"
echo "*** Java"
echo "** installed Java(s):"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ] || [ "$OS" == "SUSE LINUX" ]; then
  rpm -qa | grep -E 'jdk|jre|^java-|j2sdk' | sort
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  dpkg -l \*jdk\* \*jre\* java-\* \*j2sdk\* oracle-java\* | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi
# Which is our standard?
echo "** which java:"
command -v java
echo "** default java version:"
# https://stackoverflow.com/questions/7334754/correct-way-to-check-java-version-from-bash-script
if type -p java >/dev/null; then
  #echo "Java executable found in PATH."
  _JAVA=java
elif [ -n "$JAVA_HOME" ] && [ -x "${JAVA_HOME}/bin/java" ]; then
  #echo "Java executable found in JAVA_HOME."
  _JAVA="${JAVA_HOME}/bin/java"
else
  echo "Java not found."
fi
if [ -n "$_JAVA" ]; then
  #java -version 2>&1 || ${JAVA_HOME}/java -version 2>&1
  "$_JAVA" -version 2>&1
  _JAVA_VERSION=$("$_JAVA" -version 2>&1 | awk -F '"' '/version/ {print $2}')
  _JAVA_VERSION_MAJ=$(echo "${_JAVA_VERSION}" | awk -F. '{print $1}')
  _JAVA_VERSION_MIN=$(echo "${_JAVA_VERSION}" | awk -F. '{print $2}')
  #_JAVA_VERSION_PATCH=$(echo "${_JAVA_VERSION}" | awk -F. '{print $3}' | sed -e 's|_.*||')
  _JAVA_VERSION_RELEASE=$(echo "${_JAVA_VERSION}" | awk -F_ '{print $2}')
else
  _JAVA_VERSION_MAJ=0
  _JAVA_VERSION_MIN=0
  #_JAVA_VERSION_PATCH=0
  _JAVA_VERSION_RELEASE=0
fi

echo "****************************************"
echo "*** JAVA_HOME"
echo "JAVA_HOME=$JAVA_HOME"
echo "PATH=$PATH"

echo "****************************************"
echo "*** JCE"
if command -v unzip; then
  UNZIP=true
else
  UNZIP=false
fi
_JCE_FOUND=false
for _DIR in /usr/java/default/jre/lib/security \
            /usr/java/jdk1.6.0_31/jre/lib/security \
            /usr/java/jdk1.7.0_67-cloudera/jre/lib/security \
            /usr/java/jdk1.8.0_*/jre/lib/security \
            /usr/lib/jvm/java-7-openjdk-amd64/jre/lib/security \
            /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/security \
            /usr/lib/jvm/default-java/jre/lib/security \
            /usr/lib/jvm/java-7-oracle/jre/lib/security \
            /usr/lib/jvm/java-8-oracle/jre/lib/security; do
  if [ -f "${_DIR}/local_policy.jar" ]; then
    _JCE_FOUND=true
    if [ "$UNZIP" == true ]; then
      # http://harshj.com/checking-if-your-jre-has-the-unlimited-strength-policy-files-in-place/
      unzip -c "${_DIR}"/local_policy.jar default_local.policy | grep -q javax.crypto.CryptoAllPermission && echo -n "unlimited         " || echo -n "vanilla           "
      echo " JCE in $_DIR"
    else
      #ls -l "${_DIR}"/*.jar
      sha1sum "${_DIR}"/*.jar
    fi
  elif [ "${_JAVA_VERSION_MAJ}" -eq 1 ] && [ "${_JAVA_VERSION_MIN}" -eq 8 ] && [ "${_JAVA_VERSION_RELEASE}" -ge 151 ]; then
  # https://www.cloudera.com/documentation/enterprise/release-notes/topics/rn_consolidated_pcm.html#jce
  # Enabling Unlimited Strength Encryption for JDK 1.8.0_151 (and later)
  #
  # As of JDK 1.8.0_151, unlimited strength encryption can be enabled using the
  # java.security file as documented in the JDK 1.8.0_151 release notes. You do
  # not need to install the JCE policy files.
  #
  # As of JDK 1.8.0_161, unlimited strength encryption has been enabled by
  # default. No further action is required.
    _JCE_FOUND=true
    if [ -f "${_DIR}"/java.security ]; then
      if grep -q ^crypto.policy=unlimited "${_DIR}"/java.security; then
        echo "unlimited built-in JCE in $_DIR"
      elif grep -q ^crypto.policy=limited "${_DIR}"/java.security; then
        echo "vanilla   built-in JCE in $_DIR"
      else
        if [ "${_JAVA_VERSION_RELEASE}" -ge 161 ]; then
          echo "unlimited built-in JCE in $_DIR"
        elif [ "${_JAVA_VERSION_RELEASE}" -ge 151 ]; then
          echo "vanilla   built-in JCE in $_DIR"
        fi
      fi
    fi
  fi
done
if [ "$_JCE_FOUND" == "false" ]; then
  echo "JCE not found."
fi

echo "****************************************"
echo "*** JDBC"
echo "** JDBC packages:"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ] || [ "$OS" == "SUSE LINUX" ]; then
  rpm -q mysql-connector-java postgresql-jdbc
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  dpkg -l libmysql-java libpostgresql-jdbc-java | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi
echo "** JDBC files:"
ls -l /usr/share/java/mysql-connector-java.jar
ls -l /usr/share/java/oracle-connector-java.jar /usr/share/java/ojdbc?.jar
ls -l /usr/share/java/sqlserver-connector-java.jar /usr/share/java/sqljdbc*.jar

echo "****************************************"
echo "*** Kerberos"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ]; then
  rpm -q krb5-workstation kstart k5start
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  dpkg -l krb5-user kstart k5start | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
elif [ "$OS" == "SUSE LINUX" ]; then
  rpm -q krb5-client kstart k5start
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
if [ "$OS" == CentOS ] || [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == OracleServer ]; then
  service ntpd status
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ] || [ "$OS" == "SUSE LINUX" ]; then
  service ntp status
fi
echo "** startup config:"
RETVAL=0
if [ "$OS" == Debian ] || [ "$OS" == Ubuntu ] || [ "$OS" == "SUSE LINUX" ]; then
  chkconfig --list ntp
else
  chkconfig --list ntpd
fi
if { [ "$OS" == CentOS ] || [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == OracleServer ]; } && [ "$OSREL" == 7 ]; then
  systemctl --lines 0 status chronyd.service
  RETVAL=$?
  # Do we want to support chrony? Does CM?
fi
echo "** timesync status:"
ntpq -p
if { [ "$OS" == CentOS ] || [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == OracleServer ]; } && { [ "$OSREL" == 7 ] && [ "$RETVAL" == 0 ]; }; then
  chronyc sources
fi

echo "****************************************"
echo "*** Tuned Profile"
tuned-adm active

echo "****************************************"
echo "*** Timezone"
date +'%Z %z'

echo "****************************************"
echo "*** DNS"
IP=$(ip -4 a | awk '/inet/{print $2}' | grep -Ev '127.0.0.1|169.254.' | sed -e 's|/[0-9].*||')
echo "** system IP is: $IP"
echo "** system hostname is: $(hostname)"
if command -v dig >/dev/null 2>&1; then
#  IP=$(dig "$(hostname)" +short)
  HOST=$(dig -x "$IP" +short)
  ADDR=$(dig "$HOST" +short)
else
#  IP=$(python -c "import socket; print socket.gethostbyname('$(hostname)')")
  HOST=$(python -c 'import socket; print socket.getfqdn()')
  ADDR=$(python -c 'import socket; print socket.gethostbyname(socket.getfqdn())')
fi
# How do you know if the proper DNS tools were used (dig) vs the Python method
# (which I am told does things a little differently)?
# DNS tools provide the trailing dot on the forward result...
echo "** DNS forward is: $HOST"
echo "** DNS reverse is: $ADDR"
if [ "$IP" == "$ADDR" ]; then
  echo "DNS does match."
else
  echo "DNS does not match."
fi
echo "** /etc/hosts:"
HOSTCOUNT=$(grep -cvE 'localhost|^127.0.0.1|^::1|^#|^[[:space:]]*#|^$' /etc/hosts)
echo "There are $HOSTCOUNT non-loopback entries in /etc/hosts."
echo "** /etc/nsswitch.conf hosts entry:"
grep ^hosts /etc/nsswitch.conf
echo "** /etc/resolv.conf:"
awk 1 /etc/resolv.conf

echo "****************************************"
echo "*** Cloudera Software"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ] || [ "$OS" == "SUSE LINUX" ]; then
  rpm -qa ^cloudera\* ^navencrypt\* \*keytrustee\*
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  dpkg -l \*cloudera\* \*navencrypt\* \*keytrustee\* | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi
echo "*** Cloudera Hadoop Packages"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ] || [ "$OS" == "SUSE LINUX" ]; then
  rpm -qa ^hadoop\*
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  dpkg -l hadoop | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi
echo "*** Cloudera Parcels"
ls -l /opt/cloudera/parcels

echo "****************************************"
echo "*** Hortonworks Software"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ] || [ "$OS" == "SUSE LINUX" ]; then
  rpm -qa ^ambari\*
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  dpkg -l \*ambari\* | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi
echo "*** Hortonworks Hadoop Packages"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == OracleServer ] || [ "$OS" == "SUSE LINUX" ]; then
  rpm -qa ^hadoop\*
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  dpkg -l hadoop-?-?-?-?-???? | awk '$1~/^ii$/{print $2"\t"$3"\t"$4}'
fi

echo "****************************************"
echo "*** Native Code"
hadoop checknative

echo "****************************************"
echo "*** Internet Access"
# https://unix.stackexchange.com/questions/190513/shell-scripting-proper-way-to-check-for-internet-connectivity
if command -v curl; then
  INET=$(curl -s --max-time 10 -I http://archive.cloudera.com/cm5/ | sed 's/^[^ ]*  *\([0-9]\).*/\1/; 1q')
elif command -v wget; then
  INET=$(wget -q --timeout=10 --server-response http://archive.cloudera.com/cm5/ 2>&1 | sed 's/^  //' | sed 's/^[^ ]*  *\([0-9]\).*/\1/; 1q')
fi
case "$INET" in
  [23]) echo "HTTP connectivity is up";;
  5) echo "The web proxy won't let us through";;
  *) echo "The network is down or very slow";;
esac

if [ "$OS" == RedHatEnterpriseServer ]; then
  echo "****************************************"
  echo "*** RedHat Subscription"
  sudo -n /sbin/subscription-manager version
fi

#echo "****************************************"
#echo "*** "
#echo "** running config:"
#echo "** startup config:"

exit 0

