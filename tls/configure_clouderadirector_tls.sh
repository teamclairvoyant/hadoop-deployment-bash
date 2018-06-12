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
# Copyright Clairvoyant 2018

# ARGV:
# 1 - JKS store password - required

SP="$1"
KP="$SP"

if [ -z "$SP" ]; then
  echo "ERROR: Missing keystore password."
  exit 2
fi
if [ -z "$KP" ]; then
  echo "ERROR: Missing private key password."
  exit 3
fi

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
chmod 0440 /opt/cloudera/security/jks/localhost-keystore.jks
chown root:cloudera-director /opt/cloudera/security/jks/localhost-keystore.jks

# https://www.cloudera.com/documentation/director/latest/topics/director_tls_enable.html#concept_odg_qbv_gbb
echo "Configuring Cloudera Director to use TLS..."
sed -e '/^# CLAIRVOYANT TLS START$/,/^# CLAIRVOYANT TLS END$/d' \
    -e "/server.ssl.key-store:/a\\
# CLAIRVOYANT TLS START\\
server.ssl.key-store: /opt/cloudera/security/jks/localhost-keystore.jks\\
server.ssl.key-store-password: $SP\\
server.ssl.key-store-type: JKS\\
server.ssl.key-password: $KP\\
server.ssl.enabled-protocols: TLSv1.2\\
# CLAIRVOYANT TLS END" \
    -i /etc/cloudera-director-server/application.properties
echo "Restarting Director..."
service cloudera-director-server restart

