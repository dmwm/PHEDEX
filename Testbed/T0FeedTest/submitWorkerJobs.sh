#!/bin/sh

if [ X = X$1 ]; then
    echo "argument missing !! Please give amount of jobs you want to submit"
    exit 1
fi


for (( i = 1; $i <= $1; i += 1 )); do
   bsub -q dedicated -R itdccms "source ${T0FeedBasedir}/Config/env.sh; ${T0FeedBasedir}/run_StorageManagerWorker.sh"
done

