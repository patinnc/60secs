@include "read_specint.awk"
@include "rpn.awk"
@include "bc_eqn.awk"
BEGIN{
   row=0;
   cpu_col = 0;
   evt_idx=-1;
   num_cpus += 0;
   got_err = 0;

   use_cpu_got_list = 0;
   if (use_cpus != "") {
     #perf_cpus=0-47
     lkfr = "perf_cpus=";
     pos = index(use_cpus, lkfr);
     if (pos > 0) {
       v = substr(use_cpus, pos+length(lkfr), length(use_cpus));
       gsub(" ", "", v);
       # just handle single range of cpus for now
       n = split(v, arr, "-");
       v0 = arr[1];
       v1 = arr[2];
       use_cpu_got_list = 1;
       printf("%s perf_cpus= %s to %s\n", script, v0, v1) > "/dev/stderr";
       for (i=v0; i <= v1; i++) { use_cpu_list[i] = i; }
     } else {
       printf("%s perf_cpu_group= %s\n", script, use_cpus);
       #      got_err = 1;
       #      exit(1);
       use_cpu_got_list = 1;
       gsub(" ", "", use_cpus);
       n = split(use_cpus, arr, ",");
       for (i=1; i <= n; i++) {
         if (index(arr[i], "-") > 0) {
           n1 = split(arr[i], arr1, "-");
           if (n1 != 2) {
             printf("%s awk: not sure what is going on here: expected range like x-y. got %s in use_cpus string %s. bye.\n", script, arr[i], use_cpus);
             got_err = 1;
             exit(1);
           }
           for (j=arr1[1]; j <= arr1[2]; j++) {
             use_cpu_list[j] = j;
             printf("use_cpu_list[%d]\n", j);
           }
         } else {
             use_cpu_list[arr[i]] = arr[i]+0;
             printf("use_cpu_list[%d]= %s\n", arr[i], use_cpu_list[arr[i]]);
         }
       }
       #got_err = 1;
       #exit(1);
     }
   }
   months="  JanFebMarAprMayJunJulAugSepOctNovDec";
   date_str="";
   got_add_all_to_summary = 0;
   if (index(options, "add_all_to_summary") > 0) {
     got_add_all_to_summary = 1;
   }
   options_get_max_val = 0;
   options_get_perf_stat_max_val = 0;
   if (index(options, "get_max_val") > 0) {
     options_get_max_val = 1;
   }
   if (index(options, "get_perf_stat_max_val") > 0) {
     options_get_perf_stat_max_val = 1;
   }
   options_get_pxx_stats = 0;
   if (index(options, "get_pxx_stats") > 0) {
    options_get_pxx_stats = 1;
   }
   printf("%s got_add_all_to_summary= %d\n", script, got_add_all_to_summary) > "/dev/stderr";
   ph_mx = 0;
   if (phase_file != "" && phase_clip != "") {
     while ((getline < phase_file) > 0) {
       ph_mx++;
       ph_arr[ph_mx,1] = $1;
       ph_arr[ph_mx,2] = $2+0.0;
       ph_arr[ph_mx,3] = $3+0.0;
       ph_arr[ph_mx,4] = $4;
     }
     printf("phase_mx= %d, phase_clp=\"%s\"\n", ph_mx, phase_clip) > "/dev/stderr";
     close(phase_file);
   }
   ts_initial = 0.0;
   ts_beg += 0.0;
   ts_end += 0.0;
   options_pct_cpu_like_top = 0;
   options_pct_cpu_like_top_fctr = 1.0;
   if (index(options, "%cpu_like_top") > 0) {
      options_pct_cpu_like_top = 1;
      options_pct_cpu_like_top_fctr = num_cpus;
   }
   st_beg=0; 
   st_mx=0;
   ts_prev = 0.0;
      n_sum = 0;
     if (sum_file != "" && sum_flds != "") {
       n_sum = split(sum_flds, sum_arr, ",");
       for (i_sum=1; i_sum <= n_sum; i_sum++) {
          sum_type[i_sum] = 0;
          str = sum_arr[i_sum];
          pos = index(str, "{");
          if (pos > 0) {
             pos1 = index(str, "}");
             if (pos1 == 0) { pos1= length(str)+1; }
             sum_str = substr(str, pos+1, pos1-pos-1);
             n_sum2 = split(sum_str, sum_arr2, "|");
             if (sum_arr2[1] != "") {
               sum_prt[i_sum] = sum_arr2[1];
             } else {
               #sum_prt[i_sum] = str;
               sum_prt[i_sum] = substr(str, 1, pos-1);
             }
             if (sum_arr2[2] != "") {
               sum_res[i_sum] = sum_arr2[2];
             }
             #sum_prt[i_sum] = substr(str, pos+1, pos1-pos-1);
             sum_arr[i_sum] = substr(str, 1, pos-1);
          } else {
             sum_prt[i_sum] = str;
          }
          printf("got sum_arr[%d]= %s, prt= %s\n", i_sum, sum_arr[i_sum], sum_prt[i_sum]) > "/dev/stderr";
       }
     }
}


function do_summary(colms, v, epch, intrvl, k_idx,    v1, myn, isum) {
   if (n_sum > 0 && hdr_lkup[colms] != -1) {
      i_sum = hdr_lkup[colms];
      if (k_idx > 0) {
         nwfor[k_idx,2] = 1;  # so this computed column is already covered (or at least referenced) by sum_flds so it may be already getting adding to the summary
         nwfor[k_idx,1,"alias_i_sum"] = i_sum;
      }
      sum_occ[i_sum] += 1;
      sum_k_idx[i_sum] = k_idx;
      #printf("colms= %d, v= %f, epch= %f, intrvl= %f, i_sum= %d typ= %d\n", colms, v, epch, intrvl, i_sum, sum_type[i_sum]) >> sum_file;
      if (sum_type[i_sum] == 1) {
         if (sum_tmin[i_sum] == 0)   { sum_tmin[i_sum] = epch; sum_tmax[i_sum] = sum_tmin[i_sum]; }
         if (sum_tmax[i_sum] < epch) { sum_tmax[i_sum] = epch; }
         v1 = v * intrvl;
         sum_tot[i_sum] += v1;
      } else {
         v1 = v;
         sum_tot[i_sum] += v1;
      }
        sum_tot[i_sum,"sum"] += v1;
        sum_tot[i_sum,"sum_sq"] += v1*v1;
        sum_tot[i_sum,"n"]++;
      if (options_get_perf_stat_max_val == 1) {
        if (sum_ps_max[i_sum,"peak"] == "" || sum_ps_max[i_sum,"peak"] < v1) {
          sum_ps_max[i_sum,"peak"] = v1;
        }
        sum_ps_max[i_sum,"n"]++;
        sum_ps_max[i_sum,"sum"] += v1;
        sum_ps_max[i_sum,"sum_sq"] += v1*v1;
      }
      if (options_get_pxx_stats == 1) {
        myn = ++pxx_stats[i_sum,"n"];
        pxx_stats[i_sum,"vals",myn] = v1;
      }
   } else {
      if (k_idx > 0) {
         nwfor[k_idx,2] = 0;  # so this computed column is already covered (or at least referenced) by sum_flds so it may be already getting adding to the summary
         nwfor[k_idx,3] += v;  # accumulate values
         nwfor[k_idx,4] += 1;  # how many values
      }
   }
}
function dt_to_epoch(offset) {
 # started on Tue Dec 10 23:23:30 2019
 # Dec 10 23:23:30 2019
      if (use_tm_beg_run_log != "") {
        return use_tm_beg_run_log + offset;
      }
   if (date_str == "") {
      return 0.0;
   }
   n=split(date_str, darr, /[ :]+/);
   #for(i in darr) printf("darr[%d]= %s\n", i,  darr[i]);
   mnth_num = sprintf("%d", index(months, darr[1])/3);
   #printf("mnth_num= %d\n", mnth_num);
   dt_str = darr[6] " " mnth_num " " darr[2] " " darr[3] " " darr[4] " " darr[5];
   #printf("dt_str= %s\n", dt_str);
   epoch = mktime(dt_str);
   #printf("epoch= %s offset= %s\n", epoch, offset);
   return epoch + offset;
}
{
   FNM=ARGV[ARGIND];
   if (match(FNM, /CPU2017.[0-9][0-9][0-9].log$/)) {
      read_specint_line();
      #printf("got specint_line\n");
      next;
   }
}
#  FILENAME==ARGV[2]{
#    next;
#     #/^Issuing command .*\/benchspec\/.* -f speccmds.cmd / 
#  if (match($0, /^Issuing command .*\/benchspec\/.* -f speccmds.cmd /) == 1) {
#    #printf("got %s\n", $0);
#    n = split($0, arr, /\//);
#    for (i=1; i < n; i++) {
#      #printf("arr[%d]= %s\n", i, arr[i]);
#      if (arr[i] == "CPU") {
#       sub_test = arr[i+1];
#       #printf("sub_test= %s\n", sub_test);
#       break;
#      }
#    }
#    getline;
#    if (index($0, "Start command: ") == 1) {
#      n = split($0, arr, /[()]/);
#      beg = arr[2];
#      #printf("beg= %s\n",beg);
#      getline;
#      if (index($0, "Stop command: ") == 1) {
#        n = split($0, arr, /[()]/);
#        end = arr[2];
#        ++st_mx;
#        st_sv[st_mx,1]=sub_test;
#        st_sv[st_mx,2]=beg+0.0;
#        st_sv[st_mx,3]=end+0.0;
#      printf("%f\t%s\n", st_sv[st_mx,2], st_sv[st_mx,1]);
#        next;
#      }
#    }
#    next;
#  } else {
#    next;
#  }
#  }

/^# started on / {
# started on Sat 26 Dec 2020 12:59:46 AM PST 1608973186.709312151
# started on Sat Dec 26 00:59:46 2020

  # started on Fri Jun 12 14:36:31 UTC 2020 1591972591.618156223
  # started on Fri Jun 12 14:36:31 2020
  pos = index($0, " on ")+8;
  if (date_str != "") {
     # I prepend a more complete date time stamp as the first line
     next;
  }
  date_str = substr($0, pos);
  if (NF == 10) {
     if (NF == 10) {
        ts_initial = $10+0;
        printf("perf_stat_scatter.sh: -------- ts_initial= %f\n", ts_initial) > "/dev/stderr";
     }
     date_str = $5 " " $6 " " $7 " " $9;
  } else {
    if (tm_beg_run_log != "") {
      use_tm_beg_run_Log = tm_beg_run_log;
      ts_initial = tm_beg_run_log+0.0;
      printf("use tm_beg_run_log= %s\n", tm_beg_run_log) > "/dev/stderr";
    }
  }
  #printf("data_str = \"%s\"\n", date_str);
  tst_epoch = dt_to_epoch(0.0);
  #printf("tst_epoch= %s\n", tst_epoch);
  # works
  #   darr[1]= Dec
  #   darr[2]= 12
  #   darr[3]= 10
  #   darr[4]= 38
  #   darr[5]= 31
  #   darr[6]= 2019
  #   dt_str= 2019 12 12 10 38 31
  #   epoch= 1576175911 offset= 0
  #   tst_epoch= 1576175911
  # fails
  #   darr[1]= Jan
  #   darr[2]= 
  #   darr[3]= 6
  #   darr[4]= 13
  #   darr[5]= 36
  #   darr[6]= 55
  #   darr[7]= 2020
  #   dt_str= 55 1  6 13 36
  #   epoch= -1 offset= 0
  #   tst_epoch= -1
  next;
}
/<not supported>/ {
  next;
}
/<not counted>/ {
  next;
}
#  2879.939941800;<not supported>;Bytes;qpi_ctl_bandwidth_tx;0;100.00;;
#  2879.947975321;<not counted>;;cpu-clock;69060526;100.00;;

