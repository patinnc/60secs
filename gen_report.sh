#!/usr/bin/env bash

# expecte to be run from /root folder
# gets the results from the  most recent runs of specint, specjbb, stream, geekbench, fio, vdbench, sysinfo

export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_ALL=C


SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
AWK_BIN=awk
if [ -e $SCR_DIR/bin/gawk ]; then
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  AWK_BIN=$SCR_DIR/bin/gawk
fi
fi
if [[ "$OSTYPE" == "darwin"* ]]; then
   # Mac OSX
   AWK_BIN=gawk
fi
echo "$0.$LINENO awk_bin= $AWK_BIN" > /dev/stderr


PROJ_DIR=/root/output
VERBOSE=0
SKU="n/a"
SKU_MAKE="n/a"
SKU_MODEL="n/a"
got_fio=0
fio_key="fio_4K_randomread\tfio_1M_seq_read\tfio_4K_randomwrite\tfio_1M_seq_write"
fio_val="\t\t\t"
fiodisk_key=
fiodisk_val=
ALL_DIRS=1
CMB_FILE=
HOST=
NUM_HOST=
HOST_ARR_I=-1
IFS_SV=$IFS
#declare -A gb_arr
#declare -A cm_arr
declare -A HOST_ARR
#HOST_ARR=()
gb_arr1=()
gb_arr2=()
gb_arr3=()
cm_arr=()
cm_lines=-1
#SCR_DIR=`dirname "$(readlink -f "$0")"`
SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BM_LIST="specint specjbb coremark stream vdbench geekbench sysinfo fio"
echo "$0: +++++cmdline= ${@}"
export AWKPATH=$SCR_DIR

