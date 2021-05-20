#!/bin/bash

INFILE=$1
if [ "$INFILE" == "" ]; then
  echo "1st arg must be perf stat output file"
  exit 1
fi
if [ ! -e $INFILE ]; then
  echo "perf_stat file $INFILE not found"
  exit 1
fi
DIR=`dirname $INFILE`
echo "DIR= $DIR"
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
  
awk -v sockets="${LSCPU_INFO[3]}" -v vendor="${LSCPU_INFO[2]}" -v tsc_ghz="${LSCPU_INFO[1]}" -v num_cpus="${LSCPU_INFO[0]}" -v dlm=" " '
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
    i=0;
    UNC = ++i; hdr[UNC] = "mem_bw";
    L3m = ++i; hdr[L3m] = "L3misses";
    L3a = ++i; hdr[L3a] = "L3access";
    pwr = ++i; hdr[pwr] = "pkg_watts";
    pfl = ++i; hdr[pfl] = "pf_lcl";
    pfr = ++i; hdr[pfr] = "pf_rmt";
    meml   = ++i;  hdr[meml]    = "demand_lcl";
    memr   = ++i;  hdr[memr]    = "demand_rmt"
    L3cyc  = ++i;  hdr[L3cyc]   = "L3miss_out"
    cyc    = ++i;  hdr[cyc]     = "cycles"
    mpf    = ++i;  hdr[mpf]     = "mperf"
    uop_ret= ++i;  hdr[uop_ret] = "ret_uops_cycles";
    irprf  = ++i;  hdr[irprf]   = "instr"
    j =0;
    lkup[++j] = "qpi_data_bandwidth_tx0";
    lkup[++j] = "qpi_data_bandwidth_tx1";
    lkup[++j] = "unc_cha_tor_inserts.ia_miss.0x40433";
    lkup[++j] = "unc_cha_tor_occupancy.ia_miss.0x40433";
    lkup[++j] = "unc_cha_clockticks";
    lkup[++j] = "power/energy-pkg/";
    lkup[++j] = "ref-cycles";
    lkup[++j] = "offcore_requests.l3_miss_demand_data_rd";
    lkup[++j] = "offcore_requests_outstanding.l3_miss_demand_data_rd";
    lkup[++j] = "unc_cha_tor_inserts.ia.0x40433";
    lkup[++j] = "upi_data_bandwidth_tx"
    lkup[++j] = "msr/irperf"
    lkup[++j] = "ret_uops_cycles";
    lkup[++j] = "instructions";
    lkup[++j] = "uops_retired.retire_slots";
    lkup[++j] = "cpu_clk_unhalted.thread_any"
    lkup[++j] = "idq_uops_not_delivered.core"
    lkup[++j] = "offcore_requests.demand_data_rd"
    lkup[++j] = "offcore_requests_outstanding.demand_data_rd"
    lkup[++j] = "qpi_data_bandwidth_tx"
    lkup[++j] = "unc_c_tor_inserts.miss_opcode.0x182"
    lkup[++j] = "unc_c_tor_occupancy.miss_opcode.0x182"
    lkup[++j] = "unc_c_clockticks"

    lkup_mx = j;

    for (j=1; j <= lkup_mx; j++) {
      v = lkup[j];
      if (!(v in evt_list)) {
        #if (j == 3) { k = L3m; }
        #else if (j == 4) { k = L3cyc; }
        if (j == 7) { k = mpf; }
        else if (j == 8) { k = L3m; }
        else if (j == 9) { k = L3cyc; }
        else { k = ++i; }
        if (j == 1) { qpi0 = k; }
        if (j == 2) { qpi1 = k; }
        if (j == 3) { unc_cha_miss = k; }
        if (j == 4) { unc_cha_occ  = k; }
        if (j == 5) { unc_cha_clk  = k; }
        if (j == 6) { pwr  = k; }
        if (j == 10) { unc_cha_ref  = k; }
        if (j == 11) { unc_upi_bytes= k; }
        if (j == 12) { instr        = k; }
        if (j == 13) { ret_cycles   = k; }
        if (j == 14) { instr        = k; }
        if (j == 15) { ret_slots    = k; }
        if (j == 16) { thr_any      = k; }
        if (j == 17) { not_deliv    = k; }
        if (j == 18) { offc_dmnd_data_rd    = k; }
        if (j == 19) { offc_out_dmnd_data_rd= k; }
        if (j == 20) { qpi_tx = k;}
        if (j == 21) { tor_ins = k;}
        if (j == 22) { tor_occ = k;}
        if (j == 23) { tor_clk = k;}
        evt_list[v] = k;
        evt_lkup[i] = v;
      }
    }
    evt_last = i;
    #if (offc_dmnd_data_rd != "") { L3m = offc_dmnd_data_rd; }
    #if (offc_out_dmnd_data_rd != "") { L3cyc = offc_out_dmnd_data_rd; }
    if (qpi_tx != "" ) { unc_upi_bytes = qpi_tx; }
    if (tor_ins != "") { L3m = tor_ins; }
    if (tor_occ != "") { L3cyc = tor_occ; }
  }
  {
    j = 0;
    if (index($0, "msr/aperf/") > 0) { j=cyc; }
    else if (index($0, "L3_lat_out_cycles") > 0) { j=L3cyc; }
    else if (index($0, "msr/mperf/") > 0) { j=mpf; }
    else if (index($0, "msr/irperf/") > 0) { j=instr; }
    else if (index($0, "instructions") > 0) { j=instr; }
    else if (index($0, "ret_uops_cycles") > 0) { j=ret_cycles; }
    if (j == 0) {
      n=split($1, arr, ";");
      e = tolower(arr[4]);
      if (e in evt_list) {
        #printf("got e= %s\n", e);
        j = evt_list[e];
      }
    }
    if (j != 0) {
      n=split($1, arr, ";");
      tm_i = ck_tm(arr[1]);
      evt[j,tm_i] += arr[2];
      evt[j,tm_i,"inst"]++;
      evt[j,tm_i,"ns"] += arr[5];
      evt[j,tm_i,"multi"] = arr[6];
      #1.002152878;5415357486;;UNC_C_CLOCKTICKS;2005707182;100.00;168.823;M/sec
      next;
    }
  }
  /L3_lat_out_misses/{
   n=split($1, arr, ";");
   tm_i = ck_tm(arr[1]);
   evt[L3m,tm_i] += arr[2];
      next;
  }
  /L3_accesses/{
   n=split($1, arr, ";");
   tm_i = ck_tm(arr[1]);
   evt[L3a,tm_i] += arr[2];
      next;
  }
  /energy-pkg/{
   n=split($1, arr, ";");
   tm_i = ck_tm(arr[1]);
   evt[pwr,tm_i] += arr[2];
      next;
  }
  /hwprefetch_local/{
   n=split($1, arr, ";");
   tm_i = ck_tm(arr[1]);
   evt[pfl,tm_i] += arr[2];
      next;
  }
  /hwprefetch_remote/{
   n=split($1, arr, ";");
   tm_i = ck_tm(arr[1]);
   evt[pfr,tm_i] += arr[2];
      next;
  }
  /mem_local/{
   n=split($1, arr, ";");
   tm_i = ck_tm(arr[1]);
   evt[meml,tm_i] += arr[2];
      next;
  }
  /mem_remote/{
   n=split($1, arr, ";");
   tm_i = ck_tm(arr[1]);
   evt[memr,tm_i] += arr[2];
      next;
  }
  /unc._read_write/{
   n=split($1, arr, ";");
   tm_i = ck_tm(arr[1]);
   evt[UNC,tm_i] += arr[2]+0;
   #exit;
      next;
 }
 END{
   #exit;
   tm_lkup[0] = 0.0;
   cats=0;
   if (evt[UNC,1] != "") {
      h[++cats] = "mem_bw";
   }
   if (evt[L3m,1] != "" && evt[L3a,1] != "") {
      h[++cats] = "%L3_miss";
   }
   got_freq=0;
   if (evt[mpf,1] != "" && evt[cyc,1] != "" && tsc_ghz != "" && num_cpus != "") {
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
   if (evt[ret_slots,1] != "" && evt[thr_any,1] != "") {
      h[++cats] = "%retiring";
      td_ret = cats;
   }
   if (evt[not_deliv,1] != "") {
      h[++cats] = "%frt_end";
      td_frnt = cats;
   }
   if (td_ret != "" && td_frnt != "") {
      h[++cats] = "%be_spec";
      td_be_bad_spec = cats;
   }
   if (evt[ret_cycles,1] != "" && evt[cyc,1] != "") {
      h[++cats] = "%ret_cyc";
   }
   if (evt[pwr,1] != "" && evt[pwr,1] != "") {
      h[++cats] = "pkg_watts";
   }
   if (evt[unc_cha_miss,1] != "" && evt[unc_cha_occ,1] != "") {
      h[++cats] = "LatUncCycls";
      if (evt[unc_cha_clk,1] != "") {
        h[++cats] = "LatUnc(ns)";
      }
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
   for (i=1; i <= tm_mx; i++) {
    tm_dff = tm_lkup[i] - tm_lkup[i-1];
    tm_elap = tm_lkup[i];
    printf("%8.3f", tm_elap);
    #printf(" UNC=%d, evt[UNC,%d] %f\n", UNC,i,evt[UNC,i]);
    for (j=1; j <= cats; j++) {
      v = 0.0;
      if (h[j] == "mem_bw") { v = 64.0e-9 * evt[UNC,i]/tm_dff; }
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
          if (tor_occ == L3cyc) { v *= 0.5; }
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
      if (h[j] == "LatUncCycls") {
          #v = evt[unc_cha_occ,i]/evt[unc_cha_miss,i]/(sockets*evt[unc_cha_occ,i,"inst"]);
	  if (evt[unc_cha_miss,i] > 0) {
          v = evt[unc_cha_occ,i]/evt[unc_cha_miss,i];
	  }
          #v = evt[L3cyc,i]/evt[L3m,i];
          L3lat_cycles = v;
      }
      if (h[j] == "LatUnc(ns)") {
          #v = evt[unc_cha_occ,i]/evt[unc_cha_miss,i]/(sockets*evt[unc_cha_occ,i,"inst"]);
	  if (evt[unc_cha_clk,i,"inst"] > 0) {
          v = (1.0e-9*evt[unc_cha_clk,i]/tm_dff)/evt[unc_cha_clk,i,"inst"];
          }
          if (v > 0 && evt[unc_cha_miss,i] > 0) {
          v = evt[unc_cha_occ,i]/evt[unc_cha_miss,i]/v;
          }
          L3lat_cycles = v;
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
      if (h[j] == "%retiring") { v = 100.0*evt[ret_slots,i]/(4*evt[thr_any,i]/2); td_ret_val = v; }
      if (h[j] == "%frt_end") { v = 100.0*evt[not_deliv,i]/(4*evt[cyc,i]/2); td_frt_end_val = v; }
      if (h[j] == "%be_spec") { v = 100 - td_ret_val - td_frt_end_val; if (v < 0) { v = 0.0; }}
      if (h[j] == "%ret_cyc") { v = 100.0*evt[ret_cycles,i]/evt[cyc,i]; }
      if (h[j] == "bw_rmt") {
        if (evt[qpi0,1] != "" && evt[qpi1,1] != "") {
          v = (64.0/9.0) * 1.0e-9 * (evt[qpi0,i]+evt[qpi1,i])/tm_dff;
        }
        if (evt[unc_upi_bytes,1] != "") {
          v = 1.0e-9 * (evt[unc_upi_bytes,i])/tm_dff;
        }
      }
      if (h[j] == "pf_lcl") { v = 64.0e-9 * evt[pfl,i]/tm_dff; }
      if (h[j] == "pkg_watts") { v = evt[pwr,i]/tm_dff; }
      if (h[j] == "pf_rmt") { v = 64.0e-9 * evt[pfr,i]/tm_dff; }
      if (h[j] == "dmnd_lcl") { v = 64.0e-9 * evt[meml,i]/tm_dff; }
      if (h[j] == "dmnd_rmt") { v = 64.0e-9 * evt[memr,i]/tm_dff; }
      if (h[j] == "%busy") { bsy = 1.0e-9*(evt[mpf,i])/(num_cpus * tsc_ghz * tm_dff); v = 100.0*bsy;}
      if (h[j] == "frqGHz") { frqGHz = tsc_ghz * evt[cyc,i]/evt[mpf,i]; v = frqGHz;}
      printf("%s%8.3f", dlm, v);
    }
    printf("\n");
   }
   printf("%s\n", hstr);
 }' $INFILE

exit 0

