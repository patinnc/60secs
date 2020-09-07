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
AVERAGE=0
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
echo "BACKGROUND= $NUM_CPUS"

while getopts "hvASa:b:B:c:D:d:e:F:g:I:m:N:o:P:r:X:x:" opt; do
  case ${opt} in
    A )
      AVERAGE=1
      ;;
    S )
      SKIP_XLS=1
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
      echo "input DIR= $DIR"
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
    m )
      MAX_VAL=$OPTARG
      ;;
    N )
      NUM_DIR=$OPTARG
      ;;
    o )
      OPTIONS="$OPTARG"
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
      echo "   -m max_val    any value in chart > this value will be replaced by 0.0"
      echo "   -N number_of_dirs  if you have more than 1 directories then you can limit the num of dirs with this option. Default process all"
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
      echo "Invalid option: $OPTARG requires an argument ${@}" 1>&2
      exit
      ;;
    \? )
      echo "Invalid option: $OPTARG ${@}" 1>&2
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
  echo "remaining args= $remaining_args"
  echo "got args leftover. Usually due to * in -d dir_name option"
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
       echo "got $lkfor, rest= $rest"
       lkfor="}"
       #rest2=${rest#*$lkfor}
       pfx=${rest%%$lkfor*}
       echo "options: sum_all_avg_by_metric=\"${pfx}\""
       SUM_ALL_AVG_BY_METRIC="$pfx"
   fi
fi

