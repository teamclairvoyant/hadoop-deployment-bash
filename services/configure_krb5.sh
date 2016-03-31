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
# Copyright Cloudera 2013
# Copyright Clairvoyant 2015

prog_dir=`dirname $0`
tmpl_dir="${prog_dir}/tmpl"
domain="$(hostname -d)"
hostname="$(hostname -f)"
realm="HADOOP.COM"
kdc_directory="/var/kerberos/krb5kdc"
kdc_password=""
cm_principal="cloudera-scm"
cm_princ_password=""

log() {
  local level="$1"
  local msg="$2"

  echo "$(date "+%Y-%m-%d %H:%M:%S") ($$) $level - $msg"
}

error() {
  log ERROR "$1"

  if [ -n "$2" ] ; then
    exit $2
  fi
}

generate_unique_str() {
  $DATE +%Y%m%d-%H%M%S
}

detect_command() {
  local cmd="$1"
  local v="$2"

  log DEBUG "Detecting command $cmd"

  v=${v:-$(echo $cmd | tr 'a-z' 'A-Z')}
  cmd_path=$(type -p $cmd)
  eval_str="${v}=\"$cmd_path\""

  [ -n "$cmd_path" ] || error "Unable to locate command \"$cmd\" in path" 1

  eval "$eval_str"

  log DEBUG "  found at $cmd_path (assigned to \$$v)"
}

configure_environment() {
  log DEBUG "Checking distro type and version"

  [ -f "/etc/redhat-release" ] ||
    error "No /etc/redhat-release found - This only works on RH workalikes!" 1
  [ -n "$hostname" ] ||
    error "hostname -f produced an empty hostname (you're in clown town!)" 1
  [ -n "$domain" ] ||
    error "hostname -d produced an empty domain name (non-fully qualified hostname?)" 1

  detect_command date
  detect_command rpm
  detect_command yum
  detect_command seq
  detect_command mkdir
  detect_command chown
  detect_command chmod
  detect_command sleep
  detect_command sed
  detect_command service
  detect_command chkconfig
  detect_command id

  [ "$($ID -u)" -eq 0 ] || error "You must run this script as root" 1
}

gather_passwords() {
  echo "*** Local Kerberos Bootstrapper ***"
  echo
  echo "This utility will bootstrap a local MIT KDC for use with"
  echo "Cloudera Manager and Hadoop. Changes *will* be made to"
  echo "Kerberos related files and any pre-existing KDC. Backups"
  echo "are made of all changes files, but you shouldn't depend"
  echo "on them."
  echo
  log DEBUG "Gathering passwords"

  echo -n "Please enter the desired Kerberos realm [$realm]: "
  read kdc_realm < /dev/tty
  if [ -z "$kdc_realm" ]; then
    kdc_realm=$realm
  fi
  if [ -z "$kdc_password" ]; then
    echo "It is important that you NOT FORGET this password."
    echo -n "Please enter a STRONG master password for the KDC: "
    read kdc_password < /dev/tty
  fi
  echo -n "Please enter a new CM principal [$cm_principal]: "
  read cm_princ < /dev/tty
  if [ -z "$cm_princ" ]; then
    cm_princ=$cm_principal
  fi
  if [ -z "$cm_princ_password" ]; then
    echo -n "Please enter a new CM principal password: "
    read cm_princ_password < /dev/tty
  fi
}

prompt_for_safety() {
#  echo "*** Local Kerberos Bootstrapper ***"
#  echo
#  echo "This utility will bootstrap a local MIT KDC for use with"
#  echo "Cloudera Manager and Hadoop. Changes *will* be made to"
#  echo "Kerberos related files and any pre-existing KDC. Backups"
#  echo "are made of all changes files, but you shouldn't depend"
#  echo "on them."
  echo
  echo "Using the following settings:"
  echo
  echo "           domain: ${domain}"
  echo "         hostname: ${hostname}"
  echo "        kdc_realm: ${kdc_realm}"
  echo "    kdc_directory: ${kdc_directory}"
  echo "     kdc_password: ${kdc_password}"
  echo "         cm_princ: ${cm_princ}"
  echo "cm_princ_password: ${cm_princ_password}"
  echo
  echo "*** DANGER DANGER DANGER DANGER DANGER ***"
  echo "You have 10 seconds to hit Control-C to stop this script!"
  echo "*** DANGER DANGER DANGER DANGER DANGER ***"

  for i in $($SEQ 1 10) ; do
    $SLEEP 1
    echo -n "."
  done

  echo
}

