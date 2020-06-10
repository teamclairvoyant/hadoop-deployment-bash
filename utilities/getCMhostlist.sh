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
#
VERSION=2.0.0
#
##### START CONFIG ###################################################

CMPORT=7180

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

# Process arguments.
while [[ $1 = -* ]]; do
  case $1 in
    -c|--cmhost)
      shift
      _CM=$1
      ;;
    -C|--cluster)
      shift
      _CLUSTER_NAME=$1
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
      echo -e "Print a list of hostnames for the given cluster in Cloudera Manager.\nVersion: $VERSION"
      exit 0
      ;;
    *)
      print_help "$(basename "$0")"
      ;;
  esac
  shift
done

# Check to see if we have the required parameters.
if [ -z "$_CM" ] || [ -z "$_CLUSTER_NAME" ] || [ -z "$_USERNAME" ] || [ -z "$_PASSWORD" ]; then print_help "$(basename "$0")"; fi

# Determine the CM API version.
_API=$(curl -skLu "${_USERNAME}:${_PASSWORD}" "http://${_CM}:${CMPORT}/api/version")
if [ -z "$_API" ]; then
  echo "ERROR: No API version output from the CM server." >&2
  exit 2
fi
# Strip the leading "v" from the version string so that we have a numeral.
_APINUM=${_API#v}

# Figure out which Python version we have and URL escape the $_CLUSTER_NAME string.
if command -v python3 >/dev/null; then
  # BEGIN: Do not mess with the indentation or multiple lines in this Python code.
  CLUSTER_NAME_ESCAPED=$(echo "${_CLUSTER_NAME}" | python3 -c 'import sys, urllib.parse;
for x in sys.stdin.readlines():
  print(urllib.parse.quote(x.rstrip()))')
  # END: Do not mess with the indentation or multiple lines in this Python code.
elif command -v python2 >/dev/null; then
  # BEGIN: Do not mess with the indentation or multiple lines in this Python code.
  CLUSTER_NAME_ESCAPED=$(echo "${_CLUSTER_NAME}" | python2 -c 'import sys, urllib;
for x in sys.stdin.readlines():
  print(urllib.quote(x.rstrip()))')
  # END: Do not mess with the indentation or multiple lines in this Python code.
else
  echo "ERROR: No Python installed." >&2
  exit 3
fi

# Get the list of hostIds (and hostnames) for the given cluster.
HOSTS_OUTPUT=$(curl -skLu "${_USERNAME}:${_PASSWORD}" -X GET "http://${_CM}:${CMPORT}/api/${_API}/clusters/${CLUSTER_NAME_ESCAPED}/hosts")
if [ -z "$HOSTS_OUTPUT" ]; then
  echo "ERROR: No host output from the CM server. Is --cluster correct?" >&2
  exit 4
fi

# CM API greater than or equal to v31 also include hostnames in the output.
if [ "$_APINUM" -ge 31 ]; then
  HOST_NAMES=$(echo "${HOSTS_OUTPUT}" | python -c 'import json, sys; obj=json.load(sys.stdin); print(" ".join([x["hostname"] for x in obj["items"]]))')
  # Since we have hostnames, we are all done.
  HOSTS_ARRAY+=( "$HOST_NAMES" )
else
  HOST_IDS=$(echo "${HOSTS_OUTPUT}" | python -c 'import json, sys; obj=json.load(sys.stdin); print(" ".join([x["hostId"] for x in obj["items"]]))')
  # Since we do not have hostnames, we need to convert the hostIds to hostnames.
  for HOST in $HOST_IDS; do
    _HOSTNAME=$(curl -skLu "${_USERNAME}:${_PASSWORD}" -X GET "http://${_CM}:${CMPORT}/api/${_API}/hosts/${HOST}" | python -c 'import json, sys; obj=json.load(sys.stdin); print(obj["hostname"])')
    HOSTS_ARRAY+=( "$_HOSTNAME" )
  done
fi

# Print out the results.
echo "${HOSTS_ARRAY[@]}"

