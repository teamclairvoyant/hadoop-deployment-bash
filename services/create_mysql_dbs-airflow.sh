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

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

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

# If the variable DEBUG is set, then turn on tracing.
# http://www.research.att.com/lists/ast-users/2003/05/msg00009.html
if [ $DEBUG ]; then
  # This will turn on the ksh xtrace option for mainline code
  set -x

  # This will turn on the ksh xtrace option for all functions
  typeset +f |
  while read F junk
  do
    typeset -ft $F
  done
  unset F junk
fi

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
      print_help "$(basename $0)"
      ;;
    -v|--version)
      echo "\tScript"
      echo "\tVersion: $VERSION"
      echo "\tWritten by: $AUTHOR"
      exit 0
      ;;
    *)
      print_help "$(basename $0)"
      ;;
  esac
  shift
done

# Check to see if we have no parameters.
#if [[ ! $# -eq 1 ]]; then print_help "$(basename $0)"; fi

# Lets not bother continuing unless we have the privs to do something.
#check_root

# main
if rpm -q redhat-lsb-core; then
  OSREL=`lsb_release -rs | awk -F. '{print $1}'`
else
  OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
fi
$ECHO sudo yum -y -e1 -d1 install epel-release
if [ $OSREL == 6 ]; then
  $ECHO sudo yum -y -e1 -d1 install mysql apg || exit 4
else
  $ECHO sudo yum -y -e1 -d1 install mariadb apg || exit 4
fi
AIRFLOWDB_PASSWORD=`apg -a 1 -M NCL -m 20 -x 20 -n 1`
$ECHO mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e 'CREATE DATABASE airflow DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;'
$ECHO mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e "GRANT ALL ON airflow.* TO 'airflow'@'%' IDENTIFIED BY '$AIRFLOWDB_PASSWORD';"
echo "airflow : $AIRFLOWDB_PASSWORD"

