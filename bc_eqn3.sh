#!/bin/bash

SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
VERBOSE=0

FILES=()

while getopts "hvb:C:c:D:e:E:f:M:O:o:P:p:s:S:u:l:" opt; do
  case ${opt} in
    b )
      BEG=$OPTARG
      ;;
    C )
      CLIP_IN=$OPTARG
      ;;
    c )
      CHART_IN=$OPTARG
      ;;
    D )
      DEBUG_OPT=$OPTARG
      ;;
    e )
      END_TM=$OPTARG
      ;;
    E )
      EQN_FL=$OPTARG
      ;;
    M )
      MEM_SPEED_MHz=$OPTARG
      ;;
    P )
      PHASE_FILE=$OPTARG
      ;;
    p )
      PFX_IN=$OPTARG
      ;;
    s )
      SHEET_IN=$OPTARG
      ;;
    S )
      SUM_FILE=$OPTARG
      ;;
    u )
      USE_CPUS="$USE_CPUS $OPTARG"
      ;;
    O )
      OUT_FILE=$OPTARG
      ;;
    o )
        OPTIONS=$OPTARG
      ;;
    f )
      if [ "$OPTARG" == "" ]; then
         echo "option -f requires a filename arg"
         exit
      fi
      if [ ! -e $OPTARG ]; then
         echo "option \"-f $OPTARG\" didn't find file $OPTARG"
         exit
      fi
      FILES+=($OPTARG)
      ;;
    l )
      if [ "$OPTARG" == "" ]; then
         echo "option -l requires a filename arg"
         exit
      fi
      if [ ! -e $OPTARG ]; then
         echo "option \"-l $OPTARG\" didn't find file $OPTARG"
         exit
      fi
      SPECINT_LOG=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 split perf stat data files into columns"
      echo "Usage: $0 [-h] -f perf_stat_txt_file [ -f ...] [ -s sheetname ] [ -p prefix ] [ -c chart_name ] [ -l specInt_logfile ] [-v]"
      echo "   -f perf_stat_txt_file  perf stat data file"
      echo "      currently only 1 '-f filename' option is supported"
      echo "   -C clip_phase restrict to this phase in phase_file"
      echo "   -c chart title. Used by tsv_2_xlsx.py"
      echo "   -e end_timestamp. drop data after this timestamp"
      echo "   -E equation_file  like eqn_cxs.txt or eqn_miilan.txt or eqn_arm.txt"
      echo "   -M mem_speed_in_MHz (optional) used to compute max mem bw"
      echo "   -O out_file"
      echo "   -o options_str  Currently only option is \"dont_sum_sockets\" to not sum S0 & S1 to the system"
      echo "   -P phase_file.  phase file: fmt phase_name beg_epoch_ts end_epoch_ts elapsed_secs"
      echo "   -p prefix_str.  prefix each sheet name with this string."
      echo "   -s sheet_name.  Used by tsv_2_xlsx.py. string has to comply with Excel sheet name rules"
      echo "   -S sum_file     Output summary stats to this file"
      echo "   -u use_cpus     a range of cpus to use. Assumes that the perf data is collected at the cpu level (perf stat -A...)"
      echo "   -l SpecInt CPU2017 log (like result/CPU2017.001.log)"
      echo "   -v verbose mode"
      exit
      ;;
    : )
      echo "$0.$LINENO Invalid option: $OPTARG requires an argument cmdline= ${@}" 1>&2
      exit 1
      ;;
    \? )
      echo "$0.$LINENO Invalid option: $OPTARG. cmdline= ${@}" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))


CHART="perf stat"
if [ "$CHART_IN" != "" ]; then
  CHART=$CHART_IN
fi

SHEET="perf stat"
if [ "$SHEET_IN" != "" ]; then
  SHEET=$SHEET_IN
fi

INFILE=tmp_itp_lite_sys_2thr_dlm
INFILE="${FILES[@]}"
#if [ "$FILE_IN" != "" ]; then
#  INFILE=$FILE_IN
#else
# if [ "$1" != "" ]; then
#  if [ -e $1 ]; then
#   INFILE=$1
#  fi
# fi
#fi
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
echo "DIR= $DIR"
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
CHIP_ARCH=`echo "$LSCPU_DATA" | awk '/^Architecture/{ print $2;}'`
EQN_FILE=$SCR_DIR/eqn_csx.txt
if [ "$CHIP_MAKER" = "GenuineIntel" ]; then
  EQN_FILE=$SCR_DIR/eqn_csx.txt
