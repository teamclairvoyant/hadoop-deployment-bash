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

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
echo "Copying Kafka TLS certs and keys..."
install -m 0440 -o root -g kafka /opt/cloudera/security/jks/localhost-keystore.jks /opt/cloudera/security/jks/kafka-keystore.jks

