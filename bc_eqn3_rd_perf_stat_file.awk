
function ck_tm(tm) {
   if (!(tm in tm_list)) {
     tm_list[tm] = ++tm_mx;
     tm_lkup[tm_mx] = tm;
     #printf("new tm= %s\n", tm);
     return tm_mx;
   } else {
     return tm_list[tm];
   }
}
BEGIN{
    if (bc_eqn3_lscpu_info != "") {
      n = split(bc_eqn3_lscpu_info, arr, ",");
      for (i=1; i < n; i+=2) {
        bc_eqn_glbl_var_arr[arr[i]] = arr[i+1];
        if (arr[i] == "num_cpus") { num_cpus = arr[i+1]; }
        else if (arr[i] == "tsc_freq") { tsc_freq = arr[i+1]; }
        if (verbose > 0) {
        printf("bc_eqn_glbl_var_arr[%s]= %s\n", arr[i], arr[i+1]);
        }
      }
      if (bc_eqn_glbl_var_arr["arch"] == "aarch64" && arm_cpu_freq == "" && bc_eqn_glbl_var_arr["cpu_max_ghz"] != "") {
        arm_cpu_freq = bc_eqn_glbl_var_arr["cpu_max_ghz"];
        bc_eqn_glbl_var_arr["arm_cpu_freq"] = arm_cpu_freq;
      }
    }
    if (index(bc_eqn3_options, "no_aliases") == 0) {
      n_aliases = split("qpi[0-0]+_data_bandwidth_tx,qpi_data_bandwidth_tx[0-9]+,unc[0-9]+_read_write,cpu-cycles,cpu_clk_unhalted.thread,msr/aperf/,msr/mperf/,cpu/cycles/,cpu/ref-cycles/," \
         "inst_retired.any, cpu_clk_thread_unhalted.one_thread_active, cpu_clk_thread_unhalted.ref_xclk_any, cpu_clk_thread_unhalted.ref_xclk", arr1, ",");
      n         = split("qpi_data_bandwidth_txx,     qpi_data_bandwidth_txx,       uncx_read_write,   cycles,    cycles,                cycles,    ref-cycles, cycles,     ref-cycles,     " \
         "inst_retired.any, cpu_clk_unhalted.one_thread_active,        cpu_clk_unhalted.ref_xclk_any,        cpu_clk_unhalted.ref_xclk", arr2, ",");
      if (n_aliases != n) {
        printf("number of aliases must match, got n1_aliases= %d, n2_aliases= %d\n", n_aliases, n) > "/dev/stderr";
        exit(1);
      }
      for (i=1; i <= n_aliases; i++) {
        v1 = tolower(arr1[i]);
        v2 = tolower(arr2[i]);
        gsub(/^[ ]+/, "", v1);
        gsub(/^[ ]+/, "", v2);
        gsub(/[ ]+$/, "", v1);
        gsub(/[ ]+$/, "", v2);
        aliases[v1] = v2;
        aliases_old[i] = v1;
        aliases_new[i] = v2;
      }
      if (verbose > 0) {
        printf("n_aliases= %d\n", n_aliases);
      }
    }
    if (pcg_list != "") {
      gsub(" ", "", pcg_list);
      n = split(pcg_list, arr, ",");
      for (i=1; i <= n; i++) {
        cpu_list[arr[i]+0] = arr[i] + 0;
      }
    }
    fmt_mode = "csv";
    typ_interval = 0
    typ_interval_just_1 = 1;
    typ_interval_over_tm= 2;
    monitor_what = "";
    rec_num=0;
    tm_tot = 0;
    while ((getline < bc_eqn3_infile) > 0) {
       if ($1 == "#" && $2 == "time" && $3 == "counts") {
           fmt_mode = "human";
       }
       if (length($0) == 0 || substr($1,1,1) == "#") { continue; }

       if ($0 ~ / Performance counter stats /) { # for process id 40516:
         fmt_mode = "human"; # human formatted (not -x ";")
         if (index($0, "for process") > 0) {
           monitor_what = "per_pid";
         } else {
           # doing whole system
           monitor_what = "per_sys";
           if (bc_eqn_glbl_var_arr["thr_per_core"] == 1) {
             monitor_what = "per_pid";
           }
         }
         continue;
       }
       if (index($0, ";") > 0) {
# multiple intervals
#     1.016184341;48289.92;msec;cpu-clock;48289934291;100.00;48.290;CPUs utilized
# just one interval
#239588.25;msec;cpu-clock;239588243270;100.00;47.856;CPUs utilized
         if (1==2 && index($0, "cpu-clock") > 0) {
           nn = split($0, brr, ";");
           if (brr[4] == "cpu-clock") {
             tm_col = 0;
             tot_tm_elap = brr[1]+0.0;
             if ( fmt_mode != "human") {
               tm_tot = tot_tm_elap;
               bc_eqn_glbl_var_arr["interval"] = tm_tot;
             }
             #printf("elap_tm= %f\n", tot_tm_elap);
           }
         }
         if (index($0, "duration_time") > 0 || index($0, "cpu-clock") > 0) {
           nn = split($0, brr, ";");
           # [tm_col;][CPUxx;]evt_val;units;evt_name[;#[;metrics...]]
           for (i=1; i <= nn; i++) {
             if (brr[i] != "" && substr(brr[i], 1,3) == "CPU") {
                 cpu_col = i;
                 col_cpu = i;
             }
             if (brr[i] == "duration_time" || brr[i] == "cpu-clock") {
                 col_evt_nm = i;
                 col_units  = i - 1;
                 col_values = i - 2;
                 if (i == 5) {
                     if (col_cpu != 2) {
                       printf("bc_eqn: something wrong, got duration_time string in col %d but cpu_col= %s (didnt find CPUxx col). line= %s. forcing div by zero err. bc_eqn3_infile=%s\n", i, col_cpu, $0, bc_eqn3_infile);
                       printf("bc_eqn: something wrong, got duration_time string in col %d but cpu_col= %s (didnt find CPUxx col). line= %s. forcing div by zero err. bc_eqn3_infile=%s\n", i, col_cpu, $0, bc_eqn3_infile) > "/dev/stderr";
                       fflush();
                       #err_div_by_zero = 1;
                       #printf("dummy for an error by div by zero = %f\n", 1/0);
                       #exit(1);
                     } else {
                       col_tm = 1;
                     }
                 }
                 if (i == 4) {
                     # 1.014218244;1014218244;ns;duration_time;1014218244;100.00;20.854;M/sec
                     if (col_cpu == "") {
                       col_tm = 1;
                     }
                 }
                 if (i == 3) {
                     if ((col_cpu+0) > 0) {
                       printf("bc_eqn: something wrong, got duration_time string in col %d but cpu_col= %s (found CPUxx col). line= %s. forcing div by zero err. file= %s\n", i, col_cpu, $0, bc_eqn3_infile);
                       printf("bc_eqn: something wrong, got duration_time string in col %d but cpu_col= %s (found CPUxx col). line= %s. forcing div by zero err. file= %s\n", i, col_cpu, $0, bc_eqn3_infile) > "/dev/stderr";
                       fflush();
                       err_div_by_zero = 1;
                       #printf("dummy for an error by div by zero = %f\n", 1/0);
                       #exit(1);
                     } else {
                       col_tm  = -1;
                       col_cpu = -1;
                     }
                 }
                 if (brr[i] == "duration_time") {
                     dura_tm_recs++;
                     if (col_tm > 0) {
                         dura_tm[dura_tm_recs] = arr[col_tm];
                     } else {
                         v = arr[col_values];
                         dura_tm_cumu += v;
                         dura_tm[dura_tm_recs] = dura_tm_cumu;
                     }
                 }
             }
           }
         }
       }
       if (index($0, "seconds time elapsed") > 0) {
         tot_tm_elap = $1+0.0;
         tm_tot = tot_tm_elap;
         bc_eqn_glbl_var_arr["interval"] = tm_tot;
         print $0;
         break;
       }
    }
    close(bc_eqn3_infile);
    if (verbose > 0) {
      printf("fmt_mode= %s\n", fmt_mode);
    }
}

  FILENAME == bc_eqn3_infile && $0 ~ /not counted|not supported| Performance counter stats |seconds time elapsed / {
    next;
  }
  FILENAME == bc_eqn3_infile {
    if (length($0) == 0 || substr($1,1,1) == "#") {
      if ($0 ~ /^# started on / && NF == 10) {
        bc_eqn3_epoch_time_beg = $NF
        printf("epoch_time_beg = %s\n", $NF) > "/dev/stderr";
      }
      next; 
    }
  }

