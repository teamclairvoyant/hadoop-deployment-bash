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

exit 1
service iptables save

sed -i -e '/--dport 22/i\
-A INPUT -p tcp -m state --state NEW -m tcp --dport 88  -j ACCEPT\
-A INPUT -p tcp -m state --state NEW -m tcp --dport 464 -j ACCEPT\
-A INPUT -p tcp -m state --state NEW -m tcp --dport 749 -j ACCEPT\
-A INPUT -p udp -m udp --dport 88  -j ACCEPT\
-A INPUT -p udp -m udp --dport 464 -j ACCEPT\
-A INPUT -p udp -m udp --dport 749 -j ACCEPT' /etc/sysconfig/iptables

service iptables restart

