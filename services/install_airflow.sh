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
# Copyright Clairvoyant 2016
#
if [ -n "$DEBUG" ]; then set -x; fi
#
##### START CONFIG ###################################################
#AIRFLOWUID="-u 999"
#AIRFLOWGID="-g 999"

MYSQL_PORT=3306
PGSQL_PORT=5432

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
FILEPATH=$(dirname "$0")
PWCMD='< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo'
#PIPOPTS="-q"

# Function to print the help screen.
print_help() {
  echo "Usage:  $1 <args>"
  echo ""
  echo "          -t|--dbtype        <mysql|postgresql>"
  echo "          -d|--dbhost        <hostname>"
  echo "          [-P|--dbport       <port>]"
  echo "          -u|--dbuser        <username>"
  echo "          -p|--dbpassword    <password>"
  echo "          -r|--rabbitmqhost  <hostname>"
  echo "          [airflow version]"
  echo "          [-h|--help]"
  echo "          [-v|--version]"
  echo ""
  echo "   ex.  $1 --dbtype postgresql --dbhost hostA --dbuser airflow --dbpassword bar --rabbitmqhost hostB"
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
    -t|--dbtype)
      shift
      DB_TYPE=$1
      ;;
    -d|--dbhost)
      shift
      DB_HOST=$1
      ;;
    -r|--rabbitmqhost)
      shift
      RABBITMQ_HOST=$1
      ;;
    -u|--dbuser)
      shift
      DB_USER=$1
      ;;
    -p|--dbpassword)
      shift
      DB_PASSWORD=$1
      ;;
    -P|--dbport)
      shift
      DB_PORT=$1
      ;;
    -h|--help)
      print_help "$(basename "$0")"
      ;;
    -v|--version)
      echo "Install Airflow."
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
# Currently only EL7.
discover_os
if { [ "$OS" != RedHatEnterpriseServer ] || [ "$OS" != CentOS ]; } && [ "$OSREL" != 7 ]; then
#if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# Check to see if we have the required parameters.
if [ -z "$DB_TYPE" ] || [ -z "$DB_HOST" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ] || [ -z "$RABBITMQ_HOST" ]; then print_help "$(basename "$0")"; fi
if [ "$DB_TYPE" != "mysql" ] && [ "$DB_TYPE" != "postgresql" ]; then
  echo "** ERROR: --dbtype must be one of mysql or postgresql."
  echo ""
  print_help "$(basename "$0")"
fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
echo "Installing Airflow..."
if [ -n "$1" ]; then
  VERSION="==$1"
fi

if ! getent group airflow >/dev/null; then
  echo "** Installing airflow group."
  groupadd "$AIRFLOWGID" -r airflow
fi
if ! getent passwd airflow >/dev/null; then
  echo "** Installing airflow user."
  useradd "$AIRFLOWUID" -g airflow -c "Airflow Daemon" -m -d /var/lib/airflow -k /dev/null -r airflow
fi

