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

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
DATE=$(date '+%Y%m%d%H%M%S')
echo "Installing HAproxy..."
yum -y -d1 -e1 install haproxy

if [ ! -f /etc/haproxy/haproxy.cfg-orig ]; then
  cp -p /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg-orig
else
  cp -p /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg."${DATE}"
fi
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
    timeout client 50s
    timeout server 50s

## Setup for Oozie.
#frontend oozie
#    mode http
#    option httplog
#    bind 0.0.0.0:11000
#    default_backend oozie_servers
#
#backend oozie_servers
#    mode http
#    option httplog
#    balance roundrobin
#    server oozie-OOZIEHOST1 OOZIEHOST1.DOMAIN:11000 check
#    server oozie-OOZIEHOST2 OOZIEHOST2.DOMAIN:11000 check

## Setup for Oozie TLS.
## Non-TLS Oozie configuration is also required.
#listen oozieTLS
#    bind 0.0.0.0:11443
#    balance roundrobin
#    server oozieT-OOZIEHOST1 OOZIEHOST1.DOMAIN:11443 check
#    server oozieT-OOZIEHOST2 OOZIEHOST2.DOMAIN:11443 check

## Setup for HttpFS.
#frontend httpfs
#    mode http
#    option httplog
#    bind 0.0.0.0:14000
#    default_backend httpfs_servers
#
#backend httpfs_servers
#    mode http
#    option httplog
#    balance roundrobin
#    server httpfs-HTTPFSHOST1 HTTPFSHOST1.DOMAIN:14000 check
#    server httpfs-HTTPFSHOST2 HTTPFSHOST2.DOMAIN:14000 check

## Setup for HttpFS TLS.
#listen httpfs
#    bind 0.0.0.0:14000
#    balance roundrobin
#    server httpfs-HTTPFSHOST1 HTTPFSHOST1.DOMAIN:14000 check
#    server httpfs-HTTPFSHOST2 HTTPFSHOST2.DOMAIN:14000 check

## Setup for Hue.
#frontend hue
#    mode http
#    option httplog
#    bind 0.0.0.0:8889
#    option http-server-close
#    timeout client 120s
#    option forwardfor    # X-Forwarded-For
#    default_backend hue_servers
#    timeout http-request 5s
#
#backend hue_servers
#    mode http
#    option httplog
#    option http-server-close
#    timeout server 120s
#    option forwardfor    # X-Forwarded-For
#    option httpchk HEAD /desktop/debug/is_alive
#    http-check expect status 200
#    balance source
#    server hue-HUEHOST1 HUEHOST1.DOMAIN:8889 cookie ServerA check
#    server hue-HUEHOST2 HUEHOST2.DOMAIN:8889 cookie ServerB check

## Setup for Hue TLS.
#listen hue
#    bind 0.0.0.0:8889
#    timeout client 120s
#    timeout server 120s
#    balance source
#    server hue-HUEHOST1 HUEHOST1.DOMAIN:8889 check
#    server hue-HUEHOST2 HUEHOST2.DOMAIN:8889 check

## Setup for Solr.
#frontend solr
#    mode http
#    option httplog
#    bind 0.0.0.0:8983
#    default_backend solr_servers
#
#backend solr_servers
#    mode http
#    option httplog
##    option httpchk GET /solr/<core-name>/admin/ping\ HTTP/1.0
##    http-check expect status 200
#    balance roundrobin
#    server solr-SOLRHOST1 SOLRHOST1.DOMAIN:8983 check
#    server solr-SOLRHOST2 SOLRHOST2.DOMAIN:8983 check
#    server solr-SOLRHOST3 SOLRHOST3.DOMAIN:8983 check
#    server solr-SOLRHOST4 SOLRHOST4.DOMAIN:8983 check
#    server solr-SOLRHOST5 SOLRHOST5.DOMAIN:8983 check

