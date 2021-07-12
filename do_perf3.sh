#!/bin/bash

SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
export LC_ALL=C
AWK_BIN=awk
if [ -e $SCR_DIR/bin/gawk ]; then
  AWK_BIN=$SCR_DIR/bin/gawk
fi

#SCR_DIR=`dirname "$(readlink -f "$0")"`
FOREGRND=0
PID=
IFS_SV=$IFS

GOT_QUIT=0
# function called by trap
catch_signal() {
    printf "\rSIGINT caught      "
    GOT_QUIT=1
}
trap 'catch_signal' SIGINT

while getopts "hFvb:C:I:P:p:w:W:x:X:" opt; do
  case ${opt} in
    b )
      PERF_BIN_IN=$OPTARG
      ;;
    C )
      CPU_LIST_IN=$OPTARG
      ;;
    F )
      FOREGRND=1
      ;;
    I )
      INTRVL_IN=$OPTARG
      echo "$0.$LINENO intrvl_in= $INTRVL_IN" > /dev/stderr
      ;;
    P )
      PID_IN=$OPTARG
      ;;
    p )
      PROJ_IN=$OPTARG
      ;;
    w )
      WAIT_IN=$OPTARG
      echo "$0.$LINENO wait_in= $WAIT_IN" > /dev/stderr
      ;;
    W )
      WARGS=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    x )
      EXE_IN=$OPTARG
      ;;
    X )
      EXE_ARGS="$OPTARG"
      ;;
    h )
      echo "$0 run itp-lite"
      echo "Usage: $0 [ -v ] [-F] [-b perf_binary] -I interval_in_secs -p proj_dir [ -w wait_in_secs ] [ -x binary_to_be_run ] [ -X args_to_binary_to_be_run ] "
      echo "   -b perf_binary_path  default is $SCR_DIR/perf"
      echo "   -C cpu_list  default is all cpus. Intended for doing multiple simultaneous perf stat runs"
      echo "   -F foreground  wait for '-x binary_to_be_run' to finish before exiting" 
      echo "   -I interval_in_secs the perf stat output will be written every this number of secs"
      echo "   -P pid_to_monitor  have perf monitor just this pid"
      echo "      if you enter -P pid then -x option is ignored"
      echo "      if you also enter -w time_to_run_in_secs then perf is started in the background and stopped after -w secs"
      echo "   -p proj_dir    output will written to this dir"
      echo "   -w wait_in_secs  the number of secs to run perf (if you are doing sleep) or args for -x exe"
      echo "   -W args_to_pass_to_perf  args to be passed directly to perf stat."
      echo "      For instance '-W \" -A \" ' tells perf to show 'per cpu' event counts (don't aggregate to system)."
      echo "      The is optional."
      echo "   -x executable_or_script  exe_or_script to be run. Default is to sleep for wait_in_secs"
      echo "      if -x is not used or exe is 'sleep' then perf -a option is used (perf -a option means monitor all the system)."
      echo "      if -x is used then perf -a option is not used so perf just runs that exe and only collects stats for that process"
      echo "   -X exe_args   arg string for -x exe. include in dbl quotes if contain spaces."
      echo "   -v verbose mode"
      exit 1
      ;;
    : )
      echo "$0.$LINENO Invalid option: $OPTARG requires an argument. cmdline= ${@}" 1>&2
      exit 1
      ;;
    \? )
      echo "$0.$LINENO Invalid option: $OPTARG, cmdline= ${@} " 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ "$PERF_BIN_IN" == "" ]; then
  PERF_BIN=$SCR_DIR/perf
else
  PERF_BIN=$PERF_BIN_IN
fi
if [ ! -x $PERF_BIN ]; then
  echo "$0.$LINENO didn't find perf binary $PERF_BIN"
  exit 1
fi
PRFFILE_PID=~/perf.pid
PRFFILE_STOP=~/perf.stop
if [ -e $PRFFILE_STOP ]; then
  rm $PRFFILE_STOP
fi
DOPERF_PID=~/do_perf.pid
DOPERF_STOP=~/do_perf.stop
if [ -e $DOPERF_STOP ]; then
  rm $DOPERF_STOP
fi
echo "$BASHPID" > $DOPERF_PID
if [ "$INTRVL_IN" == "" ]; then
  echo "$0: must enter -I interval_in_secs. Bye"
  exit 1
fi

if [ "$EXE_IN" != "" ]; then
  if [ ! -e $EXE_IN ]; then
    echo "$0: you entered -x $EXE_IN but $EXE_IN file not found. Bye"
    exit 1
  fi
else
  if [ "$WAIT_IN" == "" ]; then
    echo "$0: must enter -w interval_in_secs. Bye"
    exit 1
  fi
