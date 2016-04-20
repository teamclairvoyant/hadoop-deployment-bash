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

# https://blog.stathat.com/2014/12/22/fix_ec2_network_issue_skb_rides_the_rocket.html
# Fix EC2 Network Issue: skb rides the rocket: 19 slots

if rpm -q redhat-lsb-core; then
  OSREL=`lsb_release -rs | awk -F. '{print $1}'`
else
  OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
fi
# https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1317811
if [ $OSREL == 6 ]; then
  /usr/sbin/ethtool -K eth0 sg off
  sed -i '/ethtool -K eth0 sg off/d' /etc/rc.local
  echo '/usr/sbin/ethtool -K eth0 sg off' >>/etc/rc.local
else
  # http://www.certdepot.net/rhel7-rc-local-service/
  sed -i '/ethtool -K eth0 sg off/d' /etc/rc.d/rc.local
  echo '/usr/sbin/ethtool -K eth0 sg off' >>/etc/rc.d/rc.local
  chmod +x /etc/rc.d/rc.local
  systemctl start rc-local
fi

