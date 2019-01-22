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

#_ROOTDN="Manager"

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
DATE=$(date '+%Y%m%d%H%M%S')

# Function to print the help screen.
print_help() {
  echo "Usage:  $1"
#  echo "Usage:  $1 --domain <dns domain or kerberos realm>"
#  echo "        [-r|--rootdn <LDAP superuser>]"
#  echo "        [-p|--passwd <LDAP superuser password>]"
  echo "        [-h|--help]"
  echo "        [-v|--version]"
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
      if [ -f /etc/centos-release ]; then
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
#    -d|--domain)
#      shift
#      _DOMAIN_LOWER=$(echo "$1" | tr '[:upper:]' '[:lower:]')
#      ;;
#    -r|--rootdn)
#      shift
#      _ROOTDN="$1"
#      ;;
#    -p|--passwd)
#      shift
#      _ROOTPW="$1"
#      ;;
    -h|--help)
      print_help "$(basename "$0")"
      ;;
    -v|--version)
      echo "Install PHP LDAP Admin."
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
#if [ -z "$_DOMAIN_LOWER" ]; then print_help "$(basename "$0")"; fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
echo "Installing phpLDAPadmin..."
#_SUFFIX=$(echo ${_DOMAIN_LOWER} | awk -F. '{print "dc="$1",dc="$2}')
#_ROOTDN=$(echo "$_ROOTDN" | sed -e 's|cn=||' -e "s|,${_SUFFIX}||")
#_ROOTDN="cn=${_ROOTDN},${_SUFFIX}"

if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  setsebool -P httpd_can_connect_ldap=on

  yum -y -e1 -d1 install epel-release
  if ! rpm -q epel-release; then
    rpm -Uvh "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSREL}.noarch.rpm"
  fi
  yum -y -e1 -d1 install httpd phpldapadmin

  if [ ! -f /etc/httpd/conf.d/phpldapadmin.conf-orig ]; then
    cp -p /etc/httpd/conf.d/phpldapadmin.conf /etc/httpd/conf.d/phpldapadmin.conf-orig
  else
    cp -p /etc/httpd/conf.d/phpldapadmin.conf /etc/httpd/conf.d/phpldapadmin.conf."${DATE}"
  fi
#  cat <<EOF >/etc/httpd/conf.d/phpldapadmin.conf
##
##  Web-based tool for managing LDAP servers
##
#Alias /phpldapadmin /usr/share/phpldapadmin/htdocs
#Alias /ldapadmin /usr/share/phpldapadmin/htdocs
#
#<Directory /usr/share/phpldapadmin/htdocs>
#  Order Allow,Deny
#  Allow from all
#</Directory>
#
#EOF
  sed -e '/Require/s|Require local|Require all granted|' \
      -e '/Order/s|Deny,Allow|Allow,Deny|' \
      -e '/Order/s|deny,allow|Allow,Deny|' \
      -e '/Allow from/d' \
      -e '/Deny from all/s|Deny|Allow|' \
      -i /etc/httpd/conf.d/phpldapadmin.conf
  if [ ! -f /etc/phpldapadmin/config.php-orig ]; then
    cp -p /etc/phpldapadmin/config.php /etc/phpldapadmin/config.php-orig
  else
    cp -p /etc/phpldapadmin/config.php /etc/phpldapadmin/config.php."${DATE}"
  fi
  sed -e '/# CLAIRVOYANT$/d' \
      -e "/Local LDAP Server/a\
\$servers->setValue('server','host','ldaps://127.0.0.1'); # CLAIRVOYANT\\
\$servers->setValue('server','port',636); # CLAIRVOYANT\\
\$servers->setValue('login','fallback_dn',true); # CLAIRVOYANT\\
\$servers->setValue('auto_number','min',array('uidNumber'=>10000,'gidNumber'=>10000)); # CLAIRVOYANT" \
      -i /etc/phpldapadmin/config.php

  chkconfig httpd on
  service httpd restart
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  :
fi

echo "Go to http://$(hostname -f)/phpldapadmin/"

exit 0


#servie iptables save
#sed -i -e '/--dport 22/i\
#-A INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT\
#-A INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT' /etc/sysconfig/iptables
#service iptables restart