fi
if [ "$PROJ_IN" == "" ]; then
  echo "$0: must enter -p proj_dir. Bye"
  exit 1
fi
if [ ! -d $PROJ_IN ]; then
  mkdir -p $PROJ_IN
  #echo "$0: -d $PROJ_IN but dir doesn't exist. bye"
  #exit 1
fi
INTRVL=$INTRVL_IN
WAIT=$WAIT_IN
ODIR=$PROJ_IN
if [ ! -e $ODIR ]; then
  mkdir -p $ODIR
fi
CPU_DECODE=`${SCR_DIR}/decode_cpu_fam_mod.sh`

if [ "$PID_IN" != "" ]; then
  PID=$PID_IN
  IFS=',' read -ra PIDA <<< "$PID"
  IFS=$IFS_SV
  PID=
  SEP=
  for i in "${PIDA[@]}"; do
    if [ -e /proc/$i ]; then
      PID="${PID}${SEP}$i"
      SEP=","
    fi
  done
fi

LSCPU=`lscpu`
echo "$LSCPU" > $ODIR/lscpu.txt

skts=`echo "$LSCPU"|$AWK_BIN '/Socket.s.:/{ printf("%d", $2); exit;}'`

hostname > $ODIR/hostname.txt
$SCR_DIR/bin/tsc_freq.x > $ODIR/tsc_freq.txt

RUN_CMDS_LOG=$ODIR/run.log
myArgs="$((($#)) && printf ' %q' "$@")"
tstmp=`date "+%Y%m%d_%H%M%S"`
ts_beg=`date "+%s.%N"`
echo "$tstmp $ts_beg start $myArgs"  >> $RUN_CMDS_LOG


PERF_LIST=`$PERF_BIN list`

SV_WATCHDOG=`cat /proc/sys/kernel/nmi_watchdog`
echo 0 > /proc/sys/kernel/nmi_watchdog

FLNUM=10

FL=$ODIR/sys_${FLNUM}_perf_stat.txt
if [ -e $FL ]; then
  rm $FL
