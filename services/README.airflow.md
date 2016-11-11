# Airflow Installation

These are shell scripts to deploy [Apache Airflow](http://airflow.incubator.apache.org/) and [RabbitMQ](https://www.rabbitmq.com/) to a node.  The goal of these scripts are to be idempotent and to serve as a template for translation into other Configuration Management frameworks/languages.

* Assumes RHEL/CentOS 7 x86_64.
* Assumes use of MySQL.

# Prep

Install MySQL somewhere.  (PostgreSQL is not presently supported by these install scripts.)  Amazon RDS works too in which case, do not run the below code segment.

```
yum -y -e1 -d1 install mariadb-server
service mariadb start
chkconfig mariadb on
mysqladmin password hahaha
```

# Installation

Run the script to create the Airflow database.
```
GITREPO=~/git/teamclairvoyant/bash
CMSERVER=localhost
MYSQL_USER=root
MYSQL_PASSWORD=hahaha
MYSQL_HOST=localhost

scp -p -o StrictHostKeyChecking=no ${GITREPO}/create_mysql_dbs-airflow.sh centos@${CMSERVER}:
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
ssh -t centos@${AIRFLOWSERVER} "sudo bash -x /home/centos/install_airflow.sh --mysqlhost $MYSQL_HOST \
 --mysqluser airflow --mysqlpassword $AFPASSWORD --rabbitmqhost localhost"
```
Grab the password for the admin user to the Airflow WebUI.
This will install the WebUI which has a login of admin:$AFPASSWORD at [http://localhost:8080/](http://localhost:8080/) .

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

