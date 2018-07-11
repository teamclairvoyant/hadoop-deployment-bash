# Cloudera Navigator Encrypt Installation

These are shell scripts to deploy [Cloudera Navigator Encrypt](https://www.cloudera.com/documentation/enterprise/latest/topics/sg_navigator_encrypt.html) to a node.  The goal of these scripts are to be idempotent and to serve as a template for translation into other Configuration Management frameworks/languages.

THESE SCRIPTS ASSUME THAT YOU HAVE READ THE NAVIGATOR ENCRYPT DOCUMENTATION NO LESS THAT FIVE TIMES.

DO NOT RUN THESE SCRIPTS FOR THE FIRST TIME ON YOUR PRODUCTION CLUSTER. OR YOUR DEVELOPMENT CLUSTER.

THESE SCRIPTS FORMAT DISKS, WIPE FILESYSTEMS, AND EAT BABIES.

* Assumes RHEL/CentOS 7 x86_64.

Scripts should be run in the following order:

* install_entropy.sh
* install_clouderanavigatorencrypt.sh
* navencrypt_register.sh
* navencrypt_evacuate.sh
* navencrypt_prepare.sh
* navencrypt_move.sh

Pass `--help` to each script to see the options.

## Installation

Read the details at [Installing Cloudera Navigator Encrypt](https://www.cloudera.com/documentation/enterprise/latest/topics/navigator_encrypt_install.html) in order to determine how to create the internal package repository containing the Navigator Encrypt packages.  Then run the script to install Navigator Encrypt on each host.

```
GITREPO=~/git/teamclairvoyant/bash
REPOHOST=yum.localdomain

for HOST in `cat HOSTLIST`; do
  echo "*** $HOST"
  scp -p -o StrictHostKeyChecking=no ${GITREPO}/install_clouderanavigatorencrypt.sh ${GITREPO}/install_entropy.sh ${HOST}:
  ssh -t $HOST "sudo bash install_entropy.sh; sudo bash install_clouderanavigatorencrypt.sh $REPOHOST"
done
```

## Configuration

You will need to have the [Cloudera Navigator Key Trustee Server](https://www.cloudera.com/documentation/enterprise/latest/topics/key_trustee_install.html) up and running under Cloudera Manager control before going any further.

[Register](https://www.cloudera.com/documentation/enterprise/latest/topics/navigator_encrypt_register.html) the Navigator Encrypt software with the Key Trustee Server:
```
GITREPO=~/git/teamclairvoyant/bash
NAVPASS=password            # Can be different on each host.  Do not lose it.
NAVSERVER1=kts1.localdomain
NAVSERVER2=kts2.localdomain # Skip if you only have one KTS server and you don't value your data.
                            # Also remove --passive-server from the below command.
MYORG=awesome_org           # Read the docs to determine this value.
KTPASS=password_from_kts    # Read the docs to determine this value.
KEYTYPE=single-passphrase

scp -p -o StrictHostKeyChecking=no ${GITREPO}/navencrypt/navencrypt_register.sh ${HOST}:
ssh -t $HOST "sudo bash navencrypt_register.sh --navpass $NAVPASS --server $NAVSERVER1 --passive-server $NAVSERVER2 --org $MYORG --auth $KTPASS --key-type $KEYTYPE"
```

THESE SCRIPTS FORMAT DISKS, WIPE FILESYSTEMS, AND EAT BABIES.

(Did you read the part of the docs that said the cluster should be stopped at this point?)

On the chance that you are bolting on Navigator Encrypt *after* you have built out your CDH cluster, run navencrypt_evacuate.sh on each disk/mountpoint in order to suffle your data around.  This may fill up the parent filesystem.
```
GITREPO=~/git/teamclairvoyant/bash
MOUNTPOINT=/data/0

scp -p -o StrictHostKeyChecking=no ${GITREPO}/navencrypt/navencrypt_evacuate.sh ${HOST}:
ssh -t $HOST "sudo bash navencrypt_evacuate.sh --mountpoint $MOUNTPOINT"
```

THESE SCRIPTS FORMAT DISKS, WIPE FILESYSTEMS, AND EAT BABIES.

[Encrypt](https://www.cloudera.com/documentation/enterprise/latest/topics/navigator_encrypt_prepare.html) the storage device.  Do this for each disk/mountpoint.
```
GITREPO=~/git/teamclairvoyant/bash
NAVPASS=password            # Can be different on each host.  Do not lose it.
DEVICE=/dev/sdb
EMOUNTPOINT=/navencrypt/0

scp -p -o StrictHostKeyChecking=no ${GITREPO}/navencrypt/navencrypt_prepare.sh ${HOST}:
ssh -t $HOST "sudo bash navencrypt_prepare.sh --navpass $NAVPASS --device $DEVICE --emountpoint $EMOUNTPOINT"
```

THESE SCRIPTS FORMAT DISKS, WIPE FILESYSTEMS, AND EAT BABIES.

(Did you read the part of the docs that said the cluster should be stopped at this point?)

[Move](https://www.cloudera.com/documentation/enterprise/latest/topics/navigator_encrypt_data.html) the data to the encrypted storage.  Do this for each disk/mountpoint.  This can take a while if there is a large amount of data.
```
GITREPO=~/git/teamclairvoyant/bash
NAVPASS=password            # Can be different on each host.  Do not lose it.
MOUNTPOINT=/data/0
EMOUNTPOINT=/navencrypt/0
CATEGORY=hadoop             # Can be whatever string you desire.  Is used by ACLs.

scp -p -o StrictHostKeyChecking=no ${GITREPO}/navencrypt/navencrypt_move.sh ${HOST}:
ssh -t $HOST "sudo bash navencrypt_move.sh --navpass $NAVPASS --mountpoint $MOUNTPOINT --emountpoint $EMOUNTPOINT --category $CATEGORY"
```

TODO: Insert notes about [ACLs](https://www.cloudera.com/documentation/enterprise/latest/topics/navigator_encrypt_acl.html) here.

