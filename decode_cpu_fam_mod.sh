#!/usr/bin/env bash

SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
AWK_BIN=awk

ARCH=
FAMILY=
MODEL=
NAME=
VENDOR=
INFILE=
VERBOSE=0
UNKNOWN="n/a"

while getopts "ha:f:i:m:n:u:v:V:" opt; do
  case ${opt} in
    a )
      ARCH=$OPTARG
      if [ "$ARCH" == "aarch64" ]; then
        echo "arm64"
        exit 0
      fi
      ;;
    f )
      FAMILY=$OPTARG
      ;;
    i )
      INFILE=$OPTARG
      ;;
    m )
      MODEL=$OPTARG
      ;;
    n )
      NAME=$OPTARG
      ;;
    u )
      UNKNOWN=$OPTARG
      ;;
    v )
      VENDOR=$OPTARG
      if [ "$VENDOR" == "ARM" -o "$VENDOR" == "arm" ]; then
        echo "arm64"
        exit 0
      fi
      ;;
    V )
      VERBOSE=$OPTARG
      ;;
    h )
      echo "$0 [ [ -a architecture | -f family -m model -n name -v vendor ] | filename"
      echo " Get the cpu code name from lscpu or /proc/cpuinfo"
      echo " Either pass in the -f/-m/-n/-v options or the name of the lscpu file or /proc/cpuinfo."
      echo "   -i input_filename  must be either a lscpu output file or a /proc/cpuinfo file"
      echo "   -V verbose 0 (not verbose, the default) or 1 verbose"
      echo "   -u unknown_string   if the cpu is not found, this string is returned. Default is \"n/a\""
      echo " If nothing is entered then the script looks for /proc/cpuinfo (on linux) or gets the info from sysctl machdep.cpu on macbook"
      echo "   -a architecture (aarch64 for ARM, or x86_64 for Intel/AMD)"
      echo "      if you enter -a aarch64 then the script returns 'arm64'... I don't yet know how to get an ARM chip codename"
      echo "   -f cpu_family (like 6 for Intel)"
      echo "   -m cpu_model  (like 158 (not hex))"
      echo "   -n cpu_model_name  the model name must be enclosed in dbl quotes since it has spaces"
      echo "   -v cpuvendor_id  (GenuineIntel or AuthenticAMD or ARM)"
      echo "      if you enter -v ARM then the script returns 'arm64'... I don't yet know how to get an ARM chip codename"
      echo "   for example: "
      echo "     ./decode_cpu_fam_mod.sh -f 6 -m 158 -n \"Intel(R) Core(TM) i7-8850H CPU @ 2.60GHz\" -v GenuineIntel"
      echo "   returns:"
      echo "   Coffee Lake"
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
shift $((OPTIND -1))

INF=/proc/cpuinfo
if [ "$1" != "" ]; then
  INF=$1
  if [ ! -e "$INF" ]; then
    echo "$0.$LINENO you entered arg $INF but didn't find the file $INF. Bye"
    exit 0
  fi
fi
if  [ "$INFILE" != "" ]; then
  if [ ! -e "$INFILE" ]; then
    echo "$0.$LINENO you entered -i $INFILE but didn't find the file $INFILE. Bye"
    exit 0
  fi
  INF=$INFILE
fi

if [ "$FAMILY" != "" -a "$MODEL" != "" -a "$NAME" != "" -a "VENDOR" != "" ]; then
  INF=
  if [ "$ARCH" != "" ]; then
    ASTR="Architecture  : $ARCH"
  fi
  RESP="vendor_id	: $VENDOR
cpu family	: $FAMILY
model		: $MODEL
model name	: $NAME
$ASTR
"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  if [ "$1" == "" -a "$INFILE" == "" -a "$RESP" == "" ]; then
   #machdep.cpu.vendor:
   #machdep.cpu.brand_string
   #machdep.cpu.family: 6
   #machdep.cpu.model: 158
   #sysctl machdep.cpu
   #echo "$RESP"
   VENDR=`sysctl machdep.cpu.vendor|awk '{$1="";printf("Vendor ID: %s\n", $0);exit 0;}'`
   FAM=`sysctl machdep.cpu|grep cpu.family| awk '{$1=""; printf("CPU family: %s\n", $0);exit 0;}'`
   MOD=`sysctl machdep.cpu|grep cpu.model| awk '{$1="";printf("Model: %s\n", $0);exit 0;}'`
   BRAND=`sysctl machdep.cpu|grep cpu.brand_str|awk '{$1="";printf("Model name: %s\n", $0);exit 0;}'`
   RESP=`echo $VENDR; echo $FAM; echo $MOD; echo $BRAND`
   #echo "RESP= $RESP"
  fi
