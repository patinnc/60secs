#!/bin/bash

PROJ_DIR=/root/output
SCR_DIR=`dirname $(readlink -e $0)`
# don't need cfg_dir but it might get passed
CFG_DIR=
RUN_TM=1
PREFIX_DIR=0
QUIT=0

while getopts "hPlqc:p:" opt; do
  case ${opt} in
    c )
      CFG_DIR=$OPTARG
      ;;
    l )
      RUN_TM=$OPTARG
      ;;
    p )
      PROJ_DIR=$OPTARG
      ;;
    P )
      PREFIX_DIR=1
      ;;
    q )
      QUIT=1
      ;;
    h )
      echo "$0 run compute and disk benchmarks using config files in cfg_dir and put results in results dir"
      echo "Usage: $0 [-h] [ -p project_dir]"
      echo "   -p project_dir"
      echo "     by default the host results dir name $PROJ_DIR"
      echo "     If you specify a project dir the benchmark results are looked for"
      echo "     under /project_dir/"
      echo "   -l spin.x_run_time_in_secs  spin.x uses all cpus. Default is 1 sec. spin.x does 3 different runs so -l 10 secs can take all cpus for 30 seconds"
      echo "      the default is 1 second/run. -l 0 skips spin.x which is recommended for production boxes"
      echo "   -P prefix subdir name 'sysinfo' with timestamp YY-MM-DD_HHMMSS_. Default is don't prefix it"
      exit
      ;;
    : )
      echo "$0.$LINENO Invalid option: $OPTARG requires an argument" 1>&2
      ;;
    \? )
      echo "$0.$LINENO Invalid option: $OPTARG" 1>&2
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

cmds=("hostname" "uname -a" "lsb_release -a" "cat /etc/os-release" "lscpu" "who -r" "cat /proc/meminfo" "numactl --hardware" "df -h ." "dmidecode" "lshw" "lstopo --of txt --whole-io" "lstopo --no-io" "lsblk" "fdisk -l" "lspci -vv" "lspci -t" "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_driver" "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor" "java -version" "which java" "gcc --version" "rdmsr 0x1ad" "cpuid" "lsblk -P -o NAME,SIZE,MODEL")

TS=`date +%s.%N`
echo "beg sysinfo $TS" >> phase.txt

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
if [ "$RUN_TM" != "" ]; then
if [ $RUN_TM -gt 0 ]; then
  $SPIN_BIN -t $RUN_TM -w freq_sml > spin_freq.txt
  $SPIN_BIN -t $RUN_TM -w mem_bw -s 100m -b 64 > spin_bw.txt
fi
fi
lscpu > lscpu.txt
lscpu -e > lscpu_e.txt

numactl -H > numactl_H.txt
NDS=`awk '/^available: .* nodes /{printf("%s\n", $2);exit;}' numactl_H.txt`
CpusPerNode=`awk '/^node 0 cpus: /{printf("%s\n", NF-3);exit;}' numactl_H.txt`
OFILE=spin_bw_remote.txt
echo "numa_nodes= $NDS" > $OFILE
echo "cpus/node= $CpusPerNode" >> $OFILE

if [[ $RUN_TM -gt 0 ]]; then
echo "spin numa memory bandwidth matrix GB/s"  >> $OFILE
printf "Numa node\t" >> $OFILE
for ((i=0; i < $NDS; i++)); do
  printf "%d\t" $i >> $OFILE
done
printf "\n" >> $OFILE
#work= mem_bw, threads= 4, total perf= 12.025 GB/sec
for ((i=0; i < $NDS; i++)); do
  printf "%d\t" $i  >> $OFILE
  for ((j=0; j < $NDS; j++)); do
     RESP=`numactl -N $i -m $j $SPIN_BIN -w mem_bw -t 1 -s 100m -b 64 -P -n $CpusPerNode 2> /dev/null`
     PERF=`echo "$RESP" | grep "total perf=" | awk '{printf("%s\n", $7);}'`
     printf "%s\t" $PERF  >> $OFILE
  done
  printf "\n"  >> $OFILE
done
fi



BIOS_BIN=$SCR_DIR/extras/SCELNX_64_v5.03.1127
if [ -e $BIOS_BIN ]; then
  $BIOS_BIN /o /s nvram.out
fi

TS=`date +%s.%N`
echo "end sysinfo $TS" >> phase.txt
popd

if [ "$QUIT" == "1" ]; then
  $SCR_DIR/quit_monitoring.sh 
fi

exit 0

