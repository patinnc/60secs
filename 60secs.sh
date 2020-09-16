#!/bin/bash
#
# see http://www.brendangregg.com/Articles/Netflix_Linux_Perf_Analysis_60s.pdf
# usage arg1 

GOT_QUIT=0
# function called by trap
catch_signal() {
    printf "\rSIGINT caught      "
    GOT_QUIT=1
}

trap 'catch_signal' SIGINT

MYBASHPID=$BASHPID
echo "$BASHPID" > ~/60secs.pid

SCR_DIR=`dirname "$(readlink -f "$0")"`
WAIT=60
# renamed task 'top' to 'do_top' to avoid conflict with toplev
TASKS=("uptime" "dmesg" "vmstat" "mpstat" "pidstat" "iostat" "free" "nicstat" "sar_dev" "sar_tcp" "do_top" "perf" "sched_switch" "interrupts" "flamegraph" "toplev" "power" "watch")
j=0
for i in ${TASKS[@]}; do
  j=$((j+1))
done
TLAST=$j
echo "usage: $0 -t task_num|task_name -d seconds_to_run -i sample_interval_in_secs"
echo "task_num is 0 to $TLAST or -1 for all tasks"
echo "seconds_to_run is how long you want each task to monitor the system. Defaults is $WAIT seconds."
echo "data collected once a second till for $WAIT seconds."
echo "task_names are: ${TASKS[@]}"
VERBOSE=0
INTRVL=1
TSK_IN=
WAIT_IN=
PERF_BIN=
BKGRND=0
WAIT_AT_END=0
CURL_AT_END=0
DO_SCHED_SWITCH=0
DO_FLAMEGRAPH=0
DO_TOPLEV=0
DO_POWER=0
CONTAINER=
EXCLUDE=
EVT_IN=
RUN_CMDS_LOG=run.log
myArgs="$((($#)) && printf ' %q' "$@")"
tstmp=`date "+%Y%m%d_%H%M%S"`
ts_beg=`date "+%s.%N"`
echo "$tstmp start $myArgs"  >> $RUN_CMDS_LOG

while getopts "hvbcwa:C:d:E:i:p:t:W:x:" opt; do
  case ${opt} in
    a )
      ADD_IN=$OPTARG
      ;;
    b )
      BKGRND=1
      ;;
    c )
      CURL_AT_END=1
      ;;
    C )
      CONTAINER=$OPTARG
      ;;
    E )
      EVT_IN=$OPTARG
      ;;
    w )
      WAIT_AT_END=1
      ;;
    d )
      WAIT_IN=$OPTARG
      ;;
    i )
      INTERVAL=$OPTARG
      ;;
    W )
      WATCH_IN="$OPTARG"
      echo "WATCH_IN $OPTARG" > /dev/stderr
      ;;
    x )
      EXCLUDE=$OPTARG
      ;;
    p )
      if [ "$OPTARG" != "" -a ! -x $OPTARG ]; then
        echo "didn't find perf binary. You entered \"-p $OPTARG\""
        exit
      fi
      PERF_BIN=$OPTARG
      ;;
    t )
      TMPARG=$OPTARG
      if [ "$TMPARG" == "all" ]; then
        TSK_IN="-1"
      else
        TSK_IN=$TMPARG
         if [ "$TMPARG" == "sched_switch" ]; then
           DO_SCHED_SWITCH=1
         fi
         if [ "$TMPARG" == "flamegraph" ]; then
           DO_FLAMEGRAPH=1
         fi
         if [[ $TMPARG == *"toplev"* ]]; then
           DO_TOPLEV=1
         fi
         if [[ $TMPARG == *"power"* ]]; then
           DO_POWER=1
         fi
      fi
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "usage: $0 -t task_num|task_name[,taskname[...]] [ -b ] -d seconds_to_run -i sample_interval_in_secs [ -p full_path_of_perf_binary ]"
      echo "task_num is 0 to $TLAST or -1 for all tasks"
      echo "seconds_to_run is how long you want each task to monitor the system. Defaults is $WAIT seconds."
      echo "data collected once a second till for $WAIT seconds."
      echo "task_names are: ${TASKS[@]}"
      echo "   -t task_num or task_name"
      echo "      The task names: ${TASKS[@]}"
      echo "      Enter '-t all' for all tasks except flamegraph and sched_switch (sched_switch which can write 100s of MBs of data per 10 sec interval... so it has more overhead)"
      echo "      Valid task_num range is 0 to $TLAST"
      echo "      Currently toplev and power tasks block and can't be run in the background."
      echo "      Enter either the number or the task name in a comma separated list"
      echo "      default is no task"
      echo "   -a flamegraph and/or sched_switch"
      echo "      if you do '-t all' flamegraph and sched_switch are not run"
      echo "      Use this option to add flamegraph and or sched_switch"
      echo "   -x task_num or task_name"
      echo "      A list of tasks to be excluded. do_top and interrupts are not too useful to me"
      echo "      Have to enter the task name, not number"
      echo "   -b start the jobs in the backgroup not waiting for each job to finish"
      echo "      The default is to not start the jobs the background (so start the 1st task, wait for it to finish, start the next task, etc)"
      echo "   -w If you run background mode, this option waits for the duration after the background jobs are started."
      echo "   -c use this option to run ${SCR_DIR}/do_curl.sh at the end"
      echo "   -C container ID to pass to ${SCR_DIR}/do_curl.sh and/or flamegraph script"
      echo "   -d time_in_seconds duration of each monitoring task in seconds"
      echo "      You can append an 'm' to specify the duration in minutes (like '-d 10m' which sets the duration to 600 seconds)"
      echo "      default is $WAIT seconds"
      echo "   -i interval in seconds between data collection"
      echo "      default is $INTRVL seconds"
      echo "   -E evt_str   for gen_flamegraph_for_java_in_container.sh"
      echo "      This is optional. Can be itimer or lock. Used for specifying the event for the flamegraph sampling of java"
      echo "      default is itimer"
      echo "   -p full_path_to_perf_binary  the perf binary might not be in the path so use this option to specify it"
      echo "      default is 'perf'"
      echo "   -W cmd  cmd to execute every -i seconds. Enclose cmd in dbl quotes"
      echo "      default is to not do a watch cmd"
      echo "   -v verbose mode. display each file after creating it."
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

