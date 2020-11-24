#!/bin/bash

# arg1 is prf stat file
# arg2 (optional) is specint .log
# for example:
# ../perf_stat_scatter.sh B20a_specint_prf/prf_data_specint.txt B20a_specint_prf/20-01-15_130627_specint/result/CPU2017.001.log  > tmp.tsv
SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
FILES=
SPECINT_LOG=
CHART_IN=
SHEET_IN=
PFX_IN=
OPTIONS=
BEG=
SUM_FILE=
END_TM=

while getopts "hvb:c:D:e:f:o:p:s:S:l:" opt; do
  case ${opt} in
    b )
      BEG=$OPTARG
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
    p )
      PFX_IN=$OPTARG
      ;;
    s )
      SHEET_IN=$OPTARG
      ;;
    S )
      SUM_FILE=$OPTARG
      ;;
    o )
        OPTIONS=$OPTARG
      #if [[ $OPTARG == *"dont_sum_sockets"* ]]; then
      #  OPTIONS=$OPTARG
      #else
      #  if [[ $OPTARG == *"chart_new"* ]]; then
      #     OPTIONS=$OPTARG
      #  else
        #if [ "$OPTARG" != "" ]; then
        #  echo "sorry but only -o option supported now is '-o dont_sum_sockets'. You entered -o $OPTARG"
        #  exit
        #fi
      #  fi
      #fi
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
      FILES="$FILES $OPTARG"
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
      echo "   -c chart title. Used by tsv_2_xlsx.py"
      echo "   -e end_timestamp. drop data after this timestamp"
      echo "   -o options_str  Currently only option is \"dont_sum_sockets\" to not sum S0 & S1 to the system"
      echo "   -p prefix_str.  prefix each sheet name with this string."
      echo "   -s sheet_name.  Used by tsv_2_xlsx.py. string has to comply with Excel sheet name rules"
      echo "   -S sum_file     Output summary stats to this file"
      echo "   -l SpecInt CPU2017 log (like result/CPU2017.001.log)"
      echo "   -v verbose mode"
      exit
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument cmdline= ${@}" 1>&2
      exit 1
      ;;
    \? )
      echo "Invalid option: $OPTARG. cmdline= ${@}" 1>&2
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

if [ "$DEBUG_OPT" != "" ]; then
  if [[ $DEBUG_OPT == *"skip_perf_stat_scatter"* ]]; then
     echo "skipping $0 due do $DEBUG_OPT"
     exit 1
  fi
fi

echo "-------------------------------- in perf_stat_scatter.sh -----------------------------------" > /dev/stderr

# didn't collect lscpu.log for most of the data
TSC_FREQ="2.1"
THR_PER_CORE=2
echo "$0.$LINENO ck_amd got here" > /dev/stderr
if [ -e lscpu.txt ]; then
LSCPU_FL="lscpu.log lscpu.txt"
echo "$0.$LINENO ck_amd got here" > /dev/stderr
else
echo "$0.$LINENO ck_amd got here" > /dev/stderr
 if [ -e ../lscpu.txt ]; then
  LSCPU_FL="../lscpu.log ../lscpu.txt"
echo "$0.$LINENO ck_amd got here" > /dev/stderr
 fi 
fi 
echo "$0.$LINENO ck_amd got here" > /dev/stderr
for i in $LSCPU_FL; do
  if [ -e $i ]; then
#Vendor ID:             AuthenticAMD
#CPU family:            23
#Model:                 49
#Model name:            AMD EPYC 7662 64-Core Processor
#Stepping:              0
#CPU MHz:               1496.962
#CPU max MHz:           2000.0000
    TSC_FREQ_AMD=`cat $i |awk '/^Vendor ID:/{if ($3 == "AuthenticAMD"){amd=1;}}/BogoMIPS:/{bogo=$2;}/CPU max MHz:/{ freq= $4; if (amd==1){printf("%s\n", freq);exit;}}END{if(amd==1){printf("%.3f\n",0.5*bogo);}}'`
    TSC_FREQ=`cat $i |awk '/^Model name/{for (i=1;i<=NF;i++){pos=index($i, "GHz");if (pos > 0){print substr($i,1,pos-1);}}}'`
    NUM_CPUS=`cat $i |awk '/^CPU.s.:/{printf("%s\n",$2);}'`
    THR_PER_CORE=`cat $i |awk '/^Thread.s. per core:/{printf("%s\n",$4);}'`
    echo "$0.$LINENO tsc_freq_amd= $TSC_FREQ_AMD" > /dev/stderr
    #CPU(s):                32
  fi
done
AMD_CPU=0;
if [ "$TSC_FREQ" == "" -a "$TSC_FREQ_AMD" != "" ]; then
  TSC_FREQ=$TSC_FREQ_AMD
  AMD_CPU=1;
  echo "$0.$LINENO got AMD cpu" > /dev/stderr
fi
echo "TSC_FREQ= $TSC_FREQ NUM_CPUS= $NUM_CPUS" > /dev/stderr
CPU2017LOG=()
RESP=`find .. -name CPU2017.001.log`
echo "got find .. -name cpu2017.*.log resp = $RESP" > /dev/stderr
CPU2017LOG=$RESP
echo "+++++++++++++++++++++got CPU2017LOG= ${CPU2017LOG[@]}" > /dev/stderr
CPU2017files=
if [ "${#CPU2017LOG[@]}" -gt "0" ]; then
   for ii in ${CPU2017LOG[@]}; do
     CPU2017files+="$ii "
    done
fi
echo "++++++++++++++++++++got CPU2017files= $CPU2017files" > /dev/stderr

export AWKPATH=$SCR_DIR

echo awk -v amd_cpu="$AMD_CPU" -v thr_per_core="$THR_PER_CORE" -v num_cpus="$NUM_CPUS" -v ts_beg="$BEG" -v ts_end="$END_TM" -v tsc_freq="$TSC_FREQ" -v pfx="$PFX_IN" -v options="$OPTIONS" -v chrt="$CHART" -v sheet="$SHEET" -v sum_file="$SUM_FILE" -v sum_flds="unc_read_write{Mem BW GB/s|memory},LLC-misses PKI{|memory},%not_halted{|CPU},avg_freq{avg_freq GHz|CPU},QPI_BW{QPI_BW GB/s|memory interconnect},power_pkg {power pkg (watts)|power}" -f $SCR_DIR/perf_stat_scatter.awk $FILES $CPU2017files > /dev/stderr
awk -v amd_cpu="$AMD_CPU" -v thr_per_core="$THR_PER_CORE" -v num_cpus="$NUM_CPUS" -v ts_beg="$BEG" -v ts_end="$END_TM" -v tsc_freq="$TSC_FREQ" -v pfx="$PFX_IN" -v options="$OPTIONS" -v chrt="$CHART" -v sheet="$SHEET" -v sum_file="$SUM_FILE" -v sum_flds="unc_read_write{Mem BW GB/s|memory},LLC-misses PKI{|memory},%not_halted{|CPU},avg_freq{avg_freq GHz|CPU},QPI_BW{QPI_BW GB/s|memory interconnect},power_pkg {power pkg (watts)|power}" -f $SCR_DIR/perf_stat_scatter.awk $FILES $CPU2017files
          RC=$?
          if [ $RC -gt 0 ]; then
            RESP=`pwd`
            echo "$0: got non-zero RC at $LINENO. curdir= $RESP" > /dev/stderr
            exit 1
          fi

# $FILES $SPECINT_LOG $CPU2017files

