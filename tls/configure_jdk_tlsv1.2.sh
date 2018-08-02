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
# Copyright Clairvoyant 2018

echo "********************************************************************************"
echo "*** $(basename $0)"
echo "********************************************************************************"
echo "Configuring JDK to disable all except TLS v1.2..."
if [ -f /etc/profile.d/jdk.sh ]; then
  . /etc/profile.d/jdk.sh
elif [ -f /etc/profile.d/java.sh ]; then
  . /etc/profile.d/java.sh
elif [ -d /usr/java/default ]; then
  JAVA_HOME=/usr/java/default
fi

if [ -z "${JAVA_HOME}" ]; then echo "ERROR: \$JAVA_HOME is not set."; exit 10; fi

if [ ! -f ${JAVA_HOME}/jre/lib/security/java.security-orig ]; then
  /bin/cp -p ${JAVA_HOME}/jre/lib/security/java.security ${JAVA_HOME}/jre/lib/security/java.security-orig
fi

if ! grep ^jdk.tls.disabledAlgorithms= ${JAVA_HOME}/jre/lib/security/java.security | grep -q "TLSv1.1, TLSv1,"; then
  sed -ie '/^jdk.tls.disabledAlgorithms=/s|SSLv3|TLSv1.1, TLSv1, SSLv3|' ${JAVA_HOME}/jre/lib/security/java.security
fi

