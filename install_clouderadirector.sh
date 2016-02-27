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

if rpm -q redhat-lsb-core; then
  OSREL=`lsb_release -rs | awk -F. '{print $1}'`
else
  OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
fi
wget -q http://archive.cloudera.com/director/redhat/${OSREL}/x86_64/director/cloudera-director.repo -O /etc/yum.repos.d/cloudera-director.repo
yum -y -e1 -d1 install cloudera-director-server cloudera-director-client
cp -p /etc/cloudera-director-server/application.properties /etc/cloudera-director-server/application.properties-orig
chgrp cloudera-director /etc/cloudera-director-server/application.properties
chmod 0640 /etc/cloudera-director-server/application.properties
sed -i -e '/lp.encryption.twoWayCipher:/a\
lp.encryption.twoWayCipher: desede' -e "/lp.encryption.twoWayCipherConfig:/a\
lp.encryption.twoWayCipherConfig: `python -c 'import base64, os; print base64.b64encode(os.urandom(24))'`" /etc/cloudera-director-server/application.properties
service cloudera-director-server start
chkconfig cloudera-director-server on

