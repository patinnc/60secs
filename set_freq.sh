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

export LC_ALL=C
SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
GOV_IN=
FREQ_IN=
DID_GOV=0
export AWKPATH=$SCR_DIR
AWK=awk
if [ -e $SCR_DIR/bin/gawk ]; then
 AWK=$SCR_DIR/bin/gawk
fi
echo "AWK= $AWK"

while getopts "hg:f:" opt; do
  case ${opt} in
    g )
      GOV_IN=$OPTARG
      ;;
    f )
      FREQ_IN=$OPTARG
      ;;
    h )
      echo "$0 run compute and disk benchmarks using config files in cfg_dir and put results in results dir"
      echo "Usage: $0 [-h] [ -g performance|powersave|ondemand|show ] [ -f freq_in_hex|allcore|reset ]"
      echo "   -g performance|powersave|ondemand|show  ondemand is for AMD"
      echo "   -f freq_in_hex|allcore|reset"
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
    exit
  fi
 fi
}


HST=`hostname`
NUM_CPUS=`grep processor /proc/cpuinfo | wc -l`
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


DEV_CPU_MSR=/dev/cpu/0/msr
if [ ! -e $DEV_CPU_MSR ]; then
  modprobe msr
  if [ ! -e $DEV_CPU_MSR ]; then
    # probably need to do 'modprobe msr'
    echo "didn't find $DEV_CPU_MSR file. Probably need to do 'modprobe msr' as root"
    MSR_MODULE_LOADED=`lsmod | grep msr | wc -l`
    if [ "$MSR_MODULE_LOADED" == "0" ]; then
      echo "msr module not loaded. It is required by this script (for rdmsr and wrmsr to work)"
      echo "please run (as root) 'modprobe msr'"
      exit
    fi
    echo "didn't find $DEV_CPU_MSR file. Not sure if rdmsr/wrmsr will work"
  fi
fi
echo "msr kernel module loaded. $DEV_CPU_MSR exists"
MSR_0x1ad=`rdmsr -p 0 0x1ad`
RC=$?
if [ "$RC" != "0" ]; then
  echo "MSR 0x1ad= $MSR_0x1ad, rc= $RC"
  apt-get install msr-tools
fi


# cascade lake 2nd gen stuff from https://www.intel.com/content/www/us/en/products/docs/processors/xeon/2nd-gen-xeon-scalable-spec-update.html
# 2nd gen xeon scalable cpus: cascade lake sku is 82xx, 62xx, 52xx, 42xx 32xx W-32xx  from https://www.intel.com/content/www/us/en/products/docs/processors/xeon/2nd-gen-xeon-scalable-spec-update.html
# skylake 1st gen stuff from https://www.intel.com/content/www/us/en/processors/xeon/scalable/xeon-scalable-spec-update.html
# 1st gen xeon scalable cpus: 81xx, 61xx, 51xx, 81xxT, 61xxT 81xxF, 61xxF, 51xx, 41xx, 31xx, 51xxT 41xxT, 51xx7, 
if [ "1" == "2" ]; then
CPU_NAME=`cat /proc/cpuinfo | $AWK '
   @include "decode_cpu_fam_mod.awk"
  /^vendor_id/ {
    vndr=$(NF);
  }
  /^cpu family/ {
    fam=$(NF);
  }
  /^model/ {
    if ($2 == ":") {
      mod=$(NF);
    }
  }
  /^model name/ {
#model name	: Intel(R) Xeon(R) CPU E5-2620 v4 @ 2.10GHz
    n=split($0, arr, ":");
    mod_nm = arr[2];
    #printf("vndr= %s, fam= %s, mod= %s, mod_nm= %s\n", vndr, fam, mod, mod_nm);
    cpu_name=decode_fam_mod(vndr, fam, mod, mod_nm);
    printf("%s\n", cpu_name);
    exit;
  }
  '`
else
    CPU_NAME=`$SCR_DIR/decode_cpu_fam_mod.sh`
fi

CPU_VENDOR=`awk '/^vendor_id/ { printf("%s\n", $(NF));exit;}' /proc/cpuinfo`
CPU_MODEL=`awk '/^model/ { if ($2 == ":") {printf("%s\n", $(NF));exit;}}' /proc/cpuinfo`
CPU_FAMILY=`awk '/^cpu family/ { printf("%s\n", $(NF));exit;}' /proc/cpuinfo`
echo "CPU_VENDOR= $CPU_VENDOR CPU_MODEL= $CPU_MODEL CPU_FAMILY= $CPU_FAMILY"
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
    FRQ=`awk -v frq="$FREQ_IN" 'BEGIN{val=frq*10.0; printf("0x%x\n", val);exit;}'`
    if [ "$FRQ" == "0x0" ]; then
      echo "problems converting -f $FREQ_IN to hex string. got 0x0. Expect a string like -f 2.7. Bye".
      exit
    fi
  fi
