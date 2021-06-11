@include "read_specint.awk"
@include "rpn.awk"
BEGIN{
    beg=1;
    mx=0
    hdr="";
    fl0=0;
    smp_intrvl=1.0;
    got_result_csv_epoch=0;
    cpu_count=0;
    skt_count=0;
    ht_count=0;
    runs= -1;
    runs_FNM = "___";
    tm_beg_in += 0.0; 
    tm_end_in += 0.0;
    printf("sum_tmam file= %s, tm_beg_in= %f tm_end_in= %f\n", sum_tmam, tm_beg_in, tm_end_in) > "/dev/stderr";
}
function prt_hdr(str, i, hn_list, hn_lkup, NFL) {
     printf("\t%s", str) > NFL;
     ++i;
     hn_list[str] = i;
     hn_lkup[i] = str;
     return i;
}
function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
function rtrim(s) { sub(/[ \t\r\n,]+$/, "", s); return s }
function trim(s) { return rtrim(ltrim(s)); }
#title	mpstat cpu= all
#hdrs	2	1	62	10
#CPU	%usr	%nice	%sys	%iowait	%irq	%soft	%steal	%guest	%gnice	%idle
#all	10.66	10.44	3.84	0.22	0.00	0.13	0.00	0.00	0.00	74.722018

