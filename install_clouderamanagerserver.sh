#!/bin/bash
# shellcheck disable=SC1090
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
#
##### START CONFIG ###################################################

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

# ARGV:
# 1 - SCM server database type : embedded, postgresql, mysql, or oracle - optional
# 2 - SCM server version - optional
_INSTALLDB=embedded
_SCMVERSION=6.3.2

# Function to print the help screen.
print_help() {
  echo "Usage:  $1 <args> database_type [version]"
  echo ""
  echo "        $1  -d|--db_type      <embedded|mysql|postgresql|oracle>"
  echo "        $1 [-V|--scmversion]  <CM version>"
  echo "        $1 [-u|--username]    <repo username>"
  echo "        $1 [-p|--password]    <repo password>"
  echo "        $1 [-h|--help]"
  echo "        $1 [-v|--version]"
  echo ""
  echo "   ex.  $1 --db_type embedded --scmversion 5.16.2"
  echo "   ex.  $1 -d mysql -V 6.3.3 -u d542bc8c-0ebb-4f2c-8709-6f292ceedf4e -p 1234567890"
  exit 1
}

# Function to check for root privileges.
check_root() {
  if [[ $(/usr/bin/id | awk -F= '{print $2}' | awk -F"(" '{print $1}' 2>/dev/null) -ne 0 ]]; then
    echo "You must have root privileges to run this program."
    exit 2
  fi
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
      if [ -f /etc/centos-release ]; then
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

_install_oracle_jdbc() {
  cd "$(dirname "$0")" || exit
  if [ ! -f ojdbc6.jar ] && [ ! -f ojdbc8.jar ]; then
    echo "** NOTICE: ojdbc6.jar or ojdbc8.jar not found.  Please manually download from"
    echo "   http://www.oracle.com/technetwork/database/enterprise-edition/jdbc-112010-090769.html"
    echo "   or"
    echo "   http://www.oracle.com/technetwork/database/features/jdbc/jdbc-ucp-122-3110062.html"
    echo "   and place in the same directory as this script."
    exit 1
  fi
  if [ ! -d /usr/share/java ]; then
    install -o root -g root -m 0755 -d /usr/share/java
  fi
  if [ -f ojdbc6.jar ]; then
    cp -p ojdbc6.jar /tmp/ojdbc6.jar
    install -o root -g root -m 0644 /tmp/ojdbc6.jar /usr/share/java/
    ln -sf ojdbc6.jar /usr/share/java/oracle-connector-java.jar
    ls -l /usr/share/java/ojdbc6.jar
  fi
  if [ -f ojdbc8.jar ]; then
    cp -p ojdbc8.jar /tmp/ojdbc8.jar
    install -o root -g root -m 0644 /tmp/ojdbc8.jar /usr/share/java/
    ln -sf ojdbc8.jar /usr/share/java/oracle-connector-java.jar
    ls -l /usr/share/java/ojdbc8.jar
  fi
  ls -l /usr/share/java/oracle-connector-java.jar
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
    -d|--db_type)
      shift
      _INSTALLDB=$1
      ;;
    -V|--scmversion)
      shift
      _SCMVERSION=$1
      ;;
    -u|--username)
      shift
      _REPO_USER=$1
      ;;
    -p|--password)
      shift
      _REPO_PASSWD=$1
      ;;
    -h|--help)
      print_help "$(basename "$0")"
      ;;
    -v|--version)
      echo "Installs the Cloudera Manager Server."
      exit 0
      ;;
    *)
      print_help "$(basename "$0")"
      ;;
  esac
  shift
done

echo "********************************************************************************"
echo "*** $(basename "$0") $*"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# Check to see if we have the required parameters.
INSTALLDB=${1:-$_INSTALLDB}
if [ "$INSTALLDB" != "embedded" ] && [ "$INSTALLDB" != "mysql" ] && [ "$INSTALLDB" != "postgresql" ] && [ "$INSTALLDB" != "oracle" ]; then
  echo "ERROR: --db_type must be one of embedded, mysql, postgresql, or oracle."
  echo ""
  print_help "$(basename "$0")"
