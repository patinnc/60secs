#!/bin/bash
#SCR_DIR=`dirname $(readlink -e $0)`
#SCR_DIR=`dirname $0`
#SCR_DIR=`dirname "$(readlink -f "$0")"`
SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo "SCR_DIR= $SCR_DIR" > /dev/stderr


declare -a REGEX
DIR=
PHASE_FILE=
OPT_OPT_DEF=chart_new,dont_sum_sockets
XLSX_FILE=
END_TM=
SKIP_XLS=0
NUM_DIR=0
NUM_DIR_BEG=
AVERAGE_END=
MAX_VAL=
TS_INIT=
VERBOSE=0
CLIP=
G_SUM=()
OPTIONS=
INPUT_FILE_LIST=
AVG_DIR=
DESC_FILE=
OSTYP=$OSTYPE
NUM_CPUS=0
FAIL=0
IFS_SV=$IFS
PY_PID=
BK_PID=()
BK_DIR=()
if [[ "$OSTYP" == "linux-gnu"* ]]; then
   NUM_CPUS=`grep -c processor /proc/cpuinfo`
elif [[ "$OSTYP" == "darwin"* ]]; then
   # Mac OSX
   NUM_CPUS=`sysctl -a | grep machdep.cpu.thread_count | awk '{v=$2+0;printf("%d\n", v);exit;}'`
elif [[ "$OSTYP" == "cygwin" ]]; then
   # POSIX compatibility layer and Linux environment emulation for Windows
   NUM_CPUS=`grep -c processor /proc/cpuinfo`
elif [[ "$OSTYP" == "msys" ]]; then
   # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
   NUM_CPUS=`grep -c processor /proc/cpuinfo`
elif [[ "$OSTYP" == "win32" ]]; then
   # I'm not sure this can happen.
   NUM_CPUS=4
elif [[ "$OSTYP" == "freebsd"* ]]; then
   # ...
   NUM_CPUS=`grep -c processor /proc/cpuinfo`
else
   # Unknown.
   NUM_CPUS=4
fi
# on macbook could do sysctl -a | grep machdep.cpu.thread_count
BACKGROUND=$(($NUM_CPUS+2))  # setting this to 0 turns off launching sys_2_tsv.sh in the background
echo "$0 ${@}"
echo "BACKGROUND= $BACKGROUND  NUM_CPUS= $NUM_CPUS"
JOB_ID=0

while getopts "hvASa:b:B:c:D:d:e:F:g:I:j:m:N:o:P:r:X:x:" opt; do
  case ${opt} in
    A )
      AVERAGE=1
      ;;
    S )
      SKIP_XLS=$(($SKIP_XLS+1))
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    a )
      AVG_DIR=$OPTARG
      ;;
    b )
      BEG_TM_IN=$OPTARG
      ;;
    B )
      BACKGROUND_IN=$OPTARG
      ;;
    c )
      CLIP=$OPTARG
      ;;
    D )
      DEBUG_OPT=$OPTARG
      ;;
    d )
      DIR=$OPTARG
      echo "$0.$LINENO input DIR= $DIR"
      ;;
    e )
      END_TM_IN=$OPTARG
      ;;
    F )
      DESC_FILE=$OPTARG
      ;;
    g )
      G_SUM+=("$OPTARG")
      ;;
    I )
      INPUT_FILE_LIST=$OPTARG
      ;;
    j )
      JOB_ID=$OPTARG
      ;;
    m )
      MAX_VAL=$OPTARG
      ;;
    N )
      NUM_DIR_IN=$OPTARG
      ;;
    o )
      OPTIONS=$OPTARG
      ;;
    P )
      PHASE_FILE=$OPTARG
      ;;
    r )
      REGEX+=($OPTARG)
      ;;
    X )
      AXLSX_FILE=$OPTARG
      ;;
    x )
      XLSX_FILE=$OPTARG
      ;;
    h )
      echo "$0 split data files into columns"
      echo "Usage: $0 [-h] -d sys_data_dir [-v] [ -p prefix ]"
      echo "   -a avg_dir requires -A. Average tsv files will be put in this dir"
      echo "   -A   flag indicating you want to average the same file from multiple dirs into 1 sheet."
      echo "          The default is to create 1 sheet per file per directory"
      echo "   -b begin_timestamp  exclude data until this timestamp (UTC timestamp)"
      echo "   -B background_processs_allowed  max background processes allowed. if 0 then no background processes. default is $BACKGROUND"
      echo "   -d dir containing sys_XX_* files created by 60secs.sh"
      echo "   -D debug_opt_strings    used for debugging"
      echo "   -F desc_file  file containing 1 line of text describing the results dir. Currently this is just the gen_xls.sh cmdline."
      echo "      this file can be used to identify breaks in the chart_sheet rows of charts. All charts with the same desc_file will be put be put on the same line"
      echo "   -g key=val    key value pairs to be added to summary sheet. use multiple -g k=v options to specify multiple key value pairs"
      echo "   -I file_with_list_of_input_files   used for getting a specify list of file proccessed"
      echo "   -j job_id   if you are doing more than 1 dir and running jobs in background then this id is used to create unique input filenames for tsv_2_xlsx.py"
      echo "   -m max_val    any value in chart > this value will be replaced by 0.0"
      echo "   -N number_of_dirs | beg_dir_num,end_dir_num  if you have more than 1 directories then you can limit the num of dirs with this option. Default process all"
      echo "      if you enter beg_dir_num,end_dir_num  then dirs numbering from beg_dir_num to end_dir_num are selected."
      echo "   -o options       comma separated options."
      echo "         'do_sum_sockets' if the perf stat data is per-socket then sum per-socket data to the system level"
      echo "         'dont_sum_sockets' if the perf stat data is per-socket then don't sum per-socket data to the system level"
      echo "         'line_for_scatter' substitute line charts for the scatter plots"
      echo "         'drop_summary' don't add a sheet for each summary sheet (if you are doing more than 1 dir). Just do the sum_all sheet"
      echo "         'chart_sheet' put all the charts on a separate sheet"
      echo "         'all_charts_one_row' put all the charts for a workbook on one row"
      echo "         'match_itp_muttley_interval' if you have itp/perf stat and muttley data, try to match the muttley interval to the perf interval"
      echo "           say the perf stat interval is 30 seconds and the muttley interval is 10 seconds. You might want to have the same number of rows of data"
      echo "           in the muttley tables as in perf stat data. So there are 3 muttley records for every 1 perf stat record. So only use the 3rd muttley record."
      echo "           this requires getting the perf stat interval from the run_itp.log file"
      echo "         'pidstat_dont_add_pid' don't add the pid to process name. Allows better matching if doing multple servers"
      echo "         'sum_file_no_formula' for non-combined summary sheets, don't use the excel formula to compute the average on the summary sheet"
      echo "           this can be useful if you are using compare_summary_table.sh to create a comparison of multiple summary sheets"
      echo "         'get_max_val' when consolidating values for spreadsheet, don't get the avareage value, get the max value"
      echo "         'get_perf_stat_max_val' when consolidating values for spreadsheet, don't get the avareage value, get the max value, this one is for perf_stat_scatter.awk"
      echo "   -P phase_file"
      echo "   -r regex   regex expression to select directories"
      echo "   -S    skip creating detail xlsx file, just do the summary all spreadsheet"
      echo "   -x xlsx_filename  This is passed to tsv_2_xlsx.py as the name of the xlsx. (you need to add the .xlsx)"
      echo "      The default is chart_line.xlsx"
      echo "   -X xlsx_filename  like above but assume path relative to current dir"
      echo "   -e ending_timestamp  cut off data files at this timestamp"
      echo "      useful for runs that mess up before the expected end time"
      echo "   -v verbose mode"
      exit
      ;;
    : )
      echo "$0.$LINENO Invalid option: $OPTARG requires an argument ${@}" 1>&2
      exit
      ;;
    \? )
      echo "$0.$LINENO Invalid option: $OPTARG ${@}" 1>&2
      exit
      ;;
  esac
done
shift $((OPTIND -1))
remaining_args="$@"

ck_last_rc() {
   local RC=$1
   local FROM=$2
   if [ $RC -gt 0 ]; then
      echo "$0: got non-zero RC=$RC at $LINENO. called from line $FROM" > /dev/stderr
      exit $RC
   fi
}

if [ "$remaining_args" != "" ]; then
  echo "$0.$LINENO remaining args= $remaining_args"
  echo "$0.$LINENO got args leftover. Usually due to * in -d dir_name option"
  exit
fi

if [ "$BACKGROUND_IN" != "" ]; then
   BACKGROUND=$BACKGROUND_IN
fi

