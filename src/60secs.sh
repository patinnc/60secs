#!/bin/bash
#
# see http://www.brendangregg.com/Articles/Netflix_Linux_Perf_Analysis_60s.pdf
# usage arg1 

WAIT=60
TASKS=("uptime" "dmesg" "vmstat" "mpstat" "pidstat" "iostat" "free" "sar_dev" "sar_tcp" "top" "perf" "interrupts")
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
PERF_BIN=perf
BKGRND=0
WAIT_AT_END=0
CURL_AT_END=0

while getopts "hvbcwd:i:p:t:" opt; do
  case ${opt} in
    b )
      BKGRND=1
      ;;
    c )
      CURL_AT_END=1
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
    p )
      if [ "$OPTARG" != "" -a ! -x $OPTARG ]; then
        echo "didn't find perf binary. You entered \"-p $OPTARG\""
        exit
      fi
      PERF_BIN=$OPTARG
      ;;
    t )
      if [ "$OPTARG" == "all" ]; then
        TSK_IN="-1"
      else
        TSK_IN=$OPTARG
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
      echo "      Enter '-t all' for all tasks"
      echo "      Valid task_num range is 0 to $TLAST"
      echo "      default is no task"
      echo "   -b start the jobs in the backgroup not waiting for each job to finish"
      echo "      The default is to not start the jobs the background (so start the 1st task, wait for it to finish, start the next task, etc)"
      echo "      uptime, dmesg, and interrupts can't run in the background currently. They will block if you select them"
      echo "   -w If you run background mode, this option waits for the duration after the background jobs are started."
      echo "   -c use this option to run /root/do_curl.sh at the end"
      echo "   -d time_in_seconds duration of each monitoring task in seconds"
      echo "      You can append an 'm' to specify the duration in minutes (like '-d 10m' which sets the duration to 600 seconds)"
      echo "      default is $WAIT seconds"
      echo "   -i interval in seconds between data collection"
      echo "      default is $INTRVL seconds"
      echo "   -p full_path_to_perf_binary  the perf binary might not be in the path so use this option to specify it"
      echo "      default is 'perf'"
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

if [ "$TSK_IN" == "" ]; then
  echo "You must enter arg1: '-t task_num|task_name' where all (all tasks) or a task_number (0-$TLAST) or a task_name"
  exit
fi

if [ "$TSK_IN" == "-1" ]; then
  TSK=$TSK_IN
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

NANO=".%N"
tdte=`date "+${NANO}"`
if [ "$tdte" == ".N" ]; then
 NANO=
fi
 
for TSKj in `seq $TB $TE`; do
  TSK=${TSK_LST[$TSKj]}
  TSKNUM=${TSK_NUM[$TSKj]}
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
    for i in `seq 1 $WAIT`; do
      #echo "i= $i of $WAIT"
      printf "\ri= %d of %d" $i $WAIT
      uptime >> $FL
      j=$((j+$INTRVL))
      if [ $j -ge $WAIT ]; then
        break
      fi
      sleep $INTRVL
    done
    printf "\n"
  fi
  
  if [[ $TSK == *"dmesg"* ]]; then
    echo "dmesg: waiting $WAIT secs and doing dmesg"
    FL=sys_${FLNUM}_dmesg.txt
    #dmesg |tail > $FL
    echo "wait for $WAIT seconds"
    BEG=`cat /proc/uptime | awk '{printf("%.0f\n", $1+0);}'`
    dmesg |tail > $FL
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
  
  if [[ $TSK == *"top"* ]]; then
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
    echo "do perf stat for $WAIT secs"
    IMC0_RDWR="uncore_imc_0/name='unc0_read_write',umask=0x0f,event=0x04/"
    IMC1_RDWR="uncore_imc_1/name='unc1_read_write',umask=0x0f,event=0x04/"
    IMC2_RDWR="uncore_imc_2/name='unc2_read_write',umask=0x0f,event=0x04/"
    IMC3_RDWR="uncore_imc_3/name='unc3_read_write',umask=0x0f,event=0x04/"
    IMC4_RDWR="uncore_imc_4/name='unc4_read_write',umask=0x0f,event=0x04/"
    EVT=$IMC0_RDWR,$IMC1_RDWR,$IMC2_RDWR,$IMC3_RDWR,$IMC4_RDWR,qpi_data_bandwidth_tx,qpi_ctl_bandwidth_tx
    EVT=instructions,cycles,ref-cycles,$EVT,LLC-load-misses
    echo do: $PERF_BIN stat -x ";"  --per-socket -a -I $ms -o $FL -e $EVT
    $PERF_BIN stat -x ";"  --per-socket -a -I $ms -o $FL -e $EVT sleep $WAIT &
    TSK_PID[$TSKj]=$!
    PRF_PID=$!
  fi

  if [[ $TSK == *"interrupts"* ]]; then
    echo "do cat /proc/interrupts for $WAIT secs"
    FL=sys_${FLNUM}_interrupts.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    j=0
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
      sleep $INTRVL
    done
    printf "\n"
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
  CMA=
  for TSKj in `seq $TB $TE`; do
    TSK=${TSK_LST[$TSKj]}
    TSKPID=${TSK_PID[$TSKj]}
    PID_LST="${PID_LST}${CMA}$TSKPID"
    CMA=","
  done
  echo "PIDs started= $PID_LST"
  echo "watch -n1 \"ps -f -p $PID_LST\""
  echo "watch -n1 \"ps -f -p $PID_LST\"" > watch.log
fi
if [ "$WAIT_AT_END" == "1" ]; then
  echo "waiting for $WAIT seconds"
  sleep $WAIT
fi
if [ "$CURL_AT_END" == "1" ]; then
  MINUTES=$((WAIT*60))
  echo "running /root/do_curl.sh $MINUTES"
  /root/do_curl.sh $MINUTES
fi

