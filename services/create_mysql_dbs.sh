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
if [ -n "$DEBUG" ]; then ECHO="echo"; fi
#
##### START CONFIG ###################################################

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
# https://discourse.criticalengineering.org/t/howto-password-generation-in-the-gnu-linux-cli/10
PWCMD='< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo'

# Function to print the help screen.
print_help() {
  echo "Usage:  $1 --host <hostname> --user <username> --password <password>"
  echo "        $1 [-h|--help]"
  echo "        $1 [-v|--version]"
  echo "   ex.  $1 --host dbhost --user foo --password bar"
  exit 1
}

# Function to check for root privileges.
check_root() {
  if [[ $(/usr/bin/id | awk -F= '{print $2}' | awk -F"(" '{print $1}' 2>/dev/null) -ne 0 ]]; then
    echo "You must have root privileges to run this program."
    exit 2
  fi
}

# Function to print and error message and exit.
err_msg() {
  local CODE=$1
  echo "ERROR: Could not install required package. Exiting."
  exit "$CODE"
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
      echo "Create the Cloudera Manager users and databases in MySQL."
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
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != AlmaLinux ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# main
echo "Creating users and databases in MySQL for Reports Manager, Navigator Audit, Navigator Metadata, Hive, Oozie, Sentry, and Hue..."
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == AlmaLinux ]; then
  $ECHO sudo yum -y -e1 -d1 install epel-release
  if ! rpm -q epel-release; then
    $ECHO sudo rpm -Uvh "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSREL}.noarch.rpm"
  fi
  if [ "$OSREL" == 6 ]; then
    if ! rpm -q mysql; then
      $ECHO sudo yum -y -e1 -d1 install mysql apg || err_msg 4
    fi
  else
    if ! rpm -q mariadb; then
      $ECHO sudo yum -y -e1 -d1 install mariadb apg || err_msg 4
    fi
  fi
  if rpm -q apg; then
    export PWCMD='apg -a 1 -M NCL -m 20 -x 20 -n 1'
  fi
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  if dpkg -l mysql-client >/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    $ECHO sudo apt-get -y -q install mysql-client apg || err_msg 4
  fi
  if dpkg -l apg >/dev/null; then
    export PWCMD='apg -a 1 -M NCL -m 20 -x 20 -n 1'
  fi
fi
RMANDB_PASSWORD=$(eval "$PWCMD")
NAVDB_PASSWORD=$(eval "$PWCMD")
NAVMSDB_PASSWORD=$(eval "$PWCMD")
METASTOREDB_PASSWORD=$(eval "$PWCMD")
OOZIEDB_PASSWORD=$(eval "$PWCMD")
SENTRYDB_PASSWORD=$(eval "$PWCMD")
HUEDB_PASSWORD=$(eval "$PWCMD")
echo "****************************************"
echo "****************************************"
echo "****************************************"
echo "*** SAVE THESE PASSWORDS"
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e 'CREATE DATABASE rman DEFAULT CHARACTER SET utf8;'
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e "CREATE USER 'rman'@'%' IDENTIFIED BY '$RMANDB_PASSWORD';"
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e "GRANT ALL ON rman.* TO 'rman'@'%';"
echo "rman : $RMANDB_PASSWORD"
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e 'CREATE DATABASE nav DEFAULT CHARACTER SET utf8;'
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e "CREATE USER 'nav'@'%' IDENTIFIED BY '$NAVDB_PASSWORD';"
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e "GRANT ALL ON nav.* TO 'nav'@'%';"
echo "nav : $NAVDB_PASSWORD"
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e 'CREATE DATABASE navms DEFAULT CHARACTER SET utf8;'
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e "CREATE USER 'navms'@'%' IDENTIFIED BY '$NAVMSDB_PASSWORD';"
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e "GRANT ALL ON navms.* TO 'navms'@'%';"
echo "navms : $NAVMSDB_PASSWORD"
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e 'CREATE DATABASE metastore DEFAULT CHARACTER SET utf8;'
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e "CREATE USER 'hive'@'%' IDENTIFIED BY '$METASTOREDB_PASSWORD';"
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e "GRANT ALL ON metastore.* TO 'hive'@'%';"
echo "hive : $METASTOREDB_PASSWORD"
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e 'CREATE DATABASE oozie DEFAULT CHARACTER SET utf8;'
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e "CREATE USER 'oozie'@'%' IDENTIFIED BY '$OOZIEDB_PASSWORD';"
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e "GRANT ALL ON oozie.* TO 'oozie'@'%';"
echo "oozie : $OOZIEDB_PASSWORD"
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e 'CREATE DATABASE sentry DEFAULT CHARACTER SET utf8;'
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e "CREATE USER 'sentry'@'%' IDENTIFIED BY '$SENTRYDB_PASSWORD';"
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e "GRANT ALL ON sentry.* TO 'sentry'@'%';"
echo "sentry : $SENTRYDB_PASSWORD"
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e 'CREATE DATABASE hue DEFAULT CHARACTER SET utf8;'
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e "CREATE USER 'hue'@'%' IDENTIFIED BY '$HUEDB_PASSWORD';"
$ECHO mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"${MYSQL_PASSWORD}" -e "GRANT ALL ON hue.* TO 'hue'@'%';"
echo "hue : $HUEDB_PASSWORD"
echo "****************************************"
echo "****************************************"
echo "****************************************"

