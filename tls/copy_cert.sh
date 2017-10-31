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

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
echo "Copying Hadoop TLS certs and keys..."
install -m 0440 -o root -g hadoop /opt/cloudera/security/jks/localhost-keystore.jks /opt/cloudera/security/jks/hdfsyarn-keystore.jks
install -m 0440 -o root -g hbase /opt/cloudera/security/jks/localhost-keystore.jks /opt/cloudera/security/jks/hbase-keystore.jks
install -m 0440 -o root -g hive /opt/cloudera/security/jks/localhost-keystore.jks /opt/cloudera/security/jks/hive-keystore.jks
install -m 0440 -o root -g oozie /opt/cloudera/security/jks/localhost-keystore.jks /opt/cloudera/security/jks/oozie-keystore.jks
install -m 0440 -o root -g solr /opt/cloudera/security/jks/localhost-keystore.jks /opt/cloudera/security/jks/solr-keystore.jks
install -m 0440 -o root -g spark /opt/cloudera/security/jks/localhost-keystore.jks /opt/cloudera/security/jks/spark-keystore.jks
install -m 0440 -o root -g httpfs /opt/cloudera/security/jks/localhost-keystore.jks /opt/cloudera/security/jks/httpfs-keystore.jks
install -m 0440 -o root -g flume /opt/cloudera/security/jks/localhost-keystore.jks /opt/cloudera/security/jks/flume-keystore.jks
cat /opt/cloudera/security/CAcerts/ca.cert.pem /opt/cloudera/security/CAcerts/intermediate.cert.pem >/opt/cloudera/security/x509/ca-chain.cert.pem
chmod 0444 /opt/cloudera/security/x509/ca-chain.cert.pem
install -m 0444 -o hue -g hue /opt/cloudera/security/x509/localhost.pem /opt/cloudera/security/x509/hue.crt
install -m 0440 -o hue -g hue /opt/cloudera/security/x509/localhost.e.key /opt/cloudera/security/x509/hue.key
install -m 0440 -o hue -g hue /opt/cloudera/security/x509/localhost.key /opt/cloudera/security/x509/hue-proxy.key
install -m 0444 -o impala -g impala /opt/cloudera/security/x509/localhost.pem /opt/cloudera/security/x509/impala.crt
install -m 0440 -o impala -g impala /opt/cloudera/security/x509/localhost.e.key /opt/cloudera/security/x509/impala.key

