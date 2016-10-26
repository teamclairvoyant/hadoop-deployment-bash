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

USEHAVEGED=$1

if rpm -q redhat-lsb-core; then
  OSREL=`lsb_release -rs | awk -F. '{print $1}'`
else
  OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
fi

if grep -q rdrand /proc/cpuinfo; then
  RDRAND=true
else
  RDRAND=false
fi

if [ -f /dev/hwrng ]; then
  HWRNG=true
else
  HWRNG=false
fi

if [ -n "$USEHAVEGED" ]; then
  yum -y -e1 -d1 install epel-release
  yum -y -e1 -d1 install haveged
  service haveged start
  chkconfig haveged on
else
  # https://www.cloudera.com/content/www/en-us/downloads/navigator/encrypt/3-8-0.html
  # http://www.certdepot.net/rhel7-get-started-random-number-generator/
  yum -y -d1 -e1 install rng-tools
  if [ $RDRAND == false  -a $HWRNG == false ]; then
    if [ $OSREL == 6 ]; then
      sed -i -e 's|^EXTRAOPTIONS=.*|EXTRAOPTIONS="-r /dev/urandom"|' /etc/sysconfig/rngd
    else
      cp -p /usr/lib/systemd/system/rngd.service /etc/systemd/system/
      sed -i -e 's|^ExecStart=.*|ExecStart=/sbin/rngd -f -r /dev/urandom|' /etc/systemd/system/rngd.service
      systemctl daemon-reload
    fi
  fi
  service rngd start
  chkconfig rngd on
fi

