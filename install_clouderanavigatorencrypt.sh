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

YUMHOST=$1
if [ -z "$YUMHOST" ]; then
  echo "ERROR: Missing YUM hostname."
  exit 1
fi
if rpm -q redhat-lsb-core; then
  #OSREL=`lsb_release -rs | awk -F. '{print $1}'`
  OSVERSION=`lsb_release -rs`
else
  #OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
  OSVERSION=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n" | sed -e 's|\.el.*||'`
fi

echo "** Find the correct kernel-headers and kernel-devel that match the running kernel."
echo "** DON'T PANIC."
echo "** This might look scary..."
if ! yum -y -e1 -d1 install kernel-headers-$(uname -r) kernel-devel-$(uname -r); then
  cp -p /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo-orig
  sed -e "s|\$releasever|$OSVERSION|" -i /etc/yum.repos.d/CentOS-Base.repo
  yum clean metadata
  if ! yum -y -e1 -d1 install kernel-headers-$(uname -r) kernel-devel-$(uname -r); then
    sed -e '/^mirrorlist/s|^|#|' -e '/#baseurl/s|^#||' -e '/^baseurl/s|mirror.centos.org/centos|vault.centos.org|' -i /etc/yum.repos.d/CentOS-Base.repo
    yum clean metadata
    yum -y -e1 -d1 install kernel-headers-$(uname -r) kernel-devel-$(uname -r)
  fi
  mv /etc/yum.repos.d/CentOS-Base.repo-orig /etc/yum.repos.d/CentOS-Base.repo
  yum clean metadata
fi
echo "** End of possible errors."

yum -y -e1 -d1 install epel-release
wget -q http://${YUMHOST}/navigator-encrypt/latest/cloudera-navencrypt.repo -O /etc/yum.repos.d/cloudera-navencrypt.repo
yum -y -e1 -d1 install navencrypt
chkconfig navencrypt-mount on