fi
NANO=".%N"
dtc=`date`
dte=`date "+%s${NANO}"`
echo "date= $dt $dte"
echo "# started on $dtc $dte" > $FL
    ms=$(($INTRVL*1000))
    EVT=
    echo "$0.$LINENO do perf stat for $WAIT secs, CPU+decode= $CPU_DECODE"
    if [ "$CPU_DECODE" == "Zen2 Castle Peak" -o "$CPU_DECODE" == "Zen3 Milan" -o  "$CPU_DECODE" == "Zen Naples/Whitehaven/Summit Ridge/Snowy Owl" ]; then
      #libpfm: { .name   = "UOPS_QUEUE_EMPTY", .desc   = "Cycles where the uops queue is empty", .code    = 0xa9,
      # uprof -l output
      #PMCx0AE      Dispatch Resource Stall Cycles 1
      #PMCx0AF      Dispatch Resource Stall Cycles 0
      #PMCx0A9      Micro-Op Queue Empty
      #PMCx0AA      UOps Dispatched From Decoder
      #PMCx0C0      Retired Instructions
      #PMCx0C1      Retired Uops
      BR_RETIRED="cpu/name='retired_branch_instructions',umask=0x00,event=0xc2/"
      BR_MISPRED="cpu/name='retired_branch_instructions_mispredicted',umask=0x00,event=0xc3/"
      DC_ACCESSES="cpu/name='all_dc_accesses',umask=0x07,event=0x29/" # All DC Accesses: Event[0x430729]
      # All L2 Cache Accesses: Event[0x43F960] + Event[0x431F70] + Event[0x431F71] + Event[0x431F72]
      L2_ACCESSES="cpu/name='L2_accesses_g1',umask=0xf9,event=0x60/"
      L2_PF_HIT_L2="cpu/name='L2_pf_hit_L2',umask=0xff,event=0x70/"
      L2_PF_HIT_L3="cpu/name='L2_pf_hit_L3',umask=0xff,event=0x71/"
      L2_PF_MISS_L3="cpu/name='L2_pf_miss_L3',umask=0xff,event=0x72/"
      #L2 Cache Access from IC Miss (including prefetch): Event[0x431060]
      L2_ACC_IC_MISS="cpu/name='L2_acc_ic_miss',umask=0x10,event=0x60/"
      #L2 Cache Access from DC Miss (including Prefetch): Event[0x43C860]
      L2_ACC_DC_MISS="cpu/name='L2_acc_dc_miss',umask=0xc8,event=0x60/"
      #L2 Cache Access from L2 HWPF: Event[0x431F70] + Event[0x431F71] + Event[0x431F72]
      #All L2 Cache Misses: Event[0x430964] + Event[0x431F71] + Event[0x431F72]
      L2_MISSES="cpu/name='L2_misses',umask=0xc8,event=0x60/"
      #L2 Cache Miss from IC Miss: Event[0x430164]
      #L2 Cache Miss from DC Miss: Event[0x430864]
      L2_MISS_IC="cpu/name='L2_misses_ic',umask=0x01,event=0x64/"
      L2_MISS_DC="cpu/name='L2_misses_dc',umask=0x08,event=0x64/"
      #All L2 Cache Hits: Event[0x43F664] + Event[0x431F70]
      L2_HITS_DATA="cpu/name='L2_hits_data',umask=0xf6,event=0x64/"
      #L2 Cache Hit from IC Miss: Event[0x430664]
      L2_HITS_IC="cpu/name='L2_hits_due_to_ic_miss',umask=0x06,event=0x64/"
      #L2 Cache Hit from DC Miss: Event[0x437064]
      L2_HITS_DC_MISS="cpu/name='L2_hits_due_to_dc_miss',umask=0x70,event=0x64/"
  
      #Execution-Time Branch Misprediction Ratio (Non-Speculative): Event[0x4300C3] / Event[0x4300C2]
      # from intel (invert & count cycles):  inv=1,cmask=10,
      # https://elixir.bootlin.com/linux/latest/source/arch/x86/events/amd/core.c
      DISP_STALL0="cpu/name='disp_stall_cycles_0',umask=0xff,event=0xaf/"
      DISP_STALL1="cpu/name='disp_stall_cycles_1',umask=0xff,event=0xae/"
      DISP_STALL_IREG="cpu/name='disp_stall_phy_reg_cycles',event=0xae,umask=0x01/"
      DISP_STALL_REGS="cpu/name='disp_stall_regs_cycles',event=0xae,umask=0x21/"
      DISP_STALL_LD_Q="cpu/name='disp_stall_ld_q_cycles',event=0xae,umask=0x02/"
      DISP_STALL_ST_Q="cpu/name='disp_stall_st_q_cycles',event=0xae,umask=0x04/"
      DISP_STALL_INT_SCH="cpu/name='disp_stall_int_sch_cycles',event=0xae,umask=0x08/"
      DISP_STALL_BR_BUF="cpu/name='disp_stall_br_buf_cycles',event=0xae,umask=0x10/"
      DISP_STALL_FP_REG="cpu/name='disp_stall_fp_reg_cycles',event=0xae,umask=0x20/"
      DISP_STALL_FP_SCH="cpu/name='disp_stall_fp_sch_cycles',event=0xae,umask=0x40/"
      DISP_STALL_FP_MSC="cpu/name='disp_stall_fp_msc_cycles',event=0xae,umask=0x80/"
      DISP_STALL_FP="cpu/name='disp_stall_fp_msc_cycles',event=0xae,umask=0xe0/"
      STALL_UOPS="cpu/name='uops_stalls',event=0xc1/"
      STALL_UOPSIC="cpu/name='uops_stalls_ic',event=0xc0,umask=0x00,inv=1,cmask=10/"
      STALL_UOPS_C="cpu/name='uops_stalls_c',event=0xc0,umask=0x00,cmask=10/"
      STALL_UOPS_I="cpu/name='uops_stalls_i',event=0xc0,umask=0x00,inv=1,cmask=00/"
      STALL_UOPS="cpu/name='uops_stalls',event=0xc0,umask=0x00,inv=0,cmask=00/"
      #STALL_UOPS="cpu/name='uops_stalls',event=0xc1,umask=0x00,inv=0,cmask=00/"
      STALL_INST="cpu/name='inst_stalls',event=0xc0,umask=0x00,inv=1,cmask=10/"
      # see for example, PERF_COUNT_HW_STALLED_CYCLES_FRONTEND in above bootlin.com ref
      # [PERF_COUNT_HW_STALLED_CYCLES_FRONTEND]	= 0x0287,
      # [PERF_COUNT_HW_STALLED_CYCLES_BACKEND]	= 0x0187,
      FRTEND_STALLS="cpu/name='frontend_stalls',event=0x287/" # seems to be << stalled-cycles-frontend
      BKEND_STALLS="cpu/name='backend_stalls',event=0x187/"  # seems to always give 0
      FRTEND_STALLS="cpu/name='frontend_stalls',event=0x87,umask=0x02/" # seems to be << stalled-cycles-frontend
      BKEND_STALLS="cpu/name='backend_stalls',event=0x87,umask=0x01/"  # seems to always give 0
      UOPS_Q_EMPTY="cpu/name='uops_queue_empty',umask=0x0,event=0xa9/"
      UOPS_RET="cpu/name='retired_uops',umask=0x00,event=0xc1/"
      EVT="task-clock,cpu-clock,cycles,stalled-cycles-backend,$DISP_STALL_INT_SCH,$DISP_STALL_BR_BUF,$DISP_STALL_FP"
      EVT="cpu-clock,cycles,stalled-cycles-backend,$DISP_STALL_IREG,$DISP_STALL_LD_Q,$DISP_STALL_ST_Q"
      EVT="cpu-clock,instructions,cycles,$DISP_STALL1,$DISP_STALL_IREG,$DISP_STALL_LD_Q,$DISP_STALL_ST_Q"
      EVT="cpu-clock,instructions,cycles,$DISP_STALL_REGS,$UOPS_Q_EMPTY,stalled-cycles-backend,stalled-cycles-frontend"
      EVT="cpu-clock,instructions,cycles,$BKEND_STALLS,stalled-cycles-backend,$FRTEND_STALLS,stalled-cycles-frontend"
      EVT="cpu-clock,instructions,cycles,$STALL_UOPS,$DISP_STALL1,stalled-cycles-backend,stalled-cycles-frontend"
      EVT="cpu-clock,instructions,cycles,$STALL_UOPSIC,$STALL_UOPS_C,$STALL_UOPS_I,$STALL_UOPS"
      #EVTF="cpu-clock,msr/aperf/,msr/mperf/,msr/tsc/,msr/irperf/"
      IRPERF=
      if [ -e /sys/devices/msr/events/irperf ]; then
        IRPERF=",msr/irperf/"
      else
        IRPERF=",instructions"
      fi
      if [ "$CPU_DECODE" == "Zen Naples/Whitehaven/Summit Ridge/Snowy Owl" ]; then
        IRPERF=",instructions"
      fi
      EVTF="cpu-clock,msr/aperf/,msr/mperf/$IRPERF"
      CYCLES_ANY="cpu/name='cycles_any',event=0x76,cmask=0x1,inv=0/"
      BR_MISP_CYCLES="cpu/name='br_misp_cycles',event=0xc3,cmask=0x1,inv=0/"
      RET_INST_CYCLES="cpu/name='ret_inst_cycles',event=0xc0,cmask=0x1,inv=0/"
      RET_UOPS="cpu/name='ret_uops',event=0xc1/"
      RET_UOPS_CYCLES="cpu/name='ret_uops_cycles',event=0xc1,cmask=0x1,inv=0/"
      DISP_0UOPS_CYCLES="cpu/name='disp_0uops_cycles',event=0xa9,cmask=0x01,inv=0/"
      if [ -e /sys/devices/amd_df ]; then
        MEMBW=",amd_df/name='unc0_read_write',event=0x7,umask=0x38/,amd_df/name='unc1_read_write',event=0x47,umask=0x38/,amd_df/name='unc2_read_write',event=0x87,umask=0x38/,amd_df/name='unc3_read_write',event=0xc7,umask=0x38/,amd_df/name='unc4_read_write',event=0x107,umask=0x38/,amd_df/name='unc5_read_write',event=0x147,umask=0x38/,amd_df/name='unc6_read_write',event=0x187,umask=0x38/,amd_df/name='unc7_read_write',event=0x1c7,umask=0x38/"
        if [ "$skts" -gt "1" ]; then
          MEMBW="$MEMBW,amd_df/name='qpi_data_bandwidth_tx0',event=0x7c7,umask=0x02/,amd_df/name='qpi_data_bandwidth_tx1',event=0x807,umask=0x02/,amd_df/name='qpi_data_bandwidth_tx2',event=0x847,umask=0x02/,amd_df/name='qpi_data_bandwidth_tx3',event=0x887,umask=0x02/"
        fi
      fi
      if [ -e /sys/devices/amd_l3 ]; then
        #L3ACC=",amd_l3/name='L3_accesses',event=0x04,umask=0xff/,amd_l3/name='L3_misses',event=0x04,umask=0x01/"
        L3ACC=",amd_l3/name='L3_accesses',event=0x04,umask=0xff/"
        L3LAT=",amd_l3/name='L3_lat_out_cycles',event=0x90,umask=0x00/,amd_l3/name='L3_lat_out_misses',event=0x9a,umask=0x1f/"
      fi
      MEM_LCL="cpu/name='mem_local',event=0x43,umask=0x08/"
      MEM_LCL="cpu/name='mem_local',event=0x43,umask=0x0b/"
      MEM_RMT="cpu/name='mem_remote',event=0x43,umask=0x40/"
      MEM_RMT="cpu/name='mem_remote',event=0x43,umask=0x50/"
      HWPF_LCL="cpu/name='hwprefetch_local',event=0x5a,umask=0x0b/"
      HWPF_RMT="cpu/name='hwprefetch_remote',event=0x5a,umask=0x54/"
      HWPF_LCL="cpu/name='hwprefetch_local',event=0x5a,umask=0x0f/"
      HWPF_RMT="cpu/name='hwprefetch_remote',event=0x5a,umask=0x50/"
      CK_PWR=`echo "$PERF_LIST"list|grep 'power/energy-pkg/'`
      PWR_EVT=
      if [ "$CK_PWR" != "" ]; then
        PWR_EVT=",power/energy-pkg/"
      fi
      EVT="$EVTF,${RET_INST_CYCLES},${RET_UOPS_CYCLES}${MEMBW}${L3ACC}${L3LAT},$HWPF_LCL,$HWPF_RMT,$MEM_LCL,$MEM_RMT${PWR_EVT}"
      #EVT="$EVTF,$DISP_STALL1,$DISP_STALL0,stalled-cycles-backend,stalled-cycles-frontend"
    else
      # ice lake topdown events
      #  topdown-bad-spec OR cpu/topdown-bad-spec/
      #  topdown-be-bound OR cpu/topdown-be-bound/
      #  topdown-fe-bound OR cpu/topdown-fe-bound/
      #  topdown-retiring OR cpu/topdown-retiring/ 
      TD_EVTS=
      if [ "$CPU_DECODE" == "Ice Lake" ]; then
        RC=`echo "$PERF_LIST" | grep 'topdown-retiring'`
        if [ "$RC" != "" ]; then
          TD_EVTS=",cpu/slots/,cpu/name='topdown-bad-spec',event=0xa4,umask=0x8/,cpu/name='topdown-be-bound',event=0xa4,umask=0x02/,cpu/name='topdown-retiring',event=0xc2,umask=0x02/,cpu/name='int_misc.uop_dropping',event=0x0d,umask=0x10/,cpu/name='int_misc.recovery_cycles',event=0x0d,umask=0x01,cmask=0x1,edge=1/"
          #TD_EVTS=",cpu/slots/,cpu/name='topdown-bad-spec',event=0xa4,umask=0x8/,cpu/name='topdown-be-bound',event=0xa4,umask=0x02/,cpu/name='topdown-retiring',event=0xc2,umask=0x02/,cpu/name='int_misc.uop_dropping',event=0x0d,umask=0x10/"
        fi
      else
        UOPS_ISSUED_ANY=",cpu/event=0x0e,umask=0x01,name='uops_issued.any'/"
        UOPS_RETIRED_RETIRES_SLOTS=",cpu/event=0xc2,umask=0x02,name='uops_retired.retire_slots'/"
        INT_MISC_RECOVERY=",cpu/event=0x0d,umask=0x01,any=1,period=2000003,name='int_misc.recovery_cycles_any'/"
      fi
     if [ "$PID" == "" ]; then
      IMC_UMASK=0x0f
      if [ "$CPU_DECODE" == "Ice Lake" ]; then
        # see https://software.intel.com/content/dam/develop/external/us/en/documents-tps/639778%20ICX%20UPG%20v1.pdf
        IMC_UMASK=0x3f
      fi
      IMC=
      for ((i=0; i < 8; i++)); do
        if [ -e /sys/devices/uncore_imc_${i} ]; then
          IMC="${IMC},uncore_imc_${i}/name='unc"$i"_read_write',umask=${IMC_UMASK},event=0x04/"
        fi
      done
      UPI0=
      UPI1=
      UPI2=
      GOT_QPI_EVT=`echo $PERF_LIST | grep qpi_data_bandwidth_tx`
      if [ "$GOT_QPI_EVT" != "" ]; then
        UPI0=",qpi_data_bandwidth_tx"
      fi
      if [ -e /sys/devices/uncore_upi_0 ]; then
       UPI0=",uncore_upi_0/event=0x02,umask=0x0f,name='qpi_data_bandwidth_tx0'/"
      fi
      if [ "$GOT_QPI_EVT" == "" ]; then
      if [ -e /sys/devices/uncore_qpi_0 ]; then
       UPI0=",uncore_qpi_0/event=0x0,umask=0x02,name='qpi_data_bandwidth_tx0'/"
      fi
      fi
      if [ "1" == "1" ]; then
        if [ -e /sys/devices/uncore_upi_1 ]; then
         UPI1=",uncore_upi_1/event=0x02,umask=0x0f,name='qpi_data_bandwidth_tx1'/"
        fi
        if [ "$GOT_QPI_EVT" == "" ]; then
        if [ -e /sys/devices/uncore_qpi_1 ]; then
         UPI1=",uncore_qpi_1/event=0x0,umask=0x02,name='qpi_data_bandwidth_tx1'/"
        fi
        fi
        if [ -e /sys/devices/uncore_upi_2 ]; then
         UPI2=",uncore_upi_2/event=0x02,umask=0x0f,name='qpi_data_bandwidth_tx2'/"
        fi
      fi
      SKT_EVT="${IMC}${UPI0}${UPI1}${UPI2}"
      UNC_CHA=
      for ((i=0; i < 20; i++)); do
        if [ -e /sys/devices/uncore_cha_${i} ]; then
