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

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

# ARGV:
# 1 - CDSW DNS subdomain name - required

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
#"cdsw.cloudera.com" NOT "CN=cmhost.sec.cloudera.com,OU=Support,O=Cloudera,L=Denver,ST=Colorado,C=US"
CN="$1"
if [ -z "$CN" ]; then
  echo "ERROR: Missing CDSW subdomain name."
  exit 1
fi
if echo "$CN" | grep -q =; then
  echo "ERROR: Input should be only a CDSW subdomain name and NOT a DN."
  exit 3
fi

echo "Generating CDSW TLS CSR..."
if [ -d /etc/hortonworks ]; then
  _DIR=/etc/hortonworks
elif [ -d /opt/cloudera ]; then
  _DIR=/opt/cloudera
else
  echo "ERROR: Cannot determine if this is Cloudera or Hortonworks."
  exit 11
fi

if [ -f "${_DIR}/security/x509/cdsw.key" ]; then
  echo "ERROR: Private key already exists.  Exiting..."
  exit 4
fi
if [ -f "${_DIR}/security/x509/cdsw.csr" ]; then
  echo "ERROR: CSR already exists.  Exiting..."
  exit 5
fi
# Generate a CSR (cdsw.csr) and private key (cdsw.key).
cat <<EOF >${_DIR}/security/x509/cdsw.cnf
# https://www.cloudera.com/documentation/data-science-workbench/latest/topics/cdsw_tls_ssl.html
# CLAIRVOYANT
[ CA_default ]
default_md = sha2

[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
req_extensions     = req_ext

[ req_distinguished_name ]
#countryName                 = Country Name (2 letter code)
#countryName_default         = ${C}
#stateOrProvinceName         = State or Province Name (full name)
#stateOrProvinceName_default = ${ST}
#localityName                = Locality Name (eg, city)
#localityName_default        = ${L}
#organizationName            = Organization Name (eg, company)
#organizationName_default    = ${O}
commonName                  = Common Name (e.g. server FQDN)
commonName_default          = ${CN}

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
DNS.2 = *.${CN}
EOF
chown root:root "${_DIR}/security/x509/cdsw.cnf"
chmod 0444 "${_DIR}/security/x509/cdsw.cnf"
openssl req -newkey rsa:2048 -nodes -batch -out "${_DIR}/security/x509/cdsw.csr" \
  -keyout "${_DIR}/security/x509/cdsw.key" -config "${_DIR}/security/x509/cdsw.cnf"
chown root:root "${_DIR}/security/x509/cdsw.csr"
chmod 0444 "${_DIR}/security/x509/cdsw.csr"
chown root:root "${_DIR}/security/x509/cdsw.key"
chmod 0400 "${_DIR}/security/x509/cdsw.key"

