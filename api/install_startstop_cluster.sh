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
# Copyright Clairvoyant 2016

yum -y -e1 -d1 install jq
cp -p ~centos/{start,stop}_cluster.sh /usr/local/sbin/
chown 0:0 /usr/local/sbin/{start,stop}_cluster.sh
chmod 700 /usr/local/sbin/{start,stop}_cluster.sh
rm -f /tmp/$$
crontab -l | egrep -v 'stop_cluster.sh|start_cluster.sh' >/tmp/$$
echo '00 08 * * * /usr/local/sbin/start_cluster.sh >/dev/null'>>/tmp/$$
echo '00 18 * * * /usr/local/sbin/stop_cluster.sh >/dev/null'>>/tmp/$$
crontab /tmp/$$
rm -f /tmp/$$

