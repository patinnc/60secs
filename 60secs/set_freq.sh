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

GOV_IN=
FREQ_IN=
DID_GOV=0

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
      echo "Usage: $0 [-h] [ -g performance|powersave|show ] [ -f freq_in_hex|allcore|reset ]"
      echo "   -g performance|powersave|show"
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

# cascade lake 2nd gen stuff from https://www.intel.com/content/www/us/en/products/docs/processors/xeon/2nd-gen-xeon-scalable-spec-update.html
# 2nd gen xeon scalable cpus: cascade lake sku is 82xx, 62xx, 52xx, 42xx 32xx W-32xx  from https://www.intel.com/content/www/us/en/products/docs/processors/xeon/2nd-gen-xeon-scalable-spec-update.html
# skylake 1st gen stuff from https://www.intel.com/content/www/us/en/processors/xeon/scalable/xeon-scalable-spec-update.html
# 1st gen xeon scalable cpus: 81xx, 61xx, 51xx, 81xxT, 61xxT 81xxF, 61xxF, 51xx, 41xx, 31xx, 51xxT 41xxT, 51xx7, 
CPU_NAME=`cat /proc/cpuinfo | awk '
  function decode_fam_mod(vndor, fam, mod, mod_nm) {
    if (vndor == "GenuineIntel") {
      # cpuid tables from https://en.wikichip.org/wiki/intel/cpuid
      dcd[1,1]="Ice Lake";              dcd[1,2] ="Family 6 Model 108";
      dcd[2,1]="Ice Lake";              dcd[2,2] ="Family 6 Model 106";
      dcd[3,1]="Cascade Lake/Skylake";  dcd[3,2] ="Family 6 Model 85"; # 06_55h  Intel always does the hex fam_model
      dcd[4,1]="Broadwell";             dcd[4,2] ="Family 6 Model 79"; # 06_4fh
      dcd[5,1]="Broadwell";             dcd[5,2] ="Family 6 Model 86"; # 06_56h
      dcd[6,1]="Haswell";               dcd[6,2] ="Family 6 Model 63"; # 06_3fh
      dcd[7,1]="Ivy Bridge";            dcd[7,2] ="Family 6 Model 62";
      dcd[8,1]="Sandy Bridge";          dcd[8,2] ="Family 6 Model 45"; # 06_2dh
      dcd[9,1]="Westmere";              dcd[9,2] ="Family 6 Model 44";
      dcd[10,1]="EX";                   dcd[10,2]="Family 6 Model 47";
      dcd[11,1]="Nehalem";              dcd[11,2]="Family 6 Model 46";
      dcd[12,1]="Lynnfield";            dcd[12,2]="Family 6 Model 30";
      dcd[13,1]="Bloomfield, EP, WS";   dcd[13,2]="Family 6 Model 26";
      dcd[14,1]="Penryn";               dcd[14,2]="Family 6 Model 29";
      dcd[15,1]="Harpertown, QC, Wolfdale, Yorkfield";  dcd[15,2]="Family 6 Model 23";
      str = "Family " fam " Model " mod;
      #printf("str= %s\n", str);
      res=" ";
      for(k=1;k <=15;k++) { if (dcd[k,2] == str) {res=dcd[k,1];break;}}
      if (k == 3) {
        # so Cooper Lake/Cascade Lake/SkyLake)
        if (match(mod_nm, / [86543]2[0-9][0-9]R /) > 0) { res="Cascade Lake Refresh";} else
        if (match(mod_nm, / [86543]2[0-9][0-9]/) > 0) { res="Cascade Lake";} else
        if (match(mod_nm, / [86543]1[0-9][0-9]/) > 0) { res="Skylake";}
      }
      return res;
    }
  }
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
if [ "$GOV_IN" != "" ]; then
 if [ "$GOV_IN" != "performance" -a "$GOV_IN" != "powersave" -a "$GOV_IN" != "show" ]; then
  echo "arg -g arg must be performance or powersave or show. got -g $GOV_IN. bye"
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

if [[ $CPU_NAME == *"Cascade"* ]]; then
  MSR_LIST="0x1ad"
else 
  if [[ $CPU_NAME == *"Skylake"* ]]; then
    MSR_LIST="0x1ad"
  else
    if [[ $CPU_NAME == *"Broadwell"* ]]; then
      MSR_LIST="0x1ad 0x1ae 0x1af"
      MSR_SEMA="0x1ac"
    else
      if [[ $CPU_NAME == *"Haswell"* ]]; then
        MSR_LIST="0x1ad 0x1ae 0x1af"
        MSR_SEMA="0x1ac"
        if [ "$ACTION" != "show" ]; then
          echo "only support Broadwell, Skylake and Cascade Lake for ACTION= $ACTION so far. Bye."
          exit
        fi
      else
        echo "only support Broadwell, Skylake and Cascade Lake so far. Bye."
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
  echo "=========== $1 ================="
  for j in $MSR_LIST; do
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
  done
}

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
 if [ "$1" == "performance" -o "$1" == "powersave" ]; then
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

if [ "$ACTION" == "reset" ]; then
  show_MSRs "before reset " 
  if [[ $CPU_NAME == *"Skylake"* ]]; then
    # from pfay1testing1td-phx3, a 1TD Dell C6420
    wrmsr --all 0x1ad 0x1818181818181c1e
  fi
  if [[ $CPU_NAME == *"Cascade Lake Refresh"* ]]; then
    # default from odm-lab
    # which is 
    #  CPU family:            6
    #  Model:                 85
    #  Model name:            Intel(R) Xeon(R) Silver 4214R CPU @ 2.40GHz
    wrmsr --all 0x1ad 0x1e1e1e1e1e202123
  else
  if [[ $CPU_NAME == *"Cascade"* ]]; then
    # default from u154681-phx4
    # which is 
    #  CPU family:            6
    #  Model:                 85
    #  Model name:            Intel(R) Xeon(R) Silver 4214 CPU @ 2.20GHz
    wrmsr --all 0x1ad 0x1b1b1b1b1b1d1e20
  fi
  fi
  if [[ $CPU_NAME == *"Broadwell"* ]]; then
    wrmsr --all 0x1ad 0x1718191a1b1c1e1e
    wrmsr --all 0x1ae 0x1717171717171717
    wrmsr --all 0x1af 0x1717171717171717
    wrmsr --all 0x1ac 0x8000000000000000
  fi
  show_MSRs "after  reset " 
fi

if [ "$ACTION" == "allcore" ]; then
  show_MSRs "before allcore " 
  if [[ $CPU_NAME == *"Skylake"* ]]; then
    wrmsr --all 0x1ad 0x1818181818181818
  fi
  if [[ $CPU_NAME == *"Cascade Lake Refresh"* ]]; then
    wrmsr --all 0x1ad 0x1e1e1e1e1e1e1e1e
  else
  if [[ $CPU_NAME == *"Cascade"* ]]; then
    # default from u154681-phx4
    # which is 
    #  CPU family:            6
    #  Model:                 85
    #  Model name:            Intel(R) Xeon(R) Silver 4214 CPU @ 2.20GHz
    wrmsr --all 0x1ad 0x1b1b1b1b1b1b1b1b
  fi
  fi
  if [[ $CPU_NAME == *"Broadwell"* ]]; then
    wrmsr --all 0x1ad 0x1717171717171717
    wrmsr --all 0x1ae 0x1717171717171717
    wrmsr --all 0x1af 0x1717171717171717
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
