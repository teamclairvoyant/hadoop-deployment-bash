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
#
if [ $DEBUG ]; then set -x; fi
if [ $DEBUG ]; then ECHO=echo; fi
#
##### START CONFIG ###################################################

_KRBSERVER=`hostname -f`

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
DATE=`date '+%Y%m%d%H%M%S'`

# Function to print the help screen.
print_help () {
  echo "Usage:  $1 --realm <realm> --cm_principal <princ>"
#  echo "Usage:  $1 --realm <realm> [--kdc_password <password>] --cm_principal <princ> [--cm_principal_password <password>]"
  echo ""
  echo "        -r|--realm                   <Kerberos realm>"
  echo "        -c|--cm_principal            <CM principal>"
#  echo "        [-k|--kdc_password           <KDC password>]"
#  echo "        [-p|--cm_principal_password  <CM principal password>]"
  echo "        [-h|--help]"
  echo "        [-v|--version]"
  echo ""
  echo "   ex.  $1 --realm HADOOP.COM --cm_principal cloudera-scm"
#  echo "   ex.  $1 --realm HADOOP.COM --kdc_password 1234567890 --cm_principal cloudera-scm --cm_principal_password abcdefghij"
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
    -r|--realm)
      shift
      _REALM_UPPER=`echo $1 | tr '[:lower:]' '[:upper:]'`
      _REALM_LOWER=`echo $1 | tr '[:upper:]' '[:lower:]'`
      ;;
#    -k|--kdc_password)
#      shift
#      _KDC_PASSWORD=$1
#      ;;
    -c|--cm_principal)
      shift
      _CM_PRINCIPAL=$1
      ;;
#    -p|--cm_principal_password)
#      shift
#      _CM_PRINCIPAL_PASSWORD=$1
#      ;;
    -h|--help)
      print_help "$(basename $0)"
      ;;
    -v|--version)
      echo "Install MIT Kerberos Key Distribution Center."
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
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# Check to see if we have the required parameters.
if [ -z "$_REALM_UPPER" -o -z "$_CM_PRINCIPAL" ]; then print_help "$(basename $0)"; fi
#if [ -z "$_REALM_UPPER" -o -z "$_KDC_PASSWORD" -o -z "$_CM_PRINCIPAL" -o -z "$_CM_PRINCIPAL_PASSWORD" ]; then print_help "$(basename $0)"; fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
echo "Installing MIT KDC..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  yum -y -e1 -d1 install krb5-server krb5-workstation

  echo "** Writing configs..."
  if [ ! -f /var/kerberos/krb5kdc/kdc.conf-orig ]; then
    cp -p /var/kerberos/krb5kdc/kdc.conf /var/kerberos/krb5kdc/kdc.conf-orig
  else
    cp -p /var/kerberos/krb5kdc/kdc.conf /var/kerberos/krb5kdc/kdc.conf.${DATE}
  fi
  chown root:root /var/kerberos/krb5kdc/kdc.conf
  chmod 0600 /var/kerberos/krb5kdc/kdc.conf
  cat <<EOF >/var/kerberos/krb5kdc/kdc.conf
[kdcdefaults]
kdc_ports = 88
kdc_tcp_ports = 88

[realms]
${_REALM_UPPER} = {
 master_key_type = aes256-cts
 acl_file = /var/kerberos/krb5kdc/kadm5.acl
 dict_file = /usr/share/dict/words
 admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
 database_name = /var/kerberos/krb5kdc/principal
 key_stash_file = /var/kerberos/krb5kdc/.k5.${_REALM_UPPER}
 default_principal_flags = +renewable, +forwardable
 max_life = 1d 0h 0m 0s
 max_renewable_life = 7d 0h 0m 0s
 # WARNING: aes256-cts:normal requires the Java enhanced security JCE policy file
 # to be installed in order for Hadoop crypto to make use of it.
 #supported_enctypes = aes256-cts:normal aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal
 supported_enctypes = aes256-cts:normal aes128-cts:normal
}
EOF

  if [ ! -f /var/kerberos/krb5kdc/kadm5.acl-orig ]; then
    cp -p /var/kerberos/krb5kdc/kadm5.acl /var/kerberos/krb5kdc/kadm5.acl-orig
  else
    cp -p /var/kerberos/krb5kdc/kadm5.acl /var/kerberos/krb5kdc/kadm5.acl.${DATE}
  fi
  chown root:root /var/kerberos/krb5kdc/kadm5.acl
  chmod 0600 /var/kerberos/krb5kdc/kadm5.acl
  cat <<EOF >/var/kerberos/krb5kdc/kadm5.acl
