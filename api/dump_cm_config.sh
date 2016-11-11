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
# Copyright Clairvoyant 2016

##### START CONFIG ###################################################

APIUSER=
APIPASS=
CMHOST=
CMPORT=7180
#CURLDEBUG="-i"

##### STOP CONFIG ####################################################
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
CMSCHEME=http

if [ "$CMPORT" -eq 7183 ]; then
  CMSCHEME=https
  OPT="-k"
fi

BASEURL=$CMSCHEME://$CMHOST:$CMPORT
API=v5

curl -s $OPT -u "${APIUSER}:${APIPASS}" $CURLDEBUG "${BASEURL}/api/${API}/cm/deployment?view=export_redacted"