if [ "$PERF_BIN" == "" ]; then
  PERF_BIN=$SCR_DIR/perf
fi
if [ "$ADD_IN" != "" ]; then
  if [[ $ADD_IN == *"toplev"* ]]; then
     DO_TOPLEV=1
  fi
  if [[ $ADD_IN == *"power"* ]]; then
     DO_POWER=1
  fi
  if [[ $ADD_IN == *"flamegraph"* ]]; then
     DO_FLAMEGRAPH=1
  fi
  if [[ $ADD_IN == *"sched_switch"* ]]; then
     DO_SCHED_SWITCH=1
  fi
fi

echo "DO_TOPLEV= $DO_TOPLEV"

if [ "$TSK_IN" == "" ]; then
  echo "You must enter arg1: '-t task_num|task_name' where all (all tasks) or a task_number (0-$TLAST) or a task_name"
  exit
fi

if [ "$TSK_IN" == "-1" ]; then
  TSK=$TSK_IN
fi
if [ "$CONTAINER" != "" ]; then
  RESP=`docker ps | awk -v cntr="$CONTAINER" 'BEGIN{rc=0;}{if ($1 == cntr) {rc=1;}} END{printf("%d\n", rc);}'`
  echo "got docker cntr= $RESP"
  if [ "$RESP" == "1" ]; then
    echo "got match on docker cntr= $CONTAINER"
  else
    echo "missed match on docker cntr= $CONTAINER"
    exit
  fi
fi

jmx=0
t=0
TSK_LST=()
TSK_NUM=()
for i in ${TASKS[@]}; do
  if [[ $TSK_IN == *"$i"* ]]; then
    TSK=$i
    TSK_LST[$jmx]=$i
    TSK_NUM[$jmx]=$t
    printf "You selected task_name $i\n"
    jmx=$((jmx+1))
    #break
  fi
  if [ "$TSK_IN" == "-1" ]; then
    TSK=$i
    TSK_LST[$jmx]=$i
    TSK_NUM[$jmx]=$t
    printf "You selected task_name $i by -t -1\n"
    jmx=$((jmx+1))
    #break
  fi
  if [ "$TSK_IN" == "$t" ]; then
    TSK=$i
    TSK_LST[$jmx]=$i
    TSK_NUM[$jmx]=$t
    printf "You selected task_name $i which is task_num $t\n"
    break
  fi
  t=$((t+1))
done



if [ $jmx -eq 0 ]; then
  echo "you entered invalid task name or number $TSK_IN"
  echo "valid task_num is 0 to $TLAST"
  echo "valid task_names: ${TASKS[@]}"
  exit
else
  jmx=$((jmx-1))
fi

if [ "$WAIT_IN" != "" ]; then
  RESP=`echo $WAIT_IN | sed 's/m//i'`
  if [ "$RESP" != "$WAIT_IN" ]; then
    WAIT_IN=$((RESP*60))
  fi
  RESP=`echo $WAIT_IN | sed 's/h//i'`
  if [ "$RESP" != "$WAIT_IN" ]; then
    WAIT_IN=$((RESP*3600))
  fi
  re='^[0-9]+$'
  if ! [[ $WAIT_IN =~ $re ]] ; then
     echo "error: duration -d $WAIT_IN is not a number" >&2; exit 1
  fi
  if [ $WAIT_IN -lt 1 ]; then
    echo "you entered \"-d $WAIT_IN\" duration must be > 1"
    exit
  fi
  WAIT=$WAIT_IN
fi
echo "using interval $WAIT seconds"

