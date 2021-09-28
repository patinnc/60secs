#!/bin/bash

# set_freq.sh v1.3
# v1.3 add showing Haswell registers (assuming they are same as Broadwell
#      and doing modprobe msr if it is not loaded

# usage args: reset|show|allcore|set 0xYY
#  if arg1==reset then set the turbo freq MSRs back to their defaults
#      note that I got the defaults from a bdw 1T dell box and quanta cascade lake box
#  if arg1==show  then show the values of the turbo freq MSRs 
#  if arg1==allcore then broadwell freq is capped at 2.3 GHz and cascade lake at 2.7 Ghz
#  if arg1==set   then arg2=hex freq to which you turbo MSRs set
# for instance ./set_freq.sh set 0x15  # to set freq to 2.1 Ghz
#   note that the processor may not allow you to change freq below some frequency
#   For instance, broadwell seems to have a lower limit of 1.2 GHz
#
# all MSR info from Intel® 64 and IA-32 Architectures Software Developer’s Manual Volume 4: Model-Specific Registers
# Order Number: 335592-071US October 2019
# Broadwell fam_mod=06_56 fam_mod=06_4f MSR info from SDM v4
#   MSR_TURBO_RATIO_LIMIT  0x1ad  Table 2-36
#   MSR_TURBO_RATIO_LIMIT1 0x1ae  Table 2-36
#   MSR_TURBO_RATIO_LIMIT2 0x1af  Table 2-36/2-32
#   MSR_TURBO_RATIO_LIMIT3 0x1ac  Table 2-37  06_56h
#   MSR_TURBO_RATIO_LIMIT3 0x1ac  Table 2-38  06_4fh
# Cascade Lake and SkyLake fam_mod=06_55 MSR info from SDM v4
#   MSR_TURBO_RATIO_LIMIT       0x1ad  Table 2-45
#   MSR_TURBO_RATIO_LIMIT_CORES 0x1ae  Table 2-45
#
# milan  ppr_B1_pub_1.pdf  Preliminary Processor Programming Reference (PPR) for AMD Family 19h Model 01h, Revision B1 Processors Volume 1 of 2
#    55898 Rev 0.50 - May 27, 2021 PPR Vol 1 for AMD Family 19h Model 01h B1
# MSRC001_0015 [Hardware Configuration] (Core::X86::Msr::HWCR)
#  bit 25  CpbDis: core performance boost disable. Read-write. Reset: 0. 
#     0=CPB is requested to be enabled. 
#     1=CPB is disabled. Specifies whether core performance boost is requested to be enabled or disabled.
#       If core performance boost is disabled while a core is in a boosted P-state, the core automatically
#       transitions to the highest performance non-boosted P-state.
# MSRC001_006[4...B] [P-state [7:0]] (Core::X86::Msr::PStateDef)
#   CpuFid[7:0]: core frequency ID. Read-write. Reset: XXh. Specifies the core frequency multiplier. The core COF is a function of CpuFid and CpuDid, and defined by CoreCOF.

SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
GOV_IN=
FREQ_IN=
FORCE_IN=
DID_GOV=0
AWK=mawk

while getopts "hg:f:F:" opt; do
  case ${opt} in
    g )
      GOV_IN=$OPTARG
      ;;
    f )
      FREQ_IN=$OPTARG
      ;;
    F )
      FORCE_IN=$OPTARG
      ;;
    h )
      echo "$0 run compute and disk benchmarks using config files in cfg_dir and put results in results dir"
      echo "Usage: $0 [-h] [ -g performance|powersave|ondemand|show ] [ -f freq_in_hex|allcore|reset ]"
      echo "   -g performance|powersave|ondemand|show  ondemand is for AMD"
      echo "   -f freq_in_hex|allcore|reset"
      echo "      on Intel, if the cpu chip (like cascade lake) and cpu_model_name is not in the list of supported chips then MSRs will not be changed."
      echo "      on AMD Milan only allcore and reset are supported but you have to add the -F 1 option to force it."
      echo "         AMD Milan: allcore disables CPB (core performance boost) which sets the freq to max 2.3 GHz (on the 96cpu box I checked)."
      echo "         AMD Milan: allcore on milan is not setting the freq to the all-core-turbo freq. It just disables turbo mode (and turbo frequencies)."
      echo "         AMD Milan: reset enables CPB (core performance boost) which allows boost freq up to 3.6 GHz (on the 96cpu box I checked)."
      echo "   -F 0|1  if 1 then do the reset or allcore on AMD"
      echo "         the default is 0: don't try to change frequencies on AMD"
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

