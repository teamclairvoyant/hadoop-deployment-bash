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

yum -y -d1 -e1 install haproxy

cat <<EOF >/etc/haproxy/haproxy.cfg
# CLAIRVOYANT
global
    log 127.0.0.1 local2
    chroot /var/lib/haproxy
    pidfile /var/run/haproxy.pid
    maxconn 4000
    user haproxy
    group haproxy
    daemon
    # turn on stats unix socket
    #stats socket /var/lib/haproxy/stats

defaults
    mode tcp
    log global
    option tcplog
    option tcpka
    retries 3
    timeout connect 5s
    timeout client 1h
    timeout server 1h

# Setup for beeswax (impala-shell) or original ODBC driver.
# For JDBC or ODBC version 2.x driver, use port 21050 instead of 21000.
listen impala
    bind 0.0.0.0:21000
    balance leastconn

    server impala0 ip-10-30-1-4.ec2.internal:21000 check
    server impala1 ip-10-30-1-10.ec2.internal:21000 check
    server impala2 ip-10-30-1-33.ec2.internal:21000 check
    server impala3 ip-10-30-1-35.ec2.internal:21000 check
    server impala4 ip-10-30-1-46.ec2.internal:21000 check

# Setup for Hue or other JDBC-enabled applications.
# In particular, Hue requires sticky sessions.
listen impalajdbc
    bind 0.0.0.0:21050
    balance source

    server impala5 ip-10-30-1-4.ec2.internal:21050 check
    server impala6 ip-10-30-1-10.ec2.internal:21050 check
    server impala7 ip-10-30-1-33.ec2.internal:21050 check
    server impala8 ip-10-30-1-35.ec2.internal:21050 check
    server impala9 ip-10-30-1-46.ec2.internal:21050 check
EOF

cat <<EOF >/etc/rsyslog.d/remoteudp.conf
# CLAIRVOYANT
# Provides UDP syslog reception
\$ModLoad imudp
\$UDPServerRun 514

local2.* /var/log/haproxy.log
EOF
touch /var/log/haproxy.log
service rsyslog condrestart

service haproxy start
chkconfig haproxy on

