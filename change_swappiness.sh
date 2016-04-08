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

VAL=1

if rpm -q redhat-lsb-core; then
  OSREL=`lsb_release -rs | awk -F. '{print $1}'`
else
  OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
fi

sysctl -w vm.swappiness=$VAL

if [ $OSREL == 6 ]; then
  if grep -q vm.swappiness /etc/sysctl.conf; then
    sed -i -e "/^vm.swappiness/s|=.*|= $VAL|" /etc/sysctl.conf
  else
    echo "vm.swappiness = $VAL" >>/etc/sysctl.conf
  fi
else
  if grep -q vm.swappiness /etc/sysctl.conf; then
    sed -i -e '/^vm.swappiness/d' /etc/sysctl.conf
  fi
  echo "# Tuning for Hadoop installation." >/etc/sysctl.d/cloudera.conf
  echo "vm.swappiness = $VAL" >>/etc/sysctl.d/cloudera.conf
fi

