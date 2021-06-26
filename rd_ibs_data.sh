#!/bin/bash

export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
export LC_ALL=C # this line or else get awk locale error msg

if [ "$1" == "" ]; then
  echo "$0.$LINENO must enter perf output -D filename. bye"
  echo "$0.$LINENO output file created with 'perf report -D --stdio --header > xxx.txt'"
  exit 1
fi
INF=$1
if [ -d "$INF" ]; then
  ODIR=$INF
  if [ -e "$INF/perf_out_rep.txt" ]; then
    INF=$INF/perf_out_rep.txt
  fi
else
  ODIR=`dirname $INF`
fi
if [ ! -e $INF ]; then
  echo "$0.$LINENO didn't find perf output file $INF. bye"
  exit 1
fi
# event : name = ibs_fetch//pp, , id = { 1986, 1987, 1988, 1989, 1990, 1991, 1992, 1993, 1994, 1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026, 2027, 2028, 2029, 2030, 2031, 2032, 2033, 2034, 2035, 2036, 2037, 2038, 2039, 2040, 2041, 2042, 2043, 2044, 2045, 2046, 2047, 2048, 2049, 2050, 2051, 2052, 2053, 2054, 2055, 2056, 2057, 2058, 2059, 2060, 2061, 2062, 2063, 2064, 2065, 2066, 2067, 2068, 2069, 2070, 2071, 2072, 2073, 2074, 2075, 2076, 2077, 2078, 2079, 2080, 2081 }, type = 10, size = 112, { sample_period, sample_freq } = 4000, sample_type = IP|TID|TIME|ID|CPU|PERIOD|RAW, read_format = ID, disabled = 1, inherit = 1, mmap = 1, comm = 1, freq = 1, task = 1, precise_ip = 2, sample_id_all = 1, comm_exec = 1
# event : name = ibs_op//pp, , id = { 2082, 2083, 2084, 2085, 2086, 2087, 2088, 2089, 2090, 2091, 2092, 2093, 2094, 2095, 2096, 2097, 2098, 2099, 2100, 2101, 2102, 2103, 2104, 2105, 2106, 2107, 2108, 2109, 2110, 2111, 2112, 2113, 2114, 2115, 2116, 2117, 2118, 2119, 2120, 2121, 2122, 2123, 2124, 2125, 2126, 2127, 2128, 2129, 2130, 2131, 2132, 2133, 2134, 2135, 2136, 2137, 2138, 2139, 2140, 2141, 2142, 2143, 2144, 2145, 2146, 2147, 2148, 2149, 2150, 2151, 2152, 2153, 2154, 2155, 2156, 2157, 2158, 2159, 2160, 2161, 2162, 2163, 2164, 2165, 2166, 2167, 2168, 2169, 2170, 2171, 2172, 2173, 2174, 2175, 2176, 2177 }, type = 11, size = 112, { sample_period, sample_freq } = 4000, sample_type = IP|TID|TIME|ID|CPU|PERIOD|RAW, read_format = ID, disabled = 1, inherit = 1, freq = 1, precise_ip = 2, sample_id_all = 1


