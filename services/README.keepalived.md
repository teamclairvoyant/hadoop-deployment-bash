# Keepalived for HAProxy Installation

This is a shell script to deploy [Keepalived](https://www.keepalived.org/) to a node which is also setup to run [HAProxy](https://www.haproxy.org/).  Administrators can use both [Keepalived and HAProxy](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/load_balancer_administration/s2-lvs-keepalived-haproxy-vsa) together for a more robust and scalable high availability environment.  The goal of the script is to be idempotent and to serve as a template for translation into other Configuration Management frameworks/languages.

* Tested on CentOS 7.

## Installation

Multiple nodes will need to be setup *identically* with HAProxy and Keepalived.

```
GITREPO=~/git/teamclairvoyant/bash
MACHINES="hosta hostB"

for HOST in $MACHINES; do
  scp -p -o StrictHostKeyChecking=no ${GITREPO}/services/install_haproxy_keepalived.sh ${HOST}:
  ssh -t $HOST 'sudo bash install_haproxy_keepalived.sh -t backup -i 10.0.0.41 -r 51 -P changeme'
done
```

