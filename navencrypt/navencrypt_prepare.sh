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
# Copyright Clairvoyant 2017
#
# $Id$
#
# EXIT CODE:
#     0 = success
#     1 = print_help function (or incorrect commandline)
#     2 = ERROR: Must be root.
#
if [ $DEBUG ]; then set -x; fi
#
##### START CONFIG ###################################################

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin
FSTYPE=xfs
FSMOUNTOPT=noatime
FORCE=no

# Function to print the help screen.
print_help () {
  printf "Usage:  $1 --navpass <password> --device <device> --emountpoint <emountpoint> [--fstype <fstype>] [--mountoptions <options>]\n"
  printf "\n"
  printf "         -n|--navpass          Password used to encrypt the local Navigator Encrypt configuration.\n"
  printf "         -d|--device           Disk device to encrypt.  Device will be wiped.\n"
  printf "         -e|--emountpoint      Mountpoint of the encrypted filesystem.\n"
  printf "        [-t|--fstype]          Filesystem type.  Default is xfs.\n"
  printf "        [-o|--mountoptions]    Filesystem mount options.  Default is noatime.\n"
  printf "        [-f|--force]           Force wipe any existing data.\n"
  printf "        [-h|--help]\n"
  printf "        [-v|--version]\n"
  printf "\n"
  printf "   ex.  $1 --navpass \"mypasssword\" --device /dev/sdb --emountpoint /navencrypt/2\n"
  exit 1
}

# Function to check for root priviledges.
check_root () {
  if [[ `/usr/bin/id | awk -F= '{print $2}' | awk -F"(" '{print $1}' 2>/dev/null` -ne 0 ]]; then
    printf "You must have root priviledges to run this program.\n"
    exit 2
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
    -n|--navpass)
      shift
      NAVPASS=$1
      ;;
    -d|--device)
      shift
      DEVICE=$1
      ;;
    -e|--emountpoint)
      shift
      EMOUNTPOINT=$(echo $1 | sed -e 's|/$||')
      ;;
    -t|--fstype)
      shift
      FSTYPE=$1
      ;;
    -o|--mountoptions)
      shift
      FSMOUNTOPT=$1
      ;;
    -f|--force)
      FORCE=yes
      ;;
    -h|--help)
      print_help "$(basename $0)"
      ;;
    -v|--version)
      printf "\tPrepare a device for Navigator Encrypt data encryption.\n"
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
# Check to see if we have no parameters.
if [[ -z "$NAVPASS" ]]; then print_help "$(basename $0)"; fi
if [[ -z "$DEVICE" ]]; then print_help "$(basename $0)"; fi
if [[ -z "$EMOUNTPOINT" ]]; then print_help "$(basename $0)"; fi

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
set -u
umask 022

if [ -f /etc/navencrypt/keytrustee/clientname ]; then
  # Check to make sure we do not wipe a LVM.
  if ! echo $DEVICE | grep -qE '^/dev/sd|^/dev/xvd' ;then
    printf "** ERROR: ${DEVICE} is not an sd device. Exiting..."
    exit 7
  fi
  if [ -b ${DEVICE} ]; then
    # Is there a partition?
    if [ -b ${DEVICE}1 ]; then
      echo "** Device ${DEVICE} is already partitioned."
      PART="1"
    elif [ -b ${DEVICE}p1 ]; then
      echo "** Device ${DEVICE} is already partitioned."
      PART="p1"
    else
      echo "** Device ${DEVICE} is not partitioned."
      if ! rpm -q parted >/dev/null 2>&1; then
        echo "** Installing parted. Please wait..."
        yum -y -d1 -e1 install parted
      fi
      SIZE=$(lsblk --all --bytes --list --output NAME,SIZE,TYPE $DEVICE | awk '/disk$/{print $2}')
      if [ "$SIZE" -ge 2199023255552 ]; then
        parted --script $DEVICE mklabel gpt mkpart primary $FSTYPE 1049kB 100%
      else
        parted --script $DEVICE mklabel msdos mkpart primary $FSTYPE 1049kB 100%
      fi
      sleep 2
      if [ -b ${DEVICE}1 ]; then
        PART="1"
      elif [ -b ${DEVICE}p1 ]; then
        PART="p1"
      else
        printf "** ERROR: Device ${DEVICE} partitioning failed. Exiting..."
        exit 5
      fi
    fi
    echo "** Preparing ${DEVICE} for encryption..."
    if [ "$FORCE" == yes ]; then
      dd if=/dev/zero of=${DEVICE}${PART} ibs=1M count=1
    fi
    mkdir -p -m 0755 $(dirname $EMOUNTPOINT)
    mkdir -p -m 0755 $EMOUNTPOINT && \
    chattr +i $EMOUNTPOINT && \
    printf '%s' $NAVPASS |
    navencrypt-prepare -t $FSTYPE -o $FSMOUNTOPT --use-uuid ${DEVICE}${PART} $EMOUNTPOINT -
    RETVAL=$?
    if [ "$RETVAL" -ne 0 ]; then
      echo "** ERROR: Could not format ${DEVICE} for ${EMOUNTPOINT}."
      exit $RETVAL
    fi
  else
    printf "** ERROR: Device ${DEVICE} does not exist. Exiting..."
    exit 4
  fi
else
  printf "** WARNING: This host is not yet registered.  Skipping..."
  exit 3
fi