HST=`hostname`
if [ -e /proc/cpuinfo ]; then
  CPU_VENDOR=`$AWK '/^vendor_id/ { printf("%s\n", $(NF));exit;}' /proc/cpuinfo`
  CPU_MODEL=`$AWK '/^model/ { if ($2 == ":") {printf("%s\n", $(NF));exit;}}' /proc/cpuinfo`
  CPU_MOD_NM=`$AWK '/^model name/ { pos=index($0, ":"); printf("%s\n", substr($0, pos+2, length($0)));exit;}' /proc/cpuinfo`
  CPU_FAMILY=`$AWK '/^cpu family/ { printf("%s\n", $(NF));exit;}' /proc/cpuinfo`
fi
NUM_CPUS=`grep processor /proc/cpuinfo | wc -l`
echo "CPU_VENDOR= $CPU_VENDOR CPU_MODEL= $CPU_MODEL CPU_FAMILY= $CPU_FAMILY, model_name= $CPU_MOD_NM"
CPU_NAME=`$SCR_DIR/decode_cpu_fam_mod.sh`
if [ "$?" != "0" ]; then
  echo "$0.$LINENO decode_cpu_fam_mod.sh returned error. CPU_NAME= \"$CPU_NAME\". Bye"
  echo "$0.$LINENO probably need to add a new cpu to decode_cpu_fam_mod.sh\". Bye"
  exit 1
fi

DO_MSRS=0
if [ "$CPU_VENDOR" == "GenuineIntel" ]; then
  DO_MSRS=1
else
  if [ "$CPU_VENDOR" == "AuthenticAMD" -a "$FORCE_IN" == "1" ]; then
    DO_MSRS=1
  fi
fi


function show_gov() {
 echo "show gov $1"
  DID_GOV=1
  NUM_CPUS_M1=$((NUM_CPUS-1))
  VALS=
  for i in `seq 0 $NUM_CPUS_M1`; do
    V[$i]=`cat /sys/devices/system/cpu/cpufreq/policy$i/scaling_governor`
    if [ "$i" == "0" ]; then
      VALS=${V[0]}
    fi
    if [ "${V[$i]}" != "${V[0]}" ]; then
      VALS="$VALS ${V[$i]}"
    fi
  done
  echo "governor cpus 0..$NUM_CPUS_M1 /sys/devices/system/cpu/cpufreq/policy*/scaling_governor to $VALS"
 #exit
}

function set_gov() {
 echo "set gov"
 if [ "$1" == "performance" -o "$1" == "powersave"  -o "$1" == "ondemand" ]; then
  DID_GOV=1
  echo "set gov to $1"
  NUM_CPUS_M1=$((NUM_CPUS-1))
  for i in `seq 0 $NUM_CPUS_M1`; do
    echo $1 > /sys/devices/system/cpu/cpufreq/policy$i/scaling_governor
  done
  show_gov $GOV_IN
  #echo "set cpus 0..$NUM_CPUS_M1 /sys/devices/system/cpu/cpufreq/policy*/scaling_governor to $1"
  if [ "$GOV_IN" != "" ]; then
    exit 0
  fi
 fi
}


IPSTATE=/sys/devices/system/cpu/intel_pstate/status
if [ -e $IPSTATE ]; then
  PSTATE=`cat $IPSTATE`
  echo "$IPSTATE = $PSTATE"
  echo "   valid values are: off passive active"
