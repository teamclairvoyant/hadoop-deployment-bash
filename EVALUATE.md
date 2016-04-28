# Evaluation

There are several ways to provide some baseline data to the Hadoop Installation Team.

Run the evaluation script to gather the configuration of all the nodes of the cluster.  Save the output in the directory "evaluate-pre".
```
mkdir evaluate-pre
for HOST in `cat HOSTLIST`; do
  echo "*** $HOST"
  scp -p ${GITREPO}/evaluate.sh ${HOST}:
  ssh -q $HOST './evaluate.sh' >evaluate-pre/${HOST}.out 2>evaluate-pre/${HOST}.err
done
```

Or you can use mpssh and save the output in the directory "evaluate-pre".
```
mpssh -f HOSTLIST -r ${GITREPO}/evaluate.sh -o evaluate-pre
```

Or you can use mussh and print to the screen.
```
mussh -H HOSTLIST -m -b -C ${GITREPO}/evaluate.sh
```