REGEX_LEN=${#REGEX[@]}

SKIP_SYS_2_TSV=0
if [ "$OPTIONS" != "" ]; then
  if [[ $OPTIONS == *"skip_sys_2_tsv"* ]]; then
     SKIP_SYS_2_TSV=1
  fi
fi

INPUT_DIR=$DIR

echo "SKIP_XLS= $SKIP_XLS"

get_abs_filename() {
  # $1 : relative filename
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

get_dir_list() {
   local CKF=$1
   DIR=$2
   local RESP
   echo "get_dir_list: found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
   #RESP=`find $DIR -name $CKF -print0 | sort -z | xargs -0 cat`
   if [ "$REGEX_LEN" != "0" ]; then
      RESP2=`find $DIR -name $CKF -print | sort`
      RESP=$RESP2
      local ii
      for ii in ${REGEX[@]}; do
         RESP=`echo -e "$RESP" | grep "$ii"`
      done
      mydir=`echo -e "$RESP" | wc -l`
      echo "mydir count= $mydir"
   else
      RESP=`find $DIR -name $CKF -print | sort | xargs `
   fi
   echo "get_dir_list: found $CKF file in dir $DIR:"
   local STR=
   local j=0
   for ii in $RESP; do
      NM=$(dirname $ii)
      j=$((j+1))
      if [ "$NUM_DIR" != "" -a "$NUM_DIR" != "0" -a $NUM_DIR -gt 0 -a $j -ge $NUM_DIR ]; then
         echo "limit number of dirs with $CKF due to -N $NUM_DIR option"
         break
      fi
      STR="$STR $NM"
   done
   DIR=$STR
   echo "get_dir_list: j= $j DIR= $DIR"
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
   echo "DESC_FILE= $DESC_FILE" > /dev/stderr
   DESC_FILE=$(get_abs_filename "$DESC_FILE")
   echo "DESC_FILE= $DESC_FILE" > /dev/stderr
fi

if [ "$INPUT_FILE_LIST" != "" ]; then
  if [ -e $INPUT_FILE_LIST ]; then
    echo "got input_file_list= $INPUT_FILE_LIST"
  fi
else
   DIR_ORIG=$DIR
   CKF=60secs.log
   GOT_DIR=0
   RESP=`find $DIR -name $CKF | wc -l | awk '{$1=$1;print}'`
   echo "RESP= 60secs.log = $RESP"
   if [ $RESP -gt 0 ]; then
       get_dir_list $CKF $DIR
       echo "found_44 $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
       GOT_DIR=1
   fi
   if [ $RESP -eq 0 ]; then
     echo "didn't find 60secs.log file under dir $DIR. Bye"
     CKF="metric_out"
     RESP=`find $DIR -name $CKF | wc -l | awk '{$1=$1;print}'`
     if [ "$RESP" == "0" ]; then
     CKF="metric_out.tsv"
     RESP=`find $DIR -name $CKF | wc -l | awk '{$1=$1;print}'`
       echo "found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
     fi
     if [ "$RESP" == "0" ]; then
     CKF="metric_out.csv"
     RESP=`find $DIR -name $CKF | wc -l | awk '{$1=$1;print}'`
       echo "found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
     fi
     if [ "$RESP" == "0" ]; then
     CKF="metric_out.csv.tsv"
     RESP=`find $DIR -name $CKF | wc -l | awk '{$1=$1;print}'`
     fi
     if [ "$RESP" != "0" ]; then
       echo "found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
       get_dir_list $CKF $DIR
       GOT_DIR=1
#       #RESP=`find $DIR -name $CKF -print0 | sort -z | xargs -0 cat`
#       if [ "$REGEX_LEN" != "0" ]; then
#         RESP2=`find $DIR -name $CKF -print | sort`
#         RESP=$RESP2
#         for ii in ${REGEX[@]}; do
#            RESP=`echo -e "$RESP" | grep "$ii"`
#         done
#         mydir=`echo -e "$RESP" | wc -l`
#         echo "mydir count= $mydir"
#       else
#         RESP=`find $DIR -name $CKF -print | sort | xargs `
#       fi
#       echo "found $CKF file in dir $DIR"
#       STR=
#       j=0
#       for ii in $RESP; do
#         NM=$(dirname $ii)
#           j=$((j+1))
#           if [ "$NUM_DIR" != "" -a "$NUM_DIR" != "0" -a $NUM_DIR -gt 0 -a $j -ge $NUM_DIR ]; then
#              echo "limit number of dirs with $CKF due to -N $NUM_DIR option"
#              break
#           fi
#         STR="$STR $NM"
#       done
#       DIR=$STR
#       #DIR=$(dirname $RESP)
       echo "using1 DIR= $DIR, orig DIR= $DIR_ORIG"
     fi
     if [ "$GOT_DIR" == "0" ]; then
       CKF="sys_*_perf_stat.txt"
       RESP=`find $DIR -name "$CKF" | wc -l | awk '{$1=$1;print}'`
       echo "got29 $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one." > /dev/stderr
       if [ "$RESP" == "0" ]; then
       CKF="sys_*_perf_stat.txt*"
       RESP=`find $DIR -name "$CKF" | wc -l | awk '{$1=$1;print}'`
       echo "got $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one." > /dev/stderr
       fi
       if [ "$RESP" != "0" ]; then
         echo "found41 $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one." > /dev/stderr
         RESP=`find $DIR -name "$CKF"|sort`
         if [ "$REGEX_LEN" != "0" ]; then
           RESP=`find $DIR -name "$CKF" | sort`
           for ii in ${REGEX[@]}; do
             RESP=`echo -e "$RESP" | grep "$ii"`
           done
           RESP3=`echo "$RESP" | wc -l`
           echo "mydir count= $mydir, resplines= $RESP3"
         fi
         echo "found51 $CKF file in dir $DIR"
         STR=
         j=0
         for ii in $RESP; do
           NM=$(dirname $ii)
           if [ $j -eq 0 ]; then
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
             echo "first sys_*_perf_stat.txt TS_INIT= $TS_INIT" > /dev/stderr
             echo "first sys_*_perf_stat.txt TS_INIT= $TS_INIT"
           fi
           STR="$STR $NM"
           j=$((j+1))
           if [ "$NUM_DIR" != "" -a $NUM_DIR -gt 0 -a $j -ge $NUM_DIR ]; then
              echo "limit number of dirs due to -N $NUM_DIR option"
              break
           fi
         done
         DIR=$STR
         #echo "using2 DIR= $DIR, orig DIR= $DIR_ORIG"
       else
         echo "didn't find 60secs.log nor metric_out nor sys_*_perf_stat.txt file under dir $DIR. Bye"
         exit
       fi
     fi
   else
     if [ "$GOT_DIR" == "0" ]; then
     echo "found54 $RESP 60secs.log file(s) under dir $DIR. Using the dir of first one if more than one."
     RESP=`find $DIR -name 60secs.log | head -1`
     echo "found55 60secs.log file in dir $RESP"
     DIR=$(dirname $RESP)
     echo "using3 DIR= $DIR, orig DIR= $DIR_ORIG"
     fi
   fi
fi


LST=$DIR
echo "DIR at 35: $DIR"
#exit

CDIR=`pwd`
ALST=$CDIR/tmp1.jnk
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

echo "LST= $LST" > /dev/stderr

DIR_1ST_DIR=
if [ "$INPUT_FILE_LIST" == "" ]; then
  NUM_DIRS=0
  for i in $LST; do
    if [ $NUM_DIRS -eq 0 ]; then
      DIR_1ST_DIR=$i
    fi
    #echo "dir_num= $NUM_DIRS dir= $i"
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
 pushd $i
 IFS="/" read -ra PARTS <<< "$(pwd)"
 XLS=
 for k in "${PARTS[@]}"; do
    if [ "$k" != "60secs" ]; then
       XLS=$k
    fi
 done
 echo "XLS= $XLS" > /dev/stderr
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
 echo "rps= $RPS, fctr= $FCTR"
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
    echo "$0: BEG_TM= $BEG_TM_IN"
 fi
 OPT_END_TM=
 if [ "$END_TM_IN" != "" ]; then
    OPT_END_TM=" -e $END_TM_IN "
 fi
 OPT_SKIP=
 if [ "$SKIP_XLS" == "1" ]; then
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
      #echo "build g opt= $OPT_G"
   done
   echo "new g opt= $OPT_G"
 fi
 if [ "$SKIP_SYS_2_TSV" == "0" ]; then
   if [ $VERBOSE -gt 0 ]; then
     echo "$SCR_DIR/sys_2_tsv.sh $OPT_a $OPT_A $OPT_G -p \"$RPS\" $OPT_DEBUG $OPT_SKIP $OPT_M -d . $OPT_CLIP $OPT_BEG_TM $OPT_END_TM -i \"*.png\" -s $SUM_FILE -x $XLS.xlsx -o $OPT_OPT $OPT_PH -t $DIR &> tmp.jnk" &
   fi
   if [ "$BACKGROUND" -le "0" ]; then
          $SCR_DIR/sys_2_tsv.sh $OPT_a $OPT_A $OPT_G -p "$RPS" $OPT_DEBUG $OPT_SKIP $OPT_M -d . $OPT_CLIP $OPT_BEG_TM $OPT_END_TM -i "*.png" -s $SUM_FILE -x $XLS.xlsx -o $OPT_OPT $OPT_PH -t $DIR &> tmp.jnk 
          RC=$?
          ck_last_rc $RC $LINENO
   else
          $SCR_DIR/sys_2_tsv.sh $OPT_a $OPT_A $OPT_G -p "$RPS" $OPT_DEBUG $OPT_SKIP $OPT_M -d . $OPT_CLIP $OPT_BEG_TM $OPT_END_TM -i "*.png" -s $SUM_FILE -x $XLS.xlsx -o $OPT_OPT $OPT_PH -t $DIR &> tmp.jnk &
          LPID=$!
          RC=$?
          BK_DIR[$LPID]=$i
          echo "LPID= $LPID, RC= $RC"
   fi
     LOAD=`uptime | awk '{printf("%.0f\n", $(NF-2)+0.5);}'`
     jbs=0
     for job in `jobs -p`
     do
       #echo $job
       jbs=$((jbs+1))
     done
     jbs=$(($jbs+$LOAD))
   if [ "$jbs" -gt "$BACKGROUND" ]; then
     #jbs=0
     for job in `jobs -p`
     do
       echo "wait for jobs (jbs= $jbs) pid= $job"
       jbs=$((jbs-1))
       wait $job
       RC=$?
       if [ "$RC" != "0" ]; then
          echo "$0: sys_2_tsv.sh got error! bye at $LINENO" > /dev/stderr
          echo "$0: look at tmp.jnk file in last data dir for error messages" > /dev/stderr
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
 echo -e "FLS: dir_num= ${DIR_NUM} of ${DIR_NUM_MX}, elap_tm= $TS_DFF secs, ${FLS}" > /dev/stderr
 DIR_NUM=$(($DIR_NUM+1))
 popd
done

wait_for_all() {
     jbs=0
     for job in `jobs -p`
     do
       echo "wait for jobs (jbs= $jbs) pid= $job"
       wait $job
       RC=$?
       #if [ "$RC" == "1" -o "$RC" == "2" ]; then
       if [ "$RC" != "0" ]; then
          echo "$0: sys_2_tsv.sh got error RC= \"$RC\"! at $LINENO. bye. called by line $1" > /dev/stderr
          echo "$0: look at tmp.jnk file in last data dir for error messages" > /dev/stderr
          echo "$0: dir= ${BK_DIR[$job]}"
          tail -20 ${BK_DIR[$job]}/tmp.jnk
          exit 1
       fi
     done
}

wait_for_all $LINENO

for i in $LST; do
 pushd $i
 SM_FL=
 #if [ ! -e $SUM_FILE ]; then
   SM_FL=$i/$SUM_FILE
 #fi
 echo "$0 SM_FL= $SM_FL  SUM_FILE= $SUM_FILE"
 echo -e "-p\t\"$RPS\"" >> $ALST
 echo -e "-s\t2,2" >> $ALST
 if [ "$AVERAGE" == "1" ]; then
    echo -e "-A" >> $ALST
 fi
 if [ "$CLIP" != "" ]; then
    echo -e "-c $CLIP" >> $ALST
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
 popd
 FLS=`ls -1 $SM_FL $i/*txt.tsv`
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

SUM_ALL=sum_all.tsv
if [ -e $SUM_ALL ]; then
  MYDIR=`pwd`
  MYSUMALL="$MYDIR/$SUM_ALL"
  echo "got sum_all $SUM_ALL in $MYDIR"
fi
if [ "$INPUT_FILE_LIST" != "" ]; then
  echo "___$MYSUMALL" >> $ALST
  cat $INPUT_FILE_LIST >> $ALST
  DIR_1ST_DIR=`head -1 $INPUT_FILE_LIST`
  NUM_DIRS=2
fi

wait_for_all $LINENO

if [ "$SVGS" != "" ]; then
  $SCR_DIR/svg_to_html.sh $SVGS -r $FCTRS > tmp.html
  ck_last_rc $? $LINENO
fi
  
if [ $NUM_DIRS -gt 1 ]; then
  if [ -e $SUM_ALL ]; then
    rm $SUM_ALL
  fi
  echo "ALST= $ALST" > /dev/stderr
  got_pwd=`pwd`
  RESP=`grep sum.tsv $ALST | sed 's/sum.tsv/sum_all2.tsv/'`
  FLS=
  for ii in $RESP; do
    if [ -e $ii ]; then
      FLS="$FLS -i $ii"
    fi
  done
  if [ "$FLS" != "" ]; then
    echo "---------- got_pwd= $got_pwd --------------------"
    echo $SCR_DIR/compare_summary_table.sh $FLS -s sum_all.tsv -S "\t"
         $SCR_DIR/compare_summary_table.sh $FLS -s sum_all.tsv -S "\t"
    ck_last_rc $? $LINENO
    MK_SUM_ALL=0
  else
    MK_SUM_ALL=1
  fi

  echo "$0: awk -v mk_sum_all="$MK_SUM_ALL" -v input_file=\"$ALST\" -v sum_all=\"$SUM_ALL\" -v sum_file=\"$SUM_FILE\" -v curdir=\"$got_pwd\" "
  awk -v mk_sum_all="$MK_SUM_ALL" -v input_file="$ALST" -v sum_all="$SUM_ALL" -v sum_file="$SUM_FILE" -v sum_all_avg_by_metric="$SUM_ALL_AVG_BY_METRIC" -v curdir="$got_pwd" '
    BEGIN{sum_files=0;fls=0; fld_m=3;fld_v=4; got_avgby=0;}
    { if (index($0, sum_file) > 0 || index($0, sum_all) > 0) {
        flnm = $0;
        fls++;
        fls_mx = fls;
        printf("got sumfile= %s sum_all= %s\n", flnm, sum_all) > "/dev/stderr";
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
                   printf("sum_all2 metric fld= %d nf= %d\n", 3, nh) > "/dev/stderr";
                }
                if (hdrs[3] == "Metric") {
                   fld_m=3; 
                   fld_v=4; 
                   printf("sum_all3 metric fld= %d nf= %d\n", 3, nh) > "/dev/stderr";
                   if (nh > 4) {
                     nflds= nh;
                   }
                }
              }
              continue;
           }
        #printf("got sum.tsv[%d][%d]= %s\n", fls, ln, line) > "/dev/stderr";
           n = split(line, arr, /\t/);
           mtrc = arr[fld_m];
           if (!(mtrc in mtrc_list)) {
              mtrc_list[mtrc] = ++mtrc_mx;
              mtrc_lkup[mtrc_mx] = mtrc;
           }
           mtrc_i = mtrc_list[mtrc];
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
             printf("fls= %d, flx_mx= %d\n", fls, fls_mx) > "/dev/stderr";
           }
        }
        fls = fls_mx;
        close(flnm)
      }
    }
 function ck_num(a) {
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

    END {
      if (mk_sum_all == 1) {
      ofile = sum_all;
      #printf("ofile= %s\n", ofile) > "/dev/stderr";
      printf("title\tsum_all\tsheet\tsum_all\ttype\tcopy\n")  > ofile;
      printf("hdrs\t2\t0\t-1\t%d\t-1\n", fls+3) > ofile;
      printf("Resource\tTool\tMetric") > ofile;
      if (got_avgby == 0 && fls > 1) {
          printf("\taverage") > ofile;
      }
      for (j=1; j <= fls; j++) {
         if (got_avgby == 1) {
          if (j == 1 || avgby_arr[j,1] != avgby_arr[j-1,1]) {
            printf("\t%d", avgby_arr[j,1]) > ofile;
          }
         } else {
            printf("\t%d", j-1) > ofile;
         }
      }
      printf("\n") > ofile;
      for (i=1; i <= mtrc_mx; i++) {
        mtrc = mtrc_lkup[i];
        if (mtrc == "") { continue; }
        if (mtrc == "data_sheet") {
          printf("\t%s\t%s", mtrc_arr[1,i], mtrc) > ofile;
        } else {
          printf("\titp\t%s", mtrc) > ofile;
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
                  sum_v = sum_v + val2;
                  sum_n = sum_n + 1;
                  }
                }
                if (sum_n > 0) {
                  printf("\t%s%f", equal, sum_v/sum_n) > ofile;
                } else {
                  printf("\t%s%s", equal, 0) > ofile;
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
                 printf("\t%s%s", "", "") > ofile;
              }
            }
          }
          printf("\t%s%s", equal, val) > ofile;
        }
        printf("\n") > ofile;
      }
      close(ofile);
      }
      flnm = input_file;
      printf("======---- input_file= %s\n", input_file) > "/dev/stderr";
        ln = 0;
        last_non_blank = -1;
        first_blank = -1;
        while ((getline line < flnm) > 0) {
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

      if [ "$BEG_TM_IN" != "" ]; then
        BEG_TM=$BEG_TM_IN
      fi
      if [ "$END_TM_IN" != "" ]; then
        END_TM=$END_TM_IN
      fi
  echo "=========== pwd = $got_pwd ========="
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
    echo "find_401 run.log RESP= $RESP"
    ITP_INTRVL=0
    if [ "$GOT_BE_TM" == 0 -a "$RESP" != "0" ]; then
      RUN_LOG=`find $USE_DIR -name run.log | head -1`
      echo "run_log file= $RUN_LOG"
      if [ "$BEG_TM_IN" != "" ]; then
        BEG_TM=$BEG_TM_IN
      else
        BEG_TM=`awk '/ start /{printf("%s\n", $2);}' $RUN_LOG`
      fi
      if [ "$END_TM_IN" != "" ]; then
        END_TM=$END_TM_IN
      else
        END_TM=`awk '/ end /{printf("%s\n", $2);}' $RUN_LOG`
      fi
      echo "beg_tm= $BEG_TM end_tm= $END_TM" > /dev/stderr
      echo "$BEG_TM" | awk '{print strftime("beg_time: %c %Z",$1)}' > /dev/stderr
      echo "$END_TM" | awk '{print strftime("end_time: %c %Z",$1)}' > /dev/stderr
      RESP_ITP=`find $USE_DIR -name run_itp.log | wc -l | awk '{$1=$1;print}'`
      if [ "$RESP_ITP" != "0" ]; then
         ITP_LOG=`find $USE_DIR -name run_itp.log | head -1`
         ITP_INTRVL=`awk '
            BEGIN{intrvl=0;}
            /perf\sstat/ {for (i=2; i < NF; i++) { if ($i == "-I" ) { intrvl= $(i+1); exit;}}}
            END{printf("%.0f\n", intrvl/1000);}
          ' $ITP_LOG`
         echo "ITP_INTERVAL= $ITP_INTRVL, log= $ITP_LOG" > /dev/stderr
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
    echo "find $INPUT_DIR -name muttley*.json | wc -l | awk '{$1=$1;print}'"
    RESP=`find $INPUT_DIR -name "muttley*.json" | wc -l | awk '{$1=$1;print}'`
    echo "find_51 muttley RESP= \"$RESP\"" 
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
      echo "find muttley*.json.tsv RESP= $tst_files"
      echo "muttley files_0: $tst_files" > /dev/stderr
      if [ "$tst_files" != "" ]; then
        for f in $tst_files; do
          echo "try muttley_a file= $f" > /dev/stderr
          if [ -e $f ]; then
             OPT_O=
             if [ "$OPTIONS" != "" ]; then
               OPT_O=" -o \"$OPTIONS\" "
             fi
             echo "try muttley log $f" 
             echo $SCR_DIR/resp_2_tsv.sh -b $BEG_TM -e $END_TM -f $f -s $SUM_ALL $OPT_O $OPT_M > /dev/stderr
                  $SCR_DIR/resp_2_tsv.sh -b $BEG_TM -e $END_TM -f $f -s $SUM_ALL $OPT_O $OPT_M
                   ck_last_rc $? $LINENO
          fi
          if [ -e $f.tsv ]; then
            echo "++++++++++ got $f.tsv "
             echo -e "$f.tsv" >> $ALST
             #SHEETS="$SHEETS $f.tsv"
             #echo "got latency log $f.tsv" > /dev/stderr
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
  OPT_TM=
  if [ "$BEG_TM_IN" != "" ]; then
     OPT_TM=" -b $BEG_TM_IN "
  fi
  if [ "$END_TM" != "" ]; then
     OPT_TM="$OPT_TM -e $END_TM "
  fi
      
  echo "====== begin $ALST ========"
  #cat $ALST
  head -50 $ALST
  echo "====== end $ALST ========"
  TS_DFF=$(($TS_CUR-$TS_BEG))
  echo "elap_tm= $TS_DFF"
  echo "about to do tsv_2_xls.py" > /dev/stderr
  echo "python $SCR_DIR/tsv_2_xlsx.py $OPT_a $OPT_A $OPT_TM $OPT_OPTIONS $OPT_M -f $ALST > tmp2.jnk"
        python $SCR_DIR/tsv_2_xlsx.py $OPT_a $OPT_A $OPT_TM $OPT_OPTIONS $OPT_M -f $ALST $SHEETS &> tmp2.jnk &
        PY_PID=$!
        echo "$0: tsv_2_xlsx.py exit with RC= $RC at line= $LINENO" > /dev/stderr
        echo $PY_PID >> tsv_2_xlsx.pid
        
  TS_CUR=`date +%s`
  TS_DFF=$(($TS_CUR-$TS_BEG))
  echo "elap_tm= $TS_DFF"
fi
