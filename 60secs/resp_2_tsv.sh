#!/bin/bash

SCR_DIR=`dirname $0`
echo "arg1 is RPS.json or response.json, arg2 is string for header, arg3 and arg4 are optional begin and end timestamp (usually from the json file itself"

FILE=
BEG_IN=
END_IN=
SUM_FILE=
TYP_IN=

while getopts "hvf:b:e:s:" opt; do
  case ${opt} in
    f )
      FILE=$OPTARG
      ;;
    b )
      BEG_IN=$OPTARG
      ;;
    e )
      END_IN=$OPTARG
      ;;
    s )
      SUM_FILE=$OPTARG
      ;;
    t )
      HDR=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 split data files into columns"
      echo "Usage: $0 [-h] -f json_file -t header [ -b beg_timestamp -e end_timestamp ] -s summary_filename [-v]"
      echo "   -v verbose mode"
      exit
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      exit
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      exit
      ;;
  esac
done
shift $((OPTIND -1))

if [ "$FILE" == "" ]; then
  echo "need -f json_filename"
  exit
fi
if [ ! -e $FILE ]; then
  echo "didn't find -f $FILE json file"
  exit
fi
TYP=$HDR
FORCE_BEG=$BEG_IN
FORCE_END=$END_IN
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
  if [ "$END_IN" != "" ]; then
    END=$END_IN
  else
    END=`awk -v beg="$BEG" -v dura="$DURA" 'BEGIN{printf("%f\n", beg+dura);exit;}'`
  fi
else
  BEG=$FORCE_BEG
  END=$FORCE_END
fi

echo "beg= $BEG, DURA= $DURA, end= $END"
O_BEG=
if [ "$BEG" != "" ]; then
  O_BEG=" -b $BEG "
fi
O_END=
if [ "$END" != "" ]; then
  O_END=" -e $END "
fi
O_TYP=
if [ "$TYP" != "" ]; then
  O_TYP=" -t $TYP "
fi
python $SCR_DIR/json_2_tsv.py -f $FILE -s $SUM_FILE $O_BEG $O_END $O_TYP
#python ../json_2_tsv.py response_time.json $BEG $END