fi
SCMVERSION=${2:-$_SCMVERSION}
SCMVERSION_MAJ=$(echo "${SCMVERSION}" | awk -F. '{print $1}')
SCMVERSION_MIN=$(echo "${SCMVERSION}" | awk -F. '{print $2}')
SCMVERSION_PATCH=$(echo "${SCMVERSION}" | awk -F. '{print $3}')
if { [ "$SCMVERSION_MAJ" -eq 6 ] && [ "$SCMVERSION_MIN" -eq 3 ] && [ "$SCMVERSION_PATCH" -ge 3 ]; } || { [ "$SCMVERSION_MAJ" -eq 6 ] && [ "$SCMVERSION_MIN" -ge 4 ]; } || { [ "$SCMVERSION_MAJ" -eq 7 ]; }; then
  if [ -z "$_REPO_USER" ] || [ -z "$_REPO_PASSWD" ]; then
    echo "ERROR: Missing username and/or password for software repository."
    echo ""
    print_help "$(basename "$0")"
  fi
fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
PROXY=$(grep -Eh '^ *http_proxy=http|^ *https_proxy=http' /etc/profile.d/*)
eval "$PROXY"
export http_proxy
export https_proxy
if [ -z "$http_proxy" ]; then
  PROXY=$(grep -El 'http_proxy=|https_proxy=' /etc/profile.d/*)
  if [ -n "$PROXY" ]; then
    . "$PROXY"
  fi
fi

echo "Installing Cloudera Manager Server..."
echo "CM database is: $INSTALLDB"
echo "CM version is: $SCMVERSION"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  # Test to see if JDK 6 is present.
  if rpm -q jdk >/dev/null; then
    HAS_JDK=yes
  else
    HAS_JDK=no
  fi
  # Because it may have been put there by some other process.
  if [ ! -f /etc/yum.repos.d/cloudera-manager.repo ]; then
    # Require username/password for 6.3.3 and newer.
    if [ "$SCMVERSION_MAJ" -eq 7 ]; then
      wget -q "https://${_REPO_USER}:${_REPO_PASSWD}@archive.cloudera.com/p/cm7/${SCMVERSION}/redhat${OSREL}/yum/cloudera-manager.repo" -O /etc/yum.repos.d/cloudera-manager.repo
      RETVAL=$?
      if [ "$RETVAL" -ne 0 ]; then
        echo "** ERROR: Could not download https://${_REPO_USER}:${_REPO_PASSWD}@archive.cloudera.com/p/cm7/${SCMVERSION}/redhat${OSREL}/yum/cloudera-manager.repo"
        exit 8
      fi
      chown root:root /etc/yum.repos.d/cloudera-manager.repo
      chmod 0640 /etc/yum.repos.d/cloudera-manager.repo
      sed -e "s|^username=.*|username=${_REPO_USER}|" \
          -e "s|^password=.*|password=${_REPO_PASSWD}|" \
          -i /etc/yum.repos.d/cloudera-manager.repo
    elif { [ "$SCMVERSION_MAJ" -eq 6 ] && [ "$SCMVERSION_MIN" -eq 3 ] && [ "$SCMVERSION_PATCH" -ge 3 ]; } || { [ "$SCMVERSION_MAJ" -eq 6 ] && [ "$SCMVERSION_MIN" -ge 4 ]; }; then
      wget -q "https://${_REPO_USER}:${_REPO_PASSWD}@archive.cloudera.com/p/cm6/${SCMVERSION}/redhat${OSREL}/yum/cloudera-manager.repo" -O /etc/yum.repos.d/cloudera-manager.repo
      RETVAL=$?
      if [ "$RETVAL" -ne 0 ]; then
        echo "** ERROR: Could not download https://${_REPO_USER}:${_REPO_PASSWD}@archive.cloudera.com/p/cm6/${SCMVERSION}/redhat${OSREL}/yum/cloudera-manager.repo"
        exit 8
      fi
      chown root:root /etc/yum.repos.d/cloudera-manager.repo
      chmod 0644 /etc/yum.repos.d/cloudera-manager.repo
      sed -e "s|//archive.cloudera.com|//${_REPO_USER}:${_REPO_PASSWD}@archive.cloudera.com|" \
          -e 's|archive.cloudera.com/cm|archive.cloudera.com/p/cm|' \
          -e 's|http:|https:|' \
          -i /etc/yum.repos.d/cloudera-manager.repo
    elif [ "$SCMVERSION_MAJ" -eq 6 ]; then
      wget -q "https://archive.cloudera.com/cm6/${SCMVERSION}/redhat${OSREL}/yum/cloudera-manager.repo" -O /etc/yum.repos.d/cloudera-manager.repo
      RETVAL=$?
      if [ "$RETVAL" -ne 0 ]; then
        echo "** ERROR: Could not download https://archive.cloudera.com/cm6/${SCMVERSION}/redhat${OSREL}/yum/cloudera-manager.repo"
        exit 6
      fi
      chown root:root /etc/yum.repos.d/cloudera-manager.repo
      chmod 0644 /etc/yum.repos.d/cloudera-manager.repo
    elif [ "$SCMVERSION_MAJ" -eq 5 ]; then
      wget -q "https://archive.cloudera.com/cm5/redhat/${OSREL}/x86_64/cm/cloudera-manager.repo" -O /etc/yum.repos.d/cloudera-manager.repo
      RETVAL=$?
      if [ "$RETVAL" -ne 0 ]; then
        echo "** ERROR: Could not download https://archive.cloudera.com/cm5/redhat/${OSREL}/x86_64/cm/cloudera-manager.repo"
        exit 4
      fi
      chown root:root /etc/yum.repos.d/cloudera-manager.repo
      chmod 0644 /etc/yum.repos.d/cloudera-manager.repo
      if [ -n "$SCMVERSION" ]; then
        sed -e "s|/cm/5/|/cm/${SCMVERSION}/|" -i /etc/yum.repos.d/cloudera-manager.repo
      fi
    else
      echo "ERROR: $SCMVERSION_MAJ is not supported."
      exit 10
    fi
  fi
  if [ "$INSTALLDB" == embedded ]; then
    yum -y -e1 -d1 install cloudera-manager-server-db-2
    service cloudera-scm-server-db start
    chkconfig cloudera-scm-server-db on
  fi
  yum -y -e1 -d1 install cloudera-manager-server openldap-clients
  if [ "$INSTALLDB" == embedded ]; then
    service cloudera-scm-server start
    chkconfig cloudera-scm-server on
  else
    if [ "$INSTALLDB" == mysql ]; then
      yum -y -e1 -d1 install mysql-connector-java
      # Removes JDK 6 if it snuck onto the system. Tests for the actual RPM
      # named "jdk" to keep virtual packages from causing a JDK 8 uninstall.
      if [ "$HAS_JDK" == no ] && rpm -q jdk >/dev/null; then yum -y -e1 -d1 remove jdk; fi
    elif [ "$INSTALLDB" == postgresql ]; then
      yum -y -e1 -d1 install postgresql-jdbc
    elif [ "$INSTALLDB" == oracle ]; then
      _install_oracle_jdbc
    else
      echo "** ERROR: Argument must be either embedded, mysql, postgresql, or oracle."
    fi
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "** Now you must configure the Cloudera Manager server to connect to the external"
    echo "** database.  Please run:"
    if [ "$SCMVERSION_MAJ" -ge 6 ]; then
      echo "/opt/cloudera/cm/schema/scm_prepare_database.sh"
    else
      echo "/usr/share/cmf/schema/scm_prepare_database.sh"
    fi
    echo "** and then:"
    echo "service cloudera-scm-server start"
    echo "chkconfig cloudera-scm-server on"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
  fi
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  # Because it may have been put there by some other process.
  if [ ! -f /etc/apt/sources.list.d/cloudera-manager.list ]; then
    if [ "$OS" == Debian ]; then
      OS_LOWER=debian
    elif [ "$OS" == Ubuntu ]; then
      OS_LOWER=ubuntu
    fi
    # Require username/password for 6.3.3 and newer.
    if { [ "$SCMVERSION_MAJ" -eq 6 ] && [ "$SCMVERSION_MIN" -eq 3 ] && [ "$SCMVERSION_PATCH" -ge 3 ]; } || { [ "$SCMVERSION_MAJ" -eq 6 ] && [ "$SCMVERSION_MIN" -ge 4 ]; }; then
      OSVER_NUMERIC=${OSVER//./}
      wget -q "https://${_REPO_USER}:${_REPO_PASSWD}@archive.cloudera.com/p/cm6/${SCMVERSION}/${OS_LOWER}${OSVER_NUMERIC}/apt/cloudera-manager.list" -O /etc/apt/sources.list.d/cloudera-manager.list
      RETVAL=$?
      if [ "$RETVAL" -ne 0 ]; then
        echo "** ERROR: Could not download https://${_REPO_USER}:${_REPO_PASSWD}@archive.cloudera.com/p/cm6/${SCMVERSION}/${OS_LOWER}${OSVER_NUMERIC}/apt/cloudera-manager.list"
        exit 9
      fi
      chown root:root /etc/apt/sources.list.d/cloudera-manager.list
      chmod 0644 /etc/apt/sources.list.d/cloudera-manager.list
      sed -e "s|//archive.cloudera.com|//${_REPO_USER}:${_REPO_PASSWD}@archive.cloudera.com|" \
          -e 's|archive.cloudera.com/cm|archive.cloudera.com/p/cm|' \
          -e 's|http:|https:|' \
          -i /etc/apt/sources.list.d/cloudera-manager.list
      curl -s "https://${_REPO_USER}:${_REPO_PASSWD}@archive.cloudera.com/p/cm6/${SCMVERSION}/${OS_LOWER}${OSVER_NUMERIC}/apt/archive.key" | apt-key add -
    elif [ "$SCMVERSION_MAJ" -eq 6 ]; then
      OSVER_NUMERIC=${OSVER//./}
      wget -q "https://archive.cloudera.com/cm6/${SCMVERSION}/${OS_LOWER}${OSVER_NUMERIC}/apt/cloudera-manager.list" -O /etc/apt/sources.list.d/cloudera-manager.list
      RETVAL=$?
      if [ "$RETVAL" -ne 0 ]; then
        echo "** ERROR: Could not download https://archive.cloudera.com/cm6/${SCMVERSION}/${OS_LOWER}${OSVER_NUMERIC}/apt/cloudera-manager.list"
        exit 7
      fi
      chown root:root /etc/apt/sources.list.d/cloudera-manager.list
      chmod 0644 /etc/apt/sources.list.d/cloudera-manager.list
      curl -s "https://archive.cloudera.com/cm6/${SCMVERSION}/${OS_LOWER}${OSVER_NUMERIC}/apt/archive.key" | apt-key add -
    elif [ "$SCMVERSION_MAJ" -eq 5 ]; then
      wget -q "https://archive.cloudera.com/cm5/${OS_LOWER}/${OSNAME}/amd64/cm/cloudera.list" -O /etc/apt/sources.list.d/cloudera-manager.list
      RETVAL=$?
      if [ "$RETVAL" -ne 0 ]; then
        echo "** ERROR: Could not download https://archive.cloudera.com/cm5/${OS_LOWER}/${OSNAME}/amd64/cm/cloudera.list"
        exit 5
      fi
      chown root:root /etc/apt/sources.list.d/cloudera-manager.list
      chmod 0644 /etc/apt/sources.list.d/cloudera-manager.list
      if [ -n "$SCMVERSION" ]; then
        sed -e "s|-cm5 |-cm${SCMVERSION} |" -i /etc/apt/sources.list.d/cloudera-manager.list
      fi
      curl -s "http://archive.cloudera.com/cm5/${OS_LOWER}/${OSNAME}/amd64/cm/archive.key" | apt-key add -
    else
      echo "ERROR: $SCMVERSION_MAJ is not supported."
      exit 11
    fi
  fi
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y -qq update
  if [ "$INSTALLDB" == embedded ]; then
    apt-get -y -q install cloudera-manager-server-db-2
    service cloudera-scm-server-db start
    update-rc.d cloudera-scm-server-db defaults
  fi
  apt-get -y -q install cloudera-manager-server ldap-utils
  update-rc.d apache2 disable
  service apache2 stop
  if [ "$INSTALLDB" == embedded ]; then
    service cloudera-scm-server start
    update-rc.d cloudera-scm-server defaults
  else
    if [ "$INSTALLDB" == mysql ]; then
      apt-get -y -q install libmysql-java
    elif [ "$INSTALLDB" == postgresql ]; then
      apt-get -y -q install libpostgresql-jdbc-java
    elif [ "$INSTALLDB" == oracle ]; then
      _install_oracle_jdbc
    else
      echo "** ERROR: Argument must be either embedded, mysql, or postgresql, or oracle."
    fi
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
    echo "** Now you must configure the Cloudera Manager server to connect to the external"
    echo "** database.  Please run:"
    if [ "$SCMVERSION_MAJ" -ge 6 ]; then
      echo "/opt/cloudera/cm/schema/scm_prepare_database.sh"
    else
      echo "/usr/share/cmf/schema/scm_prepare_database.sh"
    fi
    echo "** and then:"
    echo "service cloudera-scm-server start"
    echo "update-rc.d cloudera-scm-server-db defaults"
    echo "****************************************"
    echo "****************************************"
    echo "****************************************"
  fi
fi