else
  echo "intel_pstate driver seems to not be loaded"
fi

CPUFRQ_DIR=/sys/devices/system/cpu/cpufreq/
if [ -d $CPUFRQ_DIR ]; then
  RESP=`ls -l $CPUFRQ_DIR`
  if [ "$RESP" == "total 0" ]; then
    echo "cpufreq dir $CPUFRQ_DIR is empty"
  else
    echo "some cpufreq governor is seems active"
    echo "see dir $CPUFRQ_DIR"
  fi
else
  echo "no cpufreq governor found"
fi
# cat /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 
# 3000000
# cat /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq 


if [ "$DO_MSRS" == "1" ]; then
  DEV_CPU_MSR=/dev/cpu/0/msr
  if [ ! -e $DEV_CPU_MSR ]; then
    modprobe msr
    if [ ! -e $DEV_CPU_MSR ]; then
      # probably need to do 'modprobe msr'
      echo "$0.$LINENO didn't find $DEV_CPU_MSR file. Probably need to do 'modprobe msr' as root"
      MSR_MODULE_LOADED=`lsmod | grep msr | wc -l`
      if [ "$MSR_MODULE_LOADED" == "0" ]; then
        echo "$0.$LINENO msr module not loaded. It is required by this script (for rdmsr and wrmsr to work)"
        echo "$0.$LINENO please run (as root) 'modprobe msr'"
        exit 1
      fi
      echo "$0.$LINENO didn't find $DEV_CPU_MSR file. Not sure if rdmsr/wrmsr will work"
      exit 1
    fi
  fi
fi

if [ "$DO_MSRS" == "1" ]; then
  echo "msr kernel module loaded. $DEV_CPU_MSR exists"
  MSR_0x1ad=`rdmsr -p 0 0x10`
  RC=$?
  if [ "$RC" != "0" ]; then
    echo "$0.$LINENO MSR 0x1ad= $MSR_0x1ad, rc= $RC"
    apt-get install msr-tools
  fi
fi


# cascade lake 2nd gen stuff from https://www.intel.com/content/www/us/en/products/docs/processors/xeon/2nd-gen-xeon-scalable-spec-update.html
# 2nd gen xeon scalable cpus: cascade lake sku is 82xx, 62xx, 52xx, 42xx 32xx W-32xx  from https://www.intel.com/content/www/us/en/products/docs/processors/xeon/2nd-gen-xeon-scalable-spec-update.html
# skylake 1st gen stuff from https://www.intel.com/content/www/us/en/processors/xeon/scalable/xeon-scalable-spec-update.html
# 1st gen xeon scalable cpus: 81xx, 61xx, 51xx, 81xxT, 61xxT 81xxF, 61xxF, 51xx, 41xx, 31xx, 51xxT 41xxT, 51xx7, 

if [ "$GOV_IN" == "" -a "$FREQ_IN" == "" ]; then
  ACTION=show
fi
if [ "$FREQ_IN" != "" ]; then
  ACTION=set
fi
if [ "$FREQ_IN" == "reset" ]; then
  ACTION=reset
fi
if [ "$FREQ_IN" == "allcore" ]; then
  ACTION=allcore
fi
if [ "$ACTION" == "set" ]; then
  if [[ $FREQ_IN != "0x"* ]]; then
    # assume freq in ghz like 2.7 or 3.0
    FRQ=`$AWK -v frq="$FREQ_IN" 'BEGIN{val=frq*10.0; printf("0x%x\n", val);exit;}'`
    if [ "$FRQ" == "0x0" ]; then
      echo "$0.$LINENO problems converting -f $FREQ_IN to hex string. got 0x0. Expect a string like -f 2.7. Bye".
      exit 1
    fi
  fi
fi
if [ "$GOV_IN" != "" ]; then
 if [ "$GOV_IN" != "performance" -a "$GOV_IN" != "powersave" -a "$GOV_IN" != "show" -a "$GOV_IN" != "ondemand" ]; then
  echo "$0.$LINENO arg -g arg must be performance or powersave or show. got -g $GOV_IN. bye"
  exit 1
 fi
