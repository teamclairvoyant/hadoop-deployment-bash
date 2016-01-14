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

SP="$1"
if [ -z "$SP" ]; then
  echo "ERROR: Missing keystore password."
  exit 1
fi

. /etc/profile.d/java.sh

keytool -importcert -trustcacerts -noprompt -alias RootCA \
-keystore /opt/cloudera/security/jks/localhost-keystore.jks \
-file /opt/cloudera/security/CAcerts/ca.cert.pem -storepass $SP

keytool -importcert -trustcacerts -noprompt -alias SubordinateCA \
-keystore /opt/cloudera/security/jks/localhost-keystore.jks \
-file /opt/cloudera/security/CAcerts/intermediate.cert.pem -storepass $SP

keytool -importcert -trustcacerts -noprompt -alias localhost \
-keystore /opt/cloudera/security/jks/localhost-keystore.jks \
-file /opt/cloudera/security/x509/localhost.pem -storepass $SP

