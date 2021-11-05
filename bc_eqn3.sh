#!/bin/bash

SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
VERBOSE=0

while getopts "hve:f:" opt; do
  case ${opt} in
    e )
      EQN_FL=$OPTARG
      ;;
    f )
      FILE_IN=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 -f dir_with_perf_out_file|sys_10_perf_stat.txt|uPMA_perf_file  [ -e equantion_file ] to compute some metrics"
      echo " Usually this is a perf stat file created by 60secs/do_perf3.sh "
      echo "   -e equation_file (like eqn_milan.txt or csx.txt). The script will try to select the right eqn file"
      echo "   -f sys_perf_stat_event_file if this is a dir then the script will look for a sys_10_perf_stat.txt file in the dir"
      echo "   -v verbose_mode"
      exit 1
      ;;
    : )
      echo "$0.$LINENO Invalid option: $OPTARG requires an argument" 1>&2
      exit 1
      ;;
    \? )
      echo "$0.$LINENO Invalid option: $OPTARG" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

INFILE=tmp_itp_lite_sys_2thr_dlm
if [ "$FILE_IN" != "" ]; then
  INFILE=$FILE_IN
else
 if [ "$1" != "" ]; then
  if [ -e $1 ]; then
   INFILE=$1
  fi
 fi
fi
AWK=gawk
AWK=mawk
AWK=awk

DIR=.
if [ "$INFILE" != "" ]; then
  if [ -d $INFILE ]; then
    DIR=$INFILE
    if [ -e "$DIR/sys_10_perf_stat.txt" ]; then
      INFILE="$DIR/sys_10_perf_stat.txt"
    fi
  else
    if [ -e $INFILE ]; then
      DIR=`dirname $INFILE`
    fi
  fi
fi
LSCPU_FL=$DIR/lscpu.txt
if [ -e $LSCPU_FL ]; then
  LSCPU_DATA=`cat $LSCPU_FL`
elif [ -e $DIR/tmp_lscpu_file ]; then
  LSCPU_FL=$DIR/tmp_lscpu_file
  LSCPU_DATA=`cat $LSCPU_FL`
else 
  LSCPU_FL="run_lscpu_on_host"
  LSCPU_DATA=`lscpu`
fi 
CHIP_MAKER=`echo "$LSCPU_DATA" | awk '/^Vendor ID/{ print $3;}'`
EQN_FILE=$SCR_DIR/eqn_csx.txt
if [ "$CHIP_MAKER" = "GenuineIntel" ]; then
  EQN_FILE=$SCR_DIR/eqn_csx.txt
fi
if [ "$CHIP_MAKER" = "AuthenticAMD" ]; then
  EQN_FILE=$SCR_DIR/eqn_milan.txt
fi
if [ "$EQN_FL" != "" -a "$EQN_FL" != "$EQN_FILE" ]; then
    BS1=`basename $EQN_FL`
    BS2=`basename $EQN_FILE`
    if [ "$BS1" != "$BS2" ]; then
    echo "+++++++++++++++ warning, you entered eqn_file- $EQN_FL but it looks like we should be using $EQN_FILE++++++++"
    fi
    EQN_FILE=$EQN_FL
fi
LSCPU_INFO=
if [ "$LSCPU_DATA" != "" ]; then
  LSCPU_INFO=`echo "$LSCPU_DATA" | $AWK -v tsc="$TSC_FREQ" '
   BEGIN{ if (tsc != "") { tsc_v = tsc; } }
   /^CPU.s.:/{num_cpus = $2;}
   /^Thread.s. per core:/{ tpc = $4; }
   /^Socket.s.:/{ skt = $2; }
   /^Vendor ID/{ mkr = $3;}
   #/^CPU max MHz:/ { if (mkr == "AuthenticAMD" && tsc="") {tsc2= $4; tsc_v2 = 0.001 * tsc;}}
   /^BogoMIPS/{ if (tsc == "" && (mkr == "GenuineIntel" || mkr == "AuthenticAMD")) { tsc = $2/2 ;tsc_v = 0.001 * tsc;}}
   /^Model name:/ {
     if (index($0, "AMD ") == 0) {for (i=NF; i > 3; i--) { if (index($i, "GHz") > 0) { tsc = $i; gsub("GHz", "", tsc); tsc_v = tsc; break;}}}
   }
#Model name:          Intel(R) Xeon(R) Silver 4214 CPU @ 2.20GHz
   END{
     printf("num_cpus,%d,tsc_freq,%.3f,chip_maker,%s,sockets,%d,thr_per_core,%d\n", num_cpus, tsc_v, mkr, skt, tpc);
   }
  '`
  if [ "$VERBOSE" -gt "0" ]; then
  echo "LSCPU_INFO= ${LSCPU_INFO}"
  fi
fi


#echo "DIR= $DIR infile= $INFILE"
#echo "$0.$LINENO bye"
#exit 1
AWK_FILES=" -f $SCR_DIR/bc_eqn3_rd_perf_stat_file.awk -f $SCR_DIR/bc_eqn3_rd_eqn_file.awk -f $SCR_DIR/bc_eqn3_core.awk "

#ARGS=" -v var_list=var1,var2 -v val_list=100,200 -v row_hdr=col1,col2 -v row_val=1e-2,20 "
BC_EQN_OPTS="no_aliases"
BC_EQN_OPTS=
echo "$0.$LINENO event data file= $INFILE  eqn_file= $EQN_FILE, LSCPU_FILE= $LSCPU_FL"

if [ "$VERBOSE" -gt "0" ]; then
echo $AWK -v verbose=$VERBOSE -v options="$BC_EQN_ALIASES" -v eqn_file=$EQN_FILE -v infile=$INFILE  -v lscpu_info="$LSCPU_INFO" $AWK_FILES $INFILE $EQN_FILE
fi
     $AWK -v verbose=$VERBOSE -v options="$BC_EQN_ALIASES" -v eqn_file=$EQN_FILE -v infile=$INFILE  -v lscpu_info="$LSCPU_INFO" $AWK_FILES $INFILE $EQN_FILE
     RC=$?
if [ "$RC" != "0" ]; then
  echo "$0.$LINENO got error for $INFILE, eqn_file= $EQN_FILE, rc= $RC ---------------"
  echo "$0.$LINENO got error for $INFILE, eqn_file= $EQN_FILE, rc= $RC ---------------" > /dev/stderr
fi
exit 0