fi
#if [ "$ACTION" != "show" -a "$ACTION" != "set" -a "$ACTION" != "reset" -a "$ACTION" != "allcore" -a "$ACTION" != "performance" -a "$ACTION" != "powersave" ]; then
#fi

#ACTION=$1
#if [ "$ACTION" == "" ]; then
#  ACTION=show
#fi

# broadwell uses bit 63 of MSR 0x1ac MSR_TURBO_RATIO_LIMIT3 as a semaphore to signal the cpu to pick up new turbro freqs
# see Table 2-38, section 2.16.2 of Intel SDM v4 MSRs (full SDM reference at top of script)
MSR_SEMA=
echo "CPU_NAME= $CPU_NAME"
MODE="Intel"

case $CPU_NAME in
  *"Cascade"*|*"Ice Lake"*|*"Skylake"*)
    MSR_LIST="0x1ad"
    XMSR_LIST="0x1ae" # the mapping
    ;;
  *"Broadwell"*|*"Haswell"*)
    MSR_LIST="0x1ad 0x1ae 0x1af"
    MSR_SEMA="0x1ac"
    ;;
  *"Milan"*|*"Rome"*)
    # MSRC001_0015 [Hardware Configuration] (Core::X86::Msr::HWCR)
    MSR_LIST="0xc0010015"
    #XMSR_LIST="0xc0010064 0xC0010065 0xC0010066 0xC0010067 0xC0010068 0xC0010069 0xC001006a 0xC001006b"
    MODE="AMD"
    echo "milan"
    ;;
  *)
    echo "$0.$LINENO unsupported cpu $CPU_NAME"
    exit 1
    ;;
esac
#echo "$0.$LINENO bye"
#exit 1

if [ "$GOV_IN" == "" ]; then
if [ "$ACTION" != "show" -a "$ACTION" != "set" -a "$ACTION" != "reset" -a "$ACTION" != "allcore" -a "$ACTION" != "performance" -a "$ACTION" != "powersave" ]; then
  echo "arg1 must be: show or reset (back to default turbo freqs) or 'set 0xyy' (where yy is the hex freq ie. 0x17 is 2.3 GHz) or allcore (cap brdwell at 2.3 Ghz and cascade lake at 2.7 Ghz)"
  echo "or arg1 can be performance or powersave"
  exit
fi
fi