fi
if [ "$RESP" == "" ]; then
  if [ ! -e $INF ]; then
    echo "didn't find input file $INF"
    exit 1
  fi
  RESP=`cat $INF`
fi

echo "$RESP" | $AWK_BIN -v unknown="$UNKNOWN" -v vrb="$VERBOSE" '
   function decode_fam_mod(vndor, fam, mod, cpu_model_name,     i, k, res, csx_i, dcd) {
      if (vndor == "GenuineIntel") {
        # cascade lake 2nd gen stuff from https://www.intel.com/content/www/us/en/products/docs/processors/xeon/2nd-gen-xeon-scalable-spec-update.html
        # 2nd gen xeon scalable cpus: cascade lake sku is 82xx, 62xx, 52xx, 42xx 32xx W-32xx  from https://www.intel.com/content/www/us/en/products/docs/processors/xeon/2nd-gen-xeon-scalable-spec-update.html
        # skylake 1st gen stuff from https://www.intel.com/content/www/us/en/processors/xeon/scalable/xeon-scalable-spec-update.html
        # 1st gen xeon scalable cpus: 81xx, 61xx, 51xx, 81xxT, 61xxT 81xxF, 61xxF, 51xx, 41xx, 31xx, 51xxT 41xxT, 51xx7, k
        
        # cpuid tables from https://en.wikichip.org/wiki/intel/cpuid
        i=0;
        dcd[++i,1]="Ice Lake";     dcd[i,2]="Family 6 Model 108";
        dcd[++i,1]="Ice Lake";     dcd[i,2]="Family 6 Model 106";
        dcd[++i,1]="Coffee Lake";  dcd[i,2]="Family 6 Model 158";
        dcd[++i,1]="Cooper Lake/Cascade Lake/Skylake";  dcd[i,2]="Family 6 Model 85"; csx_i=i;
        dcd[++i,1]="Broadwell";    dcd[i,2]="Family 6 Model 79";
        dcd[++i,1]="Broadwell";    dcd[i,2]="Family 6 Model 86";
        dcd[++i,1]="Haswell";      dcd[i,2]="Family 6 Model 63";
        dcd[++i,1]="Ivy Bridge";   dcd[i,2]="Family 6 Model 62";
        dcd[++i,1]="Sandy Bridge"; dcd[i,2]="Family 6 Model 45";
        dcd[++i,1]="Westmere";     dcd[i,2]="Family 6 Model 44";
        dcd[++i,1]="EX";           dcd[i,2]="Family 6 Model 47";
        dcd[++i,1]="Nehalem";      dcd[i,2]="Family 6 Model 46";
        dcd[++i,1]="Lynnfield";    dcd[i,2]="Family 6 Model 30";
        dcd[++i,1]="Bloomfield, EP, WS";  dcd[i,2]="Family 6 Model 26";
        dcd[++i,1]="Penryn";       dcd[i,2]="Family 6 Model 29";
        dcd[++i,1]="Harpertown, QC, Wolfdale, Yorkfield";  dcd[i,2]="Family 6 Model 23";
        str = "Family " fam " Model " mod;
        res=" ";
        for(k=1; k <= i; k++) {
           if (dcd[k,2] == str) {
              res=dcd[k,1];break;
           }
        }
        if (k==csx_i) { # so cooper/cascade/sky
           if (match(cpu_model_name, / [86543]2[0-9][0-9]/) > 0) { res="Cascade Lake"}
           else if (match(cpu_model_name, / [86543]1[0-9][0-9]/) > 0) { res="Skylake"}
        }
        if (res == " ") { res = unknown; }
        return res;
      }
      if (vndor == "AuthenticAMD") {
       # cpuid tables from https://en.wikichip.org/wiki/amd/cpuid
       #Zen 2  Rome    0x8     0xF     0x2     0x?     Family 23 Model [32-47]
       #Matisse        0x8     0xF     0x7     0x1     Family 23 Model 113
       #Castle Peak    0x8     0xF     0x3     0x1     Family 23 Model 49
       #Zen+   Picasso 0x8     0xF     0x1     0x8     Family 23 Model 24
       #Pinnacle Ridge 0x8     0xF     0x0     0x8     Family 23 Model 8
       #Zen    Raven Ridge     0x8     0xF     0x1     0x1     Family 23 Model 17
       #Naples, Whitehaven, Summit Ridge, Snowy Owl    0x8     0xF     0x0     0x1     Family 23 Model 1
#Vendor ID:           AuthenticAMD
#CPU family:          25
#Model:               1
#Model name:          AMD EPYC 7543 32-Core Processor
       
       i=0;
       dcd[++i,1]="Zen2 Rome";           dcd[i,2]="Family 23 Model 32-47"; dcd[i,3]=23; dcd[i,4]=32;  dcd[i,5]=47;
       dcd[++i,1]="Zen2 Matisse";        dcd[i,2]="Family 23 Model 113";   dcd[i,3]=23; dcd[i,4]=113; dcd[i,5]=113;
       dcd[++i,1]="Zen2 Castle Peak";    dcd[i,2]="Family 23 Model 49";    dcd[i,3]=23; dcd[i,4]=49;  dcd[i,5]=49;
       dcd[++i,1]="Zen+ Picasso";        dcd[i,2]="Family 23 Model 24";    dcd[i,3]=23; dcd[i,4]=24;  dcd[i,5]=24;
       dcd[++i,1]="Zen+ Pinnacle Ridge"; dcd[i,2]="Family 23 Model 8";     dcd[i,3]=23; dcd[i,4]=8;   dcd[i,5]=8;
       dcd[++i,1]="Zen Raven Ridge";     dcd[i,2]="Family 23 Model 17";    dcd[i,3]=23; dcd[i,4]=17;  dcd[i,5]=17;
       dcd[++i,1]="Zen Naples/Whitehaven/Summit Ridge/Snowy Owl";
         dcd[i,2]="Family 23 Model 1";    dcd[i,3]=23; dcd[i,4]=1;  dcd[i,5]=1;
       dcd[++i,1]="Zen3 Milan";          dcd[i,2]="Family 25 Model 1";    dcd[i,3]=25; dcd[i,4]=1;  dcd[i,5]=1;
       str = "Family " fam " Model " mod;
       res=" ";
       for(k=1; k <= i; k++) {
         if (dcd[k,3] == fam && dcd[k,4] <= mod && mod <= dcd[k,5] ) {
           res=dcd[k,1];break;
         }
       }
       if (res == " ") { res = unknown; }
       return res;
     }
     return unknown;
   }
   BEGIN{
     rc = 1; # indicates error
   }
   function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
   function rtrim(s) { sub(/[ \t\r\n,]+$/, "", s); return s }
   function trim(s) { return rtrim(ltrim(s)); }
   {
      if (vrb==1) {printf("%s\n", $0);}
      n=split($0, arr, ":");
      arr[1]=trim(arr[1]);
      arr[2]=trim(arr[2]);
      if (vrb==1) {printf("1=_%s_, a1=_%s_ a2= %s\n", $1, arr[1], arr[2]);}
      if (arr[1]=="Architecture" && arr[2] == "aarch64") { printf("arm64\n"); rc=0; exit 0; }
      if (arr[1]=="CPU implementer" && arr[2] == "0x41") { printf("arm64\n"); rc=0; exit 0; }
      if (arr[1]=="CPU family" || arr[1]=="cpu family") {cpu_fam=arr[2];if(vrb==1){printf("cpu_fam= %s\n", cpu_fam)};next;}
      if (arr[1]=="Vendor ID"  || arr[1]=="vendor_id") {cpu_vnd=arr[2];if(vrb==1){printf("cpu_vnd= %s\n", cpu_vnd)};next;}
      if (arr[1]=="Model"      || arr[1]=="model") { cpu_mod=arr[2];if(vrb==1){printf("cpu_mod= %s\n", cpu_mod);}next; }
      if (arr[1]=="Model name" || arr[1]=="model name") {
#vendor_id	: AuthenticAMD
#cpu family	: 25
#model		: 1
#model name	: AMD EPYC 7543 32-Core Pro
         cpu_model_name = arr[2]; 
         #if(vrb==1){printf("cpu_model_name= %s\n", cpu_model_name);}
         if(vrb==1){printf("decode_fam_mod(%s, %s, %s, %s)\n", cpu_vnd, cpu_fam, cpu_mod, cpu_model_name) > "/dev/stderr";}
         res=decode_fam_mod(cpu_vnd, cpu_fam, cpu_mod, cpu_model_name);
         printf("%s\n", res);
         if (res != "" && res != unknown) { rc = 0; }
         exit rc;
      }
   }
   END{
    exit rc;
   }
'
RC=$?
exit $RC

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
