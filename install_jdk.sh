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

# ARGV:
# 1 - Which major JDK version to install. If empty, install JDK 7 from Cloudera. - optional
# 2 - SCM version - optional

# Note:
# If you do not want to download the JDK multiple times or access to
# download.oracle.com is blocked, you can place the manually downloaded JDK RPM
# in the /tmp directory for RedHat-based systems or the JDK tarball in
# /var/cache/oracle-jdk8-installer for Debian-based systems.
#
if [ -n "$DEBUG" ]; then set -x; fi
#
##### START CONFIG ###################################################

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
JDK_TYPE=cloudera
JDK_VERSION=7

# Function to print the help screen.
print_help() {
  echo "Usage:  $1 <args>"
  echo ""
  echo "        $1 -t|--jdktype       <cloudera|oracle|openjdk>"
  echo "        $1 [-j|--jdkversion]  <version>"
  echo "        $1 [-c|--cmversion]   <version>"
  echo "        $1 [-h|--help]"
  echo "        $1 [-v|--version]"
  echo ""
  echo "   ex.  $1 --jdktype oracle --jdkversion 8"
  echo "   ex.  $1 --jdktype openjdk --jdkversion 8"
  exit 1
}

# Function to check for root priviledges.
check_root() {
  if [[ $(/usr/bin/id | awk -F= '{print $2}' | awk -F"(" '{print $1}' 2>/dev/null) -ne 0 ]]; then
    echo "You must have root priviledges to run this program."
    exit 2
  fi
}

# Function to discover basic OS details.
discover_os() {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    # shellcheck disable=SC2034
    OS=$(lsb_release -is)
    # 7.2.1511, 14.04
    # shellcheck disable=SC2034
    OSVER=$(lsb_release -rs)
    # 7, 14
    # shellcheck disable=SC2034
    OSREL=$(echo "$OSVER" | awk -F. '{print $1}')
    # trusty, wheezy, Final
    # shellcheck disable=SC2034
    OSNAME=$(lsb_release -cs)
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        # shellcheck disable=SC2034
        OS=CentOS
      else
        # shellcheck disable=SC2034
        OS=RedHatEnterpriseServer
      fi
      # shellcheck disable=SC2034
      OSVER=$(rpm -qf /etc/redhat-release --qf='%{VERSION}.%{RELEASE}\n')
      # shellcheck disable=SC2034
      OSREL=$(rpm -qf /etc/redhat-release --qf='%{VERSION}\n' | awk -F. '{print $1}')
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
    -t|--jdktype)
      shift
      JDK_TYPE=$1
      ;;
    -j|--jdkversion)
      shift
      JDK_VERSION=$1
      ;;
    -c|--cmversion)
      shift
      SCMVERSION=$1
      ;;
    -h|--help)
      print_help "$(basename "$0")"
      ;;
    -v|--version)
      echo "Installs OpenJDK or Oracle JDK."
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
discover_os
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# Check to see if we have the required parameters.
#if [ -z "$JDK_TYPE" ] || [ -z "$JDK_VERSION" ]; then print_help "$(basename "$0")"; fi
if [ "$JDK_TYPE" != "cloudera" ] && [ "$JDK_TYPE" != "oracle" ] && [ "$JDK_TYPE" != "openjdk" ]; then
  echo "** ERROR: --jdktype must be one of cloudera, oracle, or openjdk."
  echo ""
  print_help "$(basename "$0")"
fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
# Backwards support of the old script.  See ARGV above.
USECLOUDERA=$1
if [ -n "$USECLOUDERA" ]; then
  JDK_TYPE=oracle
  JDK_VERSION=$USECLOUDERA
fi
SCMVERSION=$2

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

