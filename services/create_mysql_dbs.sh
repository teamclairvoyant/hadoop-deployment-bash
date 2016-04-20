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

MYSQL_HOST=localhost
MYSQL_USER=root
MYSQL_PASSWORD=""

if rpm -q redhat-lsb-core; then
  OSREL=`lsb_release -rs | awk -F. '{print $1}'`
else
  OSREL=`rpm -qf /etc/redhat-release --qf="%{VERSION}\n"`
fi
if [ $OSREL == 6 ]; then
  yum -y -e1 -d1 install mysql
else
  yum -y -e1 -d1 install mariadb
fi
echo mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e 'CREATE DATABASE rman DEFAULT CHARACTER SET utf8;'
echo mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e "GRANT ALL ON rman.* TO 'rman'@'%' IDENTIFIED BY 'RMANDB_PASSWORD';"
echo mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e 'CREATE DATABASE nav DEFAULT CHARACTER SET utf8;'
echo mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e "GRANT ALL ON nav.* TO 'nav'@'%' IDENTIFIED BY 'NAVDB_PASSWORD';"
echo mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e 'CREATE DATABASE navms DEFAULT CHARACTER SET utf8;'
echo mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e "GRANT ALL ON navms.* TO 'navms'@'%' IDENTIFIED BY 'NAVMSDB_PASSWORD';"
echo mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e 'CREATE DATABASE metastore DEFAULT CHARACTER SET utf8;'
echo mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e "GRANT ALL ON metastore.* TO 'hive'@'%' IDENTIFIED BY 'METASTOREDB_PASSWORD';"
echo mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e 'CREATE DATABASE oozie DEFAULT CHARACTER SET utf8;'
echo mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e "GRANT ALL ON oozie.* TO 'oozie'@'%' IDENTIFIED BY 'OOZIEDB_PASSWORD';"
echo mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e 'CREATE DATABASE sentry DEFAULT CHARACTER SET utf8;'
echo mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e "GRANT ALL ON sentry.* TO 'sentry'@'%' IDENTIFIED BY 'SENTRYDB_PASSWORD';"
echo mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e 'CREATE DATABASE hue DEFAULT CHARACTER SET utf8;'
echo mysql -h $MYSQL_HOST -u $MYSQL_USER -p${MYSQL_PASSWORD} -e "GRANT ALL ON hue.* TO 'hue'@'%' IDENTIFIED BY 'HUEDB_PASSWORD';"