fi
if [ "$CHIP_MAKER" = "AuthenticAMD" ]; then
  EQN_FILE=$SCR_DIR/eqn_milan.txt
fi
if [ "$CHIP_ARCH" = "aarch64" ]; then
  EQN_FILE=$SCR_DIR/eqn_arm.txt
fi
if [[ "$EQN_FL" != "" ]] && [[ "$EQN_FL" != "$EQN_FILE" ]]; then
    BS1=`basename $EQN_FL`
    BS2=`basename $EQN_FILE`
    if [ "$BS1" != "$BS2" ]; then
    echo "+++++++++++++++ warning, you entered eqn_file- $EQN_FL but it looks like we should be using $EQN_FILE++++++++"
    fi
    EQN_FILE=$EQN_FL
fi
BC_EQN3_LSCPU_INFO=
if [ "$LSCPU_DATA" != "" ]; then
  CPU_TYPE=$(echo "$LSCPU_DATA" | $SCR_DIR/decode_cpu_fam_mod.sh )
  BC_EQN3_LSCPU_INFO=`echo "$LSCPU_DATA" | $AWK -v tsc="$TSC_FREQ" -v cpu_type="$CPU_TYPE" '
   BEGIN{ if (tsc != "") { tsc_v = tsc; } }
   /^CPU.s.:/{num_cpus = $2;}
   /^Architecture:/{arch=$2;}
   /^Thread.s. per core:/{ tpc = $4; }
   /^Socket.s.:/{ skt = $2; }
   /^Vendor ID/{ mkr = $3;}
   #/^CPU max MHz:/ { if (mkr == "AuthenticAMD" && tsc="") {tsc2= $4; tsc_v2 = 0.001 * tsc;}}
   /^BogoMIPS/{ if (tsc == "" && (mkr == "GenuineIntel" || mkr == "AuthenticAMD")) { tsc = $2/2 ;tsc_v = 0.001 * tsc;}}
   /^Model name:/ {
     if (index($0, "AMD ") == 0) {for (i=NF; i > 3; i--) { if (index($i, "GHz") > 0) { tsc = $i; gsub("GHz", "", tsc); tsc_v = tsc; break;}}}
   }
   END{
     printf("num_cpus,%d,tsc_freq,%.3f,chip_maker,%s,sockets,%d,thr_per_core,%d,arch,%s,cpu_type,%s\n", num_cpus, tsc_v, mkr, skt, tpc, arch, cpu_type);
   }
  '`
  if [ "$VERBOSE" -gt "0" ]; then
  echo "BC_EQN3_LSCPU_INFO= ${BC_EQN3_LSCPU_INFO}"
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

#if [ "$VERBOSE" -gt "0" ]; then
echo $0.$LINENO $AWK  -v bc_eqn3_pfx="$PFX_IN" -v ps_options="$OPTIONS" -v bc_eqn3_chrt="$CHART" -v bc_eqn3_sheet="$SHEET"  -v out_file="$OUT_FILE" -v sum_file="$SUM_FILE" -v verbose=$VERBOSE -v bc_eqn3_options="$BC_EQN_ALIASES" -v bc_eqn3_eqn_file=$EQN_FILE -v bc_eqn3_infile=$INFILE  -v bc_eqn3_lscpu_info="$BC_EQN3_LSCPU_INFO" $AWK_FILES $INFILE $EQN_FILE
#fi
     $AWK -v bc_eqn3_pfx="$PFX_IN" -v ps_options="$OPTIONS" -v bc_eqn3_chrt="$CHART" -v bc_eqn3_sheet="$SHEET" -v out_file="$OUT_FILE" -v sum_file="$SUM_FILE" -v verbose=$VERBOSE -v bc_eqn3_options="$BC_EQN_ALIASES" -v bc_eqn3_eqn_file=$EQN_FILE -v bc_eqn3_infile=$INFILE  -v bc_eqn3_lscpu_info="$BC_EQN3_LSCPU_INFO" $AWK_FILES $INFILE $EQN_FILE
     RC=$?
if [ "$RC" != "0" ]; then
  echo "$0.$LINENO got error for $INFILE, eqn_file= $EQN_FILE, rc= $RC ---------------"
  echo "$0.$LINENO got error for $INFILE, eqn_file= $EQN_FILE, rc= $RC ---------------" > /dev/stderr
fi
exit $RC

