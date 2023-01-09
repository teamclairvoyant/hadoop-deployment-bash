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
if [ -n "$DEBUG" ]; then set -x; fi
if [ -n "$DEBUG" ]; then ECHO="echo"; fi
#
##### START CONFIG ###################################################

PG_PORT=5432

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
# https://discourse.criticalengineering.org/t/howto-password-generation-in-the-gnu-linux-cli/10
PWCMD='< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo'

# Function to print the help screen.
print_help() {
  echo "Usage:  $1 --host <hostname> [--port <port>] --user <username> --password <password>"
  echo "        $1 [-h|--help]"
  echo "        $1 [-v|--version]"
  echo ""
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
      PG_HOST=$1
      ;;
    -P|--port)
      shift
      PG_PORT=$1
      ;;
    -u|--user)
      shift
      PG_USER=$1
      ;;
    -p|--password)
      shift
      export PGPASSWORD=$1
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
if [ -z "$PG_HOST" ] || [ -z "$PG_USER" ] || [ -z "$PGPASSWORD" ]; then print_help "$(basename "$0")"; fi

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
echo "Creating users and databases in PostgreSQL for Reports Manager, Navigator Audit, Navigator Metadata, Hive, Oozie, Sentry, and Hue..."
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ] || [ "$OS" == AlmaLinux ]; then
  $ECHO sudo yum -y -e1 -d1 install epel-release
  if ! rpm -q epel-release; then
    $ECHO sudo rpm -Uvh "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSREL}.noarch.rpm"
  fi
  $ECHO sudo yum -y -e1 -d1 install postgresql apg || err_msg 4
  if rpm -q apg; then export PWCMD='apg -a 1 -M NCL -m 20 -x 20 -n 1'; fi
echo "hue : $HUEDB_PASSWORD"
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  $ECHO sudo apt-get -y -q install postgresql-client apg || err_msg 4
  if dpkg -l apg >/dev/null; then export PWCMD='apg -a 1 -M NCL -m 20 -x 20 -n 1'; fi
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
$ECHO psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -c "CREATE ROLE rman LOGIN ENCRYPTED PASSWORD '$RMANDB_PASSWORD' NOSUPERUSER INHERIT CREATEDB NOCREATEROLE;"
$ECHO psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -c "CREATE DATABASE rman WITH OWNER = rman ENCODING = 'UTF8' TABLESPACE = pg_default LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' CONNECTION LIMIT = -1;"
echo "rman : $RMANDB_PASSWORD"
$ECHO psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -c "CREATE ROLE nav LOGIN ENCRYPTED PASSWORD '$NAVDB_PASSWORD' NOSUPERUSER INHERIT CREATEDB NOCREATEROLE;"
$ECHO psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -c "CREATE DATABASE nav WITH OWNER = nav ENCODING = 'UTF8' TABLESPACE = pg_default LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' CONNECTION LIMIT = -1;"
echo "nav : $NAVDB_PASSWORD"
$ECHO psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -c "CREATE ROLE navms LOGIN ENCRYPTED PASSWORD '$NAVMSDB_PASSWORD' NOSUPERUSER INHERIT CREATEDB NOCREATEROLE;"
$ECHO psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -c "CREATE DATABASE navms WITH OWNER = navms ENCODING = 'UTF8' TABLESPACE = pg_default LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' CONNECTION LIMIT = -1;"
echo "navms : $NAVMSDB_PASSWORD"
$ECHO psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -c "CREATE ROLE hive LOGIN ENCRYPTED PASSWORD '$METASTOREDB_PASSWORD' NOSUPERUSER INHERIT CREATEDB NOCREATEROLE;"
$ECHO psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -c "CREATE DATABASE metastore WITH OWNER = hive ENCODING = 'UTF8' TABLESPACE = pg_default LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' CONNECTION LIMIT = -1;"
echo "hive : $METASTOREDB_PASSWORD"
$ECHO psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -c "CREATE ROLE oozie LOGIN ENCRYPTED PASSWORD '$OOZIEDB_PASSWORD' NOSUPERUSER INHERIT CREATEDB NOCREATEROLE;"
$ECHO psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -c "CREATE DATABASE oozie WITH OWNER = oozie ENCODING = 'UTF8' TABLESPACE = pg_default LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' CONNECTION LIMIT = -1;"
echo "oozie : $OOZIEDB_PASSWORD"
$ECHO psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -c "CREATE ROLE sentry LOGIN ENCRYPTED PASSWORD '$SENTRYDB_PASSWORD' NOSUPERUSER INHERIT CREATEDB NOCREATEROLE;"
$ECHO psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -c "CREATE DATABASE sentry WITH OWNER = sentry ENCODING = 'UTF8' TABLESPACE = pg_default LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' CONNECTION LIMIT = -1;"
echo "sentry : $SENTRYDB_PASSWORD"
$ECHO psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -c "CREATE ROLE hue LOGIN ENCRYPTED PASSWORD '$HUEDB_PASSWORD' NOSUPERUSER INHERIT CREATEDB NOCREATEROLE;"
$ECHO psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -c "CREATE DATABASE hue WITH OWNER = hue ENCODING = 'UTF8' TABLESPACE = pg_default LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' CONNECTION LIMIT = -1;"
echo "hue : $HUEDB_PASSWORD"
echo "****************************************"
echo "****************************************"
echo "****************************************"

