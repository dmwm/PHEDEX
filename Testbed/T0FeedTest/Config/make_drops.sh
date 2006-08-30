#!/bin/bash

echo "$0: $1 $2 $3 $4"
${T0FeedBasedir}/Bin/DropGenerator -input $1,$2,$3 -dataset $4 -block $4#1 -output ${T0FeedDropDir}
