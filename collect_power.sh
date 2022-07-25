#!/bin/bash

#     ww  ww  qct qct b19a b19a b20b b20b b20a b20a
HLST="160 240 131 177 137  53   167   55  73   74"
BLST="127 234 182 175 253 191   154  164  64   67"
TLST="w   w   q   q   q   q     w    w    w    w"

HARR=($(echo "$HLST" | tr ' ' '\n'))
BARR=($(echo "$BLST" | tr ' ' '\n'))
TARR=($(echo "$TLST" | tr ' ' '\n'))
echo "HLST= $HLST"
echo "BLST= $BLST"
echo "TARR= ${TARR[@]}"
HOST_IN=
DCMI_USE=
DELLOEM=
ODIR="."

while getopts "hvDB:H:d:i:p:" opt; do
  case ${opt} in
    B )
      BMC=$OPTARG
      ;;
    D )
      DELLOEM=1
      ;;
    d )
      WAIT_IN=$OPTARG
      ;;
    i )
      INTERVAL=$OPTARG
      ;;
    H )
      HOST_IN=$OPTARG
      ;;
    p )
      ODIR=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    z )
      DCMI_USE=1
      ;;
    h )
      echo "usage: $0 TBD documentation collect power from bmc -i sample_interval_in_secs -d time_to_wait and more"
      echo "seconds_to_run is how long you want each task to monitor the system. Defaults is $WAIT seconds."
      echo "data collected once a second till for $WAIT seconds."
      echo "   -B bmc_address  if 'local' then just do ipmitool sdr locally"
      echo "   -d time_in_seconds duration of each monitoring task in seconds"
      echo "      You can append an 'm' to specify the duration in minutes (like '-d 10m' which sets the duration to 600 seconds)"
      echo "      default is $WAIT seconds"
      echo "   -D use delloem interface"
      echo "   -i interval in seconds between data collection"
      echo "      default is $INTRVL seconds"
      echo "   -p project_path for the output file"
      echo "   -H hostname"
      echo "   -v verbose mode. display each file after creating it."
      echo "   -z use dcmi power reading cmd"
      echo "Example: collect power on local host for 30 secs total doing power measurement every 10 seconds and writing results into /opt/pfay/output/tpow dir"
      echo "  ./collect_power.sh -B local -d 30 -i 10 -p /opt/pfay/output/tpow"
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

GOT_QUIT=0
# function called by trap
catch_signal() {
    printf "\rSIGINT caught      "
    GOT_QUIT=1
}

trap 'catch_signal' SIGINT


if [[ "$ODIR" != "" ]] && [[ "$ODIR" != "." ]]; then
  mkdir -p $ODIR
fi
if [ "$BMC" != "local" ]; then
if [ "$HOST_IN" != "" ]; then
  HOST=$HOST_IN
fi

if [ "$DELLOEM" == "1" ]; then
     GOT=1
     UBMC=""
     TYP=DELLOEM
else
if [ "$HOST" != "" ];then
  if [[ $HOST == *"."* ]]; then
   echo 'got . in $HOST'
   HOST=`echo $HOST| sed 's/.*\.//g'`
   echo "HOST= $HOST"
  else
   echo 'not got .'
  fi
  GOT=0
  for i in `seq 0 ${#HARR[@]}`; do
    echo "i= $i"
    if [ "${HARR[$i]}" == "$HOST" ]; then
     GOT=1
     UBMC=${BARR[$i]}
     TYP=${TARR[$i]}
     break
    fi
  done
  if [ "$GOT" == "0" ]; then
   echo "missed look of HOST= $HOST"
   echo "here is the list ${HARR[@]}"
   exit
  fi
fi
if [ "$BMC" != "" ];then
  if [[ $BMC == *"."* ]]; then
   echo 'got . in $BMC'
   BMC=`echo $BMC| sed 's/.*\.//g'`
   echo "BMC= $BMC"
  else
   echo 'not got .'
  fi
  GOT=0
  for i in `seq 0 ${#BARR[@]}`; do
    if [ "${BARR[$i]}" == "$BMC" ]; then
     GOT=1 
     UBMC=${BARR[$i]}
     HOST=${HARR[$i]}
     TYP=${TARR[$i]}
     break
    fi
  done
  if [ "$GOT" == "0" ]; then
   echo "missed look of BMC= $BMC"
   echo "here is the list ${BARR[@]}"
  fi
fi
fi
echo "ubmc= $UBMC"

if [ "$TYP" == "" ]; then
  echo "missed TYP lookup for HOST $HOST and BMC $UBMC" > /dev/stderr
  echo "add host and/or BMD to TLST. Bye" > /dev/stderr
  exit
fi
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
else
  WAIT=60
fi
echo "using duration $WAIT seconds"

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
else
  INTRVL=1
fi
echo "using interval $INTRVL seconds"

TSK=power
DO_POWER=1
if [ "$BMC" != "local" ]; then
if [ "$DELLOEM" == "1" ]; then
  echo "ipmi delloem powermonitor clar cumulativepower and peakpower"
  ipmi $HOST delloem powermonitor clear cumulativepower
  ipmi $HOST delloem powermonitor clear peakpower
  if [ "$DCMI_USE" != "1" ]; then
    CMD="ipmi $HOST delloem powermonitor powerconsumptionhistory"
  else
    CMD="ipmi $HOST dcmi power reading"
  fi
else
  if [ "$DCMI_USE" != "1" ]; then
    CMD="./ipmi-${TYP} $UBMC sdr"
  else
    CMD="./ipmi-${TYP} $UBMC dcmi power reading"
  fi
fi
fi

  if [[ $TSK == *"power"* ]]; then
    if [ "$DO_POWER" == "1" ]; then
    FL=$ODIR/sys_16_power.txt
    if [ -e $FL ]; then
      rm $FL
    fi
    if [ "$BMC" != "local" ]; then
      echo "$CMD"
    fi
    j=0
    BDT=`date +%s` 
    EDT=$((BDT+$WAIT))
    for i in `seq 1 $WAIT`; do
      #echo "i= $i of $WAIT"
      DT=`date +%s.%N`
      echo "==beg $j date $DT" >> $FL
      if [ "$BMC" == "local" ]; then
      #$CMD >> $FL
      ipmitool sdr >> $FL
      else
      if [ "$DCMI_USE" != "1" ]; then
        ./ipmi-${TYP} $UBMC sdr >> $FL
      else
        ./ipmi-${TYP} $UBMC dcmi power reading >> $FL
      fi
      fi
      DT=`date +%s.%N`
      echo "==end $j date $DT" >> $FL
      CDT=`date +%s`
      ELAP=$(($CDT-$BDT))
      j=$((j+$INTRVL))
      if [ $j -ge $WAIT ]; then
        break
      fi
      if [ $CDT -ge $EDT ]; then
        break
      fi
      printf "\rpower i= %d of %d, elap secs= %d curtm= %d, endtm= %d" $i $WAIT $ELAP $CDT  $EDT
      sleep $INTRVL
      if [ "$GOT_QUIT" == "1" ]; then
         break
      fi
    done 
    printf "\n"
    if [ "$DO_POWER" == "1" ]; then
      echo "=======did power ========="
    fi
    fi
  fi  
