#!/bin/bash
# shellcheck disable=SC2174
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

echo "********************************************************************************"
echo "*** $(basename "$0")"
echo "********************************************************************************"
echo "Making TLS security directories..."
mkdir -p -m 0755 /opt/hortonworks/security
mkdir -p -m 0755 /opt/hortonworks/security/x509
mkdir -p -m 0755 /opt/hortonworks/security/jks
mkdir -p -m 0755 /opt/hortonworks/security/CAcerts
mkdir -p -m 0755 /opt/hortonworks/security/keytabs
mkdir -p -m 0755 /opt/hortonworks/security/jaas