if [ "$INTERVAL" != "" ]; then
  re='^[0-9]+$'
  if ! [[ $INTERVAL =~ $re ]] ; then
     echo "error: interval -i $INTERVAL is not a number" >&2; exit 1
  fi
  if [ $INTERVAL -lt 1 ]; then
    echo "you entered \"-i $INTERVAL\" duration must be > 0"
    exit
  fi
  INTRVL=$INTERVAL
fi
echo "using interval $INTRVL seconds"

if [ "$TSK" == "-1" ]; then
 TB=0
 TE=$TLAST
else
 TB=0
 TE=$jmx
fi

COUNT=$(($WAIT/$INTRVL))
if [ $COUNT -lt 1 ]; then
  COUNT=1
fi
echo "count= $COUNT for interval= $INTRVL and wait= $WAIT"

lscpu > lscpu.log

echo "going to do task $TB to $TE"

LOG=60secs.log
if [ -e $LOG ]; then
  rm $LOG
fi

CPU_DECODE=`${SCR_DIR}/decode_intel_fam_mod.sh`

NANO=".%N"
tdte=`date "+${NANO}"`
if [ "$tdte" == ".N" ]; then
 NANO=
fi
 
GOT_ERR=0
RESP=`which lscpu | wc -l | sed 's/ //g'`
if [ "$RESP" == "0" ]; then
   echo "lscpu not found. You need to install lscpu: sudo apt-get install lscpu" 1>&2
   GOT_ERR=1
fi

for TSKj in `seq $TB $TE`; do
  TSK=${TSK_LST[$TSKj]}
  TSKNUM=${TSK_NUM[$TSKj]}
  echo "checking $TSK ${TSK_LST[$TSKj]}"
  if [[ $TSK == *"sar"* ]]; then
     RESP=`which sar | wc -l | sed 's/ //g'`
     if [ "$RESP" == "0" ]; then
        echo "sar not found. You need to install sar: sudo apt-get install sysstat" 1>&2
        GOT_ERR=1
     fi
  fi
  if [[ $TSK == *"perf"* ]]; then
     RESP=`which $PERF_BIN | wc -l | sed 's/ //g'`
     if [ "$RESP" == "0" ]; then
        echo "perf binary \"$PERF_BIN\" not found. Either install it or use the cmdline option -p /path_to/perf_binary" 1>&2
        GOT_ERR=1
     else
        echo "which prf wc -l resp= \"$RESP\""
     fi
  fi
  if [[ $TSK == *"flamegraph"* ]]; then
     if [ "$DO_FLAMEGRAPH" == "1" ]; then
     if [ "$CONTAINER" == "" ]; then
        echo "flamegraph option requires a container ID. run 'docker ps' to get IDs and add option '-C containerID'" 1>&2
        GOT_ERR=1
     fi
     fi
  fi
  if [[ $TSK == *"nicstat"* ]]; then
     RESP=`which nicstat | wc -l | sed 's/ //g'`
     if [ "$RESP" == "0" ]; then
        echo "nicstat not found. You need to install nicstat: sudo apt-get install nicstat" 1>&2
        GOT_ERR=1
     fi
  fi
  if [[ $TSK == *"mpstat"* ]]; then
     RESP=`which mpstat | wc -l | sed 's/ //g'`
     if [ "$RESP" == "0" ]; then
        echo "mpstat not found. You need to install mpstat: sudo apt-get install mpstat" 1>&2
        GOT_ERR=1
     fi
  fi
  if [[ $TSK == *"vmstat"* ]]; then
     RESP=`which vmstat | wc -l | sed 's/ //g'`
     if [ "$RESP" == "0" ]; then
        echo "vmstat not found. You need to install vmstat: sudo apt-get install vmstat" 1>&2
        GOT_ERR=1
     fi
  fi
  if [[ $TSK == *"pidstat"* ]]; then
     RESP=`which pidstat | wc -l | sed 's/ //g'`
     if [ "$RESP" == "0" ]; then
        echo "pidstat not found. You need to install pidstat: sudo apt-get install pidstat" 1>&2
        GOT_ERR=1
     fi
  fi
done
if [ "$GOT_ERR" == "1" ]; then
  echo "fix errors please" 1>&2
  exit
fi

if [ "$EXCLUDE" != "" ]; then
  IFS=',' read -r -a ex_arr <<< "$EXCLUDE"
fi

NEED_TO_END_FLAMEGRAPH=0
NEED_PERF_SCRIPT=

