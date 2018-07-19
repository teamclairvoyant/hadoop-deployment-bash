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
# Copyright Clairvoyant 2018
#
if [ $DEBUG ]; then set -x; fi
#
##### START CONFIG ###################################################

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
MYSQL_TLS=no

# Function to print the help screen.
print_help () {
  echo "Usage:  $1 --host <hostname> --user <username> --password <password> [--tls]"
  echo "        $1 [-h|--help]"
  echo "        $1 [-v|--version]"
  echo "   ex.  $1 --host dbhost --user foo --password bar"
  exit 1
}

# Function to check for root priviledges.
check_root () {
  if [[ $(/usr/bin/id | awk -F= '{print $2}' | awk -F"(" '{print $1}' 2>/dev/null) -ne 0 ]]; then
    echo "You must have root priviledges to run this program."
    exit 2
  fi
}

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=$(lsb_release -is)
    # 7.2.1511, 14.04
    OSVER=$(lsb_release -rs)
    # 7, 14
    OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    # trusty, wheezy, Final
    OSNAME=$(lsb_release -cs)
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=$(rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n")
      OSREL=$(rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}')
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
    -h|--host)
      shift
      MYSQL_HOST=$1
      ;;
    -u|--user)
      shift
      MYSQL_USER=$1
      ;;
    -p|--password)
      shift
      MYSQL_PASSWORD=$1
      ;;
    -t|--tls)
      MYSQL_TLS=yes
      ;;
    -H|--help)
      print_help "$(basename "$0")"
      ;;
    -v|--version)
      echo "Create the director user and database in MySQL."
      exit 0
      ;;
    *)
      print_help "$(basename "$0")"
      ;;
  esac
  shift
done

# Check to see if we have the required parameters.
if [ -z "$MYSQL_HOST" ] || [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASSWORD" ]; then print_help "$(basename "$0")"; fi

# Lets not bother continuing unless we have the privs to do something.
check_root

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# main
if [ "$MYSQL_TLS" == "yes" ]; then
  STRING='lp.database.url: jdbc:mysql://${lp.database.host}:${lp.database.port}/${lp.database.name}?verifyServerCertificate=true&useSSL=true&requireSSL=true'
else
  STRING=''
fi

echo "Configuring Cloudera Director to use MySQL..."
sed -e '/^# CLAIRVOYANT START$/,/^# CLAIRVOYANT END$/d' \
    -e "/lp.database.url:/a\\
# CLAIRVOYANT START\\
lp.database.type: mysql\\
lp.database.username: $MYSQL_USER\\
lp.database.password: $MYSQL_PASSWORD\\
lp.database.host: $MYSQL_HOST\\
lp.database.port: 3306\\
lp.database.name: director\\
$STRING\\
# CLAIRVOYANT END" \
    -i /etc/cloudera-director-server/application.properties
echo "Restarting Director..."
service cloudera-director-server restart

