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

. /etc/profile.d/java.sh
/bin/cp -p ${JAVA_HOME}/jre/lib/security/cacerts ${JAVA_HOME}/jre/lib/security/jssecacerts
keytool -importcert -file /opt/cloudera/security/CAcerts/ca.cert.pem -alias CAcert -keystore ${JAVA_HOME}/jre/lib/security/jssecacerts -storepass changeit -noprompt -trustcacerts
keytool -importcert -file /opt/cloudera/security/CAcerts/intermediate.cert.pem -alias CAcertint -keystore ${JAVA_HOME}/jre/lib/security/jssecacerts -storepass changeit -noprompt -trustcacerts

yum -y -e1 -d1 install openssl-perl
c_rehash /opt/cloudera/security/CAcerts/

