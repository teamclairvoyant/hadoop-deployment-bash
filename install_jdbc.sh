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
# Copyright Clairvoyant 2015

INSTALLDB=$1
if [ -z "$INSTALLDB" ]; then
  INSTALLDB=yes
fi
if rpm -q jdk >/dev/null; then
  HAS_JDK=yes
else
  HAS_JDK=no
fi
if [ "$INSTALLDB" = yes ]; then
  yum -y -e1 -d1 install mysql-connector-java postgresql-jdbc
  if [ $HAS_JDK = no ]; then yum -y -e1 -d1 remove jdk; fi
else
  if [ "$INSTALLDB" = mysql ]; then
    yum -y -e1 -d1 install mysql-connector-java
    if [ $HAS_JDK = no ]; then yum -y -e1 -d1 remove jdk; fi
  elif [ "$INSTALLDB" = postgresql ]; then
    yum -y -e1 -d1 install postgresql-jdbc
  else
    echo "** ERROR: Argument must be either mysql or postgresql."
  fi
fi

