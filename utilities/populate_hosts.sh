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
# 1 - name of the file which contains /etc/hosts formatted data - required

#for X in `awk -F@ '{print $2}' hosts-QA `;do
#  Y=`echo $X|sed -e 's|\.|-|g'`
#  Z=`host "ip-${Y}.us-west-2.compute.internal."`
#  echo "$Z" | awk "{print \$4,\$1,\"ip-$Y\"}"
#done >hostlist

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
HOSTLIST=$1
if [ -z "$HOSTLIST" ]; then
  echo "ERROR: Missing hostlist file."
  exit 1
fi
echo "Populating /etc/hosts..."
IP=`/usr/bin/curl -s http://169.254.169.254/latest/meta-data/local-ipv4`
#sed -i -e '/^[0-9]/d' /etc/hosts
sed -i -e "/^${IP}/d" /etc/hosts
cat $HOSTLIST >>/etc/hosts

