#!/usr/bin/env bash 
#SCR_DIR=`dirname $(readlink -e $0)`
#SCR_DIR=`dirname $0`
#SCR_DIR=`dirname "$(readlink -f "$0")"`
SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo "SCR_DIR= $SCR_DIR" > /dev/stderr


export LC_ALL=C
declare -a REGEX
declare -a SKU
declare -a LST_DIR_2_WORK_DIR
DIR=
PHASE_FILE=
OPT_OPT_DEF=chart_new,dont_sum_sockets
XLSX_FILE=
END_TM=
SKIP_XLS=0
WORK_DIR=`pwd`/work_dir
NUM_DIR=0
NUM_DIR_BEG=
AVERAGE_END=
MAX_VAL=
TS_INIT=
VERBOSE=0
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
RPS_ARR=()
SHEETS_DIR=()
SHEETS_OUT=()
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
AVERAGE=0
CLIPX=()
REDUCE=

while getopts "AhvSa:b:B:c:C:D:d:e:F:g:I:j:m:N:o:P:R:r:s:w:X:x:" opt; do
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
#    c )
#      COMBINE=$OPTARG
#      ;;
    C )
      CLIPX+=($OPTARG)
      ;;
    D )
      DEBUG_OPT=$OPTARG
      ;;
    d )
      DIR_IN=$OPTARG
      echo "$0.$LINENO input DIR_IN= $DIR_IN"
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
    s )
      SKU+=($OPTARG)
      ;;
    r )
      REGEX+=($OPTARG)
      ;;
    R )
      REDUCE=$OPTARG
      ;;
    w )
      WORK_DIR=$OPTARG
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
      echo "   -A flag indicating you want to average the same file from multiple dirs into 1 sheet."
      echo "          The default is to not average all the files (get 1 sheet per dir"
      echo "   -b begin_timestamp  exclude data until this timestamp (UTC epoch timestamp)"
      echo "   -B background_processs_allowed  max background processes allowed. if 0 then no background processes. default is $BACKGROUND"
#      echo "   -c combine_dirs_into_1_file  use this option if you've entered multiple dirs but want them all in 1 xlsx file. Currently you have to use an arg but it is ignored"
      echo "   -C clip_to_phase you can enter 1 per file/dir. Say you are doing 2 dirs and you want to select phase0 for dir 0 and phase1 of dir1:"
      echo "      '-C phase0 -C phase1' "
      echo "   -d dir containing sys_XX_* files created by 60secs.sh. If the dir haa multiple subdirs with sys_*.txt files then each dir will be used."
      echo "      You can enter multiple dirs explicitly by separating each dir with ':'"
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
      echo "         'line_for_scatter' substitute line charts for the scatter plots. If you want your xlsx to eventually be a google sheet, then use this option."
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
      echo "         'chart_size{width_scale,height_scale[,y_units,x_units]}' 2,2 is the default. (charts tiled left to right... about 15 cells wide and 30 rows high)."
      echo "            1,1,15,8 is good for multi-row charting (smaller charts)"
      echo "         'do_perlbench_subphase{1}'  this is a rarely used option. It tells sys_2_tsv.sh, when it is selecting a phase of the data,"
      echo "            to look for cpu2017 perlbench and look for the the 3 subphase workloads in cpu2017.001.log file."
      echo "            Need '-C perlaaaa' or '-C perlbbbb' or '-C perlcccc' and -P phase_file (-P phase_cpu2017.txt)."
      echo "   -P phase_file"
      echo "      should be in data dir. fmt='phase_name epoch_time_begin epoch_time_end'"
      echo "      if there are more than 3 fields, the extra fields are concatenated together (with ','s) and shown above each chart"
      echo "      You can use the e than 3 fields, the extra fields are concatenated together (with ','s) and shown above each chart"
      echo "   -R x,y     reduce amount of data by dropping x out of y rows from the tsv file."
      echo "      For example -R 1,2 will drop 1 out of 2 samples."
      echo "      reduce_tsv.sh reads the *.txt.tsv file and drops the rows from the txt.tsv file."
      echo "      You can prefix the x,y with str: to apply an x,y to specific file."
      echo "      For instance: -R infra_cputime:1,2,perf_stat:3,4  drops 1 out of 2 rows from infra_cputime.txt.tsv and 3 out of 4 rows from perf_stats txt.tsv file"
      echo "      Currently only perf_stats txt.tsv and infra_cputime txt.tsv files call the reduce_tsv.sh script"
      echo "   -r regex   regex expression to select directories"
      echo "   -S    skip creating detail xlsx file, just do the summary all spreadsheet"
      echo "   -s  sku_list  have to be able to figure host from path (or hostname.txt file) and must have lzc_info.txt info"
      echo "       sku_list  doesn't select dirs with sku at the moment."
      echo "       supports creating a 'sku' field by substituting:"
      echo "             %cpu_shrt% with short cpu name (ie if cpu name is Broadwell then replace %cpu_shrt% with bdw)"
      echo "             %cpu_long% with short cpu name (ie if cpu name is Broadwell then replace %cpu_long% with broadwell)"
      echo "             %host% with hostname"
      echo "             %sku% with sku string from lzc (ie 2T or B19a)"
      echo "             %cpu2017_threads% with the total number of threads of cpu2017 (assuming it is a cpu2017 run and the file perf_cpu_groups.txt exists"
      echo "           so if for '-s %sku%_%cpu_shrt%' you would get a string '1T_bdw' if the info for the host in that dir is 1T broadwell server"
      echo "           A 'sku' line (with the 'sku' for each server) gets added to the summary sheet"
      echo "   -w  work_dir  output tsv files will be put in this dir. Default is $WORK_DIR. Will be created if doesn't exist"
      echo "   -x xlsx_filename  This is passed to tsv_2_xlsx.py as the name of the xlsx. (you need to add the .xlsx)"
      echo "      The default is chart_line.xlsx"
      echo "   -X xlsx_filename  like above but assume path relative to current dir"
      echo "   -e ending_timestamp  cut off data files at this timestamp (UTC epoch)"
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

echo "$0.$LINENO work_dir= $WORK_DIR"
if [ ! -d $WORK_DIR ]; then
  mkdir -p $WORK_DIR
fi

RESP=`find $WORK_DIR -name "sheets.txt"`
if [ "$RESP" != "" ]; then
  echo "going to delete sheets.txt files= $RESP"
  find $WORK_DIR -name "sheets.txt" -exec rm {} \;
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
    NUM_DIR_BEG=0
    NUM_DIR_END=${NUM_DIR_ARR[0]}
  fi
  echo "NUM_DIR_ARR= ${NUM_DIR_ARR[@]}, ND0= ${NUM_DIR_ARR[0]}, ND1=${NUM_DIR_ARR[1]} NUM_DIR_BEG= $NUM_DIR_BEG NUM_DIR_END= $NUM_DIR_END" > /dev/stderr
fi

ck_skip_dir_due_to_num_dir () {
  #echo "$0.$LINENO dir_num= $1 NUM_DIR_IN= $NUM_DIR_IN ck beg $NUM_DIR_BEG end= $NUM_DIR_END" > /dev/stderr
  if [ "$1" != "" ]; then
    local j=$1
      if [ "$NUM_DIR_BEG" != "" ]; then
         if [ "$j" -lt "$NUM_DIR_BEG" ]; then
         echo "$0.$LINENO  job_id= $JOB_ID skip dir $j due to -N $NUM_DIR_IN option called by line $2" > /dev/stderr
         return 1
         fi
      fi
      if [ "$NUM_DIR_END" != "" ]; then
         if [ "$j" -gt "$NUM_DIR_END" ]; then
         echo "$0.$LINENO  job_id= $JOB_ID skip dir $j due to -N $NUM_DIR_IN option called by line $2" > /dev/stderr
         return 1
         fi
      fi
  fi
  return 0
}

