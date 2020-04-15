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
# Copyright Clairvoyant 2020

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
if [ ! -f /opt/cloudera/security/x509/localhost.pem ]; then
  echo "ERROR: Missing TLS certificate."
  exit 4
fi
if [ ! -f /opt/cloudera/security/x509/localhost.key ]; then
  echo "ERROR: Missing TLS key."
  exit 5
fi

echo "Configuring HAProxy for TLS..."
DATE=$(date '+%Y%m%d%H%M%S')
cat /opt/cloudera/security/x509/localhost.key \
    /opt/cloudera/security/x509/localhost.pem \
    /opt/cloudera/security/CAcerts/intermediate*.cert.pem \
    /opt/cloudera/security/CAcerts/ca.cert.pem \
    >/etc/haproxy/cert.pem
chmod 0600 /etc/haproxy/cert.pem
chown root:root /etc/haproxy/cert.pem

cp -p /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg."${DATE}"
sed -e 's|bind :1936.*|bind :1936 ssl crt /etc/haproxy/cert.pem no-sslv3 no-tlsv10 no-tlsv11|' \
    -i /etc/haproxy/haproxy.cfg

service haproxy condrestart