for TSKj in `seq $TB $TE`; do
  TSK=${TSK_LST[$TSKj]}
  TSKNUM=${TSK_NUM[$TSKj]}
  skip_it=0
  for skp in "${ex_arr[@]}"; do
    if [ "$skp" == "$TSK" ]; then
      echo "skip task $TSK due to -x $EXCLUDE"
      skip_it=1
      break
    fi
  done
  if [ "$skip_it" == "1" ]; then
    continue
  fi
  echo "doing $TSK ${TSK_LST[$TSKj]}"
  FLNUM=$(printf "%02d" $TSKNUM)
  #echo FLNUM= $FLNUM
  dt=`TZ=":US/Pacific" date`
  dtc=`date`
  dte=`date "+%s${NANO}"`
  echo "date= $dt $dte"
  echo "start $TSK at $dtc $dte" >> $LOG
  FL=

  if [[ $TSK == *"uptime"* ]]; then
    echo "do uptime for $WAIT secs"
    FL=sys_${FLNUM}_uptime.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    j=0
    if [ "$BKGRND" == "1" ]; then
      FL_UPTM=$FL
    else
    for i in `seq 1 $WAIT`; do
      #echo "i= $i of $WAIT"
      printf "i= %d of %d\n" $i $WAIT
      uptime >> $FL
      j=$((j+$INTRVL))
      if [ $j -ge $WAIT ]; then
        break
      fi
      sleep $INTRVL
      if [ "$GOT_QUIT" == "1" ]; then
         break
      fi
    done
    printf "\n"
    fi
  fi
  
  if [[ $TSK == *"dmesg"* ]]; then
    echo "dmesg: waiting $WAIT secs and doing dmesg"
    FL=sys_${FLNUM}_dmesg.txt
    #dmesg |tail > $FL
    echo "wait for $WAIT seconds"
    BEG=`cat /proc/uptime | awk '{printf("%.0f\n", $1+0);}'`
    dmesg |tail > $FL
    if [ "$BKGRND" == "1" ]; then
      FL_DMSG=$FL
      BEG_DMSG=$BEG
    else
    echo "wait for $WAIT seconds. Will look for lines after current timestamp $BEG"
    sleep $WAIT
    dmesg >> $FL
    if [ $VERBOSE -gt 0 ]; then
    awk -v TS="$BEG" '
      BEGIN {got_ln=0; ts=TS+0.0;beg=0; printf("current timestamp for dmesg= %.0f\n", ts);}
      { 
        tm=substr($1, 2, length($1)-2) + 0.0;
        #printf("tm= %s, ts= %s\n", tm, ts);
        if (tm >= ts) {
          printf("%s\n", $0);
          got_ln++;
        }
     }
     END{
      printf("got %d new lines in dmesg output after timestamp %.0f\n", got_ln, ts);
      printf("got %d new lines in dmesg output after timestamp %.0f\n", got_ln, ts) > "/dev/stderr";
     }
     ' $FL
    fi
    printf "\ncurrent timestamp for dmesg= $BEG\nwait for $WAIT seconds\n" >> $FL
    fi
  fi
  
  if [[ $TSK == *"vmstat"* ]]; then
    echo "do vmstat $INTRVL $COUNT"
    FL=sys_${FLNUM}_vmstat.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    if [ "$BKGRND" == "0" ]; then
      vmstat $INTRVL $COUNT > $FL
    else
      vmstat $INTRVL $COUNT > $FL &
      TSK_PID[$TSKj]=$!
    fi
  fi
  
  if [[ $TSK == *"mpstat"* ]]; then
    echo "do mpstat ­P ALL $INTRVL $COUNT"
    FL=sys_${FLNUM}_mpstat.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    if [ "$BKGRND" == "0" ]; then
      mpstat -P ALL $INTRVL $COUNT > $FL
    else
      mpstat -P ALL $INTRVL $COUNT > $FL &
      TSK_PID[$TSKj]=$!
    fi
  fi
  
  if [[ $TSK == *"pidstat"* ]]; then
    echo "do pidstat -du $INTRVL $COUNT"
    FL=sys_${FLNUM}_pidstat.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    if [ "$BKGRND" == "0" ]; then
      pidstat -du $INTRVL $COUNT > $FL
    else
      pidstat -du $INTRVL $COUNT > $FL &
      TSK_PID[$TSKj]=$!
    fi
  fi
  
  if [[ $TSK == *"iostat"* ]]; then
    echo "do iostat -xtz $INTRVL $COUNT"
    FL=sys_${FLNUM}_iostat.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    if [ "$BKGRND" == "0" ]; then
      iostat -xtz $INTRVL $COUNT > $FL
    else
      iostat -xtz $INTRVL $COUNT > $FL &
      TSK_PID[$TSKj]=$!
    fi
  fi
  
  if [[ $TSK == *"free"* ]]; then
    echo "do free -m -s $INTRVL -c $COUNT"
    FL=sys_${FLNUM}_free.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    if [ "$BKGRND" == "0" ]; then
      free -m -s $INTRVL -c $COUNT > $FL
    else
      free -m -s $INTRVL -c $COUNT > $FL &
      TSK_PID[$TSKj]=$!
    fi
  fi
  
  if [[ $TSK == *"sar_dev"* ]]; then
    echo "do sar -n DEV $INTRVL $COUNT"
    FL=sys_${FLNUM}_sar_dev.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    if [ "$BKGRND" == "0" ]; then
      sar -n DEV $INTRVL $COUNT > $FL
    else
      sar -n DEV $INTRVL $COUNT > $FL &
      TSK_PID[$TSKj]=$!
    fi
  fi
  
  if [[ $TSK == *"sar_tcp"* ]]; then
    echo "do sar -n TCP,ETCP $INTRVL $COUNT"
    FL=sys_${FLNUM}_sar_tcp.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    if [ "$BKGRND" == "0" ]; then
      sar -n TCP,ETCP $INTRVL $COUNT > $FL
    else
      sar -n TCP,ETCP $INTRVL $COUNT > $FL &
      TSK_PID[$TSKj]=$!
    fi
  fi
  
  if [[ $TSK == *"do_top"* ]]; then
    echo "do top -b -d $INTRVL -n $COUNT"
    FL=sys_${FLNUM}_top.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    if [ "$BKGRND" == "0" ]; then
      top -b -d $INTRVL -n $COUNT > $FL
    else
      top -b -d $INTRVL -n $COUNT > $FL &
      TSK_PID[$TSKj]=$!
    fi
  fi
  
  if [[ $TSK == *"perf"* ]]; then
    FL=sys_${FLNUM}_perf_stat.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    ms=$(($INTRVL*1000))
    EVT=
    echo "do perf stat for $WAIT secs"
    if [ "$CPU_DECODE" == "Broadwell" -o "$CPU_DECODE" == "Haswell" ]; then
    IMC0_RDWR="uncore_imc_0/name='unc0_read_write',umask=0x0f,event=0x04/"
    IMC1_RDWR="uncore_imc_1/name='unc1_read_write',umask=0x0f,event=0x04/"
    IMC2_RDWR="uncore_imc_2/name='unc2_read_write',umask=0x0f,event=0x04/"
    IMC3_RDWR="uncore_imc_3/name='unc3_read_write',umask=0x0f,event=0x04/"
    IMC4_RDWR="uncore_imc_4/name='unc4_read_write',umask=0x0f,event=0x04/"
    EVT=",$IMC0_RDWR,$IMC1_RDWR,$IMC2_RDWR,$IMC3_RDWR,$IMC4_RDWR,qpi_data_bandwidth_tx,qpi_ctl_bandwidth_tx"
    fi
    if [ "$CPU_DECODE" == "Skylake" ]; then
    IMC0_RDWR="uncore_imc_0/name='unc0_read_write',umask=0x0f,event=0x04/"
    IMC1_RDWR="uncore_imc_1/name='unc1_read_write',umask=0x0f,event=0x04/"
    IMC2_RDWR="uncore_imc_2/name='unc2_read_write',umask=0x0f,event=0x04/"
    IMC3_RDWR="uncore_imc_3/name='unc3_read_write',umask=0x0f,event=0x04/"
    IMC4_RDWR="uncore_imc_4/name='unc4_read_write',umask=0x0f,event=0x04/"
    #EVT=$IMC0_RDWR,$IMC1_RDWR,$IMC2_RDWR,$IMC3_RDWR,$IMC4_RDWR
    EVT=",$IMC0_RDWR,$IMC1_RDWR,$IMC2_RDWR,$IMC3_RDWR,$IMC4_RDWR,qpi_data_bandwidth_tx,qpi_ctl_bandwidth_tx"
    fi
    if [ "$CPU_DECODE" == "Cascade Lake" ]; then
    IMC0_RDWR="uncore_imc_0/name='unc0_read_write',umask=0x0f,event=0x04/"
    IMC1_RDWR="uncore_imc_1/name='unc1_read_write',umask=0x0f,event=0x04/"
    IMC2_RDWR="uncore_imc_2/name='unc2_read_write',umask=0x0f,event=0x04/"
    IMC3_RDWR="uncore_imc_3/name='unc3_read_write',umask=0x0f,event=0x04/"
    IMC4_RDWR=
    if [ -e /sys/devices/uncore_imc_4 ]; then
      IMC4_RDWR="uncore_imc_4/name='unc4_read_write',umask=0x0f,event=0x04/"
    fi
    IMC5_RDWR=
    if [ -e /sys/devices/uncore_imc_5 ]; then
      IMC5_RDWR=",uncore_imc_5/name='unc5_read_write',umask=0x0f,event=0x04/"
    fi
    UIP0=
    UIP1=
    UIP2=
    if [ -e /sys/devices/uncore_upi_0 ]; then
     UPI0=",uncore_upi_0/event=0x02,umask=0x0f,name='qpi_data_bandwidth_tx0'/"
    fi
    if [ -e /sys/devices/uncore_upi_1 ]; then
     UPI1=",uncore_upi_1/event=0x02,umask=0x0f,name='qpi_data_bandwidth_tx1'/"
    fi
    if [ -e /sys/devices/uncore_upi_2 ]; then
     UPI2=",uncore_upi_2/event=0x02,umask=0x0f,name='qpi_data_bandwidth_tx2'/"
    fi
    EVT=",$IMC0_RDWR,$IMC1_RDWR,$IMC2_RDWR,$IMC3_RDWR,$IMC4_RDWR${IMC5_RDWR}${UPI0}${UPI1}${UPI2}"
    fi
    EVT="instructions,cycles,ref-cycles,LLC-load-misses${EVT}"
    echo "do: $PERF_BIN stat -x \";\"  --per-socket -a -I $ms -o $FL -e $EVT" > /dev/stderr
    echo "do: $PERF_BIN stat -x \";\"  --per-socket -a -I $ms -o $FL -e $EVT" 
    $PERF_BIN stat -x ";"  --per-socket -a -I $ms -o $FL -e $EVT sleep $WAIT &
    TSK_PID[$TSKj]=$!
    PRF_PID=$!
  fi

  if [[ $TSK == *"sched_switch"* ]]; then
    if [ "$DO_SCHED_SWITCH" == "1" ]; then
      FL=sys_${FLNUM}_sched_switch.dat
      if [ -e $FL ]; then
        rm $FL
      fi
      ms=$(($INTRVL*1000))
      echo "do perf stat for $WAIT secs"
      EVT="sched:sched_switch"
      echo $PERF_BIN record -k CLOCK_MONOTONIC  -a -o $FL -e $EVT sleep $WAIT
           $PERF_BIN record -k CLOCK_MONOTONIC  -a -o $FL -e $EVT sleep $WAIT &
      TSK_PID[$TSKj]=$!
      PRF2_PID=$!
      NEED_PERF_SCRIPT=$FL
    fi
  fi

  if [[ $TSK == *"flamegraph"* ]]; then
    if [ "$DO_FLAMEGRAPH" == "1" ]; then
    FL=sys_${FLNUM}_flamegraph.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    OPT_E=
    if [ "$EVT_IN" != "" ]; then
      OPT_E=" -E $EVT_IN "
    fi
    echo ${SCR_DIR}/gen_flamegraph_for_java_in_container.sh -C $CONTAINER -a start $OPT_E
         ${SCR_DIR}/gen_flamegraph_for_java_in_container.sh -C $CONTAINER -a start $OPT_E &> gen_fl_start.log
    if [ "$BKGRND" == "0" ]; then
      sleep $WAIT
      ${SCR_DIR}/gen_flamegraph_for_java_in_container.sh -C $CONTAINER -a stop &> gen_fl_stop.log
    else
      NEED_TO_END_FLAMEGRAPH=1
    fi
    fi
  fi

  if [[ $TSK == *"toplev"* ]]; then
    if [ "$DO_TOPLEV" == "1" ]; then
    FL=sys_${FLNUM}_toplev
    if [ -e $FL.csv ]; then
      rm $FL.csv
    fi
    echo "sysctl kernel.nmi_watchdog=0 && export PERF=$PERF_BIN && python ${SCR_DIR}/pmu-tools-master/toplev.py -l3  -x, --no-multiplex  -o $FL.csv -v --per-core --nodes +CPU_Utilization  -- sleep $INTRVL"
          sysctl kernel.nmi_watchdog=0 && export PERF=$PERF_BIN && python ${SCR_DIR}/pmu-tools-master/toplev.py -l3  -x, --no-multiplex  -o $FL.csv -v --per-core --nodes +CPU_Utilization  -- sleep $INTRVL
    echo "finished toplev" > /dev/stderr
    $SCR_DIR/toplev_flame.sh $FL.csv > $FL.collapsed
    fi
    if [ "$DO_TOPLEV" == "1" ]; then
      echo "=======did toplev ========="
      #break
    fi
  fi
  if [[ $TSK == *"power"* ]]; then
    if [ "$DO_POWER" == "1" ]; then
    FL=sys_${FLNUM}_power.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    echo "ipmitool sdr"
    j=0
    BDT=`date +%s`
    EDT=$((BDT+$WAIT))
    if [ "$BKGRND" == "1" ]; then
      FL_PWR=$FL
    else
    for i in `seq 1 $WAIT`; do
      #echo "i= $i of $WAIT"
      DT=`date +%s.%N`
      echo "==beg $j date $DT" >> $FL
      ipmitool sdr >> $FL
      CDT=`date +%s`
      ELAP=$(($CDT-$BDT))
      j=$((j+$INTRVL))
      if [ $j -ge $WAIT ]; then
        break
      fi
      if [ $CDT -ge $EDT ]; then
        break
      fi
      printf "power i= %d of %d, elap secs= %d curtm= %d, endtm= %d\n" $i $WAIT $ELAP $CDT  $EDT
      sleep $INTRVL
      if [ "$GOT_QUIT" == "1" ]; then
         break
      fi
    done
    printf "\n"
    fi
    if [ "$DO_POWER" == "1" ]; then
      echo "=======did power ========="
      break
    fi
    fi
  fi
  if [[ $TSK == *"watch"* ]]; then
    if [ "$WATCH_IN" == "null" ]; then
       WATCH_IN=
    fi
    if [ "$WATCH_IN" != "" ]; then
    FL=sys_${FLNUM}_watch.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    echo "do watch $WATCH_IN"
    j=0
    BDT=`date +%s`
    EDT=$((BDT+$WAIT))
    if [ "$BKGRND" == "1" ]; then
      FL_WATCH=$FL
    else
    for i in `seq 1 $WAIT`; do
      #echo "i= $i of $WAIT"
      DT=`date +%s.%N`
      echo "==beg $j date $DT" >> $FL
      $WATCH_IN >> $FL
      CDT=`date +%s`
      ELAP=$(($CDT-$BDT))
      j=$((j+$INTRVL))
      if [ $j -ge $WAIT ]; then
        break
      fi
      if [ $CDT -ge $EDT ]; then
        break
      fi
      #printf "\rwatch i= %d of %d, elap secs= %d curtm= %d, endtm= %d" $i $WAIT $ELAP $CDT  $EDT
      sleep $INTRVL
      if [ "$GOT_QUIT" == "1" ]; then
         break
      fi
    done
    printf "\n"
    fi
    if [ "$DO_WATCH" == "1" ]; then
      echo "=======did watch ========="
      break
    fi
    fi
  fi

  if [[ $TSK == *"interrupts"* ]]; then
    echo "do cat /proc/interrupts for $WAIT secs"
    FL=sys_${FLNUM}_interrupts.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    j=0
    if [ "$BKGRND" == "1" ]; then
      FL_INT=$FL
    else
    for i in `seq 1 $WAIT`; do
      #echo "i= $i of $WAIT"
      printf "\rinterrupts i= %d of %d" $i $WAIT
      DT=`date +%s.%N`
      echo "==beg $j date $DT" >> $FL
      cat /proc/interrupts >> $FL
      j=$((j+$INTRVL))
      if [ $j -ge $WAIT ]; then
        break
      fi
      if [ "$GOT_QUIT" == "1" ]; then
         break
      fi
      sleep $INTRVL
    done
    printf "\n"
    fi
  fi
  if [[ $TSK == *"nicstat"* ]]; then
    echo "do nicstat -ntuxp $INTRVL $COUNT"
    FL=sys_${FLNUM}_nicstat.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    nicstat -ntux > $FL.hdr
    if [ "$BKGRND" == "0" ]; then
      nicstat -ntuxp $INTRVL $COUNT > $FL
    else
      nicstat -ntuxp $INTRVL $COUNT > $FL &
      TSK_PID[$TSKj]=$!
    fi
  fi
  
  if [ $VERBOSE -gt 0 ]; then
    if [ "$FL" != "" ]; then
    echo "cat $FL"
    cat $FL
    echo "=======cat $FL========="
    fi
  fi

