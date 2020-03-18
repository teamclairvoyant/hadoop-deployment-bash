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
# Copyright Clairvoyant 2019
#
if [ -n "$DEBUG" ]; then set -x; fi
#
##### START CONFIG ###################################################

KEEPALIVED_NIC=eth0
KEEPALIVED_NETMASK=255.255.255.128  # TODO

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
DATE=$(date '+%Y%m%d%H%M%S')

# Function to print the help screen.
print_help() {
  echo "Usage:  $1 --type <primary|backup> --ipaddress <10.2.3.4> --routerid 50 --password mypass"
  echo ""
  echo "        $1 -t|--type <primary|backup>"
  echo "        $1 -i|--ipaddress <IPv4 address> # VIP"
  echo "        $1 -r|--routerid <integer> # must be the same for all cluster nodes"
  echo "        $1 -P|--password <password> # must be the same for all cluster nodes"
  echo "        $1 [-n|--nic <NIC device name>] # defaults to eth0"
  echo "        $1 [-p|--peeripaddress <unicast peer IPv4 address>] # AWS Peer's instance IP"
  echo "        $1 [-h|--help]"
  echo "        $1 [-v|--version]"
  echo ""
  echo "   ex.  $1 -t primary -i 10.100.2.34 -n em1 -r 51 -P changeme"
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

is_virtual() {
  grep -Eqi 'VirtualBox|VMware|Parallel|Xen|innotek|QEMU|Virtual Machine|Amazon EC2' /sys/devices/virtual/dmi/id/*
  return $?
}

is_aws() {
  grep -qi 'amazon' /sys/devices/virtual/dmi/id/*
  return $?
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
    -n|--nic)
      shift
      KEEPALIVED_NIC=$1
      ;;
    -t|--type)
      shift
      KEEPALIVED_TYPE=$1
      ;;
    -i|--ipaddress)
      shift
      KEEPALIVED_VIP=$1
      ;;
    -p|--peeripaddress)
      shift
      KEEPALIVED_PEERIP=$1
      ;;
    -r|--routerid)
      shift
      KEEPALIVED_ROUTERID=$1
      ;;
    -P|--password)
      shift
      KEEPALIVED_PASSWORD=$1
      ;;
    -h|--help)
      print_help "$(basename "$0")"
      ;;
    -v|--version)
      echo "Installs Keepalived to control HAproxy."
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
if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ]; then
#if [ "$OS" != RedHatEnterpriseServer ] && [ "$OS" != CentOS ] && [ "$OS" != Debian ] && [ "$OS" != Ubuntu ]; then
  echo "ERROR: Unsupported OS."
  exit 3
fi

# Check to see if we have the required parameters.
if [ "$KEEPALIVED_TYPE" != "primary" ] && [ "$KEEPALIVED_TYPE" != "backup" ]; then
  echo "** ERROR: --type must be one of primary or backup."
  echo ""
  print_help "$(basename "$0")"
fi
if [ -z "$KEEPALIVED_VIP" ]; then
  echo "** ERROR: --ipaddress must be specified."
  echo ""
  print_help "$(basename "$0")"
fi
if [ -z "$KEEPALIVED_ROUTERID" ]; then
  echo "** ERROR: --routerid must be specified."
  echo ""
  print_help "$(basename "$0")"
fi
if [ -z "$KEEPALIVED_PASSWORD" ]; then
  echo "** ERROR: --password must be specified."
  echo ""
  print_help "$(basename "$0")"
fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
echo "Installing keepalived..."
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  yum -y -d1 -e1 install keepalived
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get -y -q install keepalived
fi

if [ ! -f /etc/keepalived/keepalived.conf-orig ]; then
  cp -p /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf-orig
else
  cp -p /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf."${DATE}"
fi

if [ "$KEEPALIVED_TYPE" == "primary" ]; then
  PRIORITY=101
elif [ "$KEEPALIVED_TYPE" == "backup" ]; then
  PRIORITY=100
fi

if is_aws; then
  # AWS does not support multicast, so we must use unicast in Keepalived.
  cat <<EOF >/etc/keepalived/keepalived.conf
# CLAIRVOYANT
# Configuration File for keepalived
# https://accelazh.github.io/loadbalance/HA-Of-Haproxy-Using-Keepalived-VRRP
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html-single/load_balancer_administration/index

global_defs {
#  notification_email {
#    root@localdomain
#  }
#  notification_email_from keepalived@localdomain
  smtp_server 127.0.0.1
  smtp_connect_timeout 60
  router_id LVS_DEVEL
  vrrp_skip_check_adv_addr
#  vrrp_strict
  vrrp_garp_interval 0
  vrrp_gna_interval 0
  enable_script_security
  script_user root
}

vrrp_script chk_haproxy {
  script "/usr/bin/pkill -0 haproxy"     # verify the pid existance
  interval 2                             # check every 2 seconds
  weight 2                               # add 2 points of priority if OK
}

vrrp_instance VI_1 {
  interface ${KEEPALIVED_NIC}                         # interface to monitor
  virtual_router_id ${KEEPALIVED_ROUTERID}                   # Assign one ID for this route
  priority ${PRIORITY}                           # Prevent automatic fail-back and a second outage with identical priority.
  state BACKUP
#  nopreempt                              # Prevent fail-back
  track_script {
    chk_haproxy
  }
  authentication {
    auth_type PASS
    auth_pass ${KEEPALIVED_PASSWORD}
  }
  unicast_src_ip $(ip -4 addr show dev "${KEEPALIVED_NIC}" | awk '/inet/{print $2}' | awk -F/ '{print $1}')
  unicast_peer {
    ${KEEPALIVED_PEERIP}
  }
  notify_master "/etc/keepalived/assign_vip.sh ${KEEPALIVED_VIP} ${KEEPALIVED_NIC}"
}
EOF
  cat <<EOF2>/etc/keepalived/assign_vip.sh
#!/bin/bash
# https://gist.github.com/kntyskw/5417140
PATH=/sbin:/bin:/usr/sbin:/usr/bin
VIP=\$1
IF=\$2

# Determine the interface's MAC address
MAC=\$(ip link show \$IF | awk '/ether/ {print \$2}')

# Determine ENI ID of the interface
ENI_ID=\$(curl -s http://169.254.169.254/latest/meta-data/network/interfaces/macs/\$MAC/interface-id)

# Set the current region as default
export AWS_DEFAULT_REGION=\$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | rev | cut -c 2- | rev)

aws ec2 assign-private-ip-addresses --network-interface-id \$ENI_ID --private-ip-addresses \$VIP --allow-reassignment

EOF2
  chmod 0755 /etc/keepalived/assign_vip.sh
  chown root:root /etc/keepalived/assign_vip.sh
  if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
    echo -e "DEVICE=${KEEPALIVED_NIC}:0\nIPADDR=${KEEPALIVED_VIP}\nNETMASK=${KEEPALIVED_NETMASK}\nONPARENT=yes" >"/tmp/ifcfg-${KEEPALIVED_NIC}:0"
    install -m 0664 -o root -g root "/tmp/ifcfg-${KEEPALIVED_NIC}:0" "/etc/sysconfig/network-scripts/ifcfg-${KEEPALIVED_NIC}:0"
    /sbin/ifup "${KEEPALIVED_NIC}:0"
  elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
    # TODO
    echo "WARNING: Interface ${KEEPALIVED_NIC}:0 is not configured! FIXME!!"
  fi
elif is_virtual; then
  cat <<EOF >/etc/keepalived/keepalived.conf
# CLAIRVOYANT
# Configuration File for keepalived
# https://accelazh.github.io/loadbalance/HA-Of-Haproxy-Using-Keepalived-VRRP
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html-single/load_balancer_administration/index

global_defs {
#  notification_email {
#    root@localdomain
#  }
#  notification_email_from keepalived@localdomain
  smtp_server 127.0.0.1
  smtp_connect_timeout 60
  router_id LVS_DEVEL
  vrrp_skip_check_adv_addr
  # https://bugzilla.redhat.com/show_bug.cgi?id=1762624
  #vrrp_strict
  vrrp_garp_interval 0
  vrrp_gna_interval 0
  enable_script_security
  script_user root
}

vrrp_script chk_haproxy {
  script "/usr/bin/pkill -0 haproxy"     # verify the pid existance
  interval 2                             # check every 2 seconds
  weight 2                               # add 2 points of priority if OK
}

vrrp_instance VI_1 {
  interface ${KEEPALIVED_NIC}                         # interface to monitor
  virtual_router_id ${KEEPALIVED_ROUTERID}                   # Assign one ID for this route
  priority ${PRIORITY}                           # Prevent automatic fail-back and a second outage with identical priority.
  state BACKUP
  #nopreempt                              # Prevent fail-back
  virtual_ipaddress {
    ${KEEPALIVED_VIP}
  }
  track_script {
    chk_haproxy
  }
  authentication {
    auth_type PASS
    auth_pass ${KEEPALIVED_PASSWORD}
  }
  # on VMware: https://sourceforge.net/p/keepalived/mailman/message/35113578/
  #garp_master_refresh 5
  #garp_master_refresh_repeat 1
}
EOF
else
  cat <<EOF >/etc/keepalived/keepalived.conf
# CLAIRVOYANT
# Configuration File for keepalived
# https://accelazh.github.io/loadbalance/HA-Of-Haproxy-Using-Keepalived-VRRP
# https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html-single/load_balancer_administration/index

global_defs {
#  notification_email {
#    root@localdomain
#  }
#  notification_email_from keepalived@localdomain
  smtp_server 127.0.0.1
  smtp_connect_timeout 60
  router_id LVS_DEVEL
  vrrp_skip_check_adv_addr
  vrrp_strict
  vrrp_garp_interval 0
  vrrp_gna_interval 0
  enable_script_security
  script_user root
}

vrrp_script chk_haproxy {
  script "/usr/bin/pkill -0 haproxy"     # verify the pid existance
  interval 2                             # check every 2 seconds
  weight 2                               # add 2 points of priority if OK
}

vrrp_instance VI_1 {
  interface ${KEEPALIVED_NIC}                         # interface to monitor
  virtual_router_id ${KEEPALIVED_ROUTERID}                   # Assign one ID for this route
  priority ${PRIORITY}                           # Prevent automatic fail-back and a second outage with identical priority.
  state BACKUP
  nopreempt                              # Prevent fail-back
  virtual_ipaddress {
    ${KEEPALIVED_VIP}
  }
  track_script {
    chk_haproxy
  }
  authentication {
    auth_type PASS
    auth_pass ${KEEPALIVED_PASSWORD}
  }
}
EOF
fi

echo "Set the Kernel to allow binding a non-local IP."
echo "Changing net.ipv4.ip_nonlocal_bind running value to 1."
sysctl -w net.ipv4.ip_nonlocal_bind=1

echo "Setting net.ipv4.ip_nonlocal_bind startup value to 1."
if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  if [ "$OSREL" == 6 ]; then
    if grep -q net.ipv4.ip_nonlocal_bind /etc/sysctl.conf; then
      sed -i -e "/^net.ipv4.ip_nonlocal_bind/s|=.*|= 1|" /etc/sysctl.conf
    else
      echo "net.ipv4.ip_nonlocal_bind = 1" >>/etc/sysctl.conf
    fi
  else
    if grep -q net.ipv4.ip_nonlocal_bind /etc/sysctl.conf; then
      sed -i -e '/^net.ipv4.ip_nonlocal_bind/d' /etc/sysctl.conf
    fi
    install -m 0644 -o root -g root /dev/null /etc/sysctl.d/keepalived.conf
    echo "# Tuning for Keepalived installation. CLAIRVOYANT" >/etc/sysctl.d/keepalived.conf
    echo "net.ipv4.ip_nonlocal_bind = 1" >>/etc/sysctl.d/keepalived.conf
  fi
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  if grep -q net.ipv4.ip_nonlocal_bind /etc/sysctl.conf; then
    sed -i -e '/^net.ipv4.ip_nonlocal_bind/d' /etc/sysctl.conf
  fi
  install -m 0644 -o root -g root /dev/null /etc/sysctl.d/keepalived.conf
  echo "# Tuning for Keepalived installation. CLAIRVOYANT" >/etc/sysctl.d/keepalived.conf
  echo "net.ipv4.ip_nonlocal_bind = 1" >>/etc/sysctl.d/keepalived.conf
fi

if [ "$OS" == RedHatEnterpriseServer ] || [ "$OS" == CentOS ]; then
  service keepalived start
  chkconfig keepalived on
elif [ "$OS" == Debian ] || [ "$OS" == Ubuntu ]; then
  service keepalived start
  update-rc.d keepalived defaults
fi

