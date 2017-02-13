# Airflow Installation

These are shell scripts to deploy [Apache Airflow](http://airflow.incubator.apache.org/) and [RabbitMQ](https://www.rabbitmq.com/) to a node.  The goal of these scripts are to be idempotent and to serve as a template for translation into other Configuration Management frameworks/languages.

* Assumes RHEL/CentOS 7 x86_64.
* Assumes use of MySQL or PostgreSQL.

# MySQL
## Prep

Install MySQL somewhere.  Amazon RDS works too in which case, do not run the below code segment.

```
yum -y -e1 -d1 install mariadb-server
service mariadb start
chkconfig mariadb on
mysqladmin password hahaha
```

## Installation

Run the script to create the Airflow database.
```
GITREPO=~/git/teamclairvoyant/bash
CMSERVER=localhost
MYSQL_USER=root
MYSQL_PASSWORD=hahaha
MYSQL_HOST=localhost

scp -p -o StrictHostKeyChecking=no ${GITREPO}/services/create_mysql_dbs-airflow.sh centos@${CMSERVER}:
ssh -t centos@${CMSERVER} "sudo bash -x /home/centos/create_mysql_dbs-airflow.sh --host $MYSQL_HOST \
 --user $MYSQL_USER --password $MYSQL_PASSWORD"
```

Grab the password that is output from the above command and assign it to the AFPASSWORD variable.
Run the script to install RabbitMQ.  This will install the WebUI which has a default login of guest:guest at [http://localhost:15672/](http://localhost:15672/) .
```
AFPASSWORD=
AIRFLOWSERVER=localhost

scp -pr -o StrictHostKeyChecking=no ${GITREPO}/services/install_{airflow,rabbitmq}.sh \
 ${GITREPO}/services/airflow/ centos@${AIRFLOWSERVER}:
ssh -t centos@${AIRFLOWSERVER} 'sudo bash -x /home/centos/install_rabbitmq.sh'
```

Run the script to install Airflow.
```
ssh -t centos@${AIRFLOWSERVER} "sudo bash -x /home/centos/install_airflow.sh --dbtype mysql \
--dbhost $MYSQL_HOST --dbuser airflow --dbpassword $AFPASSWORD --rabbitmqhost localhost"
```
Grab the password that is output from the above command.  This is to login to the Airflow WebUI at [http://localhost:8080/](http://localhost:8080/) as the admin user.

Note: `install_airflow.sh` will take an arguement that is the version number of Airflow which you would like to install.  Otherwise, it will install the latest version.

# PostgreSQL
## Prep

Install PostgreSQL somewhere.  Amazon RDS works too in which case, do not run the below code segment.

```
yum -y -e1 -d1 install postgresql-server
postgresql-setup initdb
sed -e '/^host\s*all\s*all\s*127.0.0.1\/32\s*\sident$/i\
host    all             all             0.0.0.0/0               md5' \
    -i /var/lib/pgsql/data/pg_hba.conf
service postgresql restart
chkconfig postgresql on
su - postgres -c 'psql' <<EOF
\password
hahaha
hahaha
\q
EOF
```

## Installation

Run the script to create the Airflow database.
```
GITREPO=~/git/teamclairvoyant/bash
CMSERVER=localhost
PSQL_USER=postgres
PSQL_PASSWORD=hahaha
PSQL_HOST=localhost

scp -p -o StrictHostKeyChecking=no ${GITREPO}/services/create_postgresql_dbs-airflow.sh centos@${CMSERVER}:
ssh -t centos@${CMSERVER} "sudo bash -x /home/centos/create_postgresql_dbs-airflow.sh --host $PSQL_HOST \
 --user $PSQL_USER --password $PSQL_PASSWORD"
```

Grab the password that is output from the above command and assign it to the AFPASSWORD variable.
Run the script to install RabbitMQ.  This will install the WebUI which has a default login of guest:guest at [http://localhost:15672/](http://localhost:15672/) .
```
AFPASSWORD=
AIRFLOWSERVER=localhost

scp -pr -o StrictHostKeyChecking=no ${GITREPO}/services/install_{airflow,rabbitmq}.sh \
 ${GITREPO}/services/airflow/ centos@${AIRFLOWSERVER}:
ssh -t centos@${AIRFLOWSERVER} 'sudo bash -x /home/centos/install_rabbitmq.sh'
```

Run the script to install Airflow.
```
ssh -t centos@${AIRFLOWSERVER} "sudo bash -x /home/centos/install_airflow.sh --dbtype postgresql \
--dbhost $PSQL_HOST --dbuser airflow --dbpassword $AFPASSWORD --rabbitmqhost localhost"
```
Grab the password that is output from the above command.  This is to login to the Airflow WebUI at [http://localhost:8080/](http://localhost:8080/) as the admin user.

Note: `install_airflow.sh` will take an arguement that is the version number of Airflow which you would like to install.  Otherwise, it will install the latest version.

# Use

The AIRFLOW_HOME is in `/var/lib/airflow`.  Airflow job logs are stored in `/var/logs/airflow`.  Airflow daemon logs are inside systemd.

# Troubleshooting

Since this is EL7, use `journalctl` to find the daemon logs.
```
journalctl -u airflow-webserver.service
journalctl -u airflow-worker.service
journalctl -u airflow-kerberos.service
journalctl -u airflow-flower.service
journalctl -u airflow-scheduler.service
```