gawk --non-decimal-data -v ofile_fetch="$ODIR/ibs_fetch.csv" -v ofile_op="$ODIR/ibs_op.csv" '
  function hex2dec(beg, end,    i, v) {
    str = "";
    for (i=end; i >= beg; i--) {
      str = str "" $(i+2);
    }
    if (str == "") {
      return 0;
    } else {
      v = sprintf("%d", "0x"str) + 0;
      #printf("hex str= 0x%s = %d\n", str, v);
      #exit(1);
      return v;
    }
  }
  /# event : name = / {
   ev_mx++;
   evt_nm[ev_mx] = $6;
   if (index($6, "ibs_fetch") > 0) {
     evt_ibs_fetch = ev_mx;
   }
   if (index($6, "ibs_op") > 0) {
     evt_ibs_op = ev_mx;
   }
   do_id = -1;
   for (i=7; i <= NF; i++) {
     if ($(i) == "id") {
       do_id=i+3;
       id_mx = 0;
       continue;
     }
     if ($(i) == "sample_freq" && $(i+1) == "}" && $(i+2) == "=") {
       evt_freq[ev_mx] = $(i+3);
       gsub(",", "", evt_freq[ev_mx]);
     }
     if ($(i) == "sample_type" && $(i+1) == "=") {
       evt_type[ev_mx] = $(i+2);
       gsub(",", "", evt_type[ev_mx]);
     }
     if ($(i) == "freq" && $(i+1) == "=") {
       evt_is_freq[ev_mx] = $(i+2);
       gsub(",", "", evt_is_freq[ev_mx]);
     }
     if (do_id != -1 && i >= do_id) {
       if ($(i) == "},") { do_id = -1; continue;}
       v = $(i);
       gsub(",", "", v);
       v += 0;
       ++id_mx;
       evt_id_list[ev_mx,"id",v] = id_mx;
       evt_id_lkup[ev_mx,"mx"] = id_mx;
       evt_id_lkup[ev_mx,"val",id_mx] = v;
       #if (ev_mx == 1) { printf("ev[%d]= %s, id[%d]= %d\n", ev_mx, evt_nm[ev_mx], id_mx, v);}
     }
   }
  }
  /0x.* \[.*\]: event: 9/ {
    cnt++;
    len = substr($2, 2, length($2)-3);
    #printf("len= %d, 0xlen= %s fld2= %s\n", len, len, $2);
    #exit(1);
    getline;
    getline;
    if (index($0, "... raw event: size 96 bytes") > 0) {
      typs="ftch";
      typn=1;
    } else if (index($0, "... raw event: size 128 bytes") > 0) {
      typs="op";
      typn=2;
    } else {
      next;
    }
    evtn[typn]++;
    evts[typn] = typs;
    uev = -1;
    id = -1;
    tm = 0;
    cpu = -1;
    per_v = 0;
    fetch_lat_v = 0;
    op_ret_lat0_v = 0;
    op_ret_lat1_v = 0;
    op_DCmiss_lat_v = 0;
    op_DTLBmiss_lat_v = 0;
    str = "";
    while ( getline > 0) {
      #if (NF > 18) { NF = 18; }
      if ($2 == "0010:") { 
         tm = hex2dec(9, 16);
         if (tm_beg == "") { tm_beg = tm; }
      }
      if ($2 == "0020:") { 
         id = hex2dec(1, 8);
         for (i=1; i <= ev_mx; i++) {
           if ((i,"id",id) in evt_id_list) {
             uev = i;
             break;
           }
         }
         if (uev == -1) { printf("+++++++++missed an event id\n"); exit(1);}
         cpu = hex2dec(9, 12);
         if (cpu_mx < cpu) { cpu_mx = cpu; }
      }
      if ($2 == "0030:") { 
         per_v = hex2dec(1, 8);
      }
# TBD use cap reg to determine which of the optional IBS registers are present
# cap 0x3ff
# 038 data_len 4 bytes, cap_reg 4 bytes value from CPUID_Fn8000001B_EAX [Instruction Based Sampling Identifiers] (Core::X86::Cpuid::IbsIdEax)
# cap bit 10: IbsOpData4. Read-only. Reset: Fixed,0. IBS op data 4 MSR supported.
# cap bit 9: IbsFetchCtlExtd: IBS fetch control extended MSR supported. Read-only. Reset: Fixed,1. Indicates support for Core::X86::Msr::IC_IBS_EXTD_CTL.
# cap bit 8: OpBrnFuse: fused branch op indication supported. Read-only. Reset: Fixed,1. Indicates support for Core::X86::Msr::IBS_OP_DATA[IbsOpBrnFuse].
# cap bit 7: RipInvalidChk: invalid RIP indication supported. Read-only. Reset: Fixed,1. Indicates support for Core::X86::Msr::IBS_OP_DATA[IbsRipInvalid].
# cap bit 6: OpCntExt: IbsOpCurCnt and IbsOpMaxCnt extend by 7 bits. Read-only. Reset: Fixed,1. Indicates support for Core::X86::Msr::IBS_OP_CTL[IbsOpCurCnt[26:20],IbsOpMaxCnt[26:20]].
# cap bit 5: BrnTrgt. Read-only. Reset: Fixed,1. Branch target address reporting supported.
# cap bit 4: OpCnt. Read-only. Reset: Fixed,1. Op counting mode supported. 
# cap bit 3: RdWrOpCnt. Read-only. Reset: Fixed,1. Read/Write of op counter supported.
# cap bit 2: OpSam. Read-only. Reset: Fixed,1. IBS execution sampling supported.
# cap bit 1: FetchSam. Read-only. Reset: X. IBS fetch sampling supported.
# cap bit 0: IBSFFV. Read-only. Reset: Fixed,1. IBS feature flags valid.

# ibs reg layout https://elixir.bootlin.com/linux/v5.10.33/source/arch/x86/events/amd/ibs.c  # look for offset_max
# ibs_fetch
# 040 MSRC001_1030 [IBS Fetch Control] (Core::X86::Msr::IBS_FETCH_CTL)
# 048 MSRC001_1031 [IBS Fetch Linear Address] (Core::X86::Msr::IBS_FETCH_LINADDR)
# 050 MSRC001_1032 [IBS Fetch Physical Address] (Core::X86::Msr::IBS_FETCH_PHYSADDR)
# 058 MSRC001_103C [IBS Fetch Control Extended] (Core::X86::Msr::IC_IBS_EXTD_CTL)
      if ($2 == "0040:" && uev == evt_ibs_fetch) { 
         # bytes 0-7 MSRC001_1030 [IBS Fetch Control] (Core::X86::Msr::IBS_FETCH_CTL)
         fetch_lat_v = hex2dec(5, 6);
         fetch_lat_x = str;
      }
# ibs_op
# 040 MSRC001_1033 [IBS Execution Control] (Core::X86::Msr::IBS_OP_CTL)
# 048 MSRC001_1034 [IBS Op RIP] (Core::X86::Msr::IBS_OP_RIP)
# 050 MSRC001_1035 [IBS Op Data] (Core::X86::Msr::IBS_OP_DATA)
# 058 MSRC001_1036 [IBS Op Data 2] (Core::X86::Msr::IBS_OP_DATA2)
# 060 MSRC001_1037 [IBS Op Data 3] (Core::X86::Msr::IBS_OP_DATA3)
# 068 MSRC001_1038 [IBS DC Linear Address] (Core::X86::Msr::IBS_DC_LINADDR)
# 070 MSRC001_1039 [IBS DC Physical Address] (Core::X86::Msr::IBS_DC_PHYSADDR)
# 078 MSRC001_103B [IBS Branch Target Address] (Core::X86::Msr::BP_IBSTGT_RIP)
# optional if cap bit set (it is not in this case op_data4
      if ($2 == "0050:" && uev == evt_ibs_op) { 
         # bytes 0-7
         # MSRC001_1035 [IBS Op Data] (Core::X86::Msr::IBS_OP_DATA)
         op_ret_lat0_v = hex2dec(1, 2);
         op_ret_lat1_v = hex2dec(3, 4);
      }
      if ($2 == "0060:" && uev == evt_ibs_op) { 
         op_DCmiss_lat_v = hex2dec(5, 6);
         op_DTLBmiss_lat_v = hex2dec(7, 8);
      }
      if (index($0, " ... thread:") == 1) {
        thrd_v = $3;
      }
      if (index($0, " ...... dso:") == 1) {
        dso_v = $3;
         
        if (index(thrd_v, "spin.x") > 0 || index(dso_v, "spin.x") > 0) {
          per += per_v;
          cyc[cpu,uev] += per_v;
          if (tma_prev[cpu,uev] != "") {
            tma[cpu,uev] += tm - tma_prev[cpu,uev];
          }
          tma_prev[cpu,uev] = tm;
          fetch_lat += fetch_lat_v;
          fetch_lat_arr[cpu,uev] += fetch_lat_v;
          if (uev == evt_ibs_fetch) { fetch_lat_num++; }
          if (uev == evt_ibs_op) { op_ret_lat_num++; }
          op_ret_lat0 += op_ret_lat0_v;
          op_ret_lat1 += op_ret_lat1_v;
          op_lat_arr[cpu,uev] += op_ret_lat1_v;
          op_DCmiss_lat += op_DCmiss_lat_v;
          op_DTLBmiss_lat += op_DTLBmiss_lat_v;
          if (uev == evt_ibs_fetch) { 
            if (did_hdrs == "") { printf("ts,IbsFetchLat\n") > ofile_fetch; did_hdrs = 1; }
            printf("%f,%d\n", 1.0e-9 * (tm - tm_beg), fetch_lat_v) > ofile_fetch;
          }
          if (uev == evt_ibs_op) { 
            if (did_hdrs_op == "") { printf("ts,IbsCompToRetCtr,IbsTagToRetCtr,IbsDcMissLat,IbsTlbRefillLat\n") > ofile_op; did_hdrs_op = 1; }
            printf("%f,%d,%d,%d,%d\n", 1.0e-9 * (tm - tm_beg), op_ret_lat0_v, op_ret_lat1_v, op_DCmiss_lat_v, op_DTLBmiss_lat_v) > ofile_op;
          }
        }
        break;
      }
    }
  }
  END {
   printf("got %d hw evts\n", cnt);
   for (i=1; i <= 2; i++) {
     printf("evtn[%s]= %d\n", evts[i], evtn[i]);
   }
   printf("period= %d\n", per);
   printf("fetch_lat gcyles= %f samples= %d, IbsFetchLat cycles/sample= %f\n", 1.0e-9 * fetch_lat, fetch_lat_num, fetch_lat/fetch_lat_num);
   printf("op_ret_lat0 gcyles= %f, samples= %d IbsCompToRetCtr cycles/sample= %f\n", 1.0e-9 * op_ret_lat0, op_ret_lat_num, op_ret_lat0/op_ret_lat_num);
   printf("op_ret_lat1 gcyles= %f, IbsTagToRetCtr cycles/sample= %f\n", 1.0e-9 * op_ret_lat1, op_ret_lat1/op_ret_lat_num);
   printf("op_DCmiss  gcyles= %f, IbsDcMissLat cycles/sample= %f\n", 1.0e-9 * op_DCmiss_lat, op_DCmiss_lat/op_ret_lat_num);
   printf("op_DTLBmiss  gcyles= %f, IbsTlbRefillLat cycles/sample= %f\n", 1.0e-9 * op_DTLBmiss_lat, op_DTLBmiss_lat/op_ret_lat_num);
   printf("1e-9 * period= %f\n", 1e-9 * per);
   for (i=0; i <= cpu_mx; i++) {
     for (j=1; j <= ev_mx; j++) {
     if (cyc[i,j] == "" || cyc[i,j] == 0) { continue; }
     v = 1.e-9 * cyc[i,j];
     if (v < 0.001) { continue;}
     vtm = 1.e-9 * tma[i,j];
     printf("giga_cyc[%d,%d]= %.3f tm= %.3f\n", i, j, v, vtm);
     }
   }
   if (ofile_fetch != "" ) {
     close(ofile_fetch);
   }
   if (ofile_op != "" ) {
     close(ofile_op);
   }
  }
  ' $INF
  