if [ "$JDK_TYPE" == "cloudera" ]; then
  # TODO: Deal with CM 6.
  echo "Installing Cloudera's Oracle JDK ${JDK_VERSION} ..."
  if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
    case "$JDK_VERSION" in
    7)
      # Because it may have been put there by some other process.
      if [ ! -f /etc/yum.repos.d/cloudera-manager.repo ]; then
        wget --connect-timeout=5 --tries=5 -q "https://archive.cloudera.com/cm5/redhat/${OSREL}/x86_64/cm/cloudera-manager.repo" -O /etc/yum.repos.d/cloudera-manager.repo
        chown root:root /etc/yum.repos.d/cloudera-manager.repo
        chmod 0644 /etc/yum.repos.d/cloudera-manager.repo
        if [ -n "$SCMVERSION" ]; then
          sed -e "s|/cm/5/|/cm/${SCMVERSION}/|" -i /etc/yum.repos.d/cloudera-manager.repo
        fi
      fi
      yum -y -e1 -d1 install oracle-j2sdk1.7
      DIRNAME=$(rpm -ql oracle-j2sdk1.7|head -1)
      TARGET=$(basename "$DIRNAME")
      ln -s "$TARGET" /usr/java/default
      ;;
    *)
      echo "ERROR: Unknown Java version.  Please choose 7."
      exit 10
      ;;
    esac
  elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
    export DEBIAN_FRONTEND=noninteractive
    case "$JDK_VERSION" in
    7)
      # Because it may have been put there by some other process.
      if [ ! -f /etc/apt/sources.list.d/cloudera-manager.list ]; then
        if [ "$OS" == Debian ]; then
          OS_LOWER=debian
        elif [ "$OS" == Ubuntu ]; then
          OS_LOWER=ubuntu
        fi
        wget --connect-timeout=5 --tries=5 -q "https://archive.cloudera.com/cm5/${OS_LOWER}/${OSNAME}/amd64/cm/cloudera.list" -O /etc/apt/sources.list.d/cloudera-manager.list
        chown root:root /etc/apt/sources.list.d/cloudera-manager.list
        chmod 0644 /etc/apt/sources.list.d/cloudera-manager.list
        if [ -n "$SCMVERSION" ]; then
          sed -e "s|-cm5 |-cm${SCMVERSION} |" -i /etc/apt/sources.list.d/cloudera-manager.list
        fi
        curl -s "http://archive.cloudera.com/cm5/${OS_LOWER}/${OSNAME}/amd64/cm/archive.key" | apt-key add -
      fi
      apt-get -y -qq update
      apt-get -y -q install oracle-j2sdk1.7
      ;;
    *)
      echo "ERROR: Unknown Java version.  Please choose 7."
      exit 10
      ;;
    esac
  fi
elif [ "$JDK_TYPE" == "oracle" ]; then
  echo "Installing Oracle JDK ${JDK_VERSION} ..."
  if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
    case "$JDK_VERSION" in
    7)
      # TODO: No longer works.  Oracle now requires login.
      cd /tmp || exit
      echo "*** Downloading Oracle JDK 7u80..."
      wget --connect-timeout=5 --tries=5 -nv -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
        http://download.oracle.com/otn/java/jdk/7u80-b15/jdk-7u80-linux-x64.rpm -O jdk-7u80-linux-x64.rpm
      rpm -Uv jdk-7u80-linux-x64.rpm
      ;;
    8)
      cd /tmp || exit
      echo "*** Downloading Oracle JDK 8u192..."
      wget --connect-timeout=5 --tries=5 -nv -c --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" \
        https://download.oracle.com/otn-pub/java/jdk/8u192-b12/750e1c8617c5452694857ad95c3ee230/jdk-8u192-linux-x64.rpm -O jdk-8u192-linux-x64.rpm
      rpm -Uv jdk-8u192-linux-x64.rpm
      ;;
    *)
      echo "ERROR: Unknown Java version.  Please choose 7 or 8."
      exit 11
      ;;
    esac
  elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
    export DEBIAN_FRONTEND=noninteractive
    case "$JDK_VERSION" in
    7)
      #mkdir -p /var/cache/oracle-jdk7-installer
      #mv jdk-7u*-linux-x64.tar.gz /var/cache/oracle-jdk7-installer/
      add-apt-repository -y ppa:webupd8team/java
      apt-get -y -qq update
      echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
      apt-get -y -q install oracle-java7-installer
      apt-get -y -q install oracle-java7-set-default
      ;;
    8)
      #mkdir -p /var/cache/oracle-jdk8-installer
      #mv jdk-8u*-linux-x64.tar.gz /var/cache/oracle-jdk8-installer/
      add-apt-repository -y ppa:webupd8team/java
      apt-get -y -qq update
      echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
      apt-get -y -q install oracle-java8-installer
      apt-get -y -q install oracle-java8-set-default
      ;;
    *)
      echo "ERROR: Unknown Java version.  Please choose 7 or 8."
      exit 11
      ;;
    esac
  fi
elif [ "$JDK_TYPE" == "openjdk" ]; then
  echo "Installing OpenJDK ${JDK_VERSION} ..."
  if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
    case "$JDK_VERSION" in
    7)
      yum -y -e1 -d1 install java-1.7.0-openjdk-devel
      ;;
    8)
      yum -y -e1 -d1 install java-1.8.0-openjdk-devel
      ;;
    11)
      yum -y -e1 -d1 install java-11-openjdk-devel
      ;;
    *)
      echo "ERROR: Unknown Java version.  Please choose 7, 8, or 11."
      exit 12
      ;;
    esac
  elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
    export DEBIAN_FRONTEND=noninteractive
    case "$JDK_VERSION" in
    7)
      apt-get -y -q install openjdk-7-jdk
      ;;
    8)
      apt-get -y -q install openjdk-8-jdk
      ;;
    11)
      apt-get -y -q install openjdk-11-jdk
      ;;
    *)
      echo "ERROR: Unknown Java version.  Please choose 7, 8, or 11."
      exit 12
      ;;
    esac
  fi
fi

