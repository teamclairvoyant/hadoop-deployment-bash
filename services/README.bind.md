# BIND Installation

This is a shell script to deploy [ISC BIND](https://www.isc.org/downloads/bind/) to a node.  The goal of the script is to be idempotent and to serve as a template for translation into other Configuration Management frameworks/languages.

* Tested on CentOS 6, CentOS 7, Ubuntu 14.04, and Ubuntu 16.04.

## Installation

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=localhost

scp -p -o StrictHostKeyChecking=no ${GITREPO}/services/install_bind.sh ${MACHINE}:
ssh -t $MACHINE 'sudo bash -x install_bind.sh'
```

No actual configuration of BIND is done.

