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

# https://www.server-world.info/en/note?os=CentOS_7&p=openldap&f=4

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
DATE=`date '+%Y%m%d%H%M%S'`

# Function to print the help screen.
print_help () {
  echo "Usage:  $1"
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
      _DOMAIN_LOWER=`echo $1 | tr '[:upper:]' '[:lower:]'`
      ;;
    -r|--rootdn)
      shift
      _ROOTDN="$1"
      ;;
    -h|--help)
      print_help "$(basename $0)"
      ;;
    -v|--version)
      echo "Configure OpenLDAP to use existing Cloudera TLS certificates."
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
#if [ -z "$_DOMAIN_LOWER" ]; then print_help "$(basename $0)"; fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
if [ ! -f /opt/cloudera/security/x509/localhost.pem ]; then
  echo "ERROR: Missing TLS certificate."
  exit 4
fi
if [ ! -f /opt/cloudera/security/x509/localhost.key ]; then
  echo "ERROR: Missing TLS key."
  exit 5
fi
if [ ! -f /opt/cloudera/security/x509/ca-chain.cert.pem ]; then
  echo "ERROR: Missing TLS certificate chain."
  exit 6
fi

echo "Configuring OpenLDAP for TLS..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  install -m 0444 -o ldap -g ldap /opt/cloudera/security/x509/localhost.pem /etc/openldap/certs/server.crt
  install -m 0440 -o ldap -g ldap /opt/cloudera/security/x509/localhost.key /etc/openldap/certs/server.key
  #install -m 0444 -o ldap -g ldap /opt/cloudera/security/x509/ca-chain.cert.pem /etc/openldap/certs/ca-bundle.crt

  ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: cn=config
changetype: modify
add: olcTLSCACertificateFile
#olcTLSCACertificateFile: /etc/openldap/certs/ca-bundle.crt
olcTLSCACertificateFile: /opt/cloudera/security/x509/ca-chain.cert.pem
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/openldap/certs/server.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/openldap/certs/server.key
-
# the following directive is the default but
# is explicitly included for visibility reasons
add: olcTLSVerifyClient
olcTLSVerifyClient: never
#EOF
# To require TLSv1.0 or higher with 128bit and longer ciphers you probably just want:
#  olcTLSProtocolMin: 3.1
#  olcTLSCipherSuite: HIGH
#ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
#dn: cn=config
#changetype: modify
-
add: olcSecurity
olcSecurity: tls=1
-
add: olcTLSProtocolMin
olcTLSProtocolMin: 3.1
-
add: olcTLSCipherSuite
olcTLSCipherSuite: HIGH
EOF

  cp -p /etc/sysconfig/slapd /etc/sysconfig/slapd.${DATE}
  sed -e '/^SLAPD_URLS=/s|=.*|="ldapi:/// ldaps:///"|' \
      -i /etc/sysconfig/slapd

  cp -p /etc/openldap/ldap.conf /etc/openldap/ldap.conf.${DATE}
  cat <<EOF >>/etc/openldap/ldap.conf
TLS_REQCERT     allow
EOF
  sed -e '/^URI/s|ldap://|ldaps://|' \
      -i /etc/openldap/ldap.conf

  service slapd restart
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  :
fi

