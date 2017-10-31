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
# Copyright Clairvoyant 2016
#
if [ $DEBUG ]; then set -x; fi
if [ $DEBUG ]; then ECHO=echo; fi
#
##### START CONFIG ###################################################

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
YUMOPTS="-y -e1 -d1"
DATE=`date '+%Y%m%d%H%M%S'`
_TLS=no

# Function to print the help screen.
print_help () {
  echo "Authenticate and indentify via LDAP."
  echo ""
  echo "Usage:  $1 --ldapserver <host> --suffix <search base>"
  echo ""
  echo "        -l|--ldapserver    <LDAP server>"
  echo "        -s|--suffix        <LDAP search base>"
  echo "        [-L|--ldaps]       # use LDAPS on port 636 instead of STARTTLS"
  echo "        [-h|--help]"
  echo "        [-v|--version]"
  echo ""
  echo "   ex.  $1 --ldapserver hostname --suffix dc=mydomain,dc=local"
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
    # trusty, wheezy, Final
    OSNAME=`lsb_release -cs`
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
    -l|--ldapserver)
      shift
      _LDAPSERVER=$1
      ;;
    -s|--suffix)
      shift
      _LDAPSUFFIX=$1
      ;;
    -L|--ldaps)
      _TLS=yes
      ;;
    -h|--help)
      print_help "$(basename $0)"
      ;;
    -v|--version)
      echo "Intall and configure SSSD to use the LDAP identity and authN providers."
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
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS ]; then
#if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# Check to see if we have the required parameters.
if [ -z "$_LDAPSERVER" -o -z "$_LDAPSUFFIX" ]; then print_help "$(basename $0)"; fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
echo "Installing SSSD for LDAP..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  echo "** Installing software."
  yum $YUMOPTS install sssd-ldap oddjob oddjob-mkhomedir

  echo "** Writing configs..."
  if [ "$_TLS" == yes ]; then
    _LDAPURI="ldaps://${_LDAPSERVER}:636/"
  else
    _LDAPURI="ldap://${_LDAPSERVER}/"
  fi
  cp -p /etc/sssd/sssd.conf /etc/sssd/sssd.conf.${DATE}
  cat <<EOF >/etc/sssd/sssd.conf
[sssd]
domains = default
config_file_version = 2
services = nss, pam

[domain/default]
id_provider = ldap
access_provider = simple
#access_provider = ldap
auth_provider = ldap
chpass_provider = ldap
min_id = 10000
cache_credentials = true
# sssd does not support authentication over an unencrypted channel.
ldap_uri = $_LDAPURI
ldap_tls_cacert = /etc/pki/tls/certs/ca-bundle.crt
ldap_id_use_start_tls = true
ldap_tls_reqcert = demand
ldap_search_base = $_LDAPSUFFIX
#ldap_schema = rfc2307bis
ldap_access_filter = memberOf=cn=sysadmin,ou=Groups,${_LDAPSUFFIX}
simple_allow_groups = sysadmin, hdpadmin, developer

EOF
  chown root:root /etc/sssd/sssd.conf
  chmod 0600 /etc/sssd/sssd.conf

  authconfig --enablesssd --enablesssdauth --enablemkhomedir --update
  service sssd start
  chkconfig sssd on
  service oddjobd start
  chkconfig oddjobd on

  if [ -f /etc/nscd.conf ]; then
    echo "*** Disabling NSCD caching of passwd/group/netgroup/services..."
    if [ ! -f /etc/nscd.conf-orig ]; then
      cp -p /etc/nscd.conf /etc/nscd.conf-orig
    else
      cp -p /etc/nscd.conf /etc/nscd.conf.${DATE}
    fi
    sed -e '/enable-cache[[:blank:]]*passwd/s|yes|no|' \
        -e '/enable-cache[[:blank:]]*group/s|yes|no|' \
        -e '/enable-cache[[:blank:]]*services/s|yes|no|' \
        -e '/enable-cache[[:blank:]]*netgroup/s|yes|no|' -i /etc/nscd.conf
    service nscd condrestart
    if ! service sssd status >/dev/null 2>&1; then
      service sssd restart
    fi
  fi
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  :
fi

