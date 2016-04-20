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
centos@ip-10-2-6-62.ec2.internal
centos@ip-10-2-6-5.ec2.internal
centos@ip-10-2-5-22.ec2.internal
EOF

# Copy several of the scripts to the nodes.
for HOST in `cat HOSTLIST`; do
  echo "*** $HOST"
  scp -p ${GITREPO}/install_{tools,nscd,ntp,jdk,jce,clouderamanageragent}.sh \
  ${GITREPO}/change_swappiness.sh ${GITREPO}/configure_javahome.sh \
  ${GITREPO}/disable_{iptables,selinux,thp}.sh $HOST:
done

# Run the scripts to prep the system for Cloudera Manager installation.
CMVER=5
for HOST in `cat HOSTLIST`; do
  echo "*** $HOST"
  ssh -t $HOST "for Y in install_tools.sh change_swappiness.sh disable_iptables.sh \
  disable_selinux.sh disable_thp.sh install_ntp.sh install_nscd.sh install_jdk.sh \
  configure_javahome.sh install_jce.sh install_jdbc.sh ; do sudo bash -x \
  /home/centos/\${Y} '' $CMVER;done"
done

# Install the Cloudera Manager agent.
CMSERVER=ip-10-2-5-22.ec2.internal
for HOST in `cat HOSTLIST`; do
  echo "*** $HOST"
  ssh -t $HOST "sudo bash -x /home/centos/install_clouderamanageragent.sh $CMSERVER $CMVER"
done

# Install the Cloudera Manager server.
scp -p ${GITREPO}/install_clouderamanagerserver.sh centos@${CMSERVER}:
ssh -t centos@${CMSERVER} 'sudo bash -x /home/centos/install_clouderamanagerserver.sh embedded'
```

# License

Copyright (C) 2015 [Clairvoyant, LLC.](http://clairvoyantsoft.com/)

Licensed under the Apache License, Version 2.0.
