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
# Copyright Clairvoyant 2015

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

# ARGV:
# 1 - CDSW DNS subdomain name - required
# 2 - JKS store password - required

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
#"cdsw.cloudera.com" NOT "CN=cmhost.sec.cloudera.com,OU=Support,O=Cloudera,L=Denver,ST=Colorado,C=US"
DN="$1"
SP="$2"
KP="$SP"
if [ -z "$DN" ]; then
  echo "ERROR: Missing CDSW subdomain name."
  exit 1
fi
if [ -z "$SP" ]; then
  echo "ERROR: Missing keystore password."
  exit 2
fi
if echo "$DN" | grep -q =; then
  echo "ERROR: Input should be only a CDSW subdomain name and NOT a DN."
  exit 3
fi
EXT="-ext SAN=DNS:${DN},DNS:*.${DN}"

echo "Generating TLS CSR..."
if [ -f /etc/profile.d/jdk.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/jdk.sh
elif [ -f /etc/profile.d/java.sh ]; then
  # shellcheck source=/dev/null
  . /etc/profile.d/java.sh
fi

if [ -d /etc/hortonworks ]; then
  _TYPE=hortonworks
  _DIR=/etc/hortonworks
elif [ -d /opt/cloudera ]; then
  _TYPE=cloudera
  _DIR=/opt/cloudera
else
  echo "ERROR: Cannot determine if this is Cloudera or Hortonworks."
  exit 11
fi

if [ -f "${_DIR}/security/jks/cdsw-keystore.jks" ]; then
  echo "ERROR: Keystore already exists.  Exiting..."
  exit 4
fi
# Generate a private RSA key and store it in JKS (cdsw-keystore.jks) with the distinguished name "$DN".
keytool -genkeypair -alias cdsw -keyalg RSA -sigalg SHA256withRSA \
 -keystore "${_DIR}/security/jks/cdsw-keystore.jks" \
 -keysize 2048 -dname "$DN" -storepass "$SP" -keypass "$KP"
chmod 0440 "${_DIR}/security/jks/cdsw-keystore.jks"
if [ "$_TYPE" == cloudera ]; then
  chown root:cloudera-scm "${_DIR}/security/jks/cdsw-keystore.jks"
else
  chown root:root "${_DIR}/security/jks/cdsw-keystore.jks"
fi

if [ -f "${_DIR}/security/x509/cdsw.csr" ]; then
  echo "ERROR: CSR already exists.  Exiting..."
  exit 5
fi
# https://www.cloudera.com/documentation/enterprise/5-9-x/topics/cm_sg_create_deploy_certs.html#concept_frd_1px_nw
# X509v3 Extended Key Usage:
#   TLS Web Server Authentication, TLS Web Client Authentication
# Generate a CSR (cdsw.csr) from the JKS (cdsw-keystore.jks).
# shellcheck disable=SC2086
keytool -certreq -alias cdsw \
 -keystore "${_DIR}/security/jks/cdsw-keystore.jks" \
 -file "${_DIR}/security/x509/cdsw.csr" -storepass "$SP" \
 -keypass "$KP" -ext EKU=serverAuth,clientAuth -ext KU=digitalSignature,keyEncipherment $EXT
chmod 0444 "${_DIR}/security/x509/cdsw.csr"

rm -f /tmp/cdsw-keystore.p12.$$
# Convert the proprietary JKS (cdsw-keystore.jks) to PKCS12 (cdsw-keystore.p12) format.
keytool -importkeystore -srckeystore "${_DIR}/security/jks/cdsw-keystore.jks" \
 -srcstorepass "$SP" -srckeypass "$KP" -destkeystore /tmp/cdsw-keystore.p12.$$ \
 -deststoretype PKCS12 -srcalias cdsw -deststorepass "$SP" -destkeypass "$KP"
if [ -f "${_DIR}/security/x509/cdsw.e.key" ]; then
  echo "ERROR: Encrypted Key already exists.  Exiting..."
  rm -f /tmp/cdsw-keystore.p12.$$
  exit 6
fi
# Extract the PEM encoded private key (cdsw.e.key) from the PKCS12 (cdsw-keystore.p12) file.
# The private key (cdsw.e.key) will still be in encrypted form.
openssl pkcs12 -in /tmp/cdsw-keystore.p12.$$ -passin "pass:$KP" -nocerts \
 -out "${_DIR}/security/x509/cdsw.e.key" -passout "pass:$KP"
chmod 0400 "${_DIR}/security/x509/cdsw.e.key"
rm -f /tmp/cdsw-keystore.p12.$$

if [ -f "${_DIR}/security/x509/cdsw.key" ]; then
  echo "ERROR: Key already exists.  Exiting..."
  exit 7
fi
# Extract the unencrypted PEM encoded private key (cdsw.key) from encrypted private key (cdsw.e.key).
openssl rsa -in "${_DIR}/security/x509/cdsw.e.key" \
 -passin "pass:$KP" -out "${_DIR}/security/x509/cdsw.key"
chmod 0400 "${_DIR}/security/x509/cdsw.key"
rm -f "${_DIR}/security/x509/cdsw.e.key"

