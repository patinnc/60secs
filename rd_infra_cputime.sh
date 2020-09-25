#!/bin/bash

#arg1 is infra_cputime.txt filename
VERBOSE=0

while getopts "hvf:n:o:O:S:" opt; do
  case ${opt} in
    f )
      IN_FL=$OPTARG
      ;;
    o )
      OUT_FL=$OPTARG
      ;;
    n )
      NUM_CPUS=$OPTARG
      ;;
    O )
      OPTIONS=$OPTARG
      ;;
    S )
      SUM_FILE=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 read infra_cputime.txt file"
      echo "Usage: $0 [ -v ] -f input_file [ -o out_file ] [ -n num_cpus ] [ -S sum_file ]"
      echo "   -f input_file  like infra_cputime.txt"
      echo "   -o out_file    assumed to be input_file with .tsv appended"
      echo "   -n num_cpus    number of cpus on the server"
      echo "   -S sum_file    summary file"
      echo "   -v verbose mode"
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument. cmdline= ${@}" 1>&2
      exit 1
      ;;
    \? )
      echo "Invalid option: $OPTARG, cmdline= ${@} " 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

#IN_FL=$1


if [ "$IN_FL" == "" ]; then
  echo "must pass -i input_file where the input filename (path_to/infra_cputime.txt)"
  exit 1
fi

if [ ! -e "$IN_FL" ]; then
  echo "can't find arg1 file $IN_FL"
  exit 1
fi
if [ "$OUT_FL" == "" ]; then
  OUT_FL="${IN_FL}.tsv"
fi
#NUM_CPUS=$2

awk -v num_cpus="$NUM_CPUS" -v sum_file="$SUM_FILE" -v ofile="$OUT_FL" '
  BEGIN {
   num_cpus += 0;
   ;
  }
  /^__date__/ {
    ++mx;
    dt[mx] = $2;
    #delete pid_hsh;
    #printf("mx= %d\n", mx);
    dt_diff = 0.0;
    if (mx > 1) {
      dt_diff = dt[mx] - dt[mx-1];
    }
    next;
  }
  /^__uptime__/ {
    ++idle_mx;
    idle_dt[idle_mx] = $2;
    idle_dt_diff = 0.0;
    if (idle_mx > 1) {
      idle_dt_diff = idle_dt[idle_mx] - idle_dt[idle_mx-1];
    }
    getline;
    up = $1;
    id = $2;
    if (idle_dt_diff > 0.0) {
      uval = (up - up_prev)/idle_dt_diff;
      ival = (id - id_prev)/idle_dt_diff;
    } else {
      uval = 0.0;
      ival = 0.0;
    }
    if (num_cpus > 0) {
      uval *= num_cpus;
    }
    uptm[idle_mx] = uval;
    idle[idle_mx] = ival;
    uptm_tot += uval;
    idle_tot += ival;
    up_prev = up;
    id_prev = id;
    next;
  }
  {
    if (mx == 0 || NF == 0) {
      next;
    }
    if ($1 == "PID" && $2 == "TTY") {
      next;
    }
    pid  = $1;
    tmi  = $3;
    proc = $4;
    if (!(pid in pid_list)) {
       pid_list[pid] = ++pid_mx;
       pid_lkup[pid_mx] = pid;
    }
    pid_i = pid_list[pid];
    first_tm_proc = 0;
    if (!(proc in proc_list)) {
       proc_list[proc] = ++proc_mx;
       proc_lkup[proc_mx] = proc;
    }
    proc_i = proc_list[proc];
    pid_proc = pid "," proc;
    if (!(pid_proc in pid_proc_list)) {
       pid_proc_list[pid_proc] = ++pid_prod_mx;
       pid_proc_lkup[pid_proc_mx] = pid_proc;
       pid_proc_prev[pid_proc_mx] = 0;
       first_tm_proc = 1;
    }
    pp_i = pid_proc_list[pid_proc];
    if (pid_prev[pid_i,"proc"] != proc) {
       pid_prev[pid_i,"secs"] = 0;
       first_tm_proc = 1;
    }
    secs_prev = pid_prev[pid_i,"secs"];
    dy_i = index(tmi, "-");
    days = 0;
    tm = tmi;
    #printf("tm= %s\n", tmi);
    if (dy_i > 0) {
      days = substr(tm, 1, dy_i-1);
      tm = substr(tm, dy_i+1, length(tm));
      #printf("tmi= %s, days= %s\n", tm, days);
    }
    n = split(tm, arr, ":");
    secs = days * 24 * 3600 + (arr[1]+0)*3600 + (arr[2]+0)*60 + arr[3]+0;
    #printf("tm= %s, secs= %d,  days= %s, hrs= %s, min= %s, secs= %s\n", tm, secs, days, arr[1], arr[2], arr[3]);
    if (first_tm_proc == 1) {
      secs_prev = secs;
    }
    if (dt_diff > 0.0) {
      sv[mx, proc_i] += (secs - secs_prev)/dt_diff;
      tot[proc_i] += (secs - secs_prev)/dt_diff;
    }
    pid_prev[pid_i,"secs"] = secs
    pid_prev[pid_i,"proc"] = proc;
#  5655 ?        6-09:01:27 subd
#  5661 ?        00:59:29 java
#  5744 ?        4-04:15:10 auditbeat
#  6260 ?        2-13:33:14 python2.7
# 11560 ?        3-00:00:43 connmon-agent
# 11770 ?        15-15:29:40 m3collector
  }
