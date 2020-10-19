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
      echo "   -O options     comma separated list of options. No spaces"
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
#PID RSS    VSZ     TIME COMMAND

awk -v options="$OPTIONS" -v num_cpus="$NUM_CPUS" -v sum_file="$SUM_FILE" -v ofile="$OUT_FL" '
  BEGIN {
   num_cpus += 0;
   col_pid = -1;
   col_rss = -1;
   col_vsz = -1;
   col_tm  = -1;
   col_cmd = -1;
   use_top_pct_cpu = 0;
   if (index(options, "%cpu_like_top") > 0) {
     use_top_pct_cpu = 1;
   }
   printf("use_top_pct_cpu= %d, options= \"%s\"\n", use_top_pct_cpu, options) > "/dev/stderr";
  }
  /^__ps_ef_beg__ /{
    # UID         PID   PPID  C STIME TTY          TIME CMD
    getline;
    cmd_col = index($0, "CMD");
    cmd_idx = NF;
    for (i=1; i <= NF; i++) {
       ps_ef_list[$(i)] = ++ps_ef_mx;
       ps_ef_lkup[ps_ef_mx] = $(i);
    }
    while ( getline  > 0) {
      if ($0 == "") {
         next;
      } else {
        ++ps_ef_lines_mx;
        for (i=1; i < cmd_idx; i++) {
          ps_ef_lines[ps_ef_lines_mx,i] = $(i);
          #printf("ps_ef_line[%d,%d]= %s\n", ps_ef_lines_mx, i, $(i));
        }
        ps_ef_lines[ps_ef_lines_mx,cmd_idx] = substr($0, cmd_col, length($0));
        #printf("ps_ef_line[%d,%d]= %s\n", ps_ef_lines_mx, cmd_idx, ps_ef_lines[ps_ef_lines_mx,cmd_idx]);
      }
    }
  }
  /^__docker_ps__ /{
    docker_dt[++docker_mx] = $2;
    docker_lns[docker_mx] = 0;
    k_infra = 0;
    k_serv  = 0;
    k_other = 0;
    while ( getline  > 0) {
      if ($0 == "" || (length($1) > 2 && substr($1, 1, 2) == "__")) {
        break;
      }
      docker_lns[docker_mx]++;
      j = docker_lns[docker_mx];
      n = split($0, arr, "\t");
      docker_lines[j,docker_mx,0] = n;
      for (i=1; i <= n; i++) {
        docker_lines[docker_mx,j,i] = arr[i];
        if (n == 4 && i == 2) {
           if (index(arr[i], "uber-usi") > 0) {
              k_serv++;
           } else if (index(arr[i], "uber-system") > 0) {
              k_infra++;
           } else {
              k_other++;
           }
        }
      }
    }
    dckr_hdr_mx = 0;
    dckr_hdr[++dckr_hdr_mx] = "infra";
    dckr_hdr[++dckr_hdr_mx] = "service";
    dckr_hdr[++dckr_hdr_mx] = "other";
    docker_typ[docker_mx, 1] = k_infra;
    docker_typ[docker_mx, 2] = k_serv;
    docker_typ[docker_mx, 3] = k_other;
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
    sv_uptm[idle_mx] = up;
    sv_idle[idle_mx] = id;
    uptm[idle_mx] = uval;
    idle[idle_mx] = ival;
    uptm_tot += uval;
    idle_tot += ival;
    up_prev = up;
    id_prev = id;
    next;
  }
  /^__net_snmp_udp__/ {
    ++net_mx;
    net_dt[net_mx] = $2;
    net_dt_diff = 0.0;
    if (net_mx > 1) {
      net_dt_diff = net_dt[net_mx] - net_dt[net_mx-1];
    }
    getline;
    if ($1 == "Tcp:") {
      tcp_hdrs_mx = split($0, arr);
      for (i=2; i <= tcp_hdrs_mx; i++) {
        tcp_hdrs[i-1] = arr[i];
      }
      getline;
      n = split($0, arr);
      for (i=2; i <= tcp_hdrs_mx; i++) {
        tcp[net_mx,i-1] = arr[i];
      }
      getline;
    }
    if ($1 == "Udp:") {
      udp_hdrs_mx = split($0, arr);
      for (i=2; i <= udp_hdrs_mx; i++) {
        udp_hdrs[i-1] = arr[i];
      }
      getline;
      n = split($0, arr);
      for (i=2; i <= udp_hdrs_mx; i++) {
        udp[net_mx,i-1] = arr[i];
      }
    }
    next;
  }
