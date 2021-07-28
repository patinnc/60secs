#!/bin/bash

thr_per_core=2

while getopts "hc:f:t:" opt; do
  case ${opt} in
    c )
      CPU_GROUP=$OPTARG
      ;;
    f )
      FILE_IN=$OPTARG
      ;;
    t )
      THR_PER_CORE_IN=$OPTARG
      ;;
    h )
      echo "$0 -f sys_perf_stat_event_file [ -t threads_per_core ] to compute some metrics"
      echo " Usually this is a perf stat file created by 60secs/do_perf3.sh "
      echo "   -c cpu_group select string. select line from perf_cpu_groups.txt file. Like 'perl' selects the cpus which ran perl. Assumes perf stat data is by cpu"
      echo "   -f sys_perf_stat_event_file"
      echo "   -t threads_per_core. Default is 2. This option lets you override the thr_per_core variable in topdown equations"
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

INFILE=$FILE_IN
if [ "$INFILE" == "" ]; then
  echo "-f filename1 arg must be perf stat output file"
  exit 1
fi
if [ ! -e $INFILE ]; then
  echo "perf_stat file -f $INFILE not found"
  exit 1
fi
if [ -d  $INFILE ]; then
  DIR0=$INFILE
  ARR=(`find $INFILE -name "sys_*_perf_stat.txt"`)
  N=${#ARR[@]}
  if [ "$N" == "0" ]; then
    echo "$0.$LINENO you entered dirname $INFILE but I didn't find any sys_*_perf_stat.txt file under that dir. bye"
    exit 1
  fi
  INFILE=${ARR[0]}
  DIR=`dirname $INFILE`
  if [ "$N" > "1" ]; then
    echo "$0.$LINENO you entered dirname $DIR0. Found $N sys_*_perf_stat.txt file under that dir."
    echo "$0.$LINENO sys_*_perf_stat.txt ${ARR[@]}"
  fi
  echo "$0.$LINENO using file ${ARR[0]}"
else
  DIR=`dirname $INFILE`
fi
echo "DIR= $DIR"
PCG_FILE=$DIR/perf_cpu_groups.txt
if [ -e $PCG_FILE -a "$CPU_GROUP" != "" ]; then
  PCG_LIST=`grep "$CPU_GROUP" $PCG_FILE | awk '{printf("%s\n", $3);exit(1);}'`
  echo "pcg_file cpu list= $PCG_LIST"
  if [ "$PCG_LIST" == "" ]; then
    echo "$0.$LINENO you entered -c $CPU_GROUP but didn't find the string in $PCG_FILE. below is the content of the file. Bye"
    cat $PCG_FILE
    exit 1
  fi
fi
LSCPU=$DIR/lscpu.txt
LSCPU_INFO=()
if [ -e $LSCPU ]; then
  LSCPU_INFO=(`awk '
   /^CPU.s.:/{num_cpus = $2;}
   /^Thread.s. per core:/{ tpc = $4; }
   /^Socket.s.:/{ skt = $2; }
   /^Vendor ID/{ mkr = $3;}
   /^CPU max MHz:/ { if (mkr == "AuthenticAMD") {tsc2= $4; tsc_v2 = 0.001 * tsc;}}
   /^BogoMIPS/{ if (tsc == "" || mkr == "GenuineIntel") { tsc = $2/tpc ;tsc_v = 0.001 * tsc;}}
   END{
     printf("%s\n", num_cpus);
     printf("%s\n", tsc_v);
     printf("%s\n", mkr);
     printf("%s\n", skt);
   }
  ' $LSCPU`)
  echo "LSCPU_INFO= ${LSCPU_INFO[@]}"
fi
if [ "$THR_PER_CORE_IN" != "" ]; then
  thr_per_core=$THR_PER_CORE_IN
fi
  
awk -v pcg_list="$PCG_LIST" -v thr_per_core="$thr_per_core" -v sockets="${LSCPU_INFO[3]}" -v vendor="${LSCPU_INFO[2]}" -v tsc_ghz="${LSCPU_INFO[1]}" -v num_cpus="${LSCPU_INFO[0]}" -v dlm=" " '
   function ck_tm(tm) {
   if (!(tm in tm_list)) {
     tm_list[tm] = ++tm_mx;
     tm_lkup[tm_mx] = tm;
     return tm_mx;
   } else {
     return tm_list[tm];
   }
   }
  BEGIN{
#    10.013064568;3909750994;;L3_accesses;80100000630;100.00;4.068;M/sec
#    10.013064568;5063462830;;L3_lat_out_cycles;80100005350;100.00;5.268;M/sec
#    10.013064568;214924035;;L3_lat_out_misses;80100007663;100.00;0.224;M/sec
    if (pcg_list != "") {
      gsub(" ", "", pcg_list);
      n = split(pcg_list, arr, ",");
      for (i=1; i <= n; i++) {
        cpu_list[arr[i]+0] = arr[i] + 0;
      }
    }
    i=0;
    #UNC = ++i; hdr[UNC] = "mem_bw";
    #L3m = ++i; hdr[L3m] = "L3misses";
    #L3a = ++i; hdr[L3a] = "L3access";
    #pwr = ++i; #hdr[pwr] = "pkg_watts";
    #pfl = ++i; hdr[pfl] = "pf_lcl";
    #pfr = ++i; hdr[pfr] = "pf_rmt";
    #meml   = ++i;  hdr[meml]    = "demand_lcl";
    #memr   = ++i;  hdr[memr]    = "demand_rmt"
    #L3cyc  = ++i;  hdr[L3cyc]   = "L3miss_out"
    #cyc    = ++i;  hdr[cyc]     = "cycles"
    #mpf    = ++i;  #hdr[mpf]     = "mperf"
    #uop_ret= ++i;  hdr[uop_ret] = "ret_uops_cycles";
    #irprf  = ++i;  hdr[irprf]   = "instr"
    j =0;
    lkup[++j] = "qpi_data_bandwidth_tx0";  qpi0 = j;
    lkup[++j] = "qpi_data_bandwidth_tx1";  qpi1 = j;
    lkup[++j] = "qpi_data_bandwidth_tx2";  qpi2 = j;
    lkup[++j] = "unc_cha_tor_inserts.ia_miss.0x40433";   unc_cha_miss = j;
    lkup[++j] = "unc_cha_tor_occupancy.ia_miss.0x40433"; unc_cha_occ = j;
    lkup[++j] = "unc_cha_clockticks";  unc_cha_clk = j;
    lkup[++j] = "power/energy-pkg/";   pwr = j;
    lkup[++j] = "ref-cycles";          ref_cycles = j;
    lkup[++j] = "cycles";              cyc = j;
    lkup[++j] = "offcore_requests.l3_miss_demand_data_rd";              offc_dmnd_data_rd = j;
    lkup[++j] = "offcore_requests_outstanding.l3_miss_demand_data_rd";  offc_out_dmnd_data_rd = j;
    lkup[++j] = "unc_cha_tor_inserts.ia.0x40433";        unc_cha_ref = j;
    lkup[++j] = "upi_data_bandwidth_tx";                 unc_upi_bytes = j;
    lkup[++j] = "msr/aperf";                             aperf     = j;
    lkup[++j] = "msr/mperf";                             mperf     = j;
    lkup[++j] = "msr/irperf";                            irperf    = j;
    lkup[++j] = "ret_uops_cycles";                       ret_cycles = j;
    lkup[++j] = "instructions";                          instr     = j;
    lkup[++j] = "uops_retired.retire_slots";             ret_slots = j;
    lkup[++j] = "cpu_clk_unhalted.thread_any";           thr_any   = j;
    lkup[++j] = "cpu_clk_unhalted.one_thread_active";    clk_one_thr   = j;
    lkup[++j] = "cpu_clk_unhalted.ref_xclk";             clk_ref_xclk  = j;
#    return ((EV("CPU_CLK_UNHALTED.THREAD", level) / 2) * (1 + EV("CPU_CLK_UNHALTED.ONE_THREAD_ACTIVE", level) / EV("CPU_CLK_UNHALTED.REF_XCLK", level))) if ebs_mode else(EV("CPU_CLK_UNHALTED.THREAD_ANY", level) / 2) if smt_enabled else CLKS(self, EV, level)
    lkup[++j] = "idq_uops_not_delivered.core";           not_deliv = j;
    #lkup[++j] = "offcore_requests.demand_data_rd"
    #lkup[++j] = "offcore_requests_outstanding.demand_data_rd"; 
    lkup[++j] = "qpi_data_bandwidth_tx";                 qpi_tx  = j;
    lkup[++j] = "unc_c_tor_inserts.miss_opcode.0x182";   tor_ins = j;
    lkup[++j] = "unc_c_tor_occupancy.miss_opcode.0x182"; tor_occ = j;
    lkup[++j] = "unc_c_clockticks";                      tor_clk = j;
    lkup[++j] = "l3_lat_out_misses";    L3m = j;
    lkup[++j] = "l3_accesses";          L3a = j;
    lkup[++j] = "hwprefetch_local";     pfl = j;
    lkup[++j] = "hwprefetch_remote";    pfr = j;
    lkup[++j] = "mem_local";            meml = j;
    lkup[++j] = "mem_remote";           memr = j;
    lkup[++j] = "unc_read_write";       unc_rdwr = j;
    lkup[++j] = "topdown-retiring";     icx_topd_ret = j;
    lkup[++j] = "topdown-bad-spec";     icx_topd_bs = j;
    lkup[++j] = "topdown-be-bound";     icx_topd_be = j;
    lkup[++j] = "cpu/slots/";           icx_topd_slots = j;
    lkup[++j] = "int_misc.uop_dropping"; icx_uop_drop = j;
    lkup[++j] = "int_misc.recovery_cycles"; icx_recovery_cycles = j;
    lkup[++j] = "int_misc.recovery_cycles_any"; recovery_cycles = j;
    lkup[++j] = "uops_issued.any";      uops_issued_any = j;

    lkup_mx = j;

    for (j=1; j <= lkup_mx; j++) {
      v = lkup[j];
      if (!(v in evt_list)) {
        k = j;
#        ck=0;
#        if (j == ++ck) { qpi0 = k; }
#        if (j == ++ck) { qpi1 = k; }
#        if (j == ++ck) { qpi2 = k; }
#        if (j == ++ck) { unc_cha_miss = k; }
#        if (j == ++ck) { unc_cha_occ  = k; }
#        if (j == ++ck) { unc_cha_clk  = k; }
#        if (j == ++ck) { pwr  = k; }
#        if (j == ++ck) { offc_pwr  = k; }
#        if (j == ++ck) { offc_dmnd_data_rd    = k; }
#        if (j == ++ck) { offc_out_dmnd_data_rd= k; }
#        if (j == ++ck) { unc_cha_ref  = k; }
#        if (j == ++ck) { unc_upi_bytes= k; }
#        if (j == ++ck) { instr        = k; }
#        if (j == ++ck) { ret_cycles   = k; }
#        if (j == ++ck) { cyc          = k; }
#        if (j == ++ck) { instr        = k; }
#        if (j == ++ck) { ret_slots    = k; }
#        if (j == ++ck) { thr_any      = k; }
#        if (j == ++ck) { not_deliv    = k; }
#        ck += 2;
#        #if (j == 18) { offc_dmnd_data_rd    = k; }
#        #if (j == 19) { offc_out_dmnd_data_rd= k; }
#        if (j == ++ck) { qpi_tx = k;}
#        if (j == ++ck) { tor_ins = k;}
#        if (j == ++ck) { tor_occ = k;}
#        if (j == ++ck) { tor_clk = k;}
#        if (ck != lkup_mx) {
#          printf("messup here, ck= %d, lkup_mx= %d. bye\n", ck, lkup_mx) > "/dev/stderr";
#          exit(1);
#        }
        evt_list[v] = j;
        evt_lkup[j] = v;
        evt_mx = j;
      }
    }
    if (offc_dmnd_data_rd != "") { L3m = offc_dmnd_data_rd; }
    if (offc_out_dmnd_data_rd != "") { L3cyc = offc_out_dmnd_data_rd; }
    if (qpi_tx != "" ) { unc_upi_bytes = qpi_tx; }
    #if (tor_ins != "") { L3m = tor_ins; }
    #if (tor_occ != "") { L3cyc = tor_occ; }
    #printf("tor_ins = %s, tor_occ= %s, unc_cha_miss= %s, unc_cha_occ= %s, unc_cha_clk= %s\n", tor_ins, tor_occ, unc_cha_miss, unc_cha_occ, unc_cha_clk);
  }
  {
    j = 0;
#   some events are alternative ways to get the same count (like msr/aperf/ is same as cycles (but msr/aperf/ doesnt use up an event counter)
    if (index($0, "msr/aperf/") > 0) { j=cyc; }
    else if (index($0, "msr/mperf/") > 0) { j=mperf; }
    else if (index($0, "msr/irperf/") > 0) { j=instr; }
    else if (index($0, "instructions") > 0) { j=instr; }
    else if (index($0, "ret_uops_cycles") > 0) { j=ret_cycles; }
      n=split($1, arr, ";");
      cpu_col=0;
      if (n > 2 && index(arr[2], "CPU") == 1) {
        cpu_col=1;
        cpu_num= substr(arr[2], 4, length(arr[2])) + 0;
        got_cpu[cpu_num] = 1;
        if (pcg_list != "" && cpu_list[cpu_num] == "") {
          skp_cpu[cpu_num] = 1;
          next;
        }
        #if (thr_per_core == 2) { thr_per_core = 1; }
      }
    if (j == 0) {
      e = tolower(arr[4+cpu_col]);
      if (e == "") { next; }
      if (e in evt_list) {
        #printf("got e= %s\n", e);
        j = evt_list[e];
      } else {
        if (index(e, "_read_write") == 0 && index(e, "unc_") != 1) {
        evt_list[e] = ++evt_mx;
        evt_lkup[evt_mx] = e;
        j = evt_mx;
        printf("added evt[%d]= %s\n", j, e);
        }
      }
      if (index(e, "l3_lat_out_cycles") > 0) { L3cyc = j; }
      if (index(e, "l3_lat_out_misses") > 0) { L3m = j; }
    }
    if (j != 0) {
      n=split($1, arr, ";");
      cpu_col=0;
      if (index(arr[2], "CPU") == 1) {
        cpu_col=1;
      }
      tm_i = ck_tm(arr[1]);
      evt[j,tm_i] += arr[2+cpu_col];
      evt[j,tm_i,"inst"]++;
      evt[j,tm_i,"ns"] += arr[5+cpu_col];
      evt[j,tm_i,"multi"] = arr[6+cpu_col];
      evt[j,"tot"] += arr[2+cpu_col];
      evt[j,"tot","inst"]++;
      evt[j,"tot","ns"] += arr[5+cpu_col];
      evt[j,"tot","multi"] = arr[6+cpu_col];
      #1.002152878;5415357486;;UNC_C_CLOCKTICKS;2005707182;100.00;168.823;M/sec
      next;
    }
  }
  /unc._read_write/{
   n=split($1, arr, ";");
      cpu_col=0;
      if (index(arr[2], "CPU") == 1) {
        cpu_col=1;
      }
   tm_i = ck_tm(arr[1]);
   j = unc_rdwr;
   evt[j,tm_i] += arr[2+cpu_col]+0;
   evt[j,"tot"] += arr[2+cpu_col]+0;
   #evt[j,tm_i,"inst"]++;
   #evt[j,tm_i,"ns"] += arr[5+cpu_col];
   #evt[j,tm_i,"multi"] = arr[6+cpu_col];
   #printf("unc_rd_wr %s, v= %s bw= %f\n", arr[4+cpu_col], arr[2+cpu_col], 64.0e-9*evt[unc_rdwr,tm_i]) > "/dev/stderr";
   #exit;
      next;
 }
 END{
   #exit;
   for (i=0; i < num_cpus; i++) {
     if (skp_cpu[i] == 1) { printf("skipped cpu %d\n", i);}
   }
   tm_lkup[0] = 0.0;
   cats=0;
   if (evt[unc_rdwr,1] != "") {
      h[++cats] = "mem_bw";
   }
   if (evt[L3m,1] != "" && evt[L3a,1] != "") {
      h[++cats] = "%L3_miss";
   }
   got_freq=0;
   if (evt[mperf,1] != "" && evt[cyc,1] != "" && tsc_ghz != "" && num_cpus != "") {
      h[++cats] = "%busy";
      h[++cats] = "frqGHz";
      got_freq=1;
   }
   if (evt[L3m,1] != "" && evt[L3cyc,1] != "") {
      h[++cats] = "LatCycls";
      if (got_freq == 1) {
        h[++cats] = "Lat(ns)";
      }
   }
   #if (evt[L3m,1] != "" && evt[L3cyc,1] != "") {
   #   h[++cats] = "MssO/cyc";
   #}
   if (evt[L3m,1] != "") {
      h[++cats] = "L3MssBW";
   }
   if (evt[instr,1] != "" && evt[cyc,1] != "") {
      h[++cats] = "IPC";
   }
   if (evt[ret_slots,1] != "" && evt[cyc,1] != "" && evt[clk_one_thr,1] != "" && evt[clk_ref_xclk,1] != "") {
#    return ((EV("CPU_CLK_UNHALTED.THREAD", level) / 2) * (1 + EV("CPU_CLK_UNHALTED.ONE_THREAD_ACTIVE", level) / EV("CPU_CLK_UNHALTED.REF_XCLK", level))) if ebs_mode else(EV("CPU_CLK_UNHALTED.THREAD_ANY", level) / 2) if smt_enabled else CLKS(self, EV, level)
      h[++cats] = "%retiring";
      td_ret = cats;
      got_clx_td_ret = 1;
   } else {
    if (evt[ret_slots,1] != "" && evt[thr_any,1] != "") {
      h[++cats] = "%retiring";
      td_ret = cats;
    } 
   } 
   if (evt[icx_topd_slots,1] != "" && evt[icx_topd_ret,1] != "") {
      h[++cats] = "%td_ret";
      icx_td_ret = cats;
      got_icx_td_ret = 1;
   } 
   if (evt[icx_topd_slots,1] != "" && evt[icx_topd_bs,1] != "") {
      h[++cats] = "%td_bs";
      icx_td_bs = cats;
      got_icx_td_bs = 1;
   } 
   if (evt[icx_topd_slots,1] != "" && evt[icx_topd_be,1] != "") {
      h[++cats] = "%td_be";
      icx_td_be = cats;
      got_icx_td_be = 1;
   } 
   if (evt[icx_topd_slots,1] != "" && evt[not_deliv,1] != "" && evt[icx_uop_drop,1] != "") {
      h[++cats] = "%td_fe";
      icx_td_fe = cats;
      got_icx_td_fe = 1;
   }
   #printf("\nuops_iss= %s, ret_slots= %s, rec_cy= %s, td_ret = %s\n", evt[uops_issued_any,1], evt[ret_slots,1], evt[recovery_cycles,1], td_ret);
   if (evt[uops_issued_any,1] != "" && evt[ret_slots,1] != "" && evt[recovery_cycles,1] != "" && td_ret > 0) {  # so not icx
      h[++cats] = "%bad_spec";
      td_bs = cats;
   }
   if (evt[not_deliv,1] != "" && evt[icx_topd_slots,1] == "") {  # so not icx
      h[++cats] = "%frt_end";
      td_frnt = cats;
   }
   if (td_ret != "" && td_frnt != "" && td_bs == "") {
      h[++cats] = "%be_spec";
      td_be_bad_spec = cats;
   }
   if (td_ret != "" && td_frnt != "" && td_bs != "") {
      h[++cats] = "%bck_end";
      td_bck_end = cats;
   }
   if (evt[ret_cycles,1] != "" && evt[cyc,1] != "") {
      h[++cats] = "%ret_cyc";
   }
   if (evt[pwr,1] != "") {
      h[++cats] = "pkg_watts";
   }
   if (evt[unc_cha_miss,1] != "" && evt[unc_cha_occ,1] != "") {
      if (evt[unc_cha_clk,1] != "") {
        h[++cats] = "LatUnc(ns)";
      }
      h[++cats] = "LatUncCycls";
      h[++cats] = "LatUncBW";
   }
   if (evt[unc_cha_miss,1] != "" && evt[unc_cha_ref,1] != "") {
      h[++cats] = "%L3_miss";
   }
   if ((evt[qpi0,1] != "" && evt[qpi1,1] != "") || evt[unc_upi_bytes,1] != "") {
      h[++cats] = "bw_rmt";
   }
   if (evt[pfl,1] != "") {
      h[++cats] = "pf_lcl";
   }
   if (evt[pfr,1] != "") {
      h[++cats] = "pf_rmt";
   }
   if (evt[meml,1] != "") {
      h[++cats] = "dmnd_lcl";
   }
   if (evt[memr,1] != "") {
      h[++cats] = "dmnd_rmt";
   }
   hstr = sprintf("%8s", "time");
   for (j=1; j <= cats; j++) {
     hstr = hstr sprintf("%s%8s", dlm, h[j]);
   }
   printf("%s\n", hstr);
   lat_fctr = 1.0;
   if (index(vendor, "AMD") > 0) {
      lat_fctr = 16.0;
   }
   for (kk=1; kk <= tm_mx+1; kk++) {
    if (kk <= tm_mx) {
      i = kk;
      tm_dff = tm_lkup[i] - tm_lkup[i-1];
      tm_elap = tm_lkup[i];
      printf("%8.3f", tm_elap);
    } else {
      i = "tot";
      tm_dff = tm_lkup[tm_mx];
      tm_elap = tm_lkup[tm_mx];
      printf(" avg_tot");
      #printf("tm_dff= %f tm_elap= %f\n", tm_dff, tm_elap);
    }
    #printf(" unc_rdwr=%d, evt[unc_rdwr,%d] %f\n", unc_rdwr,i,evt[unc_rdwr,i]);
    LatUncNs = 0.0;
    for (j=1; j <= cats; j++) {
      v = 0.0;
      if (h[j] == "mem_bw") { v = 64.0e-9 * evt[unc_rdwr,i]/tm_dff; }
      if (h[j] == "%L3_miss") {
        if (index(vendor, "AMD") > 0) {
          if(evt[L3a,i] > 0.0) {
            v = 100.0 * evt[L3m,i]/evt[L3a,i];
          }
        } else {
          if((evt[unc_cha_ref,i]+0) > 0.0) {
            v = 100.0 * evt[unc_cha_miss,i]/evt[unc_cha_ref,i];
          }
        }
      }
      if (h[j] == "LatCycls") {
        if (index(vendor, "AMD") > 0) {
          v = lat_fctr * evt[L3cyc,i]/evt[L3m,i];
        } else {
          #v = evt[L3cyc,i]/evt[L3m,i]/(sockets*evt[L3m,i,"inst"]);
          if (evt[L3m,i] > 0) {
            v = evt[L3cyc,i]/evt[L3m,i];
            #if (tor_occ == L3cyc && sockets > 0) { v /= sockets; }
          }
          L3lat_cycles = v;
        }
      }
      #if (h[j] == "MssO/cyc") 
      if (h[j] == "L3MssBW") {
        #if (index(vendor, "AMD") > 0) {
        #  #v = lat_fctr * evt[L3cyc,i]/evt[L3m,i];
        #  v = 0.0;
        #} else {
        #  v = 0.0;
        #  if (evt[L3cyc,1] > 0 && evt[L3m,i] > 0) {
          #v = evt[L3cyc,i]/evt[L3m,i];
          v = 64e-9*evt[L3m,i]/tm_dff;
          #v = 1.0/v;
        #  }
        #}
      }
      if (h[j] == "LatUnc(ns)") {
          #v = evt[unc_cha_occ,i]/evt[unc_cha_miss,i]/(sockets*evt[unc_cha_occ,i,"inst"]);
          v  = 0.0;
          v1 = 0.0;
          v2 = 0.0;
          if (evt[unc_cha_miss,i] > 0) {
            v = evt[unc_cha_occ,i]/evt[unc_cha_miss,i];
          }
          if (frqGHz > 0.0) {
            v /= frqGHz;
          } else {
            v = 0.0;
          }
          
          #if (sockets > 0) { skt = sockets; } else { skt = 1.0; }
          #if (evt[unc_cha_clk,i,"inst"] > 0) {
          #  v1 = evt[unc_cha_clk,i]/(evt[unc_cha_clk,i,"ns"]);
          #}
          #if (v1 > 0) {
          #  v2 = v / v1;
          #}
          #printf("v= %f v1 = %f, v2= %f, inst= %f, skt= %s\n", v, v1, v2, evt[unc_cha_clk,i,"inst"], skt) > "/dev/stderr";
          #v = v2;
          #if (evt[unc_cha_clk,i,"inst"] > 0) {
          #v = (1.0e-9*evt[unc_cha_clk,i]/tm_dff)/evt[unc_cha_clk,i,"inst"];
          #}
          #if (v > 0 && evt[unc_cha_miss,i] > 0) {
          #v = evt[unc_cha_occ,i]/evt[unc_cha_miss,i]/v;
          #if (sockets > 0) { v /= sockets; }
          #}
          #L3lat_cycles = v;
          LatUncNs = v;
      }
      if (h[j] == "LatUncCycls") {
        #v = evt[unc_cha_occ,i]/evt[unc_cha_miss,i]/(sockets*evt[unc_cha_occ,i,"inst"]);
        if (evt[unc_cha_miss,i] > 0) {
           v = evt[unc_cha_occ,i]/evt[unc_cha_miss,i];
           #if (sockets > 0) { v /= sockets; }
           #if (did_sockets_msg != 1) { did_sockets_msg = 1; printf("got sockets= %d, v= %f\n", sockets, v) > "/dev/stderr";}
        }
        #v = evt[L3cyc,i]/evt[L3m,i];
        #if (LatUncNs > 0.0) {
        #    v = LatUncNs * tsc_ghz;
        #}
        L3lat_cycles = v;
      }
      if (h[j] == "LatUncBW") {
       if (evt[unc_cha_clk,i,"inst"] > 0) {
          v = (1.0e-9*evt[unc_cha_clk,i]/tm_dff)/evt[unc_cha_clk,i,"inst"];
          }
          if (v > 0 && evt[unc_cha_miss,i] > 0) {
          v = 64.0e-9*evt[unc_cha_miss,i]/tm_dff;
          #if (sockets > 0) { v /= sockets; }
          }
          #L3lat_cycles = v;
      }
      if (h[j] == "Lat(ns)") {
        v = lat_fctr * evt[L3cyc,i]/evt[L3m,i];
        if (tor_occ == L3cyc) { v *= 0.5; }
        if (index(vendor, "AMD") > 0) {
          v = v/frqGHz; 
        } else {
          v = v/tsc_ghz;
        }
        
      }
      if (h[j] == "MissO/cyc") { v = lat_fctr * evt[L3cyc,i]/evt[cyc,i]; }
      if (h[j] == "IPC") { v = evt[instr,i]/evt[cyc,i]; }
      if (h[j] == "%retiring" && got_clx_td_ret != 1) {
         td_denom = (4*evt[thr_any,i]/thr_per_core);
         v = 100.0*evt[ret_slots,i]/td_denom;
         td_ret_val = v;
      }
      if (h[j] == "%retiring" && got_clx_td_ret == 1) {
   #if (evt[ret_slots,1] != "" && evt[cyc,1] != "" && evt[clk_one_thr,1) != "" && evt[clk_ref_xclk,1] != "") {
#    return ((EV("CPU_CLK_UNHALTED.THREAD", level) / 2) * (1 + EV("CPU_CLK_UNHALTED.ONE_THREAD_ACTIVE", level) / EV("CPU_CLK_UNHALTED.REF_XCLK", level))) if ebs_mode else(EV("CPU_CLK_UNHALTED.THREAD_ANY", level) / 2) if smt_enabled else CLKS(self, EV, level)
        #td_denom = ((4 * evt[cyc,i] / 2) * (1 + evt[clk_one_thr,i] / evt[clk_ref_xclk,i]));
        td_denom = ((4 * evt[cyc,i]));
        v = 100.0 * evt[ret_slots,i] / td_denom;
        td_ret_val = v;
      }
      if (h[j] == "%frt_end") { v = 100.0*evt[not_deliv,i]/td_denom; td_frt_end_val = v; }
      if (h[j] == "%bad_spec") { v = 100.0*(evt[uops_issued_any,i]-evt[ret_slots,i] + ((4*evt[recovery_cycles,i])/2))/td_denom; if (v < 0){v=0.0;} td_bad_spec_val = v; }
      if (h[j] == "%be_spec") { v = 100 - td_ret_val - td_frt_end_val; if (v < 0) { v = 0.0; }}
      if (h[j] == "%bck_end") { v = 100 - td_ret_val - td_frt_end_val - td_bad_spec_val; if (v < 0) { v = 0.0; }}
      if (h[j] == "%ret_cyc") { v = 100.0*evt[ret_cycles,i]/evt[cyc,i]; }
      if (h[j] == "%td_ret" || h[j] == "%td_be" || h[j] == "%td_bs" || h[j] == "%td_fe") {
         if (got_icx_td_sum != i) {
           got_icx_td_sum  = i;
           v_td_fctr = 1.0;
           v_td_ret = 100.0*evt[icx_topd_ret,i]/evt[icx_topd_slots,i];
           v_td_bs  = 100.0*evt[icx_topd_bs,i]/evt[icx_topd_slots,i];
           v_td_be  = 100.0*evt[icx_topd_be,i]/evt[icx_topd_slots,i];
           v_td_fe  = 100.0*(evt[not_deliv,i]-evt[icx_uop_drop,i])/evt[icx_topd_slots,i];
           if (got_icx_td_ret == 1 && got_icx_td_bs == 1 && got_icx_td_be == 1 && got_icx_td_fe == 1) {
              v_td_sum = v_td_ret + v_td_bs + v_td_be + v_td_fe;
              if (v_td_sum != 0.0) { v_td_fctr = 100.0/v_td_sum; }
              #printf("\nv_td_sum= %f v_td_fctr= %f i= %d fe= %f fctr*fe= %f\n", v_td_sum, v_td_fctr, i, v_td_fe, v_td_fctr * v_td_fe);
              #v_td_fctr = 1.0;
           }
         }
      }
      if (h[j] == "%td_ret") { v = v_td_fctr * v_td_ret; }
      if (h[j] == "%td_bs")  { v = v_td_fctr * v_td_bs; }
      if (h[j] == "%td_be")  { v = v_td_fctr * v_td_be; }
      if (h[j] == "%td_fe")  { v = v_td_fctr * v_td_fe; }
      #if (h[j] == "%td_fe")  { v = v_td_sum ; }

      if (h[j] == "bw_rmt") {
        if (evt[qpi0,1] != "" && evt[qpi1,1] != "") {
          v = (64.0/9.0) * 1.0e-9 * (evt[qpi0,i]+evt[qpi1,i]+evt[qpi2,i])/tm_dff;
        }
        if (evt[unc_upi_bytes,1] != "") {
          v = 1.0e-9 * (evt[unc_upi_bytes,i])/tm_dff;
        }
      }
      if (h[j] == "pf_lcl") { v = 64.0e-9 * evt[pfl,i]/tm_dff; }
      if (h[j] == "pkg_watts") { v = evt[pwr,i]/tm_dff; 
        #printf("\npwr: evt[%d,%d]= %f tm_diff= %f v= %f\n", pwr,i, evt[pwr,i], tm_dff, v);
      }
      if (h[j] == "pf_rmt") { v = 64.0e-9 * evt[pfr,i]/tm_dff; }
      if (h[j] == "dmnd_lcl") { v = 64.0e-9 * evt[meml,i]/tm_dff; }
      if (h[j] == "dmnd_rmt") { v = 64.0e-9 * evt[memr,i]/tm_dff; }
      if (h[j] == "%busy") { bsy = 1.0e-9*(evt[mperf,i])/(num_cpus * tsc_ghz * tm_dff); v = 100.0*bsy;}
      if (h[j] == "frqGHz") { frqGHz = tsc_ghz * evt[cyc,i]/evt[mperf,i]; v = frqGHz;}
      printf("%s%8.3f", dlm, v);
    }
    printf("\n");
   }
   printf("%s\n", hstr);
 }' $INFILE

exit 0

