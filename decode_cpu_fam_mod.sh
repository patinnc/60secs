#!/bin/bash

export LC_ALL=C
INF=/proc/cpuinfo
if [ "$1" != "" ]; then
  INF=$1
fi
export LANGUAGE=C.UTF-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export LC_CTYPE=C.UTF-8
export LC_ALL=C


SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
AWK_BIN=awk
if [ -e $SCR_DIR/bin/gawk ]; then
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  AWK_BIN=$SCR_DIR/bin/gawk
elif [[ "$OSTYPE" == "darwin"* ]]; then
   # Mac OSX
   AWK_BIN=gawk
fi
fi
if [[ "$OSTYPE" == "darwin"* ]]; then
  if [ "$1" == "" ]; then
   #machdep.cpu.vendor:
   #machdep.cpu.brand_string
   #machdep.cpu.family: 6
   #machdep.cpu.model: 158
   #sysctl machdep.cpu
   #echo "$RESP"
   VENDR=`sysctl machdep.cpu.vendor|awk '{$1="";printf("Vendor ID: %s\n", $0);exit;}'`
   FAM=`sysctl machdep.cpu|grep family| awk '{$1=""; printf("CPU family: %s\n", $0);exit;}'`
   MOD=`sysctl machdep.cpu|grep cpu.model| awk '{$1="";printf("Model: %s\n", $0);exit}'`
   BRAND=`sysctl machdep.cpu|grep cpu.brand_str|awk '{$1="";printf("Model name: %s\n", $0);exit;}'`
   RESP=`echo $VENDR; echo $FAM; echo $MOD; echo $BRAND`
  else
  if [ ! -e $INF ]; then
    echo "didn't find input file $INF"
    exit
  fi
   RESP=`cat $INF`
  fi
 else
  if [ ! -e $INF ]; then
    echo "didn't find input file $INF"
    exit
  fi
   RESP=`cat $INF`
fi

export AWKPATH=$SCR_DIR

echo "$RESP" | $AWK_BIN -v vrb=0 '
   @include "decode_cpu_fam_mod.awk"
   BEGIN{;}
   function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
   function rtrim(s) { sub(/[ \t\r\n,]+$/, "", s); return s }
   function trim(s) { return rtrim(ltrim(s)); }
   {
      if (vrb==1) {printf("%s\n", $0);}
      n=split($0, arr, ":");
      arr[1]=trim(arr[1]);
      arr[2]=trim(arr[2]);
      if (vrb==1) {printf("1=_%s_, a1=_%s_ a2= %s\n", $1, arr[1], arr[2]);}
      if (arr[1]=="Architecture" && arr[2] == "aarch64") { printf("arm64\n"); exit 0; }
      if (arr[1]=="CPU implementer" && arr[2] == "0x41") { printf("arm64\n"); exit 0; }
      if (arr[1]=="CPU family" || arr[1]=="cpu family") {cpu_fam=arr[2];if(vrb==1){printf("cpu_fam= %s\n", cpu_fam)};next;}
      if (arr[1]=="Vendor ID"  || arr[1]=="vendor_id") {cpu_vnd=arr[2];if(vrb==1){printf("cpu_vnd= %s\n", cpu_vnd)};next;}
      if (arr[1]=="Model"      || arr[1]=="model") { cpu_mod=arr[2];if(vrb==1){printf("cpu_mod= %s\n", cpu_mod);}next; }
      if (arr[1]=="Model name" || arr[1]=="model name") {
#vendor_id	: AuthenticAMD
#cpu family	: 25
#model		: 1
#model name	: AMD EPYC 7543 32-Core Pro
         cpu_model_name = arr[2]; 
         if(vrb==1){printf("cpu_model_name= %s\n", cpu_model_name);}
         if(vrb==1){printf("decode_fam_mod(%s, %s, %s, %s)\n", cpu_vnd, cpu_fam, cpu_mod, cpu_model_name) > "/dev/stderr";}
         res=decode_fam_mod(cpu_vnd, cpu_fam, cpu_mod, cpu_model_name);
         printf("%s\n", res);
         exit;
      }
   }
'
exit

# /proc/cpuinfo output
#processor	: 0
#vendor_id	: GenuineIntel
#cpu family	: 6
#model		: 79
#model name	: Intel(R) Xeon(R) CPU E5-2620 v4 @ 2.10GHz
#stepping	: 1
#microcode	: 0xb000038
#cpu MHz		: 1200.337
#cache size	: 20480 KB
#physical id	: 0
#siblings	: 16
#core id		: 0
#cpu cores	: 8
#apicid		: 0
#initial apicid	: 0
#fpu		: yes
#fpu_exception	: yes
#cpuid level	: 20
#wp		: yes
#flags		: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni
# pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 sdbg fma cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm abm 3dnowprefetch cpuid_fault epb cat_l3 cdp_l3 invpcid_single pti ssbd ibrs ibpb s
#tibp tpr_shadow vnmi flexpriority ept vpid fsgsbase tsc_adjust bmi1 hle avx2 smep bmi2 erms invpcid rtm cqm rdt_a rdseed adx smap intel_pt xsaveopt cqm_llc cqm_occup_llc cqm_mbm_total cqm_mbm_local dtherm ida arat pln pts md_clear flush_l1d
#bugs		: cpu_meltdown spectre_v1 spectre_v2 spec_store_bypass l1tf mds swapgs taa itlb_multihit
#bogomips	: 4199.77
#clflush size	: 64
#cache_alignment	: 64
#address sizes	: 46 bits physical, 48 bits virtual
#power management:
#
# lscpu output
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

# based on https://en.wikichip.org/wiki/intel/cpuid
NMS="
Ice Lake (Server)	SP?	0	0x6	0x6	0xC	Family 6 Model 108
Ice Lake (Server)	DE?	0	0x6	0x6	0xA	Family 6 Model 106
Cooper Lake/Skylake	 ?	0	0x6	0x5	0x5	Family 6 Model 85
Broadwell (Server)	E, EP, EX	0	0x6	0x4	0xF	Family 6 Model 79
Broadwell (Server)	DE, Hewitt Lake	0	0x6	0x5	0x6	Family 6 Model 86
Haswell (Server)	E, EP, EX	0	0x6	0x3	0xF	Family 6 Model 63
Ivy Bridge (Server)	E, EN, EP, EX	0	0x6	0x3	0xE	Family 6 Model 62
Sandy Bridge (Server)	E, EN, EP	0	0x6	0x2	0xD	Family 6 Model 45
Westmere (Server)	Gulftown, EP	0	0x6	0x2	0xC	Family 6 Model 44
EX	0	0x6	0x2	0xF	Family 6 Model 47
Nehalem (Server)	EX	0	0x6	0x2	0xE	Family 6 Model 46
Lynnfield	0	0x6	0x1	0xE	Family 6 Model 30
Bloomfield, EP, WS	0	0x6	0x1	0xA	Family 6 Model 26
Penryn (Server)	Dunnington	0	0x6	0x1	0xD	Family 6 Model 29
Harpertown, QC, Wolfdale, Yorkfield	0	0x6	0x1	0x7	Family 6 Model 23
"
STR="Family $1 Model $2"
echo "$NMS" | AWK_BIN -v lkfor="$STR" '{n=split($0,arr,"\t"); printf("%s\t%s\n", arr[1], arr[n]); }'
nm=`echo "$NMS" | AWK_BIN -v lkfor="$STR" '{if (index($0, lkfor) > 0) {n=split($0,arr,"\t"); printf("%s\n", arr[1]); }}'`
echo "$nm"

#echo "$NMS"
