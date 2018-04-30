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
USEHAVEGED=no

# Function to print the help screen.
print_help () {
  echo "Usage:  $1 [-H|--haveged]"
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

# Function to discover basic OS details.
discover_os () {
  if command -v lsb_release >/dev/null; then
    # CentOS, Ubuntu
    OS=`lsb_release -is`
    # 7.2.1511, 14.04
    OSVER=`lsb_release -rs`
    # 7, 14
    OSREL=`echo $OSVER | awk -F. '{print $1}'`
    # trusty, wheezy, Final
    OSNAME=`lsb_release -cs`
  else
    if [ -f /etc/redhat-release ]; then
      if [ -f /etc/centos-release ]; then
        OS=CentOS
      else
        OS=RedHatEnterpriseServer
      fi
      OSVER=`rpm -qf /etc/redhat-release --qf="%{VERSION}.%{RELEASE}\n"`
      OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n" | awk -F. '{print $1}'`
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
    -H|--haveged)
      USEHAVEGED=yes
      ;;
    -h|--help)
      print_help "$(basename $0)"
      ;;
    -v|--version)
      echo "Installs an entropy gathering daemon: RNGD ot HAVEGED."
      exit 0
      ;;
    *)
      print_help "$(basename $0)"
      ;;
  esac
  shift
done

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# Check to see if we have the required parameters.
#if [ -z "$USEHAVEGED" ]; then print_help "$(basename $0)"; fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
echo "Installing entropy generator..."
if grep -q rdrand /proc/cpuinfo; then
  RDRAND=true
else
  RDRAND=false
fi

if [ -f /dev/hwrng ]; then
  HWRNG=true
else
  HWRNG=false
fi

if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  if [ "$USEHAVEGED" == "yes" ]; then
    yum -y -e1 -d1 install epel-release
    if ! rpm -q epel-release; then
      rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OSREL}.noarch.rpm
    fi
    yum -y -e1 -d1 install haveged
    service haveged start
    chkconfig haveged on
  else
    # https://www.cloudera.com/content/www/en-us/downloads/navigator/encrypt/3-8-0.html
    # http://www.certdepot.net/rhel7-get-started-random-number-generator/
    yum -y -d1 -e1 install rng-tools
    if [ $RDRAND == false -a $HWRNG == false ]; then
      if [ $OSREL == 6 ]; then
        sed -i -e 's|^EXTRAOPTIONS=.*|EXTRAOPTIONS="-r /dev/urandom"|' /etc/sysconfig/rngd
      else
        cp -p /usr/lib/systemd/system/rngd.service /etc/systemd/system/
        sed -i -e 's|^ExecStart=.*|ExecStart=/sbin/rngd -f -r /dev/urandom|' /etc/systemd/system/rngd.service
        systemctl daemon-reload
      fi
    fi
    service rngd start
    chkconfig rngd on
  fi
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  if [ "$USEHAVEGED" == "yes" ]; then
    apt-get -y -q install haveged
    service haveged start
    update-rc.d haveged defaults
  else
    # https://www.cloudera.com/content/www/en-us/downloads/navigator/encrypt/3-8-0.html
    apt-get -y -q install rng-tools
    if [ $RDRAND == false -a $HWRNG == false ]; then
      sed -i -e '/^HRNGDEVICE=/d' /etc/default/rng-tools
      echo "HRNGDEVICE=/dev/urandom" >>/etc/default/rng-tools
    fi
    service rng-tools start
    update-rc.d rng-tools defaults
  fi
fi

