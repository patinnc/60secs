#!/bin/bash

GOT_QUIT=0
# function called by trap
catch_signal() {
    printf "\rSIGINT caught      "
    GOT_QUIT=1
}

trap 'catch_signal' SIGINT

j=0
MX=$1
BEG=`date +"%s"`
if [ "$MX" != "" ]; then
  END=$((BEG+MX))
fi
while [ "$GOT_QUIT" == "0" ]; do
  sleep 1
  j=$((j+1))
  if [ "$MX" != "" ]; then
    CUR=`date +"%s"`
    if [[ $CUR -ge $END ]]; then
       echo "got elapsed secs > end"
       break
    fi
    #if [[ $j -ge $MX ]]; then
    #  echo "got iters j= $j >= $MX"
    #  exit 0
    #fi
  fi
done
CUR=`date +"%s"`
DFF=$((CUR-BEG))
echo "$0.$LINENO elapsed time $DFF seconds. bye"
exit 0