#  Rate Start:   2020-08-04 05:35:25 (1596519325.87119)
#  Rate End:     2020-08-04 05:47:23 (1596520043.99671)
  /^  Rate Start: / {
      FNM=ARGV[ARGIND];
      if(FNM != runs_FNM) {
        runs = -1;
      }
      runs_FNM = FNM;
      ++runs;
      rate_beg=substr($5, 2, length($5)-2);
  }
  /^  Rate End: / {
      rate_end=substr($5, 2, length($5)-2);
  }
  /^ Run .* base refrate ratio=.*, runtime=.*, copies=.*, / {
   # Run 531.deepsjeng_r base refrate ratio=2.40, runtime=477.559603, copies=1, threads=1, power=0.00W, temp=0.00 degC, humidity=0.00%
   if (match(FNM, /CPU2017.[0-9][0-9][0-9].log$/)) {
      bm_mx++;
      bm_arr[bm_mx,"nm"] = $2;
      n = split($5, arr, /[=,]/);
      bm_arr[bm_mx,"score"] = arr[2];
      n = split($6, arr, /[=,]/);
      bm_arr[bm_mx,"runtm"] = arr[2];
      n = split($7, arr, /[=,]/);
      bm_arr[bm_mx,"copies"] = arr[2];
      bm_arr[bm_mx,"runs"] = runs;
      bm_arr[bm_mx,"rate_beg"] = rate_beg;
      bm_arr[bm_mx,"rate_end"] = rate_end;
      #printf("got cpu2017.001.log[%d] bm= %s, ratio= %s, run_tm= %s, copies= %s ln= %s file= %s\n",
      #   bm_mx, bm_arr[bm_mx,"nm"], bm_arr[bm_mx,"score"], bm_arr[bm_mx,"runtm"], bm_arr[bm_mx,"copies"], $0, FNM);
      #exit;
   }
 }
 {
   FNM=ARGV[ARGIND];
   sub(//,"")
   if (index(FNM, "spin.txt") > 0) {
      #work= mem_bw_2rdwr, threads= 1, total perf= 21.244 GB/sec
      if ($1 == "work=" && index($0, ", total perf= ") > 0) {
         spin_work= $2;
         spin_thrds= $4;
         spin_GBpsec= $7;
       printf("got spin_work= %s thrds= %s GB/s= %s\n", spin_work, spin_thrds, spin_GBpsec) > "/dev/stderr";
      }
   }
   if (index(FNM, "result.csv") > 0) {
      if (fl0 == 0) {
       #printf("got result.csv= %s\n", FNM) > "/dev/stderr";
      }
      fl0++;
      #CPU count,12.0,
      #SOCKET count,2,
      #HT count,2,
      if (index($0, "CPU count,") == 1) {
        n = split($0, arr, ",");
        cpu_count=arr[2];
      }
      if (index($0, "SOCKET count,") == 1) {
        n = split($0, arr, ",");
        skt_count=arr[2];
      }
      if (index($0, "HT count,") == 1) {
        n = split($0, arr, ",");
        ht_count=arr[2];
      }
      if (index($0, "Sampling Interval,") == 1) {
        n = split($0, arr, ",");
        smp_intrvl=arr[2];
      }
      # started on Fri Jun  5 23:17:03 2020 EPOCH 1591399023
      if (index($0, "# started on ") == 1) {
        n = split($0, arr, /[ ,]/);
        ts_mon  = $5;
        ts_day  = $6;
        ts_time = $7;
        ts_year = $8;
        ts_epoch = $10;
        printf("ts_epoch= %s for line= %s\n", ts_epoch, $0) > "/dev/stderr";
        got_result_csv_epoch=1;
        next;
        #nextfile;
      }
      if (got_result_csv_epoch == 1 && length($0) > 1) {
        n = split($0, arr, ",");
        res_ts_off = arr[1];
        if (!(res_ts_off in res_ts_list)) {
           res_ts_list[res_ts_off] = ++res_ts_mx;
           res_ts_lkup[res_ts_mx]  = res_ts_off;
           #printf("got result.csv: ts[%d]= %s\n", res_ts_mx, res_ts_off) > "/dev/stderr";
        }
      }
      next;
   }
   if (index(FNM, metric_avg) > 0) {
     if (!(FNM in avg_file_list)) {
        avg_file_list[FNM] = ++avg_file_mx;
        avg_file_lkup[avg_file_mx] = FNM;
        ahdr = $0;
        printf("+++++++avg_hdr= %s\n", ahdr) > "/dev/stderr";
        next;
     }
     avg_file_i = avg_file_list[FNM];
     n = split($0, arr, ",");
     if (!(arr[1] in sv_aln_list)) {
       amx++;
       sv_aln_list[arr[1]] = amx;
       sv_aln_lkup[amx] = arr[1];
     }
     j = sv_aln_list[arr[1]];
     sv_aln_valu[avg_file_i,j] = arr[2];
     sv_aln[avg_file_i,j] = $0;
     printf("+++++++avg_ln[%d,%d]= %s\n", avg_file_i, j, $0) > "/dev/stderr";
     next;
   }
   if (index(FNM, metric_file) > 0) {
     NFL=FNM ".tsv";
     if (hdr == "") {
        hdr = $0;
        metric_file_hdr = $0;
        printf("hdr= %s\n", hdr);
        next;
     } else {
       sv_ln[++mx] = $0;
     }
   }
   next;
   n = split($0, arr, ",");
   for (i=1; i <= NF; i++) {
      if ($i == "average:") {
           if (beg==1) {
              sv[++mx] = "ld_avg_1m\tld_avg_5m\tld_avg_15m"
              #printf("ld_avg_1m\tld_avg_5m\tld_avg_15m\n") > NFL;
              beg=0;
           }
           sv[++mx]=sprintf("%s\t%s\t%s", trim($(i+1)), trim($(i+2)), trim($(i+3)));
           #printf("%s\t%s\t%s\n", trim($(i+1)), trim($(i+2)), trim($(i+3))) > NFL;
           break;
      }
   }
 }
END{
  if (options != "" && index(options, "chart_sheet") == 0) {
    for (i=1; i <= 40; i++) {
     trows++;
     printf("\n") > NFL;
    }
  }
#       kmx  = 1; 
#       kkmx = 0;
#       sample use of eqn 
#       got_rpn_eqn[kmx, ++kkmx, "val"] = 2;
#       got_rpn_eqn[kmx,   kkmx, "opr"] = "push_val";
#       got_rpn_eqn[kmx, ++kkmx, "val"] = 3;
#       got_rpn_eqn[kmx,   kkmx, "opr"] = "push_val";
#       got_rpn_eqn[kmx, ++kkmx, "val"] = "*";
#       got_rpn_eqn[kmx,   kkmx, "opr"] = "oper";
#       got_rpn_eqn[kmx, ++kkmx, "val"] = "b";
#       got_rpn_eqn[kmx,   kkmx, "opr"] = "push_row_val";
#       got_rpn_eqn[kmx, ++kkmx, "val"] = "+";
#       got_rpn_eqn[kmx,   kkmx, "opr"] = "oper";
#       got_rpn_eqn[kmx,      1, "max"] = kkmx;
  
  #GIPS_col_freq = -1;
  #GIPS_col_CPI  = -1;
  CPU_util_col  = -1;
  #L1_data_hit_ratio_mx = 0;
  #L2_data_hit_ratio_mx = 0;
  #L3_data_hit_ratio_mx = 0;
  got_GIPS = 0
  num_cpus = cpu_count * skt_count * ht_count;
  printf("metric_out: num_cpus= %d\n", num_cpus) > "/dev/stderr";
  hn = split(hdr, harr, ",");
  extr_col = 1;

  emx = 0;
  eemx = 0
  kkmx = 0
  eqn_arr[++emx, ++eemx, "lkfor"] = "metric_CPU operating frequency (in GHz)";
  eqn_arr[  emx, ++eemx, "lkfor"] = "metric_CPU utilization %";
  eqn_arr[  emx, ++eemx, "lkfor"] = "metric_CPI";
  eqn_arr[  emx,      1, "max"]   = eemx;
  eqn_arr[  emx,      1, "hdr"]   = "instructions/sec (1e9 instr/sec)";
  eqn_arr[  emx,      1, "use"]   = "rpn";
  got_GIPS = emx;
  got_rpn_eqn[emx, ++kkmx, "val"] = num_cpus;
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 1, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "*";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 2, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "*";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx, ++kkmx, "val"] = 0.01;
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "*";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 3, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "/";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx,      1, "max"] = kkmx;

  eemx = 0
  kkmx = 0
  eqn_arr[++emx, ++eemx, "lkfor"] = "metric_CPI";
  eqn_arr[  emx,      1, "max"]   = eemx;
  eqn_arr[  emx,      1, "hdr"]   = "IPC";
  eqn_arr[  emx,      1, "use"]   = "rpn";
  got_IPC  = emx;
  got_rpn_eqn[emx, ++kkmx, "val"] = 1.0;
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 1, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "/";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx,      1, "max"] = kkmx;

  eemx = 0
  kkmx = 0
  eqn_arr[++emx, ++eemx, "lkfor"] = "metric_CPU operating frequency (in GHz)";
  eqn_arr[  emx, ++eemx, "lkfor"] = "metric_CPU utilization %";
  eqn_arr[  emx,      1, "max"]   = eemx;
  eqn_arr[  emx,      1, "hdr"]   = "cpu-cycles/sec (1e9 cycles/sec)";
  eqn_arr[  emx,      1, "use"]   = "rpn";
  got_rpn_eqn[emx, ++kkmx, "val"] = num_cpus;
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 2, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "*";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";  # num_cpus * %util
  got_rpn_eqn[emx, ++kkmx, "val"] = 0.01;
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "*";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";  # num_cpus * %util * 0.01 so got cpu_secs
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 1, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "*";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper"; # (cycles/sec) * cpu_cpus
  got_rpn_eqn[emx,      1, "max"] = kkmx;

  eemx = 0
  kkmx = 0
  eqn_arr[++emx, ++eemx, "lkfor"] = "metric_L1D demand data read hits per instr";
  eqn_arr[  emx, ++eemx, "lkfor"] = "metric_L1D MPI (includes data+rfo w/ prefetches)";
  eqn_arr[  emx,      1, "max"]   = eemx;
  eqn_arr[  emx,      1, "hdr"]   = "L1 data hit% (hits/(hits+miss))";
  eqn_arr[  emx,      1, "use"]   = "rpn";
  got_rpn_eqn[emx, ++kkmx, "val"] = 100.0;
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 1, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "*";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 1, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 2, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "+";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx, ++kkmx, "val"] = "/";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx,      1, "max"] = kkmx;

  eemx = 0
  kkmx = 0
  eqn_arr[++emx, ++eemx, "lkfor"] = "metric_L2 demand data read hits per instr";
  eqn_arr[  emx, ++eemx, "lkfor"] = "metric_L2 demand data read MPI";
  eqn_arr[  emx,      1, "max"]   = eemx;
  eqn_arr[  emx,      1, "hdr"]   = "L2 data hit% (hits/(hits+miss))";
  eqn_arr[  emx,      1, "use"]   = "rpn";
  got_rpn_eqn[emx, ++kkmx, "val"] = 100.0;
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 1, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "*";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 1, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 2, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "+";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx, ++kkmx, "val"] = "/";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx,      1, "max"] = kkmx;

  eemx = 0
  kkmx = 0
  eqn_arr[++emx, ++eemx, "lkfor"] = "metric_LLC total HITM (per instr)";
  eqn_arr[  emx, ++eemx, "lkfor"] = "metric_LLC total HIT clean line forwards (per instr)"
  eqn_arr[  emx, ++eemx, "lkfor"] = "metric_LLC MPI (includes code+data+rfo w/ prefetches)|metric_LLC MPI";  # alias bteween bdw and cascade lake
  eqn_arr[  emx,      1, "max"]   = eemx;
  eqn_arr[  emx,      1, "hdr"]   = "LLC data hit% (hits/(hits+miss))";
  eqn_arr[  emx,      1, "use"]   = "rpn";
  got_rpn_eqn[emx, ++kkmx, "val"] = 100.0;
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 1, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 2, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "+";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx, ++kkmx, "val"] = "*";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 1, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 2, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "+";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx, ++kkmx, "val"] = eqn_arr[emx, 3, "lkfor"];
  got_rpn_eqn[emx,   kkmx, "opr"] = "push_row_val";
  got_rpn_eqn[emx, ++kkmx, "val"] = "+";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx, ++kkmx, "val"] = "/";
  got_rpn_eqn[emx,   kkmx, "opr"] = "oper";
  got_rpn_eqn[emx,      1, "max"] = kkmx;

  eemx_extra_cols = 0;

  for (i=1; i <= hn; i++) {
     for (j=1; j <= emx; j++) {
        for (k=1; k <= eqn_arr[j, 1, "max"]; k++) {
          #allow alternate names separated by |
          str = eqn_arr[j, k, "lkfor"];
          n = split(str, arr, "|");
          for (kk=1; kk <= n; kk++) {
           if (index(harr[i], arr[kk]) > 0 && eqn_arr[j, k, "col"] == "") {
            # update lkfor with field actually found (in case of alias)
            eqn_arr[j, k, "lkfor"] = arr[kk];
            # update any reference to actual event in got_rpn_eqn
            for (kkj=1; kkj <= got_rpn_eqn[j,1,"max"]; kkj++) {
              if (got_rpn_eqn[j,kkj,"opr"] == "push_row_val" && got_rpn_eqn[j,kkj,"val"] == str) {
                  got_rpn_eqn[j,kkj,"val"] = arr[kk];
              }
            }
            eqn_arr[j, k, "col"] = i;
            eqn_arr[j, 1, "got"]++;
            if (eqn_arr[j, 1, "got"] == eqn_arr[j, 1, "max"]) {
               eemx_extra_cols++;
               eqn_arr[j, 1, "new_col"] = hn + eemx_extra_cols + extr_col;
            }
           }
          }
        }
     }
#     if (index(harr[i], "metric_CPU operating frequency (in GHz)") > 0) {
#        GIPS_col_freq = i+extr_col;
#        got_GIPS++;
#     }
#     if (index(harr[i], "metric_TMAM_Info_CoreIPC") > 0) {
#        GIPS_col_IPC = i+extr_col;
#     }
#     if (index(harr[i], "metric_CPI") > 0) {
#        GIPS_col_CPI = i+extr_col;
#        got_GIPS++;
#     }
     if (index(harr[i], "metric_CPU utilization %") > 0) {
        CPU_util_col = i+extr_col;
     }
#     if (index(harr[i], "metric_L1D demand data read hits per instr") > 0) {
#        L1_data_hit_ratio_mx++;
#        L1_data_hit_ratio_col[1] = i+extr_col;
#     }
#     if (index(harr[i], "metric_L1D MPI (includes data+rfo w/ prefetches)") > 0) {
#        L1_data_hit_ratio_mx++;
#        L1_data_hit_ratio_col[2] = i+extr_col;
#     }
#     if (index(harr[i], "metric_L2 demand data read hits per instr") > 0) {
#        L2_data_hit_ratio_mx++;
#        L2_data_hit_ratio_col[1] = i+extr_col;
#     }
#     if (index(harr[i], "metric_L2 demand data read MPI") > 0) {
#        L2_data_hit_ratio_mx++;
#        L2_data_hit_ratio_col[2] = i+extr_col;
#     }
#     if (index(harr[i], "metric_LLC total HITM (per instr)") > 0) {
#        L3_data_hit_ratio_mx++;
#        L3_data_hit_ratio_col[1] = i+extr_col;
#     }
#     if (index(harr[i], "metric_LLC total HIT clean line forwards (per instr)") > 0) {
#        L3_data_hit_ratio_mx++;
#        L3_data_hit_ratio_col[2] = i+extr_col;
#     }
#     if (index(harr[i], "metric_LLC MPI") > 0) {
#        L3_data_hit_ratio_mx++;
#        L3_data_hit_ratio_col[3] = i+extr_col;
#     }
  }
  for (j=1; j <= emx; j++) {
    printf("eqn_arr[%d,1,\"max\"]= %d, got= %d, eqn= %s\n", j, eqn_arr[j,1,"max"], eqn_arr[j,1,"got"], eqn_arr[j,1,"hdr"]);
  }
  #GIPS_extra_col = 0;
  tot_extra_col = 0;
  #if (got_GIPS == 2) {
  #  GIPS_extra_col = 1;
  #  GIPS_hdr = "Instr/sec (1e9 instr/sec)";
  #  tot_extra_col++;
  #  GIPS_col_num = hn + tot_extra_col + extr_col;
  #}