done

if [ "$BKGRND" == "1" ]; then
  PID_LST=
  PID_LST_NC=
  CMA=
  for TSKj in `seq $TB $TE`; do
    TSK=${TSK_LST[$TSKj]}
    TSKPID=${TSK_PID[$TSKj]}
    PID_LST="${PID_LST}${CMA}$TSKPID"
    if [ "$TSKPID" != "" ]; then
      PID_LST_NC="${PID_LST_NC} $TSKPID"
    fi
    CMA=","
  done
  PID_LST_NC="${PID_LST_NC}"
  echo "PIDs started= $PID_LST"
  echo "PIDs started= $PID_LST_NC"
  echo "watch -n1 \"ps -f -p $PID_LST\""
  echo "watch -n1 \"ps -f -p $PID_LST\"" > watch.log
  echo "PIDS_NC= $PID_LST_NC" >> watch.log
  echo "PIDS_BSH= $BASHPID" >> watch.log
  if [ "$PID_LST_NC" != "" ]; then
    echo "$PID_LST_NC" >> ~/60secs.pid
  fi
fi
if [ "$WAIT_AT_END" == "1" -a "$PID_LST_NC" != "" ]; then
  echo "waiting for $WAIT seconds"
  #sleep $WAIT
  j=0
    BDT=`date +%s`
    EDT=$((BDT+$WAIT))
  CK_STOP=~/60secs.stop
  for i in `seq 1 $WAIT`; do
    #echo "i= $i of $WAIT"
    printf "i= %d of %d\n" $i $WAIT
    if [ "$FL_UPTM" != "" ]; then
       uptime >> $FL_UPTM
    fi
    if [ "$FL_INT" != "" ]; then
      DT=`date +%s.%N`
      echo "==beg $j date $DT" >> $FL_INT
      cat /proc/interrupts >> $FL_INT
    fi
    if [ "$FL_PWR" != "" ]; then
      DT=`date +%s.%N`
      echo "==beg $j date $DT" >> $FL_PWR
      ipmitool sdr >> $FL_PWR
      DT=`date +%s.%N`
      echo "==end $j date $DT" >> $FL_PWR
      CDT=`date +%s`
      ELAP=$(($CDT-$BDT))
      if [ $CDT -ge $EDT ]; then
        break
      fi
      printf "power i= %d of %d, elap secs= %d curtm= %d, endtm= %d\n" $i $WAIT $ELAP $CDT  $EDT
    fi
    if [ "$FL_WATCH" != "" ]; then
      DT=`date +%s.%N`
      #echo "$WATCH_IN" >> $FL_WATCH
      echo "==beg $j date $DT" >> $FL_WATCH
      $WATCH_IN >> $FL_WATCH
      DT=`date +%s.%N`
      echo "==end $j date $DT" >> $FL_WATCH
      CDT=`date +%s`
      ELAP=$(($CDT-$BDT))
      if [ $CDT -ge $EDT ]; then
        break
      fi
      #printf "\rwatch i= %d of %d, elap secs= %d curtm= %d, endtm= %d" $i $WAIT $ELAP $CDT  $EDT
    fi
    j=$((j+$INTRVL))
    if [ $j -ge $WAIT ]; then
      break
    fi
    sleep $INTRVL
    if [ -e $CK_STOP ]; then
      CKPID=`head -1 $CK_STOP`
      if [ "$CKPID" == "$MYBASHPID" ]; then
         echo "GOT $CK_STOP with pid $CKPID. Bye" > /dev/stderr
         GOT_QUIT=1
      fi
    fi
    if [ "$GOT_QUIT" == "1" ]; then
       echo "quitting loop due signal" > /dev/stderr
       echo "PID_LST_NC= b${PID_LST_NC}b" > /dev/stderr
       if [ "$PID_LST_NC" != "" ]; then
       echo "kill -2 $PID_LST_NC"
             kill -2 $PID_LST_NC
       sleep 2
       echo "kill -9 $PID_LST_NC"
             kill -9 $PID_LST_NC
       fi
       break
    fi
  done
  if [ "$FL_DMSG" != "" ]; then
    dmesg >> $FL_DMSG
  fi
  if [ "$NEED_TO_END_FLAMEGRAPH" == "1" ]; then
     ${SCR_DIR}/gen_flamegraph_for_java_in_container.sh -C $CONTAINER -a stop &> gen_fl_stop.log
     NEED_TO_END_FLAMEGRAPH=0
  fi
  if [ "$CURL_AT_END" == "1" ]; then
    # put the do_curl here too so it gets done before the perf script (which can take awhile)
    MINUTES=`awk -v secs="$WAIT" 'BEGIN{printf("%.0f\n", 1.0+(secs/60.0)); exit;}'`
    echo "running ${SCR_DIR}/do_curl.sh $MINUTES"
    ${SCR_DIR}/do_curl.sh $MINUTES $CONTAINER
    CURL_AT_END=0
  fi
  if [ "$NEED_PERF_SCRIPT" != "" ]; then
     echo "waiting for perf pid $PRF2_PID to finish"
     wait $PRF2_PID
     Fopts=" -F comm,tid,pid,time,cpu,period,event,ip,sym,dso,symoff,trace,flags,callindent"
     Fopts=" -F comm,tid,pid,time,cpu,period,event,trace"
     echo $PERF_BIN script -I --header -i $NEED_PERF_SCRIPT $Fopts --ns _ $NEED_PERF_SCRIPT.txt
          $PERF_BIN script -I --header -i $NEED_PERF_SCRIPT -F comm,tid,pid,time,cpu,period,event,trace --ns > $NEED_PERF_SCRIPT.txt
     NOW=`date +%s.%N`
     GETTIME=`awk '/^now/ {printf("%.9f\n", 1.0e-9 * $3); exit}' /proc/timer_list`
     echo "NOW_UTC= $NOW" > clocks.log
     echo "NOW_MONO= $GETTIME" >> clocks.log
  fi
fi
if [ "$CURL_AT_END" == "1" ]; then
  MINUTES=`awk -v secs="$WAIT" 'BEGIN{printf("%.0f\n", 1.0+(secs/60.0)); exit;}'`
  echo "running ${SCR_DIR}/do_curl.sh $MINUTES"
  ${SCR_DIR}/do_curl.sh $MINUTES $CONTAINER
fi
if [ "$NEED_TO_END_FLAMEGRAPH" == "1" ]; then
  echo "flamegraph profiling is still running. You'll need to do cmd below manually"
  echo ${SCR_DIR}/gen_flamegraph_for_java_in_container.sh -C $CONTAINER -a stop
fi
tstmp=`date "+%Y%m%d_%H%M%S"`
ts_end=`date "+%s.%N"`
ts_elap=`awk -v ts_beg="$ts_beg" -v ts_end="$ts_end" 'BEGIN{printf("%f\n", (ts_end+0.0)-(ts_beg+0.0));exit;}'`
echo "$tstmp end elapsed_secs $ts_elap"  >> $RUN_CMDS_LOG

