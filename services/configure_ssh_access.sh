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
# Copyright Clairvoyant 2017

# This is useful to configure EC2 instances to allow SSHD to authenticate users
# via password.  It changes the SSH daemon config to allow password-based
# authentication and specifically denies root login.

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
echo "Configuring PasswordAuthentication SSH access..."
DATE=`date '+%Y%m%d%H%M%S'`
cp -p /etc/ssh/sshd_config /etc/ssh/sshd_config.${DATE}
sed -e '/^PasswordAuthentication/d' \
    -e '/^#PasswordAuthentication/a\PasswordAuthentication yes' \
    -e '/^PermitRootLogin/d' \
    -e '/^#PermitRootLogin/a\PermitRootLogin no' \
    -i /etc/ssh/sshd_config
service sshd restart