function show_MSRs() {
  if [ "$DO_MSRS" != "1" ]; then
    echo "$0.$LINENO skipping show_MSRS"
    return
  fi
  #echo CORES_PER_SKT="lscpu | $AWK '/Core.s. per socket:/{cps = $4; print cps;}'"
  CORES_PER_SKT=`lscpu | $AWK '/Core.s. per socket:/{cps = $4; print cps;}'`
  echo "=========== $1 ================= MSR_LIST= $MSR_LIST"
  k=0
  for j in $MSR_LIST; do
    MSR=$j
    REGS=`rdmsr --all $MSR`
    ALL_SAME=1
    first_val=
    for i in $REGS; do
      if [ "$first_val" == "" ]; then
        first_val=$i
        if [ "$k" == "0" ]; then
          MSR_FRQ=$i
        fi
	k=$((k+1))
      fi
      if [ "$i" != "$first_val" ]; then
        echo "diff $MSR $i and $first_val"
        ALL_SAME=0
      fi
    done
    if [ $ALL_SAME -eq 1 ]; then
      echo "all cpus have MSR $MSR == $first_val"
      MSR_LIST_0_ALL_SAME=$first_val
    fi
  done
  for j in $XMSR_LIST; do
    MSR=$j
    REGS=`rdmsr --all $MSR`
    ALL_SAME=1
    first_val=
    for i in $REGS; do
      if [ "$first_val" == "" ]; then
        first_val=$i
      fi
      if [ "$i" != "$first_val" ]; then
        echo "diff $MSR $i and $first_val"
        ALL_SAME=0
      fi
    done
    if [ $ALL_SAME -eq 1 ]; then
      echo "all cpus have MSR $MSR == $first_val"
    fi
    MSR_XTR=$first_val
  done
  if [ "$MODE" == "Intel" ]; then
    #echo "cps $CORES_PER_SKT msr_xtr= $MSR_XTR msr_frq= $MSR_FRQ"
    if [ "$CORES_PER_SKT" != "" -a "$CPU_NAME" != "" -a "$MSR_FRQ" != "" ]; then
      $AWK -v cps="$CORES_PER_SKT" -v cpu_name="$CPU_NAME" -v msr_frq="$MSR_FRQ" -v msr_xtr="$MSR_XTR" '
       function hex2dec(str) { return sprintf("%d", str)+0; }
       BEGIN{
         cps += 0;
         for (i=0; i < 8; i++) {
            str1 = "0x" substr(msr_frq, 2*(i)+1, 2);
            frq[i] = hex2dec(str1);
            #printf("str1[%d]= %s, frq= %s\n", i, str1, frq[i]);
            if (cpu_name == "Broadwell" || cpu_name == "Haswell") {
              lmt[i]=8-i;
            } else {
              str2 = "0x" substr(msr_xtr, 2*(i)+1, 2);
              lmt[i] = hex2dec(str2);
            }
            if (cps >= lmt[i]) {
              printf("freq[%d]= %.1f, cores %d\n", i, .1*frq[i], lmt[i]);
            }
         }
         exit(0);
       }'
    fi
  fi
  if [ "$MODE" == "AMD" ]; then
    CBP_STATE=`$AWK -v cps="$CORES_PER_SKT" -v cpu_name="$CPU_NAME" -v msr_frq="$MSR_FRQ" -v msr_xtr="$MSR_XTR" '
     function hex2dec(str) { return sprintf("%d", str)+0; }
     BEGIN{
       cps += 0;
       bit25 = lshift(1, 25);
       v = hex2dec("0x"msr_frq);
       b25set = and(v, bit25);
       #printf("bit25set= %s, bit25= 0x%x, msr_frq= 0x%x msr_f= %s\n", b25set, bit25, v, v);
       if (b25set == 0) {
         printf("enabled\n"); 
       } else {
         printf("disabled\n"); 
       }
       exit(0);
     }'`
     printf "Core Performance Boost (CBP) %s\n" $CBP_STATE
  fi
}

