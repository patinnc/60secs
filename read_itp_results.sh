#!/bin/bash

IN_FILE=$1

if [ "$1" == "" ]; then
  echo "missing results.csv path filename"
  exit
fi

if [ ! -e $IN_FILE ]; then
  echo "didn't find file $IN_FILE"
  exit
fi

awk '
  BEGIN{
    skip=1;
  }
  /TSC Frequency.MHz.,/ {
     n = split($0, arr, ",");
     GHz = arr[2]*0.001;
     printf("tsc= %s, GHz= %f\n", arr[2], GHz);
  }
  /^CPU count,/ {
     n = split($0, arr, ",");
     cores_per_skt = arr[2]+0;
  }
  /^SOCKET count,/ {
     n = split($0, arr, ",");
     skts = arr[2]+0;
  }
  /^HT count,/ {
     n = split($0, arr, ",");
     thrds_per_core = arr[2]+0;
     tot_cpus = cores_per_skt * skts * thrds_per_core;
  }
  
  /^### PERF DATA ###,/ {
    skip = 0;
    next;
  }
  {
    if (skip == 1) {
      next;
    }
  }
  {
     if (index($0, "not counted") > 0) {
       next;
     }
     n = split($0, arr, ",");
     tm_off = arr[1]+0.0;
     evt = arr[4];
     intrvl = arr[5] * 1.0e-9;
     pct = arr[6] + 0.0;
     val = arr[2] * 0.01 * pct;
     if (!(evt in evt_list)) {
        evt_list[evt] = ++evt_max;
        evt_lkup[evt_max] = evt;
     }
     evt_i = evt_list[evt];
     evt_arr[evt_i,"tot"] += val;
     evt_arr[evt_i,"n"]++;
     evt_arr[evt_i,"tm"] += intrvl;
     evt_arr[evt_i,"tm2"] += 0.01*pct*intrvl;
     #if (tm_off > 2600.0 && tm_off < 2602.0 && (evt == "cpu-cycles" || evt == "ref-cycles")){
     #if (tm_off > 480.0 && tm_off < 482.0 && (evt == "ref-cycles")){
     if (tm_off > 2600.0 && tm_off < 2602.0 && (evt == "ref-cycles")){
        cv = 1e-9 * val/tot_cpus;
        xp = GHz * intrvl/tot_cpus;
        printf("cv tm_off= %f evt= %s, intrvl= %f, cv= %f exp= %f ratio= %f rec= %s\n", tm_off, evt, intrvl/tot_cpus, cv, xp, cv/xp, $0);
     }
     if (evt == "instructions" && pre_prev_evt == "cpu-cycles") {
        cavg = pre_prev_val/pre_prev_tm;
        iavg = val/intrvl;
        if (iavg > 0.0) {
        cpi_det[++cpi_mx] = cavg/iavg;
        cpi_sum += cavg/iavg;
        } else {
           printf("zero for instr? line= %s %s\n", FNR, $0);
        }
     }
     pre_prev_evt = prev_evt;
     pre_prev_val = prev_val;
     pre_prev_tm = prev_tm;
     prev_evt = evt;
     prev_val = val;
     prev_tm  = intrvl;
  }
  END{
    printf("cpi_avg= %f\n", cpi_sum/cpi_mx);
    lst[1]=evt_list["CPU_CLK_UNHALTED.THREAD_ANY"];
    lst[2]=evt_list["instructions"];
    lst[3]=evt_list["cpu-cycles"];
    lst[4]=evt_list["ref-cycles"];
    ea = 1;
    ei = 2;
    ec = 3;
    er = 4;
    for (i=1; i <= 4; i++) {
      j = lst[i];
      tot = 1.0e-9 * evt_arr[j,"tot"];
      tm  =  evt_arr[j,"tm"];
      n  =  evt_arr[j,"n"];
      val = tot/tm;
      #val = val/n;
      varr[i,1] = val;
      varr[i,"ps"] = val;
      varr[i,"n"] = n;
      varr[i,"tot"] = tot;
      varr[i,"tm"] = tm;
      printf("Bill %s/s/cpu= %f, tot= %f\n", evt_lkup[j], val, val*tot_cpus);
      if (i == er) {
         xp = GHz * tm;
         printf("tot= %f, tm= %f, ref-cycle/s=tot/tm= %f, tot_cpus= %d, GHz= %f n= %d exp_cpu_cycles/cpu= %f, varr[er,1]= %f\n", tot, tm, tot/tm, tot_cpus, GHz, n, xp, varr[er,1]);
         util = tot/xp;
         printf("%%util= %f, ref_freq= %f, avg_freq= %f\n", 100.0*util, tot/tm/util, varr[ec,1]/util);
         if (1==20) {
            # this method, sort of works but it uses cycles values that are sometimes not collected at the same time (not in the same group) as the instructions.
            # I weight each value by number of collections or by the time of collection and the value is close to the "cpi avg" above but I prefer the "both collected in same group".
            # For example, below gives 1.24 vs cpi_avg above givs 1.31 for mixed/lab_b19a_mixed12_omnetpp_xalancbmk_perlbench_48cpus_2x12_2x6_2x6_Aug11_n3/20200813_132545_itp/result.csv 
            cavg = varr[ec,"tot"]/varr[ec,"n"];  # weighted by number of samples
            iavg = varr[ei,"tot"]/varr[ei,"n"];
            cpi2 = varr[ec,"ps"]/varr[ei,"ps"];  # weighted by time sampling the event
            printf("CPI= %f, cavg= %f, iavg= %f, cpi2= %f\n", cavg/iavg, cavg, iavg, cpi2);
         }
         cavg  = varr[ec,"ps"];  # weighted by number of samples
         iavg  = varr[ei,"ps"];
         htavg = varr[ea,"ps"];
         coreIPC = iavg*(thrds_per_core/htavg);
         printf("coreIPC= %f, cavg= %f, iavg= %f, htavg= %f, instr/s using cIPC= %f\n", coreIPC, cavg, iavg, htavg, coreIPC*tot_cpus*varr[ea,"ps"]/thrds_per_core);
      }
    }
    #printf("last tm= %f, tot_instr_tm= %f tm2= %f\n", tm, tot_tm, tot_tm2);
  }
  ' $IN_FILE
    
