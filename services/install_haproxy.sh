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

exit 1

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
echo "Installing HAproxy..."
yum -y -d1 -e1 install haproxy

chown root:root /etc/haproxy/haproxy.cfg
chmod 0644 /etc/haproxy/haproxy.cfg
cat <<EOF >/etc/haproxy/haproxy.cfg
# CLAIRVOYANT
# http://gethue.com/hadoop-tutorial-how-to-distribute-impala-query-load/
# https://www.cloudera.com/documentation/enterprise/5-8-x/topics/impala_proxy.html
# https://www.cloudera.com/documentation/enterprise/latest/topics/hue_sec_ha.html
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
    timeout client 50000ms
    timeout server 50000ms

## Setup for Oozie.
#frontend oozie
#    bind 0.0.0.0:11000 # http
##   bind 0.0.0.0:11443 # https
#    mode http
#    default_backend oozie_servers
#    option httplog
#
#backend oozie_servers
#    mode http
#    option httplog
#    balance roundrobin
#    server oozie1 OOZIEHOST1:11000 check
#    server oozie2 OOZIEHOST2:11000 check

## Setup for HttpFS.
#frontend httpfs
#    bind 0.0.0.0:14000
#    mode http
#    default_backend httpfs_servers
#    option httplog
#
#backend httpfs_servers
#    mode http
#    option httplog
#    balance roundrobin
#    server httpfs0 HTTPFSHOST1:14000 check
#    server httpfs1 HTTPFSHOST2:14000 check

## Setup for Hue.
#frontend hue
#    bind 0.0.0.0:8889
#    mode http
#    option http-server-close
#    timeout client 120s
#    option forwardfor
#    default_backend hue_servers
#    timeout http-request 5s
#
#backend hue_servers
#    mode http
#    option http-server-close
#    timeout server 120s
#    option forwardfor
#    option httpchk HEAD /desktop/debug/is_alive
#    http-check expect status 200
#    balance source
#    server hue1 HUEHOST1:8888 cookie ServerA check inter 2s fall 3
#    server hue2 HUEHOST2:8888 cookie ServerB check inter 2s fall 3

## Setup for Solr.
#frontend solr
#    bind 0.0.0.0:8983 # http
##   bind 0.0.0.0:8985 # https
#    mode http
#    default_backend solr_servers
#    option httplog
#
#backend solr_servers
#    mode http
#    option httplog
#    balance roundrobin
#    server solr0 SOLRHOST1:8983 check
#    server solr1 SOLRHOST2:8983 check
#    server solr2 SOLRHOST2:8983 check
#    server solr3 SOLRHOST2:8983 check
#    server solr4 SOLRHOST2:8983 check

### Setup for Solr Server.
##listen solr
##    bind 0.0.0.0:8983
##    timeout client 1h
##    timeout server 1h
##    balance leastconn
##    server solr0 SOLRHOST1:8983 check
##    server solr1 SOLRHOST2:8983 check
##    server solr2 SOLRHOST3:8983 check
##    server solr3 SOLRHOST4:8983 check
##    server solr4 SOLRHOST5:8983 check

## Setup for HiveServer2.
#listen hiveserver2
#    bind 0.0.0.0:10000
#    timeout client 1h
#    timeout server 1h
#    balance leastconn
#    server hiveserver20 HIVESERVER2HOST1:10000 check
#    server hiveserver21 HIVESERVER2HOST2:10000 check

## Setup for Hive Metastore Server.
#listen hivemetastore
#    bind 0.0.0.0:9083
#    timeout client 1h
#    timeout server 1h
#    balance leastconn
#    server hivemetastore0 HIVEMETASTOREHOST1:9083 check
#    server hivemetastore1 HIVEMETASTOREHOST2:9083 check

# Setup for beeswax (impala-shell) or original ODBC driver.
# For JDBC or ODBC version 2.x driver, use port 21050 instead of 21000.
listen impala-shell
    bind 0.0.0.0:21000
    timeout client 1h
    timeout server 1h
    balance leastconn
    server impala0 IMPALAHOST1:21000 check
    server impala1 IMPALAHOST2:21000 check
    server impala2 IMPALAHOST3:21000 check
    server impala3 IMPALAHOST4:21000 check
    server impala4 IMPALAHOST5:21000 check

# Setup for Hue or other JDBC-enabled applications.
# In particular, Hue requires sticky sessions.
listen impala-jdbc
    bind 0.0.0.0:21050
    timeout client 1h
    timeout server 1h
    balance source
    server impala5 IMPALAHOST1:21050 check
    server impala6 IMPALAHOST2:21050 check
    server impala7 IMPALAHOST3:21050 check
    server impala8 IMPALAHOST4:21050 check
    server impala9 IMPALAHOST5:21050 check

# This sets up the admin page for HA Proxy at port 1936.
listen stats :1936
    mode http
    stats enable
    stats uri /
    stats hide-version
    stats refresh 30s

EOF

cat <<EOF >/etc/rsyslog.d/remoteudp.conf
# CLAIRVOYANT
# Provides UDP syslog reception
\$ModLoad imudp
\$UDPServerRun 514

local2.* /var/log/haproxy.log
EOF
chown root:root /etc/rsyslog.d/remoteudp.conf
chmod 0644 /etc/rsyslog.d/remoteudp.conf

touch /var/log/haproxy.log
chown root:root /var/log/haproxy.log
chmod 0600 /var/log/haproxy.log
service rsyslog condrestart

service haproxy start
chkconfig haproxy on

echo "Set Hue server_conn_timeout = 1 hour to match the HAproxy timeout."