#__net_snmp_udp__ 1602432740 1602432780
#Tcp: RtoAlgorithm RtoMin RtoMax MaxConn ActiveOpens PassiveOpens AttemptFails EstabResets CurrEstab InSegs OutSegs RetransSegs InErrs OutRsts InCsumErrors
#Tcp: 1 200 120000 -1 521191991 454317201 51842064 362196675 22957 91893628805 206234253530 24434738 187 251797531 0
#Udp: InDatagrams NoPorts InErrors OutDatagrams RcvbufErrors SndbufErrors InCsumErrors IgnoredMulti
#Udp: 25821967258 6786602 322210586 26150968358 322210586 0 0 7287

  /^__date__/ {
    ++mx;
    dt[mx] = $2;
    #delete pid_hsh;
    #printf("mx= %d\n", mx);
    dt_diff = 0.0;
    if (mx > 1) {
      dt_diff = dt[mx] - dt[mx-1];
    }
    #printf("got __date = %s\n", $0);
    getline;
    if ($1 == "PID") {
      #PID RSS    VSZ     TIME COMMAND
      for(i=1; i <= NF; i++) {
        if ($(i) == "PID") { col_pid = i; continue; }
        if ($(i) == "RSS") { col_rss = i; continue; }
        if ($(i) == "VSZ") { col_vsz = i; continue; }
        if ($(i) == "TIME") { col_tm = i; continue; }
        if ($(i) == "COMMAND") { col_cmd = i; continue; }
        if ($(i) == "CMD") { col_cmd = i; continue; }
      }
    } else {
      # not sure what the format of the data is in case
      next;
    }
    while ( getline  > 0) {
      if ($0 == "") {
         next;
      } else {
    pid  = $(col_pid);
    tmi  = $(col_tm);
    proc = $(col_cmd);
    if (col_rss != -1) {
      rss  = $(col_rss);
    }
    if (col_vsz != -1) {
      vsz  = $(col_vsz);
    }
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
      if (col_rss != -1) {
        sv_rss[mx, proc_i] += rss;
      }
      if (col_vsz != -1) {
        sv_vsz[mx, proc_i] += vsz;
      }
      tot[proc_i] += (secs - secs_prev);
      tot_n[proc_i]++;
    }
    pid_prev[pid_i,"secs"] = secs
    pid_prev[pid_i,"proc"] = proc;
    }
    }
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
      elap_tm = sv_uptm[idle_mx]-sv_uptm[1];
      sum = 0.0;
      for (i=1; i <= proc_mx; i++) {
         tot[i] /= elap_tm;
         sum += tot[i];
      }
      proc = "idle";
      proc_list[proc] = ++proc_mx;
      proc_lkup[proc_mx] = proc;
      tot[proc_mx] = (sv_idle[idle_mx]-sv_idle[1])/elap_tm;
      printf("idle tot[proc_mx](%s) = (sv_idle[idle_mx](%s)-sv_idle[1](%s))/(sv_uptm[idle_mx](%s)-sv_uptm[1](%s)(%s), sum= %s\n",
         tot[proc_mx], sv_idle[idle_mx],sv_idle[1],sv_uptm[idle_mx],sv_uptm[1], elap_tm, sum);
      idle_idx = proc_mx;
      tot_n[proc_mx] = idle_mx;
      # idle_tot += ival;
      if (num_cpus > 0) {
        busy = num_cpus - tot[idle_idx] - sum;
        proc = "__other_busy__";
        printf("%s cpus= %s\n", proc, busy);
        proc_list[proc] = ++proc_mx;
        proc_lkup[proc_mx] = proc;
        tot[proc_mx] = busy;
        tot_n[proc_mx] = idle_mx;
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
    if ( use_top_pct_cpu == 0) {
      str = "infra procs cpus (1==1cpu_busy)";
    } else {
      str = "infra procs %cpus (100=1cpu_busy)";
    }
    printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", str, "infra procs") > ofile;
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
    fctr = 1.0;
    if ( use_top_pct_cpu == 1) {
      fctr = 100.0;
    }
    for(k=2; k <= mx; k++) {
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
        printf("\t%.3f", fctr*sv[k,j]) > ofile;
      }
      printf("\n") > ofile;
      trow++;
    }
    trow++;
    printf("\n") > ofile;
    if (sum_file != "") {
      printf("-------------sum_file= %s, proc_mx= %d\n", sum_file, proc_mx) > "/dev/stderr";
      printf("sum_file= %s\n", sum_file);
      for(i=1; i <= proc_mx; i++) {
         j = res_i[i];
         if ( use_top_pct_cpu == 0) {
           printf("infra_procs\tinfra procs cpusecs\t%.3f\t%s\n", tot[j], proc_lkup[j]) >> sum_file;
         } else {
           v = 100.0 * tot[j];
           printf("infra_procs\tinfra procs %%cpu\t%.3f\t%s\n", v, proc_lkup[j]) >> sum_file;
         }
      }
      #close(sum_file);
      #printf("%f\n", 1.0/0.0); # force an error
    }
    if (docker_mx > 0) {
      trow++;
      printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "docker containers", "infra procs") > ofile;
      trow++;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, 2+dckr_hdr_mx, 1) > ofile;
      printf("net_mx= %d\n", net_mx);
      cols = 3
      printf("epoch\tts") > ofile
      for(i=1; i <= dckr_hdr_mx; i++) {
        printf("\t%s", dckr_hdr[i]) > ofile;
      }
      printf("\n") > ofile;
      trow++;
      dckr_n = 0;
      for(k=2; k <= docker_mx; k++) {
        printf("%s\t%d", docker_dt[k], docker_dt[k]-docker_dt[1]) > ofile;
        dckr_n++;
        for(i=1; i <= dckr_hdr_mx; i++) {
          printf("\t%d", docker_typ[k,i]) > ofile;
          dckr_sum[i] += docker_typ[k,i];
          dckr_tot    += docker_typ[k,i];
        }
        printf("\n") > ofile;
        trow++;
      }
      trow++;
      printf("\n") > ofile;
      if (sum_file != "") {
         avg = dckr_tot/dckr_n;
         printf("infra_procs\tcontainers avg\t%.3f\t%s\n", avg, "total") >> sum_file;
         for(i=1; i <= dckr_hdr_mx; i++) {
           avg = dckr_sum[i]/dckr_n;
           printf("infra_procs\tcontainers avg\t%.3f\t%s\n", avg, dckr_hdr[i]) >> sum_file;
         }
      }
    }
    if (tcp_hdrs_mx > 0 && net_mx > 0) {
      trow++;
      printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "infra TCP", "infra procs") > ofile;
      trow++;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, tcp_hdrs_mx+1, 1) > ofile;
      printf("net_mx= %d\n", net_mx);
      printf("epoch\tts") > ofile
      for(i=1; i < tcp_hdrs_mx; i++) {
        printf("\t%s", tcp_hdrs[i]) > ofile;
      }
      printf("\n") > ofile;
      trow++;
      for(k=2; k <= net_mx; k++) {
        printf("%s\t%d", net_dt[k], net_dt[k]-net_dt[1]) > ofile;
        for(i=1; i <= tcp_hdrs_mx; i++) {
          dff = tcp[k,i]-tcp[k-1,i];
          printf("\t%.0f", dff) > ofile;
        }
        printf("\n") > ofile;
        trow++;
      }
      trow++;
      printf("\n") > ofile;
      if (sum_file != "") {
         dff = net_dt[net_mx]-net_dt[1];
         for(i=1; i < tcp_hdrs_mx; i++) {
           printf("infra_procs\tinfra TCP\t%.3f\t%s/sec\n", (tcp[net_mx,i]-tcp[1,i])/dff, tcp_hdrs[i]) >> sum_file;
         }
      }
    }
    if (udp_hdrs_mx > 0 && net_mx > 0) {
      trow++;
      printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "infra UDP", "infra procs") > ofile;
      trow++;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, udp_hdrs_mx+1, 1) > ofile;
      printf("net_mx= %d\n", net_mx);
      printf("epoch\tts") > ofile
      for(i=1; i < udp_hdrs_mx; i++) {
        printf("\t%s", udp_hdrs[i]) > ofile;
      }
      printf("\n") > ofile;
      trow++;
      for(k=2; k <= net_mx; k++) {
        printf("%s\t%d", net_dt[k], net_dt[k]-net_dt[1]) > ofile;
        for(i=1; i <= udp_hdrs_mx; i++) {
          dff = udp[k,i]-udp[k-1,i];
          printf("\t%.0f", dff) > ofile;
        }
        printf("\n") > ofile;
        trow++;
      }
      trow++;
      printf("\n") > ofile;
      if (sum_file != "") {
         dff = net_dt[net_mx]-net_dt[1];
         for(i=1; i < udp_hdrs_mx; i++) {
           printf("infra_procs\tinfra UDP\t%.3f\t%s/sec\n", (udp[net_mx,i]-udp[1,i])/dff, udp_hdrs[i]) >> sum_file;
         }
      }
    }
    if (col_rss != -1) {
      trow++;
      printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "infra procs rss mem (MBs)", "infra procs") > ofile;
      trow++;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, proc_mx+1, 1) > ofile;
      printf("proc_mx= %d\n", proc_mx);
      printf("epoch\tts") > ofile
      for(i=1; i <= proc_mx; i++) {
        j = res_i[i];
        printf("\t%s", proc_lkup[j]) > ofile;
        rss_sum[j] = 0;
        rss_n[j] = 0;
      }
      printf("\n") > ofile;
      trow++;
      for(k=1; k <= mx; k++) {
        printf("%s\t%d", dt[k], (k > 1 ? dt[k]-dt[1] : 0)) > ofile;
        for(i=1; i <= proc_mx; i++) {
          j = res_i[i];
          printf("\t%.3f", sv_rss[k,j]/1024.0) > ofile;
          rss_sum[j] += sv_rss[k,j];
          rss_n[j]++;
        }
        printf("\n") > ofile;
        trow++;
      }
      trow++;
      printf("\n") > ofile;
      if (sum_file != "") {
        for(i=1; i <= proc_mx; i++) {
          j = res_i[i];
          avg = 0.0;
          if (rss_n[j] > 0) {
            avg = rss_sum[j]/rss_n[j];
          }
          printf("infra_procs\trss avg MBs\t%.3f\t%s\n", avg/1024.0, proc_lkup[j]) >> sum_file;
         }
      }
    }
    if (col_vsz != -1) {
      trow++;
      printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "infra procs virt mem (MBs)", "infra procs") > ofile;
      trow++;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, proc_mx+1, 1) > ofile;
      printf("proc_mx= %d\n", proc_mx);
      printf("epoch\tts") > ofile
      for(i=1; i <= proc_mx; i++) {
        j = res_i[i];
        printf("\t%s", proc_lkup[j]) > ofile;
        vsz_sum[j] = 0;
        vsz_n[j] = 0;
      }
      printf("\n") > ofile;
      trow++;
      for(k=1; k <= mx; k++) {
        printf("%s\t%d", dt[k], (k > 1 ? dt[k]-dt[1] : 0)) > ofile;
        for(i=1; i <= proc_mx; i++) {
          j = res_i[i];
          printf("\t%.3f", sv_vsz[k,j]/1024.0) > ofile;
          vsz_sum[j] += sv_vsz[k,j];
          vsz_n[j]++;
        }
        printf("\n") > ofile;
        trow++;
      }
      trow++;
      printf("\n") > ofile;
      if (sum_file != "") {
        for(i=1; i <= proc_mx; i++) {
          j = res_i[i];
          avg = 0.0;
          if (rss_n[j] > 0) {
            avg = vsz_sum[j]/vsz_n[j];
          }
          printf("infra_procs\tvsz avg MBs\t%.3f\t%s\n", avg/1024.0, proc_lkup[j]) >> sum_file;
         }
      }
    }
    trow++;
    if ( use_top_pct_cpu == 0) {
      str = "top infra procs cpus (1=1cpu_busy)";
      str2 = "cpu_secs";
    } else {
      str = "top infra procs avg %cpus (100=1cpu_busy)";
      str2 = "%cpu";
    }
    printf("title\t%s\tsheet\t%s\ttype\tcolumn\n", str, "infra procs") > ofile;
    trow++;
    printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 1, -1, 1, 0) > ofile;
    trow++;
    printf("process\t%s\n", str2) > ofile;
    for(i=1; i <= proc_mx; i++) {
      j = res_i[i];
      trow++;
      v = tot[j];
      fctr = 1.0;
      if ( use_top_pct_cpu == 1) {
        fctr = 100.0;
      }
      v = v * fctr;
      printf("%s\t%.3f\n", proc_lkup[j], v) > ofile;
    }
    if (sum_file != "") {
      close(sum_file);
    }
  }
  ' $IN_FL
  RC=$?
exit $RC

