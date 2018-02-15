#!/bin/bash
# This script install the Centrify agent

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

_get_proxy() {
  PROXY=`egrep -h '^ *http_proxy=http|^ *https_proxy=http' /etc/profile.d/*`
  eval $PROXY
  export http_proxy
  export https_proxy
  if [ -z "$http_proxy" ]; then
    PROXY=`egrep -l 'http_proxy=|https_proxy=' /etc/profile.d/*`
    if [ -n "$PROXY" ]; then
      . $PROXY
    fi
  fi
}

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

echo "Installing Centrify agent..."
if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  _get_proxy
  wget -q -c -O /tmp/centrify-suite-2017.3-rhel5-x86_64.tgz https://downloads.centrify.com/products/centrify-suite/2017-update-3/centrify-suite-2017.3-rhel5-x86_64.tgz
  pushd /tmp
  tar -xzf centrify-suite-2017.3-rhel5-x86_64.tgz
  yum -y -d1 -e1 install CentrifyDC-openssl-5.4.3-rhel5.x86_64.rpm CentrifyDC-openldap-5.4.3-rhel5.x86_64.rpm CentrifyDC-curl-5.4.3-rhel5.x86_64.rpm CentrifyDC-5.4.3-rhel5.x86_64.rpm
  popd
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  _get_proxy
  wget -q -c -O /tmp/centrify-suite-2017.3-deb7-x86_64.tgz https://downloads.centrify.com/products/centrify-suite/2017-update-3/centrify-suite-2017.3-deb7-x86_64.tgz
  pushd /tmp
  tar -xzf centrify-suite-2017.3-deb7-x86_64.tgz
  dpkg -i centrifydc-openldap-5.4.3-deb7-x86_64.deb centrifydc-curl-5.4.3-deb7-x86_64.deb centrifydc-openssl-5.4.3-deb7-x86_64.deb centrifydc-5.4.3-deb7-x86_64.deb
  popd
  fi
