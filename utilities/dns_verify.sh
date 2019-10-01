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

PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin

echo "****************************************"
echo "*** DNS"
IPS=$(ip -4 a | awk '/inet/{print $2}' | grep -Ev '127.0.0.1|169.254.' | sed -e 's|/[0-9].*$||')
# shellcheck disable=SC2116,SC2086
IP=$(echo $IPS)
NUMIPS=$(echo "$IPS" | wc -l)
_HOSTNAME=$(hostname)
if [ "$NUMIPS" -gt 1 ]; then
  DNSMULTIPLE=true
  echo "DNS: Multiple IPs present."
  echo "** system IPs are: $IP"
else
  DNSMULTIPLE=false
  echo "** system IP is: $IP"
fi
echo "** system hostname is: ${_HOSTNAME}"
# How are the dig and Python methods subtly different?
#
# How do you know if the proper DNS tools were used (dig) vs the Python method
# (which I am told does things a little differently)?
# DNS tools provide the trailing dot on the forward result...
if command -v dig >/dev/null 2>&1; then
  echo "DNS: dig"
  ADDR=$(dig "$(hostname)" +short)
  HOST=$(dig -x "$ADDR" +short)
  ADDR2=$(dig "$HOST" +short)
  # Remove the trailing dot.
  HOST=${HOST%.}
else
  echo "DNS: Python"
  HOST=$(python -c 'import socket; print socket.getfqdn()')
  ADDR=$(python -c 'import socket; print socket.gethostbyname(socket.getfqdn())')
  # shellcheck disable=SC2086
  ADDR2=$(python -c 'import socket; print socket.gethostbyname("'$HOST'")')
fi
echo "** DNS forward is: $HOST"
echo "** DNS reverse is: $ADDR"
# Make sure that hostname matches DNS FQDN and both IP lookups match each other.
if [ "$_HOSTNAME" == "$HOST" ] && [ "$ADDR" == "$ADDR2" ]; then
  # Then make sure the IP lookup matches one of the system IPs.
  if [ "${DNSMULTIPLE}" == true ]; then
    DNSMATCH=false
    for X in $IP; do
      if [ "$X" == "$ADDR" ]; then
        DNSMATCH=true
        echo "DNS does match."
      fi
    done
    if [ "$DNSMATCH" == false ]; then
      echo "DNS does not match."
    fi
  else
    if [ "$IP" == "$ADDR" ]; then
      echo "DNS does match."
    else
      echo "DNS does not match."
    fi
  fi
else
  echo "DNS does not match."
fi