install_krb_packages() {
  log DEBUG "Installing necessary krb5 packages"

  local krb_packages="krb5-server krb5-workstation"

  $YUM install -y -e1 -d1 $krb_packages || error "Yum install failed" 1

  detect_command kadmin.local KADMIN_LOCAL
  detect_command kadmin
  detect_command kdb5_util
}

configure_kdc() {
  log DEBUG "Setting up the KDC configuration files"

  local kdc_directory_tmp="${kdc_directory}.$(generate_unique_str)"

  $MKDIR "$kdc_directory_tmp" ||
    error "Failed to create KDC temp directory:$kdc_directory_tmp" 1

  $SED -e "s/@@kdc_realm@@/${kdc_realm}/g" "${tmpl_dir}/kdc.conf.tmpl" > "${kdc_directory_tmp}/kdc.conf" ||
    error "Unable to generate kdc.conf" 1

  $SED -e "s/@@kdc_realm@@/${kdc_realm}/g" "${tmpl_dir}/kadm5.acl.tmpl" > "${kdc_directory_tmp}/kadm5.acl" ||
    error "Unable to generate kadm5.acl" 1

  if [ -d "$kdc_directory" ] ; then
    mv "$kdc_directory" "${kdc_directory}.bak.$(generate_unique_str)" ||
      error "Can not back up existing kdc directory: $kdc_directory" 1
  fi

  mv "$kdc_directory_tmp" "$kdc_directory" ||
    error "Unable to move $kdc_directory_tmp to $kdc_directory" 1
}

configure_krb_client() {
  log DEBUG "Setting up krb5 client configuration file"

  $SED -e "s/@@kdc_realm@@/${kdc_realm}/g;
    s/@@hostname@@/${hostname}/g;
    s/@@domain@@/${domain}/g;" "${tmpl_dir}/etc_krb5.conf.tmpl" > "/etc/krb5.conf.tmp" ||
    error "Unable to generate /etc/krb5.conf" 1

  if [ -f "/etc/krb5.conf" ] ; then
    mv "/etc/krb5.conf" "/etc/krb5.conf.bak.$(generate_unique_str)" ||
      error "Unable to back up /etc/krb5.conf" 1
  fi

  mv "/etc/krb5.conf.tmp" "/etc/krb5.conf" ||
    error "Unable to move /etc/krb5.conf.tmp to /etc/krb5.conf" 1
}

create_kdc_database() {
  log DEBUG "Creating the KDC database"

#  echo "*** NOTICE NOTICE NOTICE ***"
#  echo "The KDC database this utility creates is for TESTING PURPOSES ONLY and"
#  echo "should, under no circumstances, be used in a production setting or any"
#  echo "situation where strong security is required. The master database"
#  echo "password used is not secure, nor is the database created in the most"
#  echo "secure manner. You have been warned."
#  echo "*** NOTICE NOTICE NOTICE ***"

  log INFO "Creating the KDC can take some time as it gathers random data. To"
  log INFO "help it along, generate some activity on the host (move the mouse,"
  log INFO "generate disk IO, etc.)."

  $KDB5_UTIL -P "$kdc_password" create -s >/dev/null ||
    error "Unable to create kerberos KDC database" 1
  log INFO "Successfully created kerberos KDC database"

  log DEBUG "Generating $cm_princ principal for Cloudera Manager"

  $KADMIN_LOCAL >/dev/null <<EOF
  addpol default
  addprinc -pw $cm_princ_password $cm_princ
EOF
  [ "$?" -eq 0 ] || error "Unable to generate and/or export $cm_princ principal" 1
}