#  L1_data_hit_ratio_extra_col = 0;
#  if (L1_data_hit_ratio_mx == 2) {
#    L1_data_hit_ratio_extra_col = 1;
#    L1_data_hit_ratio_hdr = "L1 data hit% (hits/(hits+miss))";
#    L1_data_hit_ratio_col_num = hn + 1 + tot_extra_col + extr_col;
#    tot_extra_col++;
#  }
#  L2_data_hit_ratio_extra_col = 0;
#  if (L2_data_hit_ratio_mx == 2) {
#    L2_data_hit_ratio_extra_col = 1;
#    L2_data_hit_ratio_hdr = "L2 data hit% (hits/(hits+miss))";
#    L2_data_hit_ratio_col_num = hn + 1 + tot_extra_col + extr_col;
#    tot_extra_col++;
#  }
#  L3_data_hit_ratio_extra_col = 0;
#  if (L3_data_hit_ratio_mx == 3) {
#    L3_data_hit_ratio_extra_col = 1;
#    L3_data_hit_ratio_hdr = "LLC data hit% (hits/(hits+miss))";
#    L3_data_hit_ratio_col_num = hn + 1 + tot_extra_col + extr_col;
#    tot_extra_col++;
#  }
  for (j=1; j <= emx; j++) {
    if (eqn_arr[j,1,"got"] == eqn_arr[j,1,"max"] && eqn_arr[j,1,"use"] == "rpn") {
       eqn_arr[j,1,"use_col"] = hn + 1 + tot_extra_col + extr_col;
       tot_extra_col++;
    }
  }
  title_pfx = "";
  for (ii=1; ii <= bm_mx; ii++) {
     if (ii==1 || (bm_arr[ii,"nm"] != bm_arr[ii-1,"nm"])) {
       str = bm_arr[ii,"nm"];
       n = split(str, arr, ".");
       if (n == 2) {
         str = arr[2];
       }
       gsub("_r$", "", str);
       title_pfx = title_pfx "" str;
       title_pfx = title_pfx "(" bm_arr[ii,"copies"] ") ";
     }
     title_pfx = title_pfx "" bm_arr[ii,"score"] ", ";
     printf("specint_phase: %s_%s %s %s\n", bm_arr[ii,"nm"], bm_arr[ii,"runs"], bm_arr[ii,"rate_beg"], bm_arr[ii,"rate_end"]) > "/dev/stderr";
  }
  #printf("got GIPS_col_num= %d\n", GIPS_col_num) > "/dev/stderr";
  trows++;
  printf("title\t%sitp_metrics\tsheet\titp_metric\ttype\tscatter_straight\n", title_pfx) > NFL;
  trows++;
  printf("hdrs\t%d\t%d\t%d\t%d\t1\n", trows+1, 3, -1, hn+1+tot_extra_col) > NFL;
  #trows_top = trows;
  printf("\t") > NFL;
  for (i=1; i <= hn; i++) {
     frm = sprintf("=subtotal(101, INDIRECT(ADDRESS(row()+2, column(), 1)):INDIRECT(ADDRESS(row()-1+%d, column(),1)))", mx);
     printf("\t%s", frm) > NFL;
  }
