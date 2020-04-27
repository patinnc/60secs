#!/bin/bash

PID=`ps -ef |grep -v grep |grep -v kafk |grep java | awk '{print $2}'`
echo "PID= $PID"
DTE=`date +%s.%N`
HST=`hostname`
LOG=gnb.txt
echo "begin= $DTE host= $HST" >> $LOG

for i in `seq 0 600`; do
 ./get_numa.sh $PID  > tmp.jnk
 grep "%mem" tmp.jnk >> $LOG
 cat tmp.jnk
 sleep 1
done
