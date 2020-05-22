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
# Copyright Clairvoyant 2020
#
if [ -n "$DEBUG" ]; then set -x; fi
VERSION=1.0.0
#
##### START CONFIG ###################################################

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin:/opt/anaconda3/bin
# https://github.com/cloudera/cm_api/wiki/List-of-all-hosts-in-Cluster-1-and-list-hostname-for-a-Service-Role

# Function to print the help screen.
print_help() {
  echo "Usage:  $1 --cmhost <hostname> --user <username> --password <password> --cluster <clusternamd>"
  echo "        $1 [-h|--help]"
  echo "        $1 [-v|--version]"
  echo ""
  echo "   ex.  $1 --cmhost cmhost --user foo --password bar --cluster 'Cluster 1'"
  exit 1
}

# Function to check for root privileges.
check_root() {
  if [[ $(/usr/bin/id | awk -F= '{print $2}' | awk -F"(" '{print $1}' 2>/dev/null) -ne 0 ]]; then
    echo "You must have root privileges to run this program."
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
    -c|--cmhost)
      shift
      _CM=$1
      ;;
    -C|--cluster)
      shift
      _CLUSTER=$1
      ;;
    -u|--user)
      shift
      _USERNAME=$1
      ;;
    -p|--password)
      shift
      _PASSWORD=$1
      ;;
    -h|--help)
      print_help "$(basename "$0")"
      ;;
    -v|--version)
      echo -e "Print a list of hostnames for the given cluster CLoudera Manager.\nVersion: $VERSION"
      exit 0
      ;;
    *)
      print_help "$(basename "$0")"
      ;;
  esac
  shift
done

# Check to see if we have the required parameters.
if [ -z "$_CM" ] || [ -z "$_CLUSTER" ] || [ -z "$_USERNAME" ] || [ -z "$_PASSWORD" ]; then print_help "$(basename "$0")"; fi

# Lets not bother continuing unless we have the privs to do something.
#check_root

# shellcheck disable=SC2086
#_APIVERSION=$(curl -skLu "${_USERNAME}:${_PASSWORD}" "http://${_CM}:7180/api/version")
#API=${_APIVERSION:-v6}
#echo "** Using API version ${API}"

CLUSTER_NAMES=$_CLUSTER
if command -v python3 >/dev/null; then
  # BEGIN: Do not mess with the indentation or multiple lines in this Python code.
  CLUSTER_NAMES_ESCAPED=$(echo "${CLUSTER_NAMES}" | python3 -c 'import sys, urllib.parse;
for x in sys.stdin.readlines():
  print(urllib.parse.quote(x.rstrip()))')
  # END: Do not mess with the indentation or multiple lines in this Python code.
elif command -v python2 >/dev/null; then
  # BEGIN: Do not mess with the indentation or multiple lines in this Python code.
  CLUSTER_NAMES_ESCAPED=$(echo "${CLUSTER_NAMES}" | python2 -c 'import sys, urllib;
for x in sys.stdin.readlines():
  print(urllib.quote(x.rstrip()))')
  # END: Do not mess with the indentation or multiple lines in this Python code.
else
  echo "ERROR: No Python installed."
  exit 1
fi

for CLUSTER in ${CLUSTER_NAMES_ESCAPED}; do
  HOSTS_OUTPUT=$(curl -skLu "${_USERNAME}:${_PASSWORD}" -X GET "http://${_CM}:7180/api/v6/clusters/${CLUSTER}/hosts")
  if [ -z "$HOSTS_OUTPUT" ]; then
    echo "ERROR: No output from the CM server."
    exit 2
  fi
  HOST_IDS=$(echo "${HOSTS_OUTPUT}" | python -c 'import json, sys; obj=json.load(sys.stdin); print(" ".join([x["hostId"] for x in obj["items"]]))')
  for HOST in $HOST_IDS; do
    _HOSTNAME=$(curl -skLu "${_USERNAME}:${_PASSWORD}" -X GET "http://${_CM}:7180/api/v6/hosts/${HOST}" | python -c 'import json, sys; obj=json.load(sys.stdin); print(obj["hostname"])')
    HOSTS_ARRAY+=( "$_HOSTNAME" )
  done

  echo "${HOSTS_ARRAY[@]}"
  unset HOSTS_ARRAY
done

