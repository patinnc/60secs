#!/bin/bash

SCR_DIR=`dirname $0`
echo "arg1 is RPS.json or response.json, arg2 is string for header, arg3 and arg4 are optional begin and end timestamp (usually from the json file itself"
FILE=$1
if [ "$FILE" == "" ]; then
  echo "1st arg is json filename"
  exit
fi
if [ ! -e $FILE ]; then
  echo "1st arg is json filename and file $FILE not found"
  exit
fi
STR=$2
FORCE_BEG=$3
FORCE_END=$4
PRF_FILE=(sys_*_perf_stat.txt)
if [ ! -e $PRF_FILE ]; then
  if [ "$FORCE_BEG" == "" ]; then
  echo "sorry but $0 depends (currently) on the $PRF_FILE existing in the cur dir, or get the 1st timestamp from the json file and pass it as arg3 to this script"
  exit
  fi
fi
if [ "$FORCE_BEG" == "" -o "$FORCE_END" == "" ]; then
  BEG=`cat 60secs.log | awk '{n=split($0, arr);printf("%s\n", arr[n]);exit;}'`
  DURA=`tail -1 $PRF_FILE | awk '{n=split($0, arr, ";");printf("%s\n", arr[1]);exit;}'`
  END=`awk -v beg="$BEG" -v dura="$DURA" 'BEGIN{printf("%f\n", beg+dura);exit;}'`
else
  BEG=$FORCE_BEG
  END=$FORCE_END
fi

echo "beg= $BEG, DURA= $DURA, end= $END"
python $SCR_DIR/json_2_tsv.py $FILE $BEG $END $STR
#python ../json_2_tsv.py response_time.json $BEG $END