/;/{
  #          1        2          3   4          5           6
  # 120.003961364;1919857.169339;;cpu-clock;1919864513706;100.00;;

  #          1    2  3     4       5    6            7           8   9     10
  #  1.004420989;S1;16;30384313506;;instructions;16051372488;100.00;0.84;insn per cycle

  n=split($0,arr,";");
  if (index(arr[2], "CPU") == 1) {
    # if we have a 'CPU' column then we ran perf with 'perf stat -A ' to get the per-cpu CPU column
    cpu_col = 1;
    # if you do perf 'per-cpu' (with -A option) then cpu_clk_unhalted.thread_any behaves just like 'cycles'
    # at least on cascade lake and debian 5.10
    # so set thr_per_core = 1
    thr_per_core = 1;
  }
  if (cpu_col == 1 && use_cpu_got_list == 1) {
    v = substr(arr[2], 4, length(arr[2])) + 0
    if (use_cpu_list[v] == "") {
      cpus_list_skip++;
      next;
    }
    cpus_list_used++;
  }
  ts=arr[1];
  if (ts_initial > 0.0) {
     epch = ts_initial + ts;
  } else {
     epch = dt_to_epoch(ts);
  }
  if (ph_mx > 0) {
    #printf("ck phase_clp= \"%s\"  epch %f, ph_mx= %d, ph_0= %f, ph_end= %f\n", phase_clip, epch, ph_mx, ph_arr[1,2], ph_arr[ph_mx,3]) > "/dev/stderr";
    for (i=1; i <= ph_mx; i++) {
      if (epch >= ph_arr[i,2] && epch <= ph_arr[i,3]) {
        #printf("befor phase_clip: got phase[%d]= %s cur_phase= %s beg= %f epch %f end= %f\n", i, phase_clip, ph_arr[i,1], ph_arr[i,2], epch, ph_arr[i,3]) > "/dev/stderr";
        if (ph_arr[i,1] == phase_clip) {
          #printf("got phase[%d]= %s  beg= %f epch %f end= %f\n", i, phase_clip, ph_arr[i,2], epch, ph_arr[i,3]) > "/dev/stderr";
           break;
         } else {
           next;
         }
      }
    }
    if (i > ph_mx) { next; }
  }
  skt=arr[2+cpu_col];
  skt_incr = 2;
  if (skt != "S0" && skt != "S1" && skt != "S2" && skt != "S3") {
    skt="S0";
    skt_incr = 0;
    inst = num_cpus;
    if (options != "" && index(options, "dont_sum_sockets") > 0) {
        printf("options before= %s\n", options) > "/dev/stderr";
        gsub("dont_sum_sockets", "", options);
        printf("options after = %s\n", options) > "/dev/stderr";
        printf("ts_end= %s\n", ts_end) > "/dev/stderr";
    }
  } else {
    if (options != "" && index(options, "do_sum_sockets") > 0) {
      inst=arr[3+cpu_col];
      skt="S0";
    } else {
      inst=arr[3+cpu_col];
    }
  }
  val=arr[2+skt_incr+cpu_col];
  evt=arr[4+skt_incr+cpu_col];
  if (evt == "") {
    next;
  }
  if (options != "" && skt_incr != 0 && index(options, "dont_sum_sockets") > 0) {
     evt = evt " " skt;
  }
  if (val > 0 && substr(evt,1,3) == "unc") {
   pos= index(evt, "_");
   if (pos > 4 && substr(evt, pos, length(evt)) == "_read_write") {
     if (!(evt in memch_list)) {
       memch_list[evt] = ++memch_mx;
       memch_lkup[memch_mx] = evt;
     }
   }
  }
  tmr=arr[5+skt_incr+cpu_col];
  pct=arr[6+skt_incr+cpu_col];
  #printf("ts= %s, skt= %s, inst= %s val= %s, evt= %s, tmr= %s, pct= %s\n", ts, skt, inst, val, evt, tmr, pct) > "/dev/stderr";
  if ( ck_row[ts,skt] != ts","skt) {
     row++;
     ck_row[ts,skt] = ts","skt;
  }
  if ( skts[skt] != skt) {
    skts[skt] = skt;
    skt_idx++;
    skt_num[skt]=skt_idx;
    skt_lkup[skt_idx]=skt;
    printf("skt_lkup[%d]= %s\n", skt_idx, skt) > "/dev/stderr";
  }
  if (!(evt in evts)) {
    evts[evt] = evt;
    evt_idx++;
    printf("add event %s evt_idx= %d\n", evt, evt_idx) > "/dev/stderr";
    evt_num[evt]=evt_idx;
    evt_lkup[evt_idx]=evt;
    evt_inst[evt_idx]=0;
    evt_inst_ts[evt_idx]=ts;
  }
  j=evt_num[evt];
  if (evt_inst_ts[j] == ts) {
    if (evt_inst[j] == 0 || inst > 1){ # if summing per socket events, then summing to system, just put 1 for instance
       evt_inst[j] += inst;
    }
  }
    
  sv[row,0]=epch;
  sv[row,1]=ts;
  sv[row,2]=skt;
  hdr[3+j*2]=evt;
  sv[row,3+j]+=val;
  sv_tmr[row,3+j]+=tmr;
  #inst_by_evt[
  #if (row < 8) {printf("row= %d, j= %d, evt= %s, val= %s\n", row, j, evt, val);}
}
function prt_rpn_eqn(kmx,   i, str) {
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   str="";
   for (i=1; i <= got_rpn_eqn[kmx, 1, "max"]; i++) {
     str = str "" got_rpn_eqn[kmx, i, "val"];
   }
   printf("prt_rpn_eqn[%d], %s: eqn= %s\n", kmx, nwfor[kmx,1,"hdr"], str);
}
 END{
   if (got_err == 1) {
     printf("%s awk got error. bye\n", script) > "/dev/stderr";
     exit(1);
   }
  #for (ii=1; ii <= st_mx; ii++) {
  #  printf("%s\t%f\t%f\n", st_sv[ii,1], st_sv[ii,2], st_sv[ii,3]);
  #}
   printf("cpus_list_skip= %d cpus_list_used= %d\n", cpus_list_skip, cpus_list_used);
   ref_cycles_str = "ref-cycles_unknown";
   cpu_cycles_str = "cpu-cycles_unknown";
   instructions_str = "instructions_unknown";
   L3_misses_str = "L3_lat_out_misses_unknown";
   L3_misses_out_str = "L3_cha_lat_out_misses_unknown";
   L3_cha_misses_str = "L3_cha_lat_out_misses_unknown";
   L3_cha_misses_out_str = "L3_lat_out_misses_unknown";
   L3_access_str = "L3_lat_out_misses_unknown";
   L3_cha_clockticks = "unc_cha_clockticks";
   L3_cha_clockticks_str = L3_cha_clockticks "_unknown";
   got_unc_cha_miss = 0;
   got_unc_cha_miss_out = 0;
   got_unc_cha_clockticks = 0;
   use_qpi_bw = -1;
   lat_fctr = 1.0;
   for (i=0; i <= evt_idx; i++) {
     levt = tolower(evt_lkup[i]);
     if (evt_lkup[i] == "msr/aperf/" || evt_lkup[i] == "cycles" || evt_lkup[i] == "cpu-cycles") {
       cpu_cycles_str = evt_lkup[i];
     }
     if (evt_lkup[i] == "msr/mperf/" || evt_lkup[i] == "ref-cycles") {
       ref_cycles_str = evt_lkup[i];
     }
     if (evt_lkup[i] == "msr/irperf/" || evt_lkup[i] == "instructions") {
       instructions_str = evt_lkup[i];
     }
     if (evt_lkup[i] == "L3_misses") {
       L3_misses_str = evt_lkup[i];
     }
     # l3_lat_out_cycles and l3_lat_out_misses are AMD L3 latency events
     if (levt == "l3_lat_out_cycles") {
       L3_cha_misses_out_str =  evt_lkup[i];
       got_unc_cha_miss_out= 1;
       lat_fctr = 16.0;
     }
     if (levt == "l3_lat_out_misses") {
       L3_cha_misses_str =  evt_lkup[i];
       got_unc_cha_miss= 1;
     }
     if (levt == "l3_accesses") {
       L3_cha_access_str = evt_lkup[i];
     }
     if (levt == "msr/aperf/") {
       cpu_cycles_str = evt_lkup[i];
     }
     # the unc_cha_tor_inserts events are Intel L3 events
     if (levt == "unc_cha_tor_inserts.ia_miss.0x40433") {
       L3_cha_misses_str = evt_lkup[i];
       got_unc_cha_miss= 1;
     }
     if (levt == "unc_cha_tor_occupancy.ia_miss.0x40433") {
       L3_cha_misses_out_str = evt_lkup[i];
       got_unc_cha_miss_out= 1;
     }
     if (levt == L3_cha_clockticks) {
       L3_cha_clockticks_str = evt_lkup[i];
       got_unc_cha_clockticks = 1;
     }
     if (levt == "unc_cha_tor_inserts.ia.0x40433") {
       L3_cha_access_str = evt_lkup[i];
     }
     if (evt_lkup[i] == "qpi_data_bandwidth_tx") {
       # native broadwell event
       use_qpi_bw = 1;
     } else if (evt_lkup[i] == "qpi_data_bandwidth_tx0" || evt_lkup[i] == "qpi_data_bandwidth_tx1") {
       # evt created by pfay after looking for uncore_upi/uncore_qpi
       use_qpi_bw = 2;
     }
   }
   got_bad_spec_evts = 0;
   need_bad_spec_evts = -1;
   if (cpu_type != "Ice Lake") {
     for (i=0; i <= evt_idx; i++) {
       if (evt_lkup[i] == "uops_issued.any") { got_bad_spec_evts++; }
       if (evt_lkup[i] == "uops_retired.retire_slots") { got_bad_spec_evts++; }
       if (evt_lkup[i] == "int_misc.recovery_cycles_any") { got_bad_spec_evts++; }
     }
     need_bad_spec_evts = 3;
   } else {
     for (i=0; i <= evt_idx; i++) {
       if (evt_lkup[i] == "topdown-bad-spec") { got_bad_spec_evts++; }
       if (evt_lkup[i] == "cpu/slots/") { got_bad_spec_evts++; }
     }
     need_bad_spec_evts = 2;
   }
   printf("perf_stat_scatter.sh: ref_cycles_str= %s, cpu_cycles_str= %s\n", ref_cycles_str, cpu_cycles_str) > "/dev/stderr";
   kmx = 0;
   def_inst = num_cpus;

   inv_num_sockets = 0;
   if (num_sockets != "" && num_sockets > 0) {
     inv_num_sockets = 1.0/num_sockets;
   }

#  kmx++;
#  got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
#  got_lkfor[kmx,2]=2; # num of fields to look for
#  got_lkfor[kmx,3]=1.0e-9; # a factor
#  got_lkfor[kmx,4]="div"; # operation x/y/z
#  got_lkfor[kmx,5]=1; # instances
#  got_lkfor[kmx,6]="div_by_non_halted_interval"; # 
#  got_lkfor[kmx,"tag"]="avg_freq_ghz";
#  lkfor[kmx,1]=cpu_cycles_str;
#  lkfor[kmx,2]="instances";  # get the instances from the first lkfor event
#  nwfor[kmx,1,"hdr"]="avg_freq (GHz)";
#  nwfor[kmx,1,"alias"]="metric_CPU operating frequency (in GHz)";

   # frqGHz = tsc_ghz * evt[cyc,i]/evt[mperf,i]; v = frqGHz;}
   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]=1.0; # a factor
   got_lkfor[kmx,4]="bc_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # instances
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]=tsc_freq " * ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str"
   got_rpn_eqn[kmx, ++kkmx, "val"]=cpu_cycles_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" / "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]=ref_cycles_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   got_lkfor[kmx,"tag"]="avg_freq_ghz";
   lkfor[kmx,1]=cpu_cycles_str;
   lkfor[kmx,2]=ref_cycles_str;
   nwfor[kmx,1,"hdr"]="avg_freq (GHz)";
   nwfor[kmx,1,"alias"]="metric_CPU operating frequency (in GHz)";


   if (amd_cpu == 0) {
#   kmx++;
#   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
#   got_lkfor[kmx,2]=2; # num of fields to look for
#   got_lkfor[kmx,3]=100.0/(tsc_freq*1.0e9); # a factor
#   got_lkfor[kmx,4]="div"; # operation x/y
#   got_lkfor[kmx,5]=1; # instances
#   got_lkfor[kmx,6]="div_by_interval"; # 
#   lkfor[kmx,1]=ref_cycles_str;
#   lkfor[kmx,2]="instances";  # get the instances from the first lkfor event
#   nwfor[kmx,1,"hdr"]="%not_halted";
#   nwfor[kmx,1,"alias"]="metric_CPU utilization %";

   # bsy = 1.0e-9*(evt[mperf,i])/(num_cpus * tsc_ghz * tm_dff); v = 100.0*bsy;
   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=1; # num of fields to look for
   got_lkfor[kmx,3]=1.0; # a factor
   got_lkfor[kmx,4]="bc_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # instances
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]= 100.0e-9 " * ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]=ref_cycles_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" / ( " num_cpus " * " tsc_freq " * ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]=1.0;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_interval";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" ) ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]=ref_cycles_str;
   nwfor[kmx,1,"hdr"]="%not_halted";
   nwfor[kmx,1,"alias"]="metric_CPU utilization %";


   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]=1.0; # a factor
   got_lkfor[kmx,4]="bc_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # instances
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]=" 100.0 * ( "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]=cpu_cycles_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" - ( 0.5 * "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="cpu_clk_unhalted.thread_any";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" ) ) / ( 0.5 * "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="cpu_clk_unhalted.thread_any";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" ) "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]=cpu_cycles_str;
   lkfor[kmx,2]="cpu_clk_unhalted.thread_any"; 
   nwfor[kmx,1,"hdr"]="%both_HT_threads_active";


   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=1; # num of fields to look for
   got_lkfor[kmx,3]=1.0; # a factor
   got_lkfor[kmx,4]="bc_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # instances
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]=L3_cha_clockticks_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" / "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]=L3_cha_clockticks_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_tmr";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   got_lkfor[kmx,"tag"]="uncore_freq";
   lkfor[kmx,1]=L3_cha_clockticks_str;
   nwfor[kmx,1,"hdr"]="uncore_freq (GHz)";