while getopts "hvaH:m:N:p:r:s:t:z:" opt; do
  case ${opt} in
    a )
      ALL_DIRS=1
      ;;
    H )
      HOST=$OPTARG
      ;;
    m )
      SKU_MAKE=$OPTARG
      ;;
    N )
      NUM_HOST=$OPTARG
      ;;
    p )
      PROJ_DIR=$OPTARG
      ;;
    s )
      SKU=$OPTARG
      ;;
    t )
      SKU_MODEL=$OPTARG
      ;;
    z )
      CMB_FILE=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 get results on a host in /root/output/* or (if -p proj_dir) /proj_dir/"
      echo "Usage: $0 [-h] [ -p proj_dir] [-v]"
      echo "   -p project_dir"
      echo "     by default the host results dir name /root/output"
      echo "     If you specify a project dir the benchmark results are looked for"
      echo "     under /project_dir/"
      echo "   -s sku for host (from clusto info host 'Sku:' field)"
      echo "   -m sku make (like 'Dell') for host (from clusto info host 'Make:' field)"
      echo "   -t sku model (like 'R630') for host (from clusto info host 'Model:' field)"
      echo "   -v verbose mode"
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

ORIG_DIR=`pwd`
echo "$0.$LINENO ORIG_DIR= $ORIG_DIR" > /dev/stderr
echo "$0.$LINENO PROJ_DIR= $PROJ_DIR" > /dev/stderr


pushd $PROJ_DIR
LIST=(*)
LIST=`ls -1`
dirs=()
for f in $LIST; do
 echo $f
 dirs+=( "$f" )
done

DEF_BM=
got_any_bm=0
d="$PROJ_DIR"
for get_bm in $BM_LIST; do
   #if [ $VERBOSE -gt 0 ]; then
   #  echo "ck bm= $get_bm in dir $d" > /dev/stderr
   #fi
   RC=`awk -v bm="$get_bm" -v path="$d" 'BEGIN{if (index(path, bm) > 0) { rc=1; } else { rc=0; };printf("%d\n", rc);exit}'`
   if [ "$RC" == "1" ]; then
     if [ $VERBOSE -gt 0 ]; then
       echo "got bm= $get_bm in dir $d" > /dev/stderr
     fi
     let got_any_bm=($got_any_bm+1)
     DEF_BM=$get_bm
     #break
   fi
done
echo "___default bm= $DEF_BM, found $got_any_bm benchmark names, from proj_dir= $d" > /dev/stderr

if [ "$got_any_bm" == "0" ]; then
  dirs=()
  for i in $BM_LIST; do
    FND=`find . -type d -name "??-??-??_*${i}" | sort`
    if [ "$FND" != "" ]; then
    echo "FND_dir=$FND" > /dev/stderr
    dirs+=($FND)
    fi
    FND=`find . -type d -name "${i}" | sort`
    if [ "$FND" != "" ]; then
    echo "FND_dir=$FND" > /dev/stderr
    dirs+=($FND)
    fi
  done
  echo "dirs= ${dirs[@]}" > /dev/stderr
fi

echo "$0.$LINENO DIRS= ${dirs[@]}" > /dev/stderr
for ((i=0; i<${#dirs[@]}; i++)); do
#20-03-31_182513_sysinfo
  d=${dirs[$i]}
  bm=${d##*_}
  v=`basename ${dirs[$i]}`
  # above assumes a certain naming convention for results directories
  got_it=0
  for get_bm in $BM_LIST; do
     if [ "$get_bm" == "$v" ]; then
       echo "$0.$LINENO got bm $get_bm in path ${dirs[$i]}" > /dev/stderr
       bm=$get_bm
       got_it=1
       break
     fi
     if [ "$get_bm" == "$bm" ]; then
       echo "$0.$LINENO got bm $get_bm in path ${dirs[$i]}" > /dev/stderr
       got_it=1
       break
     fi
  done
  if [ $got_it -eq 0 ]; then
    bm=
  fi
  for get_bm in $BM_LIST; do
   if [ $VERBOSE -gt 0 ]; then
     echo "ck bm= $get_bm in dir $d, def_bm= $DEF_BM"
   fi
   RC=`awk -v bm="$get_bm" -v path="$d" 'BEGIN{if (index(path, bm) > 0) { rc=1; } else { rc=0; };printf("%d\n", rc);exit}'`
   if [ "$RC" == "1" ]; then
     if [ $VERBOSE -gt 0 ]; then
       echo "$0.$LINENO got bm= $get_bm in dir $d" > /dev/stderr
     fi
     if [ "$bm" == "" ]; then
       bm=$get_bm
     fi
     break
   fi
  done
  if [ "$bm" == "" -a "$DEF_BM" != "" ]; then
    bm=$DEF_BM
    if [ $VERBOSE -gt 0 ]; then
      echo "$0.$LINENO use def_bm2= $DEF_BM ================" > /dev/stderr
    fi
  fi
  EPOCH=`echo $d | awk -v bm="$bm" '
    /20-/{
      yy="20" substr($0, 1, 2);
      mn=substr($0, 4, 2);
      dd=substr($0, 7, 2);
      hh=substr($0, 10, 2);
      mm=substr($0, 12, 2);
      ss=substr($0, 14, 2);
      dt_str = yy " " mn " " dd " " hh " " hh " " ss;
      #printf("inp= %s dt_str= %s\n", $0, dt_str) > "/dev/stderr";
      epoch = mktime(dt_str);
      #printf("epoch= %s offset= %s\n", epoch, offset) > "/dev/stderr";
      printf("%s\n", epoch);
     }'`
  TS[$i]=$EPOCH
  BM[$i]=$bm
  if [ $i -gt 0 ]; then
    j=$((i-1))
    TSE[$j]=$((EPOCH-1))
  fi
done
if [ "$CMB_FILE" != "" ]; then
  PH_FILE=$ORIG_DIR/$CMB_FILE.phase.$HOST
  if [ -e $PH_FILE ]; then
    rm $PH_FILE
  fi
  echo "PH_FILE= $PH_FILE" > /dev/stderr
for ((i=0; i<${#dirs[@]}; i++)); do
  #echo "dir[$i]= ${dirs[$i]} ${BM[$i]} ${TS[$i]} ${TSE[$i]}" >> /dev/stderr
  tfl="${dirs[$i]}/phase.txt"
  echo "$tfl " > /dev/stderr
  if [ -e $tfl ]; then
    RESP=`awk '{if (NR == 1){bm= $2; tb= $3;} else { printf("%s %s %s\n", bm, tb, $3);exit}}' $tfl`
    echo "$RESP" >> $PH_FILE
    echo "got RESP= $RESP" > /dev/stderr
  else
    echo "${BM[$i]} ${TS[$i]} ${TSE[$i]}" >> $PH_FILE
  fi
done
fi

#declare -A did_bmarks
did_bmarks=()
echo "dirs_i= ${#dirs[@]}"
for ((dirs_i=${#dirs[@]}-1; dirs_i>=0; dirs_i--)); do
  echo -e "now get bm perf in dirs i= $dirs_i ${dirs[$dirs_i]}" > /dev/stderr
  #if [ $VERBOSE -gt 0 ]; then
  #  echo -e "i= $dirs_i ${dirs[$dirs_i]}" > /dev/stderr
  #fi
  d=${dirs[$dirs_i]}
  bm=${d##*_}
  lbm=`basename $d`
  got_it=0
  for get_bm in $BM_LIST; do
     if [ "$get_bm" == "$lbm" ]; then
       echo "$0.$LINENO got bm $get_bm in dir $d"
       bm=$get_bm
       got_it=1
       break
     fi
     if [ "$get_bm" == "$bm" ]; then
       got_it=1
       break
     fi
  done
  if [ $got_it -eq 0 ]; then
    bm=
  fi
  for get_bm in $BM_LIST; do
   if [ $VERBOSE -gt 0 ]; then
     echo "$0.$LINENO ck bm= $get_bm in dir $d" > /dev/stderr
   fi
   RC=`awk -v bm="$get_bm" -v path="$d" 'BEGIN{if (index(path, bm) > 0) { rc=1; } else { rc=0; };printf("%d\n", rc);exit}'`
   if [ "$RC" == "1" ]; then
     if [ $VERBOSE -gt 0 ]; then
       echo "$0.$LINENO got bm= $get_bm in dir $d" > /dev/stderr
     fi
     #bm=$get_bm
     break
   fi
  done
  echo "ck  def_bm3= $bm, def_bm= $DEF_BM ================"
  if [ "$bm" == "" -a "$DEF_BM" != "" ]; then
    bm=$DEF_BM
    if [ $VERBOSE -gt 0 ]; then
      echo "$0.$LINENO use def_bm3= $DEF_BM ================" > /dev/stderr
    fi
  fi
  if [ $VERBOSE -gt 0 ]; then
    echo -e "$0.$LINENO bmark4= $bm dir= $d" > /dev/stderr
  fi
  valid=0
  arg1=""
  arg2=""
  if [ "$bm" == "specint" ]; then
    file1=$d/result/CPU2017.001.log
    file2=$d/result/CPU2017.001.intrate.refrate.txt
    lkfor="Est. SPECrate2017_int_base"
    if [ ! -e $file2 ]; then
      file2=$d/result/CPU2017.001.intrate.txt
      lkfor="SPECrate2017_int_base"
    fi
    if [ -e $file1 -a -e $file2 ]; then
      arg1=`grep ' --copies ' $file1 | head -1 | sed 's/.*--copies //;' | awk '{print $1}'`
      if [ "$arg1" == "" ]; then
        arg1=`grep 'copies.*=' $file1 | head -1 | sed 's/.*=//;s/ //g'`
      fi
      arg2=`grep "$lkfor" $file2 | sed 's/.*int_base//; s/ //g'`
          #/ Success 557.xz_r base refrate ratio=136.27, runtime=507.220031, copies=64, threads=1, power=0.00W, temp=0.00 degC, humidity=0.00%
          #/ Success 557.xz_r base refrate ratio=/ {

      arg3=`awk '/ Success 557.xz_r base refrate ratio=/{gsub(",","",$0);for(i=5;i<NF;i++){n=split($i,arr,"=");if (arr[1]=="copies"){printf("%s\n", arr[2]);exit;}}}' $file2`
      if [ "$arg3" != "" -a "$arg1" != "" ]; then
        echo "$0.$LINENO arg3= $arg3 arg1= $arg1" > /dev/stderr
        if [ $arg3 -gt $arg1 ]; then
          arg1=$arg3
        fi
      fi
      #echo " got specint files, arg1= $arg1 arg2= $arg2"
      if [ "$arg1" != "" -a "$arg2" != "" ]; then
         valid=1
         echo "=== specint_rate === $d"
         key="++\tspecint_rate\tspecint_threads"
         val="++\t$arg2\t$arg1"
         if [ "$specint_key" == "" ]; then
           specint_key=$key
           specint_val=$val;
         fi
         echo -e "$key"
         echo -e "$val"
         echo "$0.$LINENO specint val= $specint_val vals= $val  $d" > /dev/stderr
      fi
    fi
  fi
  if [ "$bm" == "sysinfo" ]; then
    pushd $d
    file1=sysinfo.txt
    file2=spin_freq.txt
    file3=spin_bw.txt
    file4=spin_bw_remote.txt
    if [ ! -e $file2 ]; then
       file2=
    fi
    if [ ! -e $file3 ]; then
       file3=
    fi
    if [ ! -e $file4 ]; then
       file4=
    fi
    if [ ! -e $file2 ]; then
       file2=
    fi
    if [ -e $file1 ]; then
      barg=`$AWK_BIN -v scr_dir="$SCR_DIR" -v host_in="$HOST" '
            BEGIN{i=0;dsks=0;got_os=0;disk_keys=0;disk_val="";}
                 function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
                 function rtrim(s) { sub(/[ \t\r\n,]+$/, "", s); return s }
                 function trim(s) { return rtrim(ltrim(s)); }
                 function get_cache_sizes(str) {
                     mbytes = 0.0;
                     if (index(str, " L3 ") > 0 || index(str, " L2 ") > 0 || index(str, " L1i ") > 0 || index(str, " L1d ") > 0) {
                       for(k = 1; k <= NF; k++) { 
                         if ( $k == "L3" || $k == "L2" || $k == "L1i" || $k == "L1d" ) {
                           j = k+2;
                           sz = substr($j, 2, length($j)-2);
                           unit= substr(sz, length(sz)-1, 2);
                           sz  = substr(sz, 1, length(sz)-2);
                           if ($VERBOSE > 0) { printf("typ= %s sz= %s unit= %s str= %s\n", $k, sz, unit, str); }
                           if (unit == "KB") { sz /= 1024.0; }
                           if (unit == "MB") { sz *= 1.0; }
                           if (unit == "GB") { sz *= 1024.0; }
                           mbytes += sz;
                           if ($VERBOSE > 0) { printf("MBs= %.3f str= %s\n", mbytes, str);}
                         }
                       }
                     }
                     return mbytes;
                 }
                #work= freq_sml, threads= 96, total perf= 293.273 Gops/sec
                /^work= freq.*, threads=/ { 
                   if (FILENAME == "spin_freq.txt") { thrds= rtrim($4);cycles=$7/thrds;cycles=sprintf("%.3f",cycles);totcyc=sprintf("%.3f",$7);;
                     i++;key[i]="cycles/cpu";val[i]=cycles;
                     i++;key[i]="tot_cycles";val[i]=totcyc;
                   }
                }
                /^work= mem_bw_remote, threads=/ { 
                   if (FILENAME == "spin_bw_remote.txt") {
                     # old format
                     thrds= rtrim($4);bw_rem=$7;bw_rem=sprintf("%.3f",bw_rem);
                     i++;key[i]="spin_bw_remote";val[i]=bw_rem;
                   }
                }
#numa_nodes= 2
#cpus/node= 48
#spin numa memory bandwidth matrix GB/s
#Numa node       0       1
#0       86.593  79.660
#1       81.503  84.481
                /^numa_nodes= / { 
                   if (FILENAME == "spin_bw_remote.txt") {
                     # new format
                     numa_nodes_rmt = $2;
                     numa_nodes_beg = 0;
                     while(getline > 0) {
                        #printf("got spin bw remote line= %s\n", $0) > "/dev/stderr";
                        if ($1 == "Numa" && $2 == "node") { numa_nodes_beg = 1; continue; }
                        if ( numa_nodes_beg == 1 ) {
                           n = split($0, arr, "\t");
                           rmt_rw = arr[1]+1;
                           if (arr[n] == "" ) { n--;} # there can be a trailing tab char
                           # use < n since there is a trailing tab char
                           for (rmt_i=2; rmt_i <= n; rmt_i++) {
                              rmt_col=rmt_i -1;
                              v = arr[rmt_i]+0.0;
                              if (rmt_min == "") {
                                rmt_min = v;
                                #printf("got spin bw remote initial v= %f\n", v) > "/dev/stderr";
                              }
                              if (rmt_col != rmt_rw && rmt_min > v) {
                                rmt_min = v;
                                #printf("got spin bw remote new     v= %f\n", v) > "/dev/stderr";
                              }
                           }
                           if (rmt_rw == numa_nodes_rmt) {break;}
                        }
                     }
                     if (rmt_min == "") { bw_rem=0.0; } else { bw_rem = rmt_min; }
                     i++;key[i]="spin_bw_remote";val[i]=bw_rem;
                   }
                }
                /^work= mem_bw, threads=/ { 
                   if (FILENAME == "spin_bw.txt") {
                     thrds= rtrim($4);bw=$7;bw=sprintf("%.3f",bw);
                     i++;key[i]="spin_bw_local";val[i]=bw;
                   }
                }
                { 
                   if (FILENAME == "spin_freq.txt" || FILENAME == "spin_bw.txt" || FILENAME == "spin_bw_remote.txt") { next; }
                }

                /====start cat .*scaling_governor=====/ {
                  getline;
                  ++i;
printf("============== %s\n", $0) > "/dev/stderr";
                  key[i]="governor";
                  val[i]=$1;
                  next;
                }
                /====start uname -a/ {
                  getline;
                  ++i;
                  key[i]="host";
                  hst=$2;
                  if (host_in != "" && host_in != hst) { hst = hst " " host_in;}
                  val[i]=hst;
                  ++i;
                  key[i]="kernel";
                  val[i]=$3;
                  next;
                }
                /====start numactl --hardware/ {
                  getline;
                  ++i;
                  key[i]="numa nodes";
                  val[i]=$2;
                  next;
                }
                /====start cat \/proc\/meminfo/ {
                  getline;
                  ++i;
                  key[i]="MemTotal";
                  mem  = $2;
                  unit = $3;
                  if (unit == "kB") { mem = mem/(1024.0*1024.0); unit = "GB"};
                  if (unit == "mB") { mem = mem/(1024.0); unit = "GB"};
                  mem = sprintf("%.3f", mem);
                  val[i]=mem " " unit;
                  next;
                }
                /====start lsb_release/ {
                  while(1) {
                    rc=getline; if (rc==0 || substr($0, 1, 4) == "====") {break;}
                    if ($1=="Description:") {$1=""; i++;key[i]="OS"; val[i]=$0;got_os=1;break;}
                  }
                  next;
                }
                /====start cat \/etc\/os-release/ {
                  if (got_os == 1) { next; }
                  while(1) {
                    rc=getline; if (rc==0 || substr($0, 1, 4) == "====") {break;}
                    n=split($0, arr, "=");
                    if (arr[1]=="PRETTY_NAME") {i++;key[i]="OS"; got_os=1; val[i]=arr[2];break;}
                  }
                  next;
                }
                /====start lscpu/{
                  while(1) {
                    rc=getline; if (rc==0 || substr($0, 1, 4) == "====") {break;}
                    n=split($0, arr, ":"); 
                    arr[2]=trim(arr[2]);
                    #printf("1=_%s_, a1=_%s_\n", $1, arr[1]);
#Thread(s) per core:    2
#Core(s) per socket:    16
#Socket(s):             1
#NUMA node(s):          1
#Vendor ID:             GenuineIntel
#CPU family:            6
#Model:                 85
#Model name:            Intel(R) Xeon(R) Platinum 8175M CPU @ 2.50GHz 
#Stepping:              4
#CPU MHz:               2500.000 
#BogoMIPS:              5000.00
#Hypervisor vendor:     KVM
#Virtualization type:   full
#L1d cache:             32K
#L1i cache:             32K
#L2 cache:              1024K
#L3 cache:              33792K
#NUMA node0 CPU(s):     0-31
                    if ($1=="CPU(s):") {i++;key[i]="num_cpus"; val[i]=$2;continue;}
                    if (arr[1]=="Thread(s) per core") {i++;key[i]="thr/core"; val[i]=arr[2];continue;}
                    if (arr[1]=="Core(s) per socket") {i++;key[i]="cores/skt"; val[i]=arr[2];continue;}
                    if (arr[1]=="Socket(s)")  {i++;key[i]="skts"; val[i]=arr[2];continue;}
                    if (arr[1]=="CPU family") {cpu_fam=arr[2];i++;key[i]="cpu family"; val[i]=arr[2];continue;}
                    if (arr[1]=="Architecture") {cpu_arch=arr[2];}
                    if (arr[1]=="Vendor ID") {cpu_vnd=arr[2];continue;}
                    if (arr[1]=="Model") {
                              cpu_mod=arr[2];
                              i++;key[i]="model"; val[i]=arr[2];
                              continue;}
                    if (arr[1]=="Model name") {
                              cpu_model_name = arr[2];
                              i++;key[i]="model name"; val[i]=arr[2];
                              cmd_decode = scr_dir "/decode_cpu_fam_mod.sh -f " cpu_fam " -m " cpu_mod " -n \""cpu_model_name "\" -v GenuineIntel -V 0" ;
                              cmd_decode | getline cpu_codename;
                              close(cmd_decode);
                              res = cpu_codename;
                              #res=decode_fam_mod(cpu_vnd, cpu_fam, cpu_mod, cpu_model_name);
                              ++i;key[i]="cpu_decoder"; val[i]=res;
                              continue;}
                    if (arr[1]=="CPU MHz")    {i++;key[i]="CPU MHz"; val[i]=arr[2];continue;}
                    if (arr[1]=="BogoMIPS")   {i++;key[i]="BogoMIPS"; val[i]=arr[2];continue;}
                    if (arr[1]=="Hypervisor vendor") {i++;key[i]="Hypervisor vendor"; val[i]=arr[2];continue;}
                    if (arr[1]=="Virtualization type") {i++;key[i]="Virt. Typ"; val[i]=arr[2];continue;}
                    if (arr[1]=="L1d cache") {i++;key[i]=arr[1]; val[i]=arr[2];continue;}
                    if (arr[1]=="L1i cache") {i++;key[i]=arr[1]; val[i]=arr[2];continue;}
                    if (arr[1]=="L2 cache")  {i++;key[i]=arr[1]; val[i]=arr[2];continue;}
                    if (arr[1]=="L3 cache")  {i++;key[i]=arr[1]; val[i]=arr[2];continue;}
                  }
                  next;
                }
#====start lstopo --no-io=
#Machine (480GB total)
#  NUMANode L#0 (P#0 240GB) + Socket L#0 + L3 L#0 (45MB)
#    L2 L#0 (256KB) + L1d L#0 (32KB) + L1i L#0 (32KB) + Core L#0
#      PU L#0 (P#0)
#      PU L#1 (P#32)
#    L2 L#1 (256KB) + L1d L#1 (32KB) + L1i L#1 (32KB) + Core L#1
#      PU L#2 (P#1)
#      PU L#3 (P#33)
#====start lstopo --no-io=====
#Machine (124GB) + Socket L#0 + L3 L#0 (33MB)
#  L2 L#0 (1024KB) + L1d L#0 (32KB) + L1i L#0 (32KB) + Core L#0
#    PU L#0 (P#0)
#    PU L#1 (P#8)
#  L2 L#1 (1024KB) + L1d L#1 (32KB) + L1i L#1 (32KB) + Core L#1
#    PU L#2 (P#1)
#    PU L#3 (P#9)
#Machine (250GB total) + Socket L#0
#  NUMANode L#0 (P#0 125GB)
#    L3 L#0 (8192KB)
#      L2 L#0 (512KB) + L1d L#0 (32KB) + L1i L#0 (64KB)
#        Core L#0 + PU L#0 (P#0)
#        Core L#1 + PU L#1 (P#16)
#      L2 L#1 (512KB) + L1d L#1 (32KB) + L1i L#1 (64KB)
#        Core L#2 + PU L#2 (P#1)
#        Core L#3 + PU L#3 (P#17)

                /====start lstopo --no-io=/{
                  tot_cache=0;
                  while(1) {
                    rc=getline; if (rc==0 || substr($0, 1, 4) == "====") {printf("tot_cache MBs= %.3f\n", tot_cache);++i;key[i]="total_cache MBs";val[i]=tot_cache;break;}
                    tot_cache += get_cache_sizes($0); 
                    continue;
                  }
                  next;
                }
                /====start dmidecode/ {
                  while(1) {
                    rc=getline; if (rc==0 || substr($0, 1, 4) == "====") {break;}
                    n=split($0, arr, /[ \t]/); 
                    if ($0=="BIOS Information") {area="bios";continue;}
                    if (area == "bios" && arr[2] == "Vendor:") {$1="";str=$0;continue;}
                    if (area == "bios" && arr[2] == "Version:") {$1="";str = str " " $0;continue;}
                    if (area == "bios" && arr[2] == "Release") {$1=$2="";str = str " " $0;++i;key[i]="bios";val[i]=str;area="";continue;}
                    if ($0=="System Information") { area="sys";continue;}
                    if (area == "sys" && arr[2] == "Manufacturer:") {$1="";str=$0;continue;}
                    if (area == "sys" && arr[2] == "Product") {$1=$2="";str = str " " $0;++i;key[i]="system";val[i]=str;area="";break;}
                  }
                  next;
                }
#              *-disk:1
#                   description: ATA Disk
#                   product: MTFDDAK1T9TDD
#                   physical id: 0.1.0
#                   bus info: scsi@0:0.1.0
#                   logical name: /dev/sdb
#                   version: U004
#                   serial: 18351F1367F6
#                   size: 1788GiB (1920GB)
#                   capacity: 1788GiB (1920GB)
#                   configuration: ansiversion=6 logicalsectorsize=512 sectorsize=4096
                /====start lshw==/{
                        printf("got lshw= %s\n", $0);
                  while(1) {
                    rc=getline; if (rc==0 || substr($0, 1, 4) == "====") {break;}
                    pos=index($0, "*-disk");
                    #printf("got lshw: pos= %d %s\n", pos, $0);
                    if (pos > 1) { # start of a disk section
                        printf("got disk= %s\n", $0);
                        dck_str[1]="product: ";
                        dck_str[2]="logical name: ";
                        dck_str[3]="size: ";
                        if (disk_keys > 0) { dcomma=", ";}
                        disk_keys++;
                        disk_str=dcomma "{";
                        while(1) {
                         rc=getline; if (rc==0 || substr($0, 1, 4) == "====") {disk_str=disk_str"}";disk_val=disk_val""disk_str;break;}
                         match($0, /^ */); # find leading spaces
                         #printf("There are %d spaces leading up to %s\n", RLENGTH, substr($0,RLENGTH+1)) 
                         if (RLENGTH > pos) { # this is the details of the above disk
                           $0=substr($0, RLENGTH+1); #drop leading spaces
                           #printf("nstr= %s, disk_str= %s\n", $0, disk_str);
                           for (kk=1; kk <= 3; kk++) {
                             if (index($0, dck_str[kk]) == 1) {
                                disk_str=disk_str " " substr($0, length(dck_str[kk])+1);
                                if (kk==3) { disk_str = disk_str ", ";}
                                #printf("disk_str[%d]= %s\n", kk, disk_str);
                                break;
                             }
                           }
                         } else {
                           printf("disk_str end = %s, cur_line= %s\n", disk_str, $0);
                           disk_str = (disk_str "}");
                           printf("disk_str end = %s, cur_line= %s\n", disk_str, $0);
                           disk_val = disk_val "" disk_str;
                           printf("disk_val= %s\n", disk_val);
                           # check if the current line is for a new disk
                           pos=index($0, "*-disk");
                           if (pos > 1) {
                            printf("new disk area\n");
                            disk_keys++;
                            disk_str=dcomma "{";
                           } else {
                            # not a new disk record
                            printf("not disk area\n");
                            break;
                           }
                         }
                        }
                    }
                    n=split($0, arr, " "); 
                    #printf("1=_%s_, 2=_%s_\n", arr[1], arr[2]);
                    #if (arr[1]=="*-cpu") {getline; $1="";str=$0;++i;key[i]="cpu";val[i]=str;area="";break;}
                  }
                  next;
                }
                /====start lsblk -P -o NAME,SIZE,MODEL=/{

                  printf("got lsblk -P -o NAME,SIZE,MODEL\n")
                  lsdsk_str="";
                  lsdsk_val="";
                  while(1) {
                    #rc=getline; if (rc==0 || substr($0, 1, 4) == "====") {printf("lsdsk_str= %s\n", lsdsk_str);break;}
                    rc=getline; if (rc==0 || substr($0, 1, 4) == "====") {printf("lsdsk_str= %s\n", lsdsk_str); ++i;key[i]="lsblk_disks";val[i]=lsdsk_str;break;}
                    #n=split($0, arr, /[ \"]+/); 
                    n=split($0, arr, /[ "]+/); 
                    #for (ni=1; ni <= n; ni++) {printf("fld[%d]= %s\n", ni, arr[ni])};
                    if (n >= 7) {
                      lsdsks++;
                      nm=arr[2];
                      sz=arr[4];
                      model=arr[6];
                      if (n >= 8) {
                         model = model " " arr[7];
                      }
                      printf("disk[%d]= %s, %s, %s\n", lsdsks, nm, sz, model);
                      lsdsk_str = lsdsk_str ""  nm ", " sz ", " model "/";
                   }
                    continue;
                  }
                  next;
                }
                END {
                  if (disk_val != "") {
                    key[++i]="disks";
                    val[  i]=disk_val;
                  }
                  hdr="++\\t";for (j=1; j <= i; j++) { printf("%s%s\t", hdr, key[j]);hdr="";} printf("\n");
                  hdr="++\\t";for (j=1; j <= i; j++) { printf("%s%s\t", hdr, val[j]);hdr="";} printf("\n");
                  for (j=1; j <= i; j++) { printf("%s\t%s\n", key[j], val[j]);}
                }
                ' $file1 $file2 $file3 $file4`
      if [ "$barg" != "" ]; then
         valid=1
         echo "=== sysinfo === $d"
         if [ "$sysinfo_kv" == "" ]; then
	   sysinfo_kv=`echo -e "$barg" | grep "++"`
         fi
         echo -e "$barg"
	 tmp_str=`echo -e "$barg" | grep "++" | awk -v lkfor="host" '
              BEGIN{
                hdr=0;
                sv_col=-1;
              }
              {
                if (hdr==0){
                  hdr=1;
                  for (i=1; i <= NF; i++) {
                    if ($i == lkfor) {
                     sv_col = i;
                     break;
                    }
                  }
                } else {
                  if (sv_col != -1) {
                    str = $sv_col;
                    gsub(/\./, "_", str); # going to use hostname as key for bash array key. bash doesnt like . in key
                    printf("%s\n", str);
                  } else {
                    printf("%s\n", "not_found");
                  }
                }
              }
              '`
         HOST_SYSINFO=$tmp_str
         STR2=${HOST_ARR[$HOST_SYSINFO]}
         echo "$0.$LINENO HOST_SYSINFO= $HOST_SYSINFO" > /dev/stderr
         if [ "$STR2" == "" ]; then
           HOST_ARR_I=$((HOST_ARR_I+1))
           #HOST_ARR[$HOST_SYSINFO]=$HOST_ARR_I
           HOST_ARR[${HOST_SYSINFO}]=$HOST_ARR_I
           HOST_ARR_LKUP[$HOST_ARR_I]=$HOST_SYSINFO
         fi
         echo -e "-------sysinfo str= $tmp_str" > /dev/stderr
      fi
      popd
    fi
  fi
#====start cat /proc/meminfo=====
#MemTotal:       195898172 kB

  #15:39:40.000 Starting RD=run-1-seqWrite; I/O rate: Uncontrolled MAX; elapsed=200; For loops: threads=2 xfersize=1m
  if [ "$bm" == "fio" ]; then
    #RESP=`ls -1 -1 $d/FIO_*|wc -l`
    # nvme2n1: (g=0): rw=read, bs=1M-1M/1M-1M/1M-1M, ioengine=libaio, iodepth=8
    # READ: io=1126.7GB, aggrb=3843.6MB/s, minb=1921.8MB/s, maxb=1921.9MB/s, mint=300004msec, maxt=300004msec
#  nvme2n1: ios=4608828/0, merge=0/0, ticks=17899976/0, in_queue=17606684, util=100.00%
    arg1="";
    shopt -s nullglob
    FILES=($d/FIO_*)
    if [ ${#FILES[@]} -gt 0 ]; then
      barg=`awk 'BEGIN{i=0;dsks=0;}
                 / rw=/{sv=0;k1=index($0," rw="); str=substr($0,k1+4); k2=index(str,","); typ=substr(str,1,k2-1); k3=index(str," bs="); bs=substr(str,k3+4); k4=index(bs,"-"); bs=substr(bs,1,k4-1); }
                 / in_queue=/{if (dsk_nm[$1] != $1) {dsks++;dsk_nm[$1]=$1;dsk_arr[dsks]=$1;}}
                 / aggrb=/{
                    k1=index($0," aggrb=");
                    str=substr($0,k1+7); k2=index(str,",");
                    bw=substr(str,1,k2-1);
                    pos = index(bw, "KB");
                    if (pos > 0) { num = substr(bw,1,pos-1); num = num / 1024.0; bw=sprintf("%.3f", num);}
                    pos = index(bw, "MB");
                    if (pos > 0) { bw = substr(bw,1,pos-1);};
                    #printf("{typ= %s, bs= %s, bw= %s}\n", typ, bs, bw);
                    i++; arr[i,1]=bw;arr[i,2]=bs;arr[i,3]=typ;}
                 END{
                  printf("fio disks used:\n");
                  for(j=1; j<= dsks; j++){
                    printf("%d\t%s\n",j,dsk_arr[j]);
                  }
                  printf("fio_disks:\n");
                  str="DISKS: " dsks " x";
                  for(j=1; j<= dsks; j++){
                    str = str " " dsk_arr[j];
                  }
                  printf("%s\n", str);
                  printf("aggMB/s\tSize\tRd/Wr\n");
                  for(j=1; j<= i; j++){
                    printf("%s\t%s\t%s\n",arr[j,1],arr[j,2],arr[j,3]);
                  }
                }
                ' ${FILES[@]}`
                #' $j`
      arg1="$arg1 $barg";
    fi
    if [ "$arg1" != "" ]; then
       valid=1
       echo "=== fio === $d"
       echo "$barg"
       # fio_key="fio_4K_randomread\tfio_1M_seq_read\tfio_4K_randomwrite\tfio_1M_seq_write"
       if [ $got_fio -eq 0 ]; then
         fio_key=
         fio_val=
         fio_count=0
         RESP=`echo "$barg" | egrep "4K.randre.d"`
         for g in $RESP; do
           fio_key="fio_4K_randomread";
           fio_val="$g"
           fio_count=$((fio_count+1))
           break
         done
         RESP=`echo "$barg" | egrep "16M.re.d"`
         for g in $RESP; do
           fio_key="$fio_key\tfio_16M_seq_read";
           fio_val="$fio_val\t$g"
           fio_count=$((fio_count+1))
           break
         done
         RESP=`echo "$barg" | egrep "1M.re.d"`
         for g in $RESP; do
           fio_key="$fio_key\tfio_1M_seq_read";
           fio_val="$fio_val\t$g"
           fio_count=$((fio_count+1))
           break
         done
         RESP=`echo "$barg" | egrep "4K.randwrite"`
         for g in $RESP; do
           fio_key="$fio_key\tfio_4K_randomwrite";
           fio_val="$fio_val\t$g"
           fio_count=$((fio_count+1))
           break
         done
         RESP=`echo "$barg" | egrep "1M.write"`
         for g in $RESP; do
           fio_key="$fio_key\tfio_1M_seq_write";
           fio_val="$fio_val\t$g"
           fio_count=$((fio_count+1))
           break
         done
         RESP=`echo "$barg" | egrep "16M.write"`
         for g in $RESP; do
           fio_key="$fio_key\tfio_16M_seq_write";
           fio_val="$fio_val\t$g"
           fio_count=$((fio_count+1))
           break
         done
         RESP=`echo "$barg" | egrep "DISKS: "`
         echo "fiodisks RESP= $RESP"
         for g in "$RESP"; do
           gg=`echo $g | sed 's/DISKS: //'`
           fiodisk_key="fio_disks";
           fiodisk_val="$gg"
           echo "fiodisk_key= $fiodisk_key"
           echo "fiodisk_val= $fiodisk_val"
           break
         done
         got_fio=1
       fi
    fi
  fi
  if [ "$bm" == "vdbench" ]; then
#Dec 02, 2019    interval        i/o   MB/sec   bytes   read     resp     read    write     read    write     resp  queue  cpu%  cpu%
#                               rate  1024**2     i/o    pct     time     resp     resp      max      max   stddev  depth sys+u   sys
#09:50:56.010     avg_2-8     3832.1  3832.07 1048576 100.00    1.043    1.043    0.000     2.47     0.00    0.114    4.0   3.1   1.9
    file1=$d/vdbench_stdout.txt
                 # /Starting /{sv=0;if (index($0, "seekpct=0") > 0 && (index($0, "xfersize=4k") > 0 || index($0, "xfersize=1m") > 0)){sv=1;printf("%s\n", $0);}}
    if [ -e $file1 ]; then
      arg1=`awk -v vrb=$VERBOSE 'BEGIN{hdr1="";hdr2="";i=0;}
                 /Starting /{sv=1;if (index($0, "seekpct=0") > 0){typ="seq";}else{typ="rand";}if (vrb > 0){printf("%s\n", $0);}}
                 /bytes +read +resp +read/{if(hdr1==""){hdr1=$0;}}
                 /pct +time +resp +resp/{if(hdr2==""){hdr2=$0;}}
                 / avg_/{if(sv==1){i++; arr[i,1]=$4;arr[i,2]=$5;if($6=="100.00"){arr[i,3]="read";}else{arr[i,3]="write";};arr[i,4]=typ;if(vrb>0){printf("%s\n", $0);}}}
                 END{
                  if(vrb>0){printf("%s\n%s\n", hdr1, hdr2);}
                  printf("aggMB/s\tSize\tRd/Wr\tSeq/Rand\n");
                  for(j=1; j<= i; j++){
                    printf("%s\t%s\t%s\t%s\n",arr[j,1],arr[j,2],arr[j,3],arr[j,4]);
                  }
                 }' $file1`
      #echo " got vdbench file, arg1= $arg1"
      if [ "$arg1" != "" ]; then
         valid=1
         echo "=== vdbench === $d"
         echo "$arg1"
      fi
#logfile.html:09:30:49.903 sd=sd1,lun=/dev/nvme2n1 lun size: 7,500,000,000,000 bytes; 6,984.9194 GB (1024**3); 7,500.0001 GB (1000**3)
      file2=$d/logfile.html
      if [ -e $file2 ]; then
        arg2=`awk '/,lun=/{printf("%s\n", $0);}' $file2`
      fi
    fi
  fi
  if [ "$bm" == "stream" ]; then
    file1=$d/stream_full-stream-out.out
    if [ -e $file1 ]; then
      arg1=`grep -E 'Number of Threads counted|Copy|Scale|Add|Triad|Read|Function' $file1`
      #echo " got stream file, arg1= $arg1"
      if [ "$arg1" != "" ]; then
#Number of Threads counted = 32
#Function    Best Rate MB/s  Avg time     Min time     Max time
#Copy:           71321.0     0.030381     0.030110     0.043833
#Scale:          71709.4     0.030164     0.029947     0.035470
#Add:            81041.3     0.040092     0.039748     0.058096
#Triad:          80980.1     0.040136     0.039778     0.055336
	arg1=`echo "$arg1" | awk '
             BEGIN {i=0;}
             function add_key_val(str, res, div) {
                if (div==1){res=res/1024.0};i++;key[i]=str;val[i]=sprintf("%.3f", res);
             }
             /^Number of/{ add_key_val("stream_threads", $6, 0); next;}
             /^Copy:/    { add_key_val("stream copy GB/s",$2, 1); next;}
             /^Scale:/   { add_key_val("stream scale GB/s",$2, 1); next;}
             /^Add:/     { add_key_val("stream add GB/s",$2, 1); next;}
             /^Triad:/   { add_key_val("stream triad GB/s",$2, 1); next;}
             /^Read:/   { add_key_val("stream read GB/s",$2, 1); next;}
                END {
                  hdr="++\\t";for (j=1; j <= i; j++) { printf("%s%s\t", hdr, key[j]);hdr="";} printf("\n");
                  hdr="++\\t";for (j=1; j <= i; j++) { printf("%s%s\t", hdr, val[j]);hdr="";} printf("\n");
                  for (j=1; j <= i; j++) { printf("%s\t%s\n", key[j], val[j]);}
                }
		'`

         echo "=== stream === $d"
         echo "$arg1"
         if [ "$stream_kv" == "" ]; then
            stream_kv=`echo -e "$arg1" |grep "++"`
            echo "stream_kv= $stream_kv"
         else
            if [ "$stream_kv" != "" -a "$ALL_DIRS" == "1" ]; then
             tmp=`echo -e "$arg1" |grep "++"`
             ln_1a=`echo -e "$stream_kv" | awk '{if (NR==1){printf("%s\n", $0);}}'|sed 's/\t$//'`
             ln_2a=`echo -e "$stream_kv" | awk '{if (NR==2){printf("%s\n", $0);}}'|sed 's/\t$//'`
             ln_1b=`echo -e "$tmp" | awk '{if (NR==1){printf("%s\n", $0);}}'|sed 's/++\t//'`
             ln_2b=`echo -e "$tmp" | awk '{if (NR==2){printf("%s\n", $0);}}'|sed 's/++\t//'`
             echo -e "ln_1a= $ln_1a"
             echo -e "ln_2a= $ln_2a"
             echo -e "ln_1b= $ln_1b"
             echo -e "ln_2b= $ln_2b"
             stream_kv=$(printf "$ln_1a\t$ln_1b\n$ln_2a\t$ln_2b")
             #farr=$(tr -d \\n < $tmp)
             #stream_kv="$stream_kv;$tmp"
            echo -e "stream_kv= $stream_kv"
            fi
         fi
         valid=1
      fi
    fi
  fi
  if [ "$bm" == "geekbench" ]; then
    file1=`find $d -name "gb_scores.tsv"`
    if [ $VERBOSE -gt 0 ]; then
      echo "geekbench file1= $file1"
    fi
    gb_k="\t"
    gb_v="\t"
    if [ "$file1" != ""  ]; then
      arg1=`grep 'score_single' $file1 | sed 's/.*\t//g; s/ //g;'`
      arg2=`grep 'score_multi' $file1 | sed 's/.*\t//g; s/ //g;'`
      echo "=== geekbench === $d"
      key="++\tgb_single\tgb_multi"
      val="++\t$arg1\t${arg2}"
      echo -e "$key"
      echo -e "$val"
      if [ "$arg1" != "" -a "$arg2" != "" ]; then
         gb_i=${gb_arr1[${dirs_i}]}
         if [ "$gb_i" == "" ]; then
           gb_i=0
         fi
         gb_i=$((gb_i+1))
         gb_arr1[${dirs_i}]=$gb_i
         gb_arr2[${dirs_i},$gb_i]=$arg1
         gb_arr3[${dirs_i},$gb_i]=$arg2
         if [ "$gb_key" == "" ]; then
            gb_key="$key";
            gb_val="$val";
         else
            if [ "$gb_key" != "" -a "$ALL_DIRS" == "1" ]; then
             key="\tgb_single\tgb_multi"
             val="\t$arg1\t${arg2}"
             gb_key="$gb_key$key";
             gb_val="$gb_val$val";
            echo -e "gb_key= $gb_key"
            echo -e "gb_val= $gb_val"
            fi
         fi
         str2=${gb_arr1[${dirs_i}]}
         echo "gb_arr1[${dirs_i}]= ${gb_arr1[${dirs_i}]}, gb_i= $gb_i,  ${gb_arr2[${dirs_i},$gb_i]}, ${gb_arr3[${dirs_i},$gb_i]}"
         #echo "$0.$LINENO: bye"
         #exit 1
      fi
      if [ "$arg1" != "" -a "$arg2" != "" ]; then
         valid=1
      fi
    fi
  fi
  if [ "$bm" == "coremark" ]; then
    file1=`find $d -name "run_*_*.log*" | sort`
    if [ $VERBOSE -gt 0 ]; then
      echo "coremark file1= $file1"
    fi
    if [ "$file1" != ""  ]; then
     MyD=`pwd`
     RES=`$SCR_DIR/coremark/get_coremark_results.sh $file1`
     LNS=`echo -e "$RES" | wc -l`
     echo "LNS= $LNS"
     cm_lines=$((cm_lines+1))
     for (( t_i=1; t_i < $LNS; t_i++ )); do
       LN=(`echo "$RES" | awk -v want="$t_i" 'BEGIN{want+=0;i=-1;}{i++;if (i==want){print $0;exit}}'`)
       echo "LN[$t_i]= ${LN[@]}"
       cmln_i=$((cmln_i+1))
         cm_i=${cm_arr[${dirs_i},0]}
         if [ "$cm_i" == "" ]; then
           cm_i=0
         fi
         cm_i=$((cm_i+1))
         cm_arr[${dirs_i},0]=$cm_i
         cm_arr[${dirs_i},$cm_i,0]=${LN[0]}
         cm_arr[${dirs_i},$cm_i,1]=${LN[1]}
         cm_arr[${dirs_i},$cm_i,2]=${LN[4]}
         cm_dir=$d
      key="++\tcm_score\tcm_thrds\tcm_pct_stdev"
      val="++\t${LN[0]}\t${LN[1]}\t${LN[4]}"
      echo -e "$key"
      echo -e "$val"
      if [ "$cm_key" == "" ]; then
            cm_key="$key";
            cm_val="$val";
      else
        key="cm_score\tcm_thrds\tcm_pct_stdev"
        val="${LN[0]}\t${LN[1]}\t${LN[4]}"
        cm_key="$cm_key$key";
        cm_val="$cm_val$val";
      fi
     done
     #echo -e "myd= $MyD cm_arr= ${RES[0]}" > /dev/stderr
     #echo -e "myd= $MyD cm_arr= ${cm_arr[${dirs_i},0]}" > /dev/stderr
     #exit
   
    fi
  fi
  if [ "$bm" == "specjbb" ]; then
    echo "============= specjbb ================"
    file2=`find $d -name "specjbb.log"`
    echo "$0.$LINENO specjbb.log= $file2" > /dev/stderr
    if [ "$file2" == "" ]; then
      file2=`find $d/.. -name "specjbb.log"`
      echo "$0.$LINENO specjbb.log= $file2" > /dev/stderr
    fi
    if [ $VERBOSE -gt 0 ]; then
      echo "specjbb1 file2= $file2"
    fi
    java_k="\t"
    java_v="\t"
    if [ "$file2" != ""  ]; then
      arg3=`grep 'version' $file2 | sed 's/.*version //g;'`
      if [ "$arg3" != "" -a "$ALL_DIRS" != "1" ]; then
        java_k="\tjava_ver"
        java_v="\t$arg3"
      fi
      java_str=`awk '
        /version/{ if ($2 == "version" && ($1 == "java" || $1 == "openjdk")) {jdkver= $3;}}
        /^arg1=/{dir=substr($0, 6, length($0));}
        /^arg2=/{n=split($0,arr, "=");gsub(/ /,"",arr[3]);numa=arr[3]; if (arr[3] == "") { numa="unbnd";printf("__line= %s\n",$0) > "/dev/stderr";} gsub(/^[ \t]+/,"",numa);}
        /^arg3=/{n=split($0,arr, "=");grps=arr[3]+0; if (n < 3 || grps < 1) {def_grp=1; grps=1;}}
        /^arg4=/{
           n=split($0,arr, "=");
           tpg=arr[3]+0;
           p1=index(arr[2],"NUM_CPUS(");
           sb=substr(arr[2],p1+9,length(arr[2]));
           p1=index(sb,")");
           num_cpus=substr(sb,1,p1-1)+0;
           if ((numa=="local" || numa=="remote") && tpg == 0 && num_cpus > 0 && grps > 0) { tpg = num_cpus/grps; }
           if (numa=="unbnd") { tpg = num_cpus/grps; }
        }
        /^NUMACTL_NODES=/{numa_nodes= $2;}
        /\/bin\/java/{ java= $0;}
        END{
           if (def_grp == 1 && (numa == "local" || numa == "remote")) {
              grps = numa_nodes;
              if (num_cpus > 0) { tpg = num_cpus/grps; }
           }
           str=sprintf("specjbb numa_nodes= %s, numa_strat= %s, grps= %s, tpg= %s java= %s, java_ver= %s", numa_nodes, numa, grps, tpg, java, jdkver);
           printf("%s\n", str);printf("%s\n", str) > "/dev/stderr";
        }' $file2`
        IFS=$'\n' NUMA_STRS=(`egrep "^CMD_C|^CMD_BE|^CMD_TI" $file2`)
        IFS=$IFS_SV
        NUMA_STR=
        for ((jj=0; jj < ${#NUMA_STRS[@]}; jj++)); do
          NUMA_STR="${NUMA_STR};\"${NUMA_STRS[$jj]}\""
        done
          
      if [ "$java_str" != "" ]; then
         java_k="\tjava_ver"
         java_v="\t${java_str}"
         echo "java_str ${java_str} $java_k $java_v" > /dev/stderr
      fi
    fi
    file1=`find $d -name "specjbb2015-M-*-00001.raw"`
    if [ $VERBOSE -gt 0 ]; then
      echo "specjbb2 file1= $file1"
    fi
    if [ "$file1" != ""  ]; then
     for f in $file1; do
      arg1=`grep 'jbb2015.result.metric.max-jOPS =' $f | sed 's/.*=//g; s/ //g;'`
      arg2=`grep 'jbb2015.result.metric.critical-jOPS =' $f | sed 's/.*=//g; s/ //g;'`
         sj_i=${sj_arr[${dirs_i},0]}
         if [ "$sj_i" == "" ]; then
           sj_i=0
         fi
         sj_i=$((sj_i+1))
         sj_arr[${dirs_i},0]=$sj_i
         sj_arr[${dirs_i},$sj_i,0]=$arg1
         sj_arr[${dirs_i},$sj_i,1]=$arg2
         sj_dir=$(dirname $file1)
    echo "__val2__;sj_max_crit;$arg1;$arg2;${PROJ_DIR};${dirs[$dirs_i]};$sj_dir${NUMA_STR}" 
      echo "=== specjbb === $d"
      key="++\tmax-jOPS\tcrit-jOPS${java_k}"
      val="++\t$arg1\t${arg2}${java_v}"
      #if [ "$specjbb_key" == "" ]; then
      #  specjbb_key="$key";
      #  specjbb_val="$val";
      #fi
      echo -e "$key"
      echo -e "$val"
      if [ "$arg1" != "" -a "$arg2" != "" ]; then
         if [ "$specjbb_key" == "" ]; then
            specjbb_key="$key";
            specjbb_val="$val";
         else
            if [ "$specjbb_key" != "" -a "$ALL_DIRS" == "1" ]; then
             key="max-jOPS\tcrit-jOPS${java_k}"
             val="$arg1\t${arg2}${java_v}"
             specjbb_key="$specjbb_key$key";
             specjbb_val="$specjbb_val$val";
            echo -e "specjbb_key= $specjbb_key"
            echo -e "specjbb_val= $specjbb_val"
            fi
         fi
      fi
      if [ "$arg1" != "" -a "$arg2" != "" ]; then
         valid=1
      fi
     done
    fi
  fi
  #if [ ${did_bmarks[$bm]+_} ]; then
  #  valid=0
  #fi
  if [ $VERBOSE -gt 0 ]; then
  if [ $valid -eq 1 ]; then
    echo "  ckt $bm, dir $d"
    echo "  arg1= $arg1"
    #if [ "$arg2" != "" ]; then
      #echo "  arg2= $arg2"
    #fi
  fi
  fi
  did_bmarks[$bm]=$d
done


popd

arr=()
while read -r line; do
   arr+=("$line")
done <<< "$stream_kv"
echo -e "arr= ${arr}"
stream_key="${arr[0]}"
stream_val="${arr[1]}"
echo -e "st-key= $stream_key"
echo -e "st-val= $stream_val"

arr=()
while read -r line; do
   arr+=("$line")
done <<< "$sysinfo_kv"
sysinfo_key="${arr[0]}"
sysinfo_val="${arr[1]}"
echo -e "$specint_key"
echo -e "$specint_val"
echo -e "$stream_key"
echo -e "$stream_val"
echo -e "$fio_key"
echo -e "$fio_val"
echo -e "$fiodisk_key"
echo -e "$fiodisk_val"
echo -e "$specjbb_key"
echo -e "$specjbb_val"
echo -e "$gb_key"
echo -e "$gb_val"
echo -e "$sysinfo_key"
echo -e "$sysinfo_val"
echo "========== all ========="
specint_key=`echo -e "$specint_key" | sed 's/++ //;'| sed 's/++\t//;'`
specint_val=`echo -e "$specint_val" | sed 's/++ //;'| sed 's/++\t//;'`
stream_key=`echo -e "$stream_key" | sed 's/++ //;'| sed 's/++\t//;'`
stream_val=`echo -e "$stream_val" | sed 's/++ //;'| sed 's/++\t//;'`
fio_key=`echo -e "$fio_key" | sed 's/++ //;'| sed 's/++\t//;'`
fio_val=`echo -e "$fio_val" | sed 's/++ //;'| sed 's/++\t//;'`
fiod_key="fio_disks"
fiod_val=""
if [ "$fiodisk_key" != "" ]; then
  fiod_key="$fiodisk_key"
  fiod_val="$fiodisk_val"
fi
specjbb_key=`echo -e "$specjbb_key" | sed 's/++ //;'| sed 's/++\t//;'`
specjbb_val=`echo -e "$specjbb_val" | sed 's/++ //;'| sed 's/++\t//;'`
gb_key=`echo -e "$gb_key" | sed 's/++ //;'| sed 's/++\t//;'`
gb_val=`echo -e "$gb_val" | sed 's/++ //;'| sed 's/++\t//;'`
sysinfo_key=`echo -e "$sysinfo_key" | sed 's/++ //;'| sed 's/++\t//;'`
sysinfo_val=`echo -e "$sysinfo_val" | sed 's/++ //;'| sed 's/++\t//;'`
k1="$specint_key\t$stream_key\t$fio_key\t$specjbb_key\t$gb_key\t$sysinfo_key\t$fiod_key"
v1="$specint_val\t$stream_val\t$fio_val\t$specjbb_val\t$gb_val\t$sysinfo_val\t$fiod_val"
k2=`echo -e "$k1" | sed 's/\t/;/g;'`
v2=`echo -e "$v1" | sed 's/\t/;/g;'`
echo -e "$specint_key\t$stream_key\t$fio_key\t$specjbb_key\t$gb_key\t$sysinfo_key"
echo -e "$specint_val\t$stream_val\t$fio_val\t$specjbb_val\t$gb_val\t$sysinfo_val"
if [ "$SKU" == "\"N/A\"" -a "$HOST" != "" ]; then
  SKU=$HOST
fi
if [ "$NUM_HOST" != "" ]; then
  kk2=";NUM_HOST"
  vv2=";$NUM_HOST"
fi
echo "__key__;SKU;SKU_MAKER;SKU_MODEL${kk2};$k2"
echo "__val__;$SKU;$SKU_MAKE;$SKU_MODEL${vv2};$v2"

#echo "dirs= ${#dirs[@]}"

for ((dirs_i=${#dirs[@]}-1; dirs_i>=0; dirs_i--)); do
  gb_i=${gb_arr1[${dirs_i}]}
  echo "gb_i= $gb_i, dirs_i= $dirs_i"
  if [ "$gb_i" != "" ]; then
    #echo "__val2__;"
   for ((j=1; j<=$gb_i; j++)); do
    echo "__val2__;gb_single_multi;${gb_arr2[${dirs_i},${j}]};${gb_arr3[${dirs_i},${j}]};${PROJ_DIR};${dirs[$dirs_i]}" 
   done
  fi
done
for ((dirs_i=${#dirs[@]}-1; dirs_i>=0; dirs_i--)); do
  sj_i=${sj_arr[${dirs_i},0]}
  #echo "sj_i= $sj_i"
  if [ "$sj_i" != "" ]; then
   j=$sj_i;
   #for ((j=1; j<=$sj_i; j++)); do
    #echo "__val2__;sj_max_crit;${sj_arr[${dirs_i},${j},0]};${sj_arr[${dirs_i},${j},1];};${PROJ_DIR};${dirs[$dirs_i]}" 
   #done
  fi
done
echo "++++++++++++++++++++++at end: cm_arr= ${cm_arr[@]}" > /dev/stderr
for ((dirs_i=${#dirs[@]}-1; dirs_i>=0; dirs_i--)); do
  cm_i=${cm_arr[${dirs_i},0]}
  echo "cm_i= $cm_i" > /dev/stderr
  if [ "$cm_i" != "" ]; then
    echo "__val2__;"
   for ((j=1; j<=$cm_i; j++)); do
    echo "__val2__;coremark,score,thrds,%stdev;${cm_arr[${dirs_i},${j},0]};${cm_arr[${dirs_i},${j},1];};${cm_arr[${dirs_i},${j},2];};${cm_arr[${dirs_i},${j},3];};${PROJ_DIR};${dirs[$dirs_i]}" 
   done
  fi
done

exit
while IFS= read -r line; do
    my_array+=( "$line" )
    echo $line
done < <( $CMD )
IFS=$IFS_SV
LIST=`ls -1 |grep -E "[0-9]+-[0-9]+-[0-9]+_[0-9]+_"`

result/CPU2017.001.log
copies           = 32
result/CPU2017.001.intrate.refrate.txt
Est. SPECrate2017_int_base


for f in $LIST; do
 echo $f
done



popd
