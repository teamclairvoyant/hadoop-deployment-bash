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
# Copyright Clairvoyant 2019

# ARGV:
# 1 - TLS certificate Common Name - required
# 2 - JKS store password - required
# 3 - JKS key password (should be the same as JKS store password) - required
# 4 - Extra parameters for keytool (ie Subject Alternative Name (SAN)) - optional

# This steps to be carried out for each server.

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
#"CN=cmhost.sec.hortonworks.com,OU=Support,O=hortonworks,L=Denver,ST=Colorado,C=US"
DN="$1"
SP="$2"
#KP="$3"
KP="$SP"
#"SAN=DNS:`hostname`,DNS:my-lb.domain.com"
EXT="$4"
if [ -z "$DN" ]; then
  echo "ERROR: Missing distinguished name."
  exit 1
fi
if [ -z "$SP" ]; then
  echo "ERROR: Missing keystore password."
  exit 2
fi
if [ -z "$KP" ]; then
  echo "ERROR: Missing private key password."
  exit 3
fi
if [ -n "$EXT" ]; then
  EXT="-ext $EXT"
fi

echo "Generating TLS CSR..."
if [ -f /etc/profile.d/jdk.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/jdk.sh
elif [ -f /etc/profile.d/java.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/java.sh
fi

if [ -f /etc/hortonworks/security/jks/localhost-keystore.jks ]; then
  echo "ERROR: Keystore already exists.  Exiting..."
  exit 1
fi

# Generate a public/private key pair and store it in JKS (localhost-keystore.jks) for the domain name "$DN"
keytool -genkeypair -alias localhost -keyalg RSA -sigalg SHA256withRSA \
 -keystore /etc/hortonworks/security/jks/localhost-keystore.jks \
 -keysize 2048 -dname "$DN" -storepass "$SP" -keypass "$KP"

chmod 0440 /etc/hortonworks/security/jks/localhost-keystore.jks

chown root:root /etc/hortonworks/security/jks/localhost-keystore.jks

if [ -f /etc/hortonworks/security/x509/localhost.csr ]; then
  echo "ERROR: CSR already exists.  Exiting..."
  exit 2
fi
# https://www.cloudera.com/documentation/enterprise/5-9-x/topics/cm_sg_create_deploy_certs.html#concept_frd_1px_nw
# X509v3 Extended Key Usage:
#   TLS Web Server Authentication, TLS Web Client Authentication
# shellcheck disable=SC2086
# Generate a CSR (localhost.csr) for an existing JKS (localhost-keystore.jks)
# Send it to CA for signing purpose.
keytool -certreq -alias localhost \
 -keystore /etc/hortonworks/security/jks/localhost-keystore.jks \
 -file /etc/hortonworks/security/x509/localhost.csr -storepass "$SP" \
 -keypass "$KP" -ext EKU=serverAuth,clientAuth -ext KU=digitalSignature,keyEncipherment $EXT

rm -f /tmp/localhost-keystore.p12.$$

# Convert a JKS (localhost-keystore.jks) to a PKCS12 (localhost-keystore.p12) format
keytool -importkeystore -srckeystore /etc/hortonworks/security/jks/localhost-keystore.jks \
 -srcstorepass "$SP" -srckeypass "$KP" -destkeystore /tmp/localhost-keystore.p12.$$ \
 -deststoretype PKCS12 -srcalias localhost -deststorepass "$SP" -destkeypass "$KP"

if [ -f /etc/hortonworks/security/x509/localhost.e.key ]; then
  echo "ERROR: Encrypted Key already exists.  Exiting..."
  rm -f /tmp/localhost-keystore.p12.$$
  exit 3
fi

# Extract a private key (localhost.e.key) from a PKCS12 (localhost-keystore.p12). 
# The private key (localhost.e.key) will still be in encrypted form.
openssl pkcs12 -in /tmp/localhost-keystore.p12.$$ -passin "pass:$KP" -nocerts \
 -out /etc/hortonworks/security/x509/localhost.e.key -passout "pass:$KP"

chmod 0400 /etc/hortonworks/security/x509/localhost.e.key

rm -f /tmp/localhost-keystore.p12.$$

if [ -f /etc/hortonworks/security/x509/localhost.key ]; then
  echo "ERROR: Key already exists.  Exiting..."
  exit 4
fi

# Extract unencrypted private key (localhost.key) from encrypted private key (localhost.e.key). 
# Encrypted headers look like this:
#-----BEGIN RSA PRIVATE KEY-----
#Proc-Type: 4,ENCRYPTED DEK-Info: DES-EDE3-CBC,
#6AC307785DD187EF...
#-----END RSA PRIVATE KEY-----
openssl rsa -in /etc/hortonworks/security/x509/localhost.e.key \
 -passin "pass:$KP" -out /etc/hortonworks/security/x509/localhost.key

chmod 0400 /etc/hortonworks/security/x509/localhost.key