configure_cm_files() {
  log DEBUG "Installing Cloudera Manager keytabs and configuration files"

  if [ -d "/etc/cloudera-scm-server" ] ; then
    $CHOWN cloudera-scm:cloudera-scm cmf.keytab ||
      error "Unable to install /etc/cloudera-scm-server/cmf.keytab" 1
    $CHMOD 0600 cmf.keytab ||
      error "Unable to install /etc/cloudera-scm-server/cmf.keytab" 1
    mv cmf.keytab /etc/cloudera-scm-server/cmf.keytab ||
      error "Unable to install /etc/cloudera-scm-server/cmf.keytab" 1

    $SED -e "s/@@kdc_realm@@/${kdc_realm}/g" "${tmpl_dir}/cmf.principal.tmpl" > /etc/cloudera-scm-server/cmf.principal.tmp ||
      error "Unable to generate /etc/cloudera-scm-server/cmf.principal.tmp file" 1
    $CHMOD 0600 /etc/cloudera-scm-server/cmf.principal.tmp ||
      error "Unable to install /etc/cloudera-scm-server/cmf.principal" 1
    $CHOWN cloudera-scm:cloudera-scm /etc/cloudera-scm-server/cmf.principal.tmp ||
      error "Unable to install /etc/cloudera-scm-server/cmf.principal" 1
    mv /etc/cloudera-scm-server/cmf.principal.tmp /etc/cloudera-scm-server/cmf.principal ||
      error "Unable to install /etc/cloudera-scm-server/cmf.principal" 1
  else
    log WARN "Skipping Cloudera Manager keytab configuration - /etc/cloudera-scm-server doesn't exist!"
    log WARN "Assuming Cloudera Manager is installed on another host. You should follow the instructions"
    log WARN "at http://www.cloudera.com/content/cloudera-content/cloudera-docs/CM4Ent/4.5.1/Configuring-Hadoop-Security-with-Cloudera-Manager/cmeechs_topic_4_5.html"
  fi
}

start_services() {
  log DEBUG "Starting KDC and KAdmin services"

  $CHKCONFIG krb5kdc on ||
    error "Failed to set krb5kdc to start on boot" 1
  $CHKCONFIG kadmin on ||
    error "Failed to set kadmin to start on boot" 1

  $SERVICE krb5kdc start ||
    error "Failed to start krb5kdc service" 1
  $SERVICE kadmin start ||
    error "Failed to start kadmin service" 1
  echo
}

initializing_principals(){
    log DEBUG "Creating several principals for a start: hdfs and testuser."
    echo "addprinc -pw hdfs123 hdfs" | kadmin.local
    echo "addprinc -pw testuser123 testuser" | kadmin.local
}

display_next_steps() {
  echo "*** NEXT ***"
  echo
  echo "Go to the Cloudera Manager console, click on gear icon in the upper right"
  echo "corner, \"Security\" on the left configuration navigation panel, and update"
  echo "the \"Kerberos Security Realm\" to be ${kdc_realm} and save the change."
  echo
  echo "See http://www.cloudera.com/content/cloudera-content/cloudera-docs/CM4Ent/4.5.1/Configuring-Hadoop-Security-with-Cloudera-Manager/cmeechs_topic_4_7.html"
  echo
  echo "Once complete, follow the remaining instructions to configure kerberos in"
  echo "the various Hadoop services described here:"
  echo "http://www.cloudera.com/content/cloudera-content/cloudera-docs/CM4Ent/4.5.1/Configuring-Hadoop-Security-with-Cloudera-Manager/cmeechs_topic_4_8.html"
  echo
  echo "To create kerberos principals for users, run 'kadmin.local' as root (or"
  echo "via sudo) and enter '?' for help."
  echo
}

display_next_steps2() {
  echo "*** NEXT ***"
  echo
  echo "KDC server is configured with realm \"${kdc_realm}\". "
  echo "Please do the following steps here to configure KDC with a cluster managed by"
  echo "Cloudera Manager:"
  echo "http://www.cloudera.com/content/cloudera/en/documentation/core/latest/topics/cm_sg_s4_kerb_wizard.html"
  echo 
  echo "Note that this utility installs the required packages only on the host on which"
  echo "this runs. If there are two or more servers in the cluster, install the client"
  echo "libraries on the other hosts:"
  echo
  echo "yum -y install krb5-workstation"
  echo
}

configure_environment
gather_passwords
prompt_for_safety
install_krb_packages
configure_kdc
configure_krb_client
create_kdc_database
#configure_cm_files
start_services
#initializing_principals
display_next_steps2