*/admin@${_REALM_UPPER} *
${_CM_PRINCIPAL}@${_REALM_UPPER} * accumulo/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * flume/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * hbase/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * hdfs/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * hive/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * httpfs/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * HTTP/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * hue/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * impala/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * kafka/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * kafka_mirror_maker/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * kudu/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * kms/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * llama/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * mapred/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * oozie/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * sentry/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * solr/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * spark/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * sqoop/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * sqoop2/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * yarn/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * zookeeper/*@${_REALM_UPPER}
EOF

  if [ ! -f /etc/krb5.conf-orig ]; then
    cp -p /etc/krb5.conf /etc/krb5.conf-orig
  else
    cp -p /etc/krb5.conf /etc/krb5.conf.${DATE}
  fi
  mkdir -p -m 0755 /etc/krb5.conf.d/
  cat <<EOF >/etc/krb5.conf
# Configuration snippets may be placed in this directory as well
includedir /etc/krb5.conf.d/

[logging]
default = FILE:/var/log/krb5libs.log
kdc = FILE:/var/log/krb5kdc.log
admin_server = FILE:/var/log/kadmind.log

[libdefaults]
default_realm = $_REALM_UPPER
dns_lookup_realm = false
dns_lookup_kdc = false
ticket_lifetime = 24h
renew_lifetime = 7d
forwardable = true
rdns = false
# We have to use FILE: until JVM can support something better.
# https://community.hortonworks.com/questions/11288/kerberos-cache-in-ipa-redhat-idm-keyring-solved.html
default_ccache_name = FILE:/tmp/krb5cc_%{uid}
# Set udp_preference_limit = 1 when only TCP should be used. Consider using in
# complex network environments when troubleshooting or when dealing with
# inconsistent client behavior or GSS (63) messages.
#udp_preference_limit = 1

[realms]
$_REALM_UPPER = {
 kdc = ${_KRBSERVER}
 admin_server = ${_KRBSERVER}
}

[domain_realm]
.${_REALM_LOWER} = $_REALM_UPPER
$_REALM_LOWER = $_REALM_UPPER
EOF

  echo "** Generating initial KDC database ..."
  _KDC_PASSWORD=`apg -a 1 -M NCL -m 20 -x 20 -n 1 2>/dev/null`
  if [ -z "$_KDC_PASSWORD" ]; then
    _KDC_PASSWORD=`< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo`
  fi
  echo "****************************************"
  echo "****************************************"
  echo "****************************************"
  echo "*** SAVE THIS PASSWORD"
  echo "KDC : ${_KDC_PASSWORD}"
  echo "****************************************"
  echo "****************************************"
  echo "****************************************"
  kdb5_util -P "$_KDC_PASSWORD" create -s >/dev/null

  echo "** Generating $_CM_PRINCIPAL principal for Cloudera Manager ..."
  _CM_PRINCIPAL_PASSWORD=`apg -a 1 -M NCL -m 20 -x 20 -n 1 2>/dev/null`
  if [ -z "$_CM_PRINCIPAL_PASSWORD" ]; then
    _CM_PRINCIPAL_PASSWORD=`< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo`
  fi
  echo "****************************************"
  echo "****************************************"
  echo "****************************************"
  echo "*** SAVE THIS PASSWORD"
  echo "${_CM_PRINCIPAL}@${_REALM_UPPER} : ${_CM_PRINCIPAL_PASSWORD}"
  echo "****************************************"
  echo "****************************************"
  echo "****************************************"
  kadmin.local >/dev/null <<EOF
addpol default
addprinc -pw $_CM_PRINCIPAL_PASSWORD $_CM_PRINCIPAL
EOF

  echo "** Starting services ..."
  service krb5kdc start
  chkconfig krb5kdc on
  service kadmin start
  chkconfig kadmin on
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y -q install krb5-admin-server krb5-kdc wamerican

  echo "** Writing configs..."
  if [ ! -f /etc/krb5kdc/kdc.conf-orig ]; then
    cp -p /etc/krb5kdc/kdc.conf /etc/krb5kdc/kdc.conf-orig
  else
    cp -p /etc/krb5kdc/kdc.conf /etc/krb5kdc/kdc.conf.${DATE}
  fi
  chown root:root /etc/krb5kdc/kdc.conf
  chmod 0600 /etc/krb5kdc/kdc.conf
  cat <<EOF >/etc/krb5kdc/kdc.conf
[kdcdefaults]
kdc_ports = 88
kdc_tcp_ports = 88

[realms]
${_REALM_UPPER} = {
 master_key_type = aes256-cts
 acl_file = /etc/krb5kdc/kadm5.acl
 dict_file = /usr/share/dict/words
 admin_keytab = FILE:/etc/krb5kdc/kadm5.keytab
 database_name = /var/lib/krb5kdc/principal
 key_stash_file = /etc/krb5kdc/stash
 default_principal_flags = +renewable, +forwardable
 max_life = 1d 0h 0m 0s
 max_renewable_life = 7d 0h 0m 0s
 # WARNING: aes256-cts:normal requires the Java enhanced security JCE policy file
 # to be installed in order for Hadoop crypto to make use of it.
 #supported_enctypes = aes256-cts:normal aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal
 supported_enctypes = aes256-cts:normal aes128-cts:normal
}
EOF

  if [ ! -f /etc/krb5kdc/kadm5.acl-orig ]; then
    cp -p /etc/krb5kdc/kadm5.acl /etc/krb5kdc/kadm5.acl-orig
  else
    cp -p /etc/krb5kdc/kadm5.acl /etc/krb5kdc/kadm5.acl.${DATE}
  fi
  chown root:root /etc/krb5kdc/kadm5.acl
  chmod 0600 /etc/krb5kdc/kadm5.acl
  cat <<EOF >/etc/krb5kdc/kadm5.acl
*/admin@${_REALM_UPPER} *
${_CM_PRINCIPAL}@${_REALM_UPPER} * accumulo/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * flume/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * hbase/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * hdfs/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * hive/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * httpfs/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * HTTP/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * hue/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * impala/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * kafka/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * kafka_mirror_maker/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * kudu/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * kms/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * llama/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * mapred/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * oozie/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * sentry/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * solr/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * spark/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * sqoop/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * sqoop2/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * yarn/*@${_REALM_UPPER}
${_CM_PRINCIPAL}@${_REALM_UPPER} * zookeeper/*@${_REALM_UPPER}
EOF

  if [ ! -f /etc/krb5.conf-orig ]; then
    cp -p /etc/krb5.conf /etc/krb5.conf-orig
  else
    cp -p /etc/krb5.conf /etc/krb5.conf.${DATE}
  fi
  mkdir -p -m 0755 /etc/krb5.conf.d/
  cat <<EOF >/etc/krb5.conf
# Configuration snippets may be placed in this directory as well
includedir /etc/krb5.conf.d/

[logging]
default = FILE:/var/log/krb5libs.log
kdc = FILE:/var/log/krb5kdc.log
admin_server = FILE:/var/log/kadmind.log

[libdefaults]
default_realm = $_REALM_UPPER
dns_lookup_realm = false
dns_lookup_kdc = false
ticket_lifetime = 24h
renew_lifetime = 7d
forwardable = true
rdns = false
# We have to use FILE: until JVM can support something better.
# https://community.hortonworks.com/questions/11288/kerberos-cache-in-ipa-redhat-idm-keyring-solved.html
default_ccache_name = FILE:/tmp/krb5cc_%{uid}
# Set udp_preference_limit = 1 when only TCP should be used. Consider using in
# complex network environments when troubleshooting or when dealing with
# inconsistent client behavior or GSS (63) messages.
#udp_preference_limit = 1

[realms]
$_REALM_UPPER = {
 kdc = ${_KRBSERVER}
 admin_server = ${_KRBSERVER}
}

[domain_realm]
.${_REALM_LOWER} = $_REALM_UPPER
$_REALM_LOWER = $_REALM_UPPER
EOF

  echo "** Generating initial KDC database ..."
  _KDC_PASSWORD=`apg -a 1 -M NCL -m 20 -x 20 -n 1 2>/dev/null`
  if [ -z "$_KDC_PASSWORD" ]; then
    _KDC_PASSWORD=`< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo`
  fi
  echo "****************************************"
  echo "****************************************"
  echo "****************************************"
  echo "*** SAVE THIS PASSWORD"
  echo "KDC : ${_KDC_PASSWORD}"
  echo "****************************************"
  echo "****************************************"
  echo "****************************************"
  kdb5_util -P "$_KDC_PASSWORD" create -s >/dev/null

  echo "** Generating $_CM_PRINCIPAL principal for Cloudera Manager ..."
  _CM_PRINCIPAL_PASSWORD=`apg -a 1 -M NCL -m 20 -x 20 -n 1 2>/dev/null`
  if [ -z "$_CM_PRINCIPAL_PASSWORD" ]; then
    _CM_PRINCIPAL_PASSWORD=`< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo`
  fi
  echo "****************************************"
  echo "****************************************"
  echo "****************************************"
  echo "*** SAVE THIS PASSWORD"
  echo "${_CM_PRINCIPAL}@${_REALM_UPPER} : ${_CM_PRINCIPAL_PASSWORD}"
  echo "****************************************"
  echo "****************************************"
  echo "****************************************"
  kadmin.local >/dev/null <<EOF
addpol default
addprinc -pw $_CM_PRINCIPAL_PASSWORD $_CM_PRINCIPAL
EOF

  echo "** Starting services ..."
  service krb5-kdc start
  update-rc.d krb5-kdc defaults
  service krb5-admin-server start
  update-rc.d krb5-admin-server defaults
fi

