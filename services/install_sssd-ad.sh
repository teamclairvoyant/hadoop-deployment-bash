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
PWCMD='< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo'
YUMOPTS="-y -e1 -d1"
DATE=`date '+%Y%m%d%H%M%S'`

# Function to print the help screen.
print_help () {
  echo "Joins the node to an Active Directory domain."
  echo ""
  echo "Usage:  $1 --domain <AD domain>"
  echo "        $1 [-u|--user <User name to use for enrollment>]"
  echo "        $1 [-o|--computer-ou <Computer OU DN to join>]"
  echo "        $1 [-i|--automatic-id-mapping] # Turn off automatic id mapping"
  echo "        $1 [-b|--batch] # Do not prompt for passwords"
  echo "        $1 [-h|--help]"
  echo "        $1 [-v|--version]"
  echo "   ex.  $1"
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
    -d|--domain)
      shift
      _DOMAIN_UPPER=`echo $1 | tr '[:lower:]' '[:upper:]'`
      _DOMAIN_LOWER=`echo $1 | tr '[:upper:]' '[:lower:]'`
      ;;
    -u|--user)
      shift
      _USER="-U $1"
      ;;
    -o|--computer-ou)
      shift
      #_OU7="--computer-ou=\"$1\"" # Deal with spaces in the OU name.
      #_OU6="--domain-ou=\"$1\""   # Deal with spaces in the OU name. 
      _OU7="--computer-ou=$1"
      _OU6="--domain-ou=$1"
      ;;
    -i|--automatic-id-mapping)
      shift
      _ID="--automatic-id-mapping=no"
      ;;
    -b|--batch)
      shift
      _BATCH7="--unattended"
      ;;
    -h|--help)
      print_help "$(basename $0)"
      ;;
    -v|--version)
      echo "Intall and configure SSSD to use the Active Directory provider."
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
if [ -z "$_DOMAIN_LOWER" ]; then print_help "$(basename $0)"; fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
echo "Installing SSSD for Active Directory..."
if [ \( "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS \) -a "$OSREL" == 7 ]; then
  # EL7
  OPTS="$_USER $_OU7 $_ID $_BATCH7"
  echo "** Installing software."
  yum $YUMOPTS install sssd adcli realmd PackageKit

  cat <<EOF >/etc/realmd.conf
[users]
default-home = /home/%u
default-shell = /bin/bash
EOF

  echo "** Discovering and joining domain..."
  realm discover $_DOMAIN_LOWER && \
  realm join $_DOMAIN_LOWER $OPTS || exit $?

  sed -e '/^use_fully_qualified_names .*/d' \
      -e '/^\[domain/a\
use_fully_qualified_names = False' -i /etc/sssd/sssd.conf
  sed -e '/^default_ccache_name = .*/d' \
      -e '/^# We have to use FILE:.*/d' \
      -e '/^# https:\/\/community.hortonworks.com\/.*/d' \
      -e '/^#default_ccache_name = FILE:\/tmp\/krb5cc_%{uid}$/d' \
      -e '/^\[domain/a\
# We have to use FILE: until JVM can support something better.\
# https://community.hortonworks.com/questions/11288/kerberos-cache-in-ipa-redhat-idm-keyring-solved.html\
#default_ccache_name = FILE:/tmp/krb5cc_%{uid}' -i /etc/sssd/sssd.conf
  service sssd restart

elif [ \( "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS \) -a "$OSREL" == 6 ]; then
  # EL6
  OPTS="$_USER $_OU6"
  echo "** Installing software."
  yum $YUMOPTS install sssd oddjob oddjob-mkhomedir adcli

  echo "** Discovering and joining domain..."
  adcli info $_DOMAIN_LOWER && \
  adcli join $_DOMAIN_LOWER $OPTS || exit $?

  echo "** Writing configs..."
  cat <<EOF >/etc/krb5.conf
[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 default_realm = $_DOMAIN_UPPER
 dns_lookup_realm = true
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 default_ccache_name = KEYRING:persistent:%{uid}
 # We have to use FILE: until JVM can support something better.
 # https://community.hortonworks.com/questions/11288/kerberos-cache-in-ipa-redhat-idm-keyring-solved.html
 #default_ccache_name = FILE:/tmp/krb5cc_%{uid}

[realms]

[domain_realm]
EOF
  chown root:root /etc/krb5.conf
  chmod 0644 /etc/krb5.conf

  cat <<EOF >/etc/sssd/sssd.conf
[sssd]
domains = $_DOMAIN_LOWER
config_file_version = 2
services = nss, pam

[domain/${_DOMAIN_LOWER}]
use_fully_qualified_names = False
ad_domain = $_DOMAIN_LOWER
krb5_realm = $_DOMAIN_UPPER
realmd_tags = manages-system joined-with-samba
cache_credentials = True
id_provider = ad
krb5_store_password_if_offline = True
default_shell = /bin/bash
ldap_id_mapping = True
fallback_homedir = /home/%u
access_provider = ad
EOF
  chown root:root /etc/sssd/sssd.conf
  chmod 0600 /etc/sssd/sssd.conf

  authconfig --enablesssd --enablesssdauth --enablemkhomedir --update
  service sssd start
  chkconfig sssd on
  service oddjobd start
  chkconfig oddjobd on
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  :
fi

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
fi

