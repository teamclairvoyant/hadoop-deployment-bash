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

LDAPBASEDN=$1
if [ -z "$LDAPBASEDN" ]; then
  echo "ERROR: Missing LDAP Base DN."
  exit 1
fi
LDAPSERVER=$2
if [ -z "$LDAPSERVER" ]; then
  echo "ERROR: Missing LDAP server."
  exit 1
fi
#LDAPBASEDN="dc=clairvoyantsoft,dc=com"
#LDAPSERVER=server.clairvoyantsoft.com

# http://blog.zwiegnet.com/linux-server/configure-centos-7-ldap-client/
yum -y -e1 -d1 install nss-pam-ldapd
#yum -y -e1 -d1 install openldap-clients
authconfig --enableforcelegacy --update
authconfig --enableldap --ldapserver=${LDAPSERVER} --ldapbasedn=${LDAPBASEDN} --update
#authconfig --enableldapauth --enableldaptls --update

