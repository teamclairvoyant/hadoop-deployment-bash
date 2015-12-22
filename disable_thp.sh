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
if [ $OSREL == 6 ]; then
  echo never >/sys/kernel/mm/transparent_hugepage/defrag
  sed -i '/transparent_hugepage/d' /etc/rc.local
  echo 'echo never >/sys/kernel/mm/transparent_hugepage/defrag' >>/etc/rc.local
else
  # http://www.certdepot.net/rhel7-rc-local-service/
  sed -i '/transparent_hugepage/d' /etc/rc.d/rc.local
  echo 'echo never >/sys/kernel/mm/transparent_hugepage/defrag' >>/etc/rc.d/rc.local
  chmod +x /etc/rc.d/rc.local
  systemctl start rc-local
fi

