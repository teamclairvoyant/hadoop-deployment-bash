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

if [ ! -d /var/lib/keytrustee/.keytrustee/.ssl-orig/ ]; then
  cp -a /var/lib/keytrustee/.keytrustee/.ssl/ /var/lib/keytrustee/.keytrustee/.ssl-orig/
fi
cat /opt/cloudera/security/CAcerts/ca.cert.pem /opt/cloudera/security/CAcerts/intermediate.cert.pem >/opt/cloudera/security/x509/ca-chain.cert.pem
install -m 0400 -o keytrustee -g keytrustee /opt/cloudera/security/x509/ca-chain.cert.pem /var/lib/keytrustee/.keytrustee/.ssl/ssl-cert-keytrustee-ca.pem
install -m 0400 -o keytrustee -g keytrustee /opt/cloudera/security/x509/localhost.pem /var/lib/keytrustee/.keytrustee/.ssl/ssl-cert-keytrustee.pem
install -m 0400 -o keytrustee -g keytrustee /opt/cloudera/security/x509/localhost.key /var/lib/keytrustee/.keytrustee/.ssl/ssl-cert-keytrustee-pk.pem