function tot_compare(i1, v1, i2, v2,    l, r)
{
    m1 = tot[i1];
    m2 = tot[i2];
    if (m2 < m1)
        return -1
    else if (m1 == m2)
        return 0
    else
        return 1
}
  END {
    #ofile="tmp.tsv";
    if (idle_mx > 0) {
      proc = "idle";
      proc_list[proc] = ++proc_mx;
      proc_lkup[proc_mx] = proc;
      tot[proc_mx] = idle_tot;
      idle_idx = proc_mx;
      sum = 0.0;
      for (i=1; i < proc_mx; i++) {
         sum += tot[i];
      }
      # idle_tot += ival;
      if (num_cpus > 0) {
        busy = uptm_tot - idle_tot - sum;
        proc = "__other_busy__";
        proc_list[proc] = ++proc_mx;
        proc_lkup[proc_mx] = proc;
        tot[proc_mx] = busy;
        busy_idx = proc_mx;
      }
    }
    for(i=1; i <= proc_mx; i++) {
      idx[i] = i;
    }
    asorti(idx, res_i, "tot_compare")
    trow = -1;
#title   perf stat       sheet   perf stat       type    scatter_straight
#hdrs    4       5       -1      31      1
#epoch   ts      rel_ts  interval
    trow++;
    printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "infra procs cpus", "infra procs") > ofile;
    trow++;
    printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, proc_mx+1, 1) > ofile;
    printf("proc_mx= %d\n", proc_mx);
    printf("epoch\tts") > ofile
    for(i=1; i <= proc_mx; i++) {
      j = res_i[i];
      printf("\t%s", proc_lkup[j]) > ofile;
    }
    printf("\n") > ofile;
    trow++;
    for(k=1; k <= mx; k++) {
      printf("%s\t%d", dt[k], (k > 1 ? dt[k]-dt[1] : 0)) > ofile;
      sum = 0.0;
      for(i=1; i < idle_idx; i++) {
         sum += sv[k,i];
      }
      sv[k,idle_idx] = idle[k];
      if (num_cpus > 0) {
        i = idle_idx+1;
        busy = uptm[k] - idle[k] - sum;
        sv[k,i] = busy;
      }
      for(i=1; i <= proc_mx; i++) {
        j = res_i[i];
        printf("\t%.3f", sv[k,j]) > ofile;
      }
      printf("\n") > ofile;
      trow++;
    }
    trow++;
    printf("\n") > ofile;
    trow++;
    printf("title\t%s\tsheet\t%s\ttype\tcolumn\n", "top infra procs cpus", "infra procs") > ofile;
    trow++;
    printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 1, -1, 1, 0) > ofile;
    trow++;
    printf("process\tcpu_secs\n") > ofile;
    for(i=1; i <= proc_mx; i++) {
      j = res_i[i];
      trow++;
      printf("%s\t%.3f\n", proc_lkup[j], tot[j]) > ofile;
    }
    if (sum_file != "") {
      printf("-------------sum_file= %s, proc_mx= %d\n", sum_file, proc_mx) > "/dev/stderr";
      printf("sum_file= %s\n", sum_file);
      for(i=1; i <= proc_mx; i++) {
         j = res_i[i];
         printf("infra_procs\tinfra procs cpusecs\t%.3f\t%s\n", tot[j], proc_lkup[j]) >> sum_file;
      }
      close(sum_file);
      #printf("%f\n", 1.0/0.0); # force an error
    }

  }
  ' $IN_FL
  RC=$?
exit $RC