#  if (got_GIPS == 2) {
#     frm = sprintf("=subtotal(101, INDIRECT(ADDRESS(row()+2, column(), 1)):INDIRECT(ADDRESS(row()-1+%d, column(),1)))", mx);
#     printf("\t%s", frm) > NFL;
#  }
#  if (L1_data_hit_ratio_mx == 2) {
#     frm = sprintf("=subtotal(101, INDIRECT(ADDRESS(row()+2, column(), 1)):INDIRECT(ADDRESS(row()-1+%d, column(),1)))", mx);
#     printf("\t%s", frm) > NFL;
#  }
#  if (L2_data_hit_ratio_mx == 2) {
#     frm = sprintf("=subtotal(101, INDIRECT(ADDRESS(row()+2, column(), 1)):INDIRECT(ADDRESS(row()-1+%d, column(),1)))", mx);
#     printf("\t%s", frm) > NFL;
#  }
#  if (L3_data_hit_ratio_mx == 3) {
#     frm = sprintf("=subtotal(101, INDIRECT(ADDRESS(row()+2, column(), 1)):INDIRECT(ADDRESS(row()-1+%d, column(),1)))", mx);
#     printf("\t%s", frm) > NFL;
#  }
  for (j=1; j <= emx; j++) {
    if (eqn_arr[j,1,"got"] == eqn_arr[j,1,"max"] && eqn_arr[j,1,"use"] == "rpn") {
       frm = sprintf("=subtotal(101, INDIRECT(ADDRESS(row()+2, column(), 1)):INDIRECT(ADDRESS(row()-1+%d, column(),1)))", mx);
       printf("\t%s", frm) > NFL;
    }
  }
  printf("\n") > NFL;
  trows++;
  trows_top = trows;
  printf("TS\tts_rel") > NFL;
  mb_mx=0;
  pct_mx=0;
  lat_mx=0;
  ghz_mx=0;
  cpi_mx=0;
  mpi_mx=0;
  pwr_mx=0;
  tmam_mx=0;
  tmam_mx_L1=0;
  doing_L2=0;
  prev_2d = -1;
  prev_lvl="";
  L2_mx=1;
  tmam_hdr_L2[L2_mx] = "";
  for (i=1; i <= hn; i++) {
     printf("\t%s", harr[i]) > NFL;
     hn_list[harr[i]] = i;
     hn_lkup[i] = harr[i];
     str = tolower(harr[i]);
     hdr_cols[harr[i]] = i+2;
     if (index(str, "mb/sec") > 0) {
        mb_arr[++mb_mx] = i+extr_col;
        #printf("MB hdr= %s, mx= %d\n", harr[i], mb_arr[mb_mx]) > "/dev/stderr";
     }
     if (index(str, "%") > 0 && index(str, "tmam") == 0) {
        pct_arr[++pct_mx] = i+extr_col;
     }
     if (index(str, "latency") > 0) {
        lat_arr[++lat_mx] = i+extr_col;
     }
     if (index(str, "ghz") > 0) {
        ghz_arr[++ghz_mx] = i+extr_col;
     }
     if (index(str, "cpi") > 0) {
        cpi_arr[++cpi_mx] = i+extr_col;
     }
     if (index(str, "watts") > 0) {
        pwr_arr[++pwr_mx] = i+extr_col;
     }
     if (index(str, "mpi") > 0 || index(str, "per instr") > 0) {
        mpi_arr[++mpi_mx] = i+extr_col;
     }
     if (index(str, "tmam") > 0 || index(str, "metric_cpu utilization %") > 0) {
        tmam_arr[++tmam_mx] = i+extr_col;
     }
     pos2d = index(str, "tmam_..");
     pos3d = index(str, "tmam_....");
     pos4d = index(str, "tmam_......");
     pos5d = index(str, "tmam_........");
     if (index(str, "tmam") > 0 && pos2d == 0 && index(str, "cycles_both") == 0 && index(str, "coreipc") == 0) {
        tmam_arr_L1[++tmam_mx_L1] = i+extr_col;
     }
     if (doing_L2 == 1 && pos2d == 0) {
        doing_L2 = 0;
        L2_mx++;
        tmam_hdr_L2[L2_mx] = "";
     }
     if (tmam_hdr_L2[L2_mx] == "" && pos2d > 0 && pos3d == 0) {
        tmam_hdr_L2[L2_mx] = prev_str;
        doing_L2=1;
        tmam_mx_L2[L2_mx] = 0;
     }
     if (doing_L2 == 1 && pos2d > 0 && pos3d == 0) {
        ++tmam_mx_L2[L2_mx];
        tmam_arr_L2[L2_mx,tmam_mx_L2[L2_mx]] = i+extr_col;
     }
     prev_str = str;
  }
