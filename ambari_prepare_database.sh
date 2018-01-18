#!/bin/bash
# shellcheck disable=SC2034,SC2086,SC1091
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
#
##### START CONFIG ###################################################

AM_HOST='%'
PG_SCHEMA=ambarischema

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

# Function to print the help screen.
print_help () {
  echo "Usage:  $1 databaseType [options] databaseName databaseUser databasePassword"
  echo "        $1 [-H|--help]"
  echo "        $1 [-v|--version]"
  echo ""
  echo "Options:"
  echo "        --host <hostname>"
  echo "        --port <port>"
  echo "        --user <dbaUsername>"
  echo "        --password <dbaPassword>"
  echo "        [--ambari-host <hostname>]"
  echo ""
  echo "   ex.  $1 mysql -h dbhost -u dba -p dbapass --ambari-host \$(hostname) ambaridb ambariuser password"
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
  exit "$CODE"
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

DB_TYPE=$1
shift

# Process arguments.
while [[ $1 = -* ]]; do
  case $1 in
    -h|--host)
      shift
      DB_HOST=$1
      ;;
    -P|--port)
      shift
      DB_PORT=$1
      ;;
    -u|--user)
      shift
      ADMIN_USER=$1
      ;;
    -p|--password)
      shift
      ADMIN_PASSWD=$1
      export PGPASSWORD=$1
      ;;
    --ambari-host)
      shift
      AM_HOST=$1
      ;;
    -H|--help)
      print_help "$(basename "$0")"
      ;;
    -v|--version)
      echo "Create the Hortonworks Ambari database."
      exit 0
      ;;
    *)
      print_help "$(basename "$0")"
      ;;
  esac
  shift
done

case $DB_TYPE in
  mysql|postgresql|oracle)
    ;;
  -H|--help)
    print_help "$(basename "$0")"
    ;;
  -v|--version)
    echo "Create the Hortonworks Ambari database."
    exit 0
    ;;
  *)
    echo "ERROR: Database type is incorrect. Please use mysql, postgresql, or oracle."
    exit 10
    ;;
esac

DB_NAME=$1
if [ -z "$DB_NAME" ]; then
  echo "ERROR: Database name is required."
  exit 11
fi

DB_USER=$2
if [ -z "$DB_USER" ]; then
  echo "ERROR: Database username is required."
  exit 12
fi

DB_PASSWD=$3
if [ -z "$DB_PASSWD" ]; then
  echo "ERROR: Database password is required."
  exit 13
fi

# Check to see if we have the required parameters.
#if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWD" ]; then print_help "$(basename "$0")"; fi
if [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ] || [ -z "$ADMIN_USER" ] || [ -z "$ADMIN_PASSWD" ]; then print_help "$(basename "$0")"; fi

# Lets not bother continuing unless we have the privs to do something.
check_root

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# main
set -eo pipefail
echo "** Configuring Database..."
if [ "$DB_TYPE" == postgresql ]; then
  if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
    OPTS="--jdbc-driver=/usr/share/java/postgresql-jdbc.jar"
    if ! rpm -q postgresql >/dev/null 2>&1; then
      yum -y -e1 -d1 install postgresql
    fi
  elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
    OPTS="--jdbc-driver=/usr/share/java/postgresql.jar"
    if ! dpkg -l postgresql-client >/dev/null 2>&1; then
      export DEBIAN_FRONTEND=noninteractive
      apt-get -y -q install postgresql-client
    fi
  fi

  psql -h "$DB_HOST" -p "$DB_PORT" -U "$ADMIN_USER" -d postgres   -c "CREATE ROLE $DB_USER WITH LOGIN ENCRYPTED PASSWORD '$DB_PASSWD';"
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$ADMIN_USER" -d postgres   -c "CREATE DATABASE $DB_NAME WITH OWNER = $DB_USER;"
  #psql -h "$DB_HOST" -p "$DB_PORT" -U "$ADMIN_USER" -d postgres   -c "CREATE DATABASE $DB_NAME WITH OWNER = $DB_USER ENCODING = 'UTF8' TABLESPACE = pg_default LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8' CONNECTION LIMIT = -1;"
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$ADMIN_USER" -d postgres   -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$ADMIN_USER" -d "$DB_NAME" -c "CREATE SCHEMA $PG_SCHEMA AUTHORIZATION $DB_USER"
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$ADMIN_USER" -d "$DB_NAME" -c "ALTER SCHEMA $PG_SCHEMA OWNER TO $DB_USER"
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$ADMIN_USER" -d "$DB_NAME" -c "ALTER ROLE $DB_USER SET search_path to '$PG_SCHEMA', 'public';"
  export PGPASSWORD=$DB_PASSWD
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER"    -d "$DB_NAME" -c '\i /var/lib/ambari-server/resources/Ambari-DDL-Postgres-CREATE.sql;' 2>/dev/null

  OPTS="$OPTS --jdbc-db=postgres --database=postgres"
  OPTS="$OPTS --databasehost=$DB_HOST --databaseport=$DB_PORT --databaseusername=$DB_USER --databasepassword=$DB_PASSWD"
  OPTS="$OPTS --databasename=$DB_NAME --postgresschema=$PG_SCHEMA"
