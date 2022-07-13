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
# Copyright Clairvoyant 2021

# ARGV:
# 1 - JKS store password - required
DATE=$(date '+%Y%m%d%H%M%S')

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
CMPASS="$1"
if [ -z "$CMPASS" ]; then
  echo "ERROR: Missing keystore password."
  exit 1
fi

if [ -f /etc/profile.d/jdk.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/jdk.sh
elif [ -f /etc/profile.d/java.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/java.sh
fi

#if [ ! -f /opt/cloudera/security/jks/localhost-keystore.jks ]; then
#  echo "ERROR: Primary keystore does not exist.  Run 'generate_csr.sh'.  Exiting..."
#  exit 10
#fi

if [ ! -f /opt/cloudera/security/x509/localhost.pem ]; then
  echo "ERROR: Certificate does not exist.  Exiting..."
  exit 11
fi

if [ ! -f /opt/cloudera/security/x509/localhost.key ]; then
  echo "ERROR: Private key does not exist.  Exiting..."
  exit 12
fi

if [ ! -d /opt/cloudera/security/CAcerts ]; then
  echo "ERROR: CAcerts directory does not exist.  Exiting..."
  exit 13
fi

rm -f /tmp/localhost-keystore.p12.$$ /opt/cloudera/security/jks/localhost-keystore.jks.new
openssl pkcs12 -export -in /opt/cloudera/security/x509/localhost.pem \
  -inkey /opt/cloudera/security/x509/localhost.key -name localhost \
  -out /tmp/localhost-keystore.p12.$$ -passout "pass:$CMPASS" \
  -chain -CApath /opt/cloudera/security/CAcerts/
keytool -importkeystore -deststorepass "$CMPASS" -destkeypass "$CMPASS" \
  -destkeystore /opt/cloudera/security/jks/localhost-keystore.jks.new \
  -srckeystore /tmp/localhost-keystore.p12.$$ -srcstoretype PKCS12 \
  -srcstorepass "$CMPASS" -alias localhost
chmod 0440 /opt/cloudera/security/jks/localhost-keystore.jks.new
chown root:cloudera-scm /opt/cloudera/security/jks/localhost-keystore.jks.new
rm -f /tmp/localhost-keystore.p12.$$

cp -p /opt/cloudera/security/jks/localhost-keystore.jks /opt/cloudera/security/jks/localhost-keystore.jks."${DATE}"
mv /opt/cloudera/security/jks/localhost-keystore.jks.new /opt/cloudera/security/jks/localhost-keystore.jks