function get_expected_val() {
  EXP_VAL1=
  EXP_VAL2=
  if [[ $CPU_NAME == *"Skylake"* ]]; then
    # from pfay1testing1td-phx3, a 1TD Dell C6420
    EXP_VAL1=1818181818181c1e
    ACT_VAL=18
  elif [[ $CPU_NAME == *"Cascade Lake*"* ]]; then
    if [[ $CPU_MOD_NM == *"Gold 5218 CPU"* ]]; then
      # Intel(R) Xeon(R) Gold 5218 CPU @ 2.30GHz
      EXP_VAL1=1c1c1c1c1f242527
      ACT_VAL=1c
    elif [[ $CPU_MOD_NM == *"Gold 5218R CPU"* ]]; then
      # Model name:            Intel(R) Xeon(R) Gold 5218R CPU @ 2.10GHz
      EXP_VAL1=1d1d1d1f23252628
      ACT_VAL=1d
    elif [[ $CPU_MOD_NM == *"Silver 4214R CPU"* ]]; then
      #  Model name:            Intel(R) Xeon(R) Silver 4214R CPU @ 2.40GHz
      EXP_VAL1=1e1e1e1e1e202123
      ACT_VAL=1e
    elif [[ $CPU_MOD_NM == *"Silver 4214 CPU"* ]]; then
      #  Model name:            Intel(R) Xeon(R) Silver 4214 CPU @ 2.20GHz
      EXP_VAL1=1b1b1b1b1b1d1e20
      ACT_VAL=1b
    else
      echo "$0.$LINENO unhandled cpu model name for $CPU_NAME. Got mod_nm= $CPU_MOD_NM. fix script. Bye"
      exit 1
    fi
  elif [[ $CPU_NAME == *"Ice Lake"* ]]; then
    #wrmsr --all 0x1ad 0x1a1a1a1a1b1e2022
    # Intel(R) Xeon(R) Gold 6336Y CPU @ 2.40GHz
    if [[ $CPU_MOD_NM == *"Gold 5318Y CPU"* ]]; then
      # Model name:                      Intel(R) Xeon(R) Gold 5318Y CPU @ 2.10GHz
      EXP_VAL1=1e1f212324242424
      ACT_VAL=1e
      #EXP_VAL1=1a1a1a1a1b1e2022 # from 4113?
      #ACT_VAL=1a
    elif [[ $CPU_MOD_NM == *"Gold 6336Y CPU"* ]]; then
      # Model name:                      Intel(R) Xeon(R) Gold 5318Y CPU @ 2.10GHz
      EXP_VAL1=1e1f212324242424
      ACT_VAL=1e
      #EXP_VAL1=1a1a1a1a1b1e2022 # from 4113?
      #ACT_VAL=1a
    else
      echo "$0.$LINENO unhandled cpu model name for $CPU_NAME. Got mod_nm= $CPU_MOD_NM. fix script. Bye"
      exit 1
    fi
  elif [[ $CPU_NAME == *"Broadwell"* ]]; then
    if [[ $CPU_MOD_NM == *"CPU E5-2650 v4"* ]]; then # 48 cpus
      EXP_VAL1=191919191a1b1d1d
      EXP_VAL2=1919191919191919
      ACT_VAL=1a
    elif [[ $CPU_MOD_NM == *"CPU E5-2640 v4"* ]]; then # 40 cpus
      EXP_VAL1=1b1c1d1e1f202222
      EXP_VAL2=1a1a1a1a1a1a1a1a
      ACT_VAL=1a
    elif [[ $CPU_MOD_NM == *"CPU E5-2620 v4"* ]]; then # 32 cpus
      EXP_VAL1=1718191a1b1c1e1e
      EXP_VAL2=1717171717171717
      ACT_VAL=17
    else
      echo "$0.$LINENO unhandled cpu model name for $CPU_NAME. Got mod_nm= $CPU_MOD_NM. fix script. Bye"
      exit 1
    fi
  elif [[ $CPU_NAME == *"Haswell"* ]]; then
    if [[ $CPU_MOD_NM == *"CPU E5-2620 v3"* ]]; then # 48 cpus
      EXP_VAL1=1a1a1a1b1c1d2020
      EXP_VAL2=1a1a1a1a1a1a1a1a
      ACT_VAL=1a
    else
      echo "$0.$LINENO unhandled cpu model name for $CPU_NAME. Got mod_nm= $CPU_MOD_NM. fix script. Bye"
      exit 1
    fi
  fi
}

