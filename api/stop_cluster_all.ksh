#!/bin/ksh
#
# Stop Cloudera-Manager-managed environment via the REST API
#
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
# Copyright Clairvoyant 2016
#
if [ $DEBUG ]; then set -x; fi
#
##### START CONFIG ###################################################

# Maximum time (in seconds) before giving up
TIMEOUT=300
#CURLDEBUG="-k"

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
CMPORT=7180
CMSCHEME=http

# Function to print the help screen.
print_help () {
  print "Usage:  $1 -u <username> -p <password> -H <host> [-P <port>]"
  print "        $1 [-h|--help]"
  print "        $1 [-v|--version]"
  print "   ex.  $1 -u admin -p admin -H localhost"
  print "   ex.  $1 -u api -p passw0rd -H remotehost -P 7183"
  exit 1
}

# Function to check for root priviledges.
check_root () {
  if [[ `/usr/bin/id | awk -F= '{print $2}' | awk -F"(" '{print $1}' 2>/dev/null` -ne 0 ]]; then
    print "You must have root priviledges to run this program."
    exit 2
  fi
}

# If the variable DEBUG is set, then turn on tracing.
# http://www.research.att.com/lists/ast-users/2003/05/msg00009.html
if [ $DEBUG ]; then
  # This will turn on the ksh xtrace option for mainline code
  set -x

  # This will turn on the ksh xtrace option for all functions
  typeset +f |
  while read F junk
  do
    typeset -ft $F
  done
  unset F junk
fi

# Process arguments.
while [[ $1 = -* ]]; do
  case $1 in
    -u|--user)
      shift
      CMUSERNAME=$1
      ;;
    -p|--password)
      shift
      CMPASSWORD=$1
      ;;
    -H|--host)
      shift
      CMHOST=$1
      ;;
    -P|--port)
      shift
      CMPORT=$1
      ;;
    -h|--help)
      print_help "$(basename $0)"
      ;;
    -v|--version)
      print "\tStop Cloudera Manager managed environment via the REST API"
      exit 0
      ;;
    *)
      print_help "$(basename $0)"
      ;;
  esac
  shift
done

# Check to see if we have no parameters.
if [[ -z "$CMUSERNAME" || -z "$CMPASSWORD" || -z "$CMHOST" ]]; then print_help "$(basename $0)"; fi

if ! which jq >/dev/null; then
  echo "ERROR: the jq command is missing.  Please install it."
  exit 3
fi

# Lets not bother continuing unless we have the privs to do something.
#check_root

# main
# Restart and monitor the service

if [ "$CMPORT" -eq 7183 ]; then
  CMSCHEME=https
fi

BASEURL=$CMSCHEME://$CMHOST:$CMPORT

RETVAL=1
API=`curl -s -u "${CMUSERNAME}:${CMPASSWORD}" $CURLDEBUG "${BASEURL}/api/version"`
RETVAL=$?
# Loop until we make contact with the SCM server.
until [ "$RETVAL" -eq 0 ]; do
  echo "** Sleeping 60 seconds..."
  sleep 60
  API=`curl -s -u "${CMUSERNAME}:${CMPASSWORD}" $CURLDEBUG "${BASEURL}/api/version"`
  RETVAL=$?
done

start=`date '+%s'`

echo "** Gathering list of clusters..."
CLUSTERS=`curl -s -X GET -u "${CMUSERNAME}:${CMPASSWORD}" $CURLDEBUG \
  ${BASEURL}/api/${API}/clusters | jq -r '.items[].name'`

for NAME in $CLUSTERS; do
  echo "** Entering Maintenence Mode for Cluster ${NAME}..."
  curl -s -X POST -u "${CMUSERNAME}:${CMPASSWORD}" $CURLDEBUG \
    -H "content-type:application/json" \
    ${BASEURL}/api/${API}/clusters/${NAME}/commands/enterMaintenanceMode >/dev/null

  echo -n "** Stopping Cluster ${NAME} "
  curl -s -X POST -u "${CMUSERNAME}:${CMPASSWORD}" $CURLDEBUG \
    -H "content-type:application/json" \
    ${BASEURL}/api/${API}/clusters/${NAME}/commands/stop >/dev/null

  while ! curl -s -u "${CMUSERNAME}:${CMPASSWORD}" $CURLDEBUG \
          ${BASEURL}/api/${API}/clusters/${NAME} \
          | jq -r '.entityStatus' | grep -q STOPPED ; do
    now=`date '+%s'`
    if [ $(($now - $start)) -gt $TIMEOUT ] ; then
      echo
      echo "ERROR: timed out after $TIMEOUT seconds"
      exit 1
    fi
    echo -n "."
    sleep 5
  done
  echo "done"
done

echo "** Stopping Cloudera Management Services..."
curl -s -X POST -u "${CMUSERNAME}:${CMPASSWORD}" $CURLDEBUG \
  -H "content-type:application/json" \
  ${BASEURL}/api/${API}/cm/service/commands/stop >/dev/null
echo "** Sleeping 60 seconds..."
sleep 60

