# HAproxy Installation

This is a shell script to deploy [HAproxy](https://www.haproxy.org/) to a node.  The goal of the script is to be idempotent and to serve as a template for translation into other Configuration Management frameworks/languages.

* Tested on CentOS 7.

## Installation

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=localhost

scp -p -o StrictHostKeyChecking=no ${GITREPO}/services/install_haproxy.sh ${MACHINE}:
ssh -t $MACHINE 'sudo bash install_haproxy.sh'
```

No actual configuration of HAproxy is done although commented examples are
provided in the /etc/haproxy/haproxy.cfg configuration file.