elif [ "$DB_TYPE" == mysql ]; then
  if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
    OPTS="--jdbc-driver=/usr/share/java/mysql-connector-java.jar"
    if [ "$OSREL" == 6 ]; then
      if ! rpm -q mysql >/dev/null 2>&1; then
        yum -y -e1 -d1 install mysql
      fi
    else
      if ! rpm -q mariadb >/dev/null 2>&1; then
        yum -y -e1 -d1 install mariadb
      fi
    fi
  elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
    OPTS="--jdbc-driver=/usr/share/java/mysql-connector-java.jar"
    if ! dpkg -l mysql-client >/dev/null 2>&1; then
      export DEBIAN_FRONTEND=noninteractive
      apt-get -y -q install mysql-client
    fi
  fi

  mysql -h "$DB_HOST" -P "$DB_PORT" -u "$ADMIN_USER" -p"${ADMIN_PASSWD}" -e "CREATE DATABASE $DB_NAME DEFAULT CHARACTER SET utf8;"
  mysql -h "$DB_HOST" -P "$DB_PORT" -u "$ADMIN_USER" -p"${ADMIN_PASSWD}" -e "GRANT ALL ON ${DB_NAME}.* TO '$DB_USER'@'$AM_HOST' IDENTIFIED BY '$DB_PASSWD';"
# mysql -h "$DB_HOST" -P "$DB_PORT" -u "$ADMIN_USER" -p"${ADMIN_PASSWD}" -D "$DB_NAME" -e 'SOURCE /var/lib/ambari-server/resources/Ambari-DDL-MySQL-CREATE.sql;'
  mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER"    -p"${DB_PASSWD}"    -D "$DB_NAME" -e 'SOURCE /var/lib/ambari-server/resources/Ambari-DDL-MySQL-CREATE.sql;'

  OPTS="$OPTS --jdbc-db=mysql --database=mysql"
  OPTS="$OPTS --databasehost=$DB_HOST --databaseport=$DB_PORT --databaseusername=$DB_USER --databasepassword=$DB_PASSWD"
  OPTS="$OPTS --databasename=$DB_NAME"
elif [ "$DB_TYPE" == oracle ]; then
  if [ -z "$DB_PORT" ]; then print_help "$(basename "$0")"; fi
  echo "WARNING: Oracle Support is not implemented."
  exit 20
  #/var/lib/ambari-server/resources/Ambari-DDL-Oracle-CREATE.sql
  OPTS="--jdbc-driver=/usr/share/java/oracle-connector-java.jar"

  OPTS="$OPTS --jdbc-db=oracle --database=oracle"
  OPTS="$OPTS --databasehost=$DB_HOST --databaseport=$DB_PORT --databaseusername=$DB_USER --databasepassword=$DB_PASSWD"
  OPTS="$OPTS --databasename=$DB_NAME --sidorsname=sid"
else
  echo "WARNING: You should not have gotten here."
fi

echo "** Configuring Ambari Server..."
if [ -f /etc/profile.d/java.sh ]; then
  . /etc/profile.d/java.sh
elif [ -f /etc/profile.d/jdk.sh ]; then
  . /etc/profile.d/jdk.sh
fi
ambari-server setup --java-home="$JAVA_HOME" $OPTS