exit
0x92050 [0x60]: event: 9
.
. ... raw event: size 96 bytes
.  0000:  09 00 00 00 02 40 60 00 1a e9 de 00 00 00 00 00  .....@`..éÞ.....
.  0010:  23 0e 00 00 23 0e 00 00 04 57 44 c7 c0 2d 00 00  #...#....WDÇÀ-..
.  0020:  e8 07 00 00 00 00 00 00 26 00 00 00 00 00 00 00  è.......&.......
.  0030:  da 88 00 00 00 00 00 00 24 00 00 00 ff 03 00 00  Ú.......$...ÿ...
.  0040:  8e 08 8e 08 be 00 07 00 1a e9 de 00 00 00 00 00  ....¾....éÞ.....
.  0050:  1a 19 6e 80 40 00 00 00 00 00 00 00 00 00 00 00  ..n.@...........

38 50306000115460 0x92050 [0x60]: PERF_RECORD_SAMPLE(IP, 0x4002): 3619/3619: 0xdee91a period: 35034 addr: 0
 ... thread: spin.x:3619
 ...... dso: /root/60secs/extras/spin.x

0x920b0 [0x80]: event: 9
.
. ... raw event: size 128 bytes
.  0000:  09 00 00 00 02 40 80 00 ef 3a d4 ec ff 7f 00 00  .....@..ï:Ôìÿ...
.  0010:  23 0e 00 00 23 0e 00 00 09 d8 45 c7 c0 2d 00 00  #...#....ØEÇÀ-..
.  0020:  48 08 00 00 00 00 00 00 26 00 00 00 00 00 00 00  H.......&.......
.  0030:  7f 24 07 00 00 00 00 00 44 00 00 00 ff 03 00 00  .$......D...ÿ...
.  0040:  48 72 06 00 53 00 00 00 ef 3a d4 ec ff 7f 00 00  Hr..S...ï:Ôìÿ...
.  0050:  02 00 07 00 00 01 00 00 22 00 00 00 00 00 00 00  ........".......
.  0060:  00 00 00 00 00 00 00 00 10 7e cb ec ff 7f 00 00  .........~Ëìÿ...
.  0070:  01 00 00 00 00 00 00 00 ef 3a d4 ec ff 7f 00 00  ........ï:Ôìÿ...

38 50306000214025 0x920b0 [0x80]: PERF_RECORD_SAMPLE(IP, 0x4002): 3619/3619: 0x7fffecd43aef period: 468095 addr: 0
 ... thread: spin.x:3619
 ...... dso: [vdso]