#   kmx++;
#   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
#   got_lkfor[kmx,2]=1; # num of fields to look for
#   got_lkfor[kmx,3]=inv_num_sockets * 1.0e-9; # a factor
#   got_lkfor[kmx,4]="sum"; # operation x/y
#   got_lkfor[kmx,5]=1; # instances
#   got_lkfor[kmx,6]="div_by_tmr_interval"; # 
#   lkfor[kmx,1]=L3_cha_clockticks_str;
#   nwfor[kmx,1,"hdr"]="uncore_freq (GHz)";
   }

#    rpn operations
#    AMD %unhalted calc. amd doesn't have ref-cycles so use tsc_freq and msr/mperf/
   if (amd_cpu == 1) {
   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=1; # num of fields to look for
   got_lkfor[kmx,3]=1.0; # 100.0 * mperf / (num_cpus * tsc_freq);
   got_lkfor[kmx,4]="rpn_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   #got_lkfor[kmx,6]=""; # 
   got_lkfor[kmx,6]="div_by_interval"; # 
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]=100;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="msr/mperf/"
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="*"; # 100 * mperf
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx, ++kkmx, "val"]= num_cpus * 1.0e6 * tsc_freq;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="/";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]=tolower("msr/mperf/");
   nwfor[kmx,1,"hdr"]="%not_halted";
   nwfor[kmx,1,"alias"]="metric_CPU utilization %";


#  L3_lat_out_cycles
#  L3_lat_out_misses

   }
   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]=1000.0; # a factor
   got_lkfor[kmx,4]="div"; # operation
   got_lkfor[kmx,5]=1; # instances
   lkfor[kmx,1]=L3_cha_misses_str;
   lkfor[kmx,2]=instructions_str;
   nwfor[kmx,1,"hdr"]="LLC-misses PKI";

   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=1; # num of fields to look for
   got_lkfor[kmx,3]=64.0e-9; # a factor
   got_lkfor[kmx,4]="sum"; # operation
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]="div_by_interval"; # 
   lkfor[kmx,1]=L3_cha_misses_str;
   nwfor[kmx,1,"hdr"]="LLC-miss bw (GB/s)";

   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   if (amd_cpu == 1) {
     got_lkfor[kmx,3]=1.0; # lat_out_cycles is total cycles/16
   } else {
     got_lkfor[kmx,3]=1.0; 
   }
   #got_lkfor[kmx,4]="rpn_eqn"; # operation x/y/z
   got_lkfor[kmx,4]="bc_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   #got_lkfor[kmx,6]="div_by_interval"; # 
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]=" ( " lat_fctr " * ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]=L3_cha_misses_out_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" / "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]=L3_cha_misses_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" ) ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";

   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]=L3_cha_misses_out_str;
   lkfor[kmx,2]=L3_cha_misses_str;
   nwfor[kmx,1,"hdr"]="L3 miss latency (core_clks)";

   kmx++;
   kkmx = 0;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=3; # num of fields to look for
   got_lkfor[kmx,3]=inv_num_sockets;
   got_lkfor[kmx,3]=1.0;
   got_lkfor[kmx,4]="bc_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]="";
   got_lkfor[kmx,"tag"]="L3_lat_ns";
   #got_rpn_eqn[kmx, ++kkmx, "val"]=" ( " num_sockets " * " lat_fctr " * ";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" ( " lat_fctr " * ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]=L3_cha_misses_out_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" / "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]=L3_cha_misses_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" ) / ( ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
#   if (amd_cpu == 0) {
#   got_rpn_eqn[kmx, ++kkmx, "val"]=L3_cha_clockticks_str;
#   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
#   got_rpn_eqn[kmx, ++kkmx, "val"]=" / "
#   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
#   got_rpn_eqn[kmx, ++kkmx, "val"]=L3_cha_clockticks_str;
#   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_tmr";
#   got_rpn_eqn[kmx, ++kkmx, "val"]=" )";
#   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
#   } else {
   got_rpn_eqn[kmx, ++kkmx, "val"]="1.0";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_sv_avg_freq_ghz";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" ) ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
