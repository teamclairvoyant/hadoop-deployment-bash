# Pre-Engagement Evaluation

This script can be run on machines that will become a part of a Hadoop cluster before a Hadoop Installation Team arrives onsite (or is provided remote access) in order to help answer some of the questions that the Installation Team may have.  The bash script `evaluate.sh` can be downloaded or copied to each cluster node and executed, it's output saved and then transmitted to the Installation Team.

Note: This script mostly does not require root level privileges and can be run as a non-root user.  Only the logical volume commands use sudo.

First, download the `evaluate.sh` script to a local system and set the execute bits.  This local system could be a Linux workstation, Windows machine with a Cygwin installation, OS X laptop, or one of the Linux machines that will become a part of the cluster.  It does not matter so long as it has SSH access to the cluster nodes.
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

Run the evaluation script to gather the configuration of all the nodes of the cluster.  Save the output in the directory "evaluate-pre".
```
mkdir evaluate-pre
for HOST in `cat HOSTLIST`; do
  echo "*** $HOST"
  scp -p evaluate.sh ${HOST}:
  ssh -qt $HOST './evaluate.sh' >evaluate-pre/${HOST}.out 2>evaluate-pre/${HOST}.err
done
```

Feel free to look through the gathered data for anything you might feel concerned about sending to your Hadoop Installation Team.  Once it is ready, then bundle up the data.
```
tar zcvf YOURCOMPANYNAME-evaluate-pre.tar.gz evaluate-pre/
```

Once all the data has been gathered, email the tarball to the Installation Team Member who originally sent you this link.
