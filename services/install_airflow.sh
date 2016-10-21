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

exit 1

#UID="-u 999"
#GID="-g 999"
if [ -n "$1" ]; then
  VERSION="==$1"
fi

groupadd $GID -r airflow
useradd $UID -g airflow -c "Airflow Daemon" -d /var/lib/airflow -r airflow

install -o root -g root -m0644 airflow/*.service /etc/systemd/system/
install -o root -g root -m0644 airflow/airflow /etc/sysconfig/airflow
install -o root -g root -m0644 airflow/airflow.conf /etc/tmpfiles.d/airflow.conf

sed -e '/^AIRFLOW_HOME=/d' -i /etc/sysconfig/airflow
echo "AIRFLOW_HOME=/var/lib/airflow" >>/etc/sysconfig/airflow

yum -y -e1 -d1 groupinstall "Development tools"
yum -y -e1 -d1 install zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel python-devel wget cyrus-sasl-devel.x86_64

#yum -y -e1 -d1 install epel-release
#yum -y -e1 -d1 install python-pip
yum -y -e1 -d1 install python-setuptools
easy_install pip

pip install airflow${VERSION}
pip install airflow[hive]
pip install airflow[celery]

#####
yum -y -e1 -d1 install mysql-devel
#pip install MySQL-python
yum -y -e1 -d1 install MySQL-python
#pip install airflow[mysql]

#su -u airflow -c 'export AIRFLOW_HOME=~/airflow airflow initdb'

#pip install airflow[kerberos]
#pip install airflow[crypto]
#pip install airflow[jdbc]
#pip install airflow[hdfs]
#pip install airflow[ldap]
#pip install airflow[password]
#pip install airflow[rabbitmq]
#pip install airflow[s3]

