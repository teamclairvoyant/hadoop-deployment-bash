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

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"

if [ ! -f /opt/cloudera/security/x509/localhost_renew.csr ]; then
  echo "ERROR: New CSR does not exist.  Exiting..."
  exit 1
fi

if [ ! -f /opt/cloudera/security/x509/localhost_renew.key ]; then
  echo "ERROR: New private key does not exist.  Exiting..."
  exit 3
fi

if [ ! -f /opt/cloudera/security/x509/localhost_renew.pem ]; then
  echo "ERROR: New certificate does not exist.  Exiting..."
  exit 4
fi

mv /opt/cloudera/security/x509/localhost_renew.csr /opt/cloudera/security/x509/localhost.csr
mv /opt/cloudera/security/x509/localhost_renew.key /opt/cloudera/security/x509/localhost.key
mv /opt/cloudera/security/x509/localhost_renew.pem /opt/cloudera/security/x509/localhost.pem

echo "SUCCESS"