#   }
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]=L3_cha_misses_out_str;
   lkfor[kmx,2]=L3_cha_misses_str;
   lkfor[kmx,3]=L3_cha_clockticks_str;
   nwfor[kmx,1,"hdr"]="L3 miss latency (ns)";
   printf("%s _____ L3_cha_misses_out_str= %s L3_cha_misses_str= %s L3_cha_clockticks_str= %s inv_num_sockets= %f\n",
     script, L3_cha_misses_out_str, L3_cha_misses_str, L3_cha_clockticks_str, inv_num_sockets) > "/dev/stderr";
   prt_rpn_eqn(kmx);


   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]=1.0;
   got_lkfor[kmx,4]="rpn_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   #got_lkfor[kmx,6]="div_by_interval"; # 
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]=100.0;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=L3_cha_misses_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="*"; # 100 * mperf
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx, ++kkmx, "val"]=L3_cha_access_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="/";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]=L3_cha_misses_str;
   lkfor[kmx,2]=L3_cha_access_str;
   nwfor[kmx,1,"hdr"]="%LLC misses";

   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]=1.0;
   got_lkfor[kmx,4]="rpn_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   #got_lkfor[kmx,6]="div_by_interval"; # 
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]=100.0;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=L3_misses_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="*"; # 100 * mperf
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx, ++kkmx, "val"]=L3_access_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="/";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]=L3_misses_str;
   lkfor[kmx,2]=L3_access_str;
   nwfor[kmx,1,"hdr"]="%LLC misses";


   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=8; # num of fields to look for
   got_lkfor[kmx,3]=64e-9; # a factor
   got_lkfor[kmx,4]="sum"; # operation
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]="div_by_interval"; # 
   got_lkfor[kmx,"typ_match"]="require_any"; # 
   got_lkfor[kmx,"max"]=1000.0;
   lkfor[kmx,1]="unc0_read_write";
   lkfor[kmx,2]="unc1_read_write";
   lkfor[kmx,3]="unc2_read_write";
   lkfor[kmx,4]="unc3_read_write";
   lkfor[kmx,5]="unc4_read_write";
   lkfor[kmx,6]="unc5_read_write";
   lkfor[kmx,7]="unc6_read_write";
   lkfor[kmx,8]="unc7_read_write";
   nwfor[kmx,1,"hdr"]="unc_read_write (GB/s)";
   nwfor[kmx,1,"alias"]="metric_memory bandwidth total (MB/sec)";
   nwfor[kmx,1,"alias_factor"]=1000.0;
   nwfor[kmx,1,"alias_oper"]="*";
   mem_bw_kmx = kmx;

   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=1; # num of fields to look for
   got_lkfor[kmx,3]=64e-9; # a factor
   got_lkfor[kmx,4]="sum"; # operation
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]="div_by_interval"; # 
   got_lkfor[kmx,"typ_match"]="require_any"; # 
   got_lkfor[kmx,"max"]=1000.0;
   lkfor[kmx,1]="hwprefetch_local";
   nwfor[kmx,1,"hdr"]="hw prefetch local bw (GB/s)";

   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=1; # num of fields to look for
   got_lkfor[kmx,3]=64e-9; # a factor
   got_lkfor[kmx,4]="sum"; # operation
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]="div_by_interval"; # 
   got_lkfor[kmx,"typ_match"]="require_any"; # 
   got_lkfor[kmx,"max"]=1000.0;
   lkfor[kmx,1]="hwprefetch_remote";
   nwfor[kmx,1,"hdr"]="hw prefetch remote bw (GB/s)";

   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=1; # num of fields to look for
   got_lkfor[kmx,3]=64e-9; # a factor
   got_lkfor[kmx,4]="sum"; # operation
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]="div_by_interval"; # 
   got_lkfor[kmx,"typ_match"]="require_any"; # 
   got_lkfor[kmx,"max"]=1000.0;
   lkfor[kmx,1]="mem_remote";
   nwfor[kmx,1,"hdr"]="L1_miss_filled_from_remote bw (GB/s)";

   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=1; # num of fields to look for
   got_lkfor[kmx,3]=64e-9; # a factor
   got_lkfor[kmx,4]="sum"; # operation
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]="div_by_interval"; # 
   got_lkfor[kmx,"typ_match"]="require_any"; # 
   got_lkfor[kmx,"max"]=1000.0;
   lkfor[kmx,1]="mem_local";
   nwfor[kmx,1,"hdr"]="L1_miss_filled_from_local bw (GB/s)";

   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]=1.0; # a factor
   got_lkfor[kmx,4]="div"; # operation
   got_lkfor[kmx,5]=1; # instances
   lkfor[kmx,1]=instructions_str;
   lkfor[kmx,2]=cpu_cycles_str;
   nwfor[kmx,1,"hdr"]="IPC";
   nwfor[kmx,1,"alias"]="metric_IPC";

   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]=1.0; # a factor
   got_lkfor[kmx,4]="div"; # operation
   got_lkfor[kmx,5]=1; # instances
   lkfor[kmx,1]=cpu_cycles_str;
   lkfor[kmx,2]=instructions_str;
   nwfor[kmx,1,"hdr"]="CPI";
   nwfor[kmx,1,"alias"]="metric_CPI";



   if (amd_cpu == 1) {
     if (use_qpi_bw == 2) {
       kmx++;
       got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
       got_lkfor[kmx,2]=4; # num of fields to look for
       got_lkfor[kmx,3]=32e-9; # a factor
       got_lkfor[kmx,4]="sum"; # operation
       got_lkfor[kmx,5]=1; # instances
       got_lkfor[kmx,6]="div_by_interval"; # 
       lkfor[kmx,1]="qpi_data_bandwidth_tx0";
       lkfor[kmx,2]="qpi_data_bandwidth_tx1";
       lkfor[kmx,3]="qpi_data_bandwidth_tx2";
       lkfor[kmx,4]="qpi_data_bandwidth_tx3";
       nwfor[kmx,1,"hdr"]="QPI_BW (GB/sec)";
       nwfor[kmx,1,"alias"]="metric_UPI Data transmit BW (MB/sec) (only data)";
       nwfor[kmx,1,"alias_factor"]=1000.0;
       nwfor[kmx,1,"alias_oper"]="*";
     }
   }
   if (amd_cpu == 0) {
     if (use_qpi_bw == 1) {
       kmx++;
       got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
       got_lkfor[kmx,2]=1; # num of fields to look for
       got_lkfor[kmx,3]=1e-9; # a factor
       got_lkfor[kmx,4]="sum"; # operation
       got_lkfor[kmx,5]=1; # instances
       got_lkfor[kmx,6]="div_by_interval"; # 
       lkfor[kmx,1]="qpi_data_bandwidth_tx";
       nwfor[kmx,1,"hdr"]="QPI_BW (GB/sec)";
       nwfor[kmx,1,"alias"]="metric_UPI Data transmit BW (MB/sec) (only data)";
       nwfor[kmx,1,"alias_factor"]=1000.0;
       nwfor[kmx,1,"alias_oper"]="*";
     }

     if (use_qpi_bw == 2) {
       kmx++;
       got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
       got_lkfor[kmx,2]=2; # num of fields to look for
       got_lkfor[kmx,3]= (64.0/9.0) * 1.0e-9; # a factor
       got_lkfor[kmx,4]="sum"; # operation
       got_lkfor[kmx,5]=1; # instances
       got_lkfor[kmx,6]="div_by_interval"; # 
       lkfor[kmx,1]="qpi_data_bandwidth_tx0";
       lkfor[kmx,2]="qpi_data_bandwidth_tx1";
       nwfor[kmx,1,"hdr"]="QPI_BW (GB/sec)";
       nwfor[kmx,1,"alias"]="metric_UPI Data transmit BW (MB/sec) (only data)";
       nwfor[kmx,1,"alias_factor"]=1000.0;
       nwfor[kmx,1,"alias_oper"]="*";
     }
  
     kmx++;
     got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
     got_lkfor[kmx,2]=3; # num of fields to look for
     got_lkfor[kmx,3]= (64.0/9.0) * 1.0e-9; # a factor
     got_lkfor[kmx,4]="sum"; # operation
     got_lkfor[kmx,5]=1; # instances
     got_lkfor[kmx,6]="div_by_interval"; # 
     got_lkfor[kmx,"typ_match"]="require_any"; # 
     lkfor[kmx,1]="qpi0_data_bandwidth_tx";
     lkfor[kmx,2]="qpi1_data_bandwidth_tx";
     lkfor[kmx,3]="qpi2_data_bandwidth_tx";
     nwfor[kmx,1,"hdr"]="QPI_BW (GB/sec)";
     nwfor[kmx,1,"alias"]="metric_UPI Data transmit BW (MB/sec) (only data)";
     nwfor[kmx,1,"alias_factor"]=1000.0;
     nwfor[kmx,1,"alias_oper"]="*";
   }

   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=1; # num of fields to look for
   got_lkfor[kmx,3]=1.0; # a factor
   got_lkfor[kmx,4]="sum"; # operation
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]="div_by_interval"; # 
   lkfor[kmx,1]="power/energy-pkg/";
   nwfor[kmx,1,"hdr"]="power_pkg (watts)";
   nwfor[kmx,1,"alias"]="metric_package power (watts)";

   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=1; # num of fields to look for
   got_lkfor[kmx,3]=1.0e-9; # a factor
   got_lkfor[kmx,4]="sum"; # operation
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]="div_by_interval"; # 
   lkfor[kmx,1]=instructions_str;
   nwfor[kmx,1,"hdr"]="instructions/sec (1e9 instr/sec)";


   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=1; # num of fields to look for
   got_lkfor[kmx,3]=1.0e-9; # a factor
   got_lkfor[kmx,4]="sum"; # operation
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]="div_by_interval"; # 
   lkfor[kmx,1]=cpu_cycles_str;
   nwfor[kmx,1,"hdr"]="cpu-cycles/sec (1e9 cycles/sec)";

   if (amd_cpu == 1) {
#            "name"       : "topdown_Retiring(%)",
   kmx++;
   kkmx=0;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   got_lkfor[kmx,4]="rpn_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   # 100*${ITP_UOP}/(4*(${ITP_ANY}/${thr_per_core}))
   got_rpn_eqn[kmx, ++kkmx, "val"]=100;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=tolower("ret_uops_cycles");
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="*";   # 100 * uop_ret
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx, ++kkmx, "val"]=cpu_cycles_str;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="/";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]="ret_uops_cycles";
   lkfor[kmx,2]=cpu_cycles_str;  # get the instances from the first lkfor event
   nwfor[kmx,1,"hdr"]="topdown_Retiring(%)";
   }

   if (amd_cpu == 0) {
   kmx++;
   kkmx=0;
   lkfor[kmx,1]=instructions_str;
   lkfor[kmx,2]=tolower("CPU_CLK_UNHALTED.THREAD_ANY");  # get the instances from the first lkfor event
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   got_lkfor[kmx,4]="rpn_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   got_rpn_eqn[kmx, ++kkmx, "val"]=lkfor[kmx,1];
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=lkfor[kmx,2];
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=thr_per_core;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="/";   # clk_unh.thr_any / thr_cou
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx, ++kkmx, "val"]="/";   # instr/(clk_unh.thr_any / thr_cou)
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   nwfor[kmx,1,"hdr"]="coreIpc";
   nwfor[kmx,1,"alias"]="topdown_Info_CoreIPC";


   kmx++;
   kkmx=0;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=3; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   #got_lkfor[kmx,4]="rpn_eqn"; # operation x/y/z
   got_lkfor[kmx,4]="bc_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   # 100*${ITP_UOP}/(4*(${ITP_ANY}/${thr_per_core}))
   got_rpn_eqn[kmx, ++kkmx, "val"]=" 100.0 * ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]=tolower("UOPS_RETIRED.RETIRE_SLOTS");
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" / ( 4.0 * ( ";  
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]=tolower("CPU_CLK_UNHALTED.THREAD_ANY");
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" / ";   # 100 * uop_ret
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]=thr_per_core " ) ) ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";

   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]=tolower("UOPS_RETIRED.RETIRE_SLOTS");
   lkfor[kmx,2]=cpu_cycles_str;  # get the instances from the first lkfor event
   lkfor[kmx,3]=tolower("CPU_CLK_UNHALTED.THREAD_ANY");  # get the instances from the first lkfor event
   nwfor[kmx,1,"hdr"]="topdown_Retiring(%)";

#
#  begin tdicx topdown ice-lake sum

   kmx++;
   kkmx = 0;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=6; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   got_lkfor[kmx,4]="bc_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   got_lkfor[kmx,"tag"]="tdicx_sum";
   got_rpn_eqn[kmx, ++kkmx, "val"]="100.0 * (";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   # td_ret
   got_rpn_eqn[kmx, ++kkmx, "val"]="topdown-retiring";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" + "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   # td_fe
   got_rpn_eqn[kmx, ++kkmx, "val"]="idq_uops_not_delivered.core";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" - "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="int_misc.uop_dropping";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   # td_be
   got_rpn_eqn[kmx, ++kkmx, "val"]=" + "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="topdown-be-bound";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   # td_bs
   got_rpn_eqn[kmx, ++kkmx, "val"]=" + "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="topdown-bad-spec";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";

   got_rpn_eqn[kmx, ++kkmx, "val"]=" ) / "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="cpu/slots/";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]="topdown-retiring";
   lkfor[kmx,2]="cpu/slots/";
   lkfor[kmx,3]="idq_uops_not_delivered.core";
   lkfor[kmx,4]="int_misc.uop_dropping";
   lkfor[kmx,5]="topdown-be-bound";
   lkfor[kmx,6]="topdown-bad-spec";
   nwfor[kmx,1,"hdr"]="topdown_Sum";