if [ "$ACTION" == "reset" -a "$DO_MSRS" == "1" ]; then
  show_MSRs "before reset " 
  get_expected_val
  case $CPU_NAME in
    *"Cascade"*|*"Ice Lake"*|*"Skylake"*)
      wrmsr --all 0x1ad 0x${EXP_VAL1}
      ;;
    *"Broadwell"*|*"Haswell"*)
      wrmsr --all 0x1ad 0x${EXP_VAL1}
      wrmsr --all 0x1ae 0x${EXP_VAL2}
      wrmsr --all 0x1af 0x${EXP_VAL2}
      wrmsr --all 0x1ac 0x8000000000000000
      ;;
    *"Milan"*|*"Rome"*)
      ;;
    *)
      echo "$0.$LINENO unsupported cpu $CPU_NAME"
      exit 1
      ;;
  esac
  if [[ $CPU_NAME == *"Milan"* ]]; then
    if [ -e /sys/devices/system/cpu/cpufreq/policy0/cpb ]; then
      for ((i=0; i < $NUM_CPUS; i++)); do
        echo 1 > /sys/devices/system/cpu/cpufreq/policy$i/cpb
      done
      printf "Core Performance Boost (CBP) now enabled\n"
      else
      if [ "$MSR_LIST_0_ALL_SAME" != "" ]; then
        #MSR_LIST_0_ALL_SAME=$first_val
        useuse=1
      fi
      if [ "$CBP_STATE" == "enabled" ]; then
        echo "AMD CBP already enabled, nothing to be done"
        else
        echo "cbp_state= disabled, num_cpus= $NUM_CPUS"
        
        for ((i=0; i < $NUM_CPUS; i++)); do
         OVAL=`rdmsr -0 -p $i $MSR_LIST`
         NVAL=`echo $OVAL | $AWK '
       function hex2dec(str) { return sprintf("%d", str)+0; }
       {
        bit25 = lshift(1, 25);
        v = hex2dec("0x"$0);
        b25set = and(v, bit25);
        if(b25set!=0) {
         v = xor(v, bit25);
        }
        printf("0x%x\n", v);
       }'`
        #printf "oval[%d]= %s nval= %s\n" $i $OVAL $NVAL
        wrmsr -p $i $MSR_LIST $NVAL
        done
      fi
    fi
  fi
  show_MSRs "after  reset " 
fi

if [ "$ACTION" == "allcore" -a "$DO_MSRS" == "1" ]; then
  get_expected_val
  if [ "$MODE" == "Intel" ]; then
    #CKVAL=`rdmsr -0 -p 0 0x1ad | $AWK '{v=substr($0, 1, 2);str="";for(i=1;i<=8;i++){str=str""v;}printf("0x%s", str);}'`
    RDVAL=`rdmsr -0 -p 0 0x1ad`
    ALLSAME=`echo $RDVAL | $AWK '{rc=1;v0=substr($0,1,2);for(i=2;i<=8;i++){v=substr($0, i*2-1, 2);if (v!=v0){rc=0;break;}};printf("%d\n",rc);}'`
    CKVAL=`$AWK -v act_val="$ACT_VAL" 'BEGIN{v=act_val;str="";for(i=1;i<=8;i++){str=str""v;}printf("0x%s", str); exit(0);}'`
    echo "rdval= $RDVAL allsame= $ALLSAME  ckval= $CKVAL"
  else
    CKVAL=`rdmsr -0 -p 0 $MSR_LIST | $AWK '{v=substr($0, 1, 2);str="";for(i=1;i<=8;i++){str=str""v;}printf("0x%s", str);}'`
  fi
  show_MSRs "before allcore " 
  if [ "$MODE" == "Intel" ]; then
    if [ "$RDVAL" != "$EXP_VAL1" -a "$ALLSAME" != "1" ]; then
      echo "$0.$LINENO Error on $CPU_NAME. expected MSR_TURBO_RATIO (0x1ad) to be $EXP_VAL1 but got $RDVAL"
      echo "$0.$LINENO This script doesn't know what is the 'right' value for when it does the 'set_freq.sh -f reset"
      echo "$0.$LINENO Probably this is a new (or old) cpu not handled by this script."
      if [ "$FORCE_IN" == "1" ]; then
        echo "$0.$LINENO allowing write due to '-F 1' force option"
      else
        echo "$0.$LINENO bye"
        exit 1
      fi
    fi
  fi
  case $CPU_NAME in
    *"Cascade"*|*"Ice Lake"*|*"Skylake"*)
      wrmsr --all 0x1ad $CKVAL
      ;;
    *"Broadwell"*|*"Haswell"*)
      wrmsr --all 0x1ad 0x${CKVAL}
      wrmsr --all 0x1ae 0x${CKVAL}
      wrmsr --all 0x1af 0x${CKVAL}
      wrmsr --all 0x1ac 0x8000000000000000
      ;;
    *"Milan"*|*"Rome"*)
      ;;
    *)
      echo "$0.$LINENO unsupported cpu $CPU_NAME"
      exit 1
      ;;
  esac
  if [[ $CPU_NAME == *"Milan"* ]]; then
    if [ -e /sys/devices/system/cpu/cpufreq/policy0/cpb ]; then
    for ((i=0; i < $NUM_CPUS; i++)); do
      echo 0 > /sys/devices/system/cpu/cpufreq/policy$i/cpb
    done
    printf "Core Performance Boost (CBP) now disabled\n"
    else
    if [ "$CBP_STATE" == "disabled" ]; then
      echo "AMD CBP already disabled, nothing to be done"
    else
      #echo "cbp_state= disabled"
      
      for ((i=0; i < $NUM_CPUS; i++)); do
       OVAL=`rdmsr -0 -p $i $MSR_LIST`
       NVAL=`echo $OVAL | $AWK '
       function hex2dec(str) { return sprintf("%d", str)+0; }
     {
      bit25 = lshift(1, 25);
      v = hex2dec("0x"$0);
      v = or(v, bit25);
      #if(b25set!=0) {
      # v = xor(v, bit25);
      #}
      printf("0x%x\n", v);
     }'`
      #printf "oval[%d]= %s nval= %s\n" $i $OVAL $NVAL
      wrmsr -p $i $MSR_LIST $NVAL
      done
    fi
    fi
  fi
  show_MSRs "after  allcore" 
