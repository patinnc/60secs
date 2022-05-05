#!/bin/bash

#arg 1 (optional) can be "v" to enable verbose mode in output
VRB=${1:0}
NON_KRN=$(ps -ae -o pid=,ppid=,comm= | awk '{ if ($2 != 2) { printf("%s\n", $0);}}')
NUM_CPUS=$(grep -c processor /proc/cpuinfo)
#echo "$0.$LINENO non_kern tasks:"
RESP=$(echo "$NON_KRN" | awk '{printf("%s\n", $1);}' | xargs -n 1 taskset -cp)
AFF_DEF=$(echo "$RESP" |head -1 | awk '{ aff = substr($0, index($0, ":")+2); printf("%s\n", aff); exit(0);}')
echo "aff_def $AFF_DEF"
RESP1=$(echo "$RESP" | awk '
      /:/{
       aff = substr($0, index($0, ":")+2);
       aff_sv = aff;
       gsub(/[,-].*/, "", aff);
       printf("%s %s\n", aff, $0);
     }')
RESP2=$(echo "$RESP1" | sort -nk 1)
NET_IRQS=$(ls -1 /sys/class/net/eth0/device/msi_irqs/ );
PROC_INTS=$(cat /proc/interrupts)
IRQ_CPUS=
SEP=
for i in $NET_IRQS; do
  #printf "irq %s\n" $i
  CPU=$(echo "$PROC_INTS" | awk -v irq="${i}:" '$1 == irq {for (i=2; i < NF; i++) { if ($i != 0) { printf("%s\n", i-2);exit(0);} }}')
  #echo $CPU
  IRQ_CPUS="${IRQ_CPUS}${SEP}${CPU}"
  SEP=" "
done
NVME=$(ls -1 /sys/class/nvme)
SEP=
for i in $NVME; do
  nvme_irqs=$(ls -1 /sys/class/nvme/$i/device/msi_irqs/)
  #echo "nvme dev $i, irqs= $nvme_irqs"
  NVME_CPUS="${NVME_CPUS}${SEP}${i}"
  SEP="|"
  for j in $nvme_irqs; do
    str=$(echo "$PROC_INTS" | awk -v irq="${j}:" '$1 == irq {for (i=2; i < NF; i++) { if ($i != 0) { printf("%s\n", i-2);exit(0);} }}')
    NVME_CPUS="${NVME_CPUS},${str}"
  done
done
echo "nvme_cpus= $NVME_CPUS"
#exit
#ls -l /sys/class/nvme/nvme0/device/msi_irqs/
#exit
#pid 1's current affinity list: 0-95
awk -v nvme_text="$NVME_CPUS" -v irq_cpus="$IRQ_CPUS" -v num_cpus="$NUM_CPUS" -v vrb="$VRB"0 -v def_aff="$AFF_DEF" -v aff_txt="$RESP2" -v pid_txt="$NON_KRN" -v sngl_qt=\' '
function split_aff(aff_str, comm, prt,   beg, end, j, k, crr, drr, n2, n3, aff_i, nw_aff, comm_mx) {
  nw_aff = 0;
  if (!(aff_str in aff_sv_list)) {
    aff_sv_list[aff_str] = ++aff_sv_list_mx;
    aff_sv_lkup[aff_sv_list_mx,"str"] = aff_str;
    aff_sv_lkup[aff_sv_list_mx,"max"] = 0
    nw_aff = 1;
  }
  n2 = split(aff_str, crr, ",");
  delete used_cpus;
  used_cpus_mx = 0;
  aff_i = aff_sv_list[aff_str];
  if (aff_sv_lkup[aff_i,"max"] > 0) {
    used_cpus_mx = aff_sv_lkup[aff_i,"max"];
    for (k=1; k <= used_cpus_mx; k++) { used_cpus[k] = aff_sv_lkup[aff_i,"list", k]; }
  } else {
   for (j=1; j <= n2; j++) {
    n3 = split(crr[j], drr, "-");
    if (n3 == 2) {
      beg = drr[1];
      end = drr[2];
    } else {
      beg = drr[1];
      end = drr[1];
    }
    for (k=beg; k <= end; k++) {
      used_cpus[++used_cpus_mx] = k;
      aff_sv_lkup[aff_i,"list",used_cpus_mx] = k;
    }
    aff_sv_lkup[aff_i,"max"] = used_cpus_mx;
   }
  }
  comm_mx = ++aff_sv_lkup[aff_i,"comm_max"];
  aff_sv_lkup[aff_i,"comm_list", comm_mx] = comm;
  aff_sv_lkup[aff_i,"comm_str"] = aff_sv_lkup[aff_i,"comm_str"]";" comm;
  if (prt == 1 && nw_aff == 1)  {
  printf("input aff= %s, cpus= %s ", aff_str, used_cpus_mx);
  for (k=1; k <= used_cpus_mx; k++) { printf(" %d", used_cpus[k]);}
  printf("\n");
  }
}
  BEGIN{
    #printf("aff_txt:\n%s\n", aff_txt);
    #split_aff(def_aff, "1", 1);
    #exit(0);
    nvme_dev_n = split(nvme_text, nvme_cpus_arr, "|");
    for (i=1; i <= nvme_dev_n; i++) {
      n = split(nvme_cpus_arr[i], arr, ",");
      nvme_list[i] = arr[1];
      for (j=2; j <= n; j++) {
        nvme_cpus[i,j-1] = arr[j];
      }
      nvme_list_mx[i] = n-1;
      printf("nvme dev[%d] %s cpus= %d\n", i, nvme_list[i], nvme_list_mx[i]);
    }
    irq_cpus_n = split(irq_cpus, irq_cpus_arr, " ");
    np = split(pid_txt, pid_line, "\n");
    printf("np= %s\n", np);
    for (i=1; i <= np; i++) {
      n = split(pid_line[i], brr, " ");
      pid  = brr[1];
      ppid = brr[2];
      comm = brr[3];
      #printf("pid_line[%d]= pid= %s line= %s\n", i, pid, pid_line[i]);
      if (n > 3) { for (j=4; j <= n; j++) { comm = comm " " brr[j];}}
      if (!(pid in pid_list)) {
        pid_list[pid] = ++pid_mx;
        pid_lkup[pid_mx,"pid"] = pid;
        pid_lkup[pid_mx,"ppid"] = ppid;
        pid_lkup[pid_mx,"comm"] = comm;
	#printf("pid_lkup[%d,pid]= %s, ppid= %s comm= %s\n", i, pid, ppid, comm);
       }
    }
    na = split(aff_txt, aff_line, "\n");
    for (i=1; i <= na; i++) {
      n = split(aff_line[i], brr, " ");
      pid = substr(brr[3], 1, index(brr[3], sngl_qt)-1);
      aff = substr(aff_line[i], index(aff_line[i], ":")+2);
      #printf("pid= %s, aff= %s line= %s\n", pid, aff, aff_arr[i]);
      aff_arr[i,"pid"] = pid;
      aff_arr[i,"aff"] = aff;
      pid_i = pid_list[pid];
      comm = pid_lkup[pid_i,"comm"];
      ppid = pid_lkup[pid_i,"ppid"];
      if (aff != def_aff && ppid != 2) {
        split_aff(aff, comm, 1);
      }
      len_aff = length(aff);
      if (aff_len_mx < len_aff) {
        aff_len_mx = len_aff;
      }
      if (!(pid in aff_list)) {
        aff_list[pid] = ++aff_mx;
	aff_lkup[aff_mx,"pid"] = pid;
	aff_lkup[aff_mx,"aff"] = aff;
	if (pid == "1") { aff_def = aff; }
      }
    }
    printf("na= %s\n", na);
    for (i=1; i <= aff_mx; i++) {
      pid = aff_lkup[i,"pid"];
      if (!(pid in pid_list)) {
        printf("missed lkup of aff pid= %s in pid_list... fix yer code dude\n", pid);
        continue;
      }
      pid_i = pid_list[pid];
      ppid = pid_lkup[pid_i,"ppid"];
      comm = pid_lkup[pid_i,"comm"];
      aff  = aff_lkup[i,"aff"];
      if (aff == aff_def) {
	aff_def_n++;
      } else {
	aff_nondef_n++;
      }
      if (aff != aff_def || vrb > 0) {
        printf("pid= %-6s ppid= %-6s aff= %-*s comm= %s\n", pid, ppid, aff_len_mx, aff_lkup[i,"aff"], comm);
      }
    }
    printf("for processes with ppid != 2: %d have default affinity (%s) and %d have non-default affinity\n", aff_def_n, aff_def, aff_nondef_n);
    for (c=0; c < num_cpus; c++) {
      printf("cpu[%d]: ", c );
      for (i=1; i <= nvme_dev_n; i++) {
        for (j=1; j <= nvme_list_mx[i]; j++) {
          if (nvme_cpus[i,j] == c) { printf("%s;", nvme_list[i]); break;}
        }
      }
      for (i=1; i <= irq_cpus_n; i++) {
        if (irq_cpus_arr[i] == c) { printf("NIC_IRQ;"); break;}
      }
      for (i=1; i <= aff_sv_list_mx; i++) {
        n2 = aff_sv_lkup[i,"max"];
        for(j=1; j <= n2; j++) {
          k = aff_sv_lkup[i,"list",j];
          if (k == c) {
            printf("; %s", aff_sv_lkup[i,"comm_str"])
            break;
          }
        }
      }
      printf("\n");
    }
    exit(0);
  }' 
#ps -ae -o pid= | xargs -n 1 taskset -cp

