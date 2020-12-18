#!/bin/bash

cat /proc/cpuinfo | gawk '
   BEGIN{vrb=0;}
   function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
   function rtrim(s) { sub(/[ \t\r\n,]+$/, "", s); return s }
   function trim(s) { return rtrim(ltrim(s)); }
   function decode_fam_mod(vndor, fam, mod, cpu_model_name) {
      if (vndor == "GenuineIntel") {
        # cascade lake 2nd gen stuff from https://www.intel.com/content/www/us/en/products/docs/processors/xeon/2nd-gen-xeon-scalable-spec-update.html
        # 2nd gen xeon scalable cpus: cascade lake sku is 82xx, 62xx, 52xx, 42xx 32xx W-32xx  from https://www.intel.com/content/www/us/en/products/docs/processors/xeon/2nd-gen-xeon-scalable-spec-update.html
        # skylake 1st gen stuff from https://www.intel.com/content/www/us/en/processors/xeon/scalable/xeon-scalable-spec-update.html
        # 1st gen xeon scalable cpus: 81xx, 61xx, 51xx, 81xxT, 61xxT 81xxF, 61xxF, 51xx, 41xx, 31xx, 51xxT 41xxT, 51xx7, k
        
        # cpuid tables from https://en.wikichip.org/wiki/intel/cpuid
        dcd[1,1]="Ice Lake";  dcd[1,2]="Family 6 Model 108";
        dcd[2,1]="Ice Lake";  dcd[2,2]="Family 6 Model 106";
        dcd[3,1]="Cooper Lake/Cascade Lake/Skylake";  dcd[3,2]="Family 6 Model 85";
        dcd[4,1]="Broadwell";  dcd[4,2]="Family 6 Model 79";
        dcd[5,1]="Broadwell";  dcd[5,2]="Family 6 Model 86";
        dcd[6,1]="Haswell";  dcd[6,2]="Family 6 Model 63";
        dcd[7,1]="Ivy Bridge";  dcd[7,2]="Family 6 Model 62";
        dcd[8,1]="Sandy Bridge";  dcd[8,2]="Family 6 Model 45";
        dcd[9,1]="Westmere";  dcd[9,2]="Family 6 Model 44";
        dcd[10,1]="EX";  dcd[10,2]="Family 6 Model 47";
        dcd[11,1]="Nehalem";  dcd[11,2]="Family 6 Model 46";
        dcd[12,1]="Lynnfield";  dcd[12,2]="Family 6 Model 30";
        dcd[13,1]="Bloomfield, EP, WS";  dcd[13,2]="Family 6 Model 26";
        dcd[14,1]="Penryn";  dcd[14,2]="Family 6 Model 29";
        dcd[15,1]="Harpertown, QC, Wolfdale, Yorkfield";  dcd[15,2]="Family 6 Model 23";
        str = "Family " fam " Model " mod;
        res=" ";
        for(k=1;k <=15;k++) {
           if (dcd[k,2] == str) {
              res=dcd[k,1];break;
           }
        }
        if (k==3) { # so cooper/cascade/sky
           if (match(cpu_model_name, / [86543]2[0-9][0-9]/) > 0) { res="Cascade Lake"}
           else if (match(cpu_model_name, / [86543]1[0-9][0-9]/) > 0) { res="Skylake"}
        }
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
       
       dcd[1,1]="Zen2 Rome";           dcd[1,2]="Family 23 Model 32-47"; dcd[1,3]=23; dcd[1,4]=32;  dcd[1,5]=47;
       dcd[2,1]="Zen2 Matisse";        dcd[2,2]="Family 23 Model 113";   dcd[2,3]=23; dcd[2,4]=113; dcd[2,5]=113;
       dcd[3,1]="Zen2 Castle Peak";    dcd[3,2]="Family 23 Model 49";    dcd[3,3]=23; dcd[3,4]=49;  dcd[3,5]=49;
       dcd[4,1]="Zen+ Picasso";        dcd[4,2]="Family 23 Model 24";    dcd[4,3]=23; dcd[4,4]=24;  dcd[4,5]=24;
       dcd[5,1]="Zen+ Pinnacle Ridge"; dcd[5,2]="Family 23 Model 8";     dcd[5,3]=23; dcd[5,4]=8;   dcd[5,5]=8;
       dcd[6,1]="Zen Raven Ridge";     dcd[6,2]="Family 23 Model 17";    dcd[6,3]=23; dcd[6,4]=17;  dcd[6,5]=17;
       dcd[7,1]="Zen Naples/Whitehaven/Summit Ridge/Snowy Owl";
       dcd[7,2]="Family 23 Model 1";    dcd[7,3]=23; dcd[7,4]=1;  dcd[7,5]=1;
       dcd[8,1]="Zen3 Milan";          dcd[8,2]="Family 25 Model 1";    dcd[8,3]=25; dcd[8,4]=1;  dcd[8,5]=1;
       str = "Family " fam " Model " mod;
       res=" ";
       for(k=1; k <= 8; k++) {
         if (dcd[k,3] == fam && dcd[k,4] <= mod && mod <= dcd[k,5] ) {
           res=dcd[k,1];break;
         }
       }
       return res;
     }
   }
   {
      if (vrb==1) {printf("%s\n", $0);}
      n=split($0, arr, ":");
      arr[1]=trim(arr[1]);
      arr[2]=trim(arr[2]);
      if (vrb==1) {printf("1=_%s_, a1=_%s_ a2= %s\n", $1, arr[1], arr[2]);}
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
echo "$NMS" | awk -v lkfor="$STR" '{n=split($0,arr,"\t"); printf("%s\t%s\n", arr[1], arr[n]); }'
nm=`echo "$NMS" | awk -v lkfor="$STR" '{if (index($0, lkfor) > 0) {n=split($0,arr,"\t"); printf("%s\n", arr[1]); }}'`
echo "$nm"

#echo "$NMS"
