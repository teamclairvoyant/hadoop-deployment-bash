# Cloudera Director Installation

These are shell scripts to deploy [Cloudera Director](https://www.cloudera.com/products/product-components/cloudera-director.html) to a node.  The goal of these scripts are to be idempotent and to serve as a template for translation into other Configuration Management frameworks/languages.

* Tested on RHEL/CentOS 7.

## Installation

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=somehost

scp -p ${GITREPO}/director/install_clouderadirector.sh ${MACHINE}:
ssh -t $MACHINE 'sudo bash install_clouderadirector.sh'
```

## Using MySQL for Cloudera Director Storage
### Prep

Install MySQL somewhere.  Amazon RDS works too in which case, do not run the below code segment.

```
GITREPO=~/git/teamclairvoyant/bash

scp -p i${GITREPO}/director/director.cnf ${GITREPO}/services/install_mysql.sh ${MACHINE}:
ssh -t $MACHINE 'sudo cp -p director.cnf /tmp; sudo bash install_mysql.sh'
```
Grab the password that is output from the above command and assign it to the MYSQL_PASSWORD variable.

Run the script to create the Director database and user.
```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=somehost
MYSQL_USER=root
MYSQL_PASSWORD=
MYSQL_HOST=localhost

scp -p ${GITREPO}/services/create_mysql_dbs-director.sh ${MACHINE}:
ssh -t $MACHINE "sudo bash create_mysql_dbs-director.sh --host $MYSQL_HOST \
 --user $MYSQL_USER --password $MYSQL_PASSWORD"
```

### Configuration
Grab the password that is output from the above command and assign it to the CDPASSWORD variable.
Run the script to reconfigure Director to use MySQL for it's database.
```
CDPASSWORD=
CDUSER=director

scp -p ${GITREPO}/director/configure_clouderadirector-mysql.sh ${MACHINE}:
ssh -t $MACHINE "configure_clouderadirector-mysql.sh --host $MYSQL_HOST \
 --user $CDUSER --password $CDPASSWORD"
```

