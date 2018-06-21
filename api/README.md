# API Tools

## Cloudera Manager API Client (Python)

This is a shell script to deploy [Cloudera Manager API Client](https://cloudera.github.io/cm_api/) Python bindings to a node.  The goal of the script is to be idempotent and to serve as a template for translation into other Configuration Management frameworks/languages.

### Installation

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=somehost

scp -p -o StrictHostKeyChecking=no ${GITREPO}/api/install_cm_api.sh ${MACHINE}:
ssh -t $MACHINE 'sudo bash -x install_cm_api.sh'
```

## Cloudera Manager Configuration Backup

This is a shell script that will dump out the Cloudera Manager cluster configuration to a file every night via a cronjob.  It assumes that it is running on the same host as the CM server, that the CM server is not using TLS, that the default admin username and password are available, and that the user named "api" does not exist.  Otherwise, the variables at the top of the script will need to be modified.  The Cloudera Manager cluster configuration will be stored in the file /var/log/cm_config.dump .

### Installation

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=cmserver

scp -p -o StrictHostKeyChecking=no ${GITREPO}/api/install_dump_cm_config.sh \
  ${GITREPO}/api/dump_cm_config.sh ${MACHINE}:
ssh -t $MACHINE 'sudo bash -x install_dump_cm_config.sh -u admin -p admin -H localhost -P 7180'
```

Grab the passwords that are output from the above command.

## Start/Stop All Cloudera Manager Clusters

This is a shell script that will install two scripts to start and stop all clsuters controled by Cloudera Manager.

### Installation

```
GITREPO=~/git/teamclairvoyant/bash
MACHINE=somehost

scp -p -o StrictHostKeyChecking=no ${GITREPO}/api/install_startstop_cluster.sh \
  ${GITREPO}/api/{start,stop}_cluster_all.ksh ${MACHINE}:
ssh -t $MACHINE 'sudo bash -x install_startstop_cluster.sh'
```