#  end   tdicx topdown ice-lake sum
#


   # self.val = (EV("PERF_METRICS.RETIRING", 1) / EV("TOPDOWN.SLOTS", 1)) / PERF_METRICS_SUM(self, EV, 1) if topdown_use_fixed else EV("UOPS_RETIRED.SLOTS", 1) / SLOTS(self, EV, 1)
   #topdown-retiring
   #cpu/slots/
   kmx++;
   kkmx = 0;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   got_lkfor[kmx,4]="bc_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   got_lkfor[kmx,"tag"]="tdicx_ret";
   got_rpn_eqn[kmx, ++kkmx, "val"]="100.0 * ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="topdown-retiring";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" / "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="cpu/slots/";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]="topdown-retiring";
   lkfor[kmx,2]="cpu/slots/";
   nwfor[kmx,1,"hdr"]="topdown_Retiring(%)";

   #if (evt[tdicx_ret,1] != "" && evt[not_deliv,1] != "" && evt[uop_drop,1] != "") {
        #td_fe_v = 100.0*(evt[not_deliv,i]-evt[uop_drop,i])/evt[tdicx_slots,i];
        #td_sum = td_ret_v + td_bs_v + td_fe_v + td_be_v;
        #td_fe_v = 100.0*td_fe_v / td_sum;
   kmx++;
   kkmx = 0;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=3; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   got_lkfor[kmx,4]="bc_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   got_lkfor[kmx,"tag"]="tdicx_fe";
   got_rpn_eqn[kmx, ++kkmx, "val"]="100.0 * (";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="idq_uops_not_delivered.core";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" - "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="int_misc.uop_dropping";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" ) / "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="cpu/slots/";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]="idq_uops_not_delivered.core";
   lkfor[kmx,2]="int_misc.uop_dropping";
   lkfor[kmx,3]="cpu/slots/";
   nwfor[kmx,1,"hdr"]="topdown_Frontend_Bound(%)";


    #td_be_v = 100.0*evt[tdicx_be,i]/evt[tdicx_slots,i];
    #topdown-be-bound"
   kmx++;
   kkmx = 0;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   got_lkfor[kmx,4]="bc_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   got_lkfor[kmx,"tag"]="tdicx_be";
   got_rpn_eqn[kmx, ++kkmx, "val"]="100.0 * ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="topdown-be-bound";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" / "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="cpu/slots/";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]="topdown-be-bound";
   lkfor[kmx,2]="cpu/slots/";
   nwfor[kmx,1,"hdr"]="topdown_Backend_bound(%)";


   #uops_issued.any
   #uops_retired.retire_slots
   #int_misc.recovery_cycles_any
   kmx++;
   kkmx = 0;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   got_lkfor[kmx,4]="bc_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   got_lkfor[kmx,"tag"]="tdicx_bs";
   got_rpn_eqn[kmx, ++kkmx, "val"]="100.0 * ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="topdown-bad-spec";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" / "
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="cpu/slots/";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]="topdown-bad-spec";
   lkfor[kmx,2]="cpu/slots/";
   nwfor[kmx,1,"hdr"]="topdown_Bad_Speculation(%)";

   if (cpu_type != "Ice Lake" && got_bad_spec_evts == need_bad_spec_evts) {
   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=5; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   got_lkfor[kmx,4]="bc_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
#    bc like operations, space between all operators and values
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]="100.0 * ( ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="uops_issued.any";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" - "; 
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="uops_retired.retire_slots"; 
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" + ( ( 4.0 * ";  
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="int_misc.recovery_cycles_any";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" ) / " thr_per_core " ) ) / ( 4.0 * ( ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]=tolower("CPU_CLK_UNHALTED.THREAD_ANY");
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" / " thr_per_core " ) )"; 
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;

   lkfor[kmx,1]="uops_issued.any";
   lkfor[kmx,2]="uops_retired.retire_slots";
   lkfor[kmx,3]="int_misc.recovery_cycles_any";
   lkfor[kmx,4]=cpu_cycles_str;  # get the instances from the first lkfor event
   lkfor[kmx,5]=tolower("CPU_CLK_UNHALTED.THREAD_ANY");  # get the instances from the first lkfor event
   nwfor[kmx,1,"hdr"]="topdown_Bad_Speculation(%)";
   }

   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=3; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   got_lkfor[kmx,4]="rpn_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
#    rpn operations
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]=100;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="idq_uops_not_delivered.core";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="*";  
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx, ++kkmx, "val"]=4.0;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=tolower("CPU_CLK_UNHALTED.THREAD_ANY");
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="*";   
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx, ++kkmx, "val"]=thr_per_core;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="/"; 
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx, ++kkmx, "val"]="/";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;

   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]=tolower("IDQ_UOPS_NOT_DELIVERED.CORE");
   lkfor[kmx,2]=cpu_cycles_str;  # get the instances from the first lkfor event
   lkfor[kmx,3]=tolower("CPU_CLK_UNHALTED.THREAD_ANY");  # get the instances from the first lkfor event
   nwfor[kmx,1,"hdr"]="topdown_Frontend_Bound(%)";

#    rpn operations
#    TBD repeating this stuff for sockets. Right now (if you had per-socket data and -o dont_sum_sockets) you wouldnt match up the column header because youd have " S0" or " S1" socket suffix
   if (cpu_type != "Ice Lake" && got_bad_spec_evts == need_bad_spec_evts) {
   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=4; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   got_lkfor[kmx,4]="rpn_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]=100;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="topdown_Retiring(%)"
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="topdown_Frontend_Bound(%)"
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="+";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx, ++kkmx, "val"]="topdown_Bad_Speculation(%)"
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="+";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx, ++kkmx, "val"]="-";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]=tolower("UOPS_RETIRED.RETIRE_SLOTS");
   lkfor[kmx,2]=tolower("CPU_CLK_UNHALTED.THREAD_ANY");  # get the instances from the first lkfor event
   lkfor[kmx,3]=tolower("IDQ_UOPS_NOT_DELIVERED.CORE");
   lkfor[kmx,4]=cpu_cycles_str;  # get the instances from the first lkfor event
   nwfor[kmx,1,"hdr"]="topdown_Backend_bound(%)";
   } else {
   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=4; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
#   got_lkfor[kmx,4]="rpn_eqn"; # operation x/y/z
   got_lkfor[kmx,4]="bc_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   kkmx = 0;
#abc
   got_rpn_eqn[kmx, ++kkmx, "val"]="100.0 - ( ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="topdown_Retiring(%)"
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" + ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";
   got_rpn_eqn[kmx, ++kkmx, "val"]="topdown_Frontend_Bound(%)"
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]=" ) ";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_str";

   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]=tolower("UOPS_RETIRED.RETIRE_SLOTS");
   lkfor[kmx,2]=tolower("CPU_CLK_UNHALTED.THREAD_ANY");  # get the instances from the first lkfor event
   lkfor[kmx,3]=tolower("IDQ_UOPS_NOT_DELIVERED.CORE");
   lkfor[kmx,4]=cpu_cycles_str;  # get the instances from the first lkfor event
   nwfor[kmx,1,"hdr"]="topdown_Backend_Bound_BadSpec(%)";
   }
   }

   if (amd_cpu == 1) {
#    rpn operations
#    AMD backend bound
   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   got_lkfor[kmx,4]="rpn_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]=100;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="stalled-cycles-backend"
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="*";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx, ++kkmx, "val"]=cpu_cycles_str
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="/";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]="stalled-cycles-backend";
   lkfor[kmx,2]=cpu_cycles_str;  # get the instances from the first lkfor event
   nwfor[kmx,1,"hdr"]="topdown_Backend_Bound_BadSpec(%)";

#    AMD frontend bound
   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   got_lkfor[kmx,4]="rpn_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]=100;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="stalled-cycles-frontend"
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="*";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx, ++kkmx, "val"]=cpu_cycles_str
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="/";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]="stalled-cycles-frontend";
   lkfor[kmx,2]=cpu_cycles_str;  # get the instances from the first lkfor event
   nwfor[kmx,1,"hdr"]="topdown_Frontend_Bound(%)";

#    AMD %dispatch_stalls_0
   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   got_lkfor[kmx,4]="rpn_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]=100;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="disp_stall_cycles_0";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="*";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx, ++kkmx, "val"]=cpu_cycles_str
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="/";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]="disp_stall_cycles_0";
   lkfor[kmx,2]=cpu_cycles_str;  # get the instances from the first lkfor event
   nwfor[kmx,1,"hdr"]="%dispatch_stalls_0";

