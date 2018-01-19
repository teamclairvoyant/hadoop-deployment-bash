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
# Only available on EL.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Installing tuned..."
yum -y -e1 -d1 install tuned

mkdir -m 0755 /etc/tuned/hadoop
cat <<EOF >/etc/tuned/hadoop/tuned.conf
#
# tuned configuration
#

[cpu]
governor=performance
energy_perf_bias=performance
min_perf_pct=100

[vm]
transparent_hugepages=never

[disk]
readahead=>4096

[sysctl]
# ktune sysctl settings for rhel6 servers, maximizing i/o throughput
#
# Minimal preemption granularity for CPU-bound tasks:
# (default: 1 msec#  (1 + ilog(ncpus)), units: nanoseconds)
kernel.sched_min_granularity_ns = 10000000

# SCHED_OTHER wake-up granularity.
# (default: 1 msec#  (1 + ilog(ncpus)), units: nanoseconds)
#
# This option delays the preemption effects of decoupled workloads
# and reduces their over-scheduling. Synchronous workloads will still
# have immediate wakeup/sleep latencies.
kernel.sched_wakeup_granularity_ns = 15000000

# If a workload mostly uses anonymous memory and it hits this limit, the entire
# working set is buffered for I/O, and any more write buffering would require
# swapping, so it's time to throttle writes until I/O can catch up.  Workloads
# that mostly use file mappings may be able to use even higher values.
#
# The generator of dirty data starts writeback at this percentage (system default
# is 20%)
vm.dirty_ratio = 40

# Start background writeback (via writeback threads) at this percentage (system
# default is 10%)
vm.dirty_background_ratio = 10

# PID allocation wrap value.  When the kernel's next PID value
# reaches this value, it wraps back to a minimum PID value.
# PIDs of value pid_max or larger are not allocated.
#
# A suggested value for pid_max is 1024 * <# of cpu cores/threads in system>
# e.g., a box with 32 cpus, the default of 32768 is reasonable, for 64 cpus,
# 65536, for 4096 cpus, 4194304 (which is the upper limit possible).
#kernel.pid_max = 65536

# The swappiness parameter controls the tendency of the kernel to move
# processes out of physical memory and onto the swap disk.
# 0 tells the kernel to avoid swapping processes out of physical memory
# for as long as possible
# 100 tells the kernel to aggressively swap processes out of physical memory
# and move them to swap cache
vm.swappiness=1

#net.core.busy_read=50
#net.core.busy_poll=50
#net.ipv4.tcp_fastopen=3
#kernel.numa_balancing=0

# Increase kernel buffer size maximums.  Currently this seems only necessary at
# 40Gb speeds.
#
# The buffer tuning values below do not account for any potential hugepage
# allocation.  Ensure that you do not oversubscribe system memory.
#net.ipv4.tcp_rmem="4096 87380 16777216"
#net.ipv4.tcp_wmem="4096 16384 16777216"
#net.ipv4.udp_mem="3145728 4194304 16777216"

# Cloudera Professional Services recommendations:
# https://access.redhat.com/sites/default/files/attachments/20150325_network_performance_tuning.pdf
net.core.netdev_max_backlog = 250000
net.core.optmem_max = 4194304
net.core.rmem_default = 4194304
net.core.rmem_max = 4194304
net.core.wmem_default = 4194304
net.core.wmem_max = 4194304
# https://docs.aws.amazon.com/AmazonS3/latest/dev/TCPWindowScaling.html
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_low_latency = 1
# https://docs.aws.amazon.com/AmazonS3/latest/dev/TCPSelectiveAcknowledgement.html
net.ipv4.tcp_sack = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_wmem = 4096 65536 4194304

EOF
chown root:root /etc/tuned/hadoop/tuned.conf
chmod 0644 /etc/tuned/hadoop/tuned.conf

mkdir -m 0755 /etc/tuned/hadoop-virtual
cat <<EOF >/etc/tuned/hadoop-virtual/tuned.conf
#
# tuned configuration
#

[main]
include=hadoop

[sysctl]
# If a workload mostly uses anonymous memory and it hits this limit, the entire
# working set is buffered for I/O, and any more write buffering would require
# swapping, so it's time to throttle writes until I/O can catch up.  Workloads
# that mostly use file mappings may be able to use even higher values.
#
# The generator of dirty data starts writeback at this percentage (system default
# is 20%)
vm.dirty_ratio = 30

EOF
chown root:root /etc/tuned/hadoop-virtual/tuned.conf
chmod 0644 /etc/tuned/hadoop-virtual/tuned.conf

if virt-what | grep -q '.*'; then
  tuned-adm profile hadoop-virtual
else
  tuned-adm profile hadoop
fi

