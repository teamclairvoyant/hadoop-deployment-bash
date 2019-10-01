#!/bin/bash
# shellcheck disable=SC1091
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
# Copyright Clairvoyant 2015

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

# ARGV:
# 1 - JKS store password - required

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
SP="$1"
if [ -z "$SP" ]; then
  echo "ERROR: Missing keystore password."
  exit 1
fi

echo "Importing signed TLS certificate and chain..."
if [ -f /etc/profile.d/jdk.sh ]; then
  . /etc/profile.d/jdk.sh
elif [ -f /etc/profile.d/java.sh ]; then
  . /etc/profile.d/java.sh
fi

if [ -d /etc/hortonworks ]; then
  _DIR=/etc/hortonworks
elif [ -d /opt/cloudera ]; then
  _DIR=/opt/cloudera
else
  echo "ERROR: Cannot determine if this is Cloudera or Hortonworks."
  exit 11
fi

# Import ROOT CA certificate (ca.cert.pem) in server's JKS (localhost-keystore.jks)
keytool -importcert -trustcacerts -noprompt -alias RootCA \
 -keystore "${_DIR}/security/jks/localhost-keystore.jks" \
 -file "${_DIR}/security/CAcerts/ca.cert.pem" -storepass "$SP"

# Import Intermediate CA certificate (intermediate.cert.pem) in server's JKS (localhost-keystore.jks)
keytool -importcert -trustcacerts -noprompt -alias SubordinateCA \
 -keystore "${_DIR}/security/jks/localhost-keystore.jks" \
 -file "${_DIR}/security/CAcerts/intermediate.cert.pem" -storepass "$SP"

# Import server's signed certificate(localhost.pem)signed by CA in server's JKS (localhost-keystore.jks)
keytool -importcert -trustcacerts -noprompt -alias localhost \
 -keystore "${_DIR}/security/jks/localhost-keystore.jks" \
 -file "${_DIR}/security/x509/localhost.pem" -storepass "$SP"

