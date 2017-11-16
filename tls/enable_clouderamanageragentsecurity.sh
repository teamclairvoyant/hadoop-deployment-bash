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

# ARGV:
# 1 - Whether to enable Level 3 agent authN to server. - optional

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
LEVEL3=$1
if [ -n "$LEVEL3" ]; then
  echo "Configuring Cloudera Manager Agent for TLS level 3..."
  # https://www.cloudera.com/content/www/en-us/documentation/enterprise/latest/topics/cm_sg_config_tls_agent_auth.html
  sed -e '/^client_key_file/d' \
      -e '/^client_keypw_file/d' \
      -e '/^client_cert_file/d' \
      -e '/^# client_key_file/a\
client_key_file=/opt/cloudera/security/x509/localhost.key' \
      -e '/^# client_keypw_file/a\
client_keypw_file=/etc/cloudera-scm-agent/agentkey.pw' \
      -e '/^# client_cert_file/a\
client_cert_file=/opt/cloudera/security/x509/localhost.pem' \
      -i /etc/cloudera-scm-agent/config.ini
else
  echo "Configuring Cloudera Manager Agent for TLS level 2..."
fi

# https://www.cloudera.com/content/www/en-us/documentation/enterprise/latest/topics/cm_sg_config_tls_auth.html
sed -e '/^use_tls/s|=.*|=1|' \
    -e '/^verify_cert_file/d' \
    -e '/^verify_cert_dir/d' \
    -e '/^# verify_cert_dir/a\
verify_cert_dir=/opt/cloudera/security/CAcerts' \
    -i /etc/cloudera-scm-agent/config.ini

#sed -e '/^use_tls/s|=.*|=1|' \
#    -e '/^verify_cert_file/d' \
#    -e '/^verify_cert_dir/d' \
#    -e '/^# verify_cert_file/a\
#verify_cert_file=/opt/cloudera/security/x509/cmhost.pem' \
#    -i /etc/cloudera-scm-agent/config.ini
#touch /opt/cloudera/security/x509/cmhost.pem

service cloudera-scm-agent restart