#    AMD %dispatch_stalls_1
   kmx++;
   got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
   got_lkfor[kmx,2]=2; # num of fields to look for
   got_lkfor[kmx,3]="1.0";
   got_lkfor[kmx,4]="rpn_eqn"; # operation x/y/z
   got_lkfor[kmx,5]=1; # instances
   got_lkfor[kmx,6]=""; # 
   kkmx = 0;
   got_rpn_eqn[kmx, ++kkmx, "val"]=100;
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="disp_stall_cycles_1";
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="*";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx, ++kkmx, "val"]=cpu_cycles_str
   got_rpn_eqn[kmx,   kkmx, "opr"]="push_row_val";
   got_rpn_eqn[kmx, ++kkmx, "val"]="/";
   got_rpn_eqn[kmx,   kkmx, "opr"]="oper";
   got_rpn_eqn[kmx,      1,"max"]=kkmx;
   lkfor[kmx,1]="disp_stall_cycles_1";
   lkfor[kmx,2]=cpu_cycles_str;  # get the instances from the first lkfor event
   nwfor[kmx,1,"hdr"]="%dispatch_stalls_1";
   }

   printf("perf_stat awk options= %s, skt_idx= %s\n", options, skt_idx) > "/dev/stderr";

   if (options != "" && index(options, "dont_sum_sockets") > 0) {
     kmx_nw = kmx;
     for (k=1; k <= kmx; k++) { 
        got_it=0;
        for (kk=1; kk <= got_lkfor[k,2]; kk++) {
           #printf("got lkfor[%d,%d]= %s\n", k, kk, lkfor[k,kk]) > "/dev/stderr";
           if (lkfor[k,kk] != "interval" && lkfor[k,kk] != "instances") {
             got_it = 1;
             break;
           }
        }
        if (got_it == 1) {
          for (sk=2; sk <= skt_idx; sk++) {
            #skt_lkup[skt_idx]=skt;
            kmx_nw++;
            got_lkfor[kmx_nw,1]= got_lkfor[k,1];
            got_lkfor[kmx_nw,2]= got_lkfor[k,2];
            got_lkfor[kmx_nw,3]= got_lkfor[k,3];
            got_lkfor[kmx_nw,4]= got_lkfor[k,4];
            got_lkfor[kmx_nw,5]= got_lkfor[k,5];
            got_lkfor[kmx_nw,6]= got_lkfor[k,6];
            got_lkfor[kmx_nw,"typ_match"]= got_lkfor[k,"typ_match"];
            got_lkfor[kmx_nw,"max"]= got_lkfor[k,"max"];
            got_lkfor[kmx_nw,7]= sk; # skt_idx
            got_lkfor[kmx_nw,8]= nwfor[k,1,"hdr"]; # save off original result name so we only have to ck 1 name
            for (kk=1; kk <= got_lkfor[k,2]; kk++) {
               if (lkfor[k,kk] != "interval" && lkfor[k,kk] != "instances") {
                 lkfor[kmx_nw,kk]=lkfor[k,kk] " " skt_lkup[sk];
               } else {
                 lkfor[kmx_nw,kk]=lkfor[k,kk];
               }
            }
            nwfor[kmx_nw,1,"hdr"]=nwfor[k,1,"hdr"] " " skt_lkup[sk];
            #printf("got new got_lkfor[%d,%d]= %s\n", kmx_nw, 1, nwfor[kmx_nw,1,"hdr"]) > "/dev/stderr";
          }
          for (kk=1; kk <= got_lkfor[k,2]; kk++) {
             if (lkfor[k,kk] != "interval" && lkfor[k,kk] != "instances") {
                 lkfor[k,kk]=lkfor[k,kk] " " skt_lkup[1];
             }
          }
          got_lkfor[k,7]= 1; # skt idx
          got_lkfor[k,8]= nwfor[k,1,"hdr"]; # save off original result name so we only have to ck 1 name
          nwfor[k,1,"hdr"]=nwfor[k,1,"hdr"] " " skt_lkup[1];
        }
     }
     kmx = kmx_nw;
   }

   NO_MATCH = -1000;
   for (k=1; k <= kmx; k++) { 
       for (j=1; j <= got_lkfor[k,2]; j++) { 
           lkup[k,j] = NO_MATCH;
       }
   }
   for(i=0; i <= evt_idx; i++) {
     for (k=1; k <= kmx; k++) { 
       for (j=1; j <= got_lkfor[k,2]; j++) { 
         #printf("i= %d, evt_idx= %d, k= %d, kmx= %d, j= %d, got_lkfor[%d,2]= %d, evt_lkup[i]= %s, lkfor[k,j]= %s\n",
         #   i, evt_idx, k, kmx, j, k, got_lkfor[k,2], evt_lkup[i], lkfor[k,j]) > "/dev/stderr";
         if (evt_lkup[i] == lkfor[k,j]) {
           lkup[k,j] = i
           got_lkfor[k,1]++;
         }
       }
     }
   }
   extra_cols=0;
   for (k=1; k <= kmx; k++) { 
     for (j=1; j <= got_lkfor[k,2]; j++) { 
       if ("interval" == lkfor[k,j]) {
           lkup[k,j] = -1
           got_lkfor[k,1]++;
       }
       if ("instances" == lkfor[k,j]) {
           lkup[k,j] = -2
           got_lkfor[k,1]++;
       }
       #if (nwfor[k,1,"hdr"] == lkfor[k,j]) {
       #    lkup[k,j] = -100-k
       #    got_lkfor[k,1]++;
       #}
     }
     if (got_lkfor[k,1] == got_lkfor[k,2] || (got_lkfor[k,"typ_match"] == "require_any" && got_lkfor[k,1] > 0)) {
        printf("use nwfor[%d,1,hdr]=%s, extra_cols= %d\n", k, nwfor[k,1,"hdr"], extra_cols) > "/dev/stderr";
        extra_cols++;
     }
   }
   printf("perf_stat_scatter.awk: extra_cols= %d\n", extra_cols) > "/dev/stderr";

   rows=1;
   if (options != "" && index(options, "chart_sheet") == 0) {
     # make room for a row of charts
     for(i=0; i <= 40; i++) {
       printf("\n") > out_file;
       rows++;
     }
   }
   printf("epoch\tts\trel_ts\tinstances:") > out_file;
   for(i=0; i <= evt_idx; i++) {
     printf("\t%s", evt_inst[i]) > out_file;
   }
   for (k=1; k <= kmx; k++) { 
     if (got_lkfor[k,1] == got_lkfor[k,2] || (got_lkfor[k,"typ_match"] == "require_any" && got_lkfor[k,1] > 0)) {
        printf("\t%s", got_lkfor[k,5]) > out_file;
     }
   }
   printf("\n") > out_file;
   rows++;
   rows++;
   printf("title\t%s\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet) > out_file;
   bcol = 4;
   if (options != "" && index(options, "chart_new") > 0 && extra_cols > 0) {
     bcol += evt_idx;
   }
   ts_col = 1;
   printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", rows+1, bcol, -1, evt_idx+extra_cols+4, ts_col) > out_file;
#title	sar network IFACE dev eth0	sheet	sar network IFACE	type	line
#hdrs	8	0	68	8
   bw_cols_mx = 0;
   ipc_cols_mx = 0;
   unhalted_cols_mx = 0;
   hwpf_local_cols_mx = 0;
   hwpf_remote_cols_mx = 0;
   col_hdr[0] = "epoch";
   col_hdr[1] = "ts";
   col_hdr[2] = "rel_ts";
   col_hdr[3] = "interval";
   my_hdr=sprintf("epoch\tts\trel_ts\tinterval");
   cols = 4;
   for(i=0; i <= evt_idx; i++) {
     my_hdr = my_hdr "" sprintf("\t%s", evt_lkup[i]);
     col_hdr[cols] = evt_lkup[i];
     cols++;
   }
   got_mini_ITP=0;
   got_LLC_pct_misses = -1;
   for (k=1; k <= kmx; k++) { 
     #printf("ck nwfor[%d,1]= %s, got_lkfor1= %d, got_lkfor2= %d\n", k, nwfor[k,1,"hdr"], got_lkfor[k,1], got_lkfor[k,2]) > "/dev/stderr";
     if (got_lkfor[k,1] == got_lkfor[k,2] || (got_lkfor[k,"typ_match"] == "require_any" && got_lkfor[k,1] > 0)) {
        my_hdr = my_hdr "" sprintf("\t%s", nwfor[k,1,"hdr"]);
        col_hdr[cols] = nwfor[k,1,"hdr"];
        #printf("got nwfor[%d,1]= %s\n", k, nwfor[k,1,"hdr"]) > "/dev/stderr";
        if (index(nwfor[k,1,"hdr"], "GB/s") > 0) {
          bw_cols[++bw_cols_mx] = cols;
        }
        if (index(nwfor[k,1,"hdr"], "not_halted") > 0 || index(nwfor[k,1,"hdr"], "%LLC misses") > 0 ||  index(nwfor[k,1,"hdr"], "%both_HT_threads_active") > 0) {
          unhalted_cols[++unhalted_cols_mx] = cols;
          if (index(nwfor[k,1,"hdr"], "%LLC misses") > 0) {
            got_LLC_pct_misses = k;
          }
          if (index(nwfor[k,1,"hdr"], "%both_HT_threads_active") > 0) {
            got_both_HT_threads_active = k;
          }
        }
        if (nwfor[k,1,"hdr"] == "hw prefetch remote bw (GB/s)") {
          hwpf_remote_cols[++hwpf_remote_cols_mx] = cols;
        }
        if (nwfor[k,1,"hdr"] == "hw prefetch local bw (GB/s)") {
          hwpf_local_cols[++hwpf_local_cols_mx] = cols;
        }
        if (nwfor[k,1,"hdr"] == "L3 miss latency (core_clks)") {
          L3_latency_cols[++L3_latency_cols_mx] = cols;
        }
        if (nwfor[k,1,"hdr"] == "L3 miss latency (ns)") {
          L3_latency_cols[++L3_latency_cols_mx] = cols;
        }
        if (index(nwfor[k,1,"hdr"], "not_halted") > 0 || index(nwfor[k,1,"hdr"], "topdown_") > 0 || index(nwfor[k,1,"hdr"], "power_pkg (watts)") > 0) {
          if (index(nwfor[k,1,"hdr"], "topdown_Sum") == 0) {
            topdown_var_cols[++topdown_var_cols_mx] = cols;
          }
        }
        if (index(nwfor[k,1,"hdr"], "%dispatch_stalls_") > 0) {
          topdown_var_cols[++topdown_var_cols_mx] = cols;
        }
        if (nwfor[k,1,"hdr"] == "IPC" || index(nwfor[k,1,"hdr"], "GHz") > 0 || index(nwfor[k,1,"hdr"], "PKI") > 0) {
          ipc_cols[++ipc_cols_mx] = cols;
        }
        if (got_bad_spec_evts == need_bad_spec_evts) {
        if (index(nwfor[k,1,"hdr"], "topdown_Bad_Speculation(%)") > 0) {
          ++got_mini_ITP;
          ITP_lvl[got_mini_ITP,1] = cols;
          ITP_lvl[got_mini_ITP,2] = "bs";
        }
        if (index(nwfor[k,1,"hdr"], "topdown_Backend_bound(%)") > 0) {
          ++got_mini_ITP;
          ITP_lvl[got_mini_ITP,1] = cols;
          ITP_lvl[got_mini_ITP,2] = "be";
        }
        } else {
        if (index(nwfor[k,1,"hdr"], "topdown_Backend_Bound_BadSpec") > 0) {
          ++got_mini_ITP;
          ITP_lvl[got_mini_ITP,1] = cols;
          ITP_lvl[got_mini_ITP,2] = "bs";
        }
        }

        if (index(nwfor[k,1,"hdr"], "topdown_Frontend_Bound") > 0) {
          ++got_mini_ITP;
          ITP_lvl[got_mini_ITP,1] = cols;
          ITP_lvl[got_mini_ITP,2] = "fe";
        }
        if (index(nwfor[k,1,"hdr"], "topdown_Retiring") > 0) {
          ++got_mini_ITP;
          ITP_lvl[got_mini_ITP,1] = cols;
          ITP_lvl[got_mini_ITP,2] = "ret";
        }
#       if (index(nwfor[k,1,"hdr"], "%dispatch_stalls_0") > 0) {
#         ++got_mini_ITP;
#         ITP_lvl[got_mini_ITP,1] = cols;
#         ITP_lvl[got_mini_ITP,2] = "disp_0";
#       }
#       if (index(nwfor[k,1,"hdr"], "%dispatch_stalls_1") > 0) {
#         ++got_mini_ITP;
#         ITP_lvl[got_mini_ITP,1] = cols;
#         ITP_lvl[got_mini_ITP,2] = "disp_1";
#       }
        cols++;
     }
   }
   col_hdr_mx = cols;
   printf("\t\t\t") > out_file;
   for (k=4; k <= col_hdr_mx; k++) {
        frm = sprintf("=subtotal(101, INDIRECT(ADDRESS(row()+2, column(), 1)):INDIRECT(ADDRESS(row()-1+%d, column(),1)))", row);
        printf("\t%s", frm) > out_file;
   }
   printf("\n") > out_file;
   printf("%s\n", my_hdr) > out_file;
   if (n_sum > 0) {
          for (k=0; k <= col_hdr_mx; k++) {
            hdr_lkup[k] = -1;
          }
          for (k=0; k <= col_hdr_mx; k++) {
            #printf("ck col_hdr[%d]= %s\n", k, col_hdr[k]) > "/dev/stderr";
            for (i_sum=1; i_sum <= n_sum; i_sum++) {
               if (index(col_hdr[k], sum_arr[i_sum]) > 0) {
                  hdr_lkup[k] = i_sum;
                  printf("match col_hdr[%d]= %s with sum_arr[%d]= %s\n", k, col_hdr[k], i_sum, sum_arr[i_sum]) > "/dev/stderr";
               }
            }
          }
   }
   epoch_next=0;
   ts_prev = 0.0;
   printf("perf stat rows= %d, skt_incr= %d, ts_beg= %f, ts_end= %f\n", row, skt_incr, ts_beg, ts_end) > "/dev/stderr";
   for(i=1; i <= row; i++) {
     rw_col=0;
     if (skt_incr != 0 && sv[i,2] == "S0" && i < row) {
         # sum each evt to s0 for now
         for(ii=i+1; ii <= row; ii++) {
           if (sv[ii,1] != sv[i,1]) { 
              epoch_next=sv[ii,0];
              break;
           }
           for(j=0; j <= evt_idx; j++) {
              sv[i,3+j] += sv[ii,3+j];
           }
         }
     }
     if (skt_incr != 0 && sv[i,2] != "S0") {
       continue;
     }
     interval = sv[i,1] - ts_prev;
     ts_prev = sv[i,1]
     use_epoch = sv[i,0];
     if (ts_beg > 0.0 && use_epoch < ts_beg) {
        continue; # TBD, this is a different use of tm_beg
     }
     #if (ts_beg > 0.0) {
     #   use_epoch = ts_beg + sv[i,1];
     #}
     if (ts_end > 0.0 && use_epoch > ts_end) {
       continue;
     }
     printf("%.4f\t%.3f\t%s\t%.4f", use_epoch, sv[i,1], sv[i,1], interval) > out_file;
     rw_data[rw_col++] = use_epoch;
     rw_data[rw_col++] = sv[i,1];
     rw_data[rw_col++] = sv[i,1];
     rw_data[rw_col++] = interval;
     use_row[i] = 1;
     sv_intrvl[i] = interval;
     cols = 4;
     for (k=1; k <= kmx; k++) { 
       sum[k]=0.0;
       numer[k]=0.0;
       denom[k]=0.0;
       for(j=0; j <= evt_idx; j++) {
         if (k == 1) {
           printf("\t%s", sv[i,3+j]) > out_file;
           rw_data[rw_col]  = sv[i,3+j];
           tmr_data[rw_col] = sv_tmr[i,3+j];
           rw_col++;
           do_summary(cols, sv[i,3+j]+0.0, use_epoch+0.0, interval, k);
           cols++;
         }
         if (got_lkfor[k,4] == "sum") {
           for (kk=1; kk <= got_lkfor[k,2]; kk++) { 
             if (lkup[k,kk] == NO_MATCH) { continue; }
             if (lkup[k,kk] == j) {
               sum[k] += sv[i,3+j];
             }
             if (lkup[k,kk] == -1) {
               sum[k] += interval;
             }
             if (lkup[k,kk] == -2) {
               aaa = lkup[k,1];
               sum[k] += evt_inst[aaa]; # instances
             }
           }
         }
         if (got_lkfor[k,4] == "div") {
           if (lkup[k,1] == j) { numer[k] = sv[i,3+j]; }
           if (lkup[k,2] == j) { denom[k] = sv[i,3+j]; }
           if (lkup[k,1] == -1) { numer[k] = interval; }
           if (lkup[k,2] == -1) { denom[k] = interval; }
           if (lkup[k,1] == -2) { numer[k] = evt_inst[lkup[k,1]]; }
           if (lkup[k,2] == -2) { denom[k] = evt_inst[lkup[k,1]]; }
         }
       }
     }
     for (sk=1; sk <= skt_idx; sk++) { not_halted_fctr[sk] = 0.0; }
     sv_avg_freq_ghz = 0.0;
     for (k=1; k <= kmx; k++) { 
       prt_it=0;
       if ((got_lkfor[k,4] == "div" || got_lkfor[k,4] == "div_and_by_interval") && got_lkfor[k,1] == got_lkfor[k,2]) {
         if (denom[k] <= 0.0) {
           val = 0.0;
         } else {
           val = (numer[k]/denom[k]) * got_lkfor[k,3];
         }
         if (got_lkfor[k,4] == "div_and_by_interval") {
           val /= interval;
         }
         prt_it=1;
       }

       if (got_lkfor[k,4] == "sum" && got_lkfor[k,1] > 0) {
         val = sum[k] * got_lkfor[k,3];
         prt_it=1;
       }
       if (prt_it == 1) {
         if (got_lkfor[k,6] == "div_by_interval") {
            val = val / interval;
         }
         if (index(nwfor[k,1,"hdr"], "%not_halted") == 1) {
           #printf("%not_halted 03: prt_it= %s got_lkfor[%d,%s]= %s\n", prt_it, k, 7, got_lkfor[k,7]) > "/dev/stderr";
           sk = got_lkfor[k,7];
           if (sk == "") { sk= 1; }
           not_halted_fctr[sk] = val/100.0;
           #printf("b sk= %d, nhf= %f\n", sk, not_halted_fctr[sk]) > "/dev/stderr";
         }
       }
     }
     for (k=1; k <= kmx; k++) { 
       prt_it=0;
       if (got_lkfor[k,1] == 0) {
         continue;
       }
       if (got_lkfor[k,4] == "div" && got_lkfor[k,1] == got_lkfor[k,2]) {
         if (denom[k] == 0 && lkup[k,2] == -2) {
          denom[k] = def_inst;  # this is for input data on a per process basis where instance is 0
          printf("got zero for %s k= %s, numer= %f, lkup[%d,2]= %s, lkup[k,1]= %s evt_inst[lkup[k,1]]= %s, use num_cpus= %s\n",
            nwfor[k,1,"hdr"], k, numer[k], k, lkup[k,2], lkup[k,1], evt_inst[lkup[k,1]], num_cpus) > "/dev/stderr";
         } else if (denom[k] == 0) {
          denom[k] = def_inst;  # this is for input data on a per process basis where instance is 0
          printf("got zero2 for %s k= %s, numer= %f, lkup[%d,2]= %s, lkup[k,1]= %s evt_inst[lkup[k,1]]= %s, use num_cpus= %s\n",
            nwfor[k,1,"hdr"], k, numer[k], k, lkup[k,2], lkup[k,1], evt_inst[lkup[k,1]], num_cpus) > "/dev/stderr";
         }
         val = (numer[k]/denom[k]) * got_lkfor[k,3];
         prt_it=1;
       }

       if (got_lkfor[k,4] == "sum" && got_lkfor[k,1] > 0) {
         val = sum[k] * got_lkfor[k,3];
         prt_it=1;
       }
       if (got_lkfor[k,4] == "formula" && got_lkfor[k,1] == got_lkfor[k,2]) {
         val =  got_lkfor[k,3];
         prt_it=1;
       }
       if (got_lkfor[k,4] == "rpn_eqn" && got_lkfor[k,1] == got_lkfor[k,2]) {
         val =  0.0;
         prt_it=1;
         rpn_err = "";
         rpn_sp = 0;
         val = rpn_rtn(val, k, got_rpn_eqn, col_hdr_mx, col_hdr, rw_data);
         if (rpn_err != "") {
           printf("got rpn_rtn err: %s\n", rpn_err) > "/dev/stderr";
           printf("got err for %s k= %s, numer= %f, lkup[%d,2]= %s, lkup[k,1]= %s evt_inst[lkup[k,1]]= %s, use num_cpus= %s\n",
            nwfor[k,1,"hdr"], k, numer[k], k, lkup[k,2], lkup[k,1], evt_inst[lkup[k,1]], num_cpus) > "/dev/stderr";
           prt_rpn_eqn(k);
           exit(1);
         }
       }
       if (got_lkfor[k,4] == "bc_eqn" && got_lkfor[k,1] == got_lkfor[k,2]) {
         val =  0.0;
         prt_it=1;
         bc_err = "";
         bc_sp = 0;
         val = bc_rtn(val, k, got_rpn_eqn, col_hdr_mx, col_hdr, rw_data);
         if (bc_err != "") {
           printf("got bc_rtn err: %s\n", bc_err) > "/dev/stderr";
           printf("got err for %s k= %s, numer= %f, lkup[%d,2]= %s, lkup[k,1]= %s evt_inst[lkup[k,1]]= %s, use num_cpus= %s\n",
            nwfor[k,1,"hdr"], k, numer[k], k, lkup[k,2], lkup[k,1], evt_inst[lkup[k,1]], num_cpus) > "/dev/stderr";
           prt_rpn_eqn(k);
           exit(1);
         }
         #if (got_lkfor[k,"tag"] == "L3_lat_ns") {
         #  printf("L3_lat_ns: eqn= %s = %f\n", bc_str, val);
         #}
         if (got_lkfor[k,"tag"] == "tdicx_sum") {
           tdicx_sum = val;
         }
         if (got_lkfor[k,"tag"] == "tdicx_ret" ||
             got_lkfor[k,"tag"] == "tdicx_be" ||
             got_lkfor[k,"tag"] == "tdicx_fe" ||
             got_lkfor[k,"tag"] == "tdicx_bs") {
           if (tdicx_sum > 0.0) {
             val = 100.0 * val / tdicx_sum;
           }
         }
       }
       if (prt_it == 1) {
         if (got_lkfor[k,6] == "div_by_interval") {
            val = val / interval;
         }
         if (index(nwfor[k,1,"hdr"],"%not_halted") == 1) {
           sk = got_lkfor[k,7];
           if (sk == "") { sk= 1; }
           not_halted_fctr[sk] = val/100.0;
           #printf("b sk= %d, nhf= %f\n", sk, not_halted_fctr[sk]) > "/dev/stderr";
         }
            
         if (got_lkfor[k,6] == "div_by_non_halted_interval") {
            sk = got_lkfor[k,7];
            if (sk == "") { sk= 1; }
           #not_halted_fctr[sk] = val/100.0;
            nhf = not_halted_fctr[sk];
            dnm = interval * nhf;
            if (not_halted_fctr[sk] == 0.0) {
              # you can get a ref-cycles value of 0
              val = 0.0;
            if (dnm <= 0.0) {
              printf("got denom= 0.0 for sk= %s, nhf= %f, skt_idx= %s interval= %f eqn[%d]=%s\n",
               sk, not_halted_fctr[sk], skt_idx, interval, k, nwfor[k,1,"hdr"]) > "/dev/stderr";
            }
            } else {
            val = val / (dnm);
            }
         }
         if (got_lkfor[k,"tag"] == "avg_freq_ghz") {
           sv_avg_freq_ghz = val;
         }
         if (got_lkfor[k,"max"] != "") {
             if (val > got_lkfor[k,"max"]) {
                val=0.0;
             }
         }
         printf("\t%s", val) > out_file;
         ckv = val+0.0;
         if (options_get_perf_stat_max_val == 1 && (get_ps_max[k] == "" || get_ps_max[k] < ckv)) {
            get_ps_max[k] = ckv;
         }
         rw_data[rw_col++] = val;
         do_summary(cols, val+0.0, use_epoch+0.0, interval, k);
         cols++;
       }
     }
     if (st_mx > 0 && i < row && sv[i,0]+0.0 > 0 && st_sv[1,2]+0.0 > 0.0) {
        epb = sv[i,0]+0;
        epe = epoch_next+0;
        #printf("epb= %f, epe= %f, st_mx= %d\n", epb, epe, st_mx);
        for (ii=1; ii < st_mx; ii++) {
          if (epb <= st_sv[ii,2] && st_sv[ii,2] < epe) {
              printf("\t%s", st_sv[ii,1]) > out_file;
              rw_data[rw_col++] = st_sv[ii,1];
              do_summary(cols, st_sv[ii,1]+0.0, use_epoch+0.0, interval, -1);
              cols++;
              break;
          }
        }
     }
     printf("\n") > out_file;
   }
   printf("\n") > out_file;
   if (got_mini_ITP >= 3) {
       printf("title\t%s TopLev Level 1 Percentages\tsheet\t%s\ttype\tline_stacked\n", chrt, sheet) > out_file;
       printf("hdrs\t%d\t%d\t%d\t%d\t1", rows+1, bcol, -1, evt_idx+extra_cols+4, ts_col) > out_file;
       for (i=1; i <= got_mini_ITP; i++) {
       for (j=1; j <= got_mini_ITP; j++) {
           if ((i == 1 && ITP_lvl[j,2] == "fe") || (i == 2 && ITP_lvl[j,2] == "bs") ||
               (got_mini_ITP == 3 && (i == 3 && ITP_lvl[j,2] == "ret")) ||
               (got_mini_ITP == 3 && (i == 4 && ITP_lvl[j,2] == "be")) ||
               (got_mini_ITP  > 3 && (i == 3 && ITP_lvl[j,2] == "be")) ||
               (got_mini_ITP  > 3 && (i == 4 && ITP_lvl[j,2] == "ret")) ||
               (i == 4 && ITP_lvl[j,2] == "disp_0") || (i == 5 && ITP_lvl[j,2] == "disp_1")) {
           printf("\t%d\t%d", ITP_lvl[j,1], ITP_lvl[j,1]) > out_file;
           }
       }
       }
       printf("\n") > out_file;
   }
   if (topdown_var_cols_mx > 0) {
     printf("\ntitle\t%s Top Lev: %%cpus Back/Front End Bound, Retiring\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet) > out_file;
     printf("hdrs\t%d\t%d\t%d\t%d\t%d", rows+1, bcol, -1, evt_idx+extra_cols+4, ts_col) > out_file;
     for (i=1; i <= topdown_var_cols_mx; i++) {
       printf("\t%d\t%d", topdown_var_cols[i], topdown_var_cols[i]) > out_file;
     }
     printf("\n") > out_file;
   }
   printf("got bw_cols_mx= %d\n", bw_cols_mx) > "/dev/stderr";
   if (bw_cols_mx > 0) {
     printf("\ntitle\t%s mem bw\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet) > out_file;
     printf("hdrs\t%d\t%d\t%d\t%d\t%d", rows+1, bcol, -1, evt_idx+extra_cols+4, ts_col) > out_file;
     for (i=1; i <= bw_cols_mx; i++) {
       printf("\t%d\t%d", bw_cols[i], bw_cols[i]) > out_file;
     }
     printf("\n") > out_file;
   }
   if (ipc_cols_mx > 0) {
     printf("\ntitle\t%s mem IPC, CPU freq, LLC misses\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet) > out_file;
     printf("hdrs\t%d\t%d\t%d\t%d\t%d", rows+1, bcol, -1, evt_idx+extra_cols+4, ts_col) > out_file;
     for (i=1; i <= ipc_cols_mx; i++) {
       printf("\t%d\t%d", ipc_cols[i], ipc_cols[i]) > out_file;
     }
     printf("\n") > out_file;
   }
   if (unhalted_cols_mx > 0) {
     xtra_str  = "";
     xtra_str2 = "";
     if (got_LLC_pct_misses > -1) {
       xtra_str = ", %LLC misses"
     }
     if (got_both_HT_threads_active != "") {
         xtra_str2 = ", %both_HT_threads_active";
     }
     printf("\ntitle\t%s %%cpus not halted (running)%s%s\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, xtra_str, xtra_str2, pfx, sheet) > out_file;
     printf("hdrs\t%d\t%d\t%d\t%d\t%d", rows+1, bcol, -1, evt_idx+extra_cols+4, ts_col) > out_file;
     for (i=1; i <= unhalted_cols_mx; i++) {
       printf("\t%d\t%d", unhalted_cols[i], unhalted_cols[i]) > out_file;
     }
     printf("\n") > out_file;
   }
   if (L3_latency_cols_mx > 0) {
     printf("\ntitle\t%s L3 miss latency\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet) > out_file;
     printf("hdrs\t%d\t%d\t%d\t%d\t%d", rows+1, bcol, -1, evt_idx+extra_cols+4, ts_col) > out_file;
     for (i=1; i <= L3_latency_cols_mx; i++) {
       printf("\t%d\t%d", L3_latency_cols[i], L3_latency_cols[i]) > out_file;
     }
     printf("\n") > out_file;
   }
   if (hwpf_local_cols_mx > 0 || hwpf_remote_cols_mx > 0) {
     printf("\ntitle\t%s hw prefetch bw (GB/s)\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet) > out_file;
     printf("hdrs\t%d\t%d\t%d\t%d\t%d", rows+1, bcol, -1, evt_idx+extra_cols+4, ts_col) > out_file;
     if (hwpf_local_cols_mx > 0) {
       printf("\t%d\t%d", hwpf_local_cols[1], hwpf_local_cols[1]) > out_file;
     }
     if (hwpf_remote_cols_mx > 0) {
       printf("\t%d\t%d", hwpf_remote_cols[1], hwpf_remote_cols[1]) > out_file;
     }
     printf("\n") > out_file;
   }
   write_specint_summary(sum_file);
   if (n_sum > 0) {
        printf("got perf_stat n_sum= %d\n", n_sum) > "/dev/stderr";
        for (i_sum=1; i_sum <= n_sum; i_sum++) {
           divi = sum_occ[i_sum];
           if (sum_type[i_sum] == 1) {
              divi = sum_tmax[i_sum] - sum_tmin[i_sum];
           }
           if (divi <= 0.0) {
             continue;
           }
           ky = sum_prt[i_sum];
           vl = (divi > 0 ? sum_tot[i_sum]/divi : 0.0);
           sum_tot[i_sum,"total"] = vl;
           v2 = vl;
           peak_str = "";
           if (options_get_perf_stat_max_val == 1 && sum_ps_max[i_sum,"peak"] != "") {
              v2 = sum_ps_max[i_sum,"peak"];
              sum_tot[i_sum,"total"] = v2;
              my_n = sum_ps_max[i_sum,"n"];
              my_avg = sum_ps_max[i_sum,"sum"]/my_n;
              my_stdev=sqrt((sum_ps_max[i_sum,"sum_sq"]/my_n)-(my_avg*my_avg));
              if (my_stdev == 0.0) {
                my_peak_fctr = 0.0;
              } else {
                my_peak_fctr = my_avg + 3*my_stdev;
              }
              printf("%s\t%s\t%f\t%s avg\n", sum_res[i_sum], "perf_stat", my_avg, ky) >> sum_file;
              printf("%s\t%s\t%f\t%s stdev\n", sum_res[i_sum], "perf_stat", my_stdev, ky) >> sum_file;
              printf("%s\t%s\t%f\t%s avg+3stdev\n", sum_res[i_sum], "perf_stat", my_peak_fctr, ky) >> sum_file;
              peak_str = " peak";
           }
           if (options_get_pxx_stats == 1 && pxx_stats[i_sum,"n"] != "") {
             dist_file = sum_file;
              my_n = pxx_stats[i_sum,"n"];
              my_sum = 0.0;
              my_pk = 0;
              for (ii=1; ii <= my_n; ii++) {
                v = pxx_stats[i_sum,"vals",ii];
                my_sum += v;
                if (ii == 1 || my_pk < v) { my_pk = v;}
              }
              v2 = my_pk;
              printf("%s\t%s\t%f\t%s val_arr", sum_res[i_sum], "perf_stat", my_n, ky) >> dist_file;
              for (ii=1; ii <= my_n; ii++) {
                printf("\t%f", pxx_stats[i_sum,"vals",ii]) >> dist_file;
              }
              printf("\n") >> dist_file;
              #printf("%s\t%s\t%f\t%s avg+3stdev\n", sum_res[i_sum], "perf_stat", my_peak_fctr, ky) >> sum_file;
              if (my_n > 0) {
                printf("%s\t%s\t%f\t%s%s\n", sum_res[i_sum], "perf_stat", my_sum/my_n, ky, " avg") >> sum_file;
              }
              peak_str = " peak";
           }
           printf("got perf_stat %s\t%f\tsum_tot= %s\n", ky, v2, sum_tot[i_sum]) > "/dev/stderr";
           printf("%s\t%s\t%f\t%s%s\n", sum_res[i_sum], "perf_stat", v2, ky, peak_str) >> sum_file;
           if (sum_k_idx[i_sum] == mem_bw_kmx) {
             mem_bw_val = v2;
           }
        }
   }
   # print the computed columns which arent referenced in the sum_flds input list (and probably already printed out)
   for (k=1; k <= kmx; k++) {
     if (got_lkfor[k,1] == 0) {
        # no events found for this one
        continue;
     }
     if (nwfor[k,2] == 0 && nwfor[k,4] > 0) {
        ky = nwfor[k,1,"hdr"];
        vl = nwfor[k,3] / nwfor[k,4];
        if (options_get_perf_stat_max_val == 1 && get_ps_max[k] != "") {
            vl = get_ps_max[k];
        }

        printf("%s\t%s\t%f\t%s\n", "average", "perf_stat", vl, ky) >> sum_file;
        if (k == mem_bw_kmx) {
          mem_bw_val = vl;
        }
        if (nwfor[k,1,"alias"] != "") {
           if (nwfor[k,1,"alias_i_sum"] != "") {
              i_sum = nwfor[k,1,"alias_i_sum"];
              if (sum_occ[i_sum] == 0) {
                continue;
              }
              vl = sum_tot[i_sum,"total"];
           }
           if (nwfor[k,1,"alias_oper"] != "") {
              if (nwfor[k,1,"alias_oper"] == "*" && nwfor[k,1,"alias_factor"] != "") {
                 vl *= nwfor[k,1,"alias_factor"];
              }
              if (nwfor[k,1,"alias_oper"] == "inverse") {
                 if (vl != 0.0) {
                   vl = 1.0/vl;
                 } else {
                   vl = 0.0;
                 }
              }
           }
           printf("%s\t%s\t%f\t%s\n", "itp_metric2", "perf_stat", vl, nwfor[k,1,"alias"]) >> sum_file;
           nwfor[k,1,"alias_done"] = 1;
        }
     }
     if (nwfor[k,1,"alias"] != "" && nwfor[k,1,"alias_done"] != 1) {
        ky = nwfor[k,1,"hdr"];
        vl = 0.0;
        if (nwfor[k,4] > 0) {
           vl = nwfor[k,3] / nwfor[k,4];
        }
        if (nwfor[k,1,"alias_i_sum"] != "") {
           i_sum = nwfor[k,1,"alias_i_sum"];
           if (sum_occ[i_sum] == 0) {
             continue;
           }
           vl = sum_tot[i_sum,"total"];
        } else {
           if (nwfor[k,4] == 0) {
              continue;
           }
        }
        if (nwfor[k,1,"alias_oper"] != "") {
           if (nwfor[k,1,"alias_oper"] == "*" && nwfor[k,1,"alias_factor"] != "") {
              vl *= nwfor[k,1,"alias_factor"];
           }
           if (nwfor[k,1,"alias_oper"] == "inverse") {
              if (vl != 0.0) {
                 vl = 1.0/vl;
              } else {
                 vl = 0.0;
              }
           }
        }
        printf("%s\t%s\t%f\t%s\n", "itp_metric3", "perf_stat", vl, nwfor[k,1,"alias"]) >> sum_file;
     }
   }
   if (got_add_all_to_summary == 1) {
      sm2 = 0.0;
      n   = 0;
      for (i=1; i <= row; i++) {
        if (use_row[i] == 1) {
         sm2 += sv_intrvl[i];
         n++;
        }
      }
      avg = 0;
      if (n > 0) {
        avg = sm2 / n;
        #avg = sm2
      }
      printf("%s\t%s\t%d\t%s\n", "average", "entries",  n, "entries") >> sum_file;
      printf("%s\t%s\t%f\t%s\n", "average", "interval", avg, "avg.interval") >> sum_file;
    for (k=0; k <= evt_idx; k++) {
      sm2 = 0.0;
      n   = 0;
      for (i=1; i <= row; i++) {
        if (use_row[i] == 1) {
          sm2 += sv[i,k+3];
          n++;
        }
      }
      avg = 0;
      if (n > 0) {
        avg = sm2 / n;
      }
      printf("%s\t%s\t%f\t%s\n", "average", "perf_stat", avg, evt_lkup[k]) >> sum_file;
    }
   }
   if (memch_mx > 0) {
      printf("%s\t%s\t%d\t%s\n", "itp_metric2", "perf_stat", memch_mx, "mem_channels") >> sum_file;
      if (mem_speed_mhz != "" && num_sockets != "") {
         v = 0.001 * mem_speed_mhz * 8 * memch_mx * num_sockets;
         printf("%s\t%s\t%.3f\t%s\n", "itp_metric2", "perf_stat", v, "max_theoretical_mem_bw(GB/s)") >> sum_file;
         if (mem_bw_val != "" && mem_bw_val > 0.0 && v > 0.0) {
           printf("%s\t%s\t%.3f\t%s\n", "itp_metric2", "perf_stat", mem_bw_val, "used_mem_bw(GB/s)") >> sum_file;
           printf("%s\t%s\t%.3f\t%s\n", "itp_metric2", "perf_stat", 100.0 * mem_bw_val / v, "%used_bw_of_max_theoretical_mem_bw") >> sum_file;
           #printf("%s\t%s\t%.3f\t%s\n", "itp_metric2", "perf_stat", mem_bw_val, "%used_bw_of_max_possible_mem_bw") >> sum_file;
         }
      }
   }
   close(out_file);
}
