# Pre-Engagement Evaluation

This script can be run on machines that will become a part of a Hadoop cluster before a Hadoop Installation Team arrives onsite (or is provided remote access) in order to help answer some of the questions that the Installation Team may have.  The bash script `evaluate.sh` can be downloaded or copied to each cluster node and executed, it's output saved and then transmitted to the Installation Team.

Note: This script does not require root level privileges and should be run as a non-root user.

There are several ways to provide some baseline data to the Hadoop Installation Team.

```
wget https://raw.githubusercontent.com/razorsedge/hadoop-deployment-bash/master/evaluate.sh
chmod 0755 evaluate.sh
```

Run the evaluation script to gather the configuration of all the nodes of the cluster.  Save the output in the directory "evaluate-pre".
```
mkdir evaluate-pre
for HOST in `cat HOSTLIST`; do
  echo "*** $HOST"
  scp -p evaluate.sh ${HOST}:
  ssh -q $HOST './evaluate.sh' >evaluate-pre/${HOST}.out 2>evaluate-pre/${HOST}.err
done
```

Feel free to look through the gathered data for anything you might feel concerned about sending to your Hadoop Installation Team.  Once it is ready, then bundle up the data.
```
tar zcvf YOURCOMPANYNAME-evaluate-pre.tar.gz evaluate-pre/
```

Once all the data has been gathered, email the tarball to the Installation Team Member who originally sent you this link.
