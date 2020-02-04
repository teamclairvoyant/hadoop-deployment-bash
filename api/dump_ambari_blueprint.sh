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

##### START CONFIG ###################################################

APIUSER=
APIPASS=
AMHOST=
AMPORT=8080
#CURLDEBUG="-i"

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
AMSCHEME=http

if [ "$AMPORT" -eq 8443 ]; then
  AMSCHEME=https
  OPT="-k"
fi

BASEURL=$AMSCHEME://$AMHOST:$AMPORT
API=v1

# shellcheck disable=SC2086
_CLUSTER=$(curl -s $OPT -u "${APIUSER}:${APIPASS}" $CURLDEBUG -H 'X-Requested-By: ambari' "${BASEURL}/api/${API}/clusters" | python -c 'import json, sys; obj=json.load(sys.stdin); print("\n".join([x["Clusters"]["cluster_name"] for x in obj["items"]]))')

# shellcheck disable=SC2086
curl -s $OPT -u "${APIUSER}:${APIPASS}" $CURLDEBUG -H 'X-Requested-By: ambari' "${BASEURL}/api/${API}/clusters/${_CLUSTER}?format=blueprint"