# icx from https://perfmon-events.intel.com/
# UNC_CHA_TOR_INSERTS.IA_MISS_DRD
# EventSel=35H UMask=21H Cn_MSR_PMON_BOX_FILTER1=40433H
# Counter=0,1,2,3
# from https://lkml.org/lkml/2021/5/20/2174
# {
#> +        "BriefDescription": "TOR Inserts : All requests from iA Cores",
#> +        "Counter": "0,1,2,3",
#> +        "CounterType": "PGMABLE",
#> +        "EventCode": "0x35",
#> +        "EventName": "UNC_CHA_TOR_INSERTS.IA",
#> +        "PerPkg": "1",
#> +        "UMask": "0xC001FF01",
#> +        "UMaskExt": "0xC001FF",
#> +        "Unit": "CHA"
#> +    },
#"BriefDescription": "TOR Inserts : DRds issued by iA Cores that Missed the LLC",
#> +        "Counter": "0,1,2,3",
#> +        "CounterType": "PGMABLE",
#> +        "EventCode": "0x35",
#> +        "EventName": "UNC_CHA_TOR_INSERTS.IA_MISS_DRD",
#> +        "PerPkg": "1",
#> +        "UMask": "0xC817FE01",
#> +        "UMaskExt": "0xC817FE",
#"BriefDescription": "TOR Inserts : All requests from iA Cores that Missed the LLC",
#> +        "Counter": "0,1,2,3",
#> +        "CounterType": "PGMABLE",
#> +        "EventCode": "0x35",
#> +        "EventName": "UNC_CHA_TOR_INSERTS.IA_MISS",
#> +        "PerPkg": "1",
#> +        "UMask": "0xC001FE01",
#> +        "UMaskExt": "0xC001FE",
#> +        "BriefDescription": "TOR Occupancy : All requests from iA Cores that Missed the LLC",
#> +        "CounterType": "PGMABLE",
#> +        "EventCode": "0x36",
#> +        "EventName": "UNC_CHA_TOR_OCCUPANCY.IA_MISS",
#> +        "PerPkg": "1",
#> +        "UMask": "0xC001FE01",
#> +        "UMaskExt": "0xC001FE",
#> +        "Unit": "CHA"
#> +        "BriefDescription": "TOR Occupancy : DRds issued by iA Cores that Missed the LLC",
#> +        "CounterType": "PGMABLE",
#> +        "EventCode": "0x36",
#> +        "EventName": "UNC_CHA_TOR_OCCUPANCY.IA_MISS_DRD",
#> +        "PerPkg": "1",
#> +        "UMask": "0xC817FE01",
#> +        "UMaskExt": "0xC817FE",
#
#> +        "BriefDescription": "All DRAM CAS commands issued",
#> +        "Counter": "0,1,2,3",
#> +        "CounterType": "PGMABLE",
#> +        "EventCode": "0x04",
#> +        "EventName": "UNC_M_CAS_COUNT.ALL",
#> +        "PerPkg": "1",
#> +        "UMask": "0x3f",
#> +        "Unit": "iMC"
          if [ "$CPU_DECODE" == "Ice Lake" ]; then
          #below uses all requests that missed
          #UNC_CHA="${UNC_CHA},uncore_cha_${i}/event=0x35,umask=0xC001FF01,config1=0xC001FF,name='UNC_CHA_TOR_INSERTS.IA.0x40433'/,uncore_cha_${i}/event=0x35,umask=0xC001FE01,config1=0xC001FE,name='UNC_CHA_TOR_INSERTS.IA_MISS.0x40433'/,uncore_cha_${i}/event=0x36,umask=0xC001FE01,config1=0xC001FE,name='UNC_CHA_TOR_OCCUPANCY.IA_MISS.0x40433'/,uncore_cha_${i}/event=0x0,umask=0x0,name='UNC_CHA_CLOCKTICKS'/"
          #below uses drd requests that missed
          UNC_CHA="${UNC_CHA},uncore_cha_${i}/event=0x35,umask=0xC001FF01,config1=0xC001FF,name='UNC_CHA_TOR_INSERTS.IA.0x40433'/,uncore_cha_${i}/event=0x35,umask=0xC817FE01,config1=0xC817FE,name='UNC_CHA_TOR_INSERTS.IA_MISS.0x40433'/,uncore_cha_${i}/event=0x36,umask=0xC817FE01,config1=0xC817FE,name='UNC_CHA_TOR_OCCUPANCY.IA_MISS.0x40433'/,uncore_cha_${i}/event=0x0,umask=0x0,name='UNC_CHA_CLOCKTICKS'/"
          else
          UNC_CHA="${UNC_CHA},uncore_cha_${i}/event=0x35,umask=0x31,config1=0x12d4043300000000,name='UNC_CHA_TOR_INSERTS.IA.0x40433'/,uncore_cha_${i}/event=0x35,umask=0x21,config1=0x12d4043300000000,name='UNC_CHA_TOR_INSERTS.IA_MISS.0x40433'/,uncore_cha_${i}/event=0x36,umask=0x21,config1=0x12d4043300000000,name='UNC_CHA_TOR_OCCUPANCY.IA_MISS.0x40433'/,uncore_cha_${i}/event=0x0,umask=0x0,name='UNC_CHA_CLOCKTICKS'/"
          fi
        fi
        if [ -e /sys/devices/uncore_cbox_${i} ]; then
	  UNC_CHA="${UNC_CHA},uncore_cbox_${i}/event=0x35,umask=0x3,filter_opc=0x182,name='UNC_C_TOR_INSERTS.MISS_OPCODE.0x182'/,uncore_cbox_${i}/event=0x36,umask=0x3,filter_opc=0x182,name='UNC_C_TOR_OCCUPANCY.MISS_OPCODE.0x182'/,uncore_cbox_${i}/event=0x0,umask=0x0,name='UNC_C_CLOCKTICKS'/"

        fi
      done
      #GOT_OFFC_EVT=`echo $PERF_LIST | grep offcore_requests.demand_data_rd`
      #if [ "$GOT_OFFC_EVT" != "" ]; then
      #  OFFC=",offcore_requests.demand_data_rd,offcore_requests_outstanding.demand_data_rd"
      #else
      GOT_OFFC_EVT=`echo $PERF_LIST | grep offcore_requests_outstanding.l3_miss_demand_data_rd`
      if [ "$GOT_OFFC_EVT" != "" ]; then
      OFFC=",offcore_requests_outstanding.l3_miss_demand_data_rd,offcore_requests.l3_miss_demand_data_rd"
      fi
      #OFFC=
      #if [ -e /sys/devices/cpu ]; then
      #OFFC=",cpu/name='offcore_requests_outstanding.l3_miss_demand_data_rd',umask=0x10,event=0x60/,cpu/name='offcore_requests.l3_miss_demand_data_rd',umask=0x10,event=0xb0/"
      #fi
      #fi
    fi
    #EVT="instructions,cycles,ref-cycles,LLC-load-misses${EVT}"
    CK_PWR=`$PERF_BIN list|grep 'power/energy-pkg/'`
    PWR_EVT=
    if [ "$CK_PWR" != "" ]; then
      PWR_EVT=",power/energy-pkg/"
    fi
    GOT_IDQ_EVT=`echo $PERF_LIST | grep idq_uops_not_delivered.core`
    IDQ_EVT=
    if [ "$GOT_IDQ_EVT" != "" ]; then
      IDQ_EVT=",idq_uops_not_delivered.core"
    else
      if [ "$TD_EVTS" != "" ]; then
        IDQ_EVT=",cpu/name='idq_uops_not_delivered.core',event=0x9c,umask=0x01/"
      fi
    fi
    UOP_EVT=
    #GOT_UOP_EVT=`echo $PERF_LIST | grep uops_retired.retire_slots`
    #if [ "$GOT_UOP_EVT" != "" ]; then
    #  UOP_EVT=",uops_retired.retire_slots"
    #fi
    GOT_THA_EVT=`echo $PERF_LIST | grep cpu_clk_unhalted.thread_any`
    THA_EVT=
    if [ "$GOT_THA_EVT" != "" ]; then
      THA_EVT=",cpu_clk_unhalted.thread_any"
    fi
    SKT_EVT="${SKT_EVT}${PWR_EVT}${EVT}${UNC_CHA}"
    #EVT="cpu-clock,task-clock,instructions,cycles,ref-cycles,idq_uops_not_delivered.core,uops_retired.retire_slots,cpu_clk_unhalted.thread_any,power/energy-pkg/${EVT}${UNC_CHA}${OFFC}"
    EVT="cpu-clock,instructions,msr/aperf/,msr/mperf/${TD_EVTS}${IDQ_EVT}${UOP_EVT}${THA_EVT}${UOPS_ISSUED_ANY}${UOPS_RETIRED_RETIRES_SLOTS}${INT_MISC_RECOVERY}${OFFC}${SKT_EVT}"
    fi
    #echo "do: $PERF_BIN stat -x \";\"  --per-socket -a -I $ms -o $FL -e $EVT" > /dev/stderr
    #echo "do: $PERF_BIN stat -x \";\"  --per-socket -a -I $ms -o $FL -e $EVT"
    if [ "$PID" != "" ]; then
        DO_CMD=" --pid $PID "
    else
      if [ "$EXE_IN" == "" ]; then
        DO_CMD="$SCR_DIR/pfay1_sleep.sh"
        OPT_A=" -a "
      else
        DO_CMD="$EXE_IN"
        OPT_A=" -a "
      fi
    fi
    if [ "$CPU_LIST_IN" != "" ]; then
      #OPT_A=" $OPT_A -C $CPU_LIST_IN "
      OPT_A=" -C $CPU_LIST_IN "
    fi
    if [ "$WARGS" != "" ]; then
      OPT_A=" $OPT_A $WARGS "
    fi
    echo  "$0.$LINENO foregrnd pid wait ms do_cmd: $FOREGRND $PID $WAIT_IN $ms $DO_CMD $EXE_ARGS"
    if [ "$PID" == "" -a "$WAIT_IN" == ""  ]; then
      echo $PERF_BIN stat -x ";" --append $OPT_A -I $ms -o $FL -e "$EVT" $DO_CMD $WAIT $EXE_ARGS
      if [ "$FOREGRND" == "0" ]; then
           $PERF_BIN stat -x ";" --append $OPT_A -I $ms -o $FL -e "$EVT" $DO_CMD $WAIT $EXE_ARGS &
      else
           $PERF_BIN stat -x ";" --append $OPT_A -I $ms -o $FL -e "$EVT" $DO_CMD $WAIT $EXE_ARGS
      fi
      PRF_PID=$!
      echo "started perf pid= $PRF_PID monitoring $PID. going to sleep $WAIT seconds"
    else
      echo $0.$LINENO $PERF_BIN stat -x ";" --append $OPT_A -I $ms -o $FL -e "$EVT" $DO_CMD $WAIT $EXE_ARGS
      if [ "$FOREGRND" == "1" -a "$PID" != "" -a "$WAIT_IN" != ""  ]; then
           $PERF_BIN stat -x ";" --append $OPT_A -I $ms -o $FL -e "$EVT" $DO_CMD $WAIT $EXE_ARGS
      else
        if [ "$FOREGRND" == "0" ]; then
           $PERF_BIN stat -x ";" --append $OPT_A -I $ms -o $FL -e "$EVT" $DO_CMD $WAIT $EXE_ARGS &
        else
           $PERF_BIN stat -x ";" --append $OPT_A -I $ms -o $FL -e "$EVT" $DO_CMD $WAIT $EXE_ARGS
        fi
      PRF_PID=$!
      echo "started perf pid= $PRF_PID doing $DO_CMD $WAIT seconds in background"
      fi
    fi
      echo "$PRF_PID" > $PRFFILE_PID
      if [ "$FOREGRND" == "0" ]; then
      echo $PRF_PID > ~/perf.pid
      TM_BEG=`date "+%s"`
      TM_END=$(($TM_BEG+$WAIT+1))
      TM_CUR=$TM_BEG
      while [ $TM_CUR -lt $TM_END ]; do
        if [ "$GOT_QUIT" == "1" ]; then
          break
        fi
        sleep $INTRVL
        if [ -e $DOPERF_STOP ]; then
          RESP=`cat $DOPERF_STOP`
          if [ "$RESP" == "$BASHPID" ]; then
             echo "$0.$LINENO: quiting due to $DOPERF_STOP pid= $BASHPID"
             rm $DOPERF_STOP
             break
          fi
        fi
        TM_CUR=`date "+%s"`
      done
       if [ "$GOT_QUIT" == "0" ]; then
        echo "$0.$LINENO finished sleep $WAIT"
        kill -2 $PRF_PID
        echo "$0.$LINENO did kill -2 $PRF_PID"
       fi
      fi
    #TSK_PID[$TSKj]=$!
#wait
echo $SV_WATCHDOG > /proc/sys/kernel/nmi_watchdog

tstmp=`date "+%Y%m%d_%H%M%S"`
ts_end=`date "+%s.%N"`
ts_elap=`$AWK_BIN -v ts_beg="$ts_beg" -v ts_end="$ts_end" 'BEGIN{printf("%f\n", (ts_end+0.0)-(ts_beg+0.0));exit;}'`
echo "$tstmp $ts_end end elapsed_secs $ts_elap"  >> $RUN_CMDS_LOG

 
