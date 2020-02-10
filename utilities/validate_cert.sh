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
# 1 - x.509 certificate file - optional (defaults to /opt/cloudera/security/x509/localhost.pem)

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
FILE=${1-/opt/cloudera/security/x509/localhost.pem}
if [ ! -f "$FILE" ]; then
  echo "ERROR: $FILE does not exist or is not a file."
  exit 1
fi
echo "Validating X.509 certificate ${FILE} ..."
CRT=$(openssl x509 -text -noout -in "$FILE")
KU=$(echo "$CRT" | sed -n '/X509v3 Key Usage:/{n;p}' | sed -e 's|^[[:space:]]*||')
EKU=$(echo "$CRT" | sed -n '/X509v3 Extended Key Usage:/{n;p}' | sed -e 's|^[[:space:]]*||')
SAN=$(echo "$CRT" | sed -n '/X509v3 Subject Alternative Name:/{n;p}' | sed -e 's|, |\n|' -e 's|^[[:space:]]*||')

if [ "$KU" == "Digital Signature, Key Encipherment" ]; then
  echo "SUCCESS: The KU is correct."
else
  echo "ERROR: The KU is incorrect."
fi
if [ "$EKU" == "TLS Web Server Authentication, TLS Web Client Authentication" ]; then
  echo "SUCCESS: The EKU is correct."
else
  echo "ERROR: The EKU is incorrect."
fi
echo "Subject Alternative Names:"
echo "$SAN"

