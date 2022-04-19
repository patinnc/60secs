#!/bin/bash

INF=docker_cpu_stats.txt
SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

END_DIR=1
EXCL_ARR=()
INCL_ARR=()

while getopts "hvc:d:e:f:H:i:m:p:o:s:x:X:" opt; do
  case ${opt} in
    c )
      CPU_BSY=$OPTARG
      ;;
    d )
      DIR_IN=$OPTARG
      ;;
    e )
      END_DIR=$OPTARG
      ;;
    f )
      FILE_LIST="$OPTARG"
      ;;
    H )
      HOST_STR="$OPTARG"
      ;;
    i )
      INTRVL="$OPTARG"
      ;;
    m )
      MAX_HIGH=$OPTARG
      ;;
    s )
      SEL_PRF_STR=$OPTARG
      ;;
    o )
      OUTFILE=$OPTARG
      ;;
    p )
      PXX=$OPTARG
      ;;
    x )
      EXCL_ARR+=("$OPTARG")
      ;;
    X )
      INCL_ARR+=("$OPTARG")
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "usage: $0 -d dir_with_prf_files -f prf_dat_file -s prf_dat_sel_string"
      echo "       $0 extract SVGs from perf.dat files in dir"
      echo "   -d dir_with_prf.dat_files"
      echo "   -f prf.dat_file.txt     optional prf.dat*.txt in -d dir. Default is process all .dat files. files separated by ','"
      echo "   -s string            string to use to select on some (1?) of the files in dir (like 13 to select file 13)"
      echo "   -c cpus              cpus busy in interval to be considered throttled. Put call graphs for intervals with num_cpu >= 'cpus' in throttled file"
      echo "                        otherwise put in the non-throttled file"
      echo "                        if both '-c cpus' and '-p pxx' are entereed then -c cpus is used and -p pxx is ignored"
      echo "   -p pXX               percentile to use (like 90). Put call graphs for intervals with cpu util >= pxx in throttled file"
      echo "                        otherwise put in the non-throttled file"
      echo "   -m max_high          max number of stacks high... useful for very tall stacks"
      echo "   -H host_str          this string will be added to flamegraph title. Intended for case where you are only doing 1 host"
      echo "   -i beg_secs,end_secs select perf data between beg_secs and end secs. This is based on the relative time (0 is the begin time)"
      echo "                        If only 1 number is entered then it is taken as the begin number (select call stacks after 'beg_secs' into the prf.dat file)"
      echo "   -o outfile           if doing -p pxx then all 'throttle' callstacks will put in outfile_thr.txt. non-thr in outfile_not_thr.txt"
      echo "                        default is 'summary'"
      echo "   -e 0|1               This is for processing multiple host dirs. If you are doing the last host dir do -e 1 else do -e 0"
      echo "   -x exclude_str       exclude call stacks containing thse strings. can be specified more than once. This is mostly for debugging at this point"
      echo "   -X include_str       include only call stacks containing thse strings. can be specified more than once. This is mostly for debugging at this point"
      echo "   -v              verbose mode"
      exit
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
shift $((OPTIND -1))

IDIR=$DIR_IN
if [[ "$IDIR" == "" ]] || [[ ! -d "$IDIR" ]]; then
  echo "$0.LINENO you must enter -d dir_with_prf.dat_files or -d $IDIR not found"
  exit 1
fi
LIST=($(find $IDIR -name docker_cpu_stats.txt))
echo "LIST= $LIST, list mx= ${#LIST[@]}"

