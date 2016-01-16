# hadoop-deployment-bash

These are shell scripts to deploy Cloudera Manager and related Cloudera encryption products to a cluster.

* Assumes RHEL/CentOS 6 or 7 x86_64.
* Allows for installation of Oracle JDK 7 or 8 from Cloudera or Oracle.

This is an example of some of the functionality.  Not everything is documented.  Some scripts have arguments that can be passed to them to change their internal operation.  Read the source to learn more.

# Example

Set the GITREPO variable to the local directory where you have cloned this repository.

```
GITREPO=~/git/teamclairvoyant/bash

cat <<EOF >HOSTLIST
centos@10.2.6.62
centos@10.2.6.5
centos@10.2.5.22
EOF

# Copy several of the scripts to the nodes.
for HOST in `cat HOSTLIST`; do
  echo "*** $HOST"
  scp -p ${GITREPO}/install_{tools,ntp,jdk,jce,jdbc,clouderamanageragent}.sh \
  ${GITREPO}/change_swappiness.sh ${GITREPO}/configure_javahome.sh \
  ${GITREPO}/disable_{iptables,selinux,thp}.sh $HOST:
done

# Run the scripts to prep the system for Cloudera Manager installation.
for HOST in `cat HOSTLIST`; do
  echo "*** $HOST"
  ssh -t $HOST 'for X in install_tools.sh change_swappiness.sh disable_iptables.sh \
  disable_selinux.sh disable_thp.sh install_ntp.sh install_jdk.sh configure_javahome.sh \
  install_jce.sh install_jdbc.sh ; do sudo bash -x /home/centos/${X};done'
done

# Install the Cloudera Manager agent.
CMSERVER=ip-10-2-5-22.ec2.internal
for HOST in `cat HOSTLIST`; do
  echo "*** $HOST"
  ssh -t $HOST "sudo bash -x /home/centos/install_clouderamanageragent.sh $CMSERVER"
done

# Install the Cloudera Manager server.
SCMSERVER=10.2.5.22
scp -p ${GITREPO}/install_clouderamanagerserver.sh centos@${SCMSERVER}:
ssh -t centos@${SCMSERVER} 'sudo bash -x /home/centos/install_clouderamanagerserver.sh'
```

# License

Copyright (C) 2015 [Clairvoyant, LLC.](http://clairvoyantsoft.com/)

Licensed under the Apache License, Version 2.0.
