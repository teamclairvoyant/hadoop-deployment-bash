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

# ARGV:
# 1 - loadbalancer DNS name - required

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
#"/CN=cmhost.sec.cloudera.com/OU=Support/O=Cloudera/L=Denver/ST=Colorado/C=US"
#"/C=US/ST=Colorado/L=Denver/O=Cloudera/OU=Support/CN=cmhost.sec.cloudera.com"
#"C=US, ST=Colorado, L=Denver, O=Cloudera, OU=Support, CN=cmhost.sec.cloudera.com"
DN="$1"
if [ -z "$DN" ]; then
  echo "ERROR: Missing distinguished name."
  exit 1
fi
if ! echo "$DN" | grep -q =; then
  echo "ERROR: Input should be a distinguished name."
  echo "  /CN=cmhost.sec.cloudera.com/OU=Support/O=Cloudera/L=Denver/ST=Colorado/C=US"
  exit 2
fi
LB="$2"
if [ -z "$LB" ]; then
  echo "ERROR: Missing loadbalancer name."
  exit 3
fi
if echo "$LB" | grep -q =; then
  echo "ERROR: Input should be only a loadbalancer name and NOT a DN."
  exit 4
fi

echo "Generating TLS CSR..."
if [ -d /etc/hortonworks ]; then
  _DIR=/etc/hortonworks
elif [ -d /opt/cloudera ]; then
  _DIR=/opt/cloudera
else
  echo "ERROR: Cannot determine if this is Cloudera or Hortonworks."
  exit 11
fi

if [ -f "${_DIR}/security/x509/localhost_renew.key" ]; then
  echo "ERROR: New Private key already exists.  Exiting..."
  exit 4
fi
if [ -f "${_DIR}/security/x509/localhost_renew.csr" ]; then
  echo "ERROR: New CSR already exists.  Exiting..."
  exit 5
fi

declare "$(echo "$DN" | awk -F/ '{print $1}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F/ '{print $2}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F/ '{print $3}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F/ '{print $4}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F/ '{print $5}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F/ '{print $6}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F/ '{print $7}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F/ '{print $8}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F/ '{print $9}' | sed -e 's|^ *||')" 2>/dev/null

declare "$(echo "$DN" | awk -F, '{print $1}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F, '{print $2}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F, '{print $3}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F, '{print $4}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F, '{print $5}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F, '{print $6}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F, '{print $7}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F, '{print $8}' | sed -e 's|^ *||')" 2>/dev/null
declare "$(echo "$DN" | awk -F, '{print $9}' | sed -e 's|^ *||')" 2>/dev/null

# Generate a CSR (localhost_renew.csr) and private key (localhost_renew.key).
cat <<EOF >${_DIR}/security/x509/localhost.cnf
# https://www.cloudera.com/documentation/data-science-workbench/latest/topics/cdsw_tls_ssl.html
# CLAIRVOYANT
[ CA_default ]
default_md = sha2

[ req ]
# Stop confirmation prompts. All information is contained herein.
prompt             = no
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext

[ req_distinguished_name ]
countryName            = ${C}
stateOrProvinceName    = ${ST}
localityName           = ${L}
organizationName       = ${O}
organizationalUnitName = ${OU}
commonName             = ${CN}

# X509v3 extensions to add to a certificate request
[ req_ext ]
# What the key can/cannot be used for:
keyUsage = digitalSignature, keyEncipherment
# X509v3 Extended Key Usage:
#   TLS Web Server Authentication, TLS Web Client Authentication
extendedKeyUsage = serverAuth, clientAuth
# The subjectAltName is where you give the names of extra web sites.
# You may have more than one of these, so put in the section [ alt_names ]
# If you do not have any extra names, comment the next line out.
subjectAltName = @alt_names

# List of all the other DNS names that the certificate should work for.
[ alt_names ]
DNS.1 = ${CN}
DNS.2 = ${LB}
EOF
chown root:root "${_DIR}/security/x509/localhost.cnf"
chmod 0444 "${_DIR}/security/x509/localhost.cnf"
openssl req -newkey rsa:2048 -nodes -batch -out "${_DIR}/security/x509/localhost_renew.csr" \
  -keyout "${_DIR}/security/x509/localhost_renew.key" -config "${_DIR}/security/x509/localhost.cnf"
chown root:root "${_DIR}/security/x509/localhost_renew.csr"
chmod 0444 "${_DIR}/security/x509/localhost_renew.csr"
chown root:root "${_DIR}/security/x509/localhost_renew.key"
chmod 0400 "${_DIR}/security/x509/localhost_renew.key"