fi
if [ "$GOV_IN" != "" ]; then
 if [ "$GOV_IN" != "performance" -a "$GOV_IN" != "powersave" -a "$GOV_IN" != "show" -a "$GOV_IN" != "ondemand" ]; then
  echo "$0.$LINENO arg -g arg must be performance or powersave or show. got -g $GOV_IN. bye"
  exit
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

GOT_CSX_ICX=0
if [[ $CPU_NAME == *"Cascade"* ]]; then
 GOT_CSX_ICX=1
fi
if [[ $CPU_NAME == *"Ice Lake"* ]]; then
 # i don't know that it is correct to assume ICX is the same as CSX but I haven't seen th emanual yet.
 GOT_CSX_ICX=1
fi
if [ "$GOT_CSX_ICX" == "1" ]; then
  MSR_LIST="0x1ad"
  XMSR_LIST="0x1ae" # the mapping
else 
  if [[ $CPU_NAME == *"Skylake"* ]]; then
    MSR_LIST="0x1ad"
    XMSR_LIST="0x1ae" # the mapping
  else
    if [[ $CPU_NAME == *"Broadwell"* ]]; then
      MSR_LIST="0x1ad 0x1ae 0x1af"
      MSR_SEMA="0x1ac"
    else
      if [[ $CPU_NAME == *"Haswell"* ]]; then
        MSR_LIST="0x1ad 0x1ae 0x1af"
        MSR_SEMA="0x1ac"
        if [ "$ACTION" != "show" ]; then
          echo "$0.$LINENO only support Broadwell, Skylake and Cascade Lake for ACTION= $ACTION so far. Bye."
          exit
        fi
      else
        echo "$0.$LINENO only support Broadwell, Skylake and Cascade Lake so far. Bye."
        if [ -e /sys/devices/system/cpu/cpufreq/policy0/scaling_governor ]; then
          if [ "$GOV_IN" != "" ]; then
            set_gov $GOV_IN
          else
            show_gov
          fi
        fi
        exit
      fi
    fi
  fi
fi

if [ "$GOV_IN" == "" ]; then
if [ "$ACTION" != "show" -a "$ACTION" != "set" -a "$ACTION" != "reset" -a "$ACTION" != "allcore" -a "$ACTION" != "performance" -a "$ACTION" != "powersave" ]; then
  echo "arg1 must be: show or reset (back to default turbo freqs) or 'set 0xyy' (where yy is the hex freq ie. 0x17 is 2.3 GHz) or allcore (cap brdwell at 2.3 Ghz and cascade lake at 2.7 Ghz)"
  echo "or arg1 can be performance or powersave"
  exit
fi
fi

function show_MSRs() {
  LSCPU_LINES=`lscpu`
  echo CORES_PER_SKT="lscpu | $AWK '/Core.s. per socket:/{cps = $4; print cps;}'"
  CORES_PER_SKT=`lscpu | $AWK '/Core.s. per socket:/{cps = $4; print cps;}'`
  echo "=========== $1 ================="
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
  echo "cps $CORES_PER_SKT msr_xtr= $MSR_XTR msr_frq= $MSR_FRQ"
  if [ "$CORES_PER_SKT" != "" -a "$CPU_NAME" != "" -a "$MSR_FRQ" != "" ]; then
    $AWK -v cps="$CORES_PER_SKT" -v cpu_name="$CPU_NAME" -v msr_frq="$MSR_FRQ" -v msr_xtr="$MSR_XTR" '
     BEGIN{
       cps += 0;
       for (i=0; i < 8; i++) {
          str1 = "0x" substr(msr_frq, 2*(i)+1, 2);
	  #printf("str1[%d]= %s\n", i, str1);
          frq[i] = strtonum(str1);
	  if (cpu_name == "Broadwell" || cpu_name == "Haswell") {
            lmt[i]=8-i;
	  } else {
            str2 = "0x" substr(msr_xtr, 2*(i)+1, 2);
            lmt[i] = strtonum(str2);
	  }
          if (cps >= lmt[i]) {
            printf("freq[%d]= %.1f, cores %d\n", i, .1*frq[i], lmt[i]);
          }
       }
       exit(0);
     }'
  fi
}

