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

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
echo "Copying Kudu TLS certs and keys..."
install -m 0444 -o kudu -g kudu /opt/cloudera/security/x509/localhost.pem /opt/cloudera/security/x509/kudu.crt
install -m 0440 -o kudu -g kudu /opt/cloudera/security/x509/localhost.e.key /opt/cloudera/security/x509/kudu.key

