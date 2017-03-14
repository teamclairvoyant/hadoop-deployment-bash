# Kerberos Installation

This is a shell script to deploy [MIT Kerberos](https://web.mit.edu/kerberos/) to a node, tune it for secure Hadoop use, and add an administrative principal for Cloudera Manager.  The goal of the script is to be idempotent and to serve as a template for translation into other Configuration Management frameworks/languages.

* Tested on RHEL/CentOS 6 and 7, Debian 7, and Ubuntu 14.04.

## Installation

```
GITREPO=~/git/teamclairvoyant/bash
KDC=localhost
REALM=HADOOP.COM
PRINC=cloudera-scm

scp -p -o StrictHostKeyChecking=no ${GITREPO}/services/install_kdc.sh ${KDC}:
ssh -t $KDC "sudo bash -x install_kdc.sh --realm $REALM --cm_principal $PRINC"
```

Grab the passwords that are output from the above command.

KDC : passsword1
cloudera-scm@HADOOP.COM : passsword2

