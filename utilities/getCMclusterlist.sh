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
VERSION=1.0.0
#
##### START CONFIG ###################################################

CMPORT=7180

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin:/opt/anaconda3/bin
# https://github.com/cloudera/cm_api/wiki/List-of-all-hosts-in-Cluster-1-and-list-hostname-for-a-Service-Role

# Function to print the help screen.
print_help() {
  echo "Usage:  $1 --cmhost <hostname> --user <username> --password <password>"
  echo "        $1 [-h|--help]"
  echo "        $1 [-v|--version]"
  echo ""
  echo "   ex.  $1 --cmhost cmhost --user foo --password bar"
  exit 1
}

# Process arguments.
while [[ $1 = -* ]]; do
  case $1 in
    -c|--cmhost)
      shift
      _CM=$1
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
      echo -e "Print a list of clusternames for the given Cloudera Manager.\nVersion: $VERSION"
      exit 0
      ;;
    *)
      print_help "$(basename "$0")"
      ;;
  esac
  shift
done

# Check to see if we have the required parameters.
if [ -z "$_CM" ] || [ -z "$_USERNAME" ] || [ -z "$_PASSWORD" ]; then print_help "$(basename "$0")"; fi

# Determine the CM API version.
_API=$(curl -skLu "${_USERNAME}:${_PASSWORD}" "http://${_CM}:${CMPORT}/api/version")
if [ -z "$_API" ]; then
  echo "ERROR: No API version output from the CM server." >&2
  exit 2
fi
# Strip the leading "v" from the version string so that we have a numeral.
_APINUM=${_API#v}

# Get the list of hostIds (and hostnames) for the given cluster.
CLUSTERS_OUTPUT=$(curl -skLu "${_USERNAME}:${_PASSWORD}" -X GET "http://${_CM}:${CMPORT}/api/${_API}/clusters")
if [ -z "$CLUSTERS_OUTPUT" ]; then
  echo "ERROR: No host output from the CM server." >&2
  exit 4
fi

# CM API greater than or equal to v6 uses displayName.
# Print the clusternames.
if [ "$_APINUM" -ge 6 ]; then
  echo "${CLUSTERS_OUTPUT}" | python -c 'import json, sys; obj=json.load(sys.stdin); print("\n".join([x["displayName"] for x in obj["items"]]))'
else
  echo "${CLUSTERS_OUTPUT}" | python -c 'import json, sys; obj=json.load(sys.stdin); print("\n".join([x["name"] for x in obj["items"]]))'
fi

