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
#
if [ $DEBUG ]; then set -x; fi
if [ $DEBUG ]; then ECHO=echo; fi
#
##### START CONFIG ###################################################

# http://injustfiveminutes.com/2014/10/28/how-to-initialize-openldap-2-4-x-server-with-olc-on-centos-7/
# http://www.server-world.info/en/note?os=CentOS_7&p=openldap&f=1
_ROOTDN="Manager"

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
YUMOPTS="-y -e1 -d1"
DATE=`date '+%Y%m%d%H%M%S'`

# Function to print the help screen.
print_help () {
  echo "Usage:  $1 --domain <dns domain or kerberos realm>"
  echo "        [-r|--rootdn <LDAP superuser>]"
  echo "        [-p|--passwd <LDAP superuser password>]"
  echo "        [-h|--help]"
  echo "        [-v|--version]"
  echo "   ex.  $1 --domain HADOOP.COM"
  exit 1
}

# Function to check for root priviledges.
check_root () {
  if [[ `/usr/bin/id | awk -F= '{print $2}' | awk -F"(" '{print $1}' 2>/dev/null` -ne 0 ]]; then
    echo "You must have root priviledges to run this program."
    exit 2
  fi
}

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=`lsb_release -is`
    # 7.2.1511, 14.04
    OSVER=`lsb_release -rs`
    # 7, 14
    OSREL=`echo $OSVER | awk -F. '{print $1}'`
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n"`
      OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}'`
    fi
  fi
}

## If the variable DEBUG is set, then turn on tracing.
## http://www.research.att.com/lists/ast-users/2003/05/msg00009.html
#if [ $DEBUG ]; then
#  # This will turn on the ksh xtrace option for mainline code
#  set -x
#
#  # This will turn on the ksh xtrace option for all functions
#  typeset +f |
#  while read F junk
#  do
#    typeset -ft $F
#  done
#  unset F junk
#fi

# Process arguments.
while [[ $1 = -* ]]; do
  case $1 in
    -d|--domain)
      shift
      _DOMAIN_LOWER=`echo $1 | tr '[:upper:]' '[:lower:]'`
      ;;
    -r|--rootdn)
      shift
      _ROOTDN="$1"
      ;;
    -p|--passwd)
      shift
      _ROOTPW="$1"
      ;;
    -h|--help)
      print_help "$(basename $0)"
      ;;
    -v|--version)
      echo "Create test users and groups in LDAP and Kerberos."
      exit 0
      ;;
    *)
      print_help "$(basename $0)"
      ;;
  esac
  shift
done

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
# Currently only EL.
#discover_os
#if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS ]; then
#  echo "ERROR: Unsupported OS."
#  exit 3
#fi

# Check to see if we have the required parameters.
if [ -z "$_DOMAIN_LOWER" ]; then print_help "$(basename $0)"; fi

# Lets not bother continuing unless we have the privs to do something.
#check_root

# main
echo "Creating test credentials in LDAP..."
_SUFFIX=`echo ${_DOMAIN_LOWER} | awk -F. '{print "dc="$1",dc="$2}'`
_ROOTDN=`echo "$_ROOTDN" | sed -e 's|cn=||' -e "s|,${_SUFFIX}||"`
_ROOTDN="cn=${_ROOTDN},${_SUFFIX}"
#_LDAPPASS=`slappasswd -s $_ROOTPW`

#ldapadd -x -w $_ROOTPW -D $_ROOTDN -H ldapi:/// <<EOF
#dn: $_SUFFIX
#objectClass: dcObject
#objectClass: organization
#dc: $_DOMAIN_LOWER
#o: $_DOMAIN_LOWER
#structuralObjectClass: organization
#EOF

ldapadd -x -w $_ROOTPW -D $_ROOTDN -H ldapi:/// <<EOF
# Creates a base for DIT
dn: $_SUFFIX
objectClass: top
objectClass: dcObject
objectclass: organization
o: $_DOMAIN_LOWER
dc: $_DOMAIN_LOWER
description: $_DOMAIN_LOWER
-
#dn: $_ROOTDN
#objectclass: organizationalRole
#cn: Manager
-
# Creates a People OU (Organizational Unit)
dn: ou=People,${_SUFFIX}
objectClass: organizationalUnit
ou: People
-
# Creates a Groups OU
dn: ou=Groups,${_SUFFIX}
objectClass: organizationalUnit
ou: Groups
EOF

# Create test users and groups.
ldapadd -x -w $_ROOTPW -D $_ROOTDN -H ldapi:/// <<EOF
dn: uid=user00,ou=People,${_SUFFIX}
uid: user00
cn: User 00
givenName: User
sn: 00
objectClass: top
objectClass: posixAccount
objectClass: inetOrgPerson
loginShell: /bin/bash
homeDirectory: /home/user00
uidNumber: 15000
gidNumber: 10000
userPassword: PASSWORD1
mail: user00@${_DOMAIN_LOWER}
gecos: user00 User
-
dn: uid=user01,ou=People,${_SUFFIX}
uid: user01
cn: User 01
givenName: User
sn: 01
objectClass: top
objectClass: posixAccount
objectClass: inetOrgPerson
loginShell: /bin/bash
homeDirectory: /home/user01
uidNumber: 15001
gidNumber: 10001
userPassword: PASSWORD1
mail: user01@${_DOMAIN_LOWER}
gecos: user01 User

dn: uid=user02,ou=People,${_SUFFIX}
uid: user02
cn: User 02
givenName: User
sn: 02
objectClass: top
objectClass: posixAccount
objectClass: inetOrgPerson
loginShell: /bin/bash
homeDirectory: /home/user02
uidNumber: 15002
gidNumber: 10002
userPassword: PASSWORD1
mail: user02@${_DOMAIN_LOWER}
gecos: user02 User

dn: cn=group00,ou=Groups,${_SUFFIX}
objectClass: posixGroup
objectClass: top
cn: group00
gidNumber: 10000
memberuid: user00

dn: cn=group01,ou=Groups,${_SUFFIX}
objectClass: posixGroup
objectClass: top
cn: group01
gidNumber: 10001
memberuid: user01

dn: cn=group02,ou=Groups,${_SUFFIX}
objectClass: groupOfNames
member: uid=user02,ou=People,${_SUFFIX}
cn: group02
EOF

ldapsearch -x -D $_ROOTDN -w $_ROOTPW

if [ -x /usr/sbin/kadmin.local ]; then
  echo "Creating test credentials in Kerberos..."
  kadmin.local <<EOF
addprinc -pw p@ssw0rd user00
addprinc -pw p@ssw0rd user01
addprinc -pw p@ssw0rd user02
EOF
  echo
fi

