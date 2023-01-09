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
# 1 - SCM server hostname - required
# 2 - SCM agent version - optional
_SCMVERSION=6.3.2

# Function to print the help screen.
print_help() {
  echo "Usage:  $1 <args> servername [version]"
  echo ""
  echo "        $1  -H|--scmserver    <hostname>"
  echo "        $1 [-V|--scmversion]  <CM version>"
  echo "        $1 [-u|--username]    <repo username>"
  echo "        $1 [-p|--password]    <repo password>"
  echo "        $1 [-h|--help]"
  echo "        $1 [-v|--version]"
  echo ""
  echo "   ex.  $1 --scmserver localhost.localdomain --scmversion 5.16.2"
  echo "   ex.  $1 -H cm.example.com -V 6.3.3 -u d542bc8c-0ebb-4f2c-8709-6f292ceedf4e -p 1234567890"
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
    -H|--scmserver)
      shift
      _SCMHOST=$1
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
      echo "Installs the Cloudera Manager Agent."
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
SCMHOST=${1:-$_SCMHOST}
if [ -z "$SCMHOST" ]; then
  echo "ERROR: Missing SCM hostname."
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

echo "Installing Cloudera Manager Agent..."
echo "CM server is: $SCMHOST"
echo "CM version is: $SCMVERSION"
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
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
      chmod 0640 /etc/yum.repos.d/cloudera-manager.repo
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
  yum -y -e1 -d1 install cloudera-manager-agent
  sed -i -e "/server_host/s|=.*|=${SCMHOST}|" /etc/cloudera-scm-agent/config.ini
  service cloudera-scm-agent start
  chkconfig cloudera-scm-agent on
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
  apt-get -y -q install cloudera-manager-agent
  sed -i -e "/server_host/s|=.*|=${SCMHOST}|" /etc/cloudera-scm-agent/config.ini
  service cloudera-scm-agent start
  update-rc.d cloudera-scm-agent defaults
  update-rc.d apache2 disable
  service apache2 stop
fi