#  if (got_GIPS == 2) {
#     i = prt_hdr(GIPS_hdr, i, hn_list, hn_lkup, NFL);
#  }
#  if (L1_data_hit_ratio_mx == 2) {
#     i = prt_hdr(L1_data_hit_ratio_hdr, i, hn_list, hn_lkup, NFL);
#  }
#  if (L2_data_hit_ratio_mx == 2) {
#     i = prt_hdr(L2_data_hit_ratio_hdr, i, hn_list, hn_lkup, NFL);
#  }
#  if (L3_data_hit_ratio_mx == 3) {
#     i = prt_hdr(L3_data_hit_ratio_hdr, i, hn_list, hn_lkup, NFL);
#  }
  for (j=1; j <= emx; j++) {
    if (eqn_arr[j,1,"got"] == eqn_arr[j,1,"max"] && eqn_arr[j,1,"use"] == "rpn") {
     i = prt_hdr(eqn_arr[j,1,"hdr"], i, hn_list, hn_lkup, NFL);
    }
  }
  Ihdr_mx = i;
  trows++;
  printf("\n") > NFL;
  mx_cols = 0;
  jv = 0;
  ts_diff = 0.0;
  if (tm_beg_in != 0.0) {
    ts_diff = ts_epoch - tm_beg_in;
    printf("itp_2_tsv.awk: ts_diff = %f, ts_epoch= %f, tm_beg_in= %f, tm_end_in= %f\n", ts_diff, ts_epoch, tm_beg_in, tm_end_in) > "/dev/stderr";
  }
  for (i=1; i <= mx; i++) {
     n = split(sv_ln[i], arr, ",");
     if (mx_cols < n) { mx_cols = n; }
     tm = arr[1]+0.0;
     if (tm in res_ts_lkup) {
       tm_off = res_ts_lkup[tm]+0.0;
     } else {
       printf("missed tm= %s in results.csv\n", tm) > "/dev/stderr";
       tm_off = tm * smp_intrvl;
     }
     use_line = 1;
     tm_cur = ts_epoch + tm_off;
     if ((tm_beg_in != 0.0 && tm_cur < tm_beg_in) || (tm_end_in != 0.0 && tm_cur > tm_end_in)) {
        if (verbose > 0) {
          printf("tmam going to drop line = %d tm_off= %f, tm_beg_in= %f tm_cur= %f, tm_end_in= %f\n", i, tm_off, tm_beg_in, tm_cur, tm_end_in) > "/dev/stderr";
        }
        use_line = 0;
        continue;
     }
     sm_mx += use_line;
      

     printf("%.3f\t%.3f", ts_epoch + tm_off, tm_off+ts_diff) > NFL;
     jv = 0;
     for (j=1; j <= n; j++) {
       val = arr[j]+0.0;
       if ((index(harr[j], "MB/s") > 0 && index(harr[j], "metric_IO_bandwidth_disk_or_network_read") == 0) && val > 1000000.0) {
         val = 500.0;
       }
       if (use_line == 1) {
         sm_arr[j,"sum"] += val;
         sm_arr[j,"n"] += 1;
       }
       ++jv;
       jval_arr[jv] = val;
       printf("\t%s", val) > NFL;
     }
#     frm="";
#     if (got_GIPS == 2 && CPU_util_col > 0 && num_cpus > 0) {
#       frm = sprintf("=%d*0.01*INDIRECT(ADDRESS(row(), column()-%d,2))*(1.0/INDIRECT(ADDRESS(row(), column()-%d, 2)))*INDIRECT(ADDRESS(row(), column()-%d,2))",
#           num_cpus, GIPS_col_num-CPU_util_col, GIPS_col_num-GIPS_col_CPI, GIPS_col_num-GIPS_col_freq);
#       printf("\t%s", frm) > NFL;
#     }
#     if (L1_data_hit_ratio_mx == 2) {
#       cur_col = L1_data_hit_ratio_col_num;
#       hit  = cur_col - L1_data_hit_ratio_col[1];
#       miss = cur_col - L1_data_hit_ratio_col[2];
#       frm = sprintf("=100.0*INDIRECT(ADDRESS(row(), column()-%d,2))/(INDIRECT(ADDRESS(row(), column()-%d, 2)) + INDIRECT(ADDRESS(row(), column()-%d,2)))",
#           hit, miss, hit);
#       printf("\t%s", frm) > NFL;
#     }
#     if (L2_data_hit_ratio_mx == 2) {
#       cur_col = L2_data_hit_ratio_col_num;
#       hit  = cur_col - L2_data_hit_ratio_col[1];
#       miss = cur_col - L2_data_hit_ratio_col[2];
#       frm = sprintf("=100.0*INDIRECT(ADDRESS(row(), column()-%d,2))/(INDIRECT(ADDRESS(row(), column()-%d, 2)) + INDIRECT(ADDRESS(row(), column()-%d,2)))",
#           hit, miss, hit);
#       printf("\t%s", frm) > NFL;
#     }
#     if (L3_data_hit_ratio_mx == 3) {
#       cur_col = L3_data_hit_ratio_col_num;
#       hit1 = cur_col - L3_data_hit_ratio_col[1];
#       hit2 = cur_col - L3_data_hit_ratio_col[2];
#       miss = cur_col - L3_data_hit_ratio_col[3];
#       frm = sprintf("=100.0*(INDIRECT(ADDRESS(row(), column()-%d,2))+INDIRECT(ADDRESS(row(), column()-%d,2)))/(INDIRECT(ADDRESS(row(), column()-%d, 2)) + INDIRECT(ADDRESS(row(), column()-%d, 2)) + INDIRECT(ADDRESS(row(), column()-%d,2)))",
#           hit1, hit2, miss, hit1, hit2);
#       printf("\t%s", frm) > NFL;
#     }
     for (j=1; j <= emx; j++) {
       if (eqn_arr[j,1,"got"] == eqn_arr[j,1,"max"] && eqn_arr[j,1,"use"] == "rpn") {
         val = rpn_rtn(val, j, got_rpn_eqn, jv, hn_lkup, jval_arr);
         eqn_arr[j,1,"sum_tot"] += val;
         eqn_arr[j,1,"sum_n"]++;
         printf("\t%f", val) > NFL;
       }
     }
     trows++;
     printf("\n") > NFL;
  }
  trows_bot = trows;
  trows++;
  printf("\n") > NFL;
  trows++;
  printf("\n") > NFL;
  if (mb_mx > 0) {
    trows++;
    printf("title\t%sBandwidths\tsheet\titp_metric\ttype\tscatter_straight\n", title_pfx) > NFL;
    trows++;
    printf("hdrs\t%d\t%d\t%d\t%d\t1", trows_top, 3, -1, 3) > NFL;
    for (j=1; j <= mb_mx; j++) {
        printf("\t%d\t%d", mb_arr[j], mb_arr[j]) > NFL;
    }
    trows++;
    printf("\n") > NFL;
    trows++;
    printf("\n") > NFL;
  }
  if (tmam_mx_L1 > 0) {
    trows++;
    printf("title\t%sTopLev Level 1 Percentages\tsheet\titp_metric\ttype\tline_stacked\n", title_pfx) > NFL;
    trows++;
    printf("hdrs\t%d\t%d\t%d\t%d\t1", trows_top, 3, -1, 3) > NFL;
    for (j=1; j <= tmam_mx_L1; j++) {
        printf("\t%d\t%d", tmam_arr_L1[j], tmam_arr_L1[j]) > NFL;
    }
    trows++;
    printf("\n") > NFL;
    trows++;
    printf("\n") > NFL;
  }
  if (L2_mx > 1) {
    for (m=1; m < L2_mx; m++) {
    trows++;
    printf("title\t%sTopLev Level 2 %s Percentages\tsheet\titp_metric\ttype\tline_stacked\n", title_pfx, tmam_hdr_L2[m]) > NFL;
    trows++;
    printf("hdrs\t%d\t%d\t%d\t%d\t1", trows_top, 3, -1, 3) > NFL;
    for (j=1; j <= tmam_mx_L2[m]; j++) {
        printf("\t%d\t%d", tmam_arr_L2[m,j], tmam_arr_L2[m,j]) > NFL;
    }
    trows++;
    printf("\n") > NFL;
    }
    trows++;
    printf("\n") > NFL;
  }
  if (tmam_mx > 0) {
    trows++;
    printf("title\t%sTMAM Percentages\tsheet\titp_metric\ttype\tscatter_straight\n", title_pfx) > NFL;
    trows++;
    printf("hdrs\t%d\t%d\t%d\t%d\t1", trows_top, 3, -1, 3) > NFL;
    for (j=1; j <= tmam_mx; j++) {
        printf("\t%d\t%d", tmam_arr[j], tmam_arr[j]) > NFL;
    }
    trows++;
    printf("\n") > NFL;
    trows++;
    printf("\n") > NFL;
  }
  if (pct_mx > 0) {
    trows++;
    printf("title\t%s Percentages\tsheet\titp_metric\ttype\tscatter_straight\n", title_pfx) > NFL;
    trows++;
    printf("hdrs\t%d\t%d\t%d\t%d\t1", trows_top, 3, -1, 3) > NFL;
    for (j=1; j <= pct_mx; j++) {
        printf("\t%d\t%d", pct_arr[j], pct_arr[j]) > NFL;
    }
    trows++;
    printf("\n") > NFL;
    trows++;
    printf("\n") > NFL;
  }
  if (mpi_mx > 0) {
    trows++;
    printf("title\t%sMPI (miss/instruction) or X per instr\tsheet\titp_metric\ttype\tscatter_straight\n", title_pfx) > NFL;
    trows++;
    printf("hdrs\t%d\t%d\t%d\t%d\t1", trows_top, 3, -1, 3) > NFL;
    for (j=1; j <= mpi_mx; j++) {
        printf("\t%d\t%d", mpi_arr[j], mpi_arr[j]) > NFL;
    }
    trows++;
    printf("\n") > NFL;
    trows++;
    printf("\n") > NFL;
  }
  if (lat_mx > 0) {
    trows++;
    printf("title\t%sLatencies\tsheet\titp_metric\ttype\tscatter_straight\n", title_pfx) > NFL;
    trows++;
    printf("hdrs\t%d\t%d\t%d\t%d\t1", trows_top, 3, -1, 3) > NFL;
    for (j=1; j <= lat_mx; j++) {
        printf("\t%d\t%d", lat_arr[j], lat_arr[j]) > NFL;
    }
    trows++;
    printf("\n") > NFL;
    trows++;
    printf("\n") > NFL;
  }
  if (ghz_mx > 0) {
    trows++;
    printf("title\t%sFrequencies\tsheet\titp_metric\ttype\tscatter_straight\n", title_pfx) > NFL;
    trows++;
    printf("hdrs\t%d\t%d\t%d\t%d\t1", trows_top, 3, -1, 3) > NFL;
    for (j=1; j <= ghz_mx; j++) {
        printf("\t%d\t%d", ghz_arr[j], ghz_arr[j]) > NFL;
    }
    trows++;
    printf("\n") > NFL;
  }
  if (cpi_mx > 0) {
    trows++;
    printf("title\t%sCPI (clocks/instruction), IPC\tsheet\titp_metric\ttype\tscatter_straight\n", title_pfx) > NFL;
    trows++;
    printf("hdrs\t%d\t%d\t%d\t%d\t1", trows_top, 3, -1, 3) > NFL;
    for (j=1; j <= cpi_mx; j++) {
        printf("\t%d\t%d", cpi_arr[j], cpi_arr[j]) > NFL;
    }
    str = eqn_arr[ got_IPC,      1, "hdr"];
    if (hn_list[str] != "") {
       printf("\t%d\t%d", hn_list[str], hn_list[str]) > NFL;
    }
    trows++;
    printf("\n") > NFL;
    trows++;
    printf("\n") > NFL;
  }
  if (pwr_mx > 0) {
    trows++;
    printf("title\t%sPower\tsheet\titp_metric\ttype\tscatter_straight\n", title_pfx) > NFL;
    trows++;
    printf("hdrs\t%d\t%d\t%d\t%d\t1", trows_top, 3, -1, 3) > NFL;
    for (j=1; j <= pwr_mx; j++) {
        printf("\t%d\t%d", pwr_arr[j], pwr_arr[j]) > NFL;
    }
    trows++;
    printf("\n") > NFL;
    trows++;
    printf("\n") > NFL;
  }
  str = eqn_arr[ got_GIPS,      1, "hdr"];
  if (hn_list[str] != "") {
    trows++;
    use_cpy = num_cpus;
    printf("title\t%sinstruction/sec = %scpus*%%util*freq/cpi (Bill_instr/sec)\tsheet\titp_metric\ttype\tscatter_straight\n", title_pfx, use_cpy) > NFL;
    trows++;
    printf("hdrs\t%d\t%d\t%d\t%d\t1", trows_top, 3, -1, 3) > NFL;
    printf("\t%d\t%d", hn_list[str], hn_list[str]) > NFL;
    trows++;
    printf("\n") > NFL;
    trows++;
    printf("\n") > NFL;
  }
  close(NFL);
  if (sm_mx > 0 && sum_tmam != "") {
     for (j=1; j <= mx_cols; j++) {
        val = 0.0;
        if (sm_arr[j,"n"] > 0) {
          val = sm_arr[j,"sum"]/sm_arr[j,"n"];
        }
        printf("%s,%f\n", harr[j], val) > sum_tmam;
        printf("++__%s,%f\n", harr[j], val) > "/dev/stderr";
     }
     close(sum_tmam);
  }
  if (amx == 0) {
    exit;
  }
  an = split(ahdr, harr, ",");
  javg = 0;
  for (j=1; j <= an; j++) {
     if (harr[j] == "avg") {
        javg=j;
        break;
     }
  }
  if (javg == 0) {
    exit;
  }
  #printf("--------got into metric sum_file= %s\n", sum_file) > "/dev/stderr";
  if (bm_mx > 0) {
     for (ii=1; ii <= bm_mx; ii++) {
     bm_nm = bm_arr[ii,"nm"];
     n = split(bm_arr[ii,"nm"], arr, "."); if (n == 2) { bm_nm = arr[2]; }
     printf("\tspecint\t%s\t%s\n", bm_nm, "specint_substest") >> sum_file;
     printf("\tspecint\t%s\t%s\n", bm_arr[ii,"score"], "specint_score") >> sum_file;
     printf("\tspecint\t%s\t%s\n", bm_arr[ii,"runtm"], "specint_run_time") >> sum_file;
     printf("\tspecint\t%s\t%s\n", bm_arr[ii,"copies"], "specint_copies") >> sum_file;
     printf("\tspecint\t%s\t%s\n", bm_arr[ii,"runs"], "specint_run") >> sum_file;
     printf("\tspecint\t%s\t%s\n", bm_arr[ii,"rate_beg"], "specint_beg_ts") >> sum_file;
     printf("\tspecint\t%s\t%s\n", bm_arr[ii,"rate_end"], "specint_end_ts") >> sum_file;
     }
  }
  if (spin_work != "") {
       gsub(",", "", spin_work);
       gsub(",", "", spin_thrds);
       gsub(",", "", spin_GBpsec);
       printf("\tspin\t%s\t%s\n", spin_work, "spin_work_type") >> sum_file;
       printf("\tspin\t%s\t%s\n", spin_thrds, "spin_threads") >> sum_file;
       printf("\tspin\t%s\t%s\n", spin_GBpsec, "spin_bw_GB/sec") >> sum_file;
  }
  lkfor = "metric_";
