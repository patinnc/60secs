#!/bin/bash

# ./sys_2_tsv.sh -d some_dir_with_files_created_by_60secs_sh
# 60secs.sh creates the sys_*.txt files which are read by sys_2_tsv.sh and.
# sys_2_tsv.sh then creates sys_*.txt.tsv files.
# '-d dir' is expected to have file sys_00_uptime.txt sys_01_dmesg.txt sys_02_vmstat.txt sys_03_mpstat.txt sys_04_pidstat.txt sys_05_iostat.txt sys_06_free.txt sys_07_sar_dev.txt sys_08_sar_tcp.txt sys_09_top.txt sys_10_perf_stat.txt
# and output files in the are sys_00_uptime.txt.tsv sys_01_dmesg.txt.tsv sys_02_vmstat.txt.tsv sys_03_mpstat.txt.tsv sys_04_pidstat.txt.tsv sys_05_iostat.txt.tsv sys_06_free.txt.tsv sys_07_sar_dev.txt.tsv sys_08_sar_tcp.txt.tsv sys_09_top.txt.tsv sys_10_perf_stat.txt.tsv
#
# excel formula to convert UTC epoch to localtme =(B5/86400)+DATE(1970,1,1)
#
export LC_ALL=C
DIR=
SHEETS=
SCR_DIR=`dirname $0`
IMAGE_STR=
XLSX_FILE="chart_line.xlsx"
PFX=
SUM_FILE=
PHASE_FILE=
END_TM=
END_TM_IN=
BEG_TM_IN=
METRIC_OUT="metric_out"
METRIC_AVG="metric_out.average"
SUM_TMAM_FILE="sum_TMAM.tsv"
MUTTLEY_OUT_FILE="muttley_host_calls.tsv"
SKIP_XLS=0
MAX_VAL=
AVERAGE=0
CLIP=
AVG_DIR=
G_SUM=()
JOB_ID=0
#echo "$0: cmdline= ${@}"

ck_last_rc() {
   local RC=$1
   local FROM=$2
   if [ $RC -gt 0 ]; then
      echo "$0: got non-zero RC=$RC at $LINENO. called from line $FROM" > /dev/stderr
      exit $RC
   fi
}

while getopts "hvASa:B:b:c:D:d:e:g:i:j:m:o:P:p:s:t:x:" opt; do
  case ${opt} in
    A )
      AVERAGE=1
      ;;
    a )
      AVG_DIR=$OPTARG
      ;;
    B )
      BASE_DIR=$OPTARG
      ;;
    b )
      BEG_TM_IN=$OPTARG
      echo "$0.$LINENO: top BEG_TM_IN= $BEG_TM_IN"
      ;;
    c )
      CLIP=$OPTARG
      ;;
    d )
      DIR=$OPTARG
      ;;
    D )
      DEBUG_OPT=$OPTARG
      ;;
    e )
      END_TM=$OPTARG
      END_TM_IN=$OPTARG
      echo "$0.$LINENO: top END_TM_IN= $END_TM_IN"
      ;;
    g )
      G_SUM+=("$OPTARG")
      ;;
    i )
      IMAGE_STR=$OPTARG
      ;;
    j )
      JOB_ID=$OPTARG
      ;;
    m )
      MAX_VAL=$OPTARG
      ;;
    o )
      OPTIONS=$OPTARG
      ;;
    p )
      PFX=$OPTARG
      ;;
    P )
      PHASE_FILE=$OPTARG
      ;;
    s )
      SUM_FILE=$OPTARG
      ;;
    S )
      SKIP_XLS=1
      ;;
    t )
      TOP_DIR=$OPTARG
      ;;
    x )
      XLSX_FILE=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 split data files into columns"
      echo "Usage: $0 [-h] -d sys_data_dir [-v] [ -p prefix ]"
      echo "   -a avg_dir average files (-A ) will be put in this dir"
      echo "   -B base_dir top level dir"
      echo "   -d dir containing sys_XX_* files created by 60secs.sh"
      echo "   -b beg_tm ending timestamp to clip time to"
      echo "   -c clip_to_Phase  enter string of phase for clipping (like x264_r*)"
      echo "   -e end_tm ending timestamp to clip time to"
      echo "   -g key=val pairs to be added to summary sheet"
      echo "   -i \"image_file_name_str\" this option is passed to tsv_2_xlsx.py to identify image files to be inserted into the xlsx"
      echo "      For instance '-i \"*.png\"'. Note the dbl quotes around the glob. This keeps the cmdline from expanding the files. python will expand the glob."
      echo "   -o perf_stat_scatter_options   options for perf_stat_scatter.sh script"
      echo "      '-o dont_sum_sockets' option to not sum the perf stat per socket events to the system"
      echo "      '-o chart_new' option to start the perf_stat chart at the first new computed event column"
      echo "         The default is to start the chart at the 1st event so you get a y axis between 0 and 1e10 or so."
      echo "         If you do just the new computed events then the scale is usually 0-100 or so."
      echo "      '-o line_for_scatter' option uses 'line' chart type instead of scatter_straight"
      echo "         Excel scatter works fine and handles perhaps non-uniform x axis data"
      echo "         But google sheets translates scatter plot into just dots plots."
      echo "         And I think just the regular line chart is better in sheets than the dot plots"
      echo "      You can pass both options with '-o dont_sum_sockets,chart_new'"
      echo "      These optional options are passed to perf_stat_scatter.sh"
      echo "      default is to sum the per socket events to the system level and chart all the events"
      echo "   -x xlsx_filename  This is passed to tsv_2_xlsx.py as the name of the xlsx. (you need to add the .xlsx)"
      echo "      The default is chart_line.xlsx"
      echo "   -m max_val  any value in charts > max_val will be replaced with 0.0"
      echo "   -p prefix   string to be prefixed to each sheet name"
      echo "   -P phase_file list of phases for data. fmt is 'phasename beg_time end_time'"
      echo "   -s sum_file summary_file"
      echo "   -S   skip creating detail xlsx file. Useful for when we are doing multiple directories"
      echo "   -t top_dir  top directory"
      echo "   -v verbose mode"
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

#echo "$0: top BEG_TM_IN= $BEG_TM_IN" > /dev/stderr

for ((ck_for_null=0; ck_for_null <= 1; ck_for_null++)); do

if [ "$DIR" == "" ]; then
  echo "you must enter a dir '-d dir_path' containing sys_*_*.txt files created by 60secs.sh"
  exit 1
fi
if [ ! -d $DIR ]; then
  echo "didn't find dir $DIR"
  exit 1
fi
echo "dir= $DIR"

OPT_a=
if [ "$AVG_DIR" != "" ]; then
   if [ ! -e $AVG_DIR ]; then
     mkdir -p $AVG_DIR
   fi
   OPT_a=" -a $AVG_DIR "
fi
echo "$0: SUM_FILE= $SUM_FILE" > /dev/stderr
if [ "$SUM_FILE" != "" ]; then
  printf "title\tsummary\tsheet\tsummary\ttype\tcopy\n"  > $SUM_FILE;
  printf "hdrs\t2\t0\t-1\t3\t-1\n" >> $SUM_FILE;
  #printf "Resource\tTool\tMetric\tValue\tUSE\tComments\n" >> $SUM_FILE;
  printf "Resource\tTool\tValue\tMetric\tUSE\tComments\n" >> $SUM_FILE;
fi

