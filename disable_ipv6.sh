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

exit 1

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

if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  # https://access.redhat.com/solutions/8709
  # https://wiki.centos.org/FAQ/CentOS7#head-8984faf811faccca74c7bcdd74de7467f2fcd8ee
  sysctl -w net.ipv6.conf.all.disable_ipv6=1
  sysctl -w net.ipv6.conf.default.disable_ipv6=1

  if [ "$OSREL" == 6 ]; then
    if grep -q net.ipv6.conf.all.disable_ipv6 /etc/sysctl.conf; then
      sed -i -e "/^net.ipv6.conf.all.disable_ipv6/s|=.*|= 1|" /etc/sysctl.conf
    else
      echo "net.ipv6.conf.all.disable_ipv6 = 1" >>/etc/sysctl.conf
    fi
    if grep -q net.ipv6.conf.default.disable_ipv6 /etc/sysctl.conf; then
      sed -i -e "/^net.ipv6.conf.default.disable_ipv6/s|=.*|= 1|" /etc/sysctl.conf
    else
      echo "net.ipv6.conf.default.disable_ipv6 = 1" >>/etc/sysctl.conf
    fi
  else
    if grep -q net.ipv6.conf.all.disable_ipv6 /etc/sysctl.conf; then
      sed -i -e '/^net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
    fi
    if grep -q net.ipv6.conf.default.disable_ipv6 /etc/sysctl.conf; then
      sed -i -e '/^net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
    fi
    echo "# Tuning for Hadoop installation." >/etc/sysctl.d/cloudera-ipv6.conf
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >>/etc/sysctl.d/cloudera-ipv6.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >>/etc/sysctl.d/cloudera-ipv6.conf
  fi

#mja needs work
  #sed -e '/^AddressFamily/s|^AddressFamily .*|AddressFamily inet|' \
  #    -e '/^#AddressFamily/a\
  #AddressFamily inet' \
  #    -e '/^ListenAddress/s|^ListenAddress.*|ListenAddress 0.0.0.0|' \
  #    -e '/^#ListenAddress/a\
  #ListenAddress 0.0.0.0' \
  #    -i /etc/ssh/sshd_config
  sed -e '/# CLAIRVOYANT$/d' \
      -e '/^AddressFamily /d' \
      -e '/^ListenAddress /d' \
      -i /etc/ssh/sshd_config
  echo <<EOF >>/etc/ssh/sshd_config
# Hadoop: Disable IPv6 support # CLAIRVOYANT
AddressFamily inet             # CLAIRVOYANT
ListenAddress 0.0.0.0          # CLAIRVOYANT
# Hadoop: Disable IPv6 support # CLAIRVOYANT
EOF

#mja needs work
  if rpm -q postfix; then
    postconf inet_interfaces
    postconf -e inet_interfaces=127.0.0.1
  fi

#mja needs work
  if [ -f /etc/netconfig ]; then
    sed -e '/inet6/d' -i /etc/netconfig
  fi

  service ip6tables stop
  chkconfig ip6tables off
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  # https://askubuntu.com/questions/440649/how-to-disable-ipv6-in-ubuntu-14-04
  echo "# Tuning for Hadoop installation." >/etc/sysctl.d/cloudera-ipv6.conf
  echo "net.ipv6.conf.all.disable_ipv6 = 1" >/etc/sysctl.d/cloudera-ipv6.conf
  echo "net.ipv6.conf.default.disable_ipv6 = 1" >/etc/sysctl.d/cloudera-ipv6.conf
  echo "net.ipv6.conf.lo.disable_ipv6 = 1" >/etc/sysctl.d/cloudera-ipv6.conf
  sysctl -p
#mja needs work
fi

