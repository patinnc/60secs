#!/bin/bash

PROJ_DIR=/root/output
SCR_DIR=`dirname $(readlink -e $0)`
# don't need cfg_dir but it might get passed
CFG_DIR=
RUN_TM=1
PREFIX_DIR=0

while getopts "hPlc:p:" opt; do
  case ${opt} in
    c )
      CFG_DIR=$OPTARG
      ;;
    l )
      RUN_TM=10
      ;;
    p )
      PROJ_DIR=$OPTARG
      ;;
    P )
      PREFIX_DIR=1
      ;;
    h )
      echo "$0 run compute and disk benchmarks using config files in cfg_dir and put results in results dir"
      echo "Usage: $0 [-h] [ -p project_dir]"
      echo "   -p project_dir"
      echo "     by default the host results dir name $PROJ_DIR"
      echo "     If you specify a project dir the benchmark results are looked for"
      echo "     under /project_dir/"
      echo "   -l run spin.x for 10 seconds instead of 1 sec. 3 different runs are done of spin.x so this can take all cpus for 30 seconds"
      echo "      the default is 1 second/run"
      echo "   -P prefix subdir name 'sysinfo' with timestamp YY-MM-DD_HHMMSS_. Default is don't prefix it"
      exit
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

mkdir -p $PROJ_DIR
PROJ_DIR=`realpath -e $PROJ_DIR`

timestamp=$(date '+%y-%m-%d_%H%M%S')
extra_dir=sysinfo
if [ "$PREFIX_DIR" == "1" ]; then
  extra_dir=${timestamp}_${extra_dir}
fi
result="$PROJ_DIR/${extra_dir}"
mkdir -p $result

pushd $result
OUT_FILE=sysinfo.txt

cmds=("hostname" "uname -a" "lsb_release -a" "cat /etc/os-release" "lscpu" "who -r" "cat /proc/meminfo" "numactl --hardware" "df -h ." "dmidecode" "lshw" "lstopo --of txt --whole-io" "lstopo --no-io" "lsblk" "fdisk -l" "lspci -vv" "lspci -t" "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver" "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" "java -version" "which java" "gcc --version" "rdmsr 0x1ad" "cpuid" "lsblk -P -o NAME,SIZE,MODEL")

date > $OUT_FILE
for cmd in "${cmds[@]}"; do
  echo "====start ${cmd}=====" >> $OUT_FILE
  $cmd >> $OUT_FILE 2>&1
  echo "====end ${cmd}========" >> $OUT_FILE
done

lstopo --whole-io -v lstopo.png
hwinfo > hwinfo.txt
lsblk -P -o "NAME,SIZE,MODEL" > lsblk_sz_model.txt

SPIN_BIN=$SCR_DIR/extras/spin.x
$SPIN_BIN -t 10 -w freq > spin_freq.txt
$SPIN_BIN -t 10 -w mem_bw -s 100m -b 64 > spin_bw.txt
$SPIN_BIN -t 10 -w mem_bw_remote -s 100m -b 64 > spin_bw_remote.txt

echo "finished sysinfo"
popd

exit