if [ "$ACTION" == "reset" ]; then
  show_MSRs "before reset " 
  if [[ $CPU_NAME == *"Skylake"* ]]; then
    # from pfay1testing1td-phx3, a 1TD Dell C6420
    wrmsr --all 0x1ad 0x1818181818181c1e
  elif [[ $CPU_NAME == *"Cascade Lake Gold Refresh"* ]]; then
    # default from odm-lab
    # which is 
    # CPU family:            6
    # Model:                 85
    # Model name:            Intel(R) Xeon(R) Gold 5218R CPU @ 2.10GHz
    wrmsr --all 0x1ad 0x1d1d1d1f23252628
  elif [[ $CPU_NAME == *"Cascade Lake Refresh"* ]]; then
    # default from odm-lab
    # which is 
    #  CPU family:            6
    #  Model:                 85
    #  Model name:            Intel(R) Xeon(R) Silver 4214R CPU @ 2.40GHz
    wrmsr --all 0x1ad 0x1e1e1e1e1e202123
  elif [[ $CPU_NAME == *"Cascade"* ]]; then
    # default from u154681-phx4
    # which is 
    #  CPU family:            6
    #  Model:                 85
    #  Model name:            Intel(R) Xeon(R) Silver 4214 CPU @ 2.20GHz
    wrmsr --all 0x1ad 0x1b1b1b1b1b1d1e20
  elif [[ $CPU_NAME == *"Ice Lake"* ]]; then
    # default from ice lake config=base
    # which is 
    # CPU family:                      6
    # Model:                           106
    # Model name:                      Intel(R) Xeon(R) Gold 5318Y CPU @ 2.10GHz
    # Stepping:                        6
    wrmsr --all 0x1ad 0x1a1a1a1a1b1e2022
  elif [[ $CPU_NAME == *"Broadwell"* ]]; then
    CKVAL=`rdmsr -0 -p 0 0x1af | awk '{v=substr($0, 1, 2);str="";for(i=1;i<=8;i++){str=str""v;}printf("0x%s", str);}'`
    #if [ "$CKVAL" == "0x1a1a1a1a1a1a1a1a" ]; then
    if [ "$NUM_CPUS" == "40" ]; then
    wrmsr --all 0x1ad 0x1b1c1d1e1f202222
    wrmsr --all 0x1ae 0x1a1a1a1a1a1a1a1a
    wrmsr --all 0x1af 0x1a1a1a1a1a1a1a1a
    else
    wrmsr --all 0x1ad 0x1718191a1b1c1e1e
    wrmsr --all 0x1ae 0x1717171717171717
    wrmsr --all 0x1af 0x1717171717171717
    fi
    wrmsr --all 0x1ac 0x8000000000000000
  fi
  show_MSRs "after  reset " 
fi

if [ "$ACTION" == "allcore" ]; then
  CKVAL=`rdmsr -0 -p 0 0x1ad | awk '{v=substr($0, 1, 2);str="";for(i=1;i<=8;i++){str=str""v;}printf("0x%s", str);}'`
  show_MSRs "before allcore " 
  #CPU_VENDOR= GenuineIntel CPU_MODEL= 85 CPU_FAMILY= 6
  if [[ $CPU_NAME == *"Skylake"* ]]; then
    wrmsr --all 0x1ad $CKVAL
  elif [[ $CPU_NAME == *"Cascade Lake Gold Refresh"* ]]; then
    wrmsr --all 0x1ad $CKVAL
  elif [[ $CPU_NAME == *"Cascade Lake Refresh"* ]]; then
    wrmsr --all 0x1ad $CKVAL
  elif [[ $CPU_NAME == *"Cascade"* ]]; then
    # default from u154681-phx4
    # which is 
    #  CPU family:            6
    #  Model:                 85
    #  Model name:            Intel(R) Xeon(R) Silver 4214 CPU @ 2.20GHz
    wrmsr --all 0x1ad $CKVAL
  elif [[ $CPU_NAME == *"Ice Lake"* ]]; then
    wrmsr --all 0x1ad $CKVAL
  elif [[ $CPU_NAME == *"Broadwell"* ]]; then
    CKVAL=`rdmsr -0 -p 0 0x1af | awk '{v=substr($0, 1, 2);str="";for(i=1;i<=8;i++){str=str""v;}printf("0x%s", str);}'`
    echo "CKVAL for msr 0x1af= $CKVAL"
    wrmsr --all 0x1ad $CKVAL
    wrmsr --all 0x1ae $CKVAL
    wrmsr --all 0x1af $CKVAL
    wrmsr --all 0x1ac 0x8000000000000000
  fi
  show_MSRs "after  allcore" 
fi

if [ "$ACTION" == "show" ]; then
  show_MSRs "show " 
  cat /sys/devices/system/cpu/cpufreq/policy*/scaling_governor | awk '
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

if [ "$ACTION" == "set" ]; then
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

exit