for ((i=0; i < ${#LIST[@]}; i++)); do

#echo "$0.$LINENO RESP=$(grep sigusr2 ${LIST[$i]})"
RESP=$(grep sigusr2 ${LIST[$i]})
#if [ "$RESP" == "" ]; then
#  continue
#fi

IDIR=$(dirname ${LIST[$i]})
CLK_PRF=0
CLK_TOD=0
if [ -e $IDIR/spin.x.txt ]; then
  CLK_PRF=$(awk '/t_first= /{printf("%s", $2);}' $IDIR/spin.x.txt)
  CLK_TOD=$(awk '/t_gettimeofday= /{printf("%s", $2);}' $IDIR/spin.x.txt)
fi

if [[ "$PXX" != "" ]] && [[ "$CPU_BSY" != "" ]]; then
  PXX=
fi
if [[ "$CPU_BSY" != "" ]] && [[ "$OUTFILE" == "" ]]; then
  OUTFILE="summary"
fi
if [[ "$PXX" != "" ]] && [[ "$OUTFILE" == "" ]]; then
  OUTFILE="summary"
fi

FG_STKCOL="FlameGraph/stackcollapse-perf.pl"
LKFOR_FG_DIRS=($SCR_DIR/../  $HOME  $HOME/repos)
for ((ii=0; ii < ${#LKFOR_FG_DIRS[@]}; ii++)); do
  #echo "$0.$LINENO try  $i/$FG_STKCOL"
  if [ -e ${LKFOR_FG_DIRS[$ii]}/$FG_STKCOL ]; then
    fg_scr_dir=${LKFOR_FG_DIRS[$ii]}
    echo "found $FG_STKCOL in dir $fg_scr_dir"
    break
  fi
done
echo "$0.$LINENO found $FG_STKCOL in $fg_scr_dir"
echo "___________ onum= $i dir= $IDIR"

samples_per_sec=99

x_str=
sep=
for ((i=0; i < ${#EXCL_ARR[@]}; i++)); do
  x_str="${x_str}${sep}${EXCL_ARR[$i]}"
  sep="|"
done

X_str=
sep=
for ((i=0; i < ${#INCL_ARR[@]}; i++)); do
  X_str="${X_str}${sep}${INCL_ARR[$i]}"
  sep="|"
done

# __container_stats 1647029526.494557053 0 6d5c2a012b1a1ace0fffc81b2791aff0d3e8d30b11b9f2ff41249109808772bd
# __cpu.stat
# nr_periods 2537340
# nr_throttled 508
# throttled_time 196221582114
# __cpuacct.stat
# user 25515036
# system 681248
# __cpuacct.usage
# 262751628314962
# __blkio.throttle.io_serviced
# 259:4 Read 72
# 259:4 Write 989
# 259:4 Sync 110
# 259:4 Async 951
# 259:4 Total 1061
# Total 1061
# __blkio.throttle.io_service_bytes
# 259:4 Read 1835008
# 259:4 Write 1355997184
# 259:4 Sync 1990656
# 259:4 Async 1355841536
# 259:4 Total 1357832192
# Total 1357832192
# __memory.stat
# cache 735780864
# rss 59590410240
# rss_huge 53221523456
# shmem 0
# mapped_file 5840896
# dirty 102400
# writeback 0
# pgpgin 87673846
# pgpgout 86972211
# pgfault 233552909
# pgmajfault 25
# inactive_anon 0
# active_anon 59536715776
# inactive_file 788443136
# active_file 1024000
# unevictable 0
# hierarchical_memory_limit 64424509440
# total_cache 735780864
# total_rss 59590410240
# total_rss_huge 53221523456
# total_shmem 0
# total_mapped_file 5840896
# total_dirty 102400
# total_writeback 0
# total_pgpgin 87673846
# total_pgpgout 86972211
# total_pgfault 233552909
# total_pgmajfault 25
# total_inactive_anon 0
# total_active_anon 59536715776
# total_inactive_file 788443136
# total_active_file 1024000
# total_unevictable 0
# 
awk -v sum_file="sv/sum.tsv" -v in_dir="$IDIR" '
  BEGIN{
    csi_mx = -1;
  }
  /^__container_stats / {
     #  1647029526.494557053 0 6d5c2a012b1a1ace0fffc81b2791aff0d3e8d30b11b9f2ff41249109808772bd
     #printf("got %s\n", $0);
     tm = $2;
     cid = $3;
     if (!(cid in cid_list)) {
       cid_list[cid] = ++cid_mx;
       cid_lkup[cid_mx] = cid;
     }
     cs_i[cid]++;
     cntr = $4;
     if (tm_beg == "") {
        tm_beg = tm;
     }
     tm_end = tm;
     tm_dff = tm_end - tm_beg;
     while ((getline) > 0) {
      if(substr($1, 1, 2) == "__") {
        if ($1 == "__cpu.stat") {
          sect = "per"
        } else if ($1 == "__cpuacct.stat") {
          sect = "cpu"
        } else if ($1 == "__cpuacct.usage") {
          sect = "usage"
        } else if ($1 == "__blkio.throttle.io_serviced") {
          sect = "io_count"
        } else if ($1 == "__blkio.throttle.io_service_bytes") {
          sect = "io_bytes"
        } else if ($1 == "__memory.stat") {
          sect = "mem"
        } else {
          break;
        }
        if (!(sect in sect_list)) {
          sect_list[sect] = ++sect_mx;
          sect_lkup[sect_mx] = sect;
        }
        continue;
      }
      if (sect == "per" || sect == "cpu") {
        if (!((sect,$1) in key_list)) {
          key_list[sect,$1] = ++key_mx[sect];
          key_lkup[sect,key_mx[sect]] = $1;
          #printf("added key[%s]= %s %s\n", key_mx[sect], sect, $1);
        }
        fctr= 1.0;
        if (sect == "per") {
          if($1 == "throttled_time") { fctr = 1e-9; }
        } else {
          fctr = 0.01;
        }
        stats[cid, cs_i[cid], sect, $1] = $2 * fctr;
      } else if (sect == "usage") {
        if (!((sect,sect) in key_list)) {
          key_list[sect,sect] = ++key_mx[sect];
          key_lkup[sect,key_mx[sect]] = sect;
          #printf("added key[%s]= %s %s\n", key_mx[sect], sect, $1);
        }
        stats[cid, cs_i[cid], sect, sect] = $1 * 1e-9;
      } else if (sect == "io_count" || sect == "io_bytes") {
        dev = $1;
        typ = $2;
        dt = dev " " typ;
        if (dev == "Total") {
         dt = $1;
        }
        v   = $3;
        if (!((sect,dt) in key_list)) {
          key_list[sect,dt] = ++key_mx[sect];
          key_lkup[sect,key_mx[sect]] = dt;
          #printf("added key[%s]= %s %s\n", key_mx[sect], sect, dt);
        }
        stats[cid, cs_i[cid], sect, (dev " " typ)] = $2;
      } else if (sect == "mem") {
        if (substr($1, 1, 6) == "total_") { continue;}
        if (!((sect,$1) in key_list)) {
          key_list[sect,$1] = ++key_mx[sect];
          key_lkup[sect,key_mx[sect]] = $1;
          #printf("added key[%s]= %s %s\n", key_mx[sect], sect, $1);
        }
        stats[cid, cs_i[cid], sect, $1] = $2;
        if ($1 == "unevictable") { 
         # assume last one
         next;
        }
      }
      }
   }
  END{
    did_hdr=0;
    for (c=1; c <= cid_mx; c++) {
      cid = cid_lkup[c];
      for (r=2; r <= cs_i[cid]; r++) {
        if (did_hdr == 0) {
         sep = "";
         hdr="";
         for (i=1; i <= sect_mx; i++) {
          sect = sect_lkup[i];
          if (did_hdr == 0) {
            for (k=1; k <= key_mx[sect]; k++) {
              hdr = hdr "" sprintf("%s%s %s", sep, sect, key_lkup[sect,k]);
              sep = "\t";
              #key_lkup[sect,k]);
            }
          }
         }
         printf("%s\n", hdr);
         did_hdr = 1;
        }
        sep = "";
        kk=0;
        for (i=1; i <= sect_mx; i++) {
          sect = sect_lkup[i];
          for (k=1; k <= key_mx[sect]; k++) {
              ky = key_lkup[sect,k];
              v0 = stats[cid, r-1, sect, ky];
              v1 = stats[cid, r, sect, ky];
              v2 = v1 - v0;
              if (sect == "io_bytes" || sect== "mem") { v2 = v1 }
              if (sect == "mem") {
                fctr = 1.e-6;
                if (index(ky, "pg") > 0) { fctr = 1.0; }
                v2 *= fctr;
              }
              #printf("stats[%s, %s, %s, %s]= %s\n", cid, r, sect, ky, v1);
              printf("%s%.3f", sep, v2);
              kk_avg[++kk] += v2;
              kk_n[kk]++;
              #printf("%s%.3f", sep, v1);
              sep = "\t";
          }
        }
        printf("\n");
        #exit(0);
      }
    }
    printf("\n");
    printf("__hdr\t%s\t%s\n","dir", hdr) >> sum_file;
    sep = "\t";
    printf("__det\t%s",in_dir) >> sum_file;
    for (k=1; k <= kk; k++) {
      printf("%s%.3f", sep, kk_avg[k]/kk_n[k]) >> sum_file;
      sep = "\t";
    }
    printf("\n") >> sum_file;
  }
  ' $IDIR/$INF

#echo "$0.$LINENO bye"
#exit 1

 echo $0.$LINENO awk -v select_intrvl_in_secs="$INTRVL" -v incl_str="$X_str" -v excl_str="$x_str" -v host_str="$HOST_STR" -v max_high="$MAX_HIGH" -v file_list_in="$FILE_LIST" -v end_dir="$END_DIR" -v cpus_busy="$CPU_BSY" -v pxx="$PXX" -v outfile="$OUTFILE" -v sel_prf_str="$SEL_PRF_STR"  -v samples_per_sec="$samples_per_sec" -v clk_prf="$CLK_PRF" -v clk_tod="$CLK_TOD" -v scr_dir="$fg_scr_dir" -v dir="$IDIR" -v onum=$i > /dev/stderr
awk -v select_intrvl_in_secs="$INTRVL" -v incl_str="$X_str"  -v excl_str="$x_str"  -v host_str="$HOST_STR" -v max_high="$MAX_HIGH" -v file_list_in="$FILE_LIST" -v end_dir="$END_DIR" -v cpus_busy="$CPU_BSY" -v pxx="$PXX" -v outfile="$OUTFILE" -v sel_prf_str="$SEL_PRF_STR"  -v samples_per_sec="$samples_per_sec" -v clk_prf="$CLK_PRF" -v clk_tod="$CLK_TOD" -v scr_dir="$fg_scr_dir" -v dir="$IDIR" -v onum=$i '
  BEGIN{
     clk_prf += 0;
     clk_tod += 0;
     cid_mx = -1;
     max_high += 0;
     select_intrvl_n = 0;
     if (select_intrvl_in_secs != "" && index(select_intrvl_in_secs, ",") > 0) {
       select_intrvl_n = split(select_intrvl_in_secs, select_intrvl_arr, ",");
       for (i=1; i <= select_intrvl_n; i++) {
         select_intrvl_arr[i] += 0;
       }
     }
     #printf("select_intrvl_n= %s\n", select_intrvl_n);
     if (file_list_in != "") {
       file_list_n = split(file_list_in, file_list, ",");
       for (i=1; i <= file_list_n; i++) { printf("file_list[%d]= %s\n", i, file_list[i]);}
     }
     excl_n = split(excl_str, excl_arr, "|");
     incl_n = split(incl_str, incl_arr, "|");
  }
/^__cpu.cfs_quota_us /{
   container_num = $2+0;
   if (cid_mx < container_num) { cid_mx = container_num; }
   dckr[container_num, "cpu_quota_secs"] = 1.0e-6 * $3;
}
/^__cpu.cfs_period_us /{
   container_num = $2;
   dckr[container_num, "period_secs"] = 1.0e-6 * $3;
}

#__docker_stat 1638012722.414496 0  11 1 316373496
  /^__docker_stat / {
    ds_epch = $2;
    # field 4-6 are the docker cpu.stat fields
    #  nr_periods: how many full periods have been elapsed.
    #  nr_throttled: number of times we exausted the full allowed bandwidth
    #  throttled_time: total time the tasks were not run due to being overquota in nanosecs
    ds_period = $4+0;
    ds_nr_throttled = $5+0;
    ds_intrvl = ds_period * 0.1; # each period is 0.1 seconds
    ds_throttle = $6+0;
    if (ds_throttle > 0) {
      printf("onum= %d %%thr= %.6f\n", onum, 100.0 * ds_throttle/(0.1*ds_period * 1e6));
    }
    ds_throttled_container_num = $3;
    ds_throttled_secs = 1.0e-9 * ds_throttle;
    ds_throttled_periods = ds_nr_throttled;
  }
  /^__docker_sigusr2 |^__docker_sigint / {
# so we actually saw throttling and sent sigusr2 to dump call stacks.
# Now we look for a perf*.dat*.txt file at the time (or after the time) of the sigusr2
# we might have back to back dump files if the throttling occurred during 2 consecutive seconds.
# I have a dumb loop to look for dat.txt files with date strings up to 10 seconds after the sigusr2 time. Seems to work.

    printf("got __doc sig %s\n", $0);
    #if ($1 == "__docker_sigint" && sv_mx > 0) {
    #  next;
    #}
    doing_sigint = 0;
    cid = -1;
    if ($1 == "__docker_sigint") {
       doing_sigint = 1;
    }
    if (NF == 4) {
      elap = $2;
      epch = $3;
      dtstr= $4;
    }
    if (NF == 5) {
      cid = $2;
      elap = $3;
      epch = $4;
      dtstr= $5;
    }
    prf_tm = 0;
    if (clk_prf > 0 && clk_tod > 0) {
      prf_tm = epch - clk_tod + clk_prf;
      printf("estimate sigusr2 perf timestamp= %f epch= %s\n", prf_tm, epch);
    }
    

# __docker_sigusr2 0 15062 1638012722.414496 20211127113202
#           1 1
# 1   5 7 9 1 3
# 20211127113202
# __docker_sigusr2 0 15062 1638012722.414496 2021/11/27_11:32:02
    dt_rt= substr(dtstr, 1, 8);
    dt2mm= substr(dtstr, 1, 12);
    dt2ss= substr(dtstr, 1, 14);
    dt_hh= substr(dtstr, 9, 2);
    dt_mm= substr(dtstr, 11, 2);
    dt_ss= substr(dtstr, 13, 2);
    printf("hh= %s mm = %s ss= %s, dt= %s\n", dt_hh, dt_mm, dt_ss, dtstr);
    got_it=0;
    if (file_list_n >= (sv_mx+1) && outfile != "") {
      ufl = file_list[sv_mx+1];
      printf("using ufl from file_list[%d]= %s, file_list_n= %d\n", sv_mx+1, ufl, file_list_n);
      got_it = 1;
    } else {
    if ($1 == "__docker_sigint") {
      cid_beg = 0;
      cid_beg = cid_mx;
    } else {
      cid_beg = cid; 
      cid_end = cid; 
    }
    for (cid= cid_end; cid >= cid_beg; cid--) {
    for (i=0; i < 20; i++) {
      udt = dt2ss+i;
      ufl = sprintf("%s/prf_%d.dat.%.0f*.txt", dir, cid, udt);
      #ufl = sprintf("%sdir "/prf_" cid ".dat." udt "*.txt";
      printf("ufl= %s  cid= %d udt= %d\n", ufl, cid, udt);
      if (system("test -f " ufl)==0) {
        got_it=1;
        printf("got_it ufl= %s  cid= %d udt= %d\n", ufl, cid, udt);
        break;
      }
    }
       if (got_it == 1) { break; }
    }
    }
    if (got_it == 1) {
      sv_mx++;
      if (file_list_n > 0) {
         printf("file_list[%d]= %s\n", sv_mx, file_list[sv_mx]);
         printf("use ufl      = %s\n", ufl);
      }
      cmd = "ls " ufl " | head -1";
      cmd | getline line;
      close(cmd);
      print line;
      sv_ufl[sv_mx,"nm"] = line;
      sv_ufl[sv_mx,"epch"] = epch;
      sv_ufl[sv_mx,"prf_tm"] = prf_tm;
      sv_ufl[sv_mx,"interval"] = ds_intrvl;
      sv_ufl[sv_mx,"ds_throttled_secs"] = ds_throttled_secs;
      sv_ufl[sv_mx,"ds_throttled_periods"] = ds_throttled_periods;

    } else {
      printf("missed finding match for prf file ufl= %s dt2ss= %s\n", ufl, ddt2ss);
      printf("missed finding match for prf file ufl= %s dt2ss= %s\n", ufl, ddt2ss) > "/dev/stderr";
    }
  }
  END{
#      michelangelo-pr 374019 [005] 9233946.162347:   10101010 cpu-clock: 
# now we have the list of call stack perf .dat.txt files.
# Read each .dat.txt file.
# Now we know that the file was written within a second of the throttling.
# That is, throttling occurred in at least one 0.1 docker time slot.
# but we dont know exactly when that time slot began or ended.
# We do know each time slot interval is 0.1 second.
# So we take the last time stamp and say "this is when we sent the sigusr2"
# and assume the throttling occurred during the previous second (or maybe a little more).
# Now we could just dump the callstack and let the user try to figure out what looks "weird".
# But we can do better than that.
# We can bucket the call stacks by 0.1 second intervals. Then you can just look at a time bucket
# and say "this bucket shows throttling" because if shows >= max allowed cpu usage.
#
# The time bucket is each to do. Just insert a "time_0.xx" string as the bottom-most module name.
# That is: all the call stacks occuring in the interval "sigusr2 time" to "sigusr2 time - 0.1 sec" will be
# in the "time_0.1" bucket, all the calls stacks occurring in the interval sigusr2-0.1 -> sigusr-0.2) will be
# in the "time_0.2" bucket and so on. I think after sigusr2-1.2 seconds I just clump all those call stacks togther.
# The flamegraph scripts treat the "time_0.1" string like a module name.
# All that is great, but the code below also has to parse the perf call stack stuff.
    if (sel_prf_str != "") {
      sel_prf_str+= 0;
    }

    for (i=1; i <= sv_mx; i++) {
      ufl = sv_ufl[i,"nm"];
      printf("ufl[%d]= %s\n", i, ufl);
    }
    #printf("+++++++++ using 1 instead of sv_mx= %d\n", sv_mx);
    bkts[1] = bkts[2] = 0;
    bkt_samples[1] = bkt_samples[2] = 0;
    tot_tm_diff = 0;
    #for (i=2; i <= 2; i++) 
    for (i=1; i <= sv_mx; i++) {
      if (sel_prf_str != "" && sel_prf_str != i) {
        continue;
      }
      ufl = sv_ufl[i,"nm"];
      #bkts[1] = bkts[2] = 0;
      #bkt_samples[1] = bkt_samples[2] = 0;
      cg=0;
      line_num=-1;
      ln_n = 0;
      while ((getline < ufl) > 0) {
        if ($0 != "") {
          if (ln_n == 1) { str="";}
          if (substr($0, 1, 1) == "#") {
            continue;
          }
          ln_arr[++ln_n] = $0;
          str = str ";" $0;
          continue;
        }
        ln_arr[++ln_n] = $0;
        ln_n_end = ln_n;
        ln_n = 0;
        if (excl_n > 0) {
          got_it = 0;
          for (ei=1; ei <= excl_n; ei++) {
            if (index(str, excl_arr[ei]) > 0) { got_it=1; break;}
          }
          if (got_it == 1) {
            continue;
          }
        }
        if (incl_n > 0) {
          got_it = 0;
          for (ei=1; ei <= incl_n; ei++) {
            if (index(str, incl_arr[ei]) > 0) { got_it=1; break;}
          }
          if (got_it == 0) {
            continue;
          }
        }
              use_it = 1;
        for (ln_i=1; ln_i <= ln_n_end; ln_i++) {
          $0 = ln_arr[ln_i];
          char0 = substr($0, 1, 1);
          if (1==1 && select_intrvl_n > 0 && $0 != "") {
           #printf("got into select_intervl= %s\n", $0);
           if (char0 != "\t" && char0 != "#") {
            got_it=0;
            cpu_fld = -1;
            for (k=1; k <= NF; k++) {
             if ($k ~ /^\[[0-9][0-9][0-9]\]$/) {
              got_it = 1;
              #printf("match %s\n", $k);
              cpu_fld = k;
              break;
             } 
            }
            if (cpu_fld != -1) {
              tm = $(cpu_fld+1)+0;
              if (tm_first_val == "") {
                tm_first_val = tm;
              }
              use_it = 1;
              v = tm - tm_first_val;
              if (select_intrvl_n == 1 && v < select_intrvl_arr[1]) {
                # if only 1 value then use it as the starting time of the lines to use
                use_it = 0;
                break;
              }
              if (select_intrvl_n == 2 && (v < select_intrvl_arr[1] || v > select_intrvl_arr[2])) {
                # if the time is before select[1] or after select[2] then drop it
                use_it = 0;
                break;
              }
            }
           }
          }
          if (use_it == 0) { continue;}
        
        line_num++;
        # this xt-h- stuff just reduces some process name. Instead of see 60 xt-h-xx process just map them to 1 xt-h process
        if (char0 != "" && char0 != "\t" && char0 != "#") {
          if (match($0, /^dw-.* - GET .h/) > 0) {
            $0 = "dw-GET " substr($0, RLENGTH+1);
            $1 = $1;
          } else if (match($0, /^dw-.* - POST \//) > 0) {
            $0 = "dw-POST " substr($0, RLENGTH+1);
            $1 = $1;
          } else if (match($0, /^dw-[0-9]+ /) > 0) {
            $0 = "dw-x " substr($0, RLENGTH+1);
            $1 = $1;
          } else if (match($1, /-[0-9]+$/) > 0) {
            $1 = substr($1, 1, RSTART) "x";;
            $1 = $1;
          }
          if ($1 != "" && substr($1, 1, 5) == "xt-h-") {
            $1 = "xt-h";
          }
        }
        sv_lines[i,line_num] = $0;
        if ($0 == "") { continue; }
        if (char0 != "\t" && char0 != "#") {
          # this is not a call graph line. Look for the cpu number line [001]. The process name can have spaces (i think) so get the cpu string and work backwards.
          cg++;
          sv_ufl[i, "cg_mx"] = cg;
          got_it=0;
          cpu_fld = -1;
          for (k=1; k <= NF; k++) {
            if ($k ~ /^\[[0-9][0-9][0-9]\]$/) {
              got_it = 1;
              #printf("match %s\n", $k);
              cpu_fld = k;
              break;
            } 
          }
          if (cpu_fld == -1) {
            printf("missed cpu fld for line[%d]= %s file= %s\n", line_num, $0, ufl);
            exit(1);
          }
          tm = $(cpu_fld+1)+0;
         
          mod = $1;
          for (k=2; k <= cpu_fld -2; k++) {
            mod = mod " " $k;
          }
          if (substr(mod, 1, 4) == "xt-h") {
            mod = "xt-h";
          }
          if (substr(mod, 1, 1) == ":" && ((":" $2) == $1)) {
            # not sure why perf puts :pid_num for the process name sometimes. Maybe because the process is has died already.
            # But this causes (sometimes) lots of pointless module name call stacks. Just put them all in _unknown module.
            $1 = "_unknown";
            $1 = $1;
            sv_lines[i,line_num] = $0;
          }
          #line[66562] tm= 3614141.041924, tm_beg[1]= 3614137.655765, str= tcheck 465830 [019] 3614141.041924:   10101010 cpu-clock: 
          #line[66584] tm= 0.000000, tm_beg[1]= 3614137.655765, str= Reference Handl 14579 [029] 3614141.045519:   10101010 cpu-clock: 
          #line[66591] tm= 3614141.046863, tm_beg[1]= 3614137.655765, str= xt-h 16253 [015] 3614141.046863: 10101010 cpu-clock:

          # get list of modules
          if (!((i,mod) in mod_list)) {
            mod_list[i,mod] = ++mod_mx[i];
            mod_lkup[i,mod_mx[i]] = mod;
            mod_inst[i,mod] = 0;
          }
          ++mod_inst[i,mod];
          # save timestamp module name, init number of call graph lines to 0, save linenumber we are at in file (for debugging).
          sv_lines_time[i,line_num] = tm;
          cg_arr[i, cg, "tm"]  = tm;
          if (cg_arr[i, "tm_beg"] == "") {
             cg_arr[i, "tm_beg"] = tm;
          }
          tm_dff = tm - cg_arr[i, "tm_beg"];
          tm_bkt = int(tm_dff * 100);
          cg_arr[i, "tm_bkt", tm_bkt]++;
          if (cg_arr[i, "tm_bkt_tm_beg", tm_bkt] == "") {
            cg_arr[i, "tm_bkt_tm_beg", tm_bkt] = tm;
          }
          cg_arr[i, "tm_bkt_tm_end", tm_bkt] = tm;
          #printf("cg_arr[%d, "tm_bkt_tm_beg", %d]= %.3f, end= %.3f\n", i, tm_bkt, cg_arr[i, "tm_bkt_tm_beg", tm_bkt], cg_arr[i, "tm_bkt_tm_end", tm_bkt]);
          cg_arr[i, "tm_bkt_mx"] = tm_bkt;
          cg_arr[i, "tm_end"] = tm;
          cg_arr[i, cg, "mod"] = mod;
          cg_arr[i, cg, "mx"]  = 0;
          cg_arr[i, cg, "line_num"]  = line_num;
        } else {
          # so we are in a call graph line. Skip the address offset. save the module/function info
          $1 = "";
          $1 = $1;
          u = ++cg_arr[i, cg, "mx"]
          cg_arr[i, cg, "lines", u ] = $0;
        }
        }
      }
      close(ufl)
      # so we have read the perf dat txt file and got call stacks
      sv_line_num[i] = line_num;
      tm_end[i] = tm;
      pxx += 0;
      cpus_busy += 0;
      cpu_quota_per_period = dckr[container_num, "cpu_quota_secs"] / dckr[container_num, "period_secs"];
      printf("cpu quota= %.3f, pxx_cpus= %.3f, cpus_busy= %.3f\n", cpu_quota_per_period, (0.01*pxx*cpu_quota_per_period), cpus_busy);
      cg_mx[i] = cg;
      tm_bkt_beg = 0;
      tm_bkt_end = cg_arr[i, "tm_bkt_mx"];
      for (tb = 0; tb <= tm_bkt_end/10; tb++) {
        tm_b[tb]=0;
      }
      for (tb = tb_bkt_beg; tb <= tm_bkt_end; tb++) {
        #printf("tm_bkt[%d]= %3d\n", tb, cg_arr[i, "tm_bkt", tb]);
        tbi = int(tb/10);
        tm_b[tbi] += cg_arr[i, "tm_bkt", tb];
        if (tm_b_tm_beg[tbi] == "") {
          tm_b_tm_beg[tbi] = cg_arr[i, "tm_bkt_tm_beg", tb];
        }
        tm_b_tm_end[tbi] = cg_arr[i, "tm_bkt_tm_end", tb];
      }
      for (tb = 0; tb <= tm_bkt_end/10; tb++) {
        cpus = 10.0 * tm_b[tb] / samples_per_sec;
        #printf("tm_b[%d]= %.3f ", tb, cpus);
        if ((pxx > 0 && cpus >= (0.01*pxx*cpu_quota_per_period)) || (cpus_busy > 0.0 && cpus >= cpus_busy)) {
            tm_b_st[tb] = "thr";
        } else {
            tm_b_st[tb] = "not";
        }
        tm_b_vals[tb] = 0
        #printf(", %s\n", tm_b_st[tb]);
      }
      tot_tm_diff +=  cg_arr[i,"tm_end"] - cg_arr[i,"tm_beg"];
      printf("\n\ndir %d module counts for file %d, tm_beg= %f tm_end= %f tm_diff= %.3f tot_tm_diff= %.3f\n", onum, i, cg_arr[i,"tm_beg"], cg_arr[i,"tm_end"], cg_arr[i,"tm_end"] - cg_arr[i,"tm_beg"], tot_tm_diff);
      if (outfile != "") {
          how_many_recs= 0;
          outfile_lst[1] = outfile "_thr.txt";
          outfile_lst[2] = outfile "_not_thr.txt";
          outfile_sc[1] = outfile "_thr_sc.txt";
          outfile_sc[2] = outfile "_not_thr_sc.txt";
          outfile_bkts[1] = outfile "_thr_bkts.txt";
          outfile_bkts[2] = outfile "_not_thr_bkts.txt";
          outfile_smpls[1] = outfile "_thr_smpls.txt";
          outfile_smpls[2] = outfile "_not_thr_smpls.txt";
          h_str="";
          if (host_str != "") { h_str = "_" host_str;}
          outfile_svg[1] = outfile "_thr" h_str ".svg";
          outfile_svg[2] = outfile "_not_thr" h_str ".svg";
          outfile_str[1] = "throttled";
          outfile_str[2] = "not throttled";
          got_it = 2;
          for (j=0; j <= sv_line_num[i]; j++) {
            if (sv_lines_time[i, j] != "") {
            ln_num_beg = j;
            tm = sv_lines_time[i, j];
                use_it = 1;
            tm_dff = tm - cg_arr[i, "tm_beg"];
              if (select_intrvl_n == 1 && tm_dff < select_intrvl_arr[1]) {
                # if only 1 value then use it as the starting time of the lines to use
                use_it = 0;
              }
              if (select_intrvl_n == 2 && (tm_dff < select_intrvl_arr[1] || tm_dff > select_intrvl_arr[2])) {
                # if the time is before select[1] or after select[2] then drop it
                use_it = 0;
              }
            if (use_it == 1) {
              how_many_recs++;
            }
            tm_bkt = int(tm_dff * 100);
            tb = int(tm_bkt/10)
            if (tm_b_st[tb] == "thr") {
              got_it = 1;
              tm_b_vals[tb]++;
              #continue;
              #printf("%s\n", sv_lines[i,j]) > outfile_thr;
            } else {
              got_it = 2;
            }
            if (sv_lines[i, j] != "" && substr(sv_lines[i,j], 1,1) != "#") {
               bkt_samples[got_it]++;
            }
            }
            if (j > 0 && sv_lines[i,j] == sv_lines[i,j-1]) {continue;}
            if (index(sv_lines[i,j], "[unknown] ([unknown])") > 0) {continue;}
            if (match(sv_lines[i,j], /\[unknown\] .*perf-.*.map/)) {continue;}
            if ((max_high > 0 && ((j-ln_num_beg) > max_high && sv_lines[i,j] != ""))) {
              #printf("skip[%d,%d] tm_dff= %.3f use_it= %d txt= %s\n", sv_line_num[i],j-ln_num_beg, tm_dff, use_it, sv_lines[i,j]);
              continue;
            }
            printf("%s\n", sv_lines[i,j]) >> outfile_lst[got_it];
          }
          printf("how_many_recs= %d\n", how_many_recs);
          for (tb = 0; tb <= tm_bkt_end/10; tb++) {
            if (tm_b_st[tb] == "thr") { bkts[1]++; } else { bkts[2]++; }
            #printf("tb_b_vals[%d]= %d\n", tb, tm_b_vals[tb]);
          }
          printf("_______i= %d, sv_mx= %d\n", i, sv_mx);
          if ((i == sv_mx || (sel_prf_str != "" && sel_prf_str == i))) {
            for (fl=1; fl <= 2; fl++) {
              printf("%d\n", bkts[fl]) >> outfile_bkts[fl];
              printf("%d\n", bkt_samples[fl]) >> outfile_smpls[fl];
            }
            for (fl=1; fl <= 2; fl++) {
              close(outfile_bkts[fl]);
              close(outfile_smpls[fl]);
            }
            for (fl=1; fl <= 2; fl++) {
              close(outfile_lst[fl]);
            }
          }
          if (end_dir == 1 && (i == sv_mx || (sel_prf_str != "" && sel_prf_str == i))) {
            for (fl=1; fl <= 2; fl++) {
              bkts[fl] = 0;
              bkt_samples[fl]  = 0;
            }
            for (fl=1; fl <= 2; fl++) {
              while ((getline < outfile_bkts[fl]) > 0) {
                bkts[fl] += $1;
              }
              close(outfile_bkts[fl]);
              while ((getline < outfile_smpls[fl]) > 0) {
                bkt_samples[fl] += $1;
              }
              close(outfile_smpls[fl]);
            }
          for (fl=1; fl <= 2; fl++) {
           if (bkts[fl] == 0) { continue;}
          cmd = "perl " scr_dir "/FlameGraph/stackcollapse-perf.pl " outfile_lst[fl] " > " outfile_sc[fl];
          printf("cmd= %s\n", cmd);
          system(cmd);
          close(cmd);
          close(outfile_sc[fl]);
          h_str = "";
          if (host_str != "") { h_str = ", " host_str;}
          ttl = sprintf("%s elapsed time covers %.3f secs of tot %.3f secs%s", outfile_str[fl], bkts[fl]*0.1, 0.1*(bkts[1]+bkts[2]), h_str);
          sttl = sprintf("avg cpus/period= %.3f vs cpu quota of %.3f cpus/period",
             bkt_samples[fl]/samples_per_sec / (bkts[fl]*0.1),cpu_quota_per_period);
          cmd = "perl " scr_dir "/FlameGraph/flamegraph.pl --title \"" ttl "\" --subtitle \"" sttl "\" "  outfile_sc[fl] " > " outfile_svg[fl];
          printf("cmd= %s\n", cmd);
          system(cmd);
          close(cmd);
          }
          }
        #printf("bye ___here\n");
        continue;
      }
      for (j=1; j <= mod_mx[i]; j++) {
        v = mod_lkup[i,j];
        printf("%-5d %s\n", mod_inst[i,v], v);
      }
      tm_beg[i] = tm_end[i] - ds_intrvl; # so if the interval is 1 second then the time we want is end_time - 1.0 seconds
      if (doing_sigint == 1) {
        tm_beg[i] = tm_end[i];
      }
      #tm_beg[i] = tm_end[i] - 4*ds_intrvl;
      printf("tm_beg[%d] = %f, tm_end[%d]= %f, ds_intrvl= %f\n", i, tm_beg[i], i, tm_end[i], ds_intrvl);
      bef=0;
      aft=0;
      bef_line= -1;
      tm_0 = cg_arr[i,1,"tm"];
      tm_1 = cg_arr[i,cg_mx[i],"tm"];
      #
      # find the lines before the sigusr2 time
      tm_bef[0] = -1;
      tm_bef[1] = -1;
      tm_aft[0] = -1;
      tm_aft[1] = -1;
      for (j=1; j <= cg_mx[i]; j++) {
        v = cg_arr[i,j,"line_num"];
        #printf("line[%d] tm= %f, tm_beg[%d]= %f, str= %s\n",  v, cg_arr[i,j,"tm"],i, tm_beg[i], sv_lines[i,v]);
        if (cg_arr[i,j,"tm"] < tm_beg[i]) {
          if (tm_bef[0] == -1) {
            tm_bef[0] = cg_arr[i,j,"tm"];
          }
          tm_bef[1] = cg_arr[i,j,"tm"];
          bef++;
          bef_line= v;
        } else {
          if (tm_aft[0] == -1) {
            tm_aft[0] = cg_arr[i,j,"tm"];
          }
          tm_aft[1] = cg_arr[i,j,"tm"];
          aft++;
        }
      }
      printf("__onum= %d file %d, bef= %d aft= %d, line_num= %d tm_covered_in_file= %f, bef_line= %d\n", onum, i, bef, aft, bef_line, tm_1-tm_0, bef_line);
      delete samples_per_period;
      for (k=0; k < 2; k++) {
        onum_str = sprintf("%.2d", onum);
        fl = "tmp_" i "_" k".txt";
        flsc = "tmp_" i "_" k"_sc.txt";
        flsc1 = "tmp_" i "_" k"_sc1.txt";
        flsvg = sprintf("tmp_%s_%.2d_%d_sc.svg", onum_str, i, k);
        if (k==0) {
          # This is the case of the call stacks before the interval with the throttling
          # We can just do a standard stackcollapse-perf.pl -> flamegraph.pl for this case
          for (j=0; j < bef_line; j++) {
            if (1==2) {
            if (sv_lines_time[i,j] != "") {
              tm_dff = int(10 * (tm_beg[i] - (sv_lines_time[i,j])));
              printf("tm_dff[%d,%d]= %f\n", i,j,tm_dff);
              printf("time_%.3d_%s\n", tm_dff, sv_lines[i,j]) > fl;
            } else {
               printf("%s\n", sv_lines[i, j]) > fl;
            }
            } else {
            printf("%s\n", sv_lines[i, j]) > fl;
            }
          }
          close(fl);
          cmd = "perl " scr_dir "/FlameGraph/stackcollapse-perf.pl " fl " > " flsc;
          printf("cmd= %s\n", cmd);
          system(cmd);
          close(cmd);
          close(flsc);
          # below code looks for duplicate consecutive stack entries and only emits the 1st entry
          while ((getline < flsc) > 0) {
            nn = split($0, sarr, ";");
            printf("%s", sarr[1]) > flsc1
            ij = 2;
            while (ij <= nn) {
              if (sarr[ij-1] == sarr[ij]) {ij++; continue;}
              printf(";%s", sarr[ij]) > flsc1;
              ij++;
            }
            printf("\n") > flsc1;
          }
          close(flsc1);
#          if (1==2) {
#          while ((getline < flsc) > 0) {
#            #if (substr($1, 1, 5) == "time_") {
#            if (match($0, /^time_[0-9]+_/) > 0) {
#              $0 = substr($0, 1, RLENGTH-1) ";" substr($0, RLENGTH+1);
#              $1 = $1;
#            }
#            printf("%s\n", $0) > flsc1;
#          }
#          close(flsc1);
#          } else {
#            flsc1 = flsc;
#          }
          ttl = sprintf("not throttled elapsed time covers %.3f secs", tm_bef[1] - tm_bef[0]);
          if ((dckr[container_num, "period_secs"]+0) == 0) {
            dckr[container_num, "period_secs"] = 0.1;
          }
          cpu_quota_per_period = dckr[container_num, "cpu_quota_secs"] / dckr[container_num, "period_secs"];
          sttl = sprintf("avg cpus/period= %.3f vs cpu quota of %.3f cpus/period",
            (bef/samples_per_sec) /(tm_bef[1] - tm_bef[0]), cpu_quota_per_period);
            #bef_line /(tm_bef[1] - tm_bef[0]), 
          #cmd = "perl " scr_dir "/FlameGraph/flamegraph.pl --title \"" ttl "\" " flsc1 " > " flsvg;
          cmd = "perl " scr_dir "/FlameGraph/flamegraph.pl --title \"" ttl "\" --subtitle \"" sttl "\" "  flsc1 " > " flsvg;
          printf("cmd= %s\n", cmd);
          system(cmd);
          close(cmd);
        }
        if (k==1 && doing_sigint == 0) {
          # The call stacks for the interval with cpu throttling.
          for (j=bef_line; j <= sv_line_num[i]; j++) {
            # insert the fake "time_xx" prefix to the module name
            if (sv_lines_time[i,j] != "") {
              tm_dff = int(10 * (sv_lines_time[i,j] - tm_beg[i]));
              tm_dff_str = sprintf("time_%.2d", tm_dff);
              printf("%s_%s\n", tm_dff_str, sv_lines[i,j]) > fl;
              samples_per_period[tm_dff_str]++;
            } else {
               printf("%s\n", sv_lines[i, j]) > fl;
            }
          }
          close(fl);
          cmd = "perl " scr_dir "/FlameGraph/stackcollapse-perf.pl " fl " > " flsc;
          printf("cmd= %s\n", cmd);
          system(cmd);
          close(cmd);
          # read back in the collapsed stack list and break the time_xx_{moduleName} into time_xx;ModuleName so that flamegraph groups everything by time_xx bucket
          while ((getline < flsc) > 0) {
            if (substr($1, 1, 5) == "time_") {
              $1 = substr($1, 1, 7) ";" substr($1, 9);
              $1 = $1;
            }
            printf("%s\n", $0) > flsc1;
          }
          close(flsc);
          close(flsc1);
          mx_val = 0;
          mx_ky  = "";
          for (ky in samples_per_period) {
             if (mx_ky == "" || mx_val < samples_per_period[ky]) {
                mx_ky = ky;
                mx_val = samples_per_period[ky];
             }
          }
          ttl = sprintf("throttled elapsed time covers %.3f secs", tm_aft[1] - tm_aft[0]);
          sttl = sprintf("throttled periods= %d throttled_secs= %.3f. max= %.3f cpus/period in interval %s",
            sv_ufl[i,"ds_throttled_periods"], sv_ufl[i,"ds_throttled_secs"], (mx_val/samples_per_sec)/dckr[container_num, "period_secs"], mx_ky);
          cmd = "perl " scr_dir "/FlameGraph/flamegraph.pl --title \"" ttl "\" --subtitle \"" sttl "\" "  flsc1 " > " flsvg;
          printf("cmd= %s\n", cmd);
          system(cmd);
          close(cmd);
        }
      }
    }
  }' $IDIR/$INF

done