REGEX_LEN=${#REGEX[@]}
SKU_LEN=${#SKU[@]}

SKIP_SYS_2_TSV=0
if [ "$OPTIONS" != "" ]; then
  if [[ $OPTIONS == *"skip_sys_2_tsv"* ]]; then
     SKIP_SYS_2_TSV=1
  fi
fi

INPUT_DIR=$DIR_IN

if [ $VERBOSE -gt 0 ]; then
  echo "$0.$LINENO SKIP_XLS= $SKIP_XLS"
fi

get_abs_filename() {
  # $1 : relative filename
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

get_abs_dir() {
  # $1 : relative filename
  echo "$(cd "$(dirname "$1")" && pwd)"
}

export AWKPATH=$SCR_DIR

get_hostname_from_path() {
  local USEDIR=$1
  if [ "$1" == "" ]; then
   USEDIR=`pwd`
  fi
  awk -v script="$0" -v lineno="$LINENO" -v usedir="$USEDIR" '
  BEGIN{
    n = split(usedir, arr, "/");
    for (i=n; i > 2; i--) {
       #if (arr[i] == arr[i-2] && index(arr[i-1], "-") > 0) {
       if (arr[i] == arr[i-2]) {
          printf("%s\n", arr[i-1]);
          exit;
       }
    }
    printf("%s.%s: missed_hostnm in %s\n", script, lineno, usedir) > "/dev/stderr";
    exit 1;
  }'
   ck_last_rc $? $LINENO
}

get_grail_info_for_hostname() {
  if [ "$1" != "" ]; then
    UHOSTNM=$1
  else
    UHOSTNM=$HOSTNM
  fi
  if [ "$2" != "" ]; then
    USUM_FILE=$2
  fi
if [ "$UHOSTNM" != "" ]; then
  CKFL=grail_cpu_info.txt
  if [ ! -e $CKFL ]; then
    CKFL=$BASE_DIR/grail_cpu_info.txt
  fi
  if [ $VERBOSE -gt 0 ]; then
    echo "_____ck  grail file $CKFL" > /dev/stderr
  fi
  if [ -e $CKFL ]; then
    if [ $VERBOSE -gt 0 ]; then
      echo "_____got grail hst= $UHOSTNM file $CKFL" > /dev/stderr
    fi
    #awk -v hst="$UHOSTNM" 'BEGIN{FS=";";} $1 == hst {printf("%s\n", $0); exit;}'
    SKU_NCPU_CPU_BOX_DISK=(`awk -v hst="$UHOSTNM" -v FS=";" '
      $1 == hst {
        n=split($0,a,";");
        sku   =a[2];
        cpus  =a[3]+0;
        if (cpus == 0) { cpus = ""; }
        brand =a[4];
        model =a[5];
        diskTB=a[6]+0;
        if (diskTB == 0) {diskTB = ""; }
        owner =a[7];
        printf("\"%s\"\n%s\n\"%s\"\n\"%s\"\n%s\n\"%s\"\n", sku, cpus, brand, model,diskTB, owner); exit 0;}
        ' $CKFL`)
    ck_last_rc $? $LINENO
    #echo "_____got grail sku= ${SKU_NCPU_CPU_BOX_DISK[@]}" > /dev/stderr
    if [ "$USUM_FILE" != "" ]; then
      V=${SKU_NCPU_CPU_BOX_DISK[0]}
      if [ "$V" == "" ]; then
        V="unknown"
      fi
      #printf "host\tSKU\t\"%s\"\tSKU\n"  "$V" >> $USUM_FILE;
      printf "host\tSKU\t%s\tSKU\n"  $V >> $USUM_FILE;
  
      V=${SKU_NCPU_CPU_BOX_DISK[4]}
      if [ "$V" == "" ]; then
        V=0
      fi
      printf "host\tdisk_GBs\t%s\tdisk_GBs\n"  "$V" >> $USUM_FILE;
  
      V=${SKU_NCPU_CPU_BOX_DISK[3]}
      if [ "$V" == "" ]; then
        V="unknown"
      fi
      #printf "host\thost_make\t\"%s\"\thost_make\n"  "$V" >> $USUM_FILE;
      printf "host\thost_make\t%s\thost_make\n"  "$V" >> $USUM_FILE;
  
      V=${SKU_NCPU_CPU_BOX_DISK[2]}
      if [ "$V" == "" ]; then
        V="unknown"
      fi
      #printf "host\tcpu_string\t\"%s\"\tcpu_string\n"  "$V" >> $USUM_FILE;
      printf "host\tcpu_string\t%s\tcpu_string\n"  "$V" >> $USUM_FILE;
  
      V=${SKU_NCPU_CPU_BOX_DISK[5]}
      if [ "$V" == "" ]; then
        V="unknown"
      fi
      #printf "host\towner\t\"%s\"\towner\n"  "$V" >> $USUM_FILE;
      printf "host\towner\t%s\towner\n"  "$V" >> $USUM_FILE;
    fi
  fi
fi
}

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
   local j=-1
   for ii in $RESP; do
      NM=$(dirname $ii)
      j=$((j+1))
      if [ "$NUM_DIR" != "" -a "$NUM_DIR" != "0" -a $NUM_DIR -gt 0 -a $j -ge $NUM_DIR ]; then
         echo "$0.$LINENO  job_id= $JOB_ID limit number of dirs with $CKF due to -N $NUM_DIR option"
         break
      fi
      ck_skip_dir_due_to_num_dir $j $LINENO
      if [ "$?" == "1" ]; then
        continue
      fi
      STR="$STR $NM"
   done
   DIR=$STR
   echo "$0.$LINENO +___________-- get_dir_list: j= $j DIR= $DIR" > /dev/stderr
}

OPT_a=
if [ "$AVG_DIR" != "" ]; then
  if [ "$AVERAGE" == "0" ]; then
     echo "$0: cmdline options has -a $AVG_DIR but you didn't specify -A option. Bye" > /dev/stderr
     exit 1
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
   DIR_ORIG=$DIR_IN
   IFS=':' read -ra DIR_IN_ARR <<< "$DIR_IN"
   IFS=$IFS_SV
   STR=
   echo "$0.$LINENO DIR_IN_ARR= ${DIR_IN_ARR[@]}"
   for ((dn=0; dn < ${#DIR_IN_ARR[@]}; dn++)); do
     DIR=${DIR_IN_ARR[$dn]}
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
       CKF="run_itp.log"
       RESP=`find $DIR -name $CKF | wc -l | awk '{$1=$1;print}'`
       #echo "found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
     fi
     if [ "$RESP" == "0" ]; then
       CKF="infra_cputime.txt"
       RESP=`find $DIR -name $CKF | wc -l | awk '{$1=$1;print}'`
       #echo "found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
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
               #echo "$0.$LINENO: ck $NM/run.log got TS_INIT= $TS_INIT"
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
      ck_skip_dir_due_to_num_dir $j $LINENO
      if [ "$?" == "1" ]; then
        continue
      fi
      j=$((j+1))
      STR="$STR $NM"
           if [ "$NUM_DIR" != "" -a $NUM_DIR -gt 0 -a $j -ge $NUM_DIR ]; then
              echo "$0.$LINENO  job_id= $JOB_ID limit number of dirs due to -N $NUM_DIR option"
              break
           fi
         done
         DIR=$STR
         DIR_OUT_ARR[$dn]=$STR
         DIR_OUT="$DIR_OUT $STR"
         echo "$0.$LINENO: -__________- using2 DIR= $DIR, orig DIR= $DIR_ORIG" > /dev/stderr
       else
         echo "$0.$LINENO: didn't find 60secs.log nor metric_out nor sys_*_perf_stat.txt file under dir $DIR. dir_orig= $DIR_ORIG at line $LINENO Bye"
         #exit 1
       fi
     fi
   else
     if [ "$GOT_DIR" == "0" ]; then
     echo "$0.$LINENO found54 $RESP 60secs.log file(s) under dir $DIR. Using the dir of first one if more than one."
     RESP=`find $DIR -name 60secs.log | head -1`
     echo "$0.$LINENO found 60secs.log file in dir $RESP"
     DIR=$(dirname $RESP)
     echo "$0.$LINENO using3 DIR= $DIR, orig DIR= $DIR_ORIG"
     else
         DIR_OUT="$DIR_OUT $DIR"
     fi
   fi
   done

   echo "$0.$LINENO after DIR_IN_ARR loop STR= $STR"
   echo "$0.$LINENO dir_out= $DIR_OUT"
   DIR=$DIR_OUT
   for i in $DIR; do echo "$0.$LINENO got dir $i"; done
fi


LST=$DIR
echo "$0.$LINENO DIR_ORIG= $DIR_ORIG, DIR= $DIR LST= $LST"
if [ $VERBOSE -gt 0 ]; then
  echo "$0.$LINENO DIR: $DIR"
fi


#pwd > /dev/stderr
#  echo "$0.$LINENO DIR: $DIR"
#exit 1
declare -A PHS_ARR
declare -A PHS_DIR_LIST
declare -A PHS_DIR_LKUP
declare -A PHS_DIR_NAME
#PHS_ARR=()
j=-1
for i in $LST; do
  j=$((j+1))
  if [ $VERBOSE -gt 0 ]; then
    echo "$0.$LINENO dir $i"
  fi
      ck_skip_dir_due_to_num_dir $j $LINENO
      if [ $? == 1 ]; then
        continue
      fi
    for k in 2 1; do
      if [ $VERBOSE -gt 0 ]; then
        echo "$0.$LINENO try phase_cpu2017.txt find $i -name CPU2017.00$k.log"
      fi
      ARR=(`find $i -name CPU2017.00$k.log`)
      for ((kk=0; kk < ${#ARR[@]}; kk++)); do
        v=`dirname ${ARR[$kk]}`
        if [ $VERBOSE -gt 0 ]; then
           echo "$0.$LINENO: $SCR_DIR/cpu2017_2_phasefile.sh -i ${ARR[$kk]} -o $v/phase_cpu2017.txt  -O $OPTIONS"
        fi
                             $SCR_DIR/cpu2017_2_phasefile.sh -i ${ARR[$kk]} -o $v/phase_cpu2017.txt  -O "$OPTIONS"
      done
      if [ "${#ARR[@]}" != "0" ]; then
        break
      fi
    done
  if [ "$PHASE_FILE" != "" ]; then
    RESP=`find $i -name $PHASE_FILE`
    echo "$0.$LINENO find phase= $RESP"
    if [ "${#CLIPX[@]}" != "0" -a "$RESP" != "" ]; then
      cat $RESP
#abcd
      kk=${#CLIPX[@]}
      if [ "$j" -ge "$kk" ]; then
        echo "$0.$LINENO using the first CLIPX phase string due to current dir index $j >= numbr of CLIPX entries ($kk)"
        kk=0
      else
        kk=$j
      fi
      echo "dir LST= $LST"
      CLIP_BEG_END=(`cat $RESP | awk -v clip="${CLIPX[$kk]}" '{if (index($0, clip) > 0) { for (i=1; i <= NF; i++) { printf("%s\n", $i)};exit;}}'`)
      ck_last_rc $? $LINENO
      CLIP_BEG_END_LINE=`cat $RESP | awk -v clip="${CLIPX[$kk]}" '{if (index($0, clip) > 0) { printf("%s\n", $0);exit;}}'`
      ck_last_rc $? $LINENO
      echo "$0.$LINENO clip_beg_end_line= $CLIP_BEG_END_LINE"
      echo "$0.$LINENO clipx_use= ${CLIPX[$kk]} j= $j CLIPX= ${CLIPX[@]} CLIP_BEG_END= ${CLIP_BEG_END[@]}"
      if [[ ${CLIP_BEG_END[1]} != "" ]] && [[ ${CLIP_BEG_END[2]} != "" ]]; then
        PHS_CLIPX[$j]=$kk
        PHS_DIR_NAME[$i,$kk]=$j
        PHS_DIR_LIST[$i]=$j
        PHS_DIR_LKUP[$j]=$i
        PHS_ARR[$j,"clipx_idx"]=$kk
        PHS_ARR[$j,"name"]=${CLIP_BEG_END[0]}
        PHS_ARR[$j,"beg"]=${CLIP_BEG_END[1]}
        PHS_ARR[$j,"end"]=${CLIP_BEG_END[2]}
        PHS_ARR[$j,'line']="${CLIP_BEG_END_LINE}"
        PHS_ARR[$j,'extra']=""
        for ((k2=3; k2 < ${#CLIP_BEG_END[@]}; k2++)); do
          PHS_ARR[$j,'extra']="${PHS_ARR[$j,'extra']},${CLIP_BEG_END[$k2]}"
          echo "PHS_ARR[$j,'extra']=${PHS_ARR[$j,'extra']} and CLIP_BEG_END[$k2]= ${CLIP_BEG_END[$k2]}"
        done
      fi
    fi
  fi
done
echo "$0.$LINENO PHS_ARR= ${PHS_ARR[@]}"
#echo "$0.$LINENO PHS_DIR_LKUP= ${PHS_DIR_LKUP[@]}"
#exit 1
declare -A LZC_ARR_BY_HOST
declare -A LZC_ARR_BY_DIR
declare -A LZC_ARR_BY_DIR_NUM
declare -A LSS_ARR_BY_HOST

if [ "$SKU_LEN" != "0" ]; then
  echo "$0.$LINENO SKU= ${SKU[@]}"
   if [ "$SKU_LEN" != "0" ]; then
      itot=-1
      ii=0
      RESP=
      for idir in $DIR; do
        itot=$((itot+1))
        if [ $VERBOSE -gt 1 ]; then
          echo "__________sku try dir= $idir"
        fi
        #echo "$0.$LINENO DIRs= $DIR. bye"
        IFS='/' read -r -a PATH_ARR <<< "$idir"
        IFS=$IFS_SV
        CK_HST_NM=`find $idir -name hostname.txt`
        if [ "$CK_HST_NM" == "" ]; then
          CK_HST_NM=`find $idir/.. -name hostname.txt`
          if [ "$CK_HST_NM" == "" ]; then
            CK_HST_NM=`find $idir/../../ -name hostname.txt`
          fi
        fi
        if [ $VERBOSE -gt 1 ]; then
          echo "$0.$LINENO ck_hst_nm ${CK_HST_NM}"
        fi
        if [ "$CK_HST_NM" != "" ]; then
          CK_LNS=`echo "$CK_HST_NM" | wc -l`
          if [ "$CK_LNS" -ne "1" ]; then
            CK_HST_NM=
          fi
        fi 
        if [ $VERBOSE -gt 1 ]; then
          echo "$0.$LINENO path_arr= ${PATH_ARR[@]}"
          echo "ck_hst_nm ${CK_HST_NM}"
        fi
        LZC="lzc_info.txt"
        CLS="clusto_info.lst"
        LLS="lab_info.lst"
        STR=$idir
        for ((jj=${#PATH_ARR[@]}-1; jj >= 0; jj--)); do
          LZC_FL=`find $STR  -maxdepth 1 \( -name "$LZC" -o -name "$CLS" -o -name "lzc_info.lst" -o -name "clusto_info.txt" -o -name "do_lzc_info.txt" -o -name "$LLS" \)`
          STR=`dirname $STR`
          if [ "$LZC_FL" != "" ]; then
            break
          fi
          if [ "$STR" == "" ]; then
            break
          fi
        done
        if [ $VERBOSE -gt 1 ]; then
          echo "$0.$LINENO PATH_ARR0= ${PATH_ARR[0]}"
          echo "$0.$LINENO LZC_FL= $LZC_FL"
        fi

        CK_HST_NM=`find $idir -name hostname.txt`
        CK_LSC_NM=`find $idir -name lscpu.txt`
        if [ "$CK_HST_NM" == "" ]; then
          CK_HST_NM=`find $idir/.. -name hostname.txt`
          CK_LSC_NM=`find $idir/.. -name lscpu.txt`
          if [ "$CK_HST_NM" == "" ]; then
            CK_HST_NM=`find $idir/../../ -name hostname.txt`
            CK_LSC_NM=`find $idir/../../ -name lscpu.txt`
          fi
        fi
        if [ $VERBOSE -gt 1 ]; then
          echo "ck_hst_nm ${CK_HST_NM}"
        fi
        if [ "$CK_HST_NM" != "" ]; then
          CK_LNS=`echo "$CK_HST_NM" | wc -l`
          if [ "$CK_LNS" -ne "1" ]; then
            CK_HST_NM=
          fi
        fi 
        if [ "$CK_HST_NM" != "" ]; then
          GOT_HST=`cat $CK_HST_NM`
        fi
        HOSTNM=`get_hostname_from_path $idir`
        if [ "$HOSTNM" != "" ]; then
          echo "$0.$LINENO got hostname file= $GOT_HST, hostname from path= $HOSTNM dir_num= $itot"
          GOT_HST=$HOSTNM
        fi
        if [ "$LZC_FL" == "" ]; then
          LZC_FL=$LLS
        fi
        if [[ $LZC_FL == *$LLS* ]]; then
          LZC_FL="${PATH_ARR[0]}/$LLS"
          if [ "${LSS_ARR_BY_HOST[$HOSTNM]}" == "" ]; then
            if [ "$itot" == "0" ]; then
              echo "Name: $HOSTNM" > $LZC_FL
            else
              echo "Name: $HOSTNM" >> $LZC_FL
            fi
            # so we don't add this hostname multiple times to the file
            LSS_ARR_BY_HOST[$HOSTNM]=1
          fi
        fi
        if [ "$CK_LSC_NM" != "" ]; then
          GOT_CPU=`$SCR_DIR/decode_cpu_fam_mod.sh $CK_LSC_NM`
        fi
        CK_PCG_NM=`find $idir -name perf_cpu_groups.txt`
        if [ $VERBOSE -gt 1 ]; then
          echo "$0.$LINENO got PK_PCG_NM= $CK_PCG_NM"
        fi
        if [ "$CK_PCG_NM" != "" ]; then
          if [ -e $CK_PCG_NM ]; then
            CPU2017_THRDS=`awk '/^all.all/{n=split($0, arr, "\t"); if (n==3) { n=split(arr[3], brr, ","); printf("%s\n", n); exit(0);}}' $CK_PCG_NM`
            if [ $VERBOSE -gt 1 ]; then
              echo "$0.$LINENO got CPU2017_THRDS= $CPU2017_THRDS"
            fi
          fi
        fi
#xyz
        if [ $VERBOSE -gt 1 ]; then
          echo "$0.$LINENO got LZC_FL= $LZC_FL"
           echo $0.$LINENO awk -v infile="$LZC_FL" -v host="$GOT_HST" -v sku_in="${SKU[@]}" -v cpu_fam="$GOT_CPU" -v cpu2017_thrds="$CPU2017_THRDS"
        fi
                  LZC_OUT=$(awk -v infile="$LZC_FL" -v host="$GOT_HST" -v sku_in="${SKU[@]}" -v cpu_fam="$GOT_CPU" -v cpu2017_thrds="$CPU2017_THRDS" '
          BEGIN{
            printf("host= %s, sku= %s, cpu_fam= %s\n", host, sku_in, cpu_fam) > "/dev/stderr";
            str = tolower(cpu_fam);
            if (index(str, "sky") > 0) { cpu = "skx"; }
            if (index(str, "cascade") > 0) { cpu = "csx"; }
            if (index(str, "broad") > 0) { cpu = "bdw"; }
            if (index(str, "milan") > 0) { cpu = "mln"; }
            if (index(str, "haswell") > 0) { cpu = "hsw"; }
            if (index(infile, "lzc_info") > 0) {
              mode="lzc";
            } else {
              mode="clusto"
            }

            got_match=0;
          }
          $1 == "Hostname" || $1 == "Name:" {
            got_match = 0;
            #  printf("______got lzc host= %s, lkfor host= %s\n", $2, host) > "/dev/stderr";
            if (NF == 2 && $2 == host) {
              printf("______got lzc host= %s\n", host);
              host_list[host] = ++host_mx;
              host_lkup[host_mx] = host;
              host_i = host_list[host];
              got_match=1;
            }
          }
          got_match == 1 {
            #printf("lzc line= %s\n", $0);
            if (mode == "lzc") {
              #printf("++++++++got_lzc line= %s\n", $0) > "/dev/stderr";
              if ($1 == "Provider" && $2 == "Type") {
                prov_typ = $3;
              }
              if ($1 == "Is" && $2 == "Crane") {
                is_crane = $3;
              }
              if ($1 == "SKU:") {
                sv[host_i,"sku"] = $2;
              }
              if ($1 == "Type") {
                typ = $2;
              }
              if ($1 == "Services") {
                sv[host_i,"ptyp"] = prov_typ;
                sv[host_i,"typ"] = typ;
                sv[host_i,"is_crane"] = is_crane;
                $1="";
                sv[host_i,"services"] = $0;
                #got_match = 0;
                #exit(0);
              }
            } else {
              #printf("++++++++got_clusto line= %s\n", $0) > "/dev/stderr";
              if (index($0, "Sku:") == 1) {
               sv[host_i,"is_crane"] = "no";
               sv[host_i,"services"] = "n/a";
               sv[host_i,"sku"] = $2;
               sv[host_i,"ptyp"] = $2;
               #printf("++++++++got_clusto sku= %s\n", $2) > "/dev/stderr";
               got_match = 0;
              }
              if (index("$0", "----------") == 1) {
               got_match = 0;
              }
            }
          }
          END{
            for (i=1; i <= host_mx; i++) {
              printf("host;%s\n", host_lkup[i]);
              printf("ptyp;%s\n", sv[i,"ptyp"]);
              printf("typ;%s\n", sv[i,"typ"]);
              printf("crane;%s\n", sv[i,"is_crane"]);
              printf("cpu_long;%s\n", cpu_fam);
              printf("cpu_shrt;%s\n", cpu);
              printf("services;%s\n", sv[i,"services"]);
              printf("cpu2017_threads;%s\n", cpu2017_thrds);
              gsub("%cpu_shrt%", cpu, sku_in);
              gsub("%host%", host, sku_in);
              if ((i,"sku") in sv) {
                sku = sv[i,"sku"];
              } else {
                sku = sv[i,"ptyp"];
                if (sv[i,"is_crane"] == "yes") {
                  sku = sv[i,"typ"];
                }
              }
              gsub("%sku%", sku, sku_in);
              gsub("%cpu_long%", cpu, sku_in);
              gsub("%cpu2017_threads%", cpu2017_thrds, sku_in);
              printf("sku;%s\n", sku_in);
            }
            exit(0);
          } ' $LZC_FL)
          RC=$?
           echo $0.$LINENO awk -v infile="$LZC_FL" -v host="$GOT_HST" -v sku_in="${SKU[@]}" -v cpu_fam="$GOT_CPU" -v cpu2017_thrds="$CPU2017_THRDS"
          ck_last_rc $RC $LINENO
        #if [ $VERBOSE -gt 1 ]; then
           echo "LZC_out= $LZC_OUT"
        #fi
        if [ "$LZC_OUT" != "" ]; then
          LZC_ARR_BY_DIR[$idir]="$LZC_OUT"
          LZC_ARR_BY_DIR_NUM[$itot]="$LZC_OUT"
          LZC_ARR_BY_HOST[$GOT_HST]="$LZC_OUT"
          if [ $VERBOSE -gt 1 ]; then
            echo "$0.$LINENO LZC_ARR_BY_DIR_NUM[$itot]= ${LZC_ARR_BY_DIR_NUM[$itot]}"
            echo "$0.$LINENO LZC_ARR_BY_DIR[$idir]= ${LZC_ARR_BY_DIR[$idir]}"
          fi
        fi
        RESP="$RESP $idir"
        if [ "1" == "2" ]; then
        get_hostname_from_path $idir
        if [ "$HOSTNM" != "" ]; then
          get_grail_info_for_hostname $HOSTNM
          if [ "${#SKU_NCPU_CPU_BOX_DISK[@]}" != 0 ]; then
             V=${SKU_NCPU_CPU_BOX_DISK[0]}
             if [ $VERBOSE -gt 0 ]; then
               echo "__________HOSTNM= $HOSTNM , sku= $V"
             fi
             for ij in ${SKU[@]}; do
               if [ "$V" == "\"$ij\"" ]; then
                 if [ $VERBOSE -gt 0 ]; then
                   echo "__match __HOSTNM= $HOSTNM , sku= $V"
                 fi
                 RESP="$RESP $idir"
                 ii=$((ii+1))
                 break
               fi
             done
          fi
        fi
        fi
      done
      DIR=$RESP
      LST=$DIR
      if [ $VERBOSE -gt 1 ]; then
        echo "+__________$0.$LINENO input dirs= $itot. got matches= $ii for skus= ${SKU[@]}" > /dev/stderr
      fi
   fi
fi
#echo "$0.$LINENO bye"
#exit 1

CDIR=`pwd`
ALST=$WORK_DIR/$JOB_ID/tsv_2_xlsx_${JOB_ID}.inp
#echo "ALST= $ALST"
if [ -e $ALST ]; then
  rm $ALST
fi
OXLS=tmp.xlsx
if [ "$AXLSX_FILE" != "" ]; then
  SFX=
  if [ "$JOB_ID" -gt "0" ]; then
    SFX="_$JOB_ID"
  fi
  OXLS=${AXLSX_FILE}${SFX}.xlsx
fi



if [ $VERBOSE -gt 0 ]; then
  echo "$0.$LINENO LST= $LST" > /dev/stderr
fi

#echo "$0.$LINENO: DIR_LST= $LST" > /dev/stderr
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

echo "$0.$LINENO bef OXLS= $OXLS"

shopt -s nullglob
echo -e "-o\t$OXLS" >> $ALST
FCTRS=
SVGS=
SUM_FILE=sum.tsv

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
 i_abs_dir=$(get_abs_dir $i)
 if [ "$DESC_FILE" == "" ]; then
      echo "ck  i_ibs_dir desc.txt= $i/desc.txt"
   if [ -e $i/desc.txt ]; then
      FLS=$(get_abs_filename "$i/desc.txt")
      echo "got i_ibs_dir desc.txt= $FLS"
      if [ -e $FLS ]; then
        OPT_DESC_FILE="$FLS"
       echo "$0.$LINENO set -d6 desc_file= $OPT_DESC_FILE, i= $i"
        echo "got opt_desc_file= $FLS"
       OPT_DESC_FILE_ARR[$DIR_NUM]=$OPT_DESC_FILE
      fi
   fi
 fi
 #IDIR_ABS      OPT_DESC_FILE=$(get_abs_filename "$i/desc.txt")
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
 if [ "$RPS" != "" ]; then
 if [[ $RPS =~ v[0-9]* ]]; then
   RC=`echo $i | awk '/cpus/{n=split($0, arr, "_"); str=""; for (i=1; i <= n; i++) { if (index(arr[i], "cpus") > 0) { str = arr[i]; } }} END{printf("%s", str);}'`
   if [ "$RC" != "" ]; then
     RPS=$RC
     if [ $NUM_DIRS -gt 1 ]; then
       RPS_ARR[$DIR_NUM]=$RC
     else
       RPS_ARR[$JOB_ID]=$RC
     fi
     printf "RPS_ARR[%s]= %s, NUM_DIRS= %d DIR_NUM= %d\n" $JOB_ID $RC $NUM_DIRS $DIR_NUM > /dev/stderr
     if [ "$OPT_DESC_FILE" == "" ]; then
       if [ "$AVERAGE" != "0" ]; then
       printf "$0.$LINENO opt_desc_file RC= %s i= %s\n"  $RC $i_abs_dir/desc.txt > /dev/stderr
       echo "$RC" > $i_abs_dir/desc.txt
       OPT_DESC_FILE=$(get_abs_filename "$i_abs_dir/desc.txt")
       echo "$0.$LINENO set -d5 desc_file= $OPT_DESC_FILE"
       printf "$0.$LINENO opt_desc_file= %s  i= %s\n" $OPT_DESC_FILE $i_abs_dir > /dev/stderr
       OPT_DESC_FILE_ARR[$DIR_NUM]=$OPT_DESC_FILE
       echo "$0.$LINENO OPT_DESC_FILE_ARR[$DIR_NUM]=$OPT_DESC_FILE"
       fi
     fi
   fi
 fi
 fi
 if [ "$SUM_FILE" != "" ]; then
   if [ -e $SUM_FILE ]; then
     rm $SUM_FILE
   fi
   if [ -e "$SUM_FILE.dist" ]; then
     rm "$SUM_FILE.dist"
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
 if [ "$AVERAGE" == "1" -o "$DIR_NUM_MX" == "1" ]; then
 if [ "$END_TM_IN" != "" ]; then
    OPT_END_TM=" -e $END_TM_IN "
 fi
 fi
 #DIRN=${PHS_DIR_LIST[$i]}
 DIRN=${PHS_DIR_NAME[$i,${PHS_CLIPX[$DIR_NUM]}]}
 if [ $VERBOSE -gt 0 ]; then
   echo "$0.$LINENO phs_arr dirn= $DIRN"
 fi
 if [ "$DIRN" != "" ]; then
   OPT_BEG_TM=" -b ${PHS_ARR[$DIRN,'beg']} "
   OPT_END_TM=" -e ${PHS_ARR[$DIRN,'end']} "
   echo "$0.$LINENO phs_arr dirn= $DIRN OPT_BEG_TM= $OPT_BEG_TM OPT_END_TM= $OPT_END_TM"
 fi
 OPT_SKIP=
 if [ "$SKIP_XLS" -gt "0" ]; then
   OPT_SKIP=" -S "
 fi
 OPT_M=
 if [ "$MAX_VAL" != "" ]; then
   OPT_M=" -m $MAX_VAL "
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
 if [ $VERBOSE -gt 0 ]; then
   echo "$0.$LINENO file_sets options= $OPTIONS"
   echo "$0.$LINENO file_sets opt_opt= $OPT_OPT"
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
   JOB_WORK_DIR=$WORK_DIR/$JOB_ID/$DIR_NUM
   if [ ! -d $JOB_WORK_DIR ]; then
     mkdir -p $JOB_WORK_DIR
   else
     rm $JOB_WORK_DIR/*
   fi
   SYS_2_TSV_STDOUT_FILE=$JOB_WORK_DIR/sys_2_tsv_stdout.txt
 if [ "$SKIP_SYS_2_TSV" == "0" ]; then
   if [ $VERBOSE -gt 0 ]; then
     OPT_P=$RPS
     if [ $NUM_DIRS -gt 1 ]; then
       RESP=${RPS_ARR[$DIR_NUM]}
     else
       RESP=${RPS_ARR[$JOB_ID]}
     fi
     #printf "RPS_ARR[%s]= %s, NUM_DIRS= %d DIR_NUM= %d\n" $JOB_ID $RC $NUM_DIRS $DIR_NUM > /dev/stderr
     if [ "$RESP" != "" ]; then
       OPT_P=$RESP
     fi
   fi
   OPT_REDUCE=
   if [ "$REDUCE" != "" ]; then
     OPT_REDUCE=" -R $REDUCE "
   fi

   if [ "${LZC_ARR_BY_DIR[$i]}" != "" ]; then
     echo "${LZC_ARR_BY_DIR[$i]}" > $JOB_WORK_DIR/lzc_info.txt
   fi

   echo "$0.$LINENO: $SCR_DIR/sys_2_tsv.sh -B $CDIR $OPT_a $OPT_A $OPT_G -j $JOB_ID -p \"$OPT_P\" $OPT_DEBUG $OPT_REDUCE $OPT_SKIP $OPT_M -d . $OPT_BEG_TM $OPT_END_TM -i \"*.png\" -s $SUM_FILE -x $XLS.xlsx -o \"$OPT_OPT\" $OPT_PH -w $JOB_WORK_DIR -t $DIR" > $SYS_2_TSV_STDOUT_FILE
   if [ "$BACKGROUND" -le "0" ]; then
          $SCR_DIR/sys_2_tsv.sh -B $CDIR $OPT_a $OPT_A $OPT_G -j $JOB_ID -p "$OPT_P" $OPT_DEBUG $OPT_REDUCE $OPT_SKIP $OPT_M -d . $OPT_BEG_TM $OPT_END_TM -i "*.png" -s $SUM_FILE -x $XLS.xlsx -o "$OPT_OPT" $OPT_PH -w $JOB_WORK_DIR -t $DIR &>> $SYS_2_TSV_STDOUT_FILE
          RC=$?
          ck_last_rc $RC $LINENO
   else
          $SCR_DIR/sys_2_tsv.sh -B $CDIR $OPT_a $OPT_A $OPT_G -j $JOB_ID -p "$OPT_P" $OPT_DEBUG $OPT_REDUCE $OPT_SKIP $OPT_M -d . $OPT_BEG_TM $OPT_END_TM -i "*.png" -s $SUM_FILE -x $XLS.xlsx -o "$OPT_OPT" $OPT_PH -w $JOB_WORK_DIR -t $DIR &>> $SYS_2_TSV_STDOUT_FILE &
          LPID=$!
          RC=$?
          BK_DIR[$LPID]=$i
          BK_OUT[$LPID]=$SYS_2_TSV_STDOUT_FILE
          SHEETS_DIR+=($i)
          SHEETS_OUT+=("$JOB_WORK_DIR/sheets.txt")
          if [ $VERBOSE -gt 0 ]; then
            echo "$0.$LINENO LPID= $LPID, RC= $RC"
          fi
   fi
     LST_DIR_2_WORK_DIR[$DIR_NUM]=$JOB_WORK_DIR
     if [ $VERBOSE -gt 0 ]; then
       echo "$0.$LINENO LST_DIR_2_WORK_DIR[$DIR_NUM]= ${LST_DIR_2_WORK_DIR[$DIR_NUM]}"
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
          echo "$0:$LINENO sys_2_tsv.sh got error RC= \"$RC\"! at $LINENO. bye. called by line $1" > /dev/stderr
          echo "$0:$LINENO look at ${BK_OUT[$job]} in last data dir for error messages" > /dev/stderr
          echo "$0:$LINENO dir= ${BK_DIR[$job]}"
          #tail -20 ${BK_DIR[$job]}/${BK_OUT[$job]}
          echo "tail -20 ${BK_OUT[$job]}"
          tail -20 ${BK_OUT[$job]}
          exit 1
       fi
     done
}

wait_for_all $LINENO

CHART_SIZE=`echo -e "$OPTIONS" | awk '/chart_size{/{pos = index($0, "chart_size{"); str = substr($0, pos, length($0)); pos = index(str, "{"); str = substr(str, pos+1, length(str)); pos = index(str, "}"); str = substr(str, 1, pos-1); printf("%s", str); }'`
if [ "$CHART_SIZE" == "" ]; then
  CHART_SIZE="1,1,15,8"
fi

TCUR_DIR=`pwd`


MUTT_ARR=()
i_idx=-1
for i in $LST; do
 i_idx=$((i_idx+1))
 USE_WORK_DIR=${LST_DIR_2_WORK_DIR[$i_idx]}
 echo "$0.$LINENO use_work_dir= $USE_WORK_DIR, i_LIST= $i"
 if [ $VERBOSE -gt 0 ]; then
   #pushd $i
   pushd $USE_WORK_DIR
 else
   #pushd $i > /dev/null
   pushd $USE_WORK_DIR > /dev/null
 fi
 if [ $VERBOSE -gt 0 ]; then
   echo "$0.$LINENO after sys_2_tsv.awk dir[$i_idx]= $i   TCUR_DIR= $TCUR_DIR"
 fi
# if [ "$PHASE_FILE" == "" ]; then
#    RESP=phase_cpu2017.txt
#    if [ $VERBOSE -gt 0 ]; then
#      echo "$0.$LINENO phase blank"
#    fi
#    if [ -e $RESP ]; then
#      echo "$0.$LINENO phase $RESP"
#      #OPT_PH=" -P $i/$RESP "
#      echo -e "-P\t\"$i/$RESP\"" >> $ALST
#      echo "$0.$LINENO phase $OPT_PH"
#    fi
# fi
# SM_FL=
# #if [ ! -e $SUM_FILE ]; then
#   SM_FL=$i/$SUM_FILE
# #fi
# if [ $VERBOSE -gt 0 ]; then
#   echo "$0 SM_FL= $SM_FL  SUM_FILE= $SUM_FILE"
# fi
 OPT_P=$RPS
 if [ $NUM_DIRS -gt 1 ]; then
   RESP=${RPS_ARR[$i_idx]}
 else
   RESP=${RPS_ARR[$JOB_ID]}
 fi
 printf "RPS_ARR= %s i_idx= %s DIR_NUM= %s\n" $RESP $i_idx $DIR_NUM > /dev/stderr
 if [ "$RESP" != "" ]; then
   OPT_P=$RESP
 fi
 echo -e "-p\t\"$OPT_P\"" >> $ALST
 echo -e "-s\t$CHART_SIZE" >> $ALST
 if [ "$AVERAGE" == "1" ]; then
    echo -e "-A" >> $ALST
 fi
# if [ "$CLIP" != "" ]; then
#    echo -e "-c\t$CLIP" >> $ALST
# fi
 if [ "${LZC_ARR_BY_DIR[$i]}" != "" ]; then
     GOT_SKU=`echo "${LZC_ARR_BY_DIR[$i]}" | grep '^sku;' | sed 's/^sku;//'|head -1`
     echo -e "--sku\t$GOT_SKU" >> $ALST
     if [ $VERBOSE -gt 0 ]; then
       echo "$0.$LINENO ____________ got sku= $GOT_SKU"
     fi
 fi
 if [ "$DESC_FILE" != "" ]; then
   echo -e "-d\t\"$DESC_FILE\"" >> $ALST
   echo "$0.$LINENO set -d1 desc_file= $DESC_FILE"
 fi
 if [ "${PHS_ARR[$i_idx,'name']}" != "" ]; then
   RESP=${PHS_ARR[$i_idx,'name']}
   echo -e "--phase\t\"$RESP\"" >> $ALST
   echo "$0.$LINENO set --phase $RESP"
   if [ "${PHS_ARR[$i_idx,'extra']}" != "" ]; then
     RESP="${RESP},${PHS_ARR[$i_idx,'extra']}"
     awk -v line="${PHS_ARR[$i_idx,'line']}" -v sum_file="$SUM_FILE" '
       BEGIN{
         n = split(line, arr, " ");
         printf("phase\tphase\t%s\tphase nm\n", arr[1]) >> sum_file;
         printf("phase\tphase\t%s\tphase nm\n", arr[1]) >  "/dev/stderr";
         for (i=4; i <= n; i++) {
           n2 = split(arr[i], brr, "=");
           printf("phase\tphase\t%s\tphase %s\n", brr[2], brr[1]) >> sum_file;
           printf("phase\tphase\t%s\tphase %s\n", brr[2], brr[1]) > "/dev/stderr";
         }
         exit(0);
       }
       '
       ck_last_rc $? $LINENO
       echo "$0.$LINENO did phs_arr[$i_idx] to $SUM_FILE"
     echo "$0.$LINENO OPT_DESC_FILE_ARR[$i_idx] = ${OPT_DESC_FILE_ARR[$i_idx]}"
     if [ "${OPT_DESC_FILE_ARR[$i_idx]}" != "" ]; then
       RESP="$(cat "${OPT_DESC_FILE_ARR[$i_idx]}")"
       echo "$0.$LINENO OPT_DESC_FILE_ARR[$i_idx] = $RESP"
       echo -e "desc_e\tdesc_e\t${RESP}\tdesc_e"  >> "$SUM_FILE"
     fi
   fi
 fi
 if [ "$DESC_FILE" == "" ]; then
   if [ -e desc.txt ]; then
      FLS=$(get_abs_filename "desc.txt")
      OPT_DESC_FILE="$FLS"
      echo "$0.$LINENO set -d4 desc_file= $OPT_DESC_FILE"
   fi
 fi
 if [ "$AVERAGE" == "0" ]; then
   if [ "${OPT_DESC_FILE_ARR[$i_idx]}" != "" ]; then
     OPT_DESC_FILE=${OPT_DESC_FILE_ARR[$i_idx]}
      echo "$0.$LINENO set -d3 desc_file= $OPT_DESC_FILE"
   fi
 fi
 if [ "$OPT_DESC_FILE" != "" ]; then
      echo -e "-d\t\"$OPT_DESC_FILE\"" >> $ALST
      echo "$0.$LINENO set -d2 desc_file= $OPT_DESC_FILE"
 fi
 echo -e "-i\t\"$i/*.png\"" >> $ALST
 #echo -e "-x\t$i.xlsx" >> $ALST
 #echo -e "-o\tchart_new,dont_sum_sockets" >> $ALST
 # itp files
 # yab_cmd files might be in same dir or up 1 level
# if [ -e yab_cmds.json.tsv ]; then
#   FLS=$(get_abs_filename yab_cmds.json.tsv)
#   echo -e "${FLS}" >> $ALST
# else
# if [ -e ../yab_cmds.json.tsv ]; then
#   FLS=$(get_abs_filename ../yab_cmds.json.tsv)
#   echo -e "${FLS}" >> $ALST
# fi
# fi
# if [ -e metric_out.tsv ]; then
#   FLS=$(get_abs_filename metric_out.tsv)
#   echo -e "${FLS}" >> $ALST
# fi
# if [ -e metric_out.csv.tsv ]; then
#   FLS=$(get_abs_filename metric_out.csv.tsv)
#   echo -e "${FLS}" >> $ALST
# fi
 if [ $VERBOSE -gt 0 ]; then
   popd
 else
   popd > /dev/null
 fi
 MYSVG=($i/*.svg)
 if [ "${#MYSVG}" != "0" ]; then
   SVG=`ls -1 $i/*.svg`
 fi
 if [ "$SVG" != "" ]; then
   SVGS="${SVGS} -f ${SVG}"
 fi
 #FLS=`ls -1 $SM_FL $i/*txt.tsv | grep -v infra_cputime`
 CKNM=$i/muttley_host_calls.tsv
 if [ -e $CKNM ]; then
   MUTT_ARR+=($CKNM)
 fi
 try_phs="phase_cpu2017.txt"
 if [ "$PHASE_FILE" != "" ]; then
   try_phs=$PHASE_FILE
 fi
 SHEET_FILES=()
 #for ((k=0; k < ${#SHEETS_OUT[@]}; k++)); do
 for ((k=i_idx; k < i_idx+1; k++)); do
   #CKDIR=$i
   #RESP=`grep "$CKDIR" ${SHEETS_OUT[$k]}`
   RESP=${SHEETS_OUT[$k]}
   if [ $VERBOSE -gt 0 ]; then
     echo "$0.$LINENO ckdir[$k] dir= $i resp= $RESP" > /dev/stderr
   fi
   if [ "$RESP" != "" ]; then
     if [ $VERBOSE -gt 0 ]; then
       echo "got SHEETS_OUT[$k]= $RESP, i= $i"
     fi
     #SDIR=`echo -e "$RESP" | awk '{ printf("%s\n", $1); }'`
     SDIR=`dirname ${SHEETS_OUT[$k]}`
     #SHEET_FILES+=(`echo -e "$RESP" | awk '{ for (i=2; i <= NF; i++) { printf("%s\n", $(i)); } }'`)
     SHEET_FILES+=(`cat $RESP | awk '{ for (i=2; i <= NF; i++) { printf("%s\n", $(i)); } }'`)
     FLS=${SHEET_FILES[@]}
     missed_files=
     echo "sheet_files= ${#SHEET_FILES[@]}, SDIR= $SDIR, FLS= $FLS"
     for ((kk=0; kk < ${#SHEET_FILES[@]}; kk++)); do
       echo "sheet_files[$kk]= ${SHEET_FILES[$kk]}"
       flnm=${SHEET_FILES[$kk]}
       if [[ $flnm == *"infra_cputime"* ]]; then
         FLS_IC=$SDIR/$flnm
         echo "$0.$LINENO got infra_cputime file $flnm $FLS_IC"
       fi
       if [[ $flnm == *"perf_stat"* ]]; then
         FLS_PS=$SDIR/$flnm
         echo "$0.$LINENO perf_stat file= $FLS_PS" > /dev/stderr
       fi
       if [[ $flnm == *"mpstat"* ]]; then
         FLS_MP=$SDIR/$flnm
       fi
       if [[ $flnm == *"$try_phs"* ]]; then
         #echo -e "-P\t\"$i/$SDIR/$flnm\"" >> $ALST
         #echo -e "-P\t\"$SDIR/$flnm\"" >> $ALST
         echo -e "$SDIR/$flnm" >> $ALST
         echo "$0.$LINENO phase try_phs= $try_phs flnm= $flnm"
         continue
       fi
       if [[ $flnm == *"$SUM_FILE"* ]]; then
         SM_FL=$flnm
         if [ $VERBOSE -gt 0 ]; then
           echo "$0 SM_FL= $SM_FL  SUM_FILE= $SUM_FILE"
         fi
         echo -e "$SDIR/${flnm}" >> $ALST
         continue
       fi
       if [[ $flnm == *"yab_cmds.json.tsv"* ]]; then
         echo -e "$SDIR/${flnm}" >> $ALST
         continue
       fi
       if [[ $flnm == *"metric_out.tsv"* ]]; then
         echo -e "$SDIR/${flnm}" >> $ALST
         continue
       fi
       if [[ $flnm == *"metric_out.csv.tsv"* ]]; then
         echo -e "$SDIR/${flnm}" >> $ALST
         continue
       fi
       if [[ $flnm == *"log.tsv"* ]]; then
         echo -e "$SDIR/${flnm}" >> $ALST
         continue
       fi
       if [[ $flnm == *"txt.tsv"* ]]; then
         echo -e "$SDIR/${flnm}" >> $ALST
         continue
       fi
       if [[ $flnm == *"current.tsv"* ]]; then
         echo -e "$SDIR/${flnm}" >> $ALST
         continue
       fi
       if [[ $flnm == *"log.tsv"* ]]; then
         echo -e "$SDIR/${flnm}" >> $ALST
         continue
       fi
       if [[ $flnm == *"json.tsv"* ]]; then
         echo -e "$SDIR/${flnm}" >> $ALST
         continue
       fi
       missed_files="$missed_files $flnm"
     done
     if [ "$missed_files" != "" ]; then
       echo "$0.$LINENO: !!!!!!!!!!!!!!! SHEETS missed_files= $missed_files" > /dev/stderr
     fi
     break
   fi
 done
# exit 1
# if [ "1" == "2" ]; then
#   FLS=`ls -1 $SM_FL $i/*txt.tsv`
#   FLS_IC=`ls -1  $i/*txt.tsv | grep infra_cputime`
#   FLS_PS=`ls -1  $i/*txt.tsv | grep perf_stat`
#   FLS_MP=`ls -1  $i/*txt.tsv | grep mpstat`
#   echo "$0.$LINENO ++++++++FLS_PS= $FLS_PS" > /dev/stderr
#   if [ "$FLS_PS" == "" ]; then
#     FLS_PS=`ls -1  $i/../*txt.tsv | grep perf_stat`
#     echo "$0.$LINENO ++++++++FLS_PS= $FLS_PS"  > /dev/stderr
#     if [ "$FLS_PS" != "" ]; then
#       echo "$0.$LINENO ++++++++FLS= $FLS" > /dev/stderr
#       FLS=`ls -1 $SM_FL $i/*txt.tsv $i/../*txt.tsv`
#       echo "$0.$LINENO ++++++++FLS= $FLS" > /dev/stderr
#     fi
#   fi
#   echo -e "${FLS}" >> $ALST
#   MYA=($i/*log.tsv)
#   if [ "${#MYA}" != "0" ]; then
#     FLS=`ls -1 $i/*log.tsv`
#     echo -e "${FLS}" >> $ALST
#   fi
#   MYA=($i/*current.tsv)
#   if [ "${#MYA}" != "0" ]; then
#     FLS=`ls -1 $i/*current.tsv`
#     echo -e "${FLS}" >> $ALST
#   fi
#   MYA=($i/muttley*.json.tsv)
#   if [ "${#MYA}" != "0" ]; then
#     FLS=`ls -1 $i/muttley*.json.tsv`
#     echo -e "${FLS}" >> $ALST
#   fi
# fi
# MYA=($i/sum_all.tsv)
# if [ "${#MYA}" != "0" ]; then
#   FLS=`ls -1 $i/sum_all.tsv`
#   echo -e "${FLS}" >> $ALST
# fi
 echo -e "" >> $ALST
 if [ "$FCTRS" != "" ]; then
   FCTRS="$FCTRS,"
 fi
 FCTRS="$FCTRS$FCTR"
done
fi

SUM_ALL=$WORK_DIR/$JOB_ID/sum_all_${JOB_ID}.tsv
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
  
  echo "$0.$LINENO got here"
  if [ -e $SUM_ALL ]; then
    rm $SUM_ALL
  fi
  #printf "title\tsum_all\tsheet\tsum_all\ttype\tcopy\n"  >> $SUM_ALL
  #printf "hdrs\t2\t0\t-1\t%d\t-1\n"  500 >> $SUM_ALL
  #printf "Resource\tTool\tMetric\taverage\n" >> $SUM_ALL;
  echo "$0.$LINENO FLS_IC= $FLS_IC FLS_PS= $FLS_PS FLS_MP= $FLS_MP"
if [ "$FLS_IC" != "" -o "$FLS_PS" != "" -o "$FLS_MP" != "" ]; then
  OPT_METRIC=" -m sum "
  OPT_METRIC=" -m sum_per_server "
  OPT_METRIC=" -m avg "
#abc
  if [ "$AVERAGE" == "1" ]; then
    echo "$0.$LINENO got here"
    if [ "$FLS_IC" != "" ]; then
     OFILE=$WORK_DIR/$JOB_ID/infra_cputime_sum_${JOB_ID}.tsv
     if [ -e $OFILE ]; then
       rm $OFILE
     fi
     #if [ $VERBOSE -gt 0 ]; then
      echo "$SCR_DIR/redo_chart_table.sh -O "$OPTIONS" -S $SUM_ALL -f $ALST -o $OFILE   -g infra_cputime $OPT_METRIC -r 50 -t __all__"
     #fi
            $SCR_DIR/redo_chart_table.sh -O "$OPTIONS" -S $SUM_ALL -f $ALST -o $OFILE   -g infra_cputime $OPT_METRIC -r 50 -t __all__ 
     ck_last_rc $? $LINENO
    fi
    if [ "$FLS_MP" != "" ]; then
     OFILE=$WORK_DIR/$JOB_ID/sys_mpstat_sum_${JOB_ID}.tsv
     if [ -e $OFILE ]; then
       rm $OFILE
     fi
      #if [ $VERBOSE -gt 0 ]; then
      echo "$SCR_DIR/redo_chart_table.sh -O "$OPTIONS" -S $SUM_ALL -f $ALST -o $OFILE   -g mpstat $OPT_METRIC -r 50 -t __all__"
      #fi
            $SCR_DIR/redo_chart_table.sh -O "$OPTIONS" -S $SUM_ALL -f $ALST -o $OFILE   -g mpstat $OPT_METRIC -r 50 -t __all__ 
      ck_last_rc $? $LINENO
    fi
  echo "$0.$LINENO got here"
  if [ "$FLS_PS" != "" ]; then
  echo "$0.$LINENO got here"
    OFILE=$WORK_DIR/$JOB_ID/sys_perf_stat_sum_${JOB_ID}.tsv
    if [ -e $OFILE ]; then
      rm $OFILE
    fi
    if [ $VERBOSE -gt 0 ]; then
      echo "$SCR_DIR/redo_chart_table.sh -O "$OPTIONS" -S $SUM_ALL -f $ALST -o $OFILE   -g perf_stat $OPT_METRIC -r 50 -t __all__"
    fi
    echo "$0.$LINENO $SCR_DIR/redo_chart_table.sh -O "$OPTIONS" -S $SUM_ALL -f $ALST -o $OFILE   -g perf_stat $OPT_METRIC -r 50 -t __all__" > /dev/stderr
          $SCR_DIR/redo_chart_table.sh -O "$OPTIONS" -S $SUM_ALL -f $ALST -o $OFILE   -g perf_stat $OPT_METRIC -r 50 -t __all__ 
    ck_last_rc $? $LINENO
  fi
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
    echo $SCR_DIR/compare_summary_table.sh $FLS -w $WORK_DIR -s $SUM_ALL -S "\t"
         $SCR_DIR/compare_summary_table.sh $FLS -w $WORK_DIR -s $SUM_ALL -S "\t"
    ck_last_rc $? $LINENO
    MK_SUM_ALL=0
  else
    MK_SUM_ALL=1
  fi

  if [ $VERBOSE -gt 0 ]; then
  echo "$0: awk -v mk_sum_all="$MK_SUM_ALL" -v input_file=\"$ALST\" -v sum_all=\"$SUM_ALL\" -v sum_file=\"$SUM_FILE\" -v curdir=\"$got_pwd\" "
  fi
  awk -v work_dir="$WORK_DIR" -v average_in="$AVERAGE" -v options="$OPTIONS" -v script="$0.$LINENO.awk" -v job_id="$JOB_ID" -v verbose="$VERBOSE" -v mk_sum_all="$MK_SUM_ALL" -v input_file="$ALST" -v sum_all="$SUM_ALL" -v sum_file="$SUM_FILE" -v sum_all_avg_by_metric="$SUM_ALL_AVG_BY_METRIC" -v curdir="$got_pwd" '
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
function do_pxx_compare(fls, str1, str2, v,    str, pxx_i, my_n)
{
    str = str1";"str2;
    if (!(str in pxx_list)) {
      pxx_list[str] = ++pxx_max;
      pxx_lkup[pxx_max] = str;
      pxx_hdr[pxx_max,"grp"] = str1;
      pxx_hdr[pxx_max,"mtrc"] = str2
      pxx_n[pxx_max] = 0;
    }
    pxx_i = pxx_list[str];
    pxx_n[pxx_i]++;
    my_n = pxx_n[pxx_i];
    if (v != "") {
       pxx_arr[pxx_i,my_n] += v+0.0;
    } else {
      # if we are doing  val_arr lines then dont add empty values to array
      if (index(str, " val_arr") == 0) {
       pxx_arr[pxx_i,my_n] = v;
      }
    }
    return pxx_n[pxx_i];
}
function pre_do_pxx_compare(mtrcm1, mtrc, fld_v, arr, fls, fld_beg, n, allow_zero0_nonzero1,    ii) {
  if (allow_zero0_nonzero1 == 0 || (arr[fld_v] != "" && arr[fld_v] != 0)) {
    if (index(mtrc, " val_arr") > 0) {
      for(ii=fld_beg; ii <= n; ii++) {
        do_pxx_compare(fls, mtrcm1, mtrc, arr[ii]);
      }
    } else {
      do_pxx_compare(fls, mtrcm1, mtrc, arr[fld_v]);
    }
  }
}
    { if (index($0, sum_file) > 0 || index($0, sum_all) > 0) {
        flnm = $0;
        fls++;
        flnm_arr[fls] = flnm;
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
                fld_beg = 0;
                if (hdrs[3] == "Value" && hdrs[4] == "Metric") {
                   fld_m=4; 
                   fld_v=3; 
                   fld_beg = 5;
                   fld_mm1=2; 
                   if (verbose > 0) {
                     printf("sum_all2 metric fld= %d nf= %d\n", 3, nh) > "/dev/stderr";
                   }
                }
                if (hdrs[3] == "Metric") {
                   fld_m=3; 
                   fld_v=4; 
                   fld_mm1=2; 
                   fld_beg = 5;
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
              pre_do_pxx_compare(mtrcm1, mtrc, fld_v, arr, fls, fld_beg, n, 0);
           }
           #if (mtrcm1 == "muttley calls avg") {
           #   # the average muttley calls have so many small RPS. creates huge list especially if we match up columns
           #   # so just drop the small values
           #   continue;
           #}
           if (mtrcm1 == "net stats" && (index(mtrc, "MB/s read ") == 1 || index(mtrc, "MB/s write ") == 1)) {
              pre_do_pxx_compare(mtrcm1, mtrc, fld_v, arr, fls, fld_beg, n, 1);
           }
           if (mtrcm1 == "IO stats" && index(mtrc, "util% ") == 1) {
              pre_do_pxx_compare(mtrcm1, mtrc, fld_v, arr, fls, fld_beg, n, 1);
           }
           if (mtrcm1 == "IO stats" && (index(mtrc, "rd_MB/s ") == 1 || index(mtrc, "wr_MB/s ") == 1)) {
              pre_do_pxx_compare(mtrcm1, mtrc, fld_v, arr, fls, fld_beg, n, 1);
           }
           if (mtrcm1 == "perf_stat" && index(mtrc, " val_arr") > 0) {
              pre_do_pxx_compare(mtrcm1, mtrc, fld_v, arr, fls, fld_beg, n, 1);
           }
           if (mtrcm1 == "cgrps_val_arr" && index(mtrc, " val_arr") > 0) {
              pre_do_pxx_compare(mtrcm1, mtrc, fld_v, arr, fls, fld_beg, n, 1);
           }
#          if (mtrcm1 == "perf_stat" && index(mtrc, "%not_halted") == 1) {
#             pre_do_pxx_compare(mtrcm1, mtrc, fld_v, arr, fls, fld_beg, n, 1);
#          }
#          if (mtrcm1 == "perf_stat" && index(mtrc, "Mem BW GB/s") == 1) {
#             pre_do_pxx_compare(mtrcm1, mtrc, fld_v, arr, fls, fld_beg, n, 1);
#          }
           if (mtrcm1 == "perf_stat" && index(mtrc, "%used_bw_of_max_theoretical_mem_bw") == 1) {
              pre_do_pxx_compare(mtrcm1, mtrc, fld_v, arr, fls, fld_beg, n, 1);
           }
           if (mtrcm1 == "muttley host.calls max" && (mtrc == "RPS host.calls max")) {
              pre_do_pxx_compare(mtrcm1, mtrc, fld_v, arr, fls, fld_beg, n, 0);
           }
           if (mtrcm1 == "muttley calls avg" && (mtrc == "RPS host.calls")) {
              pre_do_pxx_compare(mtrcm1, mtrc, fld_v, arr, fls, fld_beg, n, 0);
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

function arr_in_compare_rev(i1, v1, i2, v2,    l, r)
{
    m1 = arr_in[i1];
    m2 = arr_in[i2];
    if (m2 < m1)
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
      rw = 2;
      printf("title\tsum_all\tsheet\tsum_all\ttype\tcopy\t\t=1\tfor Col.A, if 1=col_of_max,2=max,3=sum,4=countNotBlank\n")  >> ofile;
      ++rw;
      printf("hdrs\t2\t0\t-1\t%d\t-1\n", fls+3) >> ofile;
      printf("Resource\tTool\tMetric") >> ofile;
      cur_col = 2; # 1st col is 0 for me. After above printf we are in col 2
      #if (got_avgby == 0 && fls > 1) {
      if (got_avgby == 0) {
        if (get_max_val == 1) {
          printf("\tavg_or_max_of_peak") >> ofile;
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
      ++rw;
      printf("\n") >> ofile;
      ltr_beg = get_excel_col_letter_from_number(fl_col_beg);
      ltr_end = get_excel_col_letter_from_number(fl_col_end);
      printf("______ col_beg= %d, col_end= %d, ltr_beg= %s ltr_end= %s\n", fl_col_beg, fl_col_end, ltr_beg, ltr_end) > "/dev/stderr";
      first_metric = 1;
      amtrc__mx = 0;
      for (i=1; i <= mtrc_mx; i++) {
        mtrc   = mtrc_lkup[i,2];
        if (!(mtrc in amtrc_list)) {
          amtrc_list[mtrc] = ++amtrc_mx;
          amtrc_lkup[amtrc_mx] = mtrc;
        }
      }
      lst_grp=0;
      lst[++lst_grp,1]= "cgrps cpu ";
      lst[++lst_grp,1]= "cgrps %cpu ";
      lst[++lst_grp,1]= "cntr_nomap_to_muttley_pct_of_tot_cntr_cpusecs";
      lst[++lst_grp,1]= "elapsed time secs";
      lst[++lst_grp,1]= "total_busy_cpusecs";
      lst[++lst_grp,1]= "total_%cpu_utilization";
      lst[++lst_grp,1]= "tot_map_cntr_cpusecs";
      lst[++lst_grp,1]= "tot_notmap_cntr_cpusecs";
      lst[++lst_grp,1]= "tot_cntr_cpusecs";
      lst[++lst_grp,1]= "cntr_cpu_ms_per_call";
      lst[++lst_grp,1]= "cntr_pct_of_tot_cntr_secs";
      lst[++lst_grp,1]= "cntr_secs";
      lst[++lst_grp,1]= "cntr_calls";
      lst[++lst_grp,1]= "infra procs %cpu";
      lst[++lst_grp,1]= "cgrp_per_hst";
      lst[++lst_grp,1]= "RPS_per_hst";
      lst[++lst_grp,1]= "cpu_util_per_hst";
      
      str_prv = "";
      for (k=1; k <= lst_grp; k++) {
      delete idx;
      delete res_i;
      delete arr_in;
       for (i=1; i <= mtrc_mx; i++) {
        mtrc   = mtrc_lkup[i,1];
        mtrcm1 = mtrc_lkup[i,2];
        if (index(mtrcm1, lst[k,1]) == 0) { continue; }
        nn = ++lst[k,"mx"];
        mtrc_sum[nn] = 0.0;
        sumn= 0;
        my_n = fls;
        for (j=1; j <= my_n; j++) {
          if (mtrc_arr[j,i] != "") {
          sumn += mtrc_arr[j,i];
          }
        }
        lst_2_i[k,nn] = i;
        idx[nn] = nn;
        arr_in[nn] = sumn;
       }
       asorti(idx, res_i, "arr_in_compare_rev");
       #printf("cg_ lst[%d,"mx"] = %d\n", k, lst[k,"mx"]);
       for(i=1; i <= lst[k,"mx"]; i++) {
         lst_srt[k,i] = res_i[i];
         #printf("k= %d srt[%d]= %d, arr= %f\n", k, i, res_i[i], arr_in[i]);
       }
      }

      for (mm=1; mm <= amtrc_mx; mm++) {
      for (ij=1; ij <= mtrc_mx; ij++) {
        mtrcm1 = mtrc_lkup[ij,2];
        if (mtrcm1 != amtrc_lkup[mm]) { continue; }
        kk = 0;
        if (mtrcm1 == lst[1,1]) { kk = 1; }
        else if (mtrcm1 == lst[2,1]) { kk = 2; }
        if (kk != 0) {
          iij = ++lst_ij[kk];
          iijj = lst_srt[kk,iij];
          i = lst_2_i[kk,iijj];
          #printf("cg kk= %d, ij= %d iij= %d, i= %d\n", kk, ij, iij, i);
        } else {
          i = ij;
        }
        mtrc   = mtrc_lkup[i,1];
        if (mtrc == "") { continue; }
        my_str = mtrcm1";"mtrc;
        pxx_i = pxx_list[my_str];
        my_n = pxx_n[pxx_i];
        if (my_n > fls) {
          ltr_e = get_excel_col_letter_from_number(my_n+4);
        } else {
          ltr_e = ltr_end;
          my_n = fls;
        }
        got_val_arr = 0;
        if(index(mtrc, " val_arr") > 0) {
          #printf("+++++++++++++++++++++++++ got_avgby= %s\"%s\"\t%s\t%s \t my_n= %d\n", got_avgby, eqn_for_col_of_max_val, mcat, mtrc, my_n) > "/dev/stderr";
          got_val_arr = 1;
        }
        if (got_val_arr == 1) {
          continue;
        }
        rng_str = sprintf("%s%d:%s%d", ltr_beg, rw, ltr_e, rw);
        do_avg0_or_max1 = 0;
        if (mtrc == "data_sheet") {
          printf("\t%s\t%s", mtrc_arr[1,i], mtrc) >> ofile;
        } else {
          mcat = "itp";
          if (mtrc_cat[i] != "") { mcat = mtrc_cat[i]; }
          smatch = sprintf("MATCH(MAX(%s),%s,0)-1", rng_str, rng_str);
          smax   = sprintf("MAX(%s)", rng_str);
          ssum   = sprintf("SUM(%s)", rng_str);
          counta = sprintf("COUNTA(%s)", rng_str);
          if_stmt = "=IF($H$1=1,"smatch",IF($H$1=2,"smax",IF($H$1=3,"ssum","counta")))";
          #eqn_for_col_of_max_val = sprintf("=MATCH(MAX(%s),%s,0)-1", rng_str, rng_str);
          eqn_for_col_of_max_val = if_stmt;
          if (first_metric == 1) {
            eqn_for_col_of_max_val = "fileno_of_max";
            first_metric = 0;
          }
          printf("\"%s\"\t%s\t%s", eqn_for_col_of_max_val, mcat, mtrc) >> ofile;
          if (get_max_val == 1 && index(mtrc, "peak") > 0) {
            do_avg0_or_max1 = 1;
          }
        }
        for (j=1; j <= my_n; j++) {
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
                for (k=1; k <= my_n; k++) {
                  if (got_val_arr == 1) {
                    val2   = pxx_arr[pxx_i,k];
                  } else {
                    val2   = mtrc_arr[k,i];
                  }
                  got_blank = 0;
                  if (val2 == "") { got_blank = 1;}
                  isnum2 = ck_num(val2);
                  if (isnum2 > 0) {
                    #if (get_max_val == 1)
                    if (do_avg0_or_max1 == 1) {
                      if (sum_n == 0) {
                        sum_v = val2;
                        sum_n = 1;
                      } else if (sum_v < val2) {
                          sum_v = val2;
                      }
                    } else {
                      if (got_blank == 0) {
                        sum_v += val2;
                        sum_n++;
                      }
                    }
                    if (got_val_arr == 1) {
                      printf("\t%s%f", equal, val2) >> ofile;
                    }
                  }
                }
                if (got_val_arr == 0) {
                if (sum_n > 0) {
                  printf("\t%s%f", equal, sum_v/sum_n) >> ofile;
                } else {
                  printf("\t%s%s", equal, 0) >> ofile;
                }
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
              if (j == 1 && got_val_arr == 0) {
                 printf("\t%s%s", "", "") >> ofile;
              }
            }
          }
          if (got_val_arr == 0) {
            if (val == "") {
              printf("\t") >> ofile;
            } else {
              printf("\t%s%s", equal, val) >> ofile;
            }
          }
           #if (index(mtrc, "Mem BW GB/s") > 0) {
           #  printf("str= %s, fls= %d, %s, %s\n", mtrc, fls, val, isnum) > "/dev/stderr";
           #}
        }
        ++rw;
        printf("\n") >> ofile;
      }
      }
      for (k=1; k <= pxx_max; k++) {
        delete res_i;
        delete idx;
        my_n = pxx_n[k];
        for(i=1; i <= my_n; i++) {
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
        px[++px_mx] = 99.5;
        px[++px_mx] = 100;
        str = "hosts " pxx_hdr[k,"mtrc"];
        if (index(str, " val_arr") == 0) {
          printf("\t%s\t%s\t", pxx_hdr[k,"grp"], str) >> ofile;
          for(i=1; i <= fls_mx; i++) {
            printf("\t%s", pxx_hst[res_i[i]]) >> ofile;
          }
          ++rw;
          printf("\n") >> ofile;
          str = "values " pxx_hdr[k,"mtrc"];
          my_n = pxx_n[k];
          my_str = sprintf("\t%s\t%s\t", pxx_hdr[k,"grp"], str);
          #printf("+++++++++++++ my_n= %d ++++++++++++++ my_str= %s ofile= %s\n", my_n, my_str, ofile) > "/dev/stderr";
          printf("%s", my_str) >> ofile;
          for(i=1; i <= my_n; i++) {
            printf("\t%f", arr_in[res_i[i]]) >> ofile;
          }
          ++rw;
          printf("\n") >> ofile;
        }
        if (index(str, " val_arr") > 0) {
          my_sum = 0.0;
          n = 0;
          for(i=1; i <= my_n; i++) {
            my_sum += arr_in[res_i[i]];
            n++;
          }
          if (n > 0) {
            my_sum /= n;
          } else {
            my_sum = 0.0;
          }
          str = pxx_hdr[k,"mtrc"] " all_vals";
          ++rw;
          mystr = sprintf("\t%s\t%s\t%f", pxx_hdr[k,"grp"], str, my_n);
          for(i=1; i <= my_n; i++) {
            mystr = mystr "" sprintf("\t%f", arr_in[res_i[i]]);
          }
          printf("%s\n", mystr) >> ofile;
          str = pxx_hdr[k,"mtrc"] " avg";
          ++rw;
          printf("\t%s\t%s\t%f\n", pxx_hdr[k,"grp"], str, my_sum) >> ofile;
        }
        for (kk=1; kk <= px_mx; kk++) {
          pi  = 0.01 * px[kk] * my_n; # index into array for this percentile
          pii = int(pi);       # integer part
          if (pii != pi) {
            # so pi is not an integer
            piu = pii+1;
            if (piu > my_n) { piu = my_n; }
            uval = arr_in[res_i[piu]]
            hval = pxx_hst[res_i[piu]];
          } else {
            piu = pii;
            if (piu >= my_n) {
              uval = arr_in[res_i[my_n]];
              hval = pxx_hst[res_i[my_n]];
            } else {
              piup1=piu + 1;
              uval = 0.5*(arr_in[res_i[piu]] + arr_in[res_i[piup1]]);
              hval = pxx_hst[res_i[piu]] " " pxx_hst[res_i[piup1]] " ";
            }
          }
          str = pxx_hdr[k,"mtrc"] " p" px[kk];
          ++rw;
          printf("\t%s\t%s\t%f\t%s\n", pxx_hdr[k,"grp"], str, uval, hval) >> ofile;
          #printf("\t%s\t%s\t%f\t%s\n", pxx_hdr[k,"grp"], str, uval, hval) > "/dev/stderr";
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
        first_mpstat_line = -1;
        first_perf_stat = -1;
        while ((getline line < flnm) > 0) {
          if (average_in == 1) {
           if (index(line, "mpstat") > 0) {
              ++first_mpstat_line;
              if (first_mpstat_line == 0) {
                line = work_dir "/" job_id "/" "sys_mpstat_sum_" job_id ".tsv";
              } else {
                continue;
              }
              # this line will be handled outside
           }
           if (index(line, "infra_cputime") > 0) {
              ++first_infra_cputime;
              if (first_infra_cputime == 0) {
                line = work_dir "/" job_id "/" "infra_cputime_sum_" job_id ".tsv";
              } else {
                continue;
              }
              # this line will be handled outside
           }
           if (index(line, "perf_stat") > 0) {
              ++first_perf_stat;
              if (first_perf_stat == 0) {
                line = work_dir "/" job_id "/" "sys_perf_stat_sum_" job_id ".tsv";
              } else {
                continue;
              }
              # this line will be handled outside
           }
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
  OFILE2=$WORK_DIR/${JOB_ID}/muttley_host_calls_combined_${JOB_ID}.tsv
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
  echo "$0.$LINENO got to here"

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
    if [ $VERBOSE -gt 0 ]; then
      echo "$0.$LINENO find $DIR_1ST_DIR -name 60secs.log" > /dev/stderr
    fi
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
  echo "$0.$LINENO got to here________________" > /dev/stderr
      echo -e "-p\t\"$RPS\"" >> $ALST
      echo -e "-s\t$CHART_SIZE" >> $ALST
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
                echo $SCR_DIR/resp_2_tsv.sh -w $WORK_DIR/${JOB_ID} -b $BEG_TM -e $END_TM -f $f -s $SUM_ALL $OPT_O $OPT_M > /dev/stderr
             fi
                echo $SCR_DIR/resp_2_tsv.sh -w $WORK_DIR/${JOB_ID} -b $BEG_TM -e $END_TM -f $f -s $SUM_ALL $OPT_O $OPT_M > /dev/stderr
                  $SCR_DIR/resp_2_tsv.sh -w $WORK_DIR/${JOB_ID} -b $BEG_TM -e $END_TM -f $f -s $SUM_ALL $OPT_O $OPT_M
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
  if [ "$AVERAGE" == "1" ]; then
  if [ "$BEG_TM_IN" != "" ]; then
     OPT_TM=" -b $BEG_TM_IN "
  fi
  echo "$0.$LINENO ____got OPT_TM=\"$OPT_TM\"" > /dev/stderr
  if [ "$END_TM" != "" ]; then
     echo "$0.$LINENO ____got END_TM=\"$END_TM\"" > /dev/stderr
     END_TM=`echo "$END_TM"|head -1`
     OPT_TM="$OPT_TM -e $END_TM "
  fi
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
  FSTDOUT="$WORK_DIR/tsv_2_xlsx_stdout_${JOB_ID}.txt"
 if [ -e job_${JOB_ID}.stop ]; then
    RESP=`head -1 job_${JOB_ID}.stop`
    echo "$0: got job_$JOB_ID.stop pid= $RESP and bashpid= $$" > /dev/stderr
    if [ "$RESP" == "$$" ]; then
      echo "$0: quitting at line $LINENO due to job_$JOB_ID.stop having value PID= $$"
      exit 1
    fi
 fi
 WPYTHON=$(which python)
 if [[ "$WPYTHON" != *"python"* ]]; then
   WPYTHON=$(which python3)
 fi
       TS_CUR=`date +%s`
       TS_DFF=$(($TS_CUR-$TS_BEG))
       echo "$0.$LINENO: before $WPYTHON tsv_2_xlsx.py, elap_secs= $TS_DFF"
  #if [ $VERBOSE -gt 0 ]; then
    echo "$0.$LINENO $WPYTHON $SCR_DIR/tsv_2_xlsx.py $OPT_SM $OPT_a $OPT_A $OPT_TM -O "$OPTIONS" $OPT_M -f $ALST $SHEETS" > /dev/stderr
    #cat $ALST
  #fi
        $WPYTHON $SCR_DIR/tsv_2_xlsx.py -v $OPT_SM $OPT_a $OPT_A $OPT_TM -O "$OPTIONS" $OPT_M -f $ALST $SHEETS &> $FSTDOUT
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
