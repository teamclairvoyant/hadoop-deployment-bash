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

if rpm -q redhat-lsb-core; then
  OSREL=`lsb_release -rs | awk -F. '{print $1}'`
else
  OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
fi

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

#sed -e '/^AddressFamily/s|^AddressFamily .*|AddressFamily inet|' \
#    -e '/^#AddressFamily/a\
#AddressFamily inet' \
#    -e '/^ListenAddress/s|^ListenAddress.*|ListenAddress 0.0.0.0|' \
#    -e '/^#ListenAddress/a\
#ListenAddress 0.0.0.0' \
#    -i /etc/ssh/sshd_config
sed -e '/^AddressFamily /d' \
    -e '/^ListenAddress /d' \
    -i /etc/ssh/sshd_config
echo <<EOF >>/etc/ssh/sshd_config
# Hadoop: Disable IPv6 support
AddressFamily inet
ListenAddress 0.0.0.0
# Hadoop: Disable IPv6 support
EOF

if rpm -q postfix; then
  postconf inet_interfaces
  postconf -e inet_interfaces=127.0.0.1
fi

if [ -f /etc/netconfig ]; then
  sed -e '/inet6/d' -i /etc/netconfig
fi

