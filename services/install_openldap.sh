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
if [ -n "$DEBUG" ]; then set -x; fi
#
##### START CONFIG ###################################################

# http://injustfiveminutes.com/2014/10/28/how-to-initialize-openldap-2-4-x-server-with-olc-on-centos-7/
# http://www.server-world.info/en/note?os=CentOS_7&p=openldap&f=1
_ROOTDN="Manager"

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
DATE=$(date '+%Y%m%d%H%M%S')

# Function to print the help screen.
print_help() {
  echo "Usage:  $1 --domain <dns domain or kerberos realm>"
  echo "        $1 [-r|--rootdn <LDAP superuser>]"
  echo "        $1 [-h|--help]"
  echo "        $1 [-v|--version]"
  echo "   ex.  $1"
  exit 1
}

# Function to check for root privileges.
check_root() {
  if [[ $(/usr/bin/id | awk -F= '{print $2}' | awk -F"(" '{print $1}' 2>/dev/null) -ne 0 ]]; then
    echo "You must have root privileges to run this program."
    exit 2
  fi
}

# Function to discover basic OS details.
discover_os() {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu, RedHatEnterpriseServer, Debian, SUSE LINUX
    # shellcheck disable=SC2034
    OS=$(lsb_release -is)
    # CentOS= 6.10, 7.2.1511, Ubuntu= 14.04, RHEL= 6.10, 7.5, SLES= 11
    # shellcheck disable=SC2034
    OSVER=$(lsb_release -rs)
    # 7, 14
    # shellcheck disable=SC2034
    OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    # Ubuntu= trusty, wheezy, CentOS= Final, RHEL= Santiago, Maipo, SLES= n/a
    # shellcheck disable=SC2034
    OSNAME=$(lsb_release -cs)
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/almalinux-release ]; then
        # shellcheck disable=SC2034
        OS=AlmaLinux
        # 8.6
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/almalinux-release --qf='%{VERSION}\n')
        # shellcheck disable=SC2034
        OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
      elif [ -f /etc/centos-release ]; then
        # shellcheck disable=SC2034
        OS=CentOS
        # 7.5.1804.4.el7.centos, 6.10.el6.centos.12.3
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/centos-release --qf='%{VERSION}.%{RELEASE}\n' | awk -F. '{print $1"."$2}')
        # shellcheck disable=SC2034
        OSREL=$(rpm -qf /etc/centos-release --qf='%{VERSION}\n')
      else
        # shellcheck disable=SC2034
        OS=RedHatEnterpriseServer
        # 7.5, 6Server
        # shellcheck disable=SC2034
        OSVER=$(rpm -qf /etc/redhat-release --qf='%{VERSION}\n')
        if [ "$OSVER" == "6Server" ]; then
          # shellcheck disable=SC2034
          OSVER=$(rpm -qf /etc/redhat-release --qf='%{RELEASE}\n' | awk -F. '{print $1"."$2}')
          # shellcheck disable=SC2034
          OSNAME=Santiago
        else
          # shellcheck disable=SC2034
          OSNAME=Maipo
        fi
        # shellcheck disable=SC2034
        OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
      fi
    elif [ -f /etc/SuSE-release ]; then
      if grep -q "^SUSE Linux Enterprise Server" /etc/SuSE-release; then
        # shellcheck disable=SC2034
        OS="SUSE LINUX"
      fi
      # shellcheck disable=SC2034
      OSVER=$(rpm -qf /etc/SuSE-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
      # shellcheck disable=SC2034
      OSREL=$(rpm -qf /etc/SuSE-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
      # shellcheck disable=SC2034
      OSNAME="n/a"
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
      _DOMAIN_LOWER=$(echo "$1" | tr '[:upper:]' '[:lower:]')
      ;;
    -r|--rootdn)
      shift
      _ROOTDN="$1"
      ;;
    -h|--help)
      print_help "$(basename "$0")"
      ;;
    -v|--version)
      echo "Install OpenLDAP server."
      exit 0
      ;;
    *)
      print_help "$(basename "$0")"
      ;;
  esac
  shift
done

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
# Currently only EL.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ]; then
#if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# Check to see if we have the required parameters.
if [ -z "$_DOMAIN_LOWER" ]; then print_help "$(basename "$0")"; fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
echo "Installing OpenLDAP..."
_SUFFIX=$(echo "${_DOMAIN_LOWER}" | awk -F. '{print "dc="$1",dc="$2}')
_ROOTDN=$(echo "$_ROOTDN" | sed -e 's|cn=||' -e "s|,${_SUFFIX}||")
_ROOTDN="cn=${_ROOTDN},${_SUFFIX}"

if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  yum -y -e1 -d1 install openldap-servers openldap-clients

  _PASS=$(apg -a 1 -M NCL -m 20 -x 20 -n 1)
  if [ -z "$_PASS" ]; then
    _PASS=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo)
  fi
  _ROOTPW=${_PASS}
  _LDAPPASS=$(slappasswd -s "$_ROOTPW")
  cp -p /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
  chown -R ldap:ldap /var/lib/ldap
  restorecon -rv /var/lib/ldap
  service slapd start
  chkconfig slapd on

  #ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/core.ldif
  ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
  ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
  ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif

  ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcSuffix
olcSuffix: $_SUFFIX
EOF
  ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={2}hdb,cn=config
changetype: modify
replace: olcRootDN
olcRootDN: $_ROOTDN
EOF
  ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={1}monitor,cn=config
changetype: modify
replace: olcAccess
olcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read by dn.base="${_ROOTDN}" read by * none
EOF
  ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to attrs=userPassword,shadowLastChange by dn="${_ROOTDN}" write by anonymous auth by self write by * none
olcAccess: {1}to dn.base="" by * read
olcAccess: {2}to * by dn="${_ROOTDN}" write by * read
EOF
  ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={2}hdb,cn=config
changetype: modify
add: olcRootPW
olcRootPW: $_LDAPPASS
EOF

  echo "****************************************"
  echo "****************************************"
  echo "****************************************"
  echo "*** SAVE THIS PASSWORD"
  echo "${_ROOTDN} : ${_ROOTPW}"
  echo "****************************************"
  echo "****************************************"
  echo "****************************************"

  cp -p /etc/openldap/ldap.conf /etc/openldap/ldap.conf."${DATE}"
  cat <<EOF >>/etc/openldap/ldap.conf
BASE            ${_SUFFIX}
URI             ldap://$(hostname -f)
EOF
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  :
fi

