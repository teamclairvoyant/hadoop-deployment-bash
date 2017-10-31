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

# Function to print the help screen.
print_help () {
  printf "Usage:  $1 --navpass <password> --server <servername> [--passive-server <servername>] --org <myOrg> --auth <KTpass> --key-type <type> [--skip-ssl-check]\n"
  printf "\n"
  printf "         -n|--navpass          Password used to encrypt the local Navigator Encrypt configuration.\n"
  printf "         -s|--server           Active Key Trustee Server hostname. NOT A URI.\n"
  printf "        [-p|--passive-server]  Passive Key Trustee Server hostname. NOT A URI.\n"
  printf "         -o|--org              Organization name configured by the Key Trustee Server administrator.\n"
  printf "         -a|--auth             Organization authorization token, a pre-shared secret by the Key Trustee Server administrator.\n"
  printf "         -k|--key-type         single-passphrase, dual-passphrase, or ???\n"
  printf "        [-c|--skip-ssl-check]  Skip SSL certificate verification of the Key Trustee Server.\n"
  printf "        [-h|--help]\n"
  printf "        [-v|--version]\n"
  printf "\n"
  printf "   ex.  $1 --navpass \"mypasssword\" --server kts1.localdomain --org myOrg --auth \"2GpvWnC4eMFSREtlTvEUFA==\" --key-type single-passphrase\n"
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
    -s|--server)
      shift
      KTSERVERHOST1=$1
      ;;
    -p|--passive-server)
      shift
      KTSERVERHOST2=$1
      KTSERVERHOST2="--passive-server=https://${KTSERVERHOST2}:11371"
      ;;
    -o|--org)
      shift
      KTORG=$1
      ;;
    -a|--auth)
      shift
      KTPASS=$1
      ;;
    -k|--key-type)
      shift
      KTTYPE=$1
      ;;
    -c|--skip-ssl-check)
      SKIPSSL="--skip-ssl-check"
      ;;
    -h|--help)
      print_help "$(basename $0)"
      ;;
    -v|--version)
      printf "\tRegister the system with a Navigator Encrypt Key Trustee Server.\n"
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
if [[ -z "$KTSERVERHOST1" ]]; then print_help "$(basename $0)"; fi
if [[ -z "$KTORG" ]]; then print_help "$(basename $0)"; fi
if [[ -z "$KTPASS" ]]; then print_help "$(basename $0)"; fi
if [[ -z "$KTTYPE" ]]; then print_help "$(basename $0)"; fi
case $KTTYPE in
  single-passphrase|dual-passphrase|rsa)
    ;;
  *)
    printf "ERROR: key-type must be one of single-passphrase, dual-passphrase, or rsa.\n"
    exit 3
    ;;
esac

# Lets not bother continuing unless we have the privs to do something.
check_root

# main
umask 022
if [ ! -f /etc/navencrypt/keytrustee/clientname ]; then
  printf '%s\n%s' $NAVPASS $NAVPASS |
  navencrypt register --server=https://${KTSERVERHOST1}:11371 ${KTSERVERHOST2} --org=${KTORG} --auth=${KTPASS} --key-type=${KTTYPE} ${SKIPSSL}
else
  printf "** WARNING: This host is already registered.  Skipping..."
fi

