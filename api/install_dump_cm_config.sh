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

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
# Check to see if we are on a supported OS.
discover_os
if [ "$OS" != RedHatEnterpriseServer -a "$OS" != CentOS -a "$OS" != Debian -a "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

if [ "$OS" == RedHatEnterpriseServer -o "$OS" == CentOS ]; then
  # https://discourse.criticalengineering.org/t/howto-password-generation-in-the-gnu-linux-cli/10
  PWCMD='< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo'
  #if ! rpm -q apg; then echo "Installing apg. Please wait...";yum -y -d1 -e1 install apg; fi
  #if rpm -q apg; then export PWCMD='apg -a 1 -M NCL -m 20 -x 20 -n 1'; fi
  if ! rpm -q apg >/dev/null; then
    echo "Installing apg. Please wait..."
    yum -y -d1 -e1 install apg
  fi
  if rpm -q apg >/dev/null; then
    export PWCMD='apg -a 1 -M NCL -m 20 -x 20 -n 1'
  fi
elif [ "$OS" == Debian -o "$OS" == Ubuntu ]; then
  # https://discourse.criticalengineering.org/t/howto-password-generation-in-the-gnu-linux-cli/10
  PWCMD='< /dev/urandom tr -dc A-Za-z0-9 | head -c 20;echo'
  if ! dpkg -l apg >/dev/null; then
    echo "Installing apg. Please wait..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get -y -q install apg
  fi
  if dpkg -l apg >/dev/null; then
    export PWCMD='apg -a 1 -M NCL -m 20 -x 20 -n 1'
  fi
fi

ADMINUSER=admin
ADMINPASS=admin
APIUSER=api
APIPASS=`eval $PWCMD`
CMHOST=localhost
CMPORT=7180
API=v5

if ! (exec 6<>/dev/tcp/${CMHOST}/${CMPORT}); then
  echo 'ERROR: cloudera-scm-server not listening...'
  exit 1
fi

if curl -s -X GET -u "${ADMINUSER}:${ADMINPASS}" http://${CMHOST}:${CMPORT}/api/${API}/users/${APIUSER} | grep -q "does not exist"; then
  curl -s -X POST -u "${ADMINUSER}:${ADMINPASS}" -H "content-type:application/json" -d \
  "{
    \"items\" : [ {
      \"name\" : \"$APIUSER\",
      \"password\" : \"$APIPASS\",
      \"roles\" : [ \"ROLE_ADMIN\" ]
    } ]
  }" http://${CMHOST}:${CMPORT}/api/${API}/users
  echo ""
  echo "****************************************"
  echo "****************************************"
  echo "****************************************"
  echo "*** SAVE THIS PASSWORD"
  echo "APIUSER : $APIUSER"
  echo "APIPASS : $APIPASS"
  echo "****************************************"
  echo "****************************************"
  echo "****************************************"

  sed -e "/^APIUSER=/s|=.*|=${APIUSER}|" \
      -e "/^APIPASS=/s|=.*|=${APIPASS}|" \
      -e "/^CMHOST=/s|=.*|=${CMHOST}|" \
      -e "/^CMPORT=/s|=.*|=${CMPORT}|" \
      $(dirname $0)/dump_cm_config.sh >/usr/local/sbin/dump_cm_config.sh
  chown 0:0 /usr/local/sbin/dump_cm_config.sh
  chmod 700 /usr/local/sbin/dump_cm_config.sh
  rm -f /tmp/$$
  crontab -l | egrep -v 'dump_cm_config.sh' >/tmp/$$
  echo '1 0 * * * /usr/local/sbin/dump_cm_config.sh >/var/log/cm_config.dump'>>/tmp/$$
  crontab /tmp/$$
  rm -f /tmp/$$
else
  echo "WARNING: APIUSER ${APIUSER} already exists.  Exiting without installing crontab."
  exit 2
fi