#         10,000.62 msec cpu-clock                 #    2.000 CPUs utilized
#    31,915,367,198      msr/aperf/                # 3191.338 M/sec      
#    21,989,149,074      msr/mperf/                # 2198.778 M/sec    
#    39,252,077,085      instructions                                                  (55.45%)
#    20,972,403,023        uops_executed.cycles_ge_1_uop_exe #   87.536 M/sec                    (50.01%)                                                                              
#            401.98 Joules power/energy-pkg/         #    0.002 K/sec
#         5,550,474        unc0_read_write           #    0.023 M/sec

  FILENAME == bc_eqn3_infile && ($0 ~ /;/ || fmt_mode == "human") {
    if (fmt_mode == "human") {
      if (index($0, "seconds time elapsed") > 0) {
        next;
      }
      if (NF == 3 && $2 == "seconds" && ($3 == "user" || $3 == "sys")) {
          next;
      }

      if (NF == 0 || substr($1, 1, 1) == "#") {
        next;
      }
      got_pound = 0;
      for (i=1; i <= NF; i++) {
        if (i <= 2 && substr($i, 1, 3) == "CPU") {
            cpu_col = i;
            if (i == 2) {
                col_tm = 1;
            } else {
                col_tm = -1;
            }
        }
        if ($i == "#") {
          got_pound = i;
          continue;
        }
      }
      #if (v1 == 0 && (arr[2] == "" || arr[2] ~ /^[a-z]/)) 
      if (got_pound > 0) {
        e_i = got_pound -1;
      } else if (substr($NF, 1,1) == "(") {
        e_i = NF - 1;
      } else {
        e_i = NF;
      }
      col_evt_nm = e_i;
      n = 0;
      i = 1;
      #val = $1;
      evt = $(e_i);
      # get the pct of time this event actually measured.
      e_p = 0;
      if (substr($NF, 1,1) == "(") {
        e_p = NF;
      }
      if (e_p > 0) {
         pct = substr($(e_p), 2, length($(e_p))-2) + 0.0;
      } else {
         pct = 100.0;
      }
      e_u = 0;
      v = $(e_i-1); # fld before evt
      if (substr(v, 1,1)  ~ /[0-9]/) {
        # starts with a number... so its the value
        col_units = -1;
        unit = "";
        e_v  = e_i - 1;
        col_values = col_evt_nm - 1;
        val  = $(e_v);
      } else {
        col_units  = col_evt_nm - 1;
        col_values = col_units - 1;
        e_u  = e_i - 1;
        e_v  = e_u - 1;
        unit = $(e_u);
        val  = $(e_v);
      }
      e_t = 0;
      e_c = 0;
      v_tm = "";
      v_cpu = "";
      if (e_v == 3) {
        # if values are in col 3 then 1st col must be end_time of this interval and 2nd col must be CPUxx
        e_c = 2;
        e_t = 1;
        col_cpu = e_c;
        col_tm  = e_t;
        v_cpu = $(e_c);
        v_tm  = $(e_t);
      } else if (e_v == 2) {
        # if values are in col 2 then 1st col might be end_time of this interval or CPUxx (if only 1 interval)
        if (substr($1, 1, 3) == "CPU") {
          e_c = 1;
          v_cpu = $(e_c);
          col_cpu = e_c;
          col_tm  = -1;
        } else {
          e_t = 1;
          v_tm  = $(e_t);
          col_cpu = -1;
          col_tm  = e_t;
        }
      }
      n = 0;
      if (e_t > 0) { # if got end time of this interval
        arr[++n] = v_tm;
      }
      # else {
      #  arr[++n] = tot_tm_elap;
      #}
      if (e_c > 0) {
        arr[++n] = v_cpu;
      }
      gsub(/,/, "", val);
      arr[++n] = val
      if (col_units > 0) {
         arr[++n] = unit;
      }
      arr[++n] = evt;
      arr[++n] = ""; # nanoseconds the evt was collected
      arr[++n] = pct;
      str = "";
      strd = "";
      for(i=1; i <= n; i++){
        str = str strd arr[i];
        strd = ";";
      }
      $0 = str;
      $1 = str;
      if (verbose > 0) {
      printf("tm_tot= %s n= %d v_tm= %s v_cpu= %s val= %s unit= %s evt= %s pct= %s, str= %s\n", tm_tot, n, v_tm, v_cpu, val, unit, evt, pct, str);
      }
      #printf("based on human parse evt: col_tm= %s col_cpu= %s col_values= %s col_units= %s col_evt_nm= %s tm_tot= %f str= %s\n", col_tm, col_cpu, col_values, col_units, col_evt_nm, tm_tot, str);
        
      
      if (1==2) {
      arr[++n] = sprintf("%.0f", 0.01e9 * pct * tot_cpus_utilized * tot_tm_elap);
      arr[++n] = pct;
      got_pound = 0;
      for (i=3; i <= NF; i++) {
        if ($i == "#") {
          got_pound = 1;
          continue;
        }
        if (got_pound == 0) {
          continue;
        }
        if (got_pound == 1) {
          arr[++n] = $(i);
          if (i != NF) { ++n;}
          ++got_pound;
          dlm = "";
          continue;
        }
        arr[n] = arr[n] dlm $i;
        dlm = " ";
      }
      }
      if(1==2 && index($0, "mperf") > 0) {
      printf("line orig= %s\n", $0);
      printf("line now =");
      for(i=1; i <= n; i++) {printf("arr[%d]=%s\n",i, arr[i]);}
      }
    } else {
      n = split($1, arr, ";");
    }
    ++rec_num;
    if (1==2 && rec_num == 1) {
      # dont handle if 1st field is CPUxx field
#239627.82;msec;cpu-clock;239627851474;100.00;47.861;CPUs utilized
#4999.99;msec;cpu-clock;4999995441;100.00;1.000;CPUs utilized
#15909855795;;msr/aperf/;4999996839;100.00;3181.976;M/sec
#10987308158;;msr/mperf/;5000008876;100.00;2197.465;M/sec
      # see if this is just a total for the whole run (no timestamp as 1st field)
      v0 = arr[1]+0.0;
      v1 = arr[2]+0.0;
      #printf("1st rec, v0= %s, v1= %s\n", v0, v1);
      if (v1 == 0 && (arr[2] == "" || arr[2] ~ /^[a-z]/)) {
        # no time field in 1st col
        if (n >= 4) {
          if (fmt_mode != "human") {
            tm_tot = 0.001 * arr[1];
          }
          if (arr[3] == "cpu-clock" && n >= 6) {
            tm_cpu_secs = tm_tot;
            if (fmt_mode != "human") {
              tm_tot = tm_tot/arr[6];
              bc_eqn_glbl_var_arr["interval"] = tm_tot;
            }
            printf("tm_tot= %f, tm_cpu_secs= %f arr[1]= %s\n", tm_tot, tm_cpu_secs, arr[1]);
            printf("num_cpus= %s tsc_freq= %s\n", num_cpus, tsc_freq);
          }
        }
      }
    }
    if (arr[col_evt_nm] == "duration_time") {
        duration_tm_evt_n++;
        tm_tot = arr[col_values] * 1e-9;
        #tot_tm_elap += tm_tot;
        bc_eqn_glbl_var_arr["interval"] = tm_tot;
        #printf("tm from duration_time= %f\n", tm_tot);
    }
    #cpu_col=0;
    if (col_cpu > 0 && n > 2 && index(arr[col_cpu], "CPU") == 1) {
      #cpu_col=1;
      cpu_num= substr(arr[col_cpu], 4, length(arr[col_cpu])) + 0;
      if (pcg_list != "" && cpu_list[cpu_num] == "") {
        skp_cpu[cpu_num] = 1;
        next;
      }
    }
    #  some events are alternative ways to get the same count (like msr/aperf/ is same as cycles (but msr/aperf/ doesnt use up an event counter)
    evt = tolower(arr[col_evt_nm]);
    evt_orig = evt;
    if (!(evt_orig in evt_orig_list)) {
      evt_orig_list[evt_orig] = ++evt_orig_mx;
      evt_orig_lkup[evt_orig_mx] = evt_orig;
      nw_evt = "";
      if (evt in aliases) {
          nw_evt = aliases[evt];
      } else {
        for (i=1; i <= n_aliases; i++) {
          if (index(aliases_old[i], "[") > 0 && evt ~ aliases_old[i]) {
            nw_evt = aliases_new[i];
            break;
          }
        }
      }
      if (nw_evt == "") {
        # no alias found
        nw_evt = evt;
      }
      # alias found or not. Need to check that this new evt isn't the same as another evt already in the input file.
      # For instance, "cycles" event can be gotten from  msr/aperf/ or cycles or cpu/cycles/.
      # If we have both cycles and msr/aperf/ in the perf data and we alias msr/aperf/ to cycles then we'll double count cycles.
      # if the nw_evt name is already in evt_list then we are adding a name thats already been seen.
      # so give the new evt and new name
      if (evt_orig in evt_list) {
        nw_evt = nw_evt "_" evt_orig_mx;
        printf("already have event %s in list so rename orig evt %s to %s\n", evt, evt_orig, nw_evt);
      }
      evt_orig_2_new[evt_orig] = nw_evt;
    }
    evt = evt_orig_2_new[evt_orig];
    if (!(evt in evt_list)) {
      evt_list[evt] = ++evt_mx;
      evt_lkup[evt_mx] = evt;
      evt_orig_nm[evt_mx] = evt_orig;
      bc_eqn_col_hdr[evt_mx] = evt;
      bc_eqn_col_hdr_mx = evt_mx;
      if (verbose > 0) {
      printf("added evt[%d]= %s, cpu_col= %d, coltm= %d idx= %d line= %s\n", evt_mx, evt, col_cpu, col_tm, col_evt_nm, $0);
      }
    }
    evt_i = evt_list[evt];
    if (evt_i != 0) {
      #cpu_col=0;
      #if (index(arr[col_cpu], "CPU") == 1) {
      #  cpu_col=1;
      #}
      if ((col_tm == -1 || col_tm == "" ) && tm_tot > 0) {
        tm_i = ck_tm(tot_tm_elap);
      } else {
        tm_i = ck_tm(arr[col_tm]);
      }
      if (verbose > 0) {
      printf("tm_lkup[%s]= %s col_tm= %s tm_tot= %s tot_tm_elap= %s  v= %s, e= %s, line= %s\n", tm_i, tm_lkup[tm_i], col_tm, tm_tot, tot_tm_elap, arr[col_values], arr[col_evt_nm], $0);
      }
      evt_data[evt_i,tm_i]          += arr[col_values];
      bc_eqn_row_data[evt_i]        += arr[col_values];
      evt_data[evt_i,tm_i,"inst"]++;
      evt_data[evt_i,tm_i,"ns"]     += arr[col_evt_nm+1];
      evt_data[evt_i,tm_i,"multi"]   = arr[col_evt_nm+2];
      evt_data[evt_i,"tot"]         += arr[col_values];
      evt_data[evt_i,"tot","inst"]++;
      evt_data[evt_i,"tot","ns"]    += arr[col_evt_nm+1];
      evt_data[evt_i,"tot","multi"]  = arr[col_evt_nm+2];
    }
    next;
  }
  END{
      #if (err_div_by_zero == 1) {
      #  printf("dummy div by zero= %f\n", 1/0);
      #}
      ;
  }