if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  echo "** Installing software dependencies via YUM."
  yum -y -e1 -d1 groupinstall "Development tools"
  yum -y -e1 -d1 install zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel python-devel wget cyrus-sasl-devel.x86_64

  #echo "** Installing python pip."
  #yum -y -e1 -d1 install epel-release
  #if ! rpm -q epel-release; then
  #  rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSREL}.noarch.rpm
  #fi
  #yum -y -e1 -d1 install python-pip

  #echo "** Installing python setuptools."
  #yum -y -e1 -d1 install python-setuptools
  #easy_install pip

  echo "** Installing python easy_install."
  cd /tmp || exit
  wget -q https://bootstrap.pypa.io/ez_setup.py
  python ez_setup.py
  if [ ! -f /usr/bin/pip ]; then
    echo "** Installing python pip."
    easy_install pip || \
    ( yum -y -e1 -d1 reinstall python-setuptools && \
    easy_install pip )
  fi

  echo "** Installing Airflow."
  pip "$PIPOPTS" install apache-airflow"${VERSION}"
  pip "$PIPOPTS" install 'apache-airflow[celery]'

  if [ "$DB_TYPE" == "mysql" ]; then
    if [ -z "$DB_PORT" ]; then DB_PORT=$MYSQL_PORT; fi
    #####
    echo "** Installing Airflow[mysql]."
    yum -y -e1 -d1 install mysql-devel
    pip "$PIPOPTS" install 'apache-airflow[mysql]'
    DBCONNSTRING="mysql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/airflow"

  elif [ "$DB_TYPE" == "postgresql" ]; then
    if [ -z "$DB_PORT" ]; then DB_PORT=$PGSQL_PORT; fi
    #####
    echo "** Installing Airflow[postgres]."
    yum -y -e1 -d1 install postgresql-devel
    pip "$PIPOPTS" install 'apache-airflow[postgres]'
    DBCONNSTRING="postgresql+psycopg2://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/airflow"
  fi

  #####
  echo "** Installing Airflow[kerberos]."
  pip "$PIPOPTS" install 'apache-airflow[kerberos]'
  yum -y -e1 -d1 install libffi-devel
  echo "** Installing Airflow[crypto]."
  pip "$PIPOPTS" install 'apache-airflow[crypto]'
  #pip "$PIPOPTS" install 'apache-airflow[jdbc]'
  echo "** Installing Airflow[hive]."
  pip "$PIPOPTS" install 'apache-airflow[hive]'
  #pip "$PIPOPTS" install 'apache-airflow[hdfs]'
  #pip "$PIPOPTS" install 'apache-airflow[ldap]'
  pip "$PIPOPTS" install 'apache-airflow[password]'
  echo "** Installing Airflow[rabbitmq]."
  pip "$PIPOPTS" install 'apache-airflow[rabbitmq]'
  #pip "$PIPOPTS" install 'apache-airflow[s3]'

  echo "** Installing Airflow configs."
  install -o root -g airflow -m0750 -d /var/lib/airflow
  install -o root -g airflow -m0750 -d /var/lib/airflow/plugins
  install -o root -g airflow -m0750 -d /var/lib/airflow/dags
  install -o airflow -g airflow -m0750 -d /var/log/airflow
  install -o root -g root -m0644 "${FILEPATH}"/airflow/airflow.profile /etc/profile.d/airflow.sh
  install -o root -g root -m0644 "${FILEPATH}"/airflow/*.service /etc/systemd/system/
  install -o root -g root -m0644 "${FILEPATH}"/airflow/airflow /etc/sysconfig/airflow
  install -o root -g root -m0644 "${FILEPATH}"/airflow/airflow.conf /etc/tmpfiles.d/airflow.conf
  install -o root -g root -m0644 "${FILEPATH}"/airflow/airflow.cfg /var/lib/airflow/
  install -o root -g root -m0644 "${FILEPATH}"/airflow/unittests.cfg /var/lib/airflow/
  install -o root -g root -m0644 "${FILEPATH}"/airflow/airflow.logrotate /etc/logrotate.d/
  install -o root -g root -m0755 "${FILEPATH}"/airflow/mkuser.py /tmp/mkuser.py

  systemd-tmpfiles --create --prefix=/run

  CRYPTOKEY=$(eval "$PWCMD")
  FERNETCRYPTOKEY=$(python -c 'from cryptography.fernet import Fernet;key=Fernet.generate_key().decode();print key')

  sed -e "s|RABBITMQHOST|$RABBITMQ_HOST|" \
      -e "s|LOCALHOST|$(hostname)|" \
      -e "s|DBCONNSTRING|$DBCONNSTRING|" \
      -e "s|temporary_key|$CRYPTOKEY|" \
      -e "s|cryptography_not_found_storing_passwords_in_plain_text|$FERNETCRYPTOKEY|" \
      -i /var/lib/airflow/airflow.cfg

  echo "** Initializing Airflow database."
  su - airflow -c 'airflow initdb'
  su - airflow -c '/tmp/mkuser.py'

  echo "** Starting Airflow services."
  service airflow-webserver start
  service airflow-worker start
  #service airflow-kerberos start
  service airflow-scheduler start
  service airflow-flower start
  chkconfig airflow-webserver on
  chkconfig airflow-worker on
  #chkconfig airflow-kerberos on
  chkconfig airflow-scheduler on
  chkconfig airflow-flower on
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  :
fi