#itp_metric_itp!INDIRECT(ADDRESS(42, 0, 4))
#=subtotal(101, INDIRECT(ADDRESS(ROW()+6, COLUMN(), 4)):INDIRECT(ADDRESS(ROW()+100, COLUMN())))
  frm2 = sprintf("=INDIRECT(ADDRESS(%d, %d, 1, 1, \"itp_metric_itp\"))", trows_top+1, j+3);
  printf("\titp_metric_itp\t%s\t%s\n", "itp_metric_itp", "goto_sheet") >> sum_file;
  printf("\titp\t%s\t%s\n", "3", "data_col_value") >> sum_file;
  printf("\titp\t%s\t%s\n", "4", "data_col_key") >> sum_file;
  printf("\titp_metric_itp\t%s\t%s\n", "itp_metric_itp", "data_sheet") >> sum_file;
  if (options != "" && index(options, "sum_file_no_formula") > 0) {
     do_avg=1;
     printf("using computed averages for summary file\n") > "/dev/stderr";
  }
  if (do_avg == "1") {
     n = split(metric_file_hdr, mf_hdr, ",");
     for (j=1; j <= mx_cols; j++) {
         n = sm_arr[j,"n"];
         val = 0.0;
         if (n > 0) {
           val = sm_arr[j,"sum"]/n;
         }
         printf("\titp1\t%f\t%s\n", val, mf_hdr[j]) >> sum_file;
     }
     for (j=1; j <= emx; j++) {
       if (eqn_arr[j,1,"got"] == eqn_arr[j,1,"max"] && eqn_arr[j,1,"use"] == "rpn") {
         n = eqn_arr[j,1,"sum_n"];
         val = 0.0;
         if (n > 0) {
           val = eqn_arr[j,1,"sum_tot"]/n;
         }
         printf("\titp3\t%f\t%s\n", val, eqn_arr[j,1,"hdr"]) >> sum_file;
       }
     }

     if (1==2) {
     for (j=1; j <= (amx); j++) {
       rw_data[j] = sv_aln_valu[1,j];
       col_hdr[j] = sv_aln_lkup[j];
       printf("\titp1\t%s\t%s", sv_aln_valu[1,j], sv_aln_lkup[j]) >> sum_file;
       for (m=2; m <= avg_file_mx; m++) {
           printf("\t%s", sv_aln_valu[m,j]) >> sum_file;
       }
       printf("\n") >> sum_file;
     }
     for (j=1; j <= emx; j++) {
#abcd
       if (eqn_arr[j,1,"max"] == eqn_arr[j,1,"got"]) {
          n   = eqn_arr[j,1,"sum_n"];
          #val = rpn_rtn(val, j, got_rpn_eqn, amx, col_hdr, rw_data);
          val = 0.0;
          if (n > 0) {
            val = eqn_arr[j,1,"sum_tot"]/n;
          }
          printf("\titp3\t%f\t%s", val, eqn_arr[j,1,"hdr"]) >> sum_file;
          printf("\n") >> sum_file;
       }
     }
     }
  } else {
  for (j=1; j <= (hn+tot_extra_col); j++) {
     frm3 = sprintf("INDIRECT(ADDRESS(ROW()-%d, column(), 4, 1))", j);
     frm4 = sprintf("INDIRECT(ADDRESS(ROW()-%d, column()-1, 4, 1))", j);
     frm1 = sprintf("=INDIRECT(ADDRESS(%d, %d, 1, 1, %s))", trows_top, j+3, frm3);
     frm2 = sprintf("=INDIRECT(ADDRESS(%d, %d, 1, 1, %s))", trows_top+1, j+3, frm4);
     printf("\titp2\t%s\t%s\n", frm1, frm2) >> sum_file;
  }
  }
  printf("\n") >> sum_file;
  close(sum_file);
}
