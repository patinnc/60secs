#!/bin/bash

#arg 1 (optional) can be "v" to enable verbose mode in output
VRB=${1:0}
NON_KRN=$(ps -ae -o pid=,ppid=,comm= | awk '{ if ($2 != 2) { printf("%s\n", $0);}}')
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
#pid 1's current affinity list: 0-95
awk -v vrb="$VRB"0 -v def_aff="$AFF_DEF" -v aff_txt="$RESP2" -v pid_txt="$NON_KRN" -v sngl_qt=\' '
  BEGIN{
    #printf("aff_txt:\n%s\n", aff_txt);
    na = split(aff_txt, aff_line, "\n");
    for (i=1; i <= na; i++) {
      n = split(aff_line[i], brr, " ");
      pid = substr(brr[3], 1, index(brr[3], sngl_qt)-1);
      aff = substr(aff_line[i], index(aff_line[i], ":")+2);
      #printf("pid= %s, aff= %s line= %s\n", pid, aff, aff_arr[i]);
      aff_arr[i,"pid"] = pid;
      aff_arr[i,"aff"] = aff;
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
    for (i=1; i <= aff_mx; i++) {
      pid = aff_lkup[i,"pid"];
      if (!(pid in pid_list)) {
        printf("missed lkup of aff pid= %s in pid_list... fix yer code dude\n", pid);
        continue;
      }
      pid_idx = pid_list[pid];
      ppid = pid_lkup[pid_idx,"ppid"];
      comm = pid_lkup[pid_idx,"comm"];
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
    exit(0);
  }' 
#ps -ae -o pid= | xargs -n 1 taskset -cp

