# hadoop-deployment-bash

* Assumes RHEL/CentOS 6 & 7 x86_64.
* Allows for Oracle JDK 7 or 8 from Cloudera or Oracle.

This is an example of some of the functionality.  Not everything is documented.  Some scripts hace arguments that can be passed to them to change their internal operation.

Set the GITREPO variable to the local directory where you have cloned this repository.

```
GITREPO=~/git/teamclairvoyant/bash

cat <<EOF >HOSTLIST
centos@10.2.6.62
centos@10.2.6.5
centos@10.2.5.22
EOF


for HOST in `cat HOSTLIST`; do
  echo "*** $HOST"
  scp -p ${GITREPO}/install_{tools,ntp,jce,jdbc,krb5,clouderamanageragent,sssd}.sh \
  ${GITREPO}/update_hosts.sh ${GITREPO}/change_swappiness.sh ${GITREPO}/configure_javahome.sh \
  ${GITREPO}/disable_{iptables,selinux,thp}.sh $HOST:
done

for HOST in `cat HOSTLIST`; do
  echo "*** $HOST"
  ssh -t $HOST 'for X in install_tools.sh update_hosts.sh change_swappiness.sh disable_iptables.sh \
  disable_selinux.sh disable_thp.sh install_ntp.sh configure_javahome.sh install_jce.sh install_jdbc.sh \
  install_krb5.sh; do sudo bash -x /home/centos/${X};done'
done

CMSERVER=ip-10-2-5-22.ec2.internal
for HOST in `cat HOSTLIST`; do
  echo "*** $HOST"
  ssh -t $HOST "sudo bash -x /home/centos/install_clouderamanageragent.sh $CMSERVER"
done

SCMSERVER=10.2.5.22
scp -p ${GITREPO}/install_clouderamanagerserver.sh centos@${SCMSERVER}:
ssh -t centos@${SCMSERVER} 'sudo bash -x /home/centos/install_clouderamanagerserver.sh'
```