## Setup for Solr TLS.
#listen solr
#    bind 0.0.0.0:8985
#    balance roundrobin
#    server solr-SOLRHOST1 SOLRHOST1.DOMAIN:8985 check
#    server solr-SOLRHOST2 SOLRHOST2.DOMAIN:8985 check
#    server solr-SOLRHOST3 SOLRHOST3.DOMAIN:8985 check
#    server solr-SOLRHOST4 SOLRHOST4.DOMAIN:8985 check
#    server solr-SOLRHOST5 SOLRHOST5.DOMAIN:8985 check

## Setup for HiveServer2 JDBC connection.
#listen hiveserver2-jdbc
#    bind 0.0.0.0:10000
#    timeout client 1h
#    timeout server 1h
#    balance leastconn
#    server hs2J-HIVESERVER2HOST1 HIVESERVER2HOST1:10000 check
#    server hs2J-HIVESERVER2HOST2 HIVESERVER2HOST2:10000 check

## Setup for HiveServer2 Hue JDBC connection.
## Set Hue "server_conn_timeout = 1 hour" to match the HAproxy timeout.
#listen hiveserver2-hue
#    bind 0.0.0.0:10001
#    timeout client 1h
#    timeout server 1h
#    balance source
#    server hs2H-HIVESERVER2HOST1 HIVESERVER2HOST1:10000 check
#    server hs2H-HIVESERVER2HOST2 HIVESERVER2HOST2:10000 check

## Setup for Impala beeswax (impala-shell) or original ODBC driver.
## For JDBC or ODBC version 2.x driver, use port 21050 instead of 21000.
#listen impala-shell
#    bind 0.0.0.0:21000
#    timeout client 1h
#    timeout server 1h
#    balance leastconn
#    server impalaS-IMPALAHOST1 IMPALAHOST1.DOMAIN:21000 check
#    server impalaS-IMPALAHOST2 IMPALAHOST2.DOMAIN:21000 check
#    server impalaS-IMPALAHOST3 IMPALAHOST3.DOMAIN:21000 check
#    server impalaS-IMPALAHOST4 IMPALAHOST4.DOMAIN:21000 check
#    server impalaS-IMPALAHOST5 IMPALAHOST5.DOMAIN:21000 check

## Setup for Impala JDBC connections.
#listen impala-jdbc
#    bind 0.0.0.0:21050
#    timeout client 1h
#    timeout server 1h
#    balance leastconn
#    server impalaJ-IMPALAHOST1 IMPALAHOST1.DOMAIN:21050 check
#    server impalaJ-IMPALAHOST2 IMPALAHOST2.DOMAIN:21050 check
#    server impalaJ-IMPALAHOST3 IMPALAHOST3.DOMAIN:21050 check
#    server impalaJ-IMPALAHOST4 IMPALAHOST4.DOMAIN:21050 check
#    server impalaJ-IMPALAHOST5 IMPALAHOST5.DOMAIN:21050 check

## Setup for Impala Hue JDBC connection.
## In particular, Hue requires sticky sessions.
## Set Hue "server_conn_timeout = 1 hour" to match the HAproxy timeout.
#listen impala-hue
#    bind 0.0.0.0:21051
#    timeout client 1h
#    timeout server 1h
#    balance source
#    server impalaH-IMPALAHOST1 IMPALAHOST1.DOMAIN:21050 check
#    server impalaH-IMPALAHOST2 IMPALAHOST2.DOMAIN:21050 check
#    server impalaH-IMPALAHOST3 IMPALAHOST3.DOMAIN:21050 check
#    server impalaH-IMPALAHOST4 IMPALAHOST4.DOMAIN:21050 check
#    server impalaH-IMPALAHOST5 IMPALAHOST5.DOMAIN:21050 check

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

if selinuxenabled 2>/dev/null; then
  setsebool -P haproxy_connect_any on
fi

service haproxy start
chkconfig haproxy on

echo "****************************************"
echo "Now go and configure /etc/haproxy/haproxy.cfg to meet your needs."
echo "****************************************"
echo "Set Hue server_conn_timeout = 1 hour to match the HAproxy timeout."
echo "****************************************"