fi

if [ "$ACTION" == "show" ]; then
  show_MSRs "show " 
  cat /sys/devices/system/cpu/cpufreq/policy*/scaling_governor | $AWK '
    {
       val=$1;
       if (!(val in lst)) {
          indx++;
          lkup[indx]=val;
          lst[val]=indx;
       }
       i = lst[val];
       tots[i]++;
       recs++;
    }
    END{
      for (i=1; i <= indx; i++) {
        printf("cpus %d of %d have scaling_gov= %s\n", tots[i], recs, lkup[i]);
      }
    }'
fi

# root@pfay1testing1t01-phx3:~# cat /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq 
# 3000000
# root@pfay1testing1t01-phx3:~# cat /sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq 
# 1200000

if [ "$ACTION" == "set" -a "$DO_MSRS" == "1" ]; then
  if [ "$FREQ_IN" == "" ]; then
    echo 'you wanted to do a set freq you have to do -f hex_freq (in hex like 0x15) is missing'
    exit
  fi
  CHG_FREQ=$FREQ_IN
  if [[ $CHG_FREQ == "0x"* ]]; then
    echo "starts with 0x"
    CHG_FREQ=${CHG_FREQ:2}
    echo "using hex string $CHG_FREQ"
  else
    echo "you must enter the freq -f freq_in_hex arg as a hex string like 0x15"
    exit
  fi
  VAR_LEN=${#CHG_FREQ}
  if [ ! $VAR_LEN -eq 2 ]; then
   echo "sorry but you have to enter a 2 byte hex string for the freq or 0x+2byte_string"
   echo 'like 0x10 (16 GHz) or 0x08 (for 800 MHz)'
   exit
  fi
  FREQ_STR=
  for i in `seq 0 7`; do
    FREQ_STR="${FREQ_STR}${CHG_FREQ}"
  done
  echo wrmsr --all 0x1ad 0x$FREQ_STR
       wrmsr --all 0x1ad 0x$FREQ_STR
  if [[ $CPU_NAME == *"Broadwell"* ]]; then
  echo wrmsr --all 0x1ae 0x$FREQ_STR
       wrmsr --all 0x1ae 0x$FREQ_STR
  echo wrmsr --all 0x1af 0x$FREQ_STR
       wrmsr --all 0x1af 0x$FREQ_STR
  echo wrmsr --all 0x1ac 0x8000000000000000
       wrmsr --all 0x1ac 0x8000000000000000
  fi
fi

if [ "$GOV_IN" == "show" ]; then
  show_gov
fi
if [ "$GOV_IN" != "show" -a "$GOV_IN" != "" ]; then
  set_gov $GOV_IN
fi

exit 0