for g in ${G_SUM[@]}; do
  arr_g=(${g//=/ })
  printf "\t\t%s\t%s\n"  ${arr_g[1]}  ${arr_g[0]} >> $SUM_FILE
done

PH_TM_END=0
if [ "$PHASE_FILE" != "" ]; then
  PH_TM_END=`awk '{if ($3 != "") {last= $3;}} END{printf("%s\n", last);}' $PHASE_FILE`
  echo "PH_TM_END= $PH_TM_END" > /dev/stderr
fi

TDIR=$DIR
if [ "$TDIR" == "." ]; then
  TDIR=${PWD##*/}  
fi
RPS=`echo $TDIR | sed 's/rps_v/rpsv/' | sed 's/rps.*_.*/rps/' | sed 's/.*_//'`
RPS="${RPS}"
FCTR=`echo $RPS | sed 's/rps//'`
printf "DIR= $DIR, RPS= %s\n", $RPS > "/dev/stderr"

get_hostname_from_path() {
  if [ "$1" != "" ]; then
    USEDIR=$1
  else
   USEDIR=`pwd`
  fi
  HOSTNM=`awk -v script="$0" -v lineno="$LINENO" -v usedir="$USEDIR" '
  BEGIN{
    n = split(usedir, arr, "/");
    for (i=n; i > 2; i--) {
       if (arr[i] == arr[i-2] && index(arr[i-1], "-") > 0) {
          printf("%s\n", arr[i-1]);
          exit;
       }
    }
    printf("%s.%s: missed_hostnm in %s\n", script, lineno, usedir) > "/dev/stderr";
    exit 1;
  }'`
   ck_last_rc $? $LINENO
}

CK_HST_NM=`find . -name hostname.txt`
if [ "$CK_HST_NM" == "" ]; then
  get_hostname_from_path
else
  HOSTNM=`cat $CK_HST_NM|head -1`
fi

printf "host\thostname\t%s\thostname\n"  "$HOSTNM" >> $SUM_FILE

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
  CKFL=$BASE_DIR/grail_cpu_info.txt
  echo "_____ck  grail file $CKFL" > /dev/stderr
  if [ -e $CKFL ]; then
    echo "_____got grail hst= $UHOSTNM file $CKFL" > /dev/stderr
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

get_grail_info_for_hostname $HOSTNM $SUM_FILE

LSCPU_FL=lscpu.txt
if [ ! -e $LSCPU_FL ]; then
  if [ -e ../$LSCPU_FL ]; then
    LSCPU_FL=../lscpu.txt
  else
    LSCPU_FL=
  fi
fi
if [ "$LSCPU_FL" != "" ]; then
     NCPUS=`awk '/^CPU.s.:/ { printf("%s\n", $2);exit;}' $LSCPU_FL`
     printf "host\tcpus\t%s\tnum_cpus\n"  "$NCPUS" >> $SUM_FILE;
     NSKTS=`awk '/^Socket.s.:/ { printf("%s\n", $2);exit;}' $LSCPU_FL`
     printf "host\tsockets\t%s\tnum_sockets\n"  "$NSKTS" >> $SUM_FILE;
     NUMAS=`awk '/^NUMA node.s.:/ { printf("%s\n", $3);exit;}' $LSCPU_FL`
     printf "host\tnuma_nodes\t%s\tnuma_nodes\n"  "$NUMAS" >> $SUM_FILE;
     DECD=`$SCR_DIR/decode_cpu_fam_mod.sh $LSCPU_FL`
     if [ "$DECD" != "" ]; then
       printf "host\tcpu_type\t%s\tcpu_type\n"  "$DECD" >> $SUM_FILE;
     fi
fi
DMIDECODE_FL=dmidecode.txt
if [ ! -e $DMIDECODE_FL ]; then
  if [ -e ../$DMIDECODE_FL ]; then
    DMIDECODE_FL=../dmidecode.txt
  else
    DMIDECODE_FL=
  fi
fi
if [ "$DMIDECODE_FL" != "" ]; then
  MEM_SPEED=`awk '/Configured Clock Speed:/ {if ($4 == "Unknown") {next;}; printf("%s\n", $4);;exit;}' $DMIDECODE_FL`
  printf "host\tmem_speed_mhz\t%s\tmem_speed_mhz\n"  "$MEM_SPEED" >> $SUM_FILE;
fi
if [ -e run.log ]; then
 MYA=(sys_*_perf_stat.txt)
 if [ "${#MYA}" == "0" ]; then
   MYA=(../sys_*_perf_stat.txt)
 fi
 if [ "${#MYA}" != "0" ]; then
   # 20200719_155911 1595174351.170475304 start  
   DATE_ARR=()
   get_date_arr() {
   RESP=`awk -v want="$1" 'BEGIN{ ln = 0; day_str = ""; end_str = ""; }
   / start / {
      ln++;
      if (day_str == "" && $3 == "start" && substr($1, 1, 3) == "202") {
         val = $2 + 0.0;
         if (val != 0) {
            day_str=sprintf(strftime("%a_%b_%d", val));
            beg_str=sprintf(strftime("%a %b %e %H:%M:%S %Z %Y", val));
            got_it=1;
            next;
         }
      }
      printf("%s\n", $0);
      next;
   }
   / end /{
      if (end_str == "" && $3 == "end" && substr($1, 1, 3) == "202") {
         val = $2 + 0.0;
         end_str=sprintf(strftime("%a %b %e %H:%M:%S %Z %Y", val));
      }
   }
   END{
     if (day_str == "") {
       printf("");
       exit;
     } else {
     if (want == "day_str") {
       printf("%s", day_str);
     }
     if (want == "beg_str") {
       printf("%s", beg_str);
     }
     if (want == "end_str") {
       printf("%s", end_str);
     }
     }
   }' run.log`
   ck_last_rc $? $LINENO
   }
   get_date_arr "day_str"
   DATE_ARR[0]="$RESP"
   get_date_arr "beg_str"
   DATE_ARR[1]="$RESP"
   get_date_arr "end_str"
   DATE_ARR[2]="$RESP"
   echo "got run.log DATE_ARR0= ${DATE_ARR[0]}" > /dev/stderr
   echo "got run.log DATE_ARR1= ${DATE_ARR[1]}" > /dev/stderr
   echo "got run.log DATE_ARR2= ${DATE_ARR[2]}" > /dev/stderr
   printf "time\titp_run\t\"%s\"\tday_beg\n"  "${DATE_ARR[0]}" >> $SUM_FILE;
   printf "time\titp_run\t\"%s\"\tdate_beg\n" "${DATE_ARR[1]}" >> $SUM_FILE;
   printf "time\titp_run\t\"%s\"\tdate_end\n" "${DATE_ARR[2]}" >> $SUM_FILE;
 fi
fi

if [ -e $DIR/../run.log ]; then
  TST_END_TM=`cat $DIR/../run.log | awk '/ end /{printf("%d\n", $2);exit;}'`
fi
BEG=`cat $DIR/60secs.log | awk '{n=split($0, arr);printf("%s\n", arr[n]);exit;}'`
BEG_ADJ=`cat $DIR/60secs.log | awk -v script="$0.$LINENO.awk" '
   function dt_to_epoch(date_str, offset) {
   # started on Tue Dec 10 23:23:30 2019
   # Dec 10 23:23:30 2019
     if (date_str == "") {
        return 0.0;
     }
     months="  JanFebMarAprMayJunJulAugSepOctNovDec";
     n=split(date_str, darr, /[ :]+/);
     #for(i in darr) printf("darr[%d]= %s\n", i,  darr[i]);
     mnth_num = sprintf("%d", index(months, darr[1])/3);
     printf("mnth_num= %d\n", mnth_num) > "/dev/stderr";
     dt_str = darr[6] " " mnth_num " " darr[2] " " darr[3] " " darr[4] " " darr[5];
     printf("dt_str= %s\n", dt_str) > "/dev/stderr";
     epoch = mktime(dt_str);
     printf("%s epoch= %s offset= %s\n", script, epoch, offset) > "/dev/stderr";
     return epoch + offset;
   }
   {
     # start uptime at Mon May 25 01:24:45 UTC 2020 1590369885.689020272
     # Dec 10 23:23:30 2019
     epoch_in = $(NF)+0;
     num_int = sprintf("%d", epoch_in);
     print ENVIRON["AWKPATH"] > "/dev/stderr";
     num_dec = epoch_in - num_int;
     printf("%s BEG_ADJ: epoch_in= %f num_int= %s, num_dec= %s, in_str= %s\n", script, epoch_in, num_int, num_dec, $0) > "/dev/stderr";
     n=split($0, arr);
     j = 3;
     if (arr[j] != "at") {
        for (i=1; i < n; i++) {
          if (arr[i] == "at") {
             j = i;
             break;
          }
        }
     }
     #          mon           day         time         year
     date_str = arr[j+2] " " arr[j+3] " " arr[j+4] " " arr[j+6]
     epoch = dt_to_epoch(date_str, num_dec);
     dff_secs = epoch_in - epoch;
     dff_hrs  = dff_secs/3600;
     printf("epoch %d, epch_in= %d, diff= %f, dff_hrs= %f date_str= %s\n", epoch, epoch_in, dff_secs, dff_hrs, date_str) > "/dev/stderr";
     printf("%.3f\n", dff_hrs);
     printf("get back input date? %s\n", strftime("%a %b %e %H:%M:%S %Z %Y", epoch-dff_secs)) > "/dev/stderr";
     exit;
    }
    '`
   ck_last_rc $? $LINENO
if [ "$BEG_TM_IN" != "" ]; then
  BEG=$BEG_TM_IN
  echo "$0 set BEG_TM= $BEG_TM_IN"
fi
    echo "$0.$LINENO got here" > /dev/stderr
    #exit 1
if [ "$END_TM_IN" == "" -a "$TST_END_TM" != "" ]; then
  END_TM=$TST_END_TM
  echo "$0.$LINENO END_TM= $END_TM"
fi
echo "awk time offset hours BEG_ADJ= $BEG_ADJ  BEG_TM= $BEG, BEG_TM_IN= $BEG_TM_IN"
#exit
CPU2017LOG_RT_PATH="."
RESP=`find $CPU2017LOG_RT_PATH -name "CPU2017.00*.log" | wc -l | awk '{printf("%s\n", $1);exit;}'`
if [ "$RESP" -eq "0" ]; then
  CPU2017LOG_RT_PATH=".."
  RESP=`find $CPU2017LOG_RT_PATH -name "CPU2017.00*.log" | wc -l | awk '{printf("%s\n", $1);exit;}'`
fi
pwd
echo "++++++++++find .. -name CPU2017.*.log resp = $RESP" > /dev/stderr
CPU2017LOG=()
if [ "$RESP" -ge "1" -a "$PHASE_FILE" == "" ]; then
  RESP=`find $CPU2017LOG_RT_PATH -name CPU2017.00*.log`
  echo "find $CPU2017LOG_RT_PATH -name cpu2017.*.log resp = $RESP"
  CPU2017LOG=($RESP)
  echo "+++CPU2017LOG= ${CPU2017LOG[@]} is list"
  j=0
  for i in $RESP; do echo "echo $0.$LINENO j= $j CPU2017LOG $i ${CPU2017LOG[$j]}"; j=$((j+1)); done
fi
EXTRA_FILES=
if [ -e $DIR/$METRIC_OUT ]; then
  EXTRA_FILES=$DIR/$METRIC_OUT
else
  if [ -e $DIR/${METRIC_OUT}.csv ]; then
    EXTRA_FILES=$DIR/${METRIC_OUT}.csv
  fi
fi
    echo "$0.$LINENO got here" > /dev/stderr
if [ -e $DIR/infra_cputime.txt ]; then
  EXTRA_FILES="$EXTRA_FILES $DIR/infra_cputime.txt"
  #echo "$0: got $DIR/infra_cputime.txt at $LINENO" > /dev/stderr
fi
    echo "$0.$LINENO got here" > /dev/stderr
if [ -e $DIR/specjbb.log ]; then
  EXTRA_FILES="$EXTRA_FILES $DIR/specjbb.log"
  echo "$0: ____++++++_____got $DIR/specjbb.log at $LINENO" > /dev/stderr
else
if [ -e $DIR/*_specjbb/specjbb.log ]; then
  RESP=`find . -name specjbb.log`
  EXTRA_FILES="$EXTRA_FILES $RESP"
  echo "$0: ____++++++_____got specjbb.log $RESP at $LINENO" > /dev/stderr
fi
fi
for ifl in "phase_cpu2017.txt" "CPU2017.001.intrate.txt" "CPU2017.001.intrate.refrate.txt"  "CPU2017.001.log"; do
  if [ -e $DIR/$ifl ]; then
    EXTRA_FILES="$EXTRA_FILES $DIR/$ifl"
    echo "$0: ____++++++_____got $DIR/$ifl at $LINENO" > /dev/stderr
  else
  #if [ -e $DIR/*_specjbb/$ifl ]; then
    RESP=`find . -name $ifl`
    if [ "$RESP" == "" ]; then
      RESP=`find .. -name $ifl`
    fi
    if [ "$RESP" != "" ]; then
    EXTRA_FILES="$EXTRA_FILES $RESP"
    echo "$0: ____++++++_____got $ifl $RESP at $LINENO" > /dev/stderr
    fi
  #fi
  fi
done
    echo "$0.$LINENO got here" > /dev/stderr
if [ -e $DIR/yab_cmds.json ]; then
  EXTRA_FILES="$EXTRA_FILES $DIR/yab_cmds.json"
  echo "$0: got $DIR/yab_cmds.json at $LINENO" > /dev/stderr
else
if [ -e $DIR/yab_cmds.txt ]; then
  EXTRA_FILES="$EXTRA_FILES $DIR/yab_cmds.txt"
  echo "$0: got $DIR/yab_cmds.txt at $LINENO" > /dev/stderr
fi
fi
FILES=`ls -1 $DIR/sys_*_*.txt $EXTRA_FILES`
echo "FILES = $FILES"
if [ "$FILES" == "" ]; then
   FILES=`ls -1 $DIR/*txt.tsv`
fi
FILES2=`ls -1 $DIR/../sys_*_*.txt`
if [ "$FILES2" != "" ]; then
    FILES="$FILES $FILES2"
fi
for i in $FILES; do
 if [ -e job_${JOB_ID}.stop ]; then
    RESP=`head -1 job_${JOB_ID}.stop`
    echo "$0: quitting at line $LINENO due to found job_$JOB_ID.stop having value PID= $RESP"
    exit 1
 fi
 echo $i
  if [[ $i == *"_uptime.txt"* ]]; then
    echo "do uptime"
    awk -v pfx="$PFX" '
      BEGIN{beg=1;mx=0}
      function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
      function rtrim(s) { sub(/[ \t\r\n,]+$/, "", s); return s }
      function trim(s) { return rtrim(ltrim(s)); }
#title	mpstat cpu= all
#hdrs	2	1	62	10
#CPU	%usr	%nice	%sys	%iowait	%irq	%soft	%steal	%guest	%gnice	%idle
#all	10.66	10.44	3.84	0.22	0.00	0.13	0.00	0.00	0.00	74.72

      /load average/ {
	FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        n = split($0, arr, /[ ,]/);
        for (i=1; i <= NF; i++) {
           if ($i == "average:") {
                if (beg==1) {
                   sv[++mx] = "ld_avg_1m\tld_avg_5m\tld_avg_15m"
                   #printf("ld_avg_1m\tld_avg_5m\tld_avg_15m\n") > NFL;
                   beg=0;
                }
                sv[++mx]=sprintf("%s\t%s\t%s", trim($(i+1)), trim($(i+2)), trim($(i+3)));
                #printf("%s\t%s\t%s\n", trim($(i+1)), trim($(i+2)), trim($(i+3))) > NFL;
                break;
           }
        }
     }
     END{
trows++; printf("\t$ uptime\n") > NFL;
trows++; printf("\t23:51:26 up 21:31, 1 user, load average: 30.02, 26.43, 19.02\n") > NFL;
trows++; printf("\tThis is a quick way to view the load averages, which indicate the number of tasks (processes) wanting to\n") > NFL;
trows++; printf("\trun. On Linux systems, these numbers include processes wanting to run on CPU, as well as processes\n") > NFL;
trows++; printf("\tblocked in uninterruptible I/O (usually disk I/O). This gives a high level idea of resource load (or demand), but\n") > NFL;
trows++; printf("\tcan\x27t be properly understood without other tools. Worth a quick look only.\n") > NFL;
trows++; printf("\tThe three numbers are exponentially damped moving sum averages with a 1 minute, 5 minute, and 15\n") > NFL;
trows++; printf("\tminute constant. The three numbers give us some idea of how load is changing over time. For example, if\n") > NFL;
trows++; printf("\tyou\x27ve been asked to check a problem server, and the 1 minute value is much lower than the 15 minute\n") > NFL;
trows++; printf("\tvalue, then you might have logged in too late and missed the issue.\n") > NFL;
trows++; printf("\tIn the example above, the load averages show a recent increase, hitting 30 for the 1 minute value, compared\n") > NFL;
trows++; printf("\tto 19 for the 15 minute value. That the numbers are this large means a lot of something: probably CPU\n") > NFL;
trows++; printf("\tdemand; vmstat or mpstat will confirm, which are commands 3 and 4 in this sequence.\n") > NFL;
trows++; printf("\n") > NFL;

       printf("title\tuptime\tsheet\tuptime\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t0\t%d\t2\t-1\n", trows+2, trows+mx+1) > NFL;
       for (i=1; i <= mx; i++) {
          printf("%s\n", sv[i]) > NFL;
       }
       close(NFL);
     }
   ' $i
   ck_last_rc $? $LINENO
   SHEETS="$SHEETS $i.tsv"
  fi

  if [[ $i == *"$METRIC_OUT"* ]]; then
    echo "do itp $DIR $METRIC_OUT $i"
    ls -l
    NCPUS=1
    if [ "$LSCPU_FL" != "" ]; then
     NCPUS=`awk '/^CPU.s.:/ { printf("%s\n", $2);exit;}' $LSCPU_FL`
    fi
    SPIN_TXT=
    CPU2017files=
    if [ "${#CPU2017LOG[@]}" -gt "0" ]; then
      for ii in ${CPU2017LOG[@]}; do
        CPU2017files+="$ii "
      done
      echo "CPU2017files= $CPU2017files"
      #SPIN_TXT=`dirname $CPU2017LOG`
      SPIN_TXT="$( cd "$( dirname "${CPU2017LOG[0]}" )" >/dev/null 2>&1 && pwd )"
      if [ -d $SPIN_TXT ]; then
         SPIN_TXT=$SPIN_TXT/../spin.txt
         if [ ! -e $SPIN_TXT ]; then
           SPIN_TXT=
         fi
      fi
    fi
    if [ "$SPIN_TXT" == "" ]; then
      if [ -e $DIR/spin.txt ]; then
         SPIN_TXT=$DIR/spin.txt
      fi
      if [ -e $DIR/../spin.txt ]; then
         SPIN_TXT=$DIR/../spin.txt
      fi
    fi
    MET_FL=$METRIC_OUT
    MET_AV=$METRIC_AVG
    if [ ! -e $DIR/$METRIC_OUT ]; then
       MET_FL=metric_out.csv
       MET_AV=metric_out.average.csv
    fi
    pwd
    echo "========SPIN_TXT5= $SPIN_TXT dir= $DIR i= $i, average= $AVERAGE, NCPUS= $NCPUS, MET_FL= $MET_FL, MET_AV= $MET_AV" > /dev/stderr
    export AWKPATH=$SCR_DIR
    echo awk  -v verbose="$VERBOSE" -v sum_tmam="$SUM_TMAM_FILE" -v options="$OPTIONS" -v tm_beg_in="$BEG_TM_IN" -v tm_end_in="$END_TM" -v do_avg="$AVERAGE" -v sum_file="$SUM_FILE" -v metric_file="$MET_FL" -v metric_avg="$MET_AV" -v pfx="$PFX" -f $SCR_DIR/itp_2_tsv.awk $CPU2017files $DIR/result.csv $DIR/$MET_AV $i $SPIN_TXT
    awk  -v sum_tmam="$SUM_TMAM_FILE" -v options="$OPTIONS" -v tm_beg_in="$BEG_TM_IN" -v tm_end_in="$END_TM" -v do_avg="$AVERAGE" -v sum_file="$SUM_FILE" -v metric_file="$MET_FL" -v metric_avg="$MET_AV" -v pfx="$PFX" -f $SCR_DIR/itp_2_tsv.awk $CPU2017files $DIR/result.csv $DIR/$MET_AV $i $SPIN_TXT
    ck_last_rc $? $LINENO
   pwd
   echo "cpu2017log= $CPU2017LOG"
   for ii in ${CPU2017LOG[@]}; do
     if [ -e $ii ]; then
        echo "found -e $ii"
     fi
   done
   SHEETS="$SHEETS $i.tsv"
  fi

  if [[ $i == *"_power.txt"* ]]; then
    echo "do power"
    #RESP=`grep "Power Consumption History" $i | wc -l`
    #if [ "$RESP" != "0" ]; then
      # delloem format data
    #else
      # ipmitool sdr format

    UEND_TM=
    if [ "$END_TM" != "" ]; then
      UEND_TM=$END_TM
    else
      if [ "$PH_TM_END" == "" ]; then
        UEND_TM=$PH_TM_END
      fi
    fi

    awk -v ts_beg="$BEG" -v ts_end="$UEND_TM" -v pfx="$PFX" -v sum_file="$SUM_FILE" -v sum_flds="avg_60secs{avg_power_60sec_mvg_avg|power|%stdev},max_60secs{max_power_60sec_mvg_avg|power},min_60secs{min_power_60sec_mvg_avg|power},SysFan_Power{|power},MB_HSC_Pwr_Out{|power},Total_Power{|power},Power_CPU{|power},Power_Memory{|power},PSU0_Input{|power},PSU0_Output{|power},PSU1_Input{|power},PSU1_Output{|power},HSC_Input_Power{|power},HSC_Output_Power{|power},PDB_HSC_POUT{|power},P0_Pkg_Power{|power},P1_Pkg_Power{|power},CPU0_VR0_Pout{|power},CPU0_VR1_Pout{|power},CPU1_VR0_Pout{|power},CPU1_VR1_Pout{|power},PCH_VR_POUT{|power},CPU0_DM_VR0_POUT{|power},CPU0_DM_VR1_POUT{|power},CPU1_DM_VR0_POUT{|power},CPU1_DM_VR1_POUT{|power},PSU0_POUT{|power},PSU1_POUT{|power},PSU0_PIN{|power},PSU1_PIN{|power},power{power_inst|power|stdev}" '
    @include "get_excel_col_letter_from_number.awk"
      BEGIN{
        beg=1;
        mx=0;
        rw=1;
        ts_end += 0.0;
        delloem=0;
        area1_idx=0;
       if (sum_file != "" && sum_flds != "") {
         n_sum = split(sum_flds, sum_arr, ",");
         for (i_sum=1; i_sum <= n_sum; i_sum++) {
            sum_type[i_sum] = 0;
            sum_opt[i_sum] = "";
            str = sum_arr[i_sum];
            pos = index(str, "{");
            if (pos > 0) {
               pos1 = index(str, "}");
               if (pos1 == 0) { pos1= length(str)+1; }
               sum_str = substr(str, pos+1, pos1-pos-1);
               n_sum2 = split(sum_str, sum_arr2, "|");
               if (sum_arr2[1] != "") {
                 sum_prt[i_sum] = sum_arr2[1];
               } else {
                 #sum_prt[i_sum] = str;
                 sum_prt[i_sum] = substr(str, 1, pos-1);
               }
               if (sum_arr2[2] != "") {
                 sum_res[i_sum] = sum_arr2[2];
               }
               if (sum_arr2[3] != "") {
                 sum_opt[i_sum] = sum_arr2[3];
               }
               #sum_prt[i_sum] = substr(str, pos+1, pos1-pos-1);
               sum_arr[i_sum] = substr(str, 1, pos-1);
            } else {
               sum_prt[i_sum] = str;
            }
            printf("pwr: sum_prt[%d]= %s, sum_res= %s\n", i_sum, sum_prt[i_sum], sum_res[i_sum]) > "/dev/stderr";
            if (index(str, "%") > 0) {
               sum_type[i_sum] = 0;
            }
         }
       }
      }
      function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
      function rtrim(s) { sub(/[ \t\r\n,]+$/, "", s); return s }
      function trim(s) { return rtrim(ltrim(s)); }
#==beg 0 date 1585614813.506068153
#NIC_Temp         | 81 degrees C      | ok
#HSC_Input_Power  | 119.00 Watts      | ok
#HSC_Output_Power | 119.00 Watts      | ok
#PDB_HSC_POUT     | 264.00 Watts      | ok
#P0_Pkg_Power     | 34.00 Watts       | ok
#P1_Pkg_Power     | 33.00 Watts       | ok

      /^==beg / {
         tm_bdt = $4 + 0.0;
         if (ts_end > 0.0 && tm_bdt > ts_end) { exit; }
      }
      /^==end / {
         tm_edt = $4 + 0.0;
         tm[rw] = tm_edt;
         rw++;
      }
      /Instantaneous power reading:/ {
        delloem=2; 
         area = "power";
         pwr  = $4;
         typ=1
         if (!(area in area1_lkup)) {
            area1_idx++
            area1_lkup[area] = area1_idx;
            area1_list[area1_idx] = area;
         }
         i = area1_lkup[area];
         rows[rw,typ,i] = pwr + 0.0;
         next;
      }
#    Instantaneous power reading:                   138 Watts
#Statistic                   Last Minute     Last Hour     Last Day     Last Week
#Average Power Consumption   137 W           137 W         119 W        119 W   
#Max Power Consumption       174 W           174 W         174 W        180 W   
#Min Power Consumption       112 W           112 W         112 W        110 W   
      /^Power Consumption History/ {
        delloem=1; 
      }
      /^Average Power Consumption|^Max Power Consumption|^Min Power Consumption/ {
         if ($1 == "Average") { str= "avg"; }
         if ($1 == "Max")     { str= "max"; }
         if ($1 == "Min")     { str= "min"; }
         area = str "_60secs";
         pwr  = $4;
         typ=1
         if (!(area in area1_lkup)) {
            area1_idx++
            area1_lkup[area] = area1_idx;
            area1_list[area1_idx] = area;
         }
         i = area1_lkup[area];
         rows[rw,typ,i] = pwr + 0.0;
      }
      {
	FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        if (delloem >= 1) {
          next;
        }
        n = split($0, arr, "|");
        for (i=1; i <= n; i++) {
           arr[i] = trim(arr[i]);
        }
        if (arr[3] != "ok") {
           next;
        }
        nn = split(arr[2], va, " ");
        area = arr[1];
        typ=0;
        if ( va[2] == "Watts") {
          typ=1;
        }
        if (va[2] == "degrees" ) {
          typ=2;
        }
        if (va[2] == "RPM" ) {
          typ=3;
        }
        if ( typ > 0) {
          units[typ] = va[2];
          if (typ==1) {
          if ((!(area in area1_lkup))) {
             area1_idx++
             area1_lkup[area] = area1_idx;
             area1_list[area1_idx] = area;
             a_mx++;
             a_lkup[a_mx,"area"] = area;
             a_lkup[a_mx,"idx"] = area1_idx;
             a_lkup[a_mx,"typ"] = typ;
             aa_lkup[typ,area1_idx] = area;
          }
          i = area1_lkup[area];
          }
          if (typ==2) {
          if ((!(area in area2_lkup))) {
             area2_idx++
             area2_lkup[area] = area2_idx;
             area2_list[area2_idx] = area;
             a_mx++;
             a_lkup[a_mx,"area"] = area;
             a_lkup[a_mx,"idx"] = area2_idx;
             a_lkup[a_mx,"typ"] = typ;
             aa_lkup[typ,area2_idx] = area;
          }
          i = area2_lkup[area];
          }
          if (typ==3) {
          if ((!(area in area3_lkup))) {
             area3_idx++
             area3_lkup[area] = area3_idx;
             area3_list[area3_idx] = area;
             a_mx++;
             a_lkup[a_mx,"area"] = area;
             a_lkup[a_mx,"idx"] = area3_idx;
             a_lkup[a_mx,"typ"] = typ;
             aa_lkup[typ,area3_idx] = area;
          }
          i = area3_lkup[area];
          }
          rows[rw,typ,i] = va[1] + 0.0;
        }
	FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
      }
     END{
       add_col = 1;
       rw_mx = rw;
       if (delloem >= 1) {
         rw--;
         add_col = 0;
       }
       brw = 6;
       if (n_sum > 0) {
            for (k=1; k <= area1_idx; k++) {
              hdr_lkup[k] = -1;
            }
            for (k=1; k <= area1_idx; k++) {
              for (i_sum=1; i_sum <= n_sum; i_sum++) {
                 if ( area1_list[k] == sum_arr[i_sum]) {
                    hdr_lkup[k] = i_sum;
                    break; # so if hdr appears more than one in sum_flds, it will be skipped
                 }
              }
            }
       }
       hdr_mx = area1_idx;
trows++; printf("\t$ power") > NFL;
       for (i=2; i <= hdr_mx+area2_idx+area3_idx+1; i++) {
         let = get_excel_col_letter_from_number(i+add_col);
         printf("\t=subtotal(1,%s%d:%s%d)", let, brw, let, brw+rw) > NFL;
       }
       printf("\n") > NFL;
trows++; printf("\t$ power") > NFL;
       for (i=2; i <= hdr_mx+area2_idx+area3_idx+1; i++) {
         let = get_excel_col_letter_from_number(i+add_col);
         printf("\t=subtotal(4,%s%d:%s%d)", let, brw, let, brw+rw) > NFL;
       }
       printf("\n") > NFL;

       trows++;
       printf("title\tpower\tsheet\tpower\ttype\tscatter_straight\n") > NFL;
       printf("hdrs\t%d\t%d\t%d\t%d\t1\n", trows+1, 2, -1, area1_idx+1) > NFL;
       tab="";
       printf("TS\tts_rel\t") > NFL;
       for (i=1; i <= hdr_mx; i++) {
            printf("%s%s", tab, area1_list[i]) > NFL;
            tab="\t";
       }
       for (i=1; i <= area2_idx; i++) {
            printf("%s%s", tab, area2_list[i]) > NFL;
            tab="\t";
       }
       for (i=1; i <= area3_idx; i++) {
            printf("%s%s", tab, area3_list[i]) > NFL;
            tab="\t";
       }
       row++;
       printf("\n") > NFL;
       for (r=1; r <= rw; r++) {
          tab="";
          if (r == 1) {
             intrvl = tm[r]-ts_beg;
          } else {
             if (tm[r] == 0) {
               continue;
             }
             intrvl = tm[r]-tm[r-1];
          }
          printf("%.3f\t%.4f\t", tm[r], tm[r]-ts_beg) > NFL;
          for (c=1; c <= area1_idx; c++) {
              printf("%s%s", tab, rows[r,1,c]) > NFL;
              tab="\t";
                 if (hdr_lkup[c] != -1) {
                   i_sum = hdr_lkup[c];
                   sum_occ[i_sum] += 1;
                   if (sum_type[i_sum] == 1) {
                     if (sum_tmin[i_sum] == 0) { sum_tmin[i_sum] = tm[r]; sum_tmax[i_sum] = sum_tmin[i_sum]; }
                     if (sum_tmax[i_sum] < tm[r]) { sum_tmax[i_sum] = tm[r]; }
                     if (r > 1) {intrvl = tm[r] - tm[r-1]; } else { intrvl = tm[r]-ts_beg; };
                     sum_x = rows[r,1,c] * intrvl;
                   } else {
                     sum_x = rows[r,1,c]
                   }
                   sum_tot[i_sum] += sum_x
                   sum_x2[i_sum]  += sum_x * sum_x
                 }
          }
          for (c=1; c <= area2_idx; c++) {
              printf("%s%s", tab, rows[r,2,c]) > NFL;
              tab="\t";
          }
          for (c=1; c <= area3_idx; c++) {
              printf("%s%s", tab, rows[r,3,c]) > NFL;
              tab="\t";
          }
          printf("\n") > NFL;
          row++;
       }
       printf("\n") > NFL;
       if (area2_idx > 0) {
       printf("title\ttemperature\tsheet\tpower\ttype\tscatter_straight\n") > NFL;
       printf("hdrs\t%d\t%d\t%d\t%d\t1\n", trows+1, area1_idx+2, -1, area2_idx+area1_idx+1) > NFL;
       printf("\n") > NFL;
       }
       if (area3_idx > 0) {
       printf("title\tFans RPM\tsheet\tpower\ttype\tscatter_straight\n") > NFL;
       printf("hdrs\t%d\t%d\t%d\t%d\t1\n", trows+1, area1_idx+area2_idx+2, -1, area3_idx+area2_idx+area1_idx+1) > NFL;
       }
       close(NFL);
          tool = "ipmitool";
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
             if (sum_occ[i_sum] == 0) {
                continue;
             }
             n = sum_occ[i_sum];
             if (sum_type[i_sum] == 1) {
                n = sum_tmax[i_sum] - sum_tmin[i_sum];
             }
             avg = (n > 0.0 ? sum_tot[i_sum]/n : 0.0);
             printf("%s\t%s\t%f\t%s\n", sum_res[i_sum], tool, avg, sum_prt[i_sum]) >> sum_file;
             stdev = 0.0;
             if (index(sum_opt[i_sum], "stdev") > 0) {
                if (n > 0.0) {
                  #     stdev = sqrt((sum_x2 / n) - (mean * mean))
                  stdev = sqrt((sum_x2[i_sum] / n) - (avg * avg))
                }
             }
             if (index(sum_opt[i_sum], "%stdev") > 0) {
                printf("%s\t%s\t%f\t%s %%stdev\n",  sum_res[i_sum], tool, 100.0*stdev/avg, sum_prt[i_sum]) >> sum_file;
             }
             else if (index(sum_opt[i_sum], "stdev") > 0) {
                printf("%s\t%s\t%f\t%s stdev\n",  sum_res[i_sum], tool, stdev, sum_prt[i_sum]) >> sum_file;
             }
          }

          for (k=1; k <= 3; k++) {
            if (k == 1) { a_idx = area1_idx; }
            if (k == 2) { a_idx = area2_idx; }
            if (k == 3) { a_idx = area3_idx; }
          for (j=1; j <= a_idx; j++) {
             sum_n[j] = 0;
             sum[j] = 0.0;
          }
          for (i=1; i <= rw_mx; i++) {
            for (j=1; j <= a_idx; j++) {
              if (rows[i,k,j] != "") {
                sum_n[j]++;
                sum[j] += rows[i,k,j];
              }
            }
          }
          for (j=1; j <= a_idx; j++) {
            avg = 0.0;
            if (sum_n[j] > 0.0) {
              avg = sum[j]/sum_n[j];
            }
            printf("%s bb\t%s %s\t%f\t%s\n", "pppat pwr", tool, units[k], avg, aa_lkup[k,j]) >> sum_file;
          }
          }
     }
   ' $i
   ck_last_rc $? $LINENO
   SHEETS="$SHEETS $i.tsv"
  fi
  if [[ $i == *"_vmstat.txt"* ]]; then
    echo "do vmstat"
#procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
# r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
# 4  0      0 1329084 842316 44802156    0    0    51    37    0    0 16  2 81  0  0
# 4  0      0 1319472 842316 44802156    0    0     0    12 20779 58660 14  1 85  0  0
# 2  0      0 1384300 842320 44802160    0    0     0   356 17266 81860 11  1 88  0  0
#procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu----- -----timestamp-----
# r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st                 PDT
# 2  0      0 788814272  42920 490300    0    0     0     0    1    1  0  0 100  0  0 2021-06-26 13:14:55
# 8  0      0 787426944  49736 772984    0    0  3575  7574 3081 1217  6  0 94  0  0 2021-06-26 13:15:25
# 8  0      0 787579520  50260 1063436    0    0  1014 13481 2600  815  6  0 94  0  0 2021-06-26 13:15:55
# 8  0      0 787232448  52096 1390556    0    0   784 21540 3444 1150  7  1 93  0  0 2021-06-26 13:16:25

    DURA=`awk -v ts_beg="$BEG" -v ts_end="$END_TM" 'BEGIN{ts_beg+=0.0;ts_end+=0.0; if (ts_beg > 0.0 && ts_end > 0.0) {printf("%d\n", ts_end-ts_beg); } else {printf("-1\n");};exit;}'`
    awk -v ts_beg="$BEG" -v pfx="$PFX" -v max_lines="$DURA" -v sum_file="$SUM_FILE" -v sum_flds="runnable{vmstat runnable PIDs|OS},interrupts/s{|OS},context switch/s{|OS},%user{|CPU},%idle{|CPU|%stdev}" '
     BEGIN{
       beg=1;
       col_mx=-1;
       mx=0;
       n_sum = 0;
       max_lines += 0;
       has_ts = 0;
       if (sum_file != "" && sum_flds != "") {
         n_sum = split(sum_flds, sum_arr, ",");
         for (i_sum=1; i_sum <= n_sum; i_sum++) {
            sum_type[i_sum] = 0;
            sum_res[i_sum] = "";
            sum_opt[i_sum] = "";
            str = sum_arr[i_sum];
            pos = index(str, "{");
            if (pos > 0) {
               pos1 = index(str, "}");
               if (pos1 == 0) { pos1= length(str)+1; }
               sum_str = substr(str, pos+1, pos1-pos-1);
               n_sum2 = split(sum_str, sum_arr2, "|");
               if (sum_arr2[1] != "") {
                 sum_prt[i_sum] = sum_arr2[1];
               } else {
                 #sum_prt[i_sum] = str;
                 sum_prt[i_sum] = substr(str, 1, pos-1);
               }
               if (sum_arr2[2] != "") {
                 sum_res[i_sum] = sum_arr2[2];
               }
               if (sum_arr2[3] != "") {
                 sum_opt[i_sum] = sum_arr2[3];
               }
               #sum_prt[i_sum] = substr(str, pos+1, pos1-pos-1);
               sum_arr[i_sum] = substr(str, 1, pos-1);
            } else {
               sum_prt[i_sum] = str;
            }
            if (index(tolower(str), "/s") > 0) {
               sum_type[i_sum] = 1;
            }
         }
       }
     }
     /^procs/{
       if (index($0, "timestamp") > 0) {
         has_ts = 1;
       }
       next;
     }
     {
       	FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        if (max_lines > 0.0 && mx > max_lines) {
          exit;
        }
     }
     /swpd/{
        if (beg == 0) { next; }
        if (has_ts == 1) {
          ts_tz = $(NF);
          $(NF) = "ts_dt";
          ts_dt_col = NF;
          NF++;
          $(NF) = "ts_tm";
          ts_tm_col = NF;
        }
        beg = 0;
        for (i=1; i <= NF; i++) {
         hdrs[i]=$i;
        }
        tab="";
        hdr="";
        for (i=1; i <= NF; i++) {
          col_mx++;
          hdr=hdr "" sprintf("%s%s", tab, hdrs[i]);
          tab="\t";
        }
        sv[++mx]=hdr;
        #printf("\n") > NFL;
        next;
     }
     {
        tab="";
        ln="";
        for (i=1; i <= NF; i++) {
          ln=ln "" sprintf("%s%s", tab, $i);
          tab="\t";
        }
        sv[++mx]=ln;
        #printf("\n") > NFL;
     }
     END{
trows=0;
trows++; printf("\tShort for virtual memory stat, vmstat(8) is a commonly available tool (first created for BSD decades ago). It\n") > NFL;
trows++; printf("\tprints a summary of key server statistics on each line.\n") > NFL;
trows++; printf("\tvmstat was run with an argument of 1, to print one second summaries. The first line of output (in this version\n") > NFL;
trows++; printf("\tof vmstat) has some columns that show the average since boot, instead of the previous second. For now,\n") > NFL;
trows++; printf("\tskip the first line, unless you want to learn and remember which column is which.\n") > NFL;
trows++; printf("\tColumns to check:\n") > NFL;
trows++; printf("\tr: Number of processes running on CPU and waiting for a turn. This provides a better signal than\n") > NFL;
trows++; printf("\tload averages for determining CPU saturation, as it does not include I/O. To interpret: an \"r\" value\n") > NFL;
trows++; printf("\tgreater than the CPU count is saturation.\n") > NFL;
trows++; printf("\tfree: Free memory in kilobytes. If there are too many digits to count, you have enough free\n") > NFL;
trows++; printf("\tmemory. The \"free -m\" command, included as command 7, better explains the state of free\n") > NFL;
trows++; printf("\tmemory.\n") > NFL;
trows++; printf("\tsi, so: Swap-ins and swap-outs. If these are non-zero, you\x27re out of memory.\n") > NFL;

trows++; printf("\tus, sy, id, wa, st: These are breakdowns of CPU time, on average across all CPUs. They are\n") > NFL;
trows++; printf("\tuser time, system time (kernel), idle, wait I/O, and stolen time (by other guests, or with Xen, the\n") > NFL;
trows++; printf("\tguest\x27s own isolated driver domain).\n") > NFL;
trows++; printf("\tThe CPU time breakdowns will confirm if the CPUs are busy, by adding user + system time. A constant\n") > NFL;
trows++; printf("\tdegree of wait I/O points to a disk bottleneck; this is where the CPUs are idle, because tasks are blocked\n") > NFL;
trows++; printf("\twaiting for pending disk I/O. You can treat wait I/O as another form of CPU idle, one that gives a clue as to\n") > NFL;
trows++; printf("\twhy they are idle.\n") > NFL;
trows++; printf("\tSystem time is necessary for I/O processing. A high system time average, over 20%, can be interesting to\n") > NFL;
trows++; printf("\texplore further: perhaps the kernel is processing the I/O inefficiently.\n") > NFL;
trows++; printf("\tIn the above example, CPU time is almost entirely in user-level, pointing to application level usage instead.\n") > NFL;
trows++; printf("\tThe CPUs are also well over 90%% utilized on average. This isn\x27t necessarily a problem; check for the degree\n") > NFL;
trows++; printf("\tof saturation using the \"r\" column.\n") > NFL;
trows++; printf("\t\n") > NFL;

       col_beg=0;
       col_end = col_mx;
       col_ts = -1;
       if (has_ts == 1) {
         col_beg=2;
         col_end = col_mx; # dont plot the date & time string
         col_ts = 1;
       }
       printf("title\tvmstat all\tsheet\tvmstat\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t%s\t%d\t%d\t%d\n", 2+trows, col_beg, mx+1+trows, col_end, col_ts) > NFL;
       r_col = -1;
       b_col = -1;
       us_col = -1;
       in_col = -1;
       cs_col = -1;
       bi_col = -1;
       bo_col = -1;
       cache_col = -1;
       free_col = -1;
       buff_col = -1;
       nhdr["r"] = "runnable";
       nhdr["b"] = "blocked";
       nhdr["swpd"] = "swapped";
       nhdr["free"] = "free";
       nhdr["buff"] = "buffers";
       nhdr["cache"] = "cached";
       nhdr["si"] = "mem swapped in/s";
       nhdr["so"] = "mem swapped out/s";
       nhdr["in"] = "interrupts/s";
       nhdr["cs"] = "context switch/s";
       nhdr["bi"] = "blocks in/s";
       nhdr["bo"] = "blocks out/s";
       nhdr["us"] = "%user";
       nhdr["sy"] = "%system";
       nhdr["id"] = "%idle";
       nhdr["wa"] = "%waitingIO";
       nhdr["st"] = "%stolen";
        #r b swpd free buff cache si so bi bo in cs us sy id wa st
       n = split(sv[1], arr, "\t");
       nwln = "";
       sep  = "";
       for (i=1; i <= n; i++) {
          if (arr[i] == "r")  { r_col  = i-1; }
          if (arr[i] == "b")  { b_col  = i-1; }
          if (arr[i] == "us") { us_col = i-1; }
          if (arr[i] == "in") { in_col = i-1; }
          if (arr[i] == "cs") { cs_col = i-1; }
          if (arr[i] == "bi") { bi_col = i-1; }
          if (arr[i] == "bo") { bo_col = i-1; }
          if (arr[i] == "cache") { cache_col = i-1; }
          if (arr[i] == "free")  { free_col  = i-1; }
          if (arr[i] == "buff")  { buff_col  = i-1; }
          if (arr[i] in nhdr) { str = nhdr[arr[i]]; } else { str = arr[i]; }
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
              if (str == sum_arr[i_sum]) {
                 sum_lkup[i_sum] = i;
              }
          }
          nwln = nwln "" sep "" str;
          sep = "\t";
       }
       #start vmstat at Sat Jun 26 13:14:55 PDT 2021 1624738495.312025602
       if (has_ts == 1) {
         printf("%s\t%s\t", "timestamp", "ts_rel") > NFL;
       }
     
       printf("%s\n", nwln) > NFL;
       for (i=2; i <= mx; i++) {
          if (n_sum > 0) {
            n = split(sv[i], arr, "\t");
            if (has_ts == 1) {
              dt = arr[ts_dt_col];
              tm = arr[ts_tm_col];
              ndt = split(dt, dt_arr, "-");
              ntm = split(tm, tm_arr, ":");
              dt_str = dt_arr[1] " " dt_arr[2] " " dt_arr[3] " " tm_arr[1] " " tm_arr[2] " " tm_arr[3];
              epch=mktime(dt_str);
              if (ts_beg0 == "") {
                ts_beg0 = epch;
                # mktime uses current timezone which may be different then data time zone
                # assume that 1st epoch time is within an hour of ts_beg.
                ts_beg_i = sprintf("%d", ts_beg) + 0;
                ts_intrvl = (epch - ts_beg_i) % 3600; 
                #printf("dt= %s, tm= %s, epch= %s, ts_beg= %s dt_str= %s, ts_intrvl= %s\n", dt, tm, epch, ts_beg, dt_str, ts_intrvl);
                #exit(1);
              }
              printf("%3f\t%.3f\t", ts_beg+(epch - ts_beg0), epch - ts_beg0) > NFL;
            }
            for (i_sum=1; i_sum <= n_sum; i_sum++) {
              j = sum_lkup[i_sum];
              sum_occ[i_sum] += 1;
              sum_tot[i_sum] += arr[j];
              sum_x2[i_sum] += arr[j]*arr[j];

            }
          }
          printf("%s\n", sv[i]) > NFL;
       }
       #printf("hdrs\t%d\t%s\t%d\t%d\t%d\n", 2+trows, col_beg, mx+1+trows, col_end, col_ts) > NFL;
       printf("\ntitle\tvmstat cpu\tsheet\tvmstat\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n", 2+trows, col_beg, mx+1+trows, col_end, col_ts, r_col+col_beg, r_col+col_beg, b_col+col_beg, b_col+col_beg, us_col+col_beg, col_mx) > NFL;

       printf("\ntitle\tvmstat interrupts & context switches\tsheet\tvmstat\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n", 2+trows, col_beg, mx+1+trows, col_end, col_ts, in_col+col_beg, in_col+col_beg, cs_col+col_beg, cs_col+col_beg) > NFL;

       printf("\ntitle\tvmstat memory cache, free & buffers\tsheet\tvmstat\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n", 2+trows, col_beg, mx+1+trows, col_end, col_ts, cache_col+col_beg, cache_col+col_beg, free_col+col_beg, free_col+col_beg, buff_col+col_beg, buff_col+col_beg) > NFL;

       printf("\ntitle\tvmstat IO blocks in & blocks out\tsheet\tvmstat\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n", 2+trows, col_beg, mx+1+trows, col_end, col_ts, bi_col+col_beg, bi_col+col_beg, bo_col+col_beg, bo_col+col_beg) > NFL;

       close(NFL);
       if (n_sum > 0) {
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
             n = sum_occ[i_sum];
             avg = (n > 0.0 ? sum_tot[i_sum]/n : 0.0);
             printf("%s\t%s\t%f\t%s\n",  sum_res[i_sum], "vmstat", avg, sum_prt[i_sum]) >> sum_file;
             stdev = 0.0;
             if (index(sum_opt[i_sum], "stdev") > 0) {
                if (n > 0.0) {
                  #     stdev = sqrt((sum_x2 / n) - (mean * mean))
                  stdev = sqrt((sum_x2[i_sum] / n) - (avg * avg))
                }
             }
             if (index(sum_opt[i_sum], "%stdev") > 0) {
                printf("%s\t%s\t%f\t%s %%stdev\n",  sum_res[i_sum], "vmstat", 100.0*stdev/avg, sum_prt[i_sum]) >> sum_file;
             }
             else if (index(sum_opt[i_sum], "stdev") > 0) {
                printf("%s\t%s\t%f\t%s stdev\n",  sum_res[i_sum], "vmstat", stdev, sum_prt[i_sum]) >> sum_file;
             }
          }
       }
       }
   ' $i
   ck_last_rc $? $LINENO
   SHEETS="$SHEETS $i.tsv"
  fi
  if [[ $i == *"_mpstat.txt"* ]]; then
    echo "do mpstat"
#Linux 4.14.131 (agent-dedicated1812-phx2) 	01/21/2020 	_x86_64_	(32 CPU)
#12:01:01 AM  CPU    %usr   %nice    %sys %iowait    %irq   %soft  %steal  %guest  %gnice   %idle
#12:01:02 AM  all   10.66   10.44    3.84    0.22    0.00    0.13    0.00    0.00    0.00   74.72
#12:01:02 AM    0   10.10    4.04    2.02    0.00    0.00    0.00    0.00    0.00    0.00   83.84
#12:01:02 AM    1    1.03    6.19    2.06    0.00    0.00    0.00    0.00    0.00    0.00   90.72

    awk -v script="$0.$LINENO.mpstat.awk" -v sum_file="$SUM_FILE" -v options="$OPTIONS" -v ts_beg="$BEG" -v ts_end="$END_TM" -v pfx="$PFX" '
     BEGIN{
        beg=1;
        grp_mx=0;
        hdr_mx=0;
        ts_beg += 0;
        ts_end += 0;
        epoch_init = 0;
        dt_fmt_has_am_pm = 1;
        got_skip_mpstat_percpu_charts = index(options, "mpstat_skip_percpu_charts");
        if (got_skip_mpstat_percpu_charts > 0) {
           printf("%s: going to skip_mpstat_percpu_charts due to string found in options\n", script) > "/dev/stderr";
        }
        printf("%s _______beg mpstat data, ts_beg= %s, ts_end= %s\n", script, ts_beg, ts_end) > "/dev/stderr";
      }
      function dt_to_epoch(hhmmss, ampm) {
         # the epoch seconds from the date time info in the file is local time,not UTC.
         # so just use the calc"d epoch seconds to calc the elapsed seconds since the start.
         # THe real timestamp is the input ts_beg + elapsed_seconds.
         # hhmmss fmt= hh:mm:ss (w leading 0
         if (dt_beg["yy"] == "") {
            return 0.0;
         }
         dt_tm["hh"] = substr(hhmmss,1,2) + 0;
         dt_tm["mm"] = substr(hhmmss,4,2) + 0;
         dt_tm["ss"] = substr(hhmmss,7,2) + 0;
         if (ampm == "PM" && dt_tm["hh"] < 12) {
            dt_tm["hh"] += 12;
         }
         dt_str = dt_beg["yy"] " " dt_beg["mm"] " " dt_beg["dd"] " " dt_tm["hh"] " " dt_tm["mm"] " " dt_tm["ss"];
         printf("%s dt_str= %s\n", script, dt_str) > "/dev/stderr";
         epoch = mktime(dt_str);
         printf("%s epoch= %s offset= %s, ts_beg= %s\n", script, epoch, offset, ts_beg) > "/dev/stderr";
         if (epoch_init == 0) {
             epoch_init = epoch;
         }
         epoch = ts_beg + (epoch - epoch_init);
         if ((epoch-ts_beg) < 0.0) {
            printf("%s epoch= %f, hhmmss= %s, dt_str= %s ts_beg= %f. epoch-ts_beg= %f ampm= %s bye\n", script, epoch, hhmmss, dt_str, ts_beg, epoch-ts_beg, ampm) > "/dev/stderr";
            exit;
         }
         return epoch;
      }
     /^Linux/{
        if (NR == 1) {
          for (i=NF; i > 0; i--) {
                printf("%s beg_line= %s\n", script, $0) > "/dev/stderr";
             if (match($i, /^[0-9][0-9]\/[0-9][0-9]\/[0-9][0-9][0-9][0-9]/)) {
                dt_beg["yy"] = substr($i, 7);
                dt_beg["mm"] = substr($i, 1, 2);
                dt_beg["dd"] = substr($i, 4, 2);
                printf("%s beg_date= mm.dd.yyyy %s.%s.%s\n", script, dt_beg["mm"], dt_beg["dd"], dt_beg["yy"]) > "/dev/stderr";
                #break;
             } else if (match($i, /^[0-9][0-9]\/[0-9][0-9]\/[0-9][0-9]/)) {
                dt_beg["yy"] = "20" substr($i, 7, 2);
                dt_beg["mm"] = substr($i, 1, 2);
                dt_beg["dd"] = substr($i, 4, 2);
                printf("%s beg_date= mm.dd.yyyy %s.%s.%s\n", script, dt_beg["mm"], dt_beg["dd"], dt_beg["yy"]) > "/dev/stderr";
                break;
             }
             if (i == NF && $i == "CPU)") {
                num_cpus = substr($(i-1), 2, length($(i-1)))+0;
                num_cpus_pct = num_cpus * 100.0;
                printf("%s num_cpus= %d\n", script, num_cpus) > "/dev/stderr";
             }
          }
        }
       next;
     }
     {
        FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
        if (NF==0) { next; }
     }
     /%idle/{
        if (beg == 1 && ($2 == "AM" || $2 == "PM")) {
           epoch = dt_to_epoch($1, $2);
           dt_fmt_has_am_pm = 1;
           hdr_col_off = 3;
           tm_beg = epoch;
        } else if (beg == 1 && $2 == "CPU") {
           epoch = dt_to_epoch($1, "AM");
           printf("%s beg_tm= %d, epoch= %d\n", beg, epoch, ts_beg) > "/dev/stderr";
           dt_fmt_has_am_pm = 0;
           hdr_col_off = 2;
           tm_beg = epoch;
        }
        if (beg == 0) { next; }
        beg = 0;
        for (i=hdr_col_off; i <= NF; i++) {
         hdrs[++hdr_mx]=$i;
        }
        next;
     }
     {
        if (dt_fmt_has_am_pm == 1) {
          grp=$3;
        } else {
          grp=$2;
        }
        if (index($0, "Average") == 1) {
          next;
        }
        if (dt_fmt_has_am_pm == 1 && ($2 == "AM" || $2 == "PM")) {
           epoch = dt_to_epoch($1, $2);
        }
        if (dt_fmt_has_am_pm == 0) {
           epoch = dt_to_epoch($1, "AM");
        }
        if (ts_end > 0.0 && epoch > ts_end) {
           next;
        }
        if (grps[grp] == "") {
          grps[grp] = ++grp_mx;
          grp_nm[grp_mx] = grp;
          printf("grps[%s]= %d\n", grp, grp_mx);
          grp_row[grp_mx] = 0;
        }
        g = grps[grp];
        rw = ++grp_row[g];
        tm_rw[rw] = epoch;
        j=0;
        i_beg = 3;
        if (dt_fmt_has_am_pm == 0) {
          i_beg = 2;
        }
        for (i=i_beg; i <= NF; i++) {
          grp_list[g,rw,++j] = $i;
        }
        grp_col[g] = j;
        
     }
     END{
        #printf("grp_mx= %d\n", grp_mx) > NFL;
        row=-1;
trows++; printf("This command prints CPU time breakdowns per CPU, which can be used to check for an imbalance. A\n") > NFL;
trows++; printf("single hot CPU can be evidence of a single-threaded application.\n") > NFL;
trows++; printf("\n") > NFL;

          #row++;
          #printf("title\tmpstat user %%cpu top-like\tsheet\tmpstat\ttype\tscatter_straight\n", grp_nm[g]) > NFL;
          #row++;
          #printf("hdrs\t%d\t%d\t%d\t%d\t1\n", trows+row+1, 2, -1, 2) > NFL;
          row++;
          printf("title\tmpstat user %%cpu top-like\tsheet\tmpstat\ttype\tline_stacked\n") > NFL;
          row++;
          printf("hdrs\t%d\t%d\t%d\t%d\t1\n", trows+row+1, 2, -1, grp_mx) > NFL;
          col_i = -1;
          col_u = -1;
          bckts_mx = 16;

          bckts = (grp_mx-1)/bckts_mx;
          if (((grp_mx-1) % bckts_mx) != 0) {
            printf("%s. ________+++++++++ dude, grp_mx-1= %d is not evenly divisible by %d, remainder= %d\n", script, grp_mx-1, bckts_mx, ((grp_mx-1) % bckts_mx)) > "/dev/stderr";
            exit 1
          }
          for (i=1; i <= bckts_mx; i++) { bckt_arr[i] = 0;}

          for (i=1; i <= hdr_mx; i++) {
            if (hdrs[i] == "%usr") { col_u = i; }
            if (hdrs[i] == "%idle") { col_i = i; }
          }
        #for (g=1; g <= grp_mx; g++) {
        #  if (got_skip_mpstat_percpu_charts > 0 && grp_nm[g] != "all") {
        #     continue;
        #  }
          tab="";
          printf("TS\tts_rel\t") > NFL;
          for (i=1; i <= grp_mx; i++) {
            n = grp_nm[i];
            if (n == "all") { continue;}
            printf("%s%s", tab, grp_nm[i]) > NFL;
            #printf("%s%s", tab, "%user cpu") > NFL;
            tab="\t";
          }
          row++;
          printf("\n") > NFL;
          for (r=1; r <= grp_row[1]; r++) {
            tab="";
            printf("%.3f\t%.4f\t", tm_rw[r], tm_rw[r]-ts_beg) > NFL;
            v = 0.0;
            tm_dff = (r > 1 ? tm_rw[r] - tm_rw[r-1] : tm_rw[r] - ts_beg);
            for (c=1; c <= grp_mx; c++) {
              n = grp_nm[c];
              if (n == "all") { continue;}
              v = grp_list[c,r,col_u];
              bckt = int(n/bckts) + 1;
              bckt_arr[bckt] += tm_dff * v/100.0;
              #bckt_arr[bckt] += v;
              printf("%s%.3f", tab, v) > NFL;
              tab="\t";
            }
            row++;
            printf("\n") > NFL;
          }
          row++;
          printf("\n") > NFL;
        #}
        row++;
        printf("\n") > NFL;

          tot_tm_dff = tm_rw[grp_row[1]] - ts_beg;
          row++;
          printf("title\tmpstat %% cpus_in_buckets_used histogram, bucktet size= %d cpus\tsheet\tmpstat\ttype\tcolumn\n", bckts) > NFL;
          row++;
          printf("hdrs\t%d\t%d\t%d\t%d\t-1\n", trows+row+1, 0, trows+row+2, 15) > NFL;
          tab="";
          for (i=1; i <= bckts_mx; i++) {
            j = (i-1)*bckts;
            k = i*bckts -1;
            printf("%s%d-%d", tab, j, k) > NFL;
            tab="\t";
          }
          row++;
          printf("\n") > NFL;
          tab="";
          for (i=1; i <= bckts_mx; i++) {
            printf("%s%.3f", tab, 100.0*bckt_arr[i]/(bckts*tot_tm_dff)) > NFL;
            tab="\t";
          }
          row++;
          printf("\n") > NFL;
          row++;
          printf("\n") > NFL;

        for (g=1; g <= grp_mx; g++) {
          if (got_skip_mpstat_percpu_charts > 0 && grp_nm[g] != "all") {
             continue;
          }
          row++;
          printf("title\tmpstat cpu= %s\tsheet\tmpstat\ttype\tscatter_straight\n", grp_nm[g]) > NFL;
          row++;
          printf("hdrs\t%d\t%d\t%d\t%d\t1\n", trows+row+1, 3, trows+1+row+grp_row[g], hdr_mx+1) > NFL;
          tab="";
          printf("TS\tts_rel\t") > NFL;
          col_i = -1;
          col_u = -1;
          sum_i = 0; #idle
          sum_u = 0; #user
          sum_n = 0;
          for (i=1; i <= hdr_mx; i++) {
            if (hdrs[i] == "%usr") { col_u = i; }
            if (hdrs[i] == "%idle") { col_i = i; }
            printf("%s%s", tab, hdrs[i]) > NFL;
            tab="\t";
          }
          row++;
          printf("\n") > NFL;
          for (r=1; r <= grp_row[g]; r++) {
            tab="";
            printf("%.3f\t%.4f\t", tm_rw[r], tm_rw[r]-ts_beg) > NFL;
            for (c=1; c <= hdr_mx; c++) {
              if (c == col_i) { sum_n++; sum_i += grp_list[g,r,c]; }
              if (c == col_u) {          sum_u += grp_list[g,r,c]; }
              printf("%s%s", tab, grp_list[g,r,c]) > NFL;
              tab="\t";
            }
            row++;
            printf("\n") > NFL;
          }
          row++;
          printf("\n") > NFL;
          if (sum_file != "") {
            v = sum_u/sum_n;
            printf("mpstat\tmpstat\t%s\tuser %%cpu %s\n", v, grp_nm[g]) >> sum_file;
            v = sum_i/sum_n;
            printf("mpstat\tmpstat\t%s\tidle %%cpu %s\n", v, grp_nm[g]) >> sum_file;
          }
        }
        close(NFL);
        if (sum_file != "") {
          close(sum_file);
        }
     }
   ' $i
   ck_last_rc $? $LINENO
   SHEETS="$SHEETS $i.tsv"
  fi
  if [[ $i == *"_pidstat.txt"* ]]; then
    echo "do pidstat"
#Average:      UID       PID    %usr %system  %guest    %CPU   CPU  Command
#Average:        0         1    0.32    0.37    0.00    0.68     -  systemd
#Average:        0         2    0.00    0.02    0.00    0.02     -  kthreadd
#Average:        0         8    0.00    0.05    0.00    0.05     -  ksoftirqd/0
#Average:        0         9    0.00    0.17    0.00    0.17     -  rcu_sched
#
#Average:      UID       PID   cswch/s nvcswch/s  Command
#Average:        0         1     11.16      0.00  systemd
#Average:        0         2      0.05      0.00  kthreadd
#
#Average:      UID       PID threads   fd-nr  Command
#Average:        0     38184      64      70  collector
#Average:      112     43282      17      80  muttley-active
#Average:    100001     51570      18     776  m3collector
#aaaa
    awk -v max_cpus=100 -v sum_file="$SUM_FILE" -v options="$OPTIONS" -v ts_beg="$BEG" -v ts_end="$END_TM" -v pfx="$PFX" -v typ="pidstat" '
     BEGIN{
        beg=1;
        grp_mx=0;
        hdr_mx=0;
        chart=typ;
        did_notes=0;
        tm_rw = 0;
        tm_beg += 0;
        tm_end += 0;
        epoch_init = 0;
        num_cpus = 0;
        num_cpus_pct = 0;
        tot_first=1;
        pidstat_dont_add_pid = 0;
        if (index(options, "pidstat_dont_add_pid") > 0) {
           pidstat_dont_add_pid = 1;
        }
      }
      function dt_to_epoch(hhmmss, ampm) {
         # the epoch seconds from the date time info in the file is local time,not UTC.
         # so just use the calc"d epoch seconds to calc the elapsed seconds since the start.
         # THe real timestamp is the input ts_beg + elapsed_seconds.
         # hhmmss fmt= hh:mm:ss (w leading 0
         if (dt_beg["yy"] == "") {
            return 0.0;
         }
         dt_tm["hh"] = substr(hhmmss,1,2) + 0;
         dt_tm["mm"] = substr(hhmmss,4,2) + 0;
         dt_tm["ss"] = substr(hhmmss,7,2) + 0;
         if (ampm == "PM" && dt_tm["hh"] < 12) {
            dt_tm["hh"] += 12;
         }
         dt_str = dt_beg["yy"] " " dt_beg["mm"] " " dt_beg["dd"] " " dt_tm["hh"] " " dt_tm["mm"] " " dt_tm["ss"];
         #printf("dt_str= %s\n", dt_str) > "/dev/stderr";
         epoch = mktime(dt_str);
         #printf("epoch= %s offset= %s\n", epoch, offset);
         if (epoch_init == 0) {
             epoch_init = epoch;
         }
         epoch = ts_beg + (epoch - epoch_init + 1); # the plus 1 assumes a 1 second interval.
         return epoch;
      }
      function sort_data(arr_in, arr_mx, mx_lines) {
       srt_lst="";
       for (i=1; i <= arr_mx; i++) {
           srt_lst=srt_lst "" arr_in[i] "\n";
       }
       cmd = "printf \"" srt_lst "\" | sort -t '\t' -r -n -k 1";
       #printf("cmd= %s\n", cmd);
       #printf("======== end cmd=========\n");
       nf_mx=0;
       while ( ( cmd | getline result ) > 0 ) {
         n = split(result, marr, "\t");
         sv_nf[++nf_mx] = marr[2];
         #printf("asv_nf[%d]= %s, m1= %s m2= %s\n", nf_mx, result, marr[1], marr[2]) > "/dev/stderr";
         if (nf_mx > mx_lines) {
           break;
         }
       } 
       close(cmd)
       return nf_mx;
      }
      function bar_data(row, arr_in, arr_mx, title, hdr, mx_lines) {
       srt_lst="";
       for (i=2; i <= arr_mx; i++) {
           srt_lst=srt_lst "" arr_in[i] "\n";
       }
       #printf("======== beg %s =========\n%s\n======== end %s =========\n", title, srt_lst, title);
       cmd = "printf \"" srt_lst "\" | sort -t '\t' -r -n -k 1";
       #printf("cmd= %s\n", cmd);
       #printf("======== end cmd=========\n");
       nf_mx=0;
       while ( ( cmd | getline result ) > 0 ) {
         sv_nf[++nf_mx] = result;
         printf("sv_nf[%d]= %s\n", nf_mx, result);
         if (nf_mx > mx_lines) {
           break;
         }
       } 
       close(cmd)
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tcolumn\n", title, chart) > NFL;
       ++row;
       n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", row+1, 0, row+1+nf_mx, n-1, 0) > NFL;
       ++row;
       printf("%s\n", hdr) > NFL;
       for (i=1; i <= nf_mx; i++) {
         ++row;
         n = split(sv_nf[i], arr, "\t");
         printf("%s", arr[n]) > NFL;
         for (j=1; j < n; j++) {
           printf("\t%s", arr[j]) > NFL;
         }
         printf("\n") > NFL;
       }
       return row;
     }
     {
	FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
        str="";
        tab="";
        for (i=1; i <= NF; i++) {
          str = str "" sprintf("%s%s", tab, $i);
          tab = "\t";
        }
        sv[++sv_mx] = str;
        if (NR == 1) {
          for (i=1; i <= NF; i++) {
             if (match($i, /^[0-9][0-9]\/[0-9][0-9]\/[0-9][0-9][0-9][0-9]/)) {
                dt_beg["yy"] = substr($i, 7);
                dt_beg["mm"] = substr($i, 1, 2);
                dt_beg["dd"] = substr($i, 4, 2);
                printf("beg_date= mm.dd.yyyy %s.%s.%s\n", dt_beg["mm"], dt_beg["dd"], dt_beg["yy"]) > "/dev/stderr";
                #break;
             }
             if (i == NF && $i == "CPU)") {
                num_cpus = substr(fld_prv, 2)+0;
                num_cpus_pct = num_cpus * 100.0;
             }
             fld_prv = $i;
          }
          next;
        }
        if (NF == 0) {
           area="cpu";
           next;
        }
        if ($2 == "AM" || $2 == "PM") {
           if (index($0, "%CPU") > 1) {
              area="cpu";
              epoch = dt_to_epoch($1, $2);
              tm_rw = tm_rw+1;
              tm_arr[tm_rw] = epoch;
              next;
           }
           if (index($0, " kB_rd/s ") > 1) {
              area="io";
              epoch = dt_to_epoch($1, $2);
              tm_rw_io = tm_rw_io+1;
              tm_arr_io[tm_rw_io] = epoch;
              next;
           }
           if (ts_end > 0.0 && epoch > ts_end) {
              next;
           }
           if ( area == "cpu" && $1 != "Average:") {
             if (pidstat_dont_add_pid == 0) {
               nm  = $10 " " $4; # process_name + pid
             } else {
               nm  = $10; # process_name 
             }
             i = index(nm, "/");
             if (i > 0) {
               nm = substr(nm, 1, i-1);
             }
             if (!(nm in nm_arr)) {
               if (tot_first == 1) {
                 tot_first = 0;
                 nmt = "__tot__";
                 nm_idx++
                 nm_arr[nmt] = nm_idx;
                 nm_lkup[nm_idx] = nmt;
                 nm_tot[nm_idx] = 0;
                 nm_tot_io[nm_idx] = 0;
               }
               nm_idx++
               nm_arr[nm] = nm_idx;
               nm_lkup[nm_idx] = nm;
               nm_tot[nm_idx] = 0;
             }
             nmi = nm_arr[nm];
             pct = $8+0; # %cpu
             if (pct > num_cpus_pct) {
               pct = 0.0; # just set it zero
               ## it is misleading to set it to 0 as it makes me think the process is blocked and not running in this interval.
               ## The numbers "look like" they could be 1000x too big...this is a real hack
               #npct = pct * 0.001;
               #if (npct > num_cpus_pct) { npct = 0.0; }
               #printf("pidstat: trying to fixup too high %CPU: pct= %f num_cpus_pct= %f, npct= %f, tm_rw= %d, i= %d, pid[%d,%s]= %s, nm= %s\n", pct, num_cpus_pct, npct, tm_rw, i, i,nmi, pid[i,nmi], nm) > "/dev/stderr";
               #pct = npct;
             }
             pid[tm_rw,nmi] = pct;
             nm_tot[nmi] += pct;
           }
           if ( area == "io" && $1 != "Average:") {
             #nm  = $9 " " $4; # process_name + pid
             if (pidstat_dont_add_pid == 0) {
               nm  = $9 " " $4; # process_name + pid
             } else {
               nm  = $9; # process_name 
             }
             i = index(nm, "/");
             if (i > 0) {
               nm = substr(nm, 1, i-1);
             }
             if (!(nm in nm_arr)) {
               if (tot_first == 1) {
                 tot_first = 0;
                 nmt = "__tot__";
                 nm_idx++
                 nm_arr[nmt] = nm_idx;
                 nm_lkup[nm_idx] = nmt;
                 nm_tot[nm_idx] = 0;
                 nm_tot_io[nm_idx] = 0;
               }
               nm_idx++
               nm_arr[nm] = nm_idx;
               nm_lkup[nm_idx] = nm;
               nm_tot_io[nm_idx] = 0;
             }
             nmi = nm_arr[nm];
             kbr = $5+0; # kBread/s
             kbw = $6+0; # kBwrite/s
             if ((kbr + kbw) < 20.0e6) { # pidstat has some bogus numbers at times
             pid_io[tm_rw_io,nmi,"rd"] = kbr;
             pid_io[tm_rw_io,nmi,"wr"] = kbw;
             nm_tot_io[nmi] += kbr+kbw;
             nmi = nm_arr[nmt];
             pid_io[tm_rw_io,nmi,"rd"] += kbr;
             pid_io[tm_rw_io,nmi,"wr"] += kbw;
             nm_tot_io[nmi] += kbr+kbw;
             }
           }
        }
     }
     /^Average:/{
        if (index($0, "%CPU") > 1) {
          area="cpu"; 
          mx_cpu=1;
          sv_cpu[mx_cpu]=sprintf("%CPU\tProcess");
          next;
        }
        if (index($0, "nvcswch") > 1) {
          area="cs";
          mx_cs=1;
          sv_cs[mx_cs]=sprintf("cswch/s\tnvcswch/s\tProcess");
          next;
        }
        if (index($0, "threads") > 1) {
          area="threads";
          mx_threads=1;
          sv_threads[mx_threads]=sprintf("threads\tfd-nr\tProcess");
          next;
        }
        if (area == "cpu") {
          proc = $9;
          i = index(proc, "/");
          if (i > 0) {
             proc = substr(proc, 1, i-1);
          }
          if (!(proc in proc_list)) {
             proc_list[proc] = ++proc_mx;
             proc_lkup[proc_mx] = proc;
             proc_tot[proc_mx] = 0.0;
          }
          pct = $7+0.0;
          if (pct > num_cpus_pct) {
             pct = 0.0; # just set it zero
          }
          if (pidstat_dont_add_pid == 0) {
            sv_cpu[++mx_cpu]=sprintf("%s\t%s", pct, $9 " " $3);
          } else {
            proc_idx = proc_list[proc];
            proc_tot[proc_idx] += pct;
            sv_cpu[proc_idx]=sprintf("%s\t%s", proc_tot[proc_idx], proc);
            if (mx_cpu < proc_idx) {
               mx_cpu = proc_idx;
            }
          }
        }
        if (area == "cs") {
          if (pidstat_dont_add_pid == 0) {
            sv_cs[++mx_cs]=sprintf("%s\t%s\t%s", $4, $5, $6 " " $3);
          } else {
            sv_cs[++mx_cs]=sprintf("%s\t%s\t%s", $4, $5, $6);
          }
        }
        if (area == "threads") {
          if (pidstat_dont_add_pid == 0) {
            sv_threads[++mx_threads]=sprintf("%s\t%s\t%s", $4, $5, $6 " " $3);
          } else {
            sv_threads[++mx_threads]=sprintf("%s\t%s\t%s", $4, $5, $6);
          }
        }
        next;
     }
     END{
       row = -1;

trows++; printf("\tpidstat is a little like top\x27s per-process summary, but prints a rolling summary instead of clearing the screen.\n") > NFL;
trows++; printf("\tThis can be useful for watching patterns over time, and also recording what you saw (copy-n-paste) into a\n") > NFL;
trows++; printf("\trecord of your investigation.\n") > NFL;
trows++; printf("\tThe above example identifies two java processes as responsible for consuming CPU. The %%CPU column is\n") > NFL;
trows++; printf("\tthe total across all CPUs; 1591%% shows that that java processes is consuming almost 16 CPUs.\n") > NFL;

       row += trows;
       for (k=1; k <= nm_idx; k++) {
          my_cpu[k]=sprintf("%d\t%s", nm_tot[k], nm_lkup[k]);
       }
       my_nms = sort_data(my_cpu, nm_idx, 20);
       for (k=1; k <= my_nms; k++) {
         my_order[k] = sv_nf[k];
       }
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "pid_stat %CPU by proc", "pat") > NFL;
       ++row;
       #n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", row+1, 2, -1, my_nms+1, 1) > NFL;
       ++row;
       printf("TS\trel_t") > NFL;
       for (k=1; k <= my_nms; k++) {
          printf("\t%s", my_order[k]) > NFL;
       }
       printf("\n") > NFL;
       for (j=1; j <= tm_rw; j++) {
          printf("%d\t%d", tm_arr[j], tm_arr[j]-ts_beg) > NFL;
          for (k=1; k <= my_nms; k++) {
             nmi = nm_arr[my_order[k]];
             printf("\t%d", pid[j,nmi]) > NFL;
          }
          ++row;
         printf("\n") > NFL;
       }
       ++row;
       printf("\n") > NFL;

       # IO segment
       for (k=1; k <= nm_idx; k++) {
          my_cpu[k]=sprintf("%f\t%s", nm_tot_io[k], nm_lkup[k]);
          #printf("my_cpu[%d]= %s\n", k, my_cpu[k]) > "/dev/stderr";
       }
       my_nms = sort_data(my_cpu, nm_idx, 20);
       for (k=1; k <= my_nms; k++) {
         my_order[k] = sv_nf[k];
       }
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "pid_stat IO (MB/s) by proc. Proc IO might not get to disk", "pat") > NFL;
       ++row;
       #n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", row+1, 2, -1, my_nms+1, 1) > NFL;
       ++row;
       printf("TS\trel_t") > NFL;
       for (k=1; k <= my_nms; k++) {
          printf("\t%s", my_order[k]) > NFL;
       }
       printf("\n") > NFL;
       for (j=1; j <= tm_rw_io; j++) {
          printf("%d\t%d", tm_arr_io[j], tm_arr_io[j]-ts_beg) > NFL;
          for (k=1; k <= my_nms; k++) {
             nmi = nm_arr[my_order[k]];
             printf("\t%f", (pid_io[j,nmi,"rd"]+pid_io[j,nmi,"wr"])/1024.0) > NFL;
          }
          ++row;
         printf("\n") > NFL;
       }
       ++row;
       printf("\n") > NFL;

       row = bar_data(row, sv_cpu, mx_cpu, chart " average %CPU", "process\tavg.%CPUS", 40);
       for (i=1; i <= nf_mx; i++) {
         n = split(sv_nf[i], arr, "\t");
         printf("pidstat\tavg %%cpu\t%s\t%%cpu %s\n", arr[1], arr[2]) >> sum_file;
       }
       close(sum_file);
       ++row;
       printf("\n") > NFL;
       if (mx_cs > 0) {
         row = bar_data(row, sv_cs, mx_cs, chart " CSWTCH", sv_cs[1], 40);
         ++row;
         printf("\n") > NFL;
       }
       if (mx_threads > 0) {
         row = bar_data(row, sv_threads, mx_threads, chart " threads, fd", sv_threads[1], 40);
         ++row;
         printf("\n") > NFL;
       }
       if (verbose > 0) {
        # print the data
        for (i=1; i <= sv_mx; i++) {
          printf("%s\n", sv[i]) > NFL;
        }
       }
       close(NFL);
       #printf("%f\n", 1.0/0.0);  # cause an awk exception to test error handling
     }
   ' $i
   ck_last_rc $? $LINENO
   SHEETS="$SHEETS $i.tsv"
 fi
  if [[ $i == *"_iostat.txt"* ]]; then
#avg-cpu:  %user   %nice %system %iowait  %steal   %idle
#           1.32    3.52    0.76    0.16    0.00   94.24
#
#Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
#sda               0.00     0.00  567.00    0.00  7100.00     0.00    25.04     0.06    0.11    0.11    0.00   0.11   6.00
#dm-0              0.00     0.00  567.00    0.00  7100.00     0.00    25.04     0.06    0.11    0.11    0.00   0.11   6.40

#rkB/s	wkB/s	avgrq-sz	avgqu-sz	await	r_await	w_await	svctm	%util

    echo "do iostat"
    awk -v ts_beg="$BEG" -v ts_end="$END_TM" -v pfx="$PFX" -v typ="iostat"  -v sum_file="$SUM_FILE" -v sum_flds="rkB/s{io RdkB/s|disk},wkB/s{io wrkB/s|disk},avgrq-sz{io avg Req_sz|disk},avgqu-sz{io avg que_sz|disk},%util{io %util|disk}" '
     BEGIN{
        beg=1;
        grp_mx=0;
        hdr_mx=0;
        chart=typ;
        mx_cpu=0;
        mx_io=0;
        mx_dev=0;
        tm_beg = 0;
        ts_beg += 0;
        ts_end += 0;
        epoch_init = 0;
        n_sum = 0;
       if (sum_file != "" && sum_flds != "") {
         n_sum = split(sum_flds, sum_arr, ",");
         for (i_sum=1; i_sum <= n_sum; i_sum++) {
            sum_type[i_sum] = 0;
            str = sum_arr[i_sum];
            pos = index(str, "{");
            if (pos > 0) {
               pos1 = index(str, "}");
               if (pos1 == 0) { pos1= length(str)+1; }
               sum_str = substr(str, pos+1, pos1-pos-1);
               n_sum2 = split(sum_str, sum_arr2, "|");
               if (sum_arr2[1] != "") {
                 sum_prt[i_sum] = sum_arr2[1];
               } else {
                 #sum_prt[i_sum] = str;
                 sum_prt[i_sum] = substr(str, 1, pos-1);
               }
               if (sum_arr2[2] != "") {
                 sum_res[i_sum] = sum_arr2[2];
               }
               #sum_prt[i_sum] = substr(str, pos+1, pos1-pos-1);
               sum_arr[i_sum] = substr(str, 1, pos-1);
            } else {
               sum_prt[i_sum] = str;
            }
            if (index(tolower(str), "/s") > 0) {
               sum_type[i_sum] = 1;
            }
         }
       }
      }
      function dt_to_epoch(hhmmss, ampm) {
         # the epoch seconds from the date time info in the file is local time,not UTC.
         # so just use the calc"d epoch seconds to calc the elapsed seconds since the start.
         # THe real timestamp is the input ts_beg + elapsed_seconds.
         # hhmmss fmt= hh:mm:ss (w leading 0
         if (dt_beg["yy"] == "") {
            return 0.0;
         }
         dt_tm["hh"] = substr(hhmmss,1,2) + 0;
         dt_tm["mm"] = substr(hhmmss,4,2) + 0;
         dt_tm["ss"] = substr(hhmmss,7,2) + 0;
         if (ampm == "PM" && dt_tm["hh"] < 12) {
            dt_tm["hh"] += 12;
         }
         dt_str = dt_beg["yy"] " " dt_beg["mm"] " " dt_beg["dd"] " " dt_tm["hh"] " " dt_tm["mm"] " " dt_tm["ss"];
         #printf("dt_str= %s\n", dt_str) > "/dev/stderr";
         epoch = mktime(dt_str);
         #printf("epoch= %s offset= %s\n", epoch, offset);
         if (epoch_init == 0) {
             epoch_init = epoch;
         }
         epoch = ts_beg + (epoch - epoch_init + 1); # the plus 1 assumes a 1 second interval.
         return epoch;
      }
      function line_data(row, arr_in, arr_mx, title, hdr, mytarr) {
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", title, chart) > NFL;
       ++row;
       n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\t1\n", row+1, 2, row+arr_mx, n+1) > NFL;
       ++row;
       printf("TS\tts_rel\t%s\n", hdr) > NFL;
       for (i=2; i <= arr_mx; i++) {
         ++row;
         printf("%.3f\t%.4f\t%s\n", mytarr[i], mytarr[i]-ts_beg, arr_in[i]) > NFL;
       }
       return row;
     }
     {
        FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
     }
     #02/28/2020 10:34:37 PM
     / AM$| PM$/{
         dt_beg["yy"] = substr($1, 7, 4);
         dt_beg["mm"] = substr($1, 1, 2);
         dt_beg["dd"] = substr($1, 4, 2);
         epoch = dt_to_epoch($2, $3);
         if (ts_end > 0.0 && epoch > ts_end) {
              exit;
         }
         if (tm_beg == 0) {
           tm_beg = epoch;
         }
         #  printf("iostat beg_date= mm.dd.yyyy %s.%s.%s, epoch= %f\n", dt_beg["mm"], dt_beg["dd"], dt_beg["yy"], epoch) > "/dev/stderr";
     }

     /^avg-cpu:/{
        if (mx_cpu == 0) {
          mx_cpu=1;
          sv_cpu[mx_cpu]="";
          sv_cpu_cols = NF-1;
          tab=""
          for (i=2; i <= NF; i++) {
            sv_cpu[mx_cpu]=sv_cpu[mx_cpu] "" tab "" $i;
            tab="\t"
          }
        }
        area="cpu"; 
        hdr_NR=NR;
        next;
     }
     /^Device:/{
        if (mx_io == 0) {
          mx_io=1;
          sv_io[mx_io]="";
          sv_io_cols = NF;
          tab = "";
          for (i=1; i <= NF; i++) {
            sv_io[mx_io]=sv_io[mx_io] "" tab "" $i;
            tab="\t"
          }
        }
        area="io"; 
        delete got_dev;
        hdr_NR=NR;
        next;
     }
     {
        if (NF == 0) {
          if (area == "io") {
            # insert zeroes for missing dev
            for (i=1; i <= mx_dev; i++) {
               if (got_dev[i] == 1) { continue; }
               ++mx_io;
               sv_io[mx_io]=dev_lst[i];
               sv_io_tm[mx_io]=epoch;
               sv_io_dev_ids[mx_io] = dev_lst[i];
               for (j=2; j <= sv_io_cols; j++) {
                 sv_io[mx_io]=sv_io[mx_io] "\t0.0";
               }
            }
          }
          area = "";
          next;
        }
        str="";
        tab="";
        for (i=1; i <= NF; i++) {
          str = str "" sprintf("%s%s", tab, $i);
          tab = "\t";
        }
        if (area == "cpu") {
           sv_cpu[++mx_cpu] = str;
           sv_cpu_tm[mx_cpu] = epoch;
        }
        if (area == "io") {
           if (!($1 in sv_dev)) {
             ++mx_dev;
             dev_lst[mx_dev]=$1;
             sv_dev[$1]=mx_dev;
             printf("dev_lst[%d]= %s\n", mx_dev, $1);
           }
           dev_id = sv_dev[$1];
           got_dev[dev_id] = 1;
           sv_io[++mx_io] = str;
           sv_io_tm[mx_io] = epoch;
           sv_io_dev_ids[mx_io] = $1;
        }
        sv[++sv_mx] = str;
        sv_tm[sv_mx] = epoch;
        next;
     }
     END{
       row = -1;
trows++; printf("\tThis is a great tool for understanding block devices (disks), both the workload applied and the resulting\n") > NFL;
trows++; printf("\tperformance. Look for:\n") > NFL;
trows++; printf("\tr/s, w/s, rkB/s, wkB/s: These are the delivered reads, writes, read Kbytes, and write Kbytes per\n") > NFL;
trows++; printf("\tsecond to the device. Use these for workload characterization. A performance problem may\n") > NFL;
trows++; printf("\tsimply be due to an excessive load applied.\n") > NFL;
trows++; printf("\tawait: The average time for the I/O in milliseconds. This is the time that the application suffers,\n") > NFL;
trows++; printf("\tas it includes both time queued and time being serviced. Larger than expected average times can\n") > NFL;
trows++; printf("\tbe an indicator of device saturation, or device problems.\n") > NFL;
trows++; printf("\tavgqu-sz: The average number of requests issued to the device. Values greater than 1 can be\n") > NFL;
trows++; printf("\tevidence of saturation (although devices can typically operate on requests in parallel, especially\n") > NFL;
trows++; printf("\tvirtual devices which front multiple back-end disks.)\n") > NFL;
trows++; printf("\t%%util: Device utilization. This is really a busy percent, showing the time each second that the\n") > NFL;
trows++; printf("\tdevice was doing work. Values greater than 60%% typically lead to poor performance (which\n") > NFL;
trows++; printf("\tshould be seen in await), although it depends on the device. Values close to 100%% usually\n") > NFL;
trows++; printf("\tindicate saturation.\n") > NFL;
trows++; printf("\tIf the storage device is a logical disk device fronting many back-end disks, then 100%% utilization may just\n") > NFL;
trows++; printf("\tmean that some I/O is being processed 100%% of the time, however, the back-end disks may be far from\n") > NFL;
trows++; printf("\tsaturated, and may be able to handle much more work.\n") > NFL;
trows++; printf("\tBear in mind that poor performing disk I/O isn\x27t necessarily an application issue. Many techniques are\n") > NFL;
trows++; printf("\ttypically used to perform I/O asynchronously, so that the application doesn\x27t block and suffer the latency\n") > NFL;
trows++; printf("\tdirectly (e.g., read-ahead for reads, and buffering for writes).\n") > NFL;
row += trows;
       row = line_data(row, sv_cpu, mx_cpu, chart " %CPU", sv_cpu[1], sv_cpu_tm);
       ++row;
       printf("\n") > NFL;
       if (mx_dev > 0 && n_sum > 0) {
         n = split(sv_io[1], hdr_arr, "\t");
         for (i=1; i <= n; i++) {
           for (i_sum=1; i_sum <= n_sum; i_sum++) {
               if (hdr_arr[i] == sum_arr[i_sum]) {
                  sum_lkup[i_sum] = i;
               }
           }
         }
       }
       for (ii=1; ii <= mx_dev; ii++) {
          ttl=chart " dev " dev_lst[ii];
          delete narr;
          delete tarr;
          narr[1] = sv_io[1];
          tarr[1] = sv_io_tm[1];
          mx_arr=1;
          for (jj=2; jj <= mx_io; jj++) {
             if (sv_io_dev_ids[jj] == dev_lst[ii]) {
                narr[++mx_arr] = sv_io[jj];
                tarr[mx_arr] = sv_io_tm[jj];
                if (n_sum > 0) {
                  n = split(sv_io[jj], tst_arr, "\t");
                  for (i_sum=1; i_sum <= n_sum; i_sum++) {
                    j = sum_lkup[i_sum];
                    sum_occ[i_sum] += 1;
                    if (sum_type[i_sum] == 1) {
                      if (sum_tmin[i_sum] == 0) { sum_tmin[i_sum] = sv_io_tm[jj]; sum_tmax[i_sum] = sv_io_tm[jj]; }
                      if (sum_tmax[i_sum] < sv_io_tm[jj]) { sum_tmax[i_sum] = sv_io_tm[jj]; }
                      if (jj > 2) { intrvl = sv_io_tm[jj] - sv_io_tm[jj-1];} else { intrvl = 1.0; } # a hack for jj=2;
                      sum_tot[i_sum] += tst_arr[j] * intrvl;
                    } else {
                      sum_tot[i_sum] += tst_arr[j];
                    }
                  }
                }
             }
          }
          row = line_data(row, narr, mx_arr, ttl, narr[1], tarr);
          ++row;
          printf("\n") > NFL;
       }
       #row = bar_data(row, sv_threads, mx_threads, chart " threads, fd", sv_threads[1], 40);
       #++row;
       #printf("\n") > NFL;
       for (i=1; i <= sv_mx; i++) {
          printf("%s\n", sv[i]) > NFL;
       }
       close(NFL);
       if (n_sum > 0) {
          printf("got iostat n_sum= %d\n", n_sum) >> "/dev/stderr";
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
             divi = sum_occ[i_sum];
             if (sum_type[i_sum] == 1) {
                divi = sum_tmax[i_sum] - sum_tmin[i_sum];
             }
             ky = sum_prt[i_sum];
             vl = (divi > 0 ? sum_tot[i_sum]/divi : 0.0);
             printf("%s\t%s\t%f\t%s\n", sum_res[i_sum], "iostat", vl, ky) >> sum_file;
          }
       }
     }
   ' $i
   ck_last_rc $? $LINENO
   SHEETS="$SHEETS $i.tsv"
 fi
  if [[ $i == *"_sar_dev.txt"* ]]; then
#12:04:59 AM     IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil
#12:05:00 AM      eth1      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
#12:05:00 AM   docker0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
#12:05:00 AM      ifb1      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
#12:05:00 AM      eth0   1047.00   1666.00     87.55   1278.60      0.00      0.00      0.00      0.30
#12:05:00 AM        lo   1251.00   1251.00    259.82    259.82      0.00      0.00      0.00      0.00
#12:05:00 AM      ifb0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
    echo "do sar_dev"
    awk -v ts_beg="$BEG" -v ts_end="$END_TM" -v pfx="$PFX" -v typ="sar network IFACE"  -v sum_file="$SUM_FILE" -v sum_flds="rxkB/s{net rdKB/s|network},txkB/s{net wrKB/s|network},%ifutil{net %util|network}" '
     BEGIN{beg=1;
        grp_mx=0;
        hdr_mx=0;
        chart=typ;
        ts_beg += 0.0;
        ts_end += 0.0;
        mx_cpu=0;
        mx_io=0;
        mx_dev=0;
        epoch_init = 0;
        n_sum = 0;
       if (sum_file != "" && sum_flds != "") {
         n_sum = split(sum_flds, sum_arr, ",");
         for (i_sum=1; i_sum <= n_sum; i_sum++) {
            sum_type[i_sum] = 0;
            str = sum_arr[i_sum];
            pos = index(str, "{");
            if (pos > 0) {
               pos1 = index(str, "}");
               if (pos1 == 0) { pos1= length(str)+1; }
               sum_str = substr(str, pos+1, pos1-pos-1);
               n_sum2 = split(sum_str, sum_arr2, "|");
               if (sum_arr2[1] != "") {
                 sum_prt[i_sum] = sum_arr2[1];
               } else {
                 #sum_prt[i_sum] = str;
                 sum_prt[i_sum] = substr(str, 1, pos-1);
               }
               if (sum_arr2[2] != "") {
                 sum_res[i_sum] = sum_arr2[2];
               }
               #sum_prt[i_sum] = substr(str, pos+1, pos1-pos-1);
               sum_arr[i_sum] = substr(str, 1, pos-1);
            } else {
               sum_prt[i_sum] = str;
            }
            if (index(tolower(str), "/s") > 0) {
               sum_type[i_sum] = 1;
            }
         }
       }
      }
      function dt_to_epoch(hhmmss, ampm) {
         # the epoch seconds from the date time info in the file is local time,not UTC.
         # so just use the calc"d epoch seconds to calc the elapsed seconds since the start.
         # THe real timestamp is the input ts_beg + elapsed_seconds.
         # hhmmss fmt= hh:mm:ss (w leading 0
         if (dt_beg["yy"] == "") {
            return 0.0;
         }
         dt_tm["hh"] = substr(hhmmss,1,2) + 0;
         dt_tm["mm"] = substr(hhmmss,4,2) + 0;
         dt_tm["ss"] = substr(hhmmss,7,2) + 0;
         if (ampm == "PM" && dt_tm["hh"] < 12) {
            dt_tm["hh"] += 12;
         }
         dt_str = dt_beg["yy"] " " dt_beg["mm"] " " dt_beg["dd"] " " dt_tm["hh"] " " dt_tm["mm"] " " dt_tm["ss"];
         #printf("dt_str= %s\n", dt_str) > "/dev/stderr";
         epoch = mktime(dt_str);
         #printf("epoch= %s offset= %s\n", epoch, offset);
         if (epoch_init == 0) {
             epoch_init = epoch;
         }
         epoch = ts_beg + (epoch - epoch_init + 1); # the plus 1 assumes a 1 second interval.
         return epoch;
      }

      function line_data(row, arr_in, arr_mx, title, hdr, tmarr_in, dev_str) {
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", title, chart) > NFL;
       ++row;
       n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", row+1, 3, row+arr_mx, n+1, 1) > NFL;
       ++row;
       if (n_sum > 0) {
         nk = split(hdr, hdr_arr, "\t");
         for (ik=1; ik <= nk; ik++) {
           for (i_sum=1; i_sum <= n_sum; i_sum++) {
               if (hdr_arr[ik] == sum_arr[i_sum]) {
                  sum_lkup[i_sum] = ik;
               }
           }
         }
       }
       printf("TS\tts_offset\t%s\n", hdr) > NFL;
       for (i=2; i <= arr_mx; i++) {
         ++row;
         printf("%d\t%d\t%s\n", tmarr_in[i], tmarr_in[i]-ts_beg, arr_in[i]) > NFL;
                if (n_sum > 0) {
                  n = split(arr_in[i], tst_arr, "\t");
                  for (i_sum=1; i_sum <= n_sum; i_sum++) {
                    j = sum_lkup[i_sum];
                    sum_occ[i_sum] += 1;
                    if (sum_type[i_sum] == 1) {
                      if (sum_tmin[i_sum] == 0) { sum_tmin[i_sum] = tmarr_in[i]; sum_tmax[i_sum] = tmarr_in[i]; }
                      if (sum_tmax[i_sum] < tmarr_in[i]) { sum_tmax[i_sum] = tmarr_in[i]; }
                      if (i > 2) { intrvl = tmarr_in[i] - tmarr_in[i-1];} else { intrvl = 1.0; } # a hack for jj=2;
                      sum_tot[i_sum] += tst_arr[j] * intrvl;
                    } else {
                      sum_tot[i_sum] += tst_arr[j];
                    }
                  }
                }
       }
       if (n_sum > 0) {
          printf("got sum net IFACE n_sum= %d\n", n_sum) >> "/dev/stderr";
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
             divi = sum_occ[i_sum];
             if (sum_type[i_sum] == 1) {
                divi = sum_tmax[i_sum] - sum_tmin[i_sum];
             }
             if (dev_str != "lo") {
             ky = sum_prt[i_sum];
             vl = (divi > 0 ? sum_tot[i_sum]/divi : 0.0);
             printf("%s\t%s %s\t%f\t%s\n", sum_res[i_sum], "sar_net", dev_str, vl, ky) >> sum_file;
             }
          }
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
             sum_occ[i_sum] = 0;
             if (sum_type[i_sum] == 1) {
                sum_tmax[i_sum] = 0;
                sum_tmax[i_sum] = 0;
                sum_tot[i_sum] = 0;
             }
          }
       }
       return row;
     }
     {
        FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
        if (NR == 1) {
          for (i=1; i <= NF; i++) {
             if (match($i, /^[0-9][0-9]\/[0-9][0-9]\/[0-9][0-9][0-9][0-9]/)) {
                dt_beg["yy"] = substr($i, 7);
                dt_beg["mm"] = substr($i, 1, 2);
                dt_beg["dd"] = substr($i, 4, 2);
                printf("beg_date= mm.dd.yyyy %s.%s.%s\n", dt_beg["mm"], dt_beg["dd"], dt_beg["yy"]) > "/dev/stderr";
                break;
             }
          }
          next;
        }
     }
     /^Average:/ {
        # could make a bar chart of this but...
        next;
     }
     / rxpck\/s /{
        # 01:08:50 AM
        #printf("epoch= %d\n", epoch) > "/dev/stderr";
        if (mx_io == 0) {
          mx_io=1;
          sv_io[mx_io]="";
          sv_io_cols = NF-2;
          tab = "";
          for (i=3; i <= NF; i++) {
            sv_io[mx_io]=sv_io[mx_io] "" tab "" $i;
            tab="\t"
          }
        }
        area="io"; 
        delete got_dev;
        hdr_NR=NR;
        next;
     }
     {
        if (NF == 0) {
          area = "";
          next;
        }
        str="";
        tab="";
        epoch = dt_to_epoch($1, $2);
        if (ts_end > 0.0 && epoch > ts_end) {
          exit;
        }
        got_nonzero = 0;
        for (i=3; i <= NF; i++) {
          str = str "" sprintf("%s%s", tab, $i);
          if (($i+0.0) > 0.0) {
             got_nonzero = 1;
          }
          tab = "\t";
        }
        if (area == "io") {
           if (!($3 in sv_dev)) {
             ++mx_dev;
             dev_lst[mx_dev]=$3;
             sv_dev[$3]=mx_dev;
             printf("dev_lst[%d]= %s\n", mx_dev, $3);
             io_nonzero[mx_dev] = 0;
           }
           dev_id = sv_dev[$3];
           got_dev[dev_id] = 1;
           if (io_nonzero[dev_id] == 0 && got_nonzero == 1) {
              io_nonzero[dev_id] = 1;
           }
           sv_io[++mx_io] = str;
           sv_tm[mx_io] = epoch;
           sv_io_dev_ids[mx_io] = $3;
        }
        sv[++sv_mx] = str;
        next;
     }
     END{
       row = -1;
trows++; printf("\tUse this tool to check network interface throughput: rxkB/s and txkB/s, as a measure of workload, and also\n") > NFL;
trows++; printf("\tto check if any limit has been reached. In the above example, eth0 receive is reaching 22 Mbytes/s, which is\n") > NFL;
trows++; printf("\t176 Mbits/sec (well under, say, a 1 Gbit/sec limit).\n") > NFL;
trows++; printf("\tThis version also has %%ifutil for device utilization (max of both directions for full duplex), which is something\n") > NFL;
trows++; printf("\twe also use Brendan\x27s nicstat tool to measure. And like with nicstat, this is hard to get right, and seems to\n") > NFL;
trows++; printf("\tnot be working in this example (0.00).\n") > NFL;
trows++; printf("\t\n") > NFL;
row+= trows;
       for (ii=1; ii <= mx_dev; ii++) {
          if (io_nonzero[ii] == 0) {
             ++row;
             printf("data for sar_dev IFACE %s is all zeroes.\n", dev_lst[ii]) > NFL;
             ++row;
             printf("\n") > NFL;
             continue;
          }
          ttl=chart " dev " dev_lst[ii];
          delete narr;
          narr[1] = sv_io[1];
          mx_arr=1;
          for (jj=2; jj <= mx_io; jj++) {
             if (sv_io_dev_ids[jj] == dev_lst[ii]) {
                narr[++mx_arr] = sv_io[jj];
                tmarr[mx_arr] = sv_tm[jj];
             }
          }
          row = line_data(row, narr, mx_arr, ttl, narr[1], tmarr, dev_lst[ii]);
          ++row;
          printf("\n") > NFL;
       }
       for (i=1; i <= sv_mx; i++) {
          printf("%s\n", sv[i]) > NFL;
       }
       close(NFL);
     }
   ' $i
   ck_last_rc $? $LINENO
   SHEETS="$SHEETS $i.tsv"
 fi
  if [[ $i == *"_sar_tcp.txt"* ]]; then
    echo "do sar_tcp"
    awk -v ts_beg="$BEG"  -v ts_end="$END_TM" -v pfx="$PFX" -v typ="sar tcp stats" '
     BEGIN{beg=1;
        grp_mx=0;
        hdr_mx=0;
        chart=typ;
        mx_cpu=0;
        mx_io=0;
        mx_io1=0;
        mx_dev=0;
        epoch_init = 0;
        ts_beg += 0;
        ts_end += 0;
      }
      function dt_to_epoch(hhmmss, ampm, all) {
         # the epoch seconds from the date time info in the file is local time,not UTC.
         # so just use the calc"d epoch seconds to calc the elapsed seconds since the start.
         # THe real timestamp is the input ts_beg + elapsed_seconds.
         # hhmmss fmt= hh:mm:ss (w leading 0
         if (dt_beg["yy"] == "") {
            return 0.0;
         }
         dt_tm["hh"] = substr(hhmmss,1,2) + 0;
         dt_tm["mm"] = substr(hhmmss,4,2) + 0;
         dt_tm["ss"] = substr(hhmmss,7,2) + 0;
         if (ampm == "PM" && dt_tm["hh"] < 12) {
            dt_tm["hh"] += 12;
         }
         dt_str = dt_beg["yy"] " " dt_beg["mm"] " " dt_beg["dd"] " " dt_tm["hh"] " " dt_tm["mm"] " " dt_tm["ss"];
         #printf("dt_str= %s\n", dt_str) > "/dev/stderr";
         epoch = mktime(dt_str);
         #printf("epoch= %s offset= %s\n", epoch, offset);
         if (epoch_init == 0) {
             printf("dt_str= %s, all= %s\n", dt_str, all) > "/dev/stderr";
             epoch_init = epoch;
         }
         epoch = ts_beg + (epoch - epoch_init + 1); # the plus 1 assumes a 1 second interval.
         return epoch;
      }
      function line_data(row, arr_in, arr_mx, title, hdr) {
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", title, chart) > NFL;
       ++row;
       n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", row+1, 2, row+arr_mx, n+1, 1) > NFL;
       ++row;
       printf("TS\tts_rel\t%s\n", hdr) > NFL;
       for (i=2; i <= arr_mx; i++) {
         ++row;
         printf("%d\t%d\t%s\n", sv_tm[i], sv_tm[i]-ts_beg, arr_in[i]) > NFL;
       }
       return row;
     }
     {
        FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
        if (NR == 1) {
          for (i=1; i <= NF; i++) {
             if (match($i, /^[0-9][0-9]\/[0-9][0-9]\/[0-9][0-9][0-9][0-9]/)) {
                dt_beg["yy"] = substr($i, 7);
                dt_beg["mm"] = substr($i, 1, 2);
                dt_beg["dd"] = substr($i, 4, 2);
                #printf("beg_date= mm.dd.yyyy %s.%s.%s\n", dt_beg["mm"], dt_beg["dd"], dt_beg["yy"]) > "/dev/stderr";
                break;
             }
          }
          next;
        }
     }
#12:05:59 AM  active/s passive/s    iseg/s    oseg/s
#12:06:00 AM    118.00      2.00   1200.00   1473.00
#
#12:05:59 AM  atmptf/s  estres/s retrans/s isegerr/s   orsts/s
#12:06:00 AM     44.00     14.00      2.00      0.00     93.00
     /^Average:/ {
        # could make a bar chart of this but...
        next;
     }
     /  active\/s /{
        if (mx_io == 0) {
          mx_io=1;
          sv_io[mx_io]="";
          sv_io_cols = NF-2;
          tab = "";
          for (i=3; i <= NF; i++) {
            sv_io[mx_io]=sv_io[mx_io] "" tab "" $i;
            tab="\t"
          }
        }
        sv[++sv_mx] = $0;
        area="io"; 
        next;
     }
     /  atmptf\/s /{
        if (mx_io1 == 0) {
          mx_io1=1;
          sv_io_cols += NF-2;
          tab="\t"
          for (i=3; i <= NF; i++) {
            sv_io[1]=sv_io[1] "" tab "" $i;
          }
        }
        sv[++sv_mx] = $0;
        area="io1"; 
        next;
     }
     {
        if (NF == 0) {
          area = "";
          sv[++sv_mx] = $0;
          next;
        }
        epoch = dt_to_epoch($1, $2, $0);
        if (ts_end > 0.0 && epoch > ts_end) {
            exit;
        }
        str="";
        tab="";
        if (area=="io1") {
           tab = "\t"; 
           str = sv_io[mx_io];
        }
        for (i=3; i <= NF; i++) {
          str = str "" sprintf("%s%s", tab, $i);
          tab = "\t";
        }
        if (area == "io") {
           sv_io[++mx_io] = str;
        }
        if (area == "io1") {
           sv_io[mx_io] = str;
        }
        sv_tm[mx_io] = epoch;
        sv[++sv_mx] = str;
        next;
     }
     END{
       row = -1;
trows++; printf("\tThis is a summarized view of some key TCP metrics. These include:\n") > NFL;
trows++; printf("\tactive/s: Number of locally-initiated TCP connections per second (e.g., via connect()).\n") > NFL;
trows++; printf("\tpassive/s: Number of remotely-initiated TCP connections per second (e.g., via accept()).\n") > NFL;
trows++; printf("\tretrans/s: Number of TCP retransmits per second.\n") > NFL;
trows++; printf("\tThe active and passive counts are often useful as a rough measure of server load: number of new accepted\n") > NFL;
trows++; printf("\tconnections (passive), and number of downstream connections (active). It might help to think of active as\n") > NFL;
trows++; printf("\toutbound, and passive as inbound, but this isn\x27t strictly true (e.g., consider a localhost to localhost\n") > NFL;
trows++; printf("\tconnection).\n") > NFL;
trows++; printf("\tRetransmits are a sign of a network or server issue; it may be an unreliable network (e.g., the public\n") > NFL;
trows++; printf("\tInternet), or it may be due a server being overloaded and dropping packets. The example above shows just\n") > NFL;
trows++; printf("\tone new TCP connection per-second.\n") > NFL;
trows++; printf("\t\n") > NFL;
row += trows;
       ttl=chart " tcp";
       row = line_data(row, sv_io, mx_io, ttl, sv_io[1]);
       ++row;
       printf("\n") > NFL;
       for (i=1; i <= sv_mx; i++) {
          printf("%s\n", sv[i]) > NFL;
       }
       close(NFL);
     }
   ' $i
   ck_last_rc $? $LINENO
   SHEETS="$SHEETS $i.tsv"
 fi

  if [[ $i == *"_perf_stat.txt" ]]; then
    OPT_D=
    if [ "$DEBUG_OPT" != "" ]; then
       OPT_D=" -D $DEBUG_OPT "
    fi
    OPT_TME=
    if [ "$END_TM" != "" ]; then
       OPT_TME=" -e $END_TM "
    fi
    OPT_C=
    if [ "$CLIP" != "" ]; then
       OPT_C=" -C $CLIP "
    fi
    OPT_P=
    if [ "$PHASE_FILE" != "" ]; then
       OPT_P=" -P $PHASE_FILE "
    fi
    OPT_MEM=
    if [ "$MEM_SPEED" != "" ]; then
      OPT_MEM=" -M $MEM_SPEED "
    fi
    RESP=`head -10 $i |wc -l|awk '{print $1}'`
    if [ $RESP -lt 9 ]; then
       echo "File $i has less than 10 lines ($RESP lines) so skipped it" > /dev/stderr
    else
    echo "$0.$LINENO bef perf_stat_scatter.sh phase= $PHASE_FILE clip= $CLIP $OPT_C $OPT_P"

    echo "do perf_stat data $i with BEG= $BEG, end= $END_TM" > /dev/stderr
    echo  $SCR_DIR/perf_stat_scatter.sh $OPT_MEM $OPT_P $OPT_C $OPT_D -b "$BEG"  $OPT_TME  -o "$OPTIONS" -O $i.tsv -f $i -S $SUM_FILE
          $SCR_DIR/perf_stat_scatter.sh $OPT_MEM $OPT_P $OPT_C $OPT_D -b "$BEG"  $OPT_TME  -o "$OPTIONS" -O $i.tsv -f $i -S $SUM_FILE
          ck_last_rc $? $LINENO
    fi
  fi
  if [[ $i == *"infra_cputime.txt" ]]; then
    #echo "$0: got $DIR/infra_cputime.txt at $LINENO" > /dev/stderr
    INCPUS=0

    if [ "$LSCPU_FL" != "" ]; then
     INCPUS=`awk '/^CPU.s.:/ { printf("%s\n", $2);exit;}' $LSCPU_FL`
    fi
    #echo "$0.$LINENO: _____________ INCPUS= $INCPUS, LSCPU_FL= $LSCPU_FL" > /dev/stderr
    echo "$SCR_DIR/rd_infra_cputime.sh -O "$OPTIONS" -f $i -n $INCPUS -S $SUM_FILE -m $MUTTLEY_OUT_FILE"
          $SCR_DIR/rd_infra_cputime.sh -O "$OPTIONS" -f $i -n $INCPUS -S $SUM_FILE -m $MUTTLEY_OUT_FILE
          ck_last_rc $? $LINENO
    if [ -e $i.tsv ]; then
      SHEETS="$SHEETS $i.tsv"
    fi
  fi
  if [[ $i == *"specjbb.log" ]]; then
    echo "$0.$LINENO got here" > /dev/stderr
    echo "$0: got specjbb.log $i at $LINENO" > /dev/stderr
#jbb2015.result.metric.max-jOPS = 87723
#jbb2015.result.metric.critical-jOPS = 28775
    awk -v sum_file="$SUM_FILE" '
      /jbb2015.result.metric.max-jOPS =/ {
        printf("specjbb\tspecjbb\t%s\tspecjbb max-jOPS\n", $3) >> sum_file;
      }
      /jbb2015.result.metric.critical-jOPS =/ {
        printf("specjbb\tspecjbb\t%s\tspecjbb crit-jOPS\n", $3) >> sum_file;
      }
    ' $i
    ck_last_rc $? $LINENO
    echo "$0.$LINENO got here" > /dev/stderr
  fi
    echo "$0.$LINENO got here" > /dev/stderr
  if [[ $i == *"CPU2017.001.log" ]]; then
    echo "$0.$LINENO got here" > /dev/stderr
# Benchmark Times:
#   Run Start:    2021-01-30 00:20:38 (1611994838)
#   Rate Start:   2021-01-30 00:20:38 (1611994838.37371)
#   Rate End:     2021-01-30 00:30:01 (1611995401.19515)
#   Run Stop:     2021-01-30 00:30:01 (1611995401)
#   Run Elapsed:  00:09:23 (563)
#   Run Reported: 00:09:22 (562 821444034 562.821444)
#  Success 500.perlbench_r base refrate ratio=181.03, runtime=562.821444, copies=64, threads=1, power=0.00W, temp=0.00 degC, humidity=0.00%
    #awk -v sum_file="/dev/stderr" '
    RESP=`awk -v option_str="$OPTIONS" -v sum_file="$SUM_FILE" '
      BEGIN{
        do_perlbench_subphase = 0;
        if (index(option_str, "do_perlbench_subphase{1}") > 0) {
          do_perlbench_subphase = 1;
        }
      }
      /  Rate Start: / {
        bm_nm = "";
        copies = 0;
        v = substr($5, 2, length($5)-2);
        tm_beg = v;
      }
      /  Rate End: / {
        v = substr($5, 2, length($5)-2);
        tm_end = v;
      }
    /Workload elapsed time .copy .* workload .*. = .* seconds/ {
      pos = index($7, ")");
      subphs = $7; if (pos > 1) { subphs = substr(subphs, 1, pos); }
      subphs += 0;
      subphs_arr[subphs] = $9+0;
      subphs_mx = subphs;
    }
      /^ Success .* base refrate ratio=/ {
        #printf("got cpu2017.001.log line= %s\n", $0) > "/dev/stderr";
        gsub(",", "", $0);
        bm_nm = $2;
        for (i=3; i <= NF; i++) {
          n = split($i, arr, "=");
          if (index($i, "ratio=") == 1)   { ratio = arr[2]; }
          if (index($i, "runtime=") == 1) { run_tm = arr[2]; }
          if (index($i, "copies=") == 1)  { copies = arr[2]; }
        }
        if (bm_nm != "" && (copies+0) >= 1) {
          if (!(bm_nm in bm_list)){
            bm_list[bm_nm] = ++bm_mx;
            bm_lkup[bm_mx] = bm_nm;
            bm_arr[bm_mx,"mx"] = 0;
          }
          bm_i = bm_list[bm_nm];
          bm_occ = ++bm_arr[bm_i,"mx"];
          ++b_mx;
          b_arr[b_mx,1] = bm_i;
          b_arr[b_mx,2] = bm_occ;
          b_arr[b_mx,"ratio"] = ratio;
          b_arr[b_mx,"run_tm"] = run_tm;
          b_arr[b_mx,"copies"] = copies;
          b_arr[b_mx,"beg"] = tm_beg;
          b_arr[b_mx,"end"] = tm_end;
          b_arr[b_mx, "subphs_mx"] = subphs_mx;
          for (i=1; i <= subphs_mx; i++) {
            b_arr[b_mx, "subphs", i] = subphs_arr[i];
          }
        }
      }
      END{
      printf("specint b_mx= %d\n", b_mx) > "/dev/stderr";
        for(i=1; i <= b_mx; i++) {
          bm_i = b_arr[i,1];
          bm_o = b_arr[i,2];
          nm = bm_lkup[bm_i];
          ratio  = b_arr[i,"ratio"];
          run_tm = b_arr[i,"run_tm"];
          copies = b_arr[i,"copies"];
          tm_beg = b_arr[i,"beg"];
          tm_end = b_arr[i,"end"];
          printf("specint\tspecint\t%s\t\"SI %s %s %s\"\n", ratio, nm, "ratio", bm_o) >> sum_file;
          printf("specint\tspecint\t%s\t\"SI %s %s %s\"\n", run_tm, nm, "run_tm", bm_o) >> sum_file;
          printf("specint\tspecint\t%s\t\"SI %s %s %s\"\n", copies, nm, "copies", bm_o) >> sum_file;
          printf("specint\tspecint\t%s\t\"SI %s %s %s\"\n", tm_beg, nm, "beg_ts", bm_o) >> sum_file;
          printf("specint\tspecint\t%s\t\"SI %s %s %s\"\n", tm_end, nm, "end_ts", bm_o) >> sum_file;
          if (do_perlbench_subphase == 1 && index(nm, "perlbench") > 0) {
            tm_off = 0.0;
            sfx[1] = "aaaa";
            sfx[2] = "bbbb";
            sfx[3] = "cccc";
            ev = b_arr[i,"subphs_mx"];
            #printf("%s_%s %.3f %.3f %.3f\n", "perlb", ev, tm_beg, tm_beg, 0.0);
            for (j=1; j <= ev; j++) {
              v = b_arr[i,"subphs", j];
              printf("%s_%s %.3f %.3f %.3f\n", "500.perl" sfx[j] "" j, j, tm_beg, tm_beg+v, v);
              tm_beg += v;
            }
          } else {
            printf("%s_%s %.3f %.3f %.3f\n", nm, bm_o, tm_beg, tm_end, tm_end-tm_beg);
          }
        }
      }
    ' $i`
    ck_last_rc $? $LINENO
    echo "$0.$LINENO got here" > /dev/stderr
    echo  -e "$RESP" > phase_cpu2017.txt
    if [ "$PHASE_FILE" == "" ]; then
       #echo  -e "$RESP" > phase_cpu2017.txt
       PHASE_FILE=phase_cpu2017.txt
    fi
    #echo "$0.$LINENO bye"
    #exit 1
  fi
#abcd
  if [[ $i =~ phase_cpu2017.txt ]]; then
    echo "$0.$LINENO: got CPU2017.001.intrate.txt $i at $LINENO" > /dev/stderr
    OFILE="$i.tsv"
    awk -v ofile="$OFILE" -v ts_beg="$BEG"  -v sum_file="$SUM_FILE" '
 #subtest beg_epoch end_epoch
      BEGIN{
        subtst=0;
        tm_beg = ts_beg;
      }
      {
        if (NF >= 3) {
          if ($0 == "" || substr($1, 1, 1) == "#") { next; }
          if (tm_beg == "") { tm_beg = $2+0; }
          printf("specint\tspecint\t%s\t%s beg secs\n", $2-tm_beg, $1) >> sum_file;
          printf("specint\tspecint\t%s\t%s end secs\n", $3-tm_beg, $1) >> sum_file;
          subtst++;
          sv[subtst,"nm"] = $1;
          sv[subtst,"beg"] = $2;
          sv[subtst,"end"] = $3;
        }
      }
      END{
       if (subtst==0) {
         exit;
       }
       printf("title\tcpu2017 subtests\tsheet\tcpu2017_phase\ttype\tscatter_straight\n") > ofile;
       row++;
       printf("hdrs\t%d\t%d\t-1\t%d\t1\n", row+1, 2, 2+subtst) > ofile;
       row++;
       printf("epoch\tts") > ofile;
       for (i=1; i <= subtst; i++) {
         printf("\t%s", sv[i,"nm"]) > ofile;
       }
       printf("\n") > ofile;
       for (j=1; j <= subtst; j++) {
         for (k=1; k <= 4; k++) {
           if (k<=2) {
             tm  = sv[j,"beg"];
           } else {
             tm  = sv[j,"end"];
           }
           tm0 = tm;
           # for now, unless Im using scatter plots (and when I save files for google sheets then scatter plots become line charts)
           # then just enit a begin and end point. line charts dont assume linear time on xaxis.
           if (k == 1 || k == 4) { continue; }
           if (k == 1) { tm = tm - 0.01;}
           if (k == 4) { tm = tm + 0.01;}
           printf("%s\t%.3f", tm0, tm-tm_beg) > ofile;
           for (i=1; i <= subtst; i++) {
             if (k == 1 || k == 4 || i != j) {
               printf("\t%s", 0) > ofile;
             } else {
               printf("\t%s", 1+0.1*i) > ofile;
             }
           }
           printf("\n") > ofile;
         }
       }
      }
    ' $i
    ck_last_rc $? $LINENO
  fi
  if [[ $i =~ CPU2017.001.intrate.*txt ]]; then
    echo "$0.$LINENO: got CPU2017.001.intrate.txt $i at $LINENO" > /dev/stderr
    awk -v sum_file="$SUM_FILE" '
 #Est. SPECrate2017_int_base             159
 #Est. SPECrate2017_int_peak                                         Not Run
      / Est. SPECrate2017_int_base/ {
        if ($3 != "Not") {
        printf("specint\tspecint\t%s\tspecint_rate\n", $3) >> sum_file;
        }
        next;
      }
      / SPECrate2017_int_base/ {
        printf("specint\tspecint\t%s\tspecint_rate\n", $2) >> sum_file;
      }
    ' $i
    ck_last_rc $? $LINENO
  fi
    echo "$0.$LINENO got here" > /dev/stderr
  if [[ $i == *"yab_cmds.txt" ]]; then
    echo "$0: got yab_cmds.txt $i at $LINENO" > /dev/stderr
    echo "$SCR_DIR/rd_yab_json.sh -f $i -S $SUM_FILE"
          $SCR_DIR/rd_yab_json.sh -f $i -S $SUM_FILE
          ck_last_rc $? $LINENO
    if [ -e $i.tsv ]; then
      echo "$0: SHEETS add file $i.tsv"
      SHEETS="$SHEETS $i.tsv"
    fi
  fi
  if [[ $i == *"yab_cmds.json" ]]; then
    echo "$0: got yab_cmds.json $i at $LINENO" > /dev/stderr
    echo "$SCR_DIR/rd_yab_json.sh -f $i -S $SUM_FILE"
          $SCR_DIR/rd_yab_json.sh -f $i -S $SUM_FILE
          ck_last_rc $? $LINENO
    if [ -e $i.tsv ]; then
      echo "$0: SHEETS add file $i.tsv"
      SHEETS="$SHEETS $i.tsv"
    fi
  fi
  if [[ $i == *"_perf_stat.txt.tsv"* ]]; then
    SHEETS="$SHEETS $i"
  else
    if [[ $i == *"_perf_stat.txt"* ]]; then
    RESP=`head -10 $i |wc -l|awk '{print $1}'`
    if [ $RESP -gt 3 ]; then
      SHEETS="$SHEETS $i.tsv"
    fi
    fi
  fi

  if [[ $i == *"gmatching_logs.txt" ]]; then
    echo "do gmatching_logs"
    echo "+++++++++do gmatching_logs" > /dev/stderr
    awk -v ts_beg="$BEG"  -v ts_end="$END_TM" -v pfx="$PFX" -v typ="gmatching errs" -v ts_adj_hrs="$BEG_ADJ" '
     BEGIN{beg=1;
        chart=typ;
        mx = 0;
        epoch_init = 0;
        ts_beg += 0;
        ts_end += 0;
      }
      function dt_to_epoch(yy, mo, dd, hh, mm, ss, ms, all) {
         # the epoch seconds from the date time info in the file is local time,not UTC.
         # so just use the calc"d epoch seconds to calc the elapsed seconds since the start.
         # THe real timestamp is the input ts_beg + elapsed_seconds.
         # hhmmss fmt= hh:mm:ss (w leading 0
         dt_str = yy " " mo " " dd " " hh " " mm " " ss;
         #printf("dt_str= %s\n", dt_str) > NFL;
         epoch = mktime(dt_str);
         #epoch = 1;
         #epoch += 0.001 * ms;
         #printf("epoch= %s offset= %s\n", epoch, offset);
         if (epoch_init == 0) {
             #printf("dt_str= %s, all= %s\n", dt_str, all) > "/dev/stderr";
             epoch_init = epoch;
         }
         #epoch = (epoch; # the plus 1 assumes a 1 second interval.
         return epoch;
      }
     {
        FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        v = substr($0, index($0, "[")+1, length($0));
        v = substr(v, 1, index(v, "]")-1);
        yy = substr(v, 1, 4);
        mo = substr(v, 6, 2);
        dd = substr(v, 9, 2);
        hh = substr(v, 12, 2);
        mm = substr(v, 15, 2);
        ss = substr(v, 18, 2);
        ms = substr(v, 21, 3);
        epoch = dt_to_epoch(yy, mo, dd, hh, mm, ss, 0.0, $0);
        #printf("epoch[%d]= %s\n", mx, epoch) > NFL;
        sv_tm[++mx] = epoch;
     }
     END{
       row = 0;
       row++;
       printf("title\tlog errors/s vs time\tsheet\tlog errs\ttype\tscatter_straight\n") > NFL;
       row++;
       printf("hdrs\t%d\t%d\t-1\t%d\t1\n", row+1, 2, 2) > NFL;
       row++;
       printf("TS\tts_rel\tlog_errs/s\n") > NFL;
       ts_adj = ts_adj_hrs * 3600.0;
       tmd = sv_tm[mx] - sv_tm[1];
       printf("------gmathcing_logs: tmd= %f ts_beg= %f, ts_end= %f, ts_diff= %f\n", tmd, ts_beg, ts_end, ts_beg - sv_tm[1] - ts_adj) > "/dev/stderr";
       for (i=1; i <= tmd; i++) {
          bkt[i] = 0;
       }
       for (i=1; i <= mx; i++) {
          j = sprintf("%d", sv_tm[i] - epoch_init)+0;
          bkt[j]++;
       }
       sm = 0;
       for (i=1; i <= tmd; i++) {
          sm += bkt[i];
          #if ((i % 10) == 0) {
          if (i > 10 && ((i % 10) == 0)) {
            if (((sv_tm[1]+i)-ts_beg+ts_adj) >= 0) {
            row++;
            printf("=%.3f\t%.3f\t%.3f\n", (sv_tm[1]+i)+ts_adj, (sv_tm[1]+i)-ts_beg+ts_adj, sm / 10.0) > NFL;
            }
            sm = 0;
          }
       }
       printf("\n") > NFL;
       close(NFL);
     }
   ' $i
   ck_last_rc $? $LINENO
   SHEETS="$SHEETS $i.tsv"
 fi
  if [[ $i == *"_watch.txt"* ]]; then
    # /sys/devices/virtual/thermal/thermal_zone\
    GOT_TEMP=
    if [ -e run.log ]; then
      RESP=`grep "/sys/devices/virtual/thermal/thermal_zone.*temp" run.log`
      echo "$0.$LINENO ck for temperature watch file= $RESP"
      if [ "$RESP" != "" ]; then
        GOT_TEMP=1
      fi
    fi
    echo "do watch"
# ==beg 0 date 1580278735.829557760
#-rw-r--r-- 1 udocker udocker 17097435 May 24 03:18 /var/log/udocker/gmatching/performance/gmatching/gmatching.log

    awk -v got_temp="$GOT_TEMP" -v ts_beg="$BEG" -v pfx="$PFX" '
     BEGIN{
       beg=1;col_mx=-1;mx=0;
     }
     /^==beg /{
       FNM=ARGV[ARGIND];
       NFL=FNM ".tsv";
       tm = $4;
       sv_tm[++mx]=tm;
       sv_arr[mx,"mx"] = 0;
       next;
     }
     /^==end /{
       tm = $4;
       sv_tm[mx]=tm;
       next;
     }
     { # has to be an ls -l file line
        sz = $5+0;
        sv_sz[mx]=sz;
        i = ++sv_arr[mx,"mx"];
        sv_arr[mx,"val",i] = $0;
     }
     END{
       row=0;
       wraps = 0;
       sz = 0;
       if (got_temp == 1) {
         row=-1;
         skts = sv_arr[1,"mx"];
         row++;
         printf("title\twatch log temperatures vs time\tsheet\twatch\ttype\tscatter_straight\n") > NFL;
         row++;
         printf("hdrs\t%d\t%d\t-1\t%d\t1\n", row+1, 2, skts+1) > NFL;
         row++;
         printf("temperature sockets %d\n", skts);
         printf("TS\tts_rel") > NFL;
         for (i=1; i <= skts; i++) {
           printf("\ttemperature skt %d", i) > NFL;
         }
         printf("\n") > NFL;
         for (i=1; i <= mx; i++) {
           printf("=%.4f\t%.3f", sv_tm[i], sv_tm[i]-ts_beg) > NFL;
           for (j=1; j <= skts; j++) {
             printf("\t%.3f", 0.001 * sv_arr[i,"val",j]) > NFL;
           }
           row++;
           printf("\n") > NFL;
         }
         row++;
         printf("\n") > NFL;
         close(NFL);
         exit(0);
       }
       for (i=2; i <= mx; i++) {
         sz0 = sv_sz[i-1];
         sz1 = sv_sz[i];
         tm0 = sv_tm[i-1];
         tm1 = sv_tm[i];
         wraps = 0;
         if (sz1 < sz0) {
           wraps += 50*1024*1024;
         }
         sz += sz1 - sz0 + wraps;
         tm = tm1 - tm0;
       }
       tm = tm1 - sv_tm[1];
       MBpSec = 1.0e-6*sz/tm;
       row++;
       printf("average MB/s\t%.3f\n", MBpSec) > NFL;
       row++;
       printf("title\twatch log file writes (MB/s) vs time\tsheet\twatch\ttype\tscatter_straight\n") > NFL;
       row++;
       printf("hdrs\t%d\t%d\t-1\t%d\t1\n", row+1, 2, 2) > NFL;
       row++;
       printf("TS\tts_rel\tlog_MB/s\n") > NFL;
       wraps = 0;
       for (i=2; i <= mx; i++) {
         sz0 = sv_sz[i-1];
         sz1 = sv_sz[i];
         tm0 = sv_tm[i-1];
         tm1 = sv_tm[i];
         wraps = 0.0;
         if (sz1 < sz0) {
           wraps += 50*1024*1024;
         }
         sz = sz1 - sz0 + wraps;
         tm = tm1 - tm0;
         MBpSec = 1.0e-6*sz/tm;
       row++;
         printf("=%.4f\t%.3f\t%.3f\n", sv_tm[i], sv_tm[i]-ts_beg, MBpSec) > NFL;
       }
       row++;
       printf("\n") > NFL;
       row++;
       printf("title\t10sec moving avg watch log file writes (MB/s) vs time\tsheet\twatch\ttype\tscatter_straight\n") > NFL;
       row++;
       printf("hdrs\t%d\t%d\t-1\t%d\t1\n", row+1, 2, 2) > NFL;
       row++;
       printf("TS\tts_rel\tlog_sz_KB\n") > NFL;
       wraps = 0;
       szsum=0;
       tmsum=0;
       itr = 4;
       for (i=itr; i <= mx; i++) {
         sz0 = sv_sz[i-1];
         sz1 = sv_sz[i];
         tm0 = sv_tm[i-1];
         tm1 = sv_tm[i];
         wraps = 0.0;
         if (sz1 < sz0) {
           wraps += 50*1024*1024;
         }
         sz = sz1 - sz0 + wraps;
         tm = tm1 - tm0;
         szsum += sz;
         tmsum += tm;
         if (i > itr && ((i % 10) == itr)) {
           MBpSec = 1.0e-6*szsum/tmsum;
           szsum=0;
           tmsum=0;
           row++;
           printf("=%.4f\t%.3f\t%.3f\n", sv_tm[i], sv_tm[i]-ts_beg, MBpSec) > NFL;
         }
       }
       close(NFL);
   }
   ' $i
   ck_last_rc $? $LINENO
   SHEETS="$SHEETS $i.tsv"
  fi
  if [[ $i == *"_interrupts.txt"* ]]; then
    echo "do interrupts"
# ==beg 0 date 1580278735.829557760
#            CPU0       CPU1       CPU2       CPU3       CPU4       CPU5       CPU6       CPU7       CPU8       CPU9       CPU10      CPU11      CPU12      CPU13      CPU14      CPU15      CPU16      CPU17      CPU18      CPU19      CPU20      CPU21      CPU22      CPU23      CPU24      CPU25      CPU26      CPU27      CPU28      CPU29      CPU30      CPU31      
#   0:        101          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0  IR-IO-APIC    2-edge      timer
#   3:          2          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0  IR-IO-APIC    3-edge    

    awk -v pfx="$PFX" '
     BEGIN{beg=1;col_mx=-1;mx=0}
     /^==beg /{
       FNM=ARGV[ARGIND];
       NFL=FNM ".tsv";
       row = $2;
       tm = $4;
       getline;
       hdr_line = $0;
       n = split($0, hdr_cols_arr);
       hdr_cols = NF;
       next;
     }
     { # has to be an interrupt line
        nm = $1;
        if (intr_arr[nm] != nm) {
           intr_num++;
           intr_arr[nm] = nm;
           intr_arr_nms[intr_num] = nm;
           intr_arr_num[nm] = intr_num;
        }
        inum = intr_arr_num[nm];
        for (i=1; i <= NF; i++) {
          sv[row,inum,i] = $i;
        }
        sv_col[row,inum] = NF;
        if ( intr_arr_lng_nms[inum] == "" && NF > (hdr_cols+1) ) {
           for (i=hdr_cols+2; i <= NF; i++) {
             intr_arr_lng_nms[inum] = intr_arr_lng_nms[inum] " " $i;
           }
        }
        if (NF > (hdr_cols+1)) {
          sv_col[row,inum] = hdr_cols+1;
        }
     }
     END{
       for (i=1; i <= intr_num; i++) {
         ck_no_chg[i] = 0;
       }
       for (r=1; r <= row; r++) {
         for (i=1; i <= intr_num; i++) {
            jmx = sv_col[r,i];
            sum = 0;
            for (j=2; j <= jmx; j++) {
               sum += sv[r,i,j];
            }
            sum_arr[r,i] = sum;
         }
       }
       
       for (r=1; r <= row; r++) {
          for (i=1; i <= intr_num; i++) {
             val = sum_arr[r,i];
             if (r == 1) {
                val = 0;
             } else {
                val -= sum_arr[r-1,i];
             }
             ck_no_chg[i] += val;
          }
       }
       drop_cols = 0;
       for (i=1; i <= intr_num; i++) {
         if (ck_no_chg[i] == 0) {
            drop_cols++;
         }
       }
       trows=0;
       printf("title\tinterrupts\tsheet\tinterrupts\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t0\t%d\t%d\t-1\n", 2+trows, -1, intr_num-drop_cols) > NFL;
       tab="";
       for (i=1; i <= intr_num; i++) {
          if (ck_no_chg[i] == 0) {
            continue;
          }
          printf("%s%s", tab, intr_arr_nms[i]) > NFL;
          if (intr_arr_lng_nms[i] != "") {
             printf(" %s", intr_arr_lng_nms[i]) > NFL;
          }
          tab="\t";
       }
       trows=2;
       printf("\ttotal\n") > NFL;
       
       for (r=1; r <= row; r++) {
          tab="";
          total=0;
          for (i=1; i <= intr_num; i++) {
             if (ck_no_chg[i] == 0) {
               continue;
             }
             val = sum_arr[r,i];
             if (r == 1) {
                val = 0;
             } else {
                val -= sum_arr[r-1,i];
             }
             printf("%s%d", tab, val) > NFL;
             tab="\t";
             total += val;
          }
          trows++;
          printf("\t%d\n", total) > NFL;
       }
       close(NFL);
   }
   ' $i
   ck_last_rc $? $LINENO
   SHEETS="$SHEETS $i.tsv"
  fi
#02:53:57    InKB   OutKB   InSeg  OutSeg Reset  AttF %ReTX InConn OutCon Drops
#TCP         0.00    0.00  6570.7  8893.4   161  23.2 0.000   6.10    117  0.00
#02:53:57                    InDG   OutDG     InErr  OutErr
#UDP                       2940.3  2952.9     11.53    0.00
#02:53:57      RdKB    WrKB   RdPkt   WrPkt   IErr  OErr  Coll  NoCP Defer  %Util
#eth0        2833.9  4123.3  4266.9  5099.8   0.00  0.00  0.00  0.00  0.00   0.14
#1581994437:TCP:0.000:0.000:6570.7:8893.4:160.7:23.16:0.000:6.102:117.5:0.000
#1581994437:UDP:2940.3:2952.9:11.53:0.000
#1581994437:eth0:2833.9:4123.3:4266.9:5099.8:0.14:0.01:0.00:0.00:0.00:0.00:0.00

  if [[ $i == *"_nicstat.txt"* ]]; then
    echo "do nicstat"
    awk -v beg_ts="$BEG" -v ts_end="$END_TM" -v pfx="$PFX" -v sum_file="$SUM_FILE" -v sum_flds="InKB{TCP_RdKB/s|network},OutKB{TCP_WrKB/s|network},RdKB{NetDev_RdKB/s|network},WrKB{NetDev_WrKB/s|network},IErr{NetDev_IErr/s|network},OErr{NetDev_OErr/s|network},%Util{NetDev_%Util|network}" '
     BEGIN{
        beg_ts += 0.0;
        ts_end += 0.0;
        n_sum = 0;
       if (sum_file != "" && sum_flds != "") {
         n_sum = split(sum_flds, sum_arr, ",");
         for (i_sum=1; i_sum <= n_sum; i_sum++) {
            sum_type[i_sum] = 1;
            str = sum_arr[i_sum];
            pos = index(str, "{");
            if (pos > 0) {
               pos1 = index(str, "}");
               if (pos1 == 0) { pos1= length(str)+1; }
               sum_str = substr(str, pos+1, pos1-pos-1);
               n_sum2 = split(sum_str, sum_arr2, "|");
               if (sum_arr2[1] != "") {
                 sum_prt[i_sum] = sum_arr2[1];
               } else {
                 #sum_prt[i_sum] = str;
                 sum_prt[i_sum] = substr(str, 1, pos-1);
               }
               if (sum_arr2[2] != "") {
                 sum_res[i_sum] = sum_arr2[2];
               }
               #sum_prt[i_sum] = substr(str, pos+1, pos1-pos-1);
               sum_arr[i_sum] = substr(str, 1, pos-1);
            } else {
               sum_prt[i_sum] = str;
            }
            if (index(str, "%") > 0) {
               sum_type[i_sum] = 0;
            }
         }
       }
     }
     {
        FNM=ARGV[ARGIND];
        if (index(FNM, ".txt.hdr") > 0) {
          if (match($1, /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/)) {
            # hdr row
            for (i=1; i <= NF; i++) {
              cols[i]=$i;
            }
            next;
          } else {
            idx = ++hdr_typs;
            hdr_typ[idx] = $1
            hdr_str[$1] = idx;
            hdr[idx,1] = $1;
            hdr_mx[idx] = NF;
            hdr_row[idx] = 0;
            for (j=2; j <= NF; j++) {
               hdr[idx,j] = cols[j];
            }
          }
        } else {
          NFL = FNM ".tsv";
          n   = split($0, arr, ":");
          ts  = arr[1];
          typ = arr[2];
          idx = hdr_str[typ];
          rw = ++hdr_row[idx];
          ts_row[idx,rw] = ts;
          for (j=3; j <= n; j++) {
            data[idx,rw,j-2] = arr[j];
          }
       }
     }
     END{
       row=-1;
       for (i=1; i <= hdr_typs; i++) {
          if (n_sum > 0) {
            for (k=1; k <= hdr_mx[i]; k++) {
              hdr_lkup[k] = -1;
            }
            for (k=2; k <= hdr_mx[i]; k++) {
              for (i_sum=1; i_sum <= n_sum; i_sum++) {
                 if (hdr[i,k] == sum_arr[i_sum]) {
                    hdr_lkup[k-1] = i_sum;
                    break; # so if hdr appears more than one in sum_flds, it will be skipped
                 }
              }
            }
          }
           row++;
           printf("title\tnicstat %s\tsheet\tnicstat %s\ttype\tscatter_straight\n", hdr_typ[i], hdr_typ[i]) > NFL;
           row++;
           printf("hdrs\t%d\t3\t%d\t%d\t2\n", 1+row, -1, hdr_mx[i]+1) > NFL;
           printf("type\tTimeStamp\tRel_TS") > NFL;
           for (j=2; j <= hdr_mx[i]; j++) {
             printf("\t%s", hdr[i,j]) > NFL;
           }
           row++;
           printf("\n") > NFL;
           for (rw=1; rw <= hdr_row[i]; rw++) {
              if (ts_end > 0.0 && ts_row[i,rw] > ts_end) {
                continue;
              }
              ts_diff = ts_row[i,rw]-beg_ts;
              if (ts_diff < 0.0) {continue;}
              printf("%s\t%.0f\t%.3f", hdr_typ[i], ts_row[i,rw], ts_row[i,rw]-beg_ts) > NFL;
              for (k=1; k <= hdr_mx[i]; k++) {
                 printf("\t%s", data[i,rw,k]) > NFL;
                 if (hdr_lkup[k] != -1) {
                   i_sum = hdr_lkup[k];
                   sum_occ[i_sum] += 1;
                   if (sum_type[i_sum] == 1) {
                     if (sum_tmin[i_sum] == 0) { sum_tmin[i_sum] = ts_row[i,rw]; sum_tmax[i_sum] = sum_tmin[i_sum]; }
                     if (sum_tmax[i_sum] < ts_row[i,rw]) { sum_tmax[i_sum] = ts_row[i,rw]; }
                     if (rw > 1) {intrvl = ts_row[i,rw] - ts_row[i,rw-1]; } else { intrvl = 1.0 };
                     sum_tot[i_sum] += data[i,rw,k] * intrvl;
                   } else {
                     sum_tot[i_sum] += data[i,rw,k];
                   }
                 }
              }
              row++;
              printf("\n") > NFL;
           }
           row++;
           printf("\n") > NFL;
       }
       close(NFL);
       if (n_sum > 0) {
          printf("got nicstat n_sum= %d\n", n_sum) >> "/dev/stderr";
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
             divi = sum_occ[i_sum];
             if (sum_type[i_sum] == 1) {
                divi = sum_tmax[i_sum] - sum_tmin[i_sum];
             }
             ky = sum_prt[i_sum];
             vl = (divi > 0 ? sum_tot[i_sum]/divi : 0.0);
             printf("%s\t%s\t%f\t%s\n", sum_res[i_sum], "nicstat", vl, ky) >> sum_file;
          }
       }
   }
   ' $i.hdr $i
   ck_last_rc $? $LINENO
   SHEETS="$SHEETS $i.tsv"
  fi
done
OPT_END_TM=
if [ "$END_TM" != "" ]; then
  OPT_END_TM=" -e $END_TM "
fi
echo "----------- top_dir= $TOP_DIR ----------" > /dev/stderr
tst_files="latency_histo.json"
for f in $tst_files; do
  if [ -e $f ]; then
     echo "try latency log $f" > /dev/stderr
     $SCR_DIR/resp_2_tsv.sh -f $f -s $SUM_FILE $OPT_END_TM
     ck_last_rc $? $LINENO
  fi
  if [ -e $f.tsv ]; then
     SHEETS="$SHEETS $f.tsv"
     echo "got latency log $f.tsv" > /dev/stderr
  fi
done
tst_files="http-status.json"
for f in $tst_files; do
  if [ -e $f ]; then
     echo "try http-status log $f" > /dev/stderr
     $SCR_DIR/resp_2_tsv.sh -f $f -s $SUM_FILE  $OPT_END_TM
     ck_last_rc $? $LINENO
  fi
  if [ -e $f.tsv ]; then
     SHEETS="$SHEETS $f.tsv"
     echo "got http-status log $f.tsv" > /dev/stderr
     grep title $f.tsv > /dev/stderr
  fi
done
tst_files="RPS.json response_time.json"
for f in $tst_files; do
  OPT_S=
  if [ "$SUM_FILE" != "" ]; then
    OPT_S=" -s $SUM_FILE "
  fi
  if [ -e $f ]; then
     $SCR_DIR/resp_2_tsv.sh -f $f $OPT_S $OPT_END_TM
     ck_last_rc $? $LINENO
  fi
  if [ -e $f.tsv ]; then
     SHEETS="$SHEETS $f.tsv"
  fi
done
ITP_FILE=$METRIC_OUT.tsv
if [ ! -e $ITP_FILE ]; then
  ITP_FILE=$METRIC_OUT.csv.tsv
fi
if [ -e $ITP_FILE ]; then
  echo "found itp_file: $ITP_FILE" > /dev/stderr
  SHEETS="$SHEETS $ITP_FILE"
fi
GC_FILE=gc.log.0.current
if [ -e $GC_FILE ]; then
  $SCR_DIR/java_gc_log_2_tsv.sh -f $GC_FILE $OPT_END_TM  > $GC_FILE.tsv
  ck_last_rc $? $LINENO
  SHEETS="$SHEETS $GC_FILE.tsv"
fi
JAVA_COL=java.collapsed
JAVA_COL_TR=java.coll_traces
if [ ! -e $JAVA_COL ]; then
  if [ -e $JAVA_COL_TR ]; then
     awk '/^---/{exit;}{printf("%s\n", $0);}' $JAVA_COL_TR > $JAVA_COL
  fi
fi
if [ -e $JAVA_COL ]; then
  echo "do flamegraph.pl" 1>&2
  cat $JAVA_COL | perl $SCR_DIR/../flamegraph/flamegraph.pl --title "Flamegraph $RPS" > java.svg
  echo "do svg_to_html.sh " 1>&2
  $SCR_DIR/svg_to_html.sh -r 1 -d . -f java.svg > java.html
  inkscape -z  -w 2400 -j --export-file=java.png  java.svg
  $SCR_DIR/gen_flamegraph_for_java_in_container_function_hotspot.sh -t count -f $JAVA_COL > $JAVA_COL.tsv
  if [ "$SUM_FILE" != "" ]; then
    SAMPLES=`awk '/__total__/{printf("%s\n", $1);exit;}' $JAVA_COL.tsv`
    DURA_SECS=`awk '/ start /{for(j=1;j<= NF;j++){if ($(j)=="-d"){b=dura=$(j+1);n=gsub("m", "", dura);c=dura+0.0;if (n>0){c*=60.0;}printf("%.3f\n",c);exit;}}}' run.log`
    SMP_PER_SEC=`awk -v samples="$SAMPLES" -v dura="$DURA_SECS" 'BEGIN{samples+=0.0;dura+=0.0;if(dura<=0.0){printf("0.0\n");exit;};printf("%f\n", samples/dura);exit}' run.log`
    echo "====== TOP_DIR= $TOP_DIR" > /dev/stderr
    FLAME_TYP=`awk -v dir="$TOP_DIR" 'BEGIN{str="itimer";if (index(dir, "lock")>0){str="lock";}}/ start /{for(j=1;j<= NF;j++){if ($(j)=="-E"){str=$(j+1);exit;}}}END{printf("%s\n", str);}' run.log`
    echo -e "software utilization\tflamegraph\t$FLAME_TYP/s\t=$SMP_PER_SEC" >> $SUM_FILE
    echo "========flamegraph samples= $SAMPLES, dura_secs= $DURA_SECS FL_TYP= $FLAME_TYP, samples/sec= $SMP_PER_SEC" > /dev/stderr
  fi
  SHEETS="$SHEETS $JAVA_COL.tsv"
fi
if [ "$JAVA_COL_TR" != "" ]; then
 if [ -e $JAVA_COL_TR ]; then
  $SCR_DIR/gen_flamegraph_for_java_in_container_function_hotspot.sh -t time -f $JAVA_COL_TR > $JAVA_COL_TR.tsv
  if [ "$SUM_FILE" != "" ]; then
    FLAME_TYP=`awk -v dir="$TOP_DIR" 'BEGIN{str="itimer";if (index(dir, "lock")>0){str="lock";}}/ start /{for(j=1;j<= NF;j++){if ($(j)=="-E"){str=$(j+1);exit;}}}END{printf("%s\n", str);}' run.log`
    if [ "$FLAME_TYP" == "lock" ]; then
     LOCK_SECS=`awk '/__total__/{printf("%s\n", $1);exit;}' $JAVA_COL_TR.tsv`
     DURA_SECS=`awk '/ start /{for(j=1;j<= NF;j++){if ($(j)=="-d"){b=dura=$(j+1);n=gsub("m", "", dura);c=dura+0.0;if (n>0){c*=60.0;}printf("%.3f\n",c);exit;}}}' run.log`
     SMP_PER_SEC=`awk -v samples="$LOCK_SECS" -v dura="$DURA_SECS" 'BEGIN{samples+=0.0;dura+=0.0;if(dura<=0.0){printf("0.0\n");exit;};printf("%f\n", samples/dura);exit}' run.log`
     echo "====== TOP_DIR= $TOP_DIR" > /dev/stderr
     echo -e "software utilization\tflamegraph_secs\tlock_contention_secs/s\t=$SMP_PER_SEC" >> $SUM_FILE
     echo "========flamegraph samples= $LOCK_SECS, dura_secs= $DURA_SECS FL_TYP= $FLAME_TYP, samples/sec= $SMP_PER_SEC" > /dev/stderr
    fi
  fi
  SHEETS="$SHEETS $JAVA_COL_TR.tsv"
 fi
fi
TOPLEV_COL=(sys_*_toplev.csv)
if [ -e $TOPLEV_COL ]; then
  echo "do flamegraph.pl" 1>&2
  #echo "do toplev % Slots" > /dev/stderr
  $SCR_DIR/toplev_flame.sh -u "% Slots" -f $TOPLEV_COL > $TOPLEV_COL.collapsed_slots
  cat $TOPLEV_COL.collapsed_slots | perl $SCR_DIR/../flamegraph/flamegraph.pl --title "Flamegraph toplev $RPS" > toplev_slots.svg
  echo "do svg_to_html.sh " 1>&2
  $SCR_DIR/svg_to_html.sh -r 1 -d . -f toplev_slots.svg > toplev_slots.html
  inkscape -z  -w 2400 -j --export-file=toplev_slots.png  toplev_slots.svg
  $SCR_DIR/gen_flamegraph_for_java_in_container_function_hotspot.sh $TOPLEV_COL > $TOPLEV_COL.tsv
  SHEETS="$SHEETS $TOPLEV_COL.tsv"
fi
if [ "$SUM_FILE" != "" ]; then
   SHEETS="$SUM_FILE $SHEETS"
   RESP=`cat $SUM_FILE`
   echo -e "$RESP" | awk -v sum_file="$SUM_FILE" '
     BEGIN{
       ;
       got_RPS=0;
       #printf("------do_sum_file= %s\n", sum_file) > "/dev/stderr";
     }
     {
        lns[++lns_mx] = $0;
        n = split($0, arr, "\t");
        if (arr[2] == "RPS") {
          got_RPS=1;
          RPS = arr[4];
          if (substr(RPS, 1,1) == "=") {
            RPS = substr(RPS, 2, length(RPS)) + 0.0;
          }
        }
        #printf("%s\taa\n", $0);
     }
     END {
       beg = 0;
       for (i=1; i <= lns_mx; i++) {
        n = split(lns[i], arr, "\t");
        if (arr[1] == "hdrs") {
           beg = 1;
           arr[5] = 7;
        }
        if (arr[1] == "Resource") {
           if (got_RPS == 1) {
              arr[7] = "Val/1000_requests";
              n=7;
              printf("-----got_RPS= %s\n", got_RPS) > "/dev/stderr";
           }
        }
        if (beg == 1) {
          if (arr[1] != "Resource") {
          val = arr[4];
          if (substr(val, 1,1) == "=") {
            val = substr(val, 2, length(val));
          }
          arr[7] = "";
          if (got_RPS == 1 && RPS > 0.0 && index(arr[3], "/s") > 1) {
            nval = val / (0.001*RPS);
            arr[7] = nval;
            n = 7;
          }
          }
          printf("%s", arr[1]) > sum_file;
          for(j=2; j <= n; j++) {
            str = "";
            if (j==7 && arr[7] != "" && arr[1] != "Resource") { str = "=";}
            printf("\t%s%s", str, arr[j]) > sum_file;
          }
          printf("\n") > sum_file;
        } else {
          printf("%s\n", lns[i]) > sum_file;
        }
       }
       #close(sum_file);
     }
   ' 
   ck_last_rc $? $LINENO
fi
if [ "${#CPU2017LOG[@]}" -gt 0 -a "$PHASE_FILE" == "" ]; then
  RESP="${CPU2017LOG[@]}"
  echo "+++find $CPU2017LOG_RT_PATH -name cpu2017.*.log resp = $RESP"
  PH=`awk -v dir="$(pwd)" -v sum_file="$SUM_FILE" -v ofile="bmark.txt" '
    BEGIN{
        mx    = 0;
        bm_mx = 0;
        subphs_mx = 0;
    }
    #Workload elapsed time (copy 0 workload 1) = 67.605964 seconds
    /Workload elapsed time .copy .* workload .*. = .* seconds/ {
      pos = index($7, ")");
      subphs = $7; if (pos > 1) { subphs = substr(subphs, 1, pos); }
      sub_arr[subphs] = $9+0;
      subphs_mx = subphs;
    }
    #/Copy .* of .* (base refrate) run .* finished at .*.  Total elapsed time:/{
# Run 520.omnetpp_r base refrate ratio=22.93, runtime=915.660271, copies=16, threads=1, 
    /^ Run .* base refrate ratio=.*, runtime=.*, copies=.*,/{
        bm = $2;
        pos = index(dir, "cpus");
        pos0 = index(dir, "n1-");
        pos1 = index(dir, "n2-");
        pos2 = index(dir, "n2d-");
        if (pos > 0 || pos0 > 0 || pos1 > 0 || pos2 > 0) {
           n = split(dir, arr, "_");
           for (i=1; i <= n; i++) {
             pos = index(arr[i], "cpus");
             if (pos > 0) {
                cpus = substr(arr[i], 1, pos-1)+0;
             }
             pos = index(arr[i], "n1-");
             if (pos > 0) {
                cpus = substr(arr[i], pos+3, length(arr[i]))+0;
             } else {
               pos = index(arr[i], "n2-");
               if (pos > 0) {
                  cpus = substr(arr[i], pos+3, length(arr[i]))+0;
               } else {
                 pos = index(arr[i], "n2d-");
                 if (pos > 0) {
                    cpus = substr(arr[i], pos+4, length(arr[i]))+0;
                 }
               }
             }
           }
        }
        if (bm == "500.perlbench_r_1") { printf("bm= %s\n", bm)
        if (!(bm in bm_list)) {
          bm_list[bm] = ++bm_mx;
          bm_lkup[bm_mx] = bm;
          bm_vals[bm_mx] = 0;
        }
        bm_idx = bm_list[bm];
        bm_val = ++bm_vals[bm_idx];
        v = $5;
        n = split(v, arr, "=");
        gsub(",", "", arr[2]);
        rat = arr[2];
        v = $6;
        n = split(v, arr, "=");
        gsub(",", "", arr[2]);
        run_tm = arr[2];
        v = $7;
        n = split(v, arr, "=");
        gsub(",", "", arr[2]);
        copies = arr[2];
        bm_arr[bm_idx,bm_val,"ratio"] = rat;
        bm_arr[bm_idx,bm_val,"run_time"] = run_tm;
        bm_arr[bm_idx,bm_val,"copies"] = copies;
        printf("SpecInt benchmark\t%s\nratio\t%s\nrun_tm\t%s\ncopies\t%s\n", bm, rat, run_tm, copies) > ofile;
        printf("SpecInt\tSI benchmark\t%s\tSI %s ratio %s\n", rat, bm, bm_val) >> sum_file;
        printf("SpecInt\tSI benchmark\t%s\tSI %s run_time %s\n", run_tm, bm, bm_val) >> sum_file;
        printf("SpecInt\tSI benchmark\t%s\tSI %s copies %s\n", copies, bm, bm_val) >> sum_file;
        #printf("got cpu2017 line= %s\n", $4);
    }
# Run 520.omnetpp_r base refrate ratio=22.93, runtime=915.660271, copies=16, threads=1, 
    /Copy .* of .* .base refrate. run .* finished at .* Total elapsed time:/{
        bm = $4;
        #printf("got cpu2017 line= %s\n", $4);
    }
#Workload elapsed time (copy 0 workload 1) = 67.605964 seconds
    /Workload elapsed time .copy .* workload .*. = .* seconds/ {
       mx++;
       subphase[mx,1] = substr($7, 1, length($7)-1);
       subphase[mx,2] = $9+0.0;
    }
    /  Rate Start: /{
        s = $5;
        s = substr(s, 2,length(s)-2);
        tm_beg= s;
        #printf("tm_beg= %s\n", s);
    }
    /  Rate End: /{
        s = $5;
        s = substr(s, 2, length(s)-2);
        #printf("tm_end= %s\n", s);
        tm = tm_beg;
        for (i=1; i <= mx; i++) {
          elap = subphase[i,2];
          printf("%s_%s %.3f %.3f %.3f\n", bm, subphase[i,1], tm, tm+elap, elap);
          tm += elap;
        }
        #printf("%s %s %s %.3f\n", bm, tm_beg, s, s-tm_beg);
    }
function tot_compare(i1, v1, i2, v2,    l, r)
{
    m1 = arr[i1];
    m2 = arr[i2];
    if (m1 < m2)
        return -1
    else if (m1 == m2)
        return 0
    else
        return 1
}
    END{
       close(ofile);
       #The overall SPECrate metrics are calculated as a geometric mean from the individual benchmark SPECrate metrics using the median time from three runs or the slower of two runs, as explained above (rule 1.2.1).
       # Score_v2 just take the avg of the scores for each completed subtest and then new_score_v2 = .5*omne + .25*perl + .25*xalan
       valid = 1; # must have at least 1 score from each subtest (expect to have 3 xalancs, 2 perls, 1 omne)
       perl_i = 0;
       omne_i = 0;
       xalanc_i = 0;
       for(i=1; i <= bm_mx; i++) {
          if (index(bm_lkup[i], "perl") > 0) { perl_i = i; }
          if (index(bm_lkup[i], "omne") > 0) { omne_i = i; }
          if (index(bm_lkup[i], "xalanc") > 0) { xalanc_i = i; }
       }
       for(i=1; i <= bm_mx; i++) {
         #delete arr;
         #delete idx;
         sum = 0.0;
         n   = 0;
         for(j=1; j <= bm_vals[i]; j++) {
            sum += bm_arr[i,j,"ratio"];
            n++;
            #idx[j] = j;
         }
         if (n == 0) {
           valid = 0;
         } else {
           varr[i] = sum/n;
         }
         #asorti(idx, res_i, "tot_compare")
         #if (bm_vals[i] <= 2 ) {
         #   v = arr[res_i[1]];
         #} else if (bm_vals[i] == 3) {
         #   v = arr[res_i[1]];
         #}
         #varr[i] = v;
       }
       #x = varr[1];
       #printf("SI new score[1]= %.3f\n", x) > "/dev/stderr";
       #for(i=2; i <= bm_mx; i++) {
       #   printf("SI new score[%d]= %.3f\n", i, varr[i]) > "/dev/stderr";
       #   x *= varr[i];
       #}
       if (valid == 0) {
         str = "bad";
         y = 0.0;
       } else {
         str = "ok";
         y = 0.25 * varr[perl_i] + 0.25 * varr[xalanc_i] + 0.5 * varr[omne_i];
         z = varr[perl_i] + varr[xalanc_i] + varr[omne_i];
         z3 = (cpus > 0.0 ? z /= cpus : 0.0);
       }
       str = sprintf("%s.%d.%d.%d", str, bm_vals[omne_i], bm_vals[perl_i], bm_vals[xalanc_i]);
       printf("SpecInt\tSI benchmark\t%s\tSI new score_v2 valid? omnetpp.perlbench.xalanc\n", str) >> sum_file;
       printf("SI new score_v2= %.3f, bm_mx= %f\n", y, bm_mx) > "/dev/stderr";
       printf("SpecInt\tSI benchmark\t%s\tSI new score_v2\n", y) >> sum_file;
       printf("SpecInt\tSI benchmark\t%s\tSI NCU score_v3\n", z3) >> sum_file;
       printf("SpecInt\tSI benchmark\t%s\tSI cpus\n", cpus) >> sum_file;
    }
    ' $RESP`
   ck_last_rc $? $LINENO
  echo  -e "$PH" > phase_cpu2017.txt
  PHASE_FILE=phase_cpu2017.txt
fi

if [ "$PHASE_FILE" == "" ]; then
  if [ -e phase.txt ]; then
    echo "got phase.txt file"
    PHASE_FILE=phase.txt
  fi
  if [ -e ../phase.txt ]; then
    echo "got ../phase.txt file"
    PHASE_FILE=../phase.txt
  fi
fi


  RESP=`find . -name "muttley*.json.tsv" | wc -l | awk '{$1=$1;print}'`
  echo "find muttley RESP= $RESP"
  if [ "1" == "2" ]; then
    # lets not do this right now
  if [ "$RESP" != "0" ]; then
    RESP=`find . -name "muttley*.json.tsv" | xargs`
    echo "+++++++++++++++ multtley RESP= $RESP"
    awk -v cur_dir="$(pwd)" -v sum_file="$SUM_FILE" '
       BEGIN { mx=0; mx_val=-1; }
       /^title/ {
         mx++;
         n = split($0, arr, "\t");
         if (arr[2] == "") {
           arr[2] = "RPS by service";
         }
         sv[mx,"title"] = arr[2];
       }
       /^1/ {
         n = split($0, arr, "\t");
         for (i=3; i <= NF; i++) {
         val = arr[i]+0.0;
         if (sv[mx,"max"] == "" || sv[mx,"max"] < val) {
             sv[mx,"max"] = val;
         }
         if (sv[mx,"min"] == "" || sv[mx,"min"] < val) {
             sv[mx,"min"] = val;
         }
         }
       }
       END{
         for (i=1; i <= mx; i++) {
            #printf("\tm3\t%s\tmax %s  and cur_dir= %s sum_file= %s\n", sv[i,"title"], sv[i,"max"], cur_dir, sum_file) > "/dev/stderr";
            printf("\tm3\t%s\tmax %s\n", sv[i,"title"], sv[i,"max"]) >> sum_file;
            printf("\tm3\t%s\tmin %s\n", sv[i,"title"], sv[i,"min"]) >> sum_file;
         }
       }' $RESP
    ck_last_rc $? $LINENO
    SHEETS="$SHEETS $RESP"
  fi
  fi

echo "SHEETS= $SHEETS SKIP_XLS= $SKIP_XLS, xls_fl= $XLSX_FILE avg= $AVERAGE"
if [ "$SHEETS" != "" -a "$SKIP_XLS" == "0" ]; then
   OPT_I=
   MET_AV=metric_out.average
   NM=$(basename "$XLSX_FILE")
   if [ ! -e $MET_AV ]; then
     MET_AV=metric_out.average.csv
   fi
   if [ -e $SUM_TMAM_FILE ]; then
     MET_AV=$SUM_TMAM_FILE
     echo "below is sum_tmam_file $SUM_TMAM_FILE for $NM"
     cp $SUM_TMAM_FILE $NM.sum_tmam.tsv
     cat $SUM_TMAM_FILE
   fi
   if [ -e $MET_AV ]; then
      echo "do flamegraph.pl -f $MET_AV nm= $NM xlxs=$XLSX_FILE" > /dev/stderr
      $SCR_DIR/itp_flame.sh -f $MET_AV -c tmp_flamegraph.jnk
      cat tmp_flamegraph.jnk | perl $SCR_DIR/../flamegraph/flamegraph.pl --title "ITP Flamegraph $NM" > $NM.svg
      echo "do svg_to_html.sh " > /dev/stderr
      $SCR_DIR/svg_to_html.sh -r 1 -d .  > $NM.html
      inkscape -z  -w 2400 -j --export-file=$NM.png  $NM.svg
      OPT_I=" -i \"*.png\" "
   fi
   OPT_PH=
   if [ "$PHASE_FILE" != "" ]; then
     OPT_PH=" -P $PHASE_FILE "
   fi
   OPT_M=
   if [ "$MAX_VAL" != "" ]; then
     OPT_M=" -m $MAX_VAL "
   fi
   OPT_C=
   if [ "$CLIP" != "" ]; then
     OPT_C=" -c $CLIP "
   fi
   OPT_O=
   if [ "$OPTIONS" != "" ]; then
     OPT_O=" -O $OPTIONS "
   fi
   OPT_TM=
   if [ "$BEG_TM_IN" != "" ]; then
     OPT_TM=" -b $BEG_TM_IN "
   fi
   if [ "$END_TM" != "" ]; then
     OPT_TM="$OPT_TM -e $END_TM "
   fi
   if [ "$AVERAGE" == "0" ]; then
     echo "for python: SKIP_XLS= $SKIP_XLS" > /dev/stderr
     # default chart size is pretty small, scale chart size x,y by 2 each. def 1,1 seems to be about 15 rows high (on my MacBook)
     echo python $SCR_DIR/tsv_2_xlsx.py -s 2,2 -p "$PFX" $OPT_I $OPT_TM $OPT_a $OPT_O $OPT_M -o $XLSX_FILE $OPT_C $OPT_PH -i "$IMAGE_STR" $SHEETS > /dev/stderr
          python $SCR_DIR/tsv_2_xlsx.py -s 2,2 -p "$PFX" $OPT_I $OPT_TM $OPT_a $OPT_O $OPT_M -o $XLSX_FILE $OPT_C $OPT_PH -i "$IMAGE_STR" $SHEETS
          ck_last_rc $? $LINENO
          echo "$0: tsv_2_xlsx.py exit with RC= $RC at line= $LINENO" > /dev/stderr
     if [ "$DIR" == "." ];then
       UDIR=`pwd`
     else
       UDIR=$DIR
     fi
     echo "xls file: " > /dev/stderr
     echo "$UDIR/$XLSX_FILE" > /dev/stderr
   fi
fi
  if [ -e $SUM_FILE ]; then
    if [ "$ck_for_null" == "0" ]; then
      ckck=`pwd`
      grep -E  '\x00' $SUM_FILE
      RC=$?
      if [ "$RC" == "1" ]; then
        echo "ck_for_null_0: no  null char in sum_file $SUM_FILE  dir= $ckck"
        break
      fi
      if [ "$RC" == "0" ]; then
        echo "ck_for_null_0: got null char in sum_file $SUM_FILE  dir= $ckck"
      fi
    fi
    if [ "$ck_for_null" == "1" ]; then
      grep -E  '\x00' $SUM_FILE
      RC=$?
      if [ "$RC" == "1" ]; then
        echo "ck_for_null_1: got null char in sum_file $SUM_FILE  dir= $ckck"
      fi
      if [ "$RC" == "0" ]; then
        echo "ck_for_null_1: no  null char in sum_file $SUM_FILE  dir= $ckck"
      fi
    fi
  fi
done
exit 0

