# Cluster Health Check

Three steps are required in order to gather the data required for a Health Check.  First is to gather OS-level data with the evaluate.sh script.  Next is to gather Hadoop cluster configuration data via Ambari or Cloudera Manager (whichever is present for the Hadoop distribution).  Last is to send that data to Clairvoyant.

## 1. evaluate.sh

This script should be run on machines that are a part of a Hadoop cluster in order to gather data for the Health Check.  The bash script `evaluate.sh` can be downloaded, copied to each cluster node, executed, it's output saved, and then transmitted back to Clairvoyant.

Note: This script mostly does not require root level privileges and can be run as a non-root user.  Only the logical volume, iptables, and RHEL subscription-manager commands use sudo.

First, download the `evaluate.sh` script to a local system and set the execute bits.  This local system could be a Linux workstation, Windows machine with a Cygwin installation, OS X laptop, or one of the Linux machines that is a part of the cluster.  It does not matter so long as it has SSH access to the cluster nodes.
```
wget https://raw.githubusercontent.com/teamclairvoyant/hadoop-deployment-bash/master/evaluate.sh
chmod 0755 evaluate.sh
```

Create the file HOSTLIST in the same directory.  You can use an editor like `vi` or `nano`.  Populate it with a list of hosts, one per line, upon which the script will be run.  Preceed each host with the username to use to log in and '@' symbol.  You can also use IP addresses if that is easier.  Example:
```
centos@host1.localdomain
centos@host2.localdomain
root@192.168.0.3
```

Run the evaluation script to gather the configuration of all the nodes of the cluster.  Save the output in the directory "evaluate".
```
mkdir evaluate
for HOST in `cat HOSTLIST`; do
  echo "*** $HOST"
  scp -p evaluate.sh ${HOST}:
  ssh -qt $HOST './evaluate.sh' >evaluate/${HOST}.out 2>evaluate/${HOST}.err
done
```

Feel free to look through the gathered data for anything you might feel concerned about sending to Clairvoyant.  Once it is ready, then bundle up the data.
```
tar zcvf YOURCOMPANYNAME-evaluate.tar.gz evaluate/
```

## 2a. Ambari Blueprint

An Ambari Blueprint defines the Stack version and service components for a cluster and is saved as JSON file. An Ambari administrator can export a blueprint after the cluster has been deployed.  If you have a Hortonworks cluster and Ambari, then you will need the following:

* Ambari server URL
* Ambari user credentials with admin privileges
* Cluster name

### Automated Steps:
First, download the `dump_ambari_blueprint.sh` script to a local system and set the execute bits.  This local system could be a Linux workstation, Windows machine with a Cygwin installation, OS X laptop, or one of the Linux machines that will become a part of the cluster.  It does not matter so long as it has the [cURL](http://curl.haxx.se/) program available.
```
wget https://raw.githubusercontent.com/teamclairvoyant/hadoop-deployment-bash/master/api/dump_ambari_blueprint.sh
chmod 0755 dump_ambari_blueprint.sh
```
Edit the file to set the Ambari user, password, hostname, and port.

Run the Blueprint dump script to gather the configuration of the cluster.
```
./dump_ambari_blueprint.sh >blueprint.json
```

### Manual Steps:
Execute API command:
```
_USER=
_PASSWD=
_AMHOST=
_CLUSTER=

# HTTP site:
curl -s -H 'X-Requested-By: ambari' -u "${_USER}:${_PASSWD}" "http://${_AMHOST}:8080/api/v1/clusters/${_CLUSTER}?format=blueprint" >blueprint.json

# HTTPS site:
curl -s -H 'X-Requested-By: ambari' -u "${_USER}:${_PASSWD}" -k "https://${_AMHOST}:8443/api/v1/clusters/${_CLUSTER}?format=blueprint" >blueprint.json
```

## 2b. Cloudera Manager Configuration

You can use the Cloudera Manager API to programmatically export a definition of all the entities in your Cloudera Manager-managed deployment—clusters, service, roles, hosts, users and so on.  If you have a Cloudera cluster and Cloudera Manager, then you will need the following:

* Cloudera Manager server URL
* Cloudera Manager user credentials with Full Admin privileges

### Automated Steps (CLI):
First, download the `dump_cm_config.sh` script to a local system and set the execute bits.  This local system could be a Linux workstation, Windows machine with a Cygwin installation, OS X laptop, or one of the Linux machines that will become a part of the cluster.  It does not matter so long as it has the [cURL](http://curl.haxx.se/) program available.
```
wget https://raw.githubusercontent.com/teamclairvoyant/hadoop-deployment-bash/master/api/dump_cm_config.sh
chmod 0755 dump_cm_config.sh
```
Edit the file to set the CM user, password, and hostname.

Run the CM dump script to gather the configuration of the environment.
```
./dump_cm_config.sh >cm_config.json
```

### Manual Steps (WebUI):
Log in to the Cloudera Manager server with a user that has the Full Admin privileges.  Then, modify the URL in your web browesr to have the following after the port number: `/api/v6/cm/deployment?view=export_redacted`

Example:
```
http://cmhost.localdomain:7180/api/v6/cm/deployment?view=export_redacted
```

### Manual Steps (CLI):
Execute API command:
```
_USER=
_PASSWD=
_CMHOST=

# HTTP site:
curl -s -u "${_USER}:${_PASSWD}" "http://${_CMHOST}:7180/api/v6/cm/deployment?view=export_redacted" >cm_config.json

# HTTPS site:
curl -s -u "${_USER}:${_PASSWD}" -k "https://${_CMHOST}:7183/api/v6/cm/deployment?view=export_redacted" >cm_config.json
```

## 3. Send Data

Once all the data has been gathered, email the tarball and any JSON file(s) to the Clairvoyant team member who originally sent you this link.

