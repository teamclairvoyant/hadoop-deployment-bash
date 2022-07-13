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
# Copyright Clairvoyant 2017

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

# https://access.redhat.com/sites/default/files/attachments/20150325_network_performance_tuning.pdf
# https://docs.aws.amazon.com/AmazonS3/latest/dev/TCPWindowScaling.html
# https://docs.aws.amazon.com/AmazonS3/latest/dev/TCPSelectiveAcknowledgement.html
# http://www.cloudera.com/documentation/other/reference-architecture/PDF/cloudera_ref_arch_metal.pdf

# Cloudera Professional Services recommendations:
DATA="net.core.netdev_max_backlog = 250000
net.core.optmem_max = 4194304
net.core.rmem_default = 4194304
net.core.rmem_max = 4194304
net.core.wmem_default = 4194304
net.core.wmem_max = 4194304
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_wmem = 4096 65536 4194304"

# Disable TCP timestamps to improve CPU utilization (this is an optional parameter and will depend on your NIC vendor):
#   net.ipv4.tcp_timestamps=0
# Enable TCP sacks to improve throughput:
#   net.ipv4.tcp_sack=1
# Increase the maximum length of processor input queues:
#   net.core.netdev_max_backlog=250000
# Increase the TCP max and default buffer sizes using setsockopt():
#   net.core.rmem_max=4194304
#   net.core.wmem_max=4194304
#   net.core.rmem_default=4194304
#   net.core.wmem_default=4194304
#   net.core.optmem_max=4194304
# Increase memory thresholds to prevent packet dropping:
#   net.ipv4.tcp_rmem="4096 87380 4194304"
#   net.ipv4.tcp_wmem="4096 65536 4194304"
# Enable low latency mode for TCP:
#   net.ipv4.tcp_low_latency=1
# Set the socket buffer to be divided evenly between TCP window size and application buffer:
#   net.ipv4.tcp_adv_win_scale=1

# Page allocation errors are likely happening due to higher network load where
# kernel cannot allocate a contiguous chunk of memory for a network interrupt.
# This happens on 10GbE interfaces of various manufacturers.
#   vm.min_free_kbytes = 1048576

# Function to discover basic OS details.
discover_os() {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu, RedHatEnterpriseServer, Debian, SUSE LINUX
    # shellcheck disable=SC2034
    OS=$(lsb_release -is)
    # CentOS= 6.10, 7.2.1511, Ubuntu= 14.04, RHEL= 6.10, 7.5, SLES= 11
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

_sysctld() {
  FILE=/etc/sysctl.d/cloudera-network.conf

  install -m 0644 -o root -g root /dev/null "$FILE"
  cat <<EOF >"${FILE}"
# Tuning for Hadoop installation. CLAIRVOYANT
# Based on Cloudera Professional Services recommendations.
$DATA
EOF
}

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Tuning Kernel parameters..."
FILE=/etc/sysctl.conf

if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  if [ ! -d /etc/sysctl.d ]; then
    for PARAM in $(echo "$DATA" | awk '{print $1}'); do
      VAL=$(echo "$DATA" | awk -F= "/^${PARAM} = /{print \$2}" | sed -e 's|^ ||')
      if grep -q "$PARAM" "$FILE"; then
        sed -i -e "/^${PARAM}/s|=.*|= $VAL|" "$FILE"
      else
        echo "${PARAM} = ${VAL}" >>"${FILE}"
      fi
    done
  else
    for PARAM in $(echo "$DATA" | awk '{print $1}'); do
      if grep -q "$PARAM" "$FILE"; then
        sed -i -e "/^${PARAM}/d" "$FILE"
      fi
    done
    _sysctld
  fi
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  for PARAM in $(echo "$DATA" | awk '{print $1}'); do
    if grep -q "$PARAM" "$FILE"; then
      sed -i -e "/^${PARAM}/d" "$FILE"
    fi
  done
  _sysctld
fi

echo "** Applying Kernel parameters."
sysctl -p "$FILE"

