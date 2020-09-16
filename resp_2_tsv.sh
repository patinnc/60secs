#!/bin/bash

SCR_DIR=`dirname $0`
echo "arg1 is RPS.json or response.json, arg2 is string for header, arg3 and arg4 are optional begin and end timestamp (usually from the json file itself"

FILE=
DESC=
BEG_IN=
END_IN=
SUM_FILE=
TYP_IN=
SHEET_NM=
OPTIONS=
MATCH_INTRVL=
OSTYP=$OSTYPE

while getopts "hvf:b:d:e:m:o:s:S:t:" opt; do
  case ${opt} in
    f )
      FILE=$OPTARG
      ;;
    b )
      BEG_IN=$OPTARG
      ;;
    d )
      DESC=$OPTARG
      ;;
    e )
      END_IN=$OPTARG
      ;;
    m )
      MATCH_INTRVL=$OPTARG
      ;;
    o )
      OPTIONS=$OPTARG
      ;;
    S )
      SHEET_NM=$OPTARG
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
      exit 1
      ;;
    : )
      echo "$0: Invalid option: $OPTARG requires an argument. cmdline= ${@}" 1>&2
      exit 1
      ;;
    \? )
      echo "$0: Invalid option: $OPTARG, cmdline= ${@}" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ "$FILE" == "" ]; then
  echo "$0: need -f json_filename"
  exit 1
fi
if [ ! -e $FILE ]; then
  echo "$0: didn't find -f $FILE json file"
  exit 1
fi
if [ "$DESC" == "" ]; then
  CK_TXT=`echo $FILE | sed 's/.json$/.txt/'`
  if [ "$CK_TXT" != "$FILE" ]; then
    if [ -e $CK_TXT ]; then
      DESC=`head -1 $CK_TXT`
      echo "$0: CK_TXT= $CK_TXT  DESC= $DESC" > /dev/stderr
    fi
  fi
fi
SZ_CMD=" -c%s "
if [[ "$OSTYP" == "darwin"* ]]; then
   # Mac OSX
   SZ_CMD=" -f %z "
fi
FILESIZE=$(stat $SZ_CMD "$FILE" | awk '{print $1}')
echo "file $FILE has size $FILESIZE"
if [ "$FILESIZE" == "0" ]; then
  echo "$0: filesize $FILE is zero"
  exit 0
fi
TYP=$HDR
FORCE_BEG=$BEG_IN
FORCE_END=$END_IN
PRF_FILE=(sys_*_perf_stat.txt)
if [ ! -e $PRF_FILE ]; then
  if [ "$FORCE_BEG" == "" ]; then
  echo "sorry but $0 depends (currently) on the $PRF_FILE existing in the cur dir, or get the 1st timestamp from the json file and pass it as arg3 to this script"
  exit 1
  fi
fi
if [ "$FORCE_BEG" == "" -o "$FORCE_END" == "" ]; then
  BEG=`cat 60secs.log | awk '{n=split($0, arr);printf("%s\n", arr[n]);exit;}'`
  DURA=`tail -1 $PRF_FILE | awk '{n=split($0, arr, ";");printf("%s\n", arr[1]);exit;}'`
  if [ "$END_IN" != "" ]; then END=$END_IN
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
O_OPT=
if [ "$OPTIONS" != "" ]; then
  O_OPT=" -o $OPTIONS "
fi
O_MATCH=
if [ "$MATCH_INTRVL" != "" ]; then
  O_MATCH=" -m $MATCH_INTRVL "
fi
OPT_SHEET_NM=
if [ "$SHEET_NM" != "" ]; then
  OPT_SHEET_NM=" -S $SHEET_NM "
fi
echo "python $SCR_DIR/json_2_tsv.py -f $FILE $O_OPT -d \"$DESC\" $O_MATCH -s $SUM_FILE $O_BEG $O_END $O_TYP $OPT_SHEET_NM " > /dev/stderr
      python $SCR_DIR/json_2_tsv.py -f $FILE $O_OPT -d "$DESC" $O_MATCH -s $SUM_FILE $O_BEG $O_END $O_TYP $OPT_SHEET_NM
      RC=$?
      exit $RC
#python ../json_2_tsv.py response_time.json $BEG $END
