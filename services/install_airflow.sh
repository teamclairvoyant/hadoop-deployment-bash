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
if [ $DEBUG ]; then set -x; fi
if [ $DEBUG ]; then ECHO=echo; fi
#
##### START CONFIG ###################################################
#AIRFLOWUID="-u 999"
#AIRFLOWGID="-g 999"

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
PWCMD='< /dev/urandom tr -dc A-Za-z0-9 | head -c${1:-20};echo'
FILEPATH=`dirname $0`
#PIPOPTS="-q"
YUMOPTS="-y -e1 -d1"

# Function to print the help screen.
print_help () {
  echo "Usage:  $1 --mysqlhost <hostname> --mysqluser <username> --mysqlpassword <password> --rabbitmqhost <hostname>"
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

# Function to print and error message and exit.
err_msg () {
  local CODE=$1
  echo "ERROR: Could not install required package. Exiting."
  exit $CODE
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
    -m|--mysqlhost)
      shift
      MYSQL_HOST=$1
      ;;
    -r|--rabbitmqhost)
      shift
      RABBITMQ_HOST=$1
      ;;
    -u|--mysqluser)
      shift
      MYSQL_USER=$1
      ;;
    -p|--mysqlpassword)
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

# Check to see if we have the required parameters.
if [ -z "$MYSQL_HOST" -o -z "$MYSQL_USER" -o -z "$MYSQL_PASSWORD" -o -z "$RABBITMQ_HOST" ]; then print_help "$(basename $0)"; fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
if [ -n "$1" ]; then
  VERSION="==$1"
fi

if ! getent group airflow >/dev/null; then
  echo "** Installing airflow group."
  groupadd $AIRFLOWGID -r airflow
fi
if ! getent passwd airflow >/dev/null; then
  echo "** Installing airflow user."
  useradd $AIRFLOWUID -g airflow -c "Airflow Daemon" -m -d /var/lib/airflow -k /dev/null -r airflow
fi

echo "** Installing software dependencies via YUM."
yum $YUMOPTS groupinstall "Development tools"
yum $YUMOPTS install zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel python-devel wget cyrus-sasl-devel.x86_64

#echo "** Installing python pip."
#yum $YUMOPTS install epel-release
#yum $YUMOPTS install python-pip

echo "** Installing python setuptools."
#yum $YUMOPTS install python-setuptools
#easy_install pip
pushd /tmp
wget -q https://bootstrap.pypa.io/ez_setup.py
python ez_setup.py
popd
echo "** Installing python pip."
easy_install pip

echo "** Installing Airflow."
pip $PIPOPTS install airflow${VERSION}
pip $PIPOPTS install airflow[celery]

#####
echo "** Installing Airflow[mysql]."
yum $YUMOPTS install mysql-devel
pip $PIPOPTS install airflow[mysql]

#####
##yum $YUMOPTS install python-psycopg2
#yum $YUMOPTS install postgresql-devel
#pip $PIPOPTS install airflow[postgres]

#####
echo "** Installing Airflow[kerberos]."
pip $PIPOPTS install airflow[kerberos]
yum $YUMOPTS install libffi-devel
echo "** Installing Airflow[crypto]."
pip $PIPOPTS install airflow[crypto]
#pip $PIPOPTS install airflow[jdbc]
echo "** Installing Airflow[hive]."
pip $PIPOPTS install airflow[hive]
#pip $PIPOPTS install airflow[hdfs]
#pip $PIPOPTS install airflow[ldap]
pip $PIPOPTS install airflow[password]
echo "** Installing Airflow[rabbitmq]."
pip $PIPOPTS install airflow[rabbitmq]
#pip $PIPOPTS install airflow[s3]

echo "** Installing Airflow configs."
install -o root -g airflow -m0750 -d /var/lib/airflow
install -o root -g airflow -m0750 -d /var/lib/airflow/plugins
install -o root -g airflow -m0750 -d /var/lib/airflow/dags
install -o airflow -g airflow -m0750 -d /var/log/airflow
install -o root -g root -m0644 ${FILEPATH}/airflow/airflow.profile /etc/profile.d/airflow.sh
install -o root -g root -m0644 ${FILEPATH}/airflow/*.service /etc/systemd/system/
install -o root -g root -m0644 ${FILEPATH}/airflow/airflow /etc/sysconfig/airflow
install -o root -g root -m0644 ${FILEPATH}/airflow/airflow.conf /etc/tmpfiles.d/airflow.conf
install -o root -g root -m0644 ${FILEPATH}/airflow/airflow.cfg /var/lib/airflow/
install -o root -g root -m0644 ${FILEPATH}/airflow/unittests.cfg /var/lib/airflow/
install -o root -g root -m0644 ${FILEPATH}/airflow/airflow.logrotate /etc/logrotate.d/
install -o root -g root -m0755 ${FILEPATH}/airflow/mkuser.sh /tmp/mkuser.sh

systemd-tmpfiles --create --prefix=/run

CRYPTOKEY=`eval $PWCMD`
FERNETCRYPTOKEY=`python -c 'from cryptography.fernet import Fernet;key=Fernet.generate_key().decode();print key'`

sed -e "s|USERNAME|$MYSQL_USER|" \
    -e "s|PASSWORD|$MYSQL_PASSWORD|" \
    -e "s|MYSQLHOST|$MYSQL_HOST|" \
    -e "s|LOCALHOST|`hostname`|" \
    -e "s|RABBITMQHOST|$RABBITMQ_HOST|" \
    -e "s|temporary_key|$CRYPTOKEY|" \
    -e "s|cryptography_not_found_storing_passwords_in_plain_text|$FERNETCRYPTOKEY|" \
    -i /var/lib/airflow/airflow.cfg

echo "** Initializing Airflow database."
su - airflow -c 'airflow initdb'
su - airflow -c '/tmp/mkuser.sh'

echo "** Starting Airflow services."
service airflow-webserver start
service airflow-worker start
service airflow-kerberos start
service airflow-scheduler start
service airflow-flower start
chkconfig airflow-webserver on
chkconfig airflow-worker on
chkconfig airflow-kerberos on
chkconfig airflow-scheduler on
chkconfig airflow-flower on

