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
if [ $DEBUG ]; then ECHO=echo; fi
#
##### START CONFIG ###################################################

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
# https://discourse.criticalengineering.org/t/howto-password-generation-in-the-gnu-linux-cli/10
PWCMD='< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo'

# Function to print the help screen.
print_help () {
  echo "Usage:  $1 --host <hostname> --user <username> --password <password>"
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

# Function to print and error message and exit.
err_msg () {
  local CODE=$1
  echo "ERROR: Could not install required package. Exiting."
  exit $CODE
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
#check_root

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# main
echo "Creating users and databases in MySQL for Director..."
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  $ECHO sudo yum -y -e1 -d1 install epel-release
  if ! rpm -q epel-release; then
    $ECHO sudo rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSREL}.noarch.rpm
  fi
  if [ "$OSREL" == 6 ]; then
    $ECHO sudo yum -y -e1 -d1 install mysql apg || err_msg 4
  else
    $ECHO sudo yum -y -e1 -d1 install mariadb apg || err_msg 4
  fi
  if rpm -q apg >/dev/null; then export PWCMD='apg -a 1 -M NCL -m 20 -x 20 -n 1'; fi
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  $ECHO sudo apt-get -y -q install mysql-client apg || err_msg 4
  if dpkg -l apg >/dev/null; then export PWCMD='apg -a 1 -M NCL -m 20 -x 20 -n 1'; fi
fi
DIRECTORDB_PASSWORD=$(eval $PWCMD)
echo "****************************************"
echo "****************************************"
echo "****************************************"
echo "*** SAVE THIS PASSWORD"
$ECHO mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e 'CREATE DATABASE director DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;'
$ECHO mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e "GRANT ALL ON director.* TO 'director'@'localhost' IDENTIFIED BY '$DIRECTORDB_PASSWORD';"
$ECHO mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e "GRANT ALL ON director.* TO 'director'@'%' IDENTIFIED BY '$DIRECTORDB_PASSWORD';"
echo "director : $DIRECTORDB_PASSWORD"
echo "****************************************"
echo "****************************************"
echo "****************************************"