SUM_ALL_AVG_BY_METRIC=
if [ "$OPTIONS" != "" ]; then
   lkfor="sum_all_avg_by_metric{"
   if [[ $OPTIONS == *"$lkfor"* ]]; then
       rest=${OPTIONS#*$lkfor}
       echo $(( ${#OPTIONS} - ${#rest} - ${#lkfor} ))
       echo "$0.$LINENO got $lkfor, rest= $rest"
       lkfor="}"
       #rest2=${rest#*$lkfor}
       pfx=${rest%%$lkfor*}
       echo "$0.$LINENO options: sum_all_avg_by_metric=\"${pfx}\""
       SUM_ALL_AVG_BY_METRIC="$pfx"
   fi
fi

if [ "$NUM_DIR_IN" != "" ]; then
  NUM_DIR_ARR=()
  IFS=',' read -r -a NUM_DIR_ARR <<< "$NUM_DIR_IN"
  IFS=$IFS_SV
  echo "NUM_DIR_ARR= ${NUM_DIR_ARR[@]}, BM0= ${NUM_DIR_ARR[0]}, BM1=${NUM_DIR_ARR[1]}" > /dev/stderr
  NUM_DIR_BEG=${NUM_DIR_ARR[0]}
  NUM_DIR_END=${NUM_DIR_ARR[1]}
  if [ "$NUM_DIR_END" == "" ]; then
    # only 1 value entered. Treat it as a 'read this many files' 
    NUM_DIR=$NUM_DIR_BEG
    NUM_DIR_BEG=
  fi
  echo "NUM_DIR_ARR= ${NUM_DIR_ARR[@]}, ND0= ${NUM_DIR_ARR[0]}, ND1=${NUM_DIR_ARR[1]} NUM_DIR_BEG= $NUM_DIR_BEG NUM_DIR_END= $NUM_DIR_END" > /dev/stderr
fi

REGEX_LEN=${#REGEX[@]}

SKIP_SYS_2_TSV=0
if [ "$OPTIONS" != "" ]; then
  if [[ $OPTIONS == *"skip_sys_2_tsv"* ]]; then
     SKIP_SYS_2_TSV=1
  fi
fi

INPUT_DIR=$DIR

if [ $VERBOSE -gt 0 ]; then
  echo "$0.$LINENO SKIP_XLS= $SKIP_XLS"
fi

get_abs_filename() {
  # $1 : relative filename
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

export AWKPATH=$SCR_DIR

get_dir_list() {
   local CKF=$1
   DIR=$2
   local RESP
   echo "$0.$LINENO get_dir_list: found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
   #RESP=`find $DIR -name $CKF -print0 | sort -z | xargs -0 cat`
   if [ "$REGEX_LEN" != "0" ]; then
      RESP2=`find $DIR -name $CKF -print | sort`
      RESP=$RESP2
      local ii
      for ii in ${REGEX[@]}; do
         RESP=`echo -e "$RESP" | grep "$ii"`
      done
      mydir=`echo -e "$RESP" | wc -l`
      echo "$0.$LINENO mydir count= $mydir"
   else
      RESP=`find $DIR -name $CKF -print | sort | xargs `
   fi
   echo "$0.$LINENO get_dir_list: found $CKF file in dir $DIR:"
   local STR=
   local j=0
   for ii in $RESP; do
      NM=$(dirname $ii)
      j=$((j+1))
      if [ "$NUM_DIR" != "" -a "$NUM_DIR" != "0" -a $NUM_DIR -gt 0 -a $j -ge $NUM_DIR ]; then
         echo "$0.$LINENO  job_id= $JOB_ID limit number of dirs with $CKF due to -N $NUM_DIR option"
         break
      fi
      if [ "$NUM_DIR_BEG" != "" ]; then
         if [ "$j" -lt "$NUM_DIR_BEG" ]; then
         echo "$0.$LINENO  job_id= $JOB_ID skip dir $j due to -N $NUM_DIR_IN option" > /dev/stderr
         continue
         fi
      fi
      if [ "$NUM_DIR_END" != "" ]; then
         if [ "$j" -gt "$NUM_DIR_END" ]; then
         echo "$0.$LINENO  job_id= $JOB_ID skip dir $j due to -N $NUM_DIR_IN option" > /dev/stderr
         continue
         fi
      fi
      STR="$STR $NM"
   done
   DIR=$STR
   echo "$0.$LINENO +___________-- get_dir_list: j= $j DIR= $DIR" > /dev/stderr
   #exit 1
}

OPT_a=
if [ "$AVG_DIR" != "" ]; then
  if [ "$AVERAGE" == "0" ]; then
     echo "$0: cmdline options has -a $AVG_DIR but you didn't specify -A option. Bye" > /dev/stderr
     exit
  fi
  if [ -d $AVG_DIR ]; then
    mkdir -p "$AVG_DIR"
  fi
  AVG_DIR=$(get_abs_filename "$AVG_DIR")
  OPT_a=" -a $AVG_DIR "
fi
if [ "$DESC_FILE" != "" ]; then
   if [ $VERBOSE -gt 0 ]; then
     echo "$0.$LINENO DESC_FILE= $DESC_FILE" > /dev/stderr
   fi
   DESC_FILE=$(get_abs_filename "$DESC_FILE")
   if [ $VERBOSE -gt 0 ]; then
     echo "$0.$LINENO DESC_FILE= $DESC_FILE" > /dev/stderr
   fi
fi

if [ "$INPUT_FILE_LIST" != "" ]; then
  if [ -e $INPUT_FILE_LIST ]; then
    echo "$0.$LINENO got input_file_list= $INPUT_FILE_LIST"
  fi
else
   DIR_ORIG=$DIR
   CKF=60secs.log
   GOT_DIR=0
   RESP=`find $DIR -name $CKF | wc -l | awk '{$1=$1;print}'`
   if [ $VERBOSE -gt 0 ]; then
     echo "$0.$LINENO RESP= 60secs.log = $RESP"
   fi
   if [ $RESP -gt 0 ]; then
       get_dir_list $CKF $DIR
       echo "$0.$LINENO found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
       GOT_DIR=1
   fi
   if [ $RESP -eq 0 ]; then
     if [ $VERBOSE -gt 0 ]; then
       echo "$0.$LINENO didn't find 60secs.log file under dir $DIR. Bye"
     fi
     CKF="metric_out"
     RESP=`find $DIR -name $CKF | wc -l | awk '{$1=$1;print}'`
     if [ "$RESP" == "0" ]; then
     CKF="metric_out.tsv"
     RESP=`find $DIR -name $CKF | wc -l | awk '{$1=$1;print}'`
       #echo "found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
     fi
     if [ "$RESP" == "0" ]; then
     CKF="metric_out.csv"
     RESP=`find $DIR -name $CKF | wc -l | awk '{$1=$1;print}'`
       #echo "found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
     fi
     if [ "$RESP" == "0" ]; then
     CKF="metric_out.csv.tsv"
     RESP=`find $DIR -name $CKF | wc -l | awk '{$1=$1;print}'`
     fi
     if [ "$RESP" != "0" ]; then
       echo "$0.$LINENO found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
       get_dir_list $CKF $DIR
       GOT_DIR=1
       echo "$0.$LINENO using1 DIR= $DIR, orig DIR= $DIR_ORIG"
     fi
     if [ "$GOT_DIR" == "0" ]; then
       CKF="sys_*_perf_stat.txt"
       RESP=`find $DIR -name "$CKF" | wc -l | awk '{$1=$1;print}'`
       if [ $VERBOSE -gt 0 ]; then
         echo "$0.$LINENO got29 $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one." > /dev/stderr
       fi
       if [ "$RESP" == "0" ]; then
         CKF="sys_*_perf_stat.txt*"
         RESP=`find $DIR -name "$CKF" | wc -l | awk '{$1=$1;print}'`
         if [ $VERBOSE -gt 0 ]; then
           echo "$0.$LINENO got $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one." > /dev/stderr
         fi
       fi
       if [ "$RESP" != "0" ]; then
         if [ $VERBOSE -gt 0 ]; then
           echo "$0.$LINENO found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one." > /dev/stderr
         fi
         RESP=`find $DIR -name "$CKF"|sort`
         if [ "$REGEX_LEN" != "0" ]; then
           RESP=`find $DIR -name "$CKF" | sort`
           for ii in ${REGEX[@]}; do
             RESP=`echo -e "$RESP" | grep "$ii"`
           done
           RESP3=`echo "$RESP" | wc -l`
           if [ $VERBOSE -gt 0 ]; then
             echo "$0.$LINENO mydir count= $mydir, resplines= $RESP3"
           fi
         fi
         if [ $VERBOSE -gt 0 ]; then
           echo "$0.$LINENO found51 $CKF file in dir $DIR"
         fi
         STR=
         j=0
         GOT_TS_INIT=0
         for ii in $RESP; do
           NM=$(dirname $ii)
           NUM_LINES=`head -10 $ii | wc -l |awk '{$1=$1;printf("%d\n", $1);}'`
           if [ $NUM_LINES -lt 10 ]; then
             # the sys_*_perf_stat.txt file can get created with just one line in it if perf isn't present
             # so don't include dirs with empty data
             if [ -e $NM/run.log ]; then
#20201203_201403 1607055243.064233658 start  -p /mnt/root/output/onprem_rome_combo_32cpus_v10 -I 0 -i 1 -d 7200
#20201203_204129 1607056889.971113020 end elapsed_secs 1646.906879
               TS_INIT=`awk '/start/{if ($3 == "start") {print $2;exit;}}' $NM/run.log`
               if [ "$TS_INIT" != "" ]; then
                 GOT_TS_INIT=1
               fi
               echo "$0.$LINENO: ck $NM/run.log got TS_INIT= $TS_INIT"
             fi
             if [ "$GOT_TS_INIT" != "1" ]; then
              if [ $VERBOSE -gt 0 ]; then
               echo "$0.$LINENO skip $CKF file in dir $DIR due to too few lines= $NUM_LINES"
             fi
               continue
             fi
           fi
           if [ $GOT_TS_INIT == 0 -a $j -eq 0 ]; then
             TS_INIT=`awk '
  function dt_to_epoch(offset) {
     if (date_str == "") {
        return 0.0;
     }
     months="  JanFebMarAprMayJunJulAugSepOctNovDec";
     n=split(date_str, darr, /[ :]+/);
     mnth_num = sprintf("%d", index(months, darr[1])/3);
     dt_str = darr[6] " " mnth_num " " darr[2] " " darr[3] " " darr[4] " " darr[5];
     epoch = mktime(dt_str);
     return epoch + offset;
  }
  /epoch\tts\trel_ts\tinterval/ {
    getline;
    ts=$1 - $2;
    printf("%f\n", ts);
    exit;
  }
  /^# started on / {
    # started on Fri Jun 12 14:36:31 UTC 2020 1591972591.618156223
    # started on Fri Jun 12 14:36:31 2020
    pos = index($0, " on ")+8;
    date_str = substr($0, pos);
    if ($8 == "UTC") {
       if (NF == 10) {
          ts_initial = $10+0;
          printf("%s\n", $10);
          exit;
       }
       date_str = $5 " " $6 " " $7 " " $9;
    }
    tst_epoch = dt_to_epoch(0.0);
    printf("%s\n", tst_epoch);
       exit
    }' $ii`
             #TS_INIT=
            if [ $VERBOSE -gt 0 ]; then
             echo "$0.$LINENO first sys_*_perf_stat.txt TS_INIT= $TS_INIT" > /dev/stderr
             echo "$0.$LINENO first sys_*_perf_stat.txt TS_INIT= $TS_INIT"
            fi
           fi
      if [ "$NUM_DIR_BEG" != "" ]; then
         if [ "$j" -lt "$NUM_DIR_BEG" ]; then
         #echo "$0.$LINENO  job_id= $JOB_ID skip dir $j due to -N $NUM_DIR_IN option" > /dev/stderr
         j=$((j+1))
         continue
         fi
      fi
      if [ "$NUM_DIR_END" != "" ]; then 
         if [ "$j" -gt "$NUM_DIR_END" ]; then
           #echo "$0.$LINENO  job_id= $JOB_ID skip dir $j due to -N $NUM_DIR_IN option" > /dev/stderr
           j=$((j+1))
           continue
         fi
      fi
      j=$((j+1))
      STR="$STR $NM"
           if [ "$NUM_DIR" != "" -a $NUM_DIR -gt 0 -a $j -ge $NUM_DIR ]; then
              echo "$0.$LINENO  job_id= $JOB_ID limit number of dirs due to -N $NUM_DIR option"
              break
           fi
         done
         DIR=$STR
         #echo "$0.$LINENO: -__________- using2 DIR= $DIR, orig DIR= $DIR_ORIG" > /dev/stderr
       else
         echo "$0.$LINENO: didn't find 60secs.log nor metric_out nor sys_*_perf_stat.txt file under dir $DIR at line $LINENO Bye"
         exit
       fi
     fi
   else
     if [ "$GOT_DIR" == "0" ]; then
     echo "$0.$LINENO found54 $RESP 60secs.log file(s) under dir $DIR. Using the dir of first one if more than one."
     RESP=`find $DIR -name 60secs.log | head -1`
     echo "$0.$LINENO found 60secs.log file in dir $RESP"
     DIR=$(dirname $RESP)
     echo "$0.$LINENO using3 DIR= $DIR, orig DIR= $DIR_ORIG"
     fi
   fi
fi


LST=$DIR
if [ $VERBOSE -gt 0 ]; then
  echo "$0.$LINENO DIR at 35: $DIR"
fi
#exit

CDIR=`pwd`
ALST=$CDIR/tsv_2_xlsx_${JOB_ID}.inp
#echo "ALST= $ALST"
if [ -e $ALST ]; then
  rm $ALST
fi
OXLS=tmp.xlsx
if [ "$AXLSX_FILE" != "" ]; then
  OXLS=${AXLSX_FILE}_all.xlsx
fi

shopt -s nullglob
echo -e "-o\t$OXLS" >> $ALST
FCTRS=
SVGS=
SUM_FILE=sum.tsv

if [ $VERBOSE -gt 0 ]; then
  echo "$0.$LINENO LST= $LST" > /dev/stderr
fi

DIR_1ST_DIR=
if [ "$INPUT_FILE_LIST" == "" ]; then
  NUM_DIRS=0
  for i in $LST; do
    if [ $NUM_DIRS -eq 0 ]; then
      DIR_1ST_DIR=$i
    fi
    #echo "$0.$LINENO dir_num= $NUM_DIRS dir= $i"
    NUM_DIRS=$((NUM_DIRS+1))
  done
fi

TS_BEG=`date +%s`
if [ "$INPUT_FILE_LIST" == "" ]; then
oIFS=$IFS
DIR_NUM_MX=0
for i in $LST; do
 DIR_NUM_MX=$(($DIR_NUM_MX+1))
done
DIR_NUM=0
for i in $LST; do
 OPT_DESC_FILE=
 if [ "$DESC_FILE" == "" ]; then
   if [ -e $i/desc.txt ]; then
      FLS=$(get_abs_filename "$i/desc.txt")
      if [ -e $FLS ]; then
        OPT_DESC_FILE="$FLS"
      fi
   fi
 fi
 if [ $VERBOSE -gt 0 ]; then
   pushd $i
 else
   pushd $i > /dev/null
 fi
 pd=$(pwd)
 str=`echo "${pd##*/}"`
 if [ "$str" != "60secs" ]; then
   XLS=$str
 fi
 if [ $VERBOSE -gt 0 ]; then
   echo "$0.$LINENO XLS= $XLS" > /dev/stderr
 fi
 RPS=`echo $i | sed 's/rps_v/rpsv/' | sed 's/rps.*_.*/rps/' | sed 's/.*_//' | sed 's/\/.*//'`
 RPS="${RPS}"
 if [ "$RPS" == "" ]; then
   RPS="1rps"
 fi
 if [ "$SUM_FILE" != "" ]; then
   if [ -e $SUM_FILE ]; then
     rm $SUM_FILE
   fi
 fi
 FCTR=`echo $RPS | sed 's/rps//'`
 FCTR=`awk -v fctr="$FCTR" 'BEGIN{fctr += 0.0; mby=1.0; if (fctr >= 100.0) {mby=0.001;} if (fctr == 0.0) {fctr=1.0;mby=1.0;} printf("%.3f\n", mby*fctr); exit;}'`
 if [ $VERBOSE -gt 0 ]; then
   echo "$0.$LINENO rps= $RPS, fctr= $FCTR"
 fi
 if [ "$XLSX_FILE" != "" ]; then
   XLS=$XLSX_FILE
 fi
 if [ "$AXLSX_FILE" != "" ]; then
   XLS=$CDIR/$AXLSX_FILE
 fi
 OPT_PH=
 if [ "$PHASE_FILE" != "" ]; then
    OPT_PH=" -P $PHASE_FILE "
 fi
 OPT_BEG_TM=
 if [ "$TS_INIT" != "" ]; then
    OPT_BEG_TM=" -b $TS_INIT "
 fi
 if [ "$BEG_TM_IN" != "" ]; then
    OPT_BEG_TM=" -b $BEG_TM_IN "
    echo "$0.$LINENO: BEG_TM= $BEG_TM_IN"
  echo "$0.$LINENO ____got BEG_TM_IN=\"$BEG_TM_IN\"" > /dev/stderr
 fi
 OPT_END_TM=
 if [ "$END_TM_IN" != "" ]; then
    OPT_END_TM=" -e $END_TM_IN "
 fi
 OPT_SKIP=
 if [ "$SKIP_XLS" -gt "0" ]; then
   OPT_SKIP=" -S "
 fi
 OPT_M=
 if [ "$MAX_VAL" != "" ]; then
   OPT_M=" -m $MAX_VAL "
 fi
 OPT_CLIP=
 if [ "$CLIP" != "" ]; then
   OPT_CLIP=" -c $CLIP "
 fi
 OPT_DEBUG=
 if [ "$DEBUG_OPT" != "" ]; then
   OPT_DEBUG=" -D $DEBUG_OPT "
 fi
 OPT_OPT=
 if [ "$OPTIONS" != "" ]; then
   OPT_OPT="$OPTIONS "
 else
   OPT_OPT=$OPT_OPT_DEF
 fi
 OPT_A=
 if [ "$AVERAGE" != "0" ]; then
   if [ $NUM_DIRS -gt 1 ]; then
     OPT_A=" -A "
   fi
 fi
 OPT_G=
 if [ "$G_SUM" != "" ]; then
   for g in "${G_SUM[@]}"; do
      OPT_G+=" -g $g "
      #echo "$0.$LINENO build g opt= $OPT_G"
   done
   echo "$0.$LINENO new g opt= $OPT_G"
 fi
 if [ -e $CDIR/job_${JOB_ID}.stop ]; then
    RESP=`head -1 $CDIR/job_${JOB_ID}.stop`
    echo "$0: got job_$JOB_ID.stop pid= $RESP and bashpid= $$" > /dev/stderr
    if [ "$RESP" == "$$" ]; then
      echo "$0: quitting at line $LINENO due to job_$JOB_ID.stop having value PID= $$"
      exit 1
    fi
 fi
 if [ "$SKIP_SYS_2_TSV" == "0" ]; then
   SYS_2_TSV_STDOUT_FILE=tmp.jnk
   if [ $VERBOSE -gt 0 ]; then
     echo "$SCR_DIR/sys_2_tsv.sh -B $CDIR $OPT_a $OPT_A $OPT_G -j $JOB_ID -p \"$RPS\" $OPT_DEBUG $OPT_SKIP $OPT_M -d . $OPT_CLIP $OPT_BEG_TM $OPT_END_TM -i \"*.png\" -s $SUM_FILE -x $XLS.xlsx -o $OPT_OPT $OPT_PH -t $DIR &> $SYS_2_TSV_STDOUT_FILE" &
   fi
   if [ "$BACKGROUND" -le "0" ]; then
          $SCR_DIR/sys_2_tsv.sh -B $CDIR $OPT_a $OPT_A $OPT_G -j $JOB_ID -p "$RPS" $OPT_DEBUG $OPT_SKIP $OPT_M -d . $OPT_CLIP $OPT_BEG_TM $OPT_END_TM -i "*.png" -s $SUM_FILE -x $XLS.xlsx -o $OPT_OPT $OPT_PH -t $DIR &> $SYS_2_TSV_STDOUT_FILE
          RC=$?
          ck_last_rc $RC $LINENO
   else
          $SCR_DIR/sys_2_tsv.sh -B $CDIR $OPT_a $OPT_A $OPT_G -j $JOB_ID -p "$RPS" $OPT_DEBUG $OPT_SKIP $OPT_M -d . $OPT_CLIP $OPT_BEG_TM $OPT_END_TM -i "*.png" -s $SUM_FILE -x $XLS.xlsx -o $OPT_OPT $OPT_PH -t $DIR &> $SYS_2_TSV_STDOUT_FILE &
          LPID=$!
          RC=$?
          BK_DIR[$LPID]=$i
          BK_OUT[$LPID]=$SYS_2_TSV_STDOUT_FILE
          if [ $VERBOSE -gt 0 ]; then
            echo "$0.$LINENO LPID= $LPID, RC= $RC"
          fi
   fi
     LOAD=`uptime | awk '{printf("%.0f\n", $(NF-2)+0.5);}'`
     jbs=0
     for job in `jobs -p`
     do
       #echo $job
       jbs=$((jbs+1))
     done
     #echo "$0.$LINENO job_id= $JOB_ID jbs= $jbs LOAD= $LOAD BACKGROUND= $BACKGROUND" > /dev/stderr
     jbs=$(($jbs+$LOAD))
   if [ "$jbs" -gt "$BACKGROUND" ]; then
     #jbs=0
     for job in `jobs -p`
     do
       TS_CUR=`date +%s`
       TS_DFF=$(($TS_CUR-$TS_BEG))
       echo "$0.$LINENO: job_id= $JOB_ID wait for jobs (jbs= $jbs) pid= $job, dir_num= $DIR_NUM of $DIR_NUM_MX, elap_secs= $TS_DFF, load= $LOAD"
       jbs=$((jbs-1))
       wait $job
       RC=$?
       if [ "$RC" != "0" ]; then
          echo "$0: sys_2_tsv.sh got error! bye at $LINENO" > /dev/stderr
          echo "$0: look at ${BK_OUT[$LPID]} file in last data dir for error messages" > /dev/stderr
          echo "$0: dir= ${BK_DIR[$job]}"
          exit 1
       fi
       if [ "$jbs" -lt "$BACKGROUND" ]; then
         break
       fi
     done
   fi
 fi
 TS_CUR=`date +%s`
 TS_DFF=$(($TS_CUR-$TS_BEG))
 if [ $VERBOSE -gt 0 ]; then
   echo "$0.$LINENO FLS: job_id= $JOB_ID dir_num= ${DIR_NUM} of ${DIR_NUM_MX}, elap_tm= $TS_DFF secs, ${FLS}" > /dev/stderr
 fi
 DIR_NUM=$(($DIR_NUM+1))
 if [ $VERBOSE -gt 0 ]; then
   popd
 else
   popd > /dev/null
 fi
done

wait_for_all() {
     jbs=0
     for job in `jobs -p`
     do
       echo "$0.$LINENO wait for jobs (jbs= $jbs) pid= $job"
       wait $job
       RC=$?
       #if [ "$RC" == "1" -o "$RC" == "2" ]; then
       if [ "$RC" != "0" ]; then
          echo "$0: sys_2_tsv.sh got error RC= \"$RC\"! at $LINENO. bye. called by line $1" > /dev/stderr
          echo "$0: look at ${BK_OUT[$job]} in last data dir for error messages" > /dev/stderr
          echo "$0: dir= ${BK_DIR[$job]}"
          tail -20 ${BK_DIR[$job]}/${BK_OUT[$job]}
          exit 1
       fi
     done
}

wait_for_all $LINENO

MUTT_ARR=()
for i in $LST; do
 if [ $VERBOSE -gt 0 ]; then
   pushd $i
 else
   pushd $i > /dev/null
 fi
 if [ "$PHASE_FILE" == "" ]; then
    RESP=phase_cpu2017.txt
    if [ $VERBOSE -gt 0 ]; then
      echo "$0.$LINENO phase blank"
    fi
    if [ -e $RESP ]; then
      echo "$0.$LINENO phase $RESP"
      #OPT_PH=" -P $i/$RESP "
      echo -e "-P\t\"$i/$RESP\"" >> $ALST
      echo "$0.$LINENO phase $OPT_PH"
    fi
 fi
 SM_FL=
 #if [ ! -e $SUM_FILE ]; then
   SM_FL=$i/$SUM_FILE
 #fi
 if [ $VERBOSE -gt 0 ]; then
   echo "$0 SM_FL= $SM_FL  SUM_FILE= $SUM_FILE"
 fi
 echo -e "-p\t\"$RPS\"" >> $ALST
 echo -e "-s\t2,2" >> $ALST
 if [ "$AVERAGE" == "1" ]; then
    echo -e "-A" >> $ALST
 fi
 if [ "$CLIP" != "" ]; then
    echo -e "-c\t$CLIP" >> $ALST
 fi
 if [ "$DESC_FILE" != "" ]; then
   echo -e "-d\t\"$DESC_FILE\"" >> $ALST
 fi
 if [ "$DESC_FILE" == "" ]; then
   if [ -e desc.txt ]; then
      FLS=$(get_abs_filename "desc.txt")
      OPT_DESC_FILE="$FLS"
   fi
 fi
 if [ "$OPT_DESC_FILE" != "" ]; then
      echo -e "-d\t\"$OPT_DESC_FILE\"" >> $ALST
 fi
 echo -e "-i\t\"$i/*.png\"" >> $ALST
 #echo -e "-x\t$i.xlsx" >> $ALST
 #echo -e "-o\tchart_new,dont_sum_sockets" >> $ALST
 # itp files
 # yab_cmd files might be in same dir or up 1 level
 if [ -e yab_cmds.json.tsv ]; then
   FLS=$(get_abs_filename yab_cmds.json.tsv)
   #FLS=`ls -1 $i/metric_out.tsv`
   echo -e "${FLS}" >> $ALST
 else
 if [ -e ../yab_cmds.json.tsv ]; then
   FLS=$(get_abs_filename ../yab_cmds.json.tsv)
   #FLS=`ls -1 $i/metric_out.tsv`
   echo -e "${FLS}" >> $ALST
 fi
 fi
 if [ -e metric_out.tsv ]; then
   FLS=$(get_abs_filename metric_out.tsv)
   #FLS=`ls -1 $i/metric_out.tsv`
   echo -e "${FLS}" >> $ALST
 fi
 if [ -e metric_out.csv.tsv ]; then
   FLS=$(get_abs_filename metric_out.csv.tsv)
   #FLS=`ls -1 $i/metric_out.tsv`
   echo -e "${FLS}" >> $ALST
 fi
 #if [ -e infra_cputime.txt.tsv ]; then
 #  FLS=$(get_abs_filename infra_cputime.txt.tsv)
 #  echo -e "${FLS}" >> $ALST
 #fi
 if [ $VERBOSE -gt 0 ]; then
   popd
 else
   popd > /dev/null
 fi
 #FLS=`ls -1 $SM_FL $i/*txt.tsv | grep -v infra_cputime`
 CKNM=$i/muttley_host_calls.tsv
 if [ -e $CKNM ]; then
   MUTT_ARR+=($CKNM)
 fi
 FLS=`ls -1 $SM_FL $i/*txt.tsv`
 FLS_IC=`ls -1  $i/*txt.tsv | grep infra_cputime`
 FLS_PS=`ls -1  $i/*txt.tsv | grep perf_stat`
 echo -e "${FLS}" >> $ALST
 MYA=($i/*log.tsv)
 if [ "${#MYA}" != "0" ]; then
   FLS=`ls -1 $i/*log.tsv`
   echo -e "${FLS}" >> $ALST
 fi
 MYSVG=($i/*.svg)
 if [ "${#MYSVG}" != "0" ]; then
   SVG=`ls -1 $i/*.svg`
 fi
 MYA=($i/*current.tsv)
 if [ "${#MYA}" != "0" ]; then
   FLS=`ls -1 $i/*current.tsv`
   echo -e "${FLS}" >> $ALST
 fi
 MYA=($i/muttley*.json.tsv)
 if [ "${#MYA}" != "0" ]; then
   FLS=`ls -1 $i/muttley*.json.tsv`
   echo -e "${FLS}" >> $ALST
 fi
# MYA=($i/sum_all.tsv)
# if [ "${#MYA}" != "0" ]; then
#   FLS=`ls -1 $i/sum_all.tsv`
#   echo -e "${FLS}" >> $ALST
# fi
 echo -e "" >> $ALST
 if [ "$FCTRS" != "" ]; then
   FCTRS="$FCTRS,"
 fi
 if [ "$SVG" != "" ]; then
   SVGS="${SVGS} -f ${SVG}"
 fi
 FCTRS="$FCTRS$FCTR"
done
fi

SUM_ALL=sum_all_${JOB_ID}.tsv
#SUM_ALL=sum_all.tsv
if [ -e $SUM_ALL ]; then
  MYDIR=`pwd`
  MYSUMALL="$MYDIR/$SUM_ALL"
  echo "$0.$LINENO got sum_all $SUM_ALL in $MYDIR"
fi
if [ "$INPUT_FILE_LIST" != "" ]; then
  echo "___$MYSUMALL" >> $ALST
  cat $INPUT_FILE_LIST >> $ALST
  DIR_1ST_DIR=`head -1 $INPUT_FILE_LIST`
  NUM_DIRS=2
fi

wait_for_all $LINENO
 if [ -e job_${JOB_ID}.stop ]; then
    RESP=`head -1 job_${JOB_ID}.stop`
    echo "$0: got job_$JOB_ID.stop pid= $RESP and bashpid= $$" > /dev/stderr
    if [ "$RESP" == "$$" ]; then
      echo "$0: quitting at line $LINENO due to job_$JOB_ID.stop having value PID= $$"
      exit 1
    fi
 fi

if [ "$SVGS" != "" ]; then
  $SCR_DIR/svg_to_html.sh $SVGS -r $FCTRS > tmp.html
  ck_last_rc $? $LINENO
fi
  
  if [ -e $SUM_ALL ]; then
    rm $SUM_ALL
  fi
  #printf "title\tsum_all\tsheet\tsum_all\ttype\tcopy\n"  >> $SUM_ALL
  #printf "hdrs\t2\t0\t-1\t%d\t-1\n"  500 >> $SUM_ALL
  #printf "Resource\tTool\tMetric\taverage\n" >> $SUM_ALL;
if [ "$FLS_IC" != "" -o "$FLS_PS" != "" ]; then
  OPT_METRIC=" -m sum "
  OPT_METRIC=" -m sum_per_server "
  OPT_METRIC=" -m avg "
  OFILE=infra_cputime_sum_${JOB_ID}.tsv
  if [ -e $OFILE ]; then
    rm $OFILE
  fi
#abc
  if [ "$FLS_IC" != "" -o "$FLS_PS" != "" ]; then
  if [ $VERBOSE -gt 0 ]; then
  echo "$SCR_DIR/redo_chart_table.sh -O $OPTIONS -S $SUM_ALL -f $ALST -o $OFILE   -g infra_cputime $OPT_METRIC -r 50 -t __all__"
  fi
        $SCR_DIR/redo_chart_table.sh -O $OPTIONS -S $SUM_ALL -f $ALST -o $OFILE   -g infra_cputime $OPT_METRIC -r 50 -t __all__ 
  ck_last_rc $? $LINENO
  fi
  if [ "$FLS_PS" != "" ]; then
  OFILE=sys_perf_stat_sum_${JOB_ID}.tsv
  if [ -e $OFILE ]; then
    rm $OFILE
  fi
  if [ $VERBOSE -gt 0 ]; then
  echo "$SCR_DIR/redo_chart_table.sh -O $OPTIONS -S $SUM_ALL -f $ALST -o $OFILE   -g perf_stat $OPT_METRIC -r 50 -t __all__"
  fi
        $SCR_DIR/redo_chart_table.sh -O $OPTIONS -S $SUM_ALL -f $ALST -o $OFILE   -g perf_stat $OPT_METRIC -r 50 -t __all__ 
  ck_last_rc $? $LINENO
  fi
fi

DO_TSV_2_XLS=0
if [ $NUM_DIRS -gt 1 ]; then
  DO_TSV_2_XLS=1
fi

if [ "$DO_TSV_2_XLS" == "0" ]; then
  if [ "$SKIP_XLS" -eq "1" ]; then
    DO_TSV_2_XLS=1
  fi
fi

  
if [ "$DO_TSV_2_XLS" == "1" ]; then
  echo "$0.$LINENO: ALST= $ALST" > /dev/stderr
  got_pwd=`pwd`
  RESP=`grep sum.tsv $ALST | sed 's/sum.tsv/sum_all2.tsv/'`
  FLS=
  for ii in $RESP; do
    if [ -e $ii ]; then
      FLS="$FLS -i $ii"
    fi
  done
  if [ "$FLS" != "" ]; then
    echo "$0.$LINENO ---------- got_pwd= $got_pwd --------------------"
    echo $SCR_DIR/compare_summary_table.sh $FLS -s $SUM_ALL -S "\t"
         $SCR_DIR/compare_summary_table.sh $FLS -s $SUM_ALL -S "\t"
    ck_last_rc $? $LINENO
    MK_SUM_ALL=0
  else
    MK_SUM_ALL=1
  fi

  if [ $VERBOSE -gt 0 ]; then
  echo "$0: awk -v mk_sum_all="$MK_SUM_ALL" -v input_file=\"$ALST\" -v sum_all=\"$SUM_ALL\" -v sum_file=\"$SUM_FILE\" -v curdir=\"$got_pwd\" "
  fi
  awk -v options="$OPTIONS" -v script="$0.$LINENO.awk" -v job_id="$JOB_ID" -v verbose="$VERBOSE" -v mk_sum_all="$MK_SUM_ALL" -v input_file="$ALST" -v sum_all="$SUM_ALL" -v sum_file="$SUM_FILE" -v sum_all_avg_by_metric="$SUM_ALL_AVG_BY_METRIC" -v curdir="$got_pwd" '
    @include "get_excel_col_letter_from_number.awk"
    BEGIN{
      sum_files=0;
      fls=0;
      fld_m=3;
      fld_v=4;
      got_avgby=0;
      get_max_val = 0;
      if (index(options, "get_max_val") > 0) {
        get_max_val = 1;
      }
    }
function do_pxx_compare(fls, str1, str2, v,    str, pxx_i)
{
    str = str1";"str2;
    if (!(str in pxx_list)) {
      pxx_list[str] = ++pxx_max;
      pxx_lkup[pxx_max] = str;
      pxx_hdr[pxx_max,"grp"] = str1;
      pxx_hdr[pxx_max,"mtrc"] = str2
    }
    pxx_i = pxx_list[str];
    pxx_arr[pxx_i,fls] += v+0.0;
}
    { if (index($0, sum_file) > 0 || index($0, sum_all) > 0) {
        flnm = $0;
        fls++;
        fls_mx = fls;
        if (verbose > 0) {
           printf("got sumfile[%d]= %s sum_all= %s\n", fls, flnm, sum_all) > "/dev/stderr";
        }
        ln = -1;
        nflds=4;
        while ((getline line < flnm) > 0) {
           ln++;
           if (ln <= 2) {
              if (ln == 2) {
                nh = split(line, hdrs, /\t/);
                if (hdrs[3] == "Value" && hdrs[4] == "Metric") {
                   fld_m=4; 
                   fld_v=3; 
                   fld_mm1=2; 
                   if (verbose > 0) {
                     printf("sum_all2 metric fld= %d nf= %d\n", 3, nh) > "/dev/stderr";
                   }
                }
                if (hdrs[3] == "Metric") {
                   fld_m=3; 
                   fld_v=4; 
                   fld_mm1=2; 
                   if (verbose > 0) {
                     printf("sum_all3 metric fld= %d nf= %d\n", 3, nh) > "/dev/stderr";
                   }
                   if (nh > 4) {
                     nflds= nh;
                   }
                }
              }
              continue;
           }
        #printf("got sum.tsv[%d][%d]= %s\n", fls, ln, line) > "/dev/stderr";
           n      = split(line, arr, /\t/);
           mtrcm1 = arr[fld_mm1];
           mtrc   = arr[fld_m];
           #printf("fl[%d].ln= %s\n", fls, line) > "/dev/stderr";
           if (mtrcm1 == "hostname" && mtrc == "hostname") {
              pxx_hst[fls] = arr[fld_v];
           }
           if (mtrcm1 == "infra procs max %cpu" && (mtrc == "busy muttley" || mtrc == "busy non-infra" || mtrc == "busy infra")) {
              str1 = mtrcm1;
              str2 = mtrc;
              do_pxx_compare(fls, str1, str2, arr[fld_v]);
           }
           #if (mtrcm1 == "muttley calls avg") {
           #   # the average muttley calls have so many small RPS. creates huge list especially if we match up columns
           #   # so just drop the small values
           #   continue;
           #}
           if (mtrcm1 == "net stats" && (index(mtrc, "MB/s read ") == 1 || index(mtrc, "MB/s write ") == 1)) {
              str1 = mtrcm1;
              str2 = mtrc;
              if (arr[fld_v] != "" && arr[fld_v] != 0) {
              do_pxx_compare(fls, str1, str2, arr[fld_v]);
              }
           }
           if (mtrcm1 == "IO stats" && index(mtrc, "util% ") == 1) {
              str1 = mtrcm1;
              str2 = mtrc;
              if (arr[fld_v] != "" && arr[fld_v] != 0) {
              do_pxx_compare(fls, str1, str2, arr[fld_v]);
              }
           }
           if (mtrcm1 == "IO stats" && (index(mtrc, "rd_MB/s ") == 1 || index(mtrc, "wr_MB/s ") == 1)) {
              str1 = mtrcm1;
              str2 = mtrc;
              if (arr[fld_v] != "" && arr[fld_v] != 0) {
              do_pxx_compare(fls, str1, str2, arr[fld_v]);
              }
           }
           if (mtrcm1 == "perf_stat" && index(mtrc, "QPI_BW GB/s") == 1) {
              str1 = mtrcm1;
              str2 = mtrc;
              if (arr[fld_v] != "" && arr[fld_v] != 0) {
              do_pxx_compare(fls, str1, str2, arr[fld_v]);
              }
           }
           if (mtrcm1 == "perf_stat" && index(mtrc, "%used_bw_of_max_theoretical_mem_bw") == 1) {
              str1 = mtrcm1;
              str2 = mtrc;
              if (arr[fld_v] != "" && arr[fld_v] != 0) {
              do_pxx_compare(fls, str1, str2, arr[fld_v]);
              }
           }
           if (mtrcm1 == "perf_stat" && index(mtrc, "Mem BW GB/s") == 1) {
              str1 = mtrcm1;
              str2 = mtrc;
              if (arr[fld_v] != "" && arr[fld_v] != 0) {
              do_pxx_compare(fls, str1, str2, arr[fld_v]);
              }
           }
           if (mtrcm1 == "muttley host.calls max" && (mtrc == "RPS host.calls max")) {
              str1 = mtrcm1;
              str2 = mtrc;
              do_pxx_compare(fls, str1, str2, arr[fld_v]);
           }
           if (mtrcm1 == "muttley calls avg" && (mtrc == "RPS host.calls")) {
              str1 = mtrcm1;
              str2 = mtrc;
              do_pxx_compare(fls, str1, str2, arr[fld_v]);
           }
           if (mtrcm1 == "muttley calls avg" && arr[fld_v] < 1.0) {
              # the average muttley calls have so many small RPS. creates huge list especially if we match up columns
              # so just drop the small values
              continue;
           }
           if (mtrcm1 == "perf_stat" && arr[fld_v] == 0.0) {
              # not all events are defined on each box
              # so just drop the 0 values
              continue;
           }
           str = mtrcm1 " " mtrc;
           if (!(str in mtrc_list)) {
              mtrc_list[str] = ++mtrc_mx;
              mtrc_lkup[str] = mtrc;
              mtrc_lkup[mtrc_mx] = str;
              mtrc_lkup[mtrc_mx,1] = mtrc;
              mtrc_lkup[mtrc_mx,2] = mtrcm1;
              if (fld_v > fld_m && fld_m > 1) {
                mtrc_cat[mtrc_mx] = arr[fld_m-1];
              }
              if (fld_v < fld_m && fld_m > 1) {
                mtrc_cat[mtrc_mx] = arr[fld_v-1];
              }
           }
           mtrc_i = mtrc_list[str];
           if (sum_all_avg_by_metric != "" && mtrc == sum_all_avg_by_metric) {
              got_avgby = 1;
              avgby=arr[fld_v]; 
              if (!(avgby in avgby_list)) {
                avgby_list[avgby] = ++avgby_list_mx;
                avgby_lkup[avgby_list_mx] = avgby;
              } 
              avgby_i = avgby_list[avgby];
              avgby_arr[fls,1] = avgby_i;
              avgby_arr[fls,2]++;
           }
           if (mtrc == "goto_sheet") {
              gs=arr[fld_v]; 
              if (!(gs in gs_list)) {
                gs_list[gs] = ++gs_list_mx;
                gs_lkup[gs_list_mx] = gs;
              } else {
                for (i=0; i <= 100; i++) {
                   tnm = gs "_" i;
                   if (!(tnm in gs_list)) {
                     gs_list[tnm] = ++gs_list_mx;
                     gs_lkup[gs_list_mx] = tnm;
                     arr[fld_v] = tnm;
                     break;
                   }
                }
              }
           }
           if (mtrc == "data_sheet") {
              ds=arr[fld_v]; 
              if (!(ds in ds_list)) {
                ds_list[ds] = ++ds_list_mx;
                ds_lkup[ds_list_mx] = ds;
              } else {
                for (i=0; i <= 100; i++) {
                   tnm = ds "_" i;
                   if (!(tnm in ds_list)) {
                     ds_list[tnm] = ++ds_list_mx;
                     ds_lkup[ds_list_mx] = tnm;
                     arr[fld_v] = tnm;
                     break;
                   }
                }
              }
           }
           mtrc_arr[fls,mtrc_i] = arr[fld_v];
           if (nflds > 4) {
             for (f= 5; f <= nflds; f++) {
                mtrc_arr[fls+f-4,mtrc_i] = arr[f];
             }
             if (fls_mx < (fls+nflds-5)) {
               fls_mx = fls+nflds-5;
             }
             if (verbose > 0) {
               printf("fls= %d, flx_mx= %d\n", fls, fls_mx) > "/dev/stderr";
             }
           }
        }
        fls = fls_mx;
        close(flnm)
      }
    }
 function ck_num(a,    b, isnum, c) {
  b=a+0;
  isnum=0;
  if (a==0.0){
    isnum=2;
  }else {
    if (b==0) {
     if (index(a, "0") > 0) {
       c = a;
       gsub(/[0]+/,"",c);
       gsub(/\./,"",c);
       if (c == "") {
         isnum=3;
       } else {
         isnum=-1;
       }
     } else {
       isnum=-2;
     }
    } else {
     isnum=4;
    }
  }
  return isnum;
 }
function arr_in_compare(i1, v1, i2, v2,    l, r)
{
    m1 = arr_in[i1];
    m2 = arr_in[i2];
    if (m2 > m1)
        return -1
    else if (m1 == m2)
        return 0
    else
        return 1
}

    END {
      if (mk_sum_all == 1) {
      ofile = sum_all;
      printf("_____script= %s ofile= %s, got_avgby= %d\n", script, ofile, got_avgby) > "/dev/stderr";
      rw = 1;
      printf("title\tsum_all\tsheet\tsum_all\ttype\tcopy\n")  >> ofile;
      ++rw;
      printf("hdrs\t2\t0\t-1\t%d\t-1\n", fls+3) >> ofile;
      ++rw;
      printf("Resource\tTool\tMetric") >> ofile;
      cur_col = 2; # 1st col is 0 for me. After above printf we are in col 2
      #if (got_avgby == 0 && fls > 1) {
      if (got_avgby == 0) {
        if (get_max_val == 1) {
          printf("\tmax") >> ofile;
        } else {
          printf("\taverage") >> ofile;
        }
        ++cur_col;
      }
      fl_col_beg = cur_col + 1;
      for (j=1; j <= fls; j++) {
         if (got_avgby == 1) {
          if (j == 1 || avgby_arr[j,1] != avgby_arr[j-1,1]) {
            printf("\t%d", avgby_arr[j,1]) >> ofile;
          }
         } else {
            printf("\t%d", j-1) >> ofile;
         }
         ++cur_col;
      }
      fl_col_end = cur_col;
      printf("\n") >> ofile;
      ltr_beg = get_excel_col_letter_from_number(fl_col_beg);
      ltr_end = get_excel_col_letter_from_number(fl_col_end);
      printf("______ col_beg= %d, col_end= %d, ltr_beg= %s ltr_end= %s\n", fl_col_beg, fl_col_end, ltr_beg, ltr_end) > "/dev/stderr";
      first_metric = 1;
      for (i=1; i <= mtrc_mx; i++) {
        mtrc   = mtrc_lkup[i,1];
        mtrcm1 = mtrc_lkup[i,2];
        if (mtrc == "") { continue; }
        ++rw;
        rng_str = sprintf("%s%d:%s%d", ltr_beg, rw, ltr_end,rw);
        if (mtrc == "data_sheet") {
          printf("\t%s\t%s", mtrc_arr[1,i], mtrc) >> ofile;
        } else {
          mcat = "itp";
          if (mtrc_cat[i] != "") { mcat = mtrc_cat[i]; }
          eqn_for_col_of_max_val = sprintf("=MATCH(MAX(%s),%s,0)-1", rng_str, rng_str);
          if (first_metric == 1) {
            eqn_for_col_of_max_val = "fileno_of_max";
            first_metric = 0;
          }
          printf("\"%s\"\t%s\t%s", eqn_for_col_of_max_val, mcat, mtrc) >> ofile;
        }
        for (j=1; j <= fls; j++) {
          val = mtrc_arr[j,i];
          isnum=ck_num(val);
          equal = "";
          if (isnum > 0) {
            equal = "=";
            if (got_avgby == 1) {
              if (j == 1 || avgby_arr[j,1] != avgby_arr[j-1,1]) {
                sm = 0;
                for (jj=0; jj < avgby_arr[j,2]; jj++) {
                  sm += mtrc_arr[j+jj,i];
                }
                if (avgby_arr[j,2] > 0) {
                  val = sm / avgby_arr[j,2];
                } else {
                  val = 0.0;
                }
              } else {
                continue;
              }
            } else {
              if (j == 1) {
                sum_n = 0;
                sum_v = 0;
                for (k=1; k <= fls; k++) {
                  val2   = mtrc_arr[k,i];
                  isnum2 = ck_num(val2);
                  if (isnum2 > 0) {
                    if (get_max_val == 1) {
                      if (sum_n == 0) {
                        sum_v = val2;
                        sum_n = 1;
                      } else if (sum_v < val2) {
                          sum_v = val2;
                      }
                    } else {
                      sum_v = sum_v + val2;
                      sum_n = sum_n + 1;
                    }
                  }
                }
                if (sum_n > 0) {
                  printf("\t%s%f", equal, sum_v/sum_n) >> ofile;
                } else {
                  printf("\t%s%s", equal, 0) >> ofile;
                }
              }
            }
          } else {
            if (got_avgby == 1) {
              if (j == 1 || avgby_arr[j,1] != avgby_arr[j-1,1]) {
               ;
              } else {
                continue;
              }
            } else {
              if (j == 1) {
                 printf("\t%s%s", "", "") >> ofile;
              }
            }
          }
          if (val == "") {
          printf("\t") >> ofile;
          } else {
          printf("\t%s%s", equal, val) >> ofile;
          }
           #if (index(mtrc, "Mem BW GB/s") > 0) {
           #  printf("str= %s, fls= %d, %s, %s\n", mtrc, fls, val, isnum) > "/dev/stderr";
           #}
        }
        printf("\n") >> ofile;
      }
      for (k=1; k <= pxx_max; k++) {
        #pxx_arr[2,fls] += arr[fld_v];
        #pxx_hdr[2,"grp"] = mtrcm1;
        #pxx_hdr[2,"mtrc"] = mtrc;
        delete res_i;
        delete idx;
        for(i=1; i <= fls_mx; i++) {
          idx[i] = i;
          arr_in[i] = pxx_arr[k,i];
        }
        asorti(idx, res_i, "arr_in_compare");
        # https://www.dummies.com/education/math/statistics/how-to-calculate-percentiles-in-statistics/
        px_mx = 0;
        px[++px_mx] = 10;
        px[++px_mx] = 20;
        px[++px_mx] = 30;
        px[++px_mx] = 40;
        px[++px_mx] = 50;
        px[++px_mx] = 60;
        px[++px_mx] = 70;
        px[++px_mx] = 80;
        px[++px_mx] = 90;
        px[++px_mx] = 95;
        px[++px_mx] = 99;
        px[++px_mx] = 100;
        str = "hosts " pxx_hdr[k,"mtrc"];
        printf("\t%s\t%s\t", pxx_hdr[k,"grp"], str) >> ofile;
        for(i=1; i <= fls_mx; i++) {
           printf("\t%s", pxx_hst[res_i[i]]) >> ofile;
        }
        printf("\n") >> ofile;
        str = "values " pxx_hdr[k,"mtrc"];
        printf("\t%s\t%s\t", pxx_hdr[k,"grp"], str) >> ofile;
        for(i=1; i <= fls_mx; i++) {
           printf("\t%f", arr_in[res_i[i]]) >> ofile;
        }
        printf("\n") >> ofile;
        for (kk=1; kk <= px_mx; kk++) {
          pi  = 0.01 * px[kk] * fls_mx; # index into array for this percentile
          pii = int(pi);       # integer part
          if (pii != pi) {
            # so pi is not an integer
            piu = pii+1;
            if (piu > fls_mx) { piu = fls_mx; }
            uval = arr_in[res_i[piu]]
            hval = pxx_hst[res_i[piu]];
          } else {
            piu = pii;
            if (piu >= fls_mx) {
              uval = arr_in[res_i[fls_mx]];
              hval = pxx_hst[res_i[fls_mx]];
            } else {
              piup1=piu + 1;
              uval = 0.5*(arr_in[res_i[piu]] + arr_in[res_i[piup1]]);
              hval = pxx_hst[res_i[piu]] " " pxx_hst[res_i[piup1]] " "
            }
          }
          str = "p" px[kk] " " pxx_hdr[k,"mtrc"];
          printf("\t%s\t%s\t%f\t%s\n", pxx_hdr[k,"grp"], str, uval, hval) >> ofile;
          printf("\t%s\t%s\t%f\t%s\n", pxx_hdr[k,"grp"], str, uval, hval) > "/dev/stderr";
        }
      }
      close(ofile);
      }
      flnm = input_file;
      if (verbose > 0) {
        printf("======---- input_file= %s\n", input_file) > "/dev/stderr";
      }
        ln = 0;
        last_non_blank = -1;
        first_blank = -1;
        first_infra_cputime = -1;
        first_perf_stat = -1;
        while ((getline line < flnm) > 0) {
           if (index(line, "infra_cputime") > 0) {
              ++first_infra_cputime;
              if (first_infra_cputime == 0) {
                line = "infra_cputime_sum_" job_id ".tsv";
              } else {
                continue;
              }
              # this line will be handled outside
           }
           if (index(line, "perf_stat") > 0) {
              ++first_perf_stat;
              if (first_perf_stat == 0) {
                line = "sys_perf_stat_sum_" job_id ".tsv";
              } else {
                continue;
              }
              # this line will be handled outside
           }
           ln++;
           if (first_blank == -1 && length(line) == 0) {
             first_blank = ln;
           }
           if (length(line) > 0) {
             last_non_blank = ln;
           }
           sv[ln] = line;
        }
        close(flnm)
        if (ln == 0) { exit; }
        printf("%s\n", sv[1]) > flnm;
        for(i=2; i <= ln; i++) {
          if (first_blank == i) {
             printf("%s\n", sum_all) >> flnm;
          }
          printf("%s\n", sv[i]) >> flnm;
          #if (last_non_blank == i) {
          #   printf("%s\n", sum_all) >> flnm;
          #}
        }
        close(flnm)
      }
  ' $ALST
      ck_last_rc $? $LINENO

#abc
  if [ ${#MUTT_ARR[@]} -gt 0 ]; then
  OFILE2=muttley_host_calls_combined_${JOB_ID}.tsv
  echo $SCR_DIR/combine_muttley_host_calls.sh -S $SUM_ALL -o $OFILE2 -f $ALST  -t "avg muttley host calls by group" -c scatter_straight -s mutt_calls ${MUTT_ARR[@]} | cut -c 1-400
       $SCR_DIR/combine_muttley_host_calls.sh -S $SUM_ALL -o $OFILE2 -f $ALST  -t "avg muttley host calls by group" -c scatter_straight -s mutt_calls ${MUTT_ARR[@]}
  ck_last_rc $? $LINENO
  awk -v add_file="$OFILE2" -v file_list="$ALST" '
     BEGIN{did_add = 0; }
     {
       if (did_add == 0 && $0 != "" && substr($0, 1, 1) != "#" && substr($0,1,1) != "-") {
          ln[++ln_mx] = add_file;
          did_add = 1;
       }
       ln[++ln_mx] = $0;
     }
     END{
       for (i=1; i <= ln_mx; i++) {
         printf("%s\n", ln[i]) > file_list;
       }
     }' $ALST
  fi

  echo "$0.$LINENO ____got BEG_TM_IN=\"$BEG_TM_IN\"" > /dev/stderr
      if [ "$BEG_TM_IN" != "" ]; then
        BEG_TM=$BEG_TM_IN
      fi
      if [ "$END_TM_IN" != "" ]; then
        END_TM=$END_TM_IN
      fi
    if [ $VERBOSE -gt 0 ]; then
       echo "$0.$LINENO =========== pwd = $got_pwd ========="
    fi
    USE_DIR=
    RESP=`find $DIR_1ST_DIR -name 60secs.log | head -1 | wc -l | awk '{$1=$1;print}'`
    BTM=
    ETM=
    GOT_BE_TM=0
    if [ "$RESP" != "0" ]; then
       RESP=`find $DIR_1ST_DIR -name 60secs.log | head -1`
       #start vmstat at Tue Sep  1 15:52:53 UTC 2020 1598975573.042925368
       BTM=`awk '/^start /{if (NF==10){printf("%d\n", $10); exit;}}' $RESP`
       RESP=`find $DIR_1ST_DIR -name run.log | head -1`
       if [ "$RESP" != "" ]; then
         ETM=`awk -v beg="$BTM" '/end elapsed_secs/{printf("%d\n", beg+$4+1.0);}' $RESP`
         GOT_BE_TM=1
         BEG_TM=$BTM
         END_TM=$ETM
       fi
    fi
    RESP=`find $DIR_1ST_DIR -name run.log | head -1 | wc -l | awk '{$1=$1;print}'`
    if [ "$RESP" == "0" ]; then
      RESP=`find $INPUT_DIR -name run.log | head -1 | wc -l | awk '{$1=$1;print}'`
      USE_DIR=$INPUT_DIR
    else
      USE_DIR=$DIR_1ST_DIR
    fi
    if [ $VERBOSE -gt 0 ]; then
      echo "$0.$LINENO find_401 run.log RESP= $RESP"
    fi
    ITP_INTRVL=0
    if [ "$GOT_BE_TM" == 0 -a "$RESP" != "0" ]; then
      RUN_LOG=`find $USE_DIR -name run.log | head -1`
       if [ $VERBOSE -gt 0 ]; then
        echo "$0.$LINENO run_log file= $RUN_LOG"
      fi
  echo "$0.$LINENO ____got BEG_TM_IN=\"$BEG_TM_IN\"" > /dev/stderr
      if [ "$BEG_TM_IN" != "" ]; then
        BEG_TM=$BEG_TM_IN
      else
        BEG_TM=`awk '/ start /{printf("%d\n", $2);}' $RUN_LOG`
      fi
      if [ "$END_TM_IN" != "" ]; then
        END_TM=$END_TM_IN
      else
        END_TM=`awk '/ end /{printf("%d", $2);exit}' $RUN_LOG`
      fi
      echo "got RUN_LOG BEG_TM= $BEG_TM END_TM= $END_TM"
      RUN_INFRA=`find $USE_DIR -name infra_cputime.txt | head -1`
      if [ "$RUN_INFRA" != "" ]; then
        BEG_TMI=`awk '/^__/{printf("%s\n", $2);exit}' $RUN_INFRA`
        END_TMI=`awk '/^__/{tm=$2;}END{printf("%s\n", tm);}' $RUN_INFRA`
        echo "got RUN_INF BEG_TM= $BEG_TMI END_TM= $END_TM END_TMI= $END_TMI"
        if [ "$END_TMI" != "" ]; then
           if [ "$END_TM" == "" ]; then
               # END_TM can be empty if the data dir is not yet done and the last date tm hasnt been written yet
               END_TM=$END_TMI
           else
             echo "$0.$LINENO END_TM= $END_TM and END_TMI= $END_TMI"
             if [ "$END_TM" -lt "$END_TMI" ]; then
               END_TM=$END_TMI
             fi
           fi
        fi
      fi
      if [ $VERBOSE -gt 0 ]; then
        echo "$0.$LINENO beg_tm= $BEG_TM end_tm= $END_TM" > /dev/stderr
        echo "$0.$LINENO $BEG_TM" | awk '{print strftime("beg_time: %c %Z",$1)}' > /dev/stderr
        echo "$0.$LINENO $END_TM" | awk '{print strftime("end_time: %c %Z",$1)}' > /dev/stderr
      fi
      RESP_ITP=`find $USE_DIR -name run_itp.log | wc -l | awk '{$1=$1;print}'`
      if [ "$RESP_ITP" != "0" ]; then
         ITP_LOG=`find $USE_DIR -name run_itp.log | head -1`
         ITP_INTRVL=`awk '
            BEGIN{intrvl=0;}
            /perf\sstat/ {for (i=2; i < NF; i++) { if ($i == "-I" ) { intrvl= $(i+1); exit;}}}
            END{printf("%.0f\n", intrvl/1000);}
          ' $ITP_LOG`
         if [ $VERBOSE -gt 0 ]; then
           echo "$0.$LINENO ITP_INTERVAL= $ITP_INTRVL, log= $ITP_LOG" > /dev/stderr
         fi
      fi
      if [ "$ITP_INTRVL" == "0" ]; then
        if [ -e "$RUN_LOG" ]; then
          TRY_ITP=`awk '/ start /{for (i=1; i < NF; i++) { if ($(i) == "-i") { printf("%s\n", $(i+1));exit}};printf("\n");exit;}' $RUN_LOG`
          if [ "$TRY_ITP" != "" ]; then
            ITP_INTRVL=$TRY_ITP
          fi
        fi
      fi
    fi
  if [ "$INPUT_FILE_LIST" != "" ]; then
    RESP=0
  else
    if [ $VERBOSE -gt 0 ]; then
       echo "$0.$LINENO find $INPUT_DIR -name muttley*.json | wc -l | awk '{$1=$1;print}'"
    fi
    RESP=`find $INPUT_DIR -name "muttley*.json" | wc -l | awk '{$1=$1;print}'`
    if [ $VERBOSE -gt 0 ]; then
      echo "$0.$LINENO find_51 muttley RESP= \"$RESP\"" 
    fi
  fi
  if [ "$RESP" != "0" ]; then
      OPT_M=
      if [ "$ITP_INTRVL" != "0" -a "$OPTIONS" != "" ]; then
         if [[ $OPTIONS == *"match_itp_muttley_interval"* ]]; then
           OPT_M=" -m $ITP_INTRVL "
         fi
      fi
      echo -e "-p\t\"$RPS\"" >> $ALST
      echo -e "-s\t2,2" >> $ALST
      if [ "$DESC_FILE" != "" ]; then
        echo -e "-d\t\"$DESC_FILE\"" >> $ALST
      fi
      tst_files=`find $INPUT_DIR -name "muttley*.json"|sort`
      if [ $VERBOSE -gt 0 ]; then
        echo "$0.$LINENO find muttley*.json.tsv RESP= $tst_files"
        echo "$0.$LINENO muttley files_0: $tst_files" > /dev/stderr
      fi
      if [ "$tst_files" != "" ]; then
        for f in $tst_files; do
          if [ $VERBOSE -gt 0 ]; then
            echo "$0.$LINENO try muttley_a file= $f" > /dev/stderr
          fi
          if [ -e $f ]; then
             OPT_O=
             if [ "$OPTIONS" != "" ]; then
               OPT_O=" -o \"$OPTIONS\" "
             fi
             if [ $VERBOSE -gt 0 ]; then
               echo "$0.$LINENO try muttley log $f" 
             fi
             if [ $VERBOSE -gt 0 ]; then
                echo $SCR_DIR/resp_2_tsv.sh -b $BEG_TM -e $END_TM -f $f -s $SUM_ALL $OPT_O $OPT_M > /dev/stderr
             fi
                  $SCR_DIR/resp_2_tsv.sh -b $BEG_TM -e $END_TM -f $f -s $SUM_ALL $OPT_O $OPT_M
                   ck_last_rc $? $LINENO
          fi
          if [ -e $f.tsv ]; then
             if [ $VERBOSE -gt 0 ]; then
                echo "$0.$LINENO ++++++++++ got $f.tsv "
             fi
             echo -e "$f.tsv" >> $ALST
             #SHEETS="$SHEETS $f.tsv"
             #echo "$0.$LINENO got latency log $f.tsv" > /dev/stderr
          fi
        done
      fi
    echo -e "" >> $ALST
  fi
  OPT_A=
  if [ "$AVERAGE" == "1" ]; then
    OPT_A=" -A "
  fi
  OPT_OPTIONS=
  if [ "$OPTIONS" != "" ]; then
    OPT_OPTIONS=" -O $OPTIONS "
  fi
  OPT_M=
  if [ "$MAX_VAL" != "" ]; then
    OPT_M=" -m $MAX_VAL "
  fi
  OPT_SM=
  if [ "$SUM_ALL" != "" ]; then
    OPT_SM=" -S $SUM_ALL "
  fi
  OPT_TM=
  echo "$0.$LINENO ____got BEG_TM_IN=\"$BEG_TM_IN\"" > /dev/stderr
  if [ "$BEG_TM_IN" != "" ]; then
     OPT_TM=" -b $BEG_TM_IN "
  fi
  echo "$0.$LINENO ____got OPT_TM=\"$OPT_TM\"" > /dev/stderr
  if [ "$END_TM" != "" ]; then
     echo "$0.$LINENO ____got END_TM=\"$END_TM\"" > /dev/stderr
     END_TM=`echo "$END_TM"|head -1`
     OPT_TM="$OPT_TM -e $END_TM "
  fi
  echo "$0.$LINENO ____got OPT_TM=\"$OPT_TM\"" > /dev/stderr

      
  #cat $ALST
  echo "$0.$LINENO ====== using input file $ALST ========"
  if [ $VERBOSE -gt 0 ]; then
    echo "$0.$LINENO ====== begin $ALST ========"
    head -50 $ALST
    echo "$0.$LINENO ====== end $ALST ========"
  fi
  TS_DFF=$(($TS_CUR-$TS_BEG))
  if [ $VERBOSE -gt 0 ]; then
    echo "$0.$LINENO elap_tm= $TS_DFF"
    echo "$0.$LINENO about to do tsv_2_xls.py" > /dev/stderr
  fi
  FSTDOUT="tmp_${JOB_ID}.jnk"
 if [ -e job_${JOB_ID}.stop ]; then
    RESP=`head -1 job_${JOB_ID}.stop`
    echo "$0: got job_$JOB_ID.stop pid= $RESP and bashpid= $$" > /dev/stderr
    if [ "$RESP" == "$$" ]; then
      echo "$0: quitting at line $LINENO due to job_$JOB_ID.stop having value PID= $$"
      exit 1
    fi
 fi
  #if [ $VERBOSE -gt 0 ]; then
    echo "$0.$LINENO python $SCR_DIR/tsv_2_xlsx.py $OPT_SM $OPT_a $OPT_A $OPT_TM $OPT_OPTIONS $OPT_M -f $ALST $SHEETS" > /dev/stderr
  #fi
        python $SCR_DIR/tsv_2_xlsx.py $OPT_SM $OPT_a $OPT_A $OPT_TM $OPT_OPTIONS $OPT_M -f $ALST $SHEETS &> $FSTDOUT
        PY_RC=$?
        PY_PID=$!
        #sleep 1
        #(wait $PY_PID && RC=$? && echo $RC > tsv_2_xls_${JOB_ID}.rc && echo "tsv_2_xls.py $PYPID rc= $RC at $LINENO" > /dev/stderr) &
        #echo "$0: tsv_2_xlsx.py started with pid= $PY_PID at line= $LINENO" > /dev/stderr
        #echo $PY_PID >> tsv_2_xlsx.pid
        if [ "$PY_RC" != "0" ]; then
           echo "$0: ================== at line $LINENO: error in tsv_2_xlsx.py. py RC= $PY_RC. See log $FSTDOUT. Bye =================" > /dev/stderr
           tail -20 $FSTDOUT
           exit 1
        fi
        #if [ ! -e /proc/$PY_PID ]; then
        #   echo "$0: ================== at line $LINENO: error in tsv_2_xlsx.py. py_pid= $PY_PID. See log $FSTDOUT. Bye =================" > /dev/stderr
        #   tail -20 $FSTDOUT
        #   exit 1
        #else
        #   echo "$0.$LINENO /proc/$PY_PID exists"
        #fi
        
  TS_CUR=`date +%s`
  TS_DFF=$(($TS_CUR-$TS_BEG))
  if [ $VERBOSE -gt 0 ]; then
    echo "$0.$LINENO elap_tm= $TS_DFF"
  fi
fi
exit 0
