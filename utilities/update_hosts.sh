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
echo "Updating /etc/hosts..."
IP=`/usr/bin/curl -s http://169.254.169.254/latest/meta-data/local-ipv4`
H1=`hostname -f`
H2=`hostname -s`
sed -i -e "/^$IP/d" /etc/hosts
echo "$IP	$H1 $H2" >>/etc/hosts
hostname $H1

