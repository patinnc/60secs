#!/usr/bin/env bash

#arg1 is infra_cputime.txt filename
VERBOSE=0
export LC_ALL=C
SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

ck_last_rc() {
   local RC=$1
   local FROM=$2
   if [ $RC -gt 0 ]; then
      echo "$0: got non-zero RC=$RC at $LINENO. called from line $FROM" > /dev/stderr
      exit $RC
   fi
}

while getopts "hvb:e:f:m:n:o:O:S:t:w:" opt; do
  case ${opt} in
    b )
      BEG_TS=$OPTARG
      ;;
    e )
      END_TS=$OPTARG
      ;;
    f )
      IN_FL=$OPTARG
      ;;
    m )
      MUTT_OUT_FL=$OPTARG
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
    t )
      TS_INITIAL=$OPTARG
      ;;
    w )
      WORK_DIR=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 read infra_cputime.txt file"
      echo "Usage: $0 [ -v ] -f input_file [ -o out_file ] [ -n num_cpus ] [ -S sum_file ]"
      echo "   -f input_file  like infra_cputime.txt"
      echo "   -m muttley_out_file    muttley complete table of calls over time. format is like chart table without hdrs titles rows"
      echo "   -O options     comma separated list of options. No spaces"
      echo "   -o out_file    assumed to be input_file with .tsv appended"
      echo "   -n num_cpus    number of cpus on the server"
      echo "   -S sum_file    summary file"
      echo "   -w work_dir    all tsv output files go in this dir"
      echo "   -b beg_ts      begin epoch time stamp (for clipping)"
      echo "   -e end_ts      end epoch time stamp (for clipping)"
      echo "   -t ts_initial  ts_initial (when the data collection was begun)"
      echo "   -v verbose mode"
      exit 1
      ;;
    : )
      echo "$0 Invalid option: $OPTARG requires an argument. cmdline= ${@}" 1>&2
      exit 1
      ;;
    \? )
      echo "$0 Invalid option: $OPTARG, cmdline= ${@} " 1>&2
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
  OUT_FL="${WORK_DIR}/${IN_FL}.tsv"
fi
#NUM_CPUS=$2
#PID RSS    VSZ     TIME COMMAND
CUR_DIR=`pwd`

MUTT_FL=
MUTT_NM="muttley_host_calls.tsv"
echo "$0.$LINENO: $MUTT_NM"
pwd
# I'm now sure where this file gets created. It might get created at collection time in which case it would be the source dir
if [ -e $MUTT_NM ]; then
  echo "$0.$LINENO: got $MUTT_NM"
  MUTT_FL=$MUTT_NM
fi
if [ -e $WORK_DIR/$MUTT_NM ]; then
  echo "$0.$LINENO: got $MUTT_NM"
  MUTT_FL=$WORK_DIR/$MUTT_NM
fi

OSTYP=$OSTYPE
if [[ "$OSTYP" == "linux-gnu"* ]]; then
  AWK_BIN=awk
if [ -e $SCR_DIR/../patrick_fay_bin/gawk ]; then
  AWK_BIN=$SCR_DIR/../patrick_fay_bin/gawk
fi
elif [[ "$OSTYP" == "darwin"* ]]; then
   # Mac OSX
  AWK_BIN=gawk # has to installed locally
fi
#AWK_BIN=awk  # awk is a link to gawk

my_scr=$(basename $0)
if [ "$WORK_DIR" == "" ]; then
  WORK_DIR="."
fi
my_tmp_output_file="$WORK_DIR/tmp_${my_scr}.txt"

echo $0.$LINENO $AWK_BIN -v beg_ts="$BEG_TS" -v end_ts="$END_TS" -v ts_initial="$TS_INITIAL" -v script_nm="$0.$LINENO.awk" -v mutt_file="$MUTT_FL" -v mutt_ofile="$MUTT_OUT_FL" -v cur_dir="$CUR_DIR" -v options="$OPTIONS" -v num_cpus="$NUM_CPUS" -v sum_file="$SUM_FILE" -v ofile="$OUT_FL"
$AWK_BIN -v work_dir="$WORK_DIR" -v beg_ts="$BEG_TS" -v end_ts="$END_TS" -v ts_initial="$TS_INITIAL" -v script_nm="$0.$LINENO.awk" -v mutt_file="$MUTT_FL" -v mutt_ofile="$MUTT_OUT_FL" -v cur_dir="$CUR_DIR" -v options="$OPTIONS" -v num_cpus="$NUM_CPUS" -v sum_file="$SUM_FILE" -v ofile="$OUT_FL" -v ifile="$IN_FL"  '
  BEGIN {
   rc = 0;
   num_cpus += 0;
   cg_cntr_typ_srvc = 1;
   cg_cntr_typ_sys  = 2;
   nm_lkfor = "yyy_service_name"; # dummy name
   mutt_host_calls_i = -100; # just some value to indicate whether we found host.calls
   mutt_host_calls_n = 0; # number of host.calls entries
   mutt_host_calls_str = "";
   col_pid = -1;
   col_rss = -1;
   col_vsz = -1;
   col_tm  = -1;
   col_cmd = -1;
   beg_ts += 0.0;
   end_ts += 0.0;
   pse_col_pid = -1;
   pse_col_rss = -1;
   pse_col_vsz = -1;
   pse_col_tm  = -1;
   pse_col_cmd = -1;
   muttley_use_nm = "host.calls";
   use_top_pct_cpu = 0;
   if (index(options, "%cpu_like_top") > 0) {
     use_top_pct_cpu = 1;
   }
   options_get_max_val = 0;
   if (index(options, "get_max_val") > 0) {
     options_get_max_val = 1;
   }
   printf("use_top_pct_cpu= %d, options= \"%s\"\n", use_top_pct_cpu, options);
   plst[++plst_mx] = "ksoftirqd/";
   plst[++plst_mx] = "cpuhp/";
   plst[++plst_mx] = "watchdog/";
   plst[++plst_mx] = "migration/";
   plst[++plst_mx] = "ksoftirqd/";
   plst[++plst_mx] = "cpuhp/";
   plst[++plst_mx] = "kworker/";
   plst[++plst_mx] = "ksoftirqd/";
        px_mx = 0;
        px[++px_mx] = 10;
        px[++px_mx] = 20;
        px[++px_mx] = 30;
        px[++px_mx] = 40;
        px[++px_mx] = 50;
        px[++px_mx] = 60;
        px[++px_mx] = 70;
        px[++px_mx] = 80;
        px[++px_mx] = 90;
        px[++px_mx] = 95;
        px[++px_mx] = 99;
        px[++px_mx] = 99.5;
        px[++px_mx] = 100;
    while((getline < ifile) > 0) {
      if ($1 == "__muttley__") {
        v = 2;
        if (mutt_frst_hdr == "") { v = 1;  mutt_frst_hdr = $0; }
        while((getline < ifile) > 0) {
          if ($0 == "" || substr($0, 1, 2) == "__") {
            break;
          }
          mutt_last[v, $1] = $2;
          if (!($1 in mutt_last_nms_list)) {
            mutt_last_nms_list[$1] = ++mutt_last_mx;
            mutt_last_nms_lkup[utt_last_mx] = $1;
            mutt_last_nms[mutt_last_mx] = $1;
          }
        }
      }
    }
    close(ifile);
    m_drops = 0;
    for (i=1; i <= mutt_last_mx; i++) {
       v = mutt_last_nms[i];
       if (mutt_last[1,v] == mutt_last[2,v]) {
         mutt_drop[v] = 1;
         m_drops++;
       }
    }
    printf("got muttley lines to drop (due to no changes to instances) = %d out of mutt_last_mx= %d infile= %s\n", m_drops, mutt_last_mx, ifile);
  }
function join(array, start, end, sep,    result, i)
{
    if (sep == "")
       sep = " "
    else if (sep == SUBSEP) # magic value
       sep = ""
    result = array[start]
    for (i = start + 1; i <= end; i++)
        result = result sep array[i]
    return result
}
function get_max(a, b) {
  if (a > b) {
    return a;
  };
  return b;
}
function ck_netdev_max_val(val, i, fld,    my_n, isnum) {
  if (netdev_max[i,fld,"peak"] == "" || netdev_max[i,fld,"peak"] < val) {
     netdev_max[i,fld,"peak"] = val;
  }
  if (val != "") {
    isnum = (val == (val+0));
    if (!isnum) {
    my_n = ++netdev_max[i,fld,"val_n"];
    netdev_max[i,fld,"val_arr",my_n] = val;
    }
  }
  netdev_max[i,fld,"sum_sq"] += val*val;
  netdev_max[i,fld,"sum"] += val;
  netdev_max[i,fld,"n"]++;
}
function ck_diskstats_max_val(val, i, j,    my_n, isnum) {
  # v = diskstats_max[i,k];
  if (diskstats_max[i,j,"peak"] == "" || diskstats_max[i,j,"peak"] < val) {
    diskstats_max[i,j,"peak"] = val;
  }
  if (val != "") {
    isnum = (val == (val+0));
    if (!isnum) {
    diskstats_max[i,j,"val_n"]++;
    my_n = diskstats_max[i,j,"val_n"];
    diskstats_max[i,j,"val_arr",my_n] = val;
    }
  }
  diskstats_max[i,j,"sum_sq"] += val*val;
  diskstats_max[i,j,"sum"] += val;
  diskstats_max[i,j,"n"]++;
}
function compute_pxx(kk, my_n, res_i, arr_in,     pi, pii, piu, uval, piup1) {
    pi  = 0.01 * px[kk] * my_n; # index into array for this percentile
    pii = int(pi);       # integer part
    if (pii != pi) {
      # so pi is not an integer
      piu = pii+1;
      if (piu > my_n) { piu = my_n; }
      uval = arr_in[res_i[piu]]
    } else {
      piu = pii;
      if (piu >= my_n) {
        uval = arr_in[res_i[my_n]];
      } else {
        piup1=piu + 1;
        uval = 0.5*(arr_in[res_i[piu]] + arr_in[res_i[piup1]]);
      }
    }
    return uval;
}

function prt_diskstats(i, cols,    dev, fmt_str, k, v, my_n, my_avg, my_stdev, my_p997, my_peak, hdr, grp, mtrc, mtrcm1,
res_i, idx, j, px, px_mx, str) {
    compute_diskstats(diskstats_mx,1, i);
    dev = diskstats_data[1,i,"device"];
    mtrcm1 = "IO stats";
    grp = "infra_procs";
    fmt_str = grp"\t%s\t%.4f\t%s %s";
    for (k=2; k <= cols; k++) {
       v = diskstats_vals[k];
       hdr = diskstats_hdrs[k];
       mtrc = hdr " " dev;
       printf(fmt_str "\n", mtrcm1, v, hdr, dev) > sum_file;
       my_n     = diskstats_max[i,k,"n"];
       #printf(fmt_str"\n", v, hdr, dev) > sum_file;
       if (my_n > 0) {
         my_avg   = diskstats_max[i,k,"sum"]/my_n;
         my_stdev = sqrt((diskstats_max[i,k,"sum_sq"]/my_n)-(my_avg*my_avg));
         my_p997  = my_avg + 3.0*my_stdev;
         my_peak  = diskstats_max[i,k,"peak"];
       } else {
         my_avg   = 0.0;
         my_stdev = 0.0;
         my_p997  = 0.0;
         my_peak  = 0.0;
       }
       printf(fmt_str" avg\n", mtrcm1, my_avg, hdr, dev) > sum_file;
       printf(fmt_str" peak\n", mtrcm1, my_peak, hdr, dev) > sum_file;
        delete arr_in;
        delete res_i;
        delete idx;
        n = diskstats_max[i,k,"val_n"];
        my_n = 0;
        for(j=1; j <= n; j++) {
          #if (diskstats_max[i,k,"val_arr",j] != "") {
          if ((i,k,"val_arr",j) in  diskstats_max) {
          idx[++my_n] = my_n;
          arr_in[my_n] = diskstats_max[i,k,"val_arr",j];
          }
        }
        asorti(idx, res_i, "arr_in_compare");
        #fflush();
        str = sprintf("%s\t%s\t%f\t%s val_arr", grp, mtrcm1, my_n, mtrc);
        for(j=1; j <= n; j++) {
            str = str "" sprintf("\t%f", arr_in[res_i[j]]);
        }
        printf("%s\n", str) > sum_file;
        #fflush();
        # https://www.dummies.com/education/math/statistics/how-to-calculate-percentiles-in-statistics/
        if (index(fmt_str, " val_arr") > 0) {
          my_sum = 0.0;
          n = 0;
          for(j=1; j <= n; j++) {
            my_sum += arr_in[res_i[j]];
            n++;
          }
          if (n > 0) {
            my_sum /= n;
          } else {
            my_sum = 0.0;
          }
          str = mtrc " avg";
          printf("%s\t%s\t%s\t%f\n", grp, mtrcm1, str, my_sum) >> ofile;
        }
        if (1==2) {
        printf("++++++++____________++++++++++++ io %s %s my_y= %d\n", mtrcm1, mtrc, my_n);
        for (kk=1; kk <= px_mx; kk++) {
          uval = compute_pxx(kk, my_n, res_i, arr_in);
          str = mtrc " p" px[kk] " ";
          printf("%s\t%s\t%f\t%s\n", grp, mtrcm1, uval, str) > sum_file;
          printf("%s\t%s\t%f\t%s\n", grp, mtrcm1, uval, str);
        }
        }
    }
    #v = diskstats_max[i,k];
    #printf("infra_procs\tIO stats\t%.4f\t%s %s peak\n", v, diskstats_hdrs[k], dev) > sum_file;
}
function arr_in_compare(i1, v1, i2, v2,    l, r, m1, m2)
{
    m1 = arr_in[i1];
    m2 = arr_in[i2];
    if (m2 > m1)
        return -1
    else if (m1 == m2)
        return 0
    else
        return 1
}
function do_netdev_print(fmt_str, i, fld, iend, ibeg, scl,     n, fmt_arr, dev, my_n, my_avg, my_stdev, my_997, my_peak,
tm_diff, diff, v, grp, mtrc, mtrcm1, res_i, idx, j, px, px_mx, my_sum, str) {
   dev     = netdev_data[1,i,"device"];
   n = split(fmt_str, fmt_arr, "\t");
   grp = fmt_arr[1];
   mtrc = fmt_arr[4];
   mtrcm1 = fmt_arr[2];
   tm_diff = netdev_dt[iend]-netdev_dt[ibeg];
   diff = (netdev_data[iend,i,fld]-netdev_data[ibeg,i,fld])/scl;
   v = diff / tm_diff;
   my_n     = netdev_max[i,fld,"n"];
   printf(fmt_str"\n", v, dev) > sum_file;
   if (my_n > 0) {
     my_avg   = netdev_max[i,fld,"sum"]/my_n;
     my_stdev = sqrt((netdev_max[i,fld,"sum_sq"]/my_n)-(my_avg*my_avg));
     my_p997  = my_avg + 3.0*my_stdev;
     my_peak  = netdev_max[i,fld,"peak"];
   } else {
     my_avg   = 0.0;
     my_stdev = 0.0;
     my_p997  = 0.0;
     my_peak  = 0.0;
   }
   printf(fmt_str" avg+3stdev\n", my_p997, dev) > sum_file;
   printf(fmt_str" peak\n", my_peak, dev) > sum_file;
        delete arr_in;
        delete res_i;
        delete idx;
        n=0;
        for(j=2; j <= iend; j++) {
          n++;
          idx[n] = n;
          tm_diff = netdev_dt[j]-netdev_dt[j-1];
          diff = (netdev_data[j,i,fld]-netdev_data[j-1,i,fld])/scl;
          v = diff / tm_diff;
          arr_in[n] = v;
        }
        my_n     = n;
        asorti(idx, res_i, "arr_in_compare");
        #fflush();
        str = sprintf("%s\t%s\t%f\t%s %s val_arr", grp, mtrcm1, my_n, mtrc, dev);
        #printf("%s\t%s\t%f\t%s %s val_arr", grp, mtrcm1, my_n, mtrc, dev) > sum_file;
        for(j=1; j <= n; j++) {
          str = str "" sprintf("\t%f", arr_in[res_i[j]]);
        }
        printf("%s\n", str) > sum_file;
        #fflush();
        # https://www.dummies.com/education/math/statistics/how-to-calculate-percentiles-in-statistics/
        if (index(fmt_str, " val_arr") > 0) {
          my_sum = 0.0;
          n = 0;
          for(j=1; j <= n; j++) {
            my_sum += arr_in[res_i[j]];
            n++;
          }
          if (n > 0) {
            my_sum /= n;
          } else {
            my_sum = 0.0;
          }
          str = "avg " mtrc;
          printf("infra_procs\t%s\t%s\t%s %s\n", mtrcm1, my_sum, str, dev) > sum_file;
        }
        if (1==2) {
        printf("++++++++____________++++++++++++ io %s %s my_y= %d\n", mtrcm1, mtrc, my_n);
        for (kk=1; kk <= px_mx; kk++) {
          uval = compute_pxx(kk, my_n, res_i, arr_in);
          str = mtrc " p" px[kk] " ";
          printf("infra_procs\t%s\t%f\t%s %s\n", mtrcm1, uval, str, dev) > sum_file;
          printf("infra_procs\t%s\t%f\t%s %s\n", mtrcm1, uval, str, dev);
        }
        }
}

function compute_diskstats(di,dim1, dj) {
      dev_name = diskstats_data[di,dj,"device"];
      rd_sec   = diskstats_data[di,dj,"rd_sec"];
      wr_sec   = diskstats_data[di,dj,"wr_sec"];
      rd_ios   = diskstats_data[di,dj,"rd_ios"];
      wr_ios   = diskstats_data[di,dj,"wr_ios"];
      rd_ticks = diskstats_data[di,dj,"rd_ticks"];
      wr_ticks = diskstats_data[di,dj,"wr_ticks"];
      rq_ticks = diskstats_data[di,dj,"rq_ticks"];
      tot_ticks= diskstats_data[di,dj,"tot_ticks"];

      ctm = diskstats_dt[di];
      if (di > 1) {
          tm_diff         = ctm      -diskstats_dt[dim1];
          rd_ios_diff     = get_max(0, rd_ios   -diskstats_data[dim1,dj,"rd_ios"]);
          wr_ios_diff     = get_max(0, wr_ios   -diskstats_data[dim1,dj,"wr_ios"]);
          rd_sec_diff     = get_max(0, rd_sec   -diskstats_data[dim1,dj,"rd_sec"]);
          wr_sec_diff     = get_max(0, wr_sec   -diskstats_data[dim1,dj,"wr_sec"]);
          rd_ticks_diff   = get_max(0, rd_ticks -diskstats_data[dim1,dj,"rd_ticks"]);
          wr_ticks_diff   = get_max(0, wr_ticks -diskstats_data[dim1,dj,"wr_ticks"]);
          rq_ticks_diff   = get_max(0, rq_ticks -diskstats_data[dim1,dj,"rq_ticks"]);
          tot_ticks_diff  = get_max(0, tot_ticks-diskstats_data[dim1,dj,"tot_ticks"]);
          rw_ticks_diff   = rd_ticks_diff + wr_ticks_diff;
          rw_ios_diff     = rd_ios_diff + wr_ios_diff;
          rw_sec_diff     = rd_sec_diff + wr_sec_diff;
          rd_kps          = rd_ios_diff/tm_diff/1024;
          wr_kps          = wr_ios_diff/tm_diff/1024;
          rd_MB           = rd_sec_diff / 2.0/1024.0; # 512/1024
          wr_MB           = wr_sec_diff / 2.0/1024.0;
          rd_KB_per_rd    = (rd_ios_diff > 0 ? 1024.0*rd_MB/rd_ios_diff : 0.0);
          wr_KB_per_wr    = (wr_ios_diff > 0 ? 1024.0*wr_MB/wr_ios_diff : 0.0);
          await    = (rw_ios_diff > 0.0 ? rw_ticks_diff/rw_ios_diff : 0.0);
          await_rd = (rd_ios_diff > 0.0 ? rd_ticks_diff/rd_ios_diff : 0.0);
          await_wr = (wr_ios_diff > 0.0 ? wr_ticks_diff/wr_ios_diff : 0.0);
          avgrq_sz = (rw_ios_diff > 0.0 ? rw_sec_diff/rw_ios_diff : 0.0);
          avgqu_sz =  0.001 * rq_ticks_diff/tm_diff;
          dev_util = 0.1*tot_ticks_diff/tm_diff;

          diskstats_vals[1]= dev_name;
          diskstats_vals[2]= rd_kps;
          diskstats_vals[3]= wr_kps;
          diskstats_vals[4]= rd_MB/tm_diff;
          diskstats_vals[5]= wr_MB/tm_diff;
          diskstats_vals[6]= rd_KB_per_rd;
          diskstats_vals[7]= wr_KB_per_wr;
          diskstats_vals[8]= await;
          diskstats_vals[9]= await_rd;
          diskstats_vals[10]= await_wr;
          diskstats_vals[11]= avgqu_sz;
          diskstats_vals[12]= avgrq_sz;
          diskstats_vals[13]= dev_util;
          diskstats_vals_mx = 13;
      }
      if (diskstats_hdrs[1] == "" ) {
          diskstats_hdrs[1]="dev";
          diskstats_hdrs[2]="rd kIO/s";
          diskstats_hdrs[3]="wr kIO/s";
          diskstats_hdrs[4]="rd_MB/s";
          diskstats_hdrs[5]="wr_MB/s";
          diskstats_hdrs[6]="rd_KB/rd";
          diskstats_hdrs[7]="wr_Kb/wr";
          diskstats_hdrs[8]="await(io_ms/io)";
          diskstats_hdrs[9]="await_rd";
          diskstats_hdrs[10]="await_wr";
          diskstats_hdrs[11]="avgqu-sz(avg_rq_ms/s)";
          diskstats_hdrs[12]="avgrq_sz(sctrs/ios)";
          diskstats_hdrs[13]="util%";
          diskstats_hdrs_mx = 13;
      }
}
#__ps_ef_beg__ 1616876223 1616905023
#UID        PID  PPID  C STIME TTY          TIME CMD
#root         1     0  1 Mar16 ?        04:37:55 /sbin/init
function rd_ps_tm(rec, beg0_end1,   i, dt_diff, pid, tmi, proc, rss, vsz, pid_i, first_tm_proc, got_kw, proc_i, pid_proc, pp_i, secs_prev, dy_i, days, tm, arr, v, use_proc_i) {
    if (rec == 1) {
    ++pse_mx;
    pse_dt[pse_mx] = $2;
    #delete pid_hsh;
    #printf("mx= %d\n", mx);
    return;
    }
    if (rec == 2) {
    if ($1 == "UID") {
      for(i=1; i <= NF; i++) {
        if ($(i) == "PID") { pse_col_pid = i; continue; }
        if ($(i) == "PPID") { pse_col_ppid = i; continue; }
        if ($(i) == "RSS") { pse_col_rss = i; continue; }
        if ($(i) == "VSZ") { pse_col_vsz = i; continue; }
        if ($(i) == "TIME") { pse_col_tm = i; continue; }
        if ($(i) == "COMMAND") { pse_col_cmd = i; continue; }
        if ($(i) == "CMD") { pse_col_cmd = i; continue; }
      }
    }
    return;
    }
    if (rec >= 3) {
    dt_diff = 0.0;
    if (pse_mx > 1) {
      dt_diff = pse_dt[pse_mx] - pse_dt[pse_mx-1];
    }
      pid  = $(pse_col_pid);
      tmi  = $(pse_col_tm);
      ppid  = $(pse_col_ppid);
      proc = $(pse_col_cmd);
      if (pse_col_rss != -1) {
        rss  = $(pse_col_rss);
      }
      if (pse_col_vsz != -1) {
        vsz  = $(pse_col_vsz);
      }
      if (!(pid in pse_pid_list)) {
         pse_pid_list[pid] = ++pse_pid_mx;
         pse_pid_lkup[pse_pid_mx] = pid;
      }
      pid_i = pse_pid_list[pid];
      first_tm_proc = 0;
      got_kw = -1;
      if (!(pid in ps_tree_list)) {
        ps_tree_list[pid] = ++ps_tree_mx;
        ps_tree_lkup[ps_tree_mx,"pid"] = pid;
        ps_tree_lkup[ps_tree_mx,"ppid"] = ppid;
        ps_tree_tm[pid] = 0;
      }
      if (!(ppid in ppid_tree_list)) {
        ppid_tree_list[ppid] = ++ppid_tree_mx;
        ppid_tree_lkup[ppid_tree_mx,"ppid"] = ppid;
        ppid_tree_lkup[ppid_tree_mx,"kids"] = 0;
      }
      ps_tree2[pid] = ppid;
      ps_line2[pid] = $0;
      ps_proc2[pid] = proc;
      pid_tr_i = ps_tree_list[pid];
      ppid_tr_i = ppid_tree_list[ppid];
      #kids = ++ppid_tree_lkup[ppid_tr_i,"kids"];
      #ppid_tree_lkup[ppid_tr_i,"kid_list",kids] = pid;
      cntr_i = "";
      if ($8 == "docker-containerd-shim" || $8 == "containerd-shim") {
        if ($8 == "containerd-shim") {
          for(ik=9; ik <= NF; ik++) {
            if ($(ik) == "-workdir") {
              cntr = $(ik+1);
              nnn = split(cntr, arr_tmp, "/");
              cntr = arr_tmp[nnn];
            }
          }
        } else {
          cntr = $9;
        }
        if (!(cntr in cntr_list)) {
          cntr_list[cntr] = ++cntr_mx;
          cntr_lkup[cntr_mx,"cntr"] = cntr;
          cntr_lkup[cntr_mx,"pid"]  = pid;
        }
        cntr_i = cntr_list[cntr];
        ps_cntr2[pid] = cntr_i;
        ps_tree_lkup[pid_tr_i,"cntr_i"] = cntr_i;
      }
      for (i=1; i <= plst_mx; i++) {
        if (index(proc, plst[i]) == 1) {
         if (!(plst[i] in pse_proc_list)) {
           pse_proc_list[plst[i]] = ++pse_proc_mx;
           pse_proc_lkup[pse_proc_mx] = plst[i];
           proc_kw = pse_proc_mx;
         }
         got_kw = proc_kw;
         proc_i = proc_kw;
         break;
        }
      }
      if (got_kw == -1) {
        if (!(proc in pse_proc_list)) {
           pse_proc_list[proc] = ++pse_proc_mx;
           pse_proc_lkup[pse_proc_mx] = proc;
        }
        proc_i = pse_proc_list[proc];
      }
      pid_proc = pid "," proc;
      if (!(pid_proc in pse_pid_proc_list)) {
         pse_pid_proc_list[pid_proc] = ++pse_pid_prod_mx;
         pse_pid_proc_lkup[pse_pid_proc_mx] = pid_proc;
         pse_pid_proc_prev[pse_pid_proc_mx] = 0;
         first_tm_proc = 1;
      }
      pp_i = pse_pid_proc_list[pid_proc];
      if (pse_pid_prev[pid_i,"proc"] != proc) {
         pse_pid_prev[pid_i,"secs"] = 0;
         first_tm_proc = 1;
      }
      secs_prev = pse_pid_prev[pid_i,"secs"];
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
#        if (beg0_end1 == 0) {
#          secs_prev = secs;
#        } else {
#          secs_prev = 0;
#        }
      }
      if (dt_diff > 0.0) {
        v = (secs - secs_prev)/dt_diff;
        if (v < 0.0) { v = 0.0; }
        use_proc_i = proc_i;
        if (got_kw != -1) {
          use_proc_i = proc_kw;
        }
        pse_sv[mx, use_proc_i] += v;
        if (pse_col_rss != -1) {
          pse_sv_rss[mx, use_proc_i] += rss;
        }
        if (pse_col_vsz != -1) {
          pse_sv_vsz[mx, use_proc_i] += vsz;
        }

        pse_tot[use_proc_i] += (secs - secs_prev);
        pse_tot_n[use_proc_i]++;
        pid += 0;
        ps_tree_tm[pid] += secs - secs_prev;
        tot_tm += secs - secs_prev;
      }
      pse_pid_prev[pid_i,"secs"] = secs
      pse_pid_prev[pid_i,"proc"] = proc;
    }
}
  /^__ps_ef_beg__ /{
    # UID         PID   PPID  C STIME TTY          TIME CMD
    psef_ln = 1;
    rd_ps_tm(psef_ln, 0);
    getline;
    rd_ps_tm(++psef_ln, 0);
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
        rd_ps_tm(++psef_ln, 0);
        ++ps_ef_lines_mx[1];
        for (i=1; i < cmd_idx; i++) {
          ps_ef_lines[1,ps_ef_lines_mx[1],i] = $(i);
          #printf("ps_ef_line[%d,%d]= %s\n", ps_ef_lines_mx, i, $(i));
        }
        ps_ef_lines[1,ps_ef_lines_mx[1],cmd_idx] = substr($0, cmd_col, length($0));
        #printf("ps_ef_line[%d,%d]= %s\n", ps_ef_lines_mx, cmd_idx, ps_ef_lines[ps_ef_lines_mx,cmd_idx]);
      }
    }
  }
  /^__ps_ef_end__ /{
    # UID         PID   PPID  C STIME TTY          TIME CMD
    psef_ln = 1;
    rd_ps_tm(psef_ln, 1);
    getline;
    rd_ps_tm(++psef_ln, 1);
    cmd_col = index($0, "CMD");
    cmd_idx = NF;
    for (i=1; i <= NF; i++) {
       ps_ef_end_list[$(i)] = ++ps_ef_end_mx;
       ps_ef_end_lkup[ps_ef_end_mx] = $(i);
    }
    while ( getline  > 0) {
      if ($0 == "") {
         break;
      } else {
        ++ps_ef_end_lines_mx[2];
        rd_ps_tm(++psef_ln, 1);
        for (i=1; i < cmd_idx; i++) {
          ps_ef_lines[2,ps_ef_lines_mx[2],i] = $(i);
          #printf("ps_ef_line[%d,%d]= %s\n", ps_ef_lines_mx, i, $(i));
        }
        ps_ef_lines[2,ps_ef_lines_mx[2],cmd_idx] = substr($0, cmd_col, length($0));
        #printf("ps_ef_line[%d,%d]= %s\n", ps_ef_lines_mx, cmd_idx, ps_ef_lines[ps_ef_lines_mx,cmd_idx]);
      }
    }
  }
#__net_dev__ 1613325090 1613361090
#Inter-|   Receive                                                |  Transmit
# face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
#    lo: 23718376346263 49951651466    0    0    0     0          0         0 23718376346263 49951651466    0    0    0     0       0          0
#  eth1:       0       0    0    0    0     0          0         0        0       0    0    0    0     0       0          0
#docker0:       0       0    0    0    0     0          0         0        0       0    0    0    0     0       0          0
#  eth0: 1789224819997486 3969195799626   14    0    0    14          0  24714218 2735699337437607 4819718487079    0    0    0     0       0          0
  /^__net_eth0_stats__ /{
    if (got___net_dev__ == 1) { next; }
    got___net_eth0_stats__ = 1;
    i = 0;
    ts = $2 + 0;
    ts_skip = 0;
    typ_rec = $1;
    if ((beg_ts > 0.0 && ts < beg_ts) || (end_ts > 0.0 && ts > end_ts)) {
      ts_skip = 1;
      while ( getline  > 0) {
        if ($0 == "" || substr($0, 1, 2) == "__") {
          break;
        }
      }
    }
    if (ts_skip == 0) {
    netdev_dt[++netdev_mx] = $2;
    netdev_lns[netdev_mx] = 0;
    rd_bytes_col = 0;
    wr_bytes_col = 0;
    j = 0;
    while ( getline  > 0) {
      ++i;
      if ($0 == "" || substr($0, 1, 2) == "__") {
         break;
      } else {
      j++;
      netdev_data[netdev_mx,j,"device"] = "eth0";
      netdev_data[netdev_mx,j,"bytes_rd"] += $1;
      netdev_data[netdev_mx,j,"bytes_wr"] += $2;
      netdev_data[netdev_mx,j,"packets_rd"] += $3;
      netdev_data[netdev_mx,j,"packets_wr"] += $4;
      netdev_lns[netdev_mx] = j;
      #printf("got netdev_eth0_stats line[%d,%d]= %s\n", netdev_mx, j, $0) > "/dev/stderr";
      }
    }
    }
  }

  /^__net_dev__ /{
    if (got___net_eth0_stats__ == 1 ) { next; }
    got___net_dev__ = 1;
    i = 0;
    ts = $2 + 0;
    ts_skip = 0;
    if ((beg_ts > 0.0 && ts < beg_ts) || (end_ts > 0.0 && ts > end_ts)) {
      ts_skip = 1;
      while ( getline  > 0) {
        if ($0 == "" || substr($0, 1, 2) == "__") {
          break;
        }
      }
    }
    if (ts_skip == 0) {
    netdev_dt[++netdev_mx] = $2+0;
    #printf("___netdev_dt[%d] = %f\n", netdev_mx, $2+0);
    netdev_lns[netdev_mx] = 0;
    rd_bytes_col = 0;
    wr_bytes_col = 0;
    j = 0;
    while ( getline  > 0) {
      ++i;
      if ($0 == "" || substr($0, 1, 2) == "__") {
         break;
      } else {
        if (i == 1) { continue; }
        if (i == 2) {
            if ($1 != "face") { printf("%s expected \"face\" as 1st word of 2nd net_dev line, got= %s\n", script_nm, $1); exit 1;}
              #printf(".0= %s\nFS= %s\n", $0, FS) > "/dev/stderr";
            gsub(/\|/, " ");
              #printf(".0= %s\nFS= %s, NF= %d\n", $0, FS, NF) > "/dev/stderr";
            #n = split($0, arr);
            for (k=1; k <= NF; k++) {
              arr[k] = $k;
              if(netdev_mx == 1) {printf("fld[%d]= %s\n", k, arr[k])}
              if (arr[k] == "bytes") {
                if (rd_bytes_col == 0) {
                  rd_bytes_col = k;
                } else {
                  wr_bytes_col = k;
                  break;
                }
              }
            }
          if(netdev_mx == 1) {printf("=========---------_________ got rd_bytes_col= %d, wr_bytes_col= %d\n", rd_bytes_col, wr_bytes_col);}
            continue;
        }
      j++;
      netdev_data[netdev_mx,j,"device"] = $1;
      netdev_data[netdev_mx,j,"bytes_rd"] += $(rd_bytes_col);
      netdev_data[netdev_mx,j,"packets_rd"] += $(rd_bytes_col+1);
      netdev_data[netdev_mx,j,"bytes_wr"] += $(wr_bytes_col);
      netdev_data[netdev_mx,j,"packets_wr"] += $(wr_bytes_col+1);
      netdev_lns[netdev_mx] = j;
      }
    }
    }
  }

  /^__diskstats__ /{
#   8       0 sda 8619575 32211 794372805 4523480 181006599 266524862 29481431352 1752692472 0 228989488 1760207280
#   8       1 sda1 458 0 7240 104 910 2668 122392 9396 0 2924 9500
#   8       2 sda2 8032146 32211 787926426 3685420 181005689 266522194 29481308960 1752683076 0 228198064 1759359684
#   8       3 sda3 586582 0 6425142 837840 0 0 0 0 0 836788 837416
# 253       0 dm-0 8064303 0 787785446 4614272 434995945 0 29481308960 2347715344 0 228140820 2352456704
#   7       0 loop0 13838 0 111138 1328 3211 0 25624 504 0 76 988
#   7       1 loop1 0 0 0 0 0 0 0 0 0 0 0
# Field  1 -- # of reads completed. This is the total number of reads completed successfully.
# Field  2 -- # of reads merged, field 6 -- # of writes merged Reads and writes which are adjacent to each other may be merged for
#     efficiency.  Thus two 4K reads may become one 8K read before it is ultimately handed to the disk, and so it will be counted (and queued)
#     as only one I/O.  This field lets you know how often this was done.
# Field  3 -- # of sectors read.  This is the total number of sectors read successfully.
# Field  4 -- # of milliseconds spent reading.  This is the total number of milliseconds spent by all reads (as measured from __make_request() to end_that_request_last()).
# Field  5 -- # of writes completed.  This is the total number of writes completed successfully.
# Field  6 -- # of writes merged.  See the description of field 2.
# Field  7 -- # of sectors written. This is the total number of sectors written successfully.
    ts = $2 + 0;
    ts_skip = 0;
    if ((beg_ts > 0.0 && ts < beg_ts) || (end_ts > 0.0 && ts > end_ts)) {
      ts_skip = 1;
      while ( getline  > 0) {
        if ($0 == "" || substr($0, 1, 2) == "__") {
          break;
        }
      }
    }
    if (ts_skip == 0) {
    diskstats_dt[++diskstats_mx] = $2;
    diskstats_lns[diskstats_mx] = 0;
    diskstats_tots = 0;
    j = 0;
      j++;
      diskstats_lns[diskstats_mx] = j;
      diskstats_data[diskstats_mx,j,"device"] = "_total_";
    while ( getline  > 0) {
      if ($0 == "" || (length($1) > 2 && substr($1, 1, 2) == "__")) {
        break;
      }
      dev = $3;
      dev_len = length(dev);


#		if (NF >= 14)
#			sdev.rd_ios     = rd_ios;
#			sdev.rd_merges  = rd_merges_or_rd_sec;
#			sdev.rd_sectors = rd_sec_or_wr_ios;
#			sdev.rd_ticks   = (unsigned int) rd_ticks_or_wr_sec;
#			sdev.wr_ios     = wr_ios;
#			sdev.wr_merges  = wr_merges;
#			sdev.wr_sectors = wr_sec;
#			sdev.wr_ticks   = wr_ticks;
#			sdev.ios_pgr    = ios_pgr;
#			sdev.tot_ticks  = tot_ticks;
#			sdev.rq_ticks   = rq_ticks;
#
#			if (NF >= 18)
#				#/* Discard I/O */
#				sdev.dc_ios     = dc_ios;
#				sdev.dc_merges  = dc_merges;
#				sdev.dc_sectors = dc_sec;
#				sdev.dc_ticks   = dc_ticks;
#
#			if (NF >= 20)
#				# Flush I/O
#				sdev.fl_ios     = fl_ios;
#				sdev.fl_ticks   = fl_ticks;
#		else if (NF == 7)
#			#/* Partition without extended statistics */
#			#if (DISPLAY_EXTENDED(flags))
#		#		continue;
#
#			sdev.rd_ios     = rd_ios;
#			sdev.rd_sectors = rd_merges_or_rd_sec;
#			sdev.wr_ios     = rd_sec_or_wr_ios;
#			sdev.wr_sectors = rd_ticks_or_wr_sec;
#		

      use_it= 0;
      if (substr(dev, 1, 2) == "sd") {
        if (length(dev) == 3) {
          use_it = 1;
        } else {
          if (length(dev) == 4) {
             sb = substr(dev, 4, 1);
             isnum = (sb == (sb+0));
             if (!isnum) {
               use_it = 1;
             }
          }
        }
      }
      if (dev_len == 7 && substr(dev, 1, 4) == "nvme") {
        use_it = 1;
      }
      if (use_it == 1) {
        j++;
         # from https://github.com/sysstat/sysstat/blob/master/iostat.c
	       major = $1; minor = $2; dev_name = $3;
			   rd_ios = $4; rd_merges = $5; rd_sec = $6; rd_ticks = $7;
			   wr_ios = $8; wr_merges = $9; wr_sec = $10; wr_ticks = $11; ios_pgr = $12; tot_ticks = $13; rq_ticks = $14;
			   #dc_ios = $15; dc_merges = $16; dc_sec = $17; dc_ticks = $18;
			   #fl_ios = $19; fl_ticks = $20;

      diskstats_lns[diskstats_mx] = j;
      diskstats_data[diskstats_mx,j,"device"] = dev_name;
      diskstats_data[diskstats_mx,j,"rd_sec"] = rd_sec+0;
      diskstats_data[diskstats_mx,j,"wr_sec"] = wr_sec+0;
      diskstats_data[diskstats_mx,j,"rd_ios"] = rd_ios+0;
      diskstats_data[diskstats_mx,j,"wr_ios"] = wr_ios+0;
      diskstats_data[diskstats_mx,j,"rd_ticks"] = rd_ticks+0;
      diskstats_data[diskstats_mx,j,"wr_ticks"] = wr_ticks+0;
      diskstats_data[diskstats_mx,j,"rq_ticks"] = rq_ticks+0;
      diskstats_data[diskstats_mx,j,"tot_ticks"] = tot_ticks+0;

      diskstats_data[diskstats_mx,1,"rd_sec"] += rd_sec+0;
      diskstats_data[diskstats_mx,1,"wr_sec"] += wr_sec+0;
      diskstats_data[diskstats_mx,1,"rd_ios"] += rd_ios+0;
      diskstats_data[diskstats_mx,1,"wr_ios"] += wr_ios+0;
      diskstats_data[diskstats_mx,1,"rd_ticks"] += rd_ticks+0;
      diskstats_data[diskstats_mx,1,"wr_ticks"] += wr_ticks+0;
      diskstats_data[diskstats_mx,1,"rq_ticks"] += rq_ticks+0;
      diskstats_data[diskstats_mx,1,"tot_ticks"] += tot_ticks+0;
      }
    }
    }
  }
  /^__docker_ps__ /{
    ts = $2 + 0;
    ts_skip = 0;
    if ((beg_ts > 0.0 && ts < beg_ts) || (end_ts > 0.0 && ts > end_ts)) {
      ts_skip = 1;
      while ( getline  > 0) {
        if ($0 == "" || substr($0, 1, 2) == "__") {
          break;
        }
      }
    }
    if (ts_skip == 0) {
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
        if (n >= 4 && i == 2) {
           if (index(arr[i], "uber-usi") > 0) {
              k_serv++;
           } else {
              k_infra++;
           }
           # else {
           #   k_other++;
           #}
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
  }
  /^__muttley__ /{
    ts = $2 + 0;
    ts_skip = 0;
    if ((beg_ts > 0.0 && ts < beg_ts) || (end_ts > 0.0 && ts > end_ts)) {
      ts_skip = 1;
      while ( getline  > 0) {
        if ($0 == "" || substr($0, 1, 2) == "__") {
          break;
        }
      }
    }
    if (ts_skip == 0) {
    ++muttley_mx;
    muttley_dt[muttley_mx] = $2;
    delete tmutt_data;
    delete tmutt_list;
    delete tmutt_data;
    mutt_cur_hdr = $0;
    tmutt_mx = 0;
    while ( getline  > 0) {
      if ($0 == "" || (length($1) > 2 && substr($1, 1, 2) == "__")) {
        break;
      }
      if (mutt_drop[$1] == 1) { continue; }
      mutt_nm = $1;
      pos = index(mutt_nm, ".");
      if (pos > 0 && mutt_nm != "host.calls") {
        mutt_nm = substr(mutt_nm, 1, pos-1);
      }
      mutt_num = $2+0;
      if (!(mutt_nm in tmutt_list)) {
         tmutt_list[mutt_nm] = ++tmutt_mx;
         tmutt_lkup[tmutt_mx] = mutt_nm;
      }
      tmutt_i = tmutt_list[mutt_nm];
      tmutt_data[tmutt_i] += mutt_num;
    }
    for (im=1; im <= tmutt_mx; im++) {
      mutt_nm  = tmutt_lkup[im];
      mutt_num = tmutt_data[im];
      if (muttley_use_nm == "host.calls" || (muttley_use_nm != "" && mutt_nm == muttley_use_nm)) {
        if (!(mutt_nm in mutt_list)) {
           mutt_list[mutt_nm] = ++mutt_mx;
           mutt_lkup[mutt_mx] = mutt_nm;
           mutt_calls_prev[mutt_mx] = mutt_num;
           printf("added mutt_list[%d] = %s\n", mutt_mx, mutt_nm);
        }
        mutt_i = mutt_list[mutt_nm];
        dff = mutt_num - mutt_calls_prev[mutt_i];
        if (dff < 0) {
           #printf("%s: got neg diff= %s for mutt_nm= %s, file= %s, cur_dir= %s, timestamp= %s\n", script_nm, dff, mutt_nm, ARGV[ARGIND], cur_dir, muttley_dt[muttley_mx]) > "/dev/stderr";
           #exit 1;
           dff = 0;
        }
        mutt_calls[muttley_mx, mutt_i] = dff;
        mutt_calls_tot[mutt_i] += dff;
        mutt_calls_prev[mutt_i] = mutt_num;
      }

      if (!(mutt_nm in mutt_list2)) {
         mutt_list2[mutt_nm] = ++mutt_mx2;
         mutt_lkup2[mutt_mx2] = mutt_nm;
         mutt_calls_prev2[mutt_mx2] = mutt_num;
         if (mutt_nm == "host.calls") {
           mutt_host_calls_i = mutt_mx2;
         }
      }
      mutt_i = mutt_list2[mutt_nm];
      dff = mutt_num - mutt_calls_prev2[mutt_i];
      if (dff < 0) {
         #printf("%s: got neg diff= %s for mutt_nm= %s, file= %s, cur_dir= %s, timestamp= %s\n", script_nm, dff, mutt_nm, ARGV[ARGIND], cur_dir, muttley_dt[muttley_mx]) > "/dev/stderr";
         #exit 1;
         dff = 0;
      }
      mutt_calls2[muttley_mx, mutt_i] = dff;
      mutt_calls_tot2[mutt_i] += dff;
      mutt_calls_prev2[mutt_i] = mutt_num;
    }
    if ($0 == "" ) {
      next;
    }
    }
  }
  /^__uptime__/ {
    ts = $2 + 0;
    ts_skip = 0;
    if ((beg_ts > 0.0 && ts < beg_ts) || (end_ts > 0.0 && ts > end_ts)) {
      ts_skip = 1;
      while ( getline  > 0) {
        if ($0 == "" || substr($0, 1, 2) == "__") {
          break;
        }
      }
    }
    if (ts_skip == 0) {
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
  }
  /^__net_snmp_udp__/ {
    ts = $2 + 0;
    ts_skip = 0;
    if ((beg_ts > 0.0 && ts < beg_ts) || (end_ts > 0.0 && ts > end_ts)) {
      ts_skip = 1;
      while ( getline  > 0) {
        if ($0 == "" || substr($0, 1, 2) == "__") {
          break;
        }
      }
    }
    if (ts_skip == 0) {
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
  }

function add_cg_stat_data(cntr_i, v, area, subarea, cur_ts_idx,     ts_mx, prv, tv, cumu, tm_series, tm_series_mx)
{
  prv = area "_" subarea "_prev";
  cumu = area "_" subarea "_cumu";
  tm_series = area "_" subarea "_arr";
  tm_series_mx = area "_" subarea "_mx";
  tm_series_ts_idx = area "_" subarea "_arr_ts_idx";

  if (cg_stat_data[cntr_i,prv] == "") {
      cg_stat_data[cntr_i,prv] = v;
  }
  tv = v;
  if (v >= cg_stat_data[cntr_i,prv]) {
    tv = v - cg_stat_data[cntr_i,prv];
  }
  cg_stat_data[cntr_i,cumu] += tv;
  tm_cg_stat_data[cntr_i,cumu] += tv;
  cg_stat_data[cntr_i,prv] = v;
  ts_mx = ++tm_cg_stat_data[cntr_i,tm_series_mx];
  tm_cg_stat_data[cntr_i,tm_series, ts_mx] = tv;
  tm_cg_stat_data[cntr_i,tm_series_ts_idx, ts_mx] = cur_ts_idx;
}
  /__container_ids__ |__sys_container_ids__/ {
    cg_cntr_typ = -1;
    if ($1 == "__container_ids__") {
      ts = $3 + 0;
      cg_cntr_typ = cg_cntr_typ_srvc;
    }
    if ($1 == "__sys_container_ids__") {
      cg_cntr_typ = cg_cntr_typ_sys;
    }
    #printf("got cg_stat 0 %s, beg_ts= %.2f end_ts= %.2f ts-beg_ts= %.2f\n", $0, beg_ts, end_ts, ts - beg_ts);
    ts_skip = 0;
    if ((beg_ts > 0.0 && ts < beg_ts) || (end_ts > 0.0 && ts > end_ts)) {
      ts_skip = 1;
      while ( getline  > 0) {
        #end of __container_ids__ marked by blank line
        if ($0 == "") {
          break;
        }
      }
    }
    #printf("got cg_stat 1 %s ts_skip= %s\n", $0, ts_skip);
    if (ts_skip == 0) {
      if (cg_cntr_typ == cg_cntr_typ_srvc) {
        cg_stat_ts[++cg_stat_ts_mx] = ts;
      }
      #getline;
      while ( getline  > 0) {
        if ($0 == "") {
           next;
        }
        if ($1 == "__container_id__" || $1 == "__sys_container_id__") {
          cntr = $3;
          if (cg_cntr_typ == cg_cntr_typ_sys && cntr == "__none__") {
            # some system slice cgroups dont have a container... Im not sure how or why
            cntr = $3 " " $4;
          }
          #printf("got cg_stat cntr= %s\n", cntr);
          if (!(cntr in cg_stat_list)) {
            cg_stat_list[cntr] = ++cg_stat_mx;
            printf("added cg_stat_list[%s]= %d\n", cntr, cg_stat_mx);
            cg_stat_lkup[cg_stat_mx] = cntr;
            cg_stat_lkup[cg_stat_mx, "cntr_typ"] = cg_cntr_typ;
            if (cg_cntr_typ == cg_cntr_typ_sys) {
              cg_stat_lkup[cg_stat_mx, "cntr_typ_sys_cntr_id"] = $3;
              cg_stat_lkup[cg_stat_mx, "cntr_typ_sys_srvc"] = $4;
            }
            cg_stat_data[cg_stat_mx, "cumu"] = 0;
            cg_stat_data[cg_stat_mx, "cumu_sys"] = 0;
            cg_stat_data[cg_stat_mx, "cumu_usr"] = 0;
            cg_stat_data[cg_stat_mx, "cumu_sys_prev"] = -1;
            cg_stat_data[cg_stat_mx, "cumu_usr_prev"] = -1;
            cg_stat_data[cg_stat_mx, "occurs"] = 1;
            cg_stat_data[cg_stat_mx, "ts_cumu"] = 0;
            cg_stat_data[cg_stat_mx, "prev"] = -1;
            cg_stat_data[cg_stat_mx, "ts_prev"] = -1;
            cg_stat_data[cg_stat_mx, "thr_cumu"] = 0;
            cg_stat_data[cg_stat_mx, "thr_prev"] = -1;
            cg_stat_data[cg_stat_mx, "nr_per_cumu"] = 0;
            cg_stat_data[cg_stat_mx, "nr_per_prev"] = -1;
            cg_stat_data[cg_stat_mx, "nr_thr_cumu"] = 0;
            cg_stat_data[cg_stat_mx, "nr_thr_prev"] = -1;
          }
          cntr_i = cg_stat_list[cntr];
          continue;
        }
#__cpuacct.stat
#user 1976775
#system 576920
#__cpu.stat
#nr_periods 1191
#nr_throttled 117
#throttled_time 20591095843
        if ($1 == "__cpu.stat") {
          area = "cpu_stat";
          getline;
          if ($1 == "nr_periods") {
            subarea = $1;
            v = 1e-6 * $2;
            add_cg_stat_data(cntr_i, v, area, $1, cg_stat_ts_mx);
            if (cg_stat_data[cntr_i,"nr_per_prev"] == -1) {
              cg_stat_data[cntr_i,"nr_per_prev"] = v;
            }
            tv = v;
            if (v >= cg_stat_data[cntr_i,"nr_per_prev"]) {
              tv = v - cg_stat_data[cntr_i,"nr_per_prev"];
            }
            cg_stat_data[cntr_i,"nr_per_cumu"] += tv;
            cg_stat_data[cntr_i,"nr_per_prev"] = v;
            getline;
          }
          if ($1 == "nr_throttled") {
            v = 1e-6 * $2;
            add_cg_stat_data(cntr_i, v, area, $1, cg_stat_ts_mx);
            if (cg_stat_data[cntr_i,"nr_thr_prev"] == -1) {
              cg_stat_data[cntr_i,"nr_thr_prev"] = v;
            }
            cg_stat_data[cntr_i,"nr_thr_cumu"] += v - cg_stat_data[cntr_i,"nr_thr_prev"];
            cg_stat_data[cntr_i,"nr_thr_prev"] = v;
            getline;
          }
          if ($1 == "throttled_time") {
            v = 1e-9 * $2;
            add_cg_stat_data(cntr_i, v, area, $1, cg_stat_ts_mx);
            if (cg_stat_data[cntr_i,"thr_prev"] == -1) {
              cg_stat_data[cntr_i,"thr_prev"] = v;
            }
            cg_stat_data[cntr_i,"thr_cumu"] += v - cg_stat_data[cntr_i,"thr_prev"];
            cg_stat_data[cntr_i,"thr_prev"] = v;
          }
          continue;
        }
        if ($1 == "__cpuacct.stat") {
          area = "cpuacct_stat";
          getline;
          v = 0.01 * $2;
          add_cg_stat_data(cntr_i, v, area, $1, cg_stat_ts_mx);
          if (cg_stat_data[cntr_i,"cumu_usr_prev"] == -1) {
            cg_stat_data[cntr_i,"cumu_usr_prev"] = v;
          }
          tv = v;
          if (tv >= cg_stat_data[cntr_i,"cumu_usr_prev"]) {
            tv = v - cg_stat_data[cntr_i,"cumu_usr_prev"]
          }
          cg_stat_tot_tm_usr += tv;
          cg_stat_data[cntr_i,"cumu_usr"] += tv;
          cg_stat_data[cntr_i,"stat",stat_mx] = tv;
          cg_stat_data[cntr_i,"cumu_usr_prev"] = v;
          getline;
          v = 0.01 * $2;
          add_cg_stat_data(cntr_i, v, area, $1, cg_stat_ts_mx);
          if (cg_stat_data[cntr_i,"cumu_sys_prev"] == -1) {
            cg_stat_data[cntr_i,"cumu_sys_prev"] = v;
          }
          if (v < cg_stat_data[cntr_i,"cumu_sys_prev"]) {
            cg_stat_tot_tm_sys += v;
            cg_stat_data[cntr_i,"cumu_sys"] += v;
          } else {
            cg_stat_tot_tm_sys += v - cg_stat_data[cntr_i,"cumu_sys_prev"]
            cg_stat_data[cntr_i,"cumu_sys"] += v - cg_stat_data[cntr_i,"cumu_sys_prev"];
          }
          #cg_stat_data[cntr_i,"cumu_sys"] += v - cg_stat_data[cntr_i,"cumu_sys_prev"];
          #cg_stat_tot_tm_sys += v - cg_stat_data[cntr_i,"cumu_sys_prev"]
          cg_stat_data[cntr_i,"cumu_sys_prev"] = v;
          continue;
        }
        if ($1 == "__cpuacct.usage") {
          area = "cpuacct_usage";
          getline;
          v = 1e-9 * $1;
          add_cg_stat_data(cntr_i, v, area, "usage", cg_stat_ts_mx);
          if (cg_stat_data[cntr_i,"prev"] == -1) {
            cg_stat_data[cntr_i,"prev"] = v;
            cg_stat_data[cntr_i,"ts_prev"] = ts;
          }
          #cg_stat_data[cntr_i,"cumu"] += v - cg_stat_data[cntr_i,"prev"];
          #cg_stat_tot_tm += v - cg_stat_data[cntr_i,"prev"]
          if (v < cg_stat_data[cntr_i,"prev"]) {
            cg_stat_tot_tm += v;
            cg_stat_data[cntr_i,"cumu"] += v;
          } else {
            cg_stat_tot_tm += v - cg_stat_data[cntr_i,"prev"]
            cg_stat_data[cntr_i,"cumu"] += v - cg_stat_data[cntr_i,"prev"];
          }
          cg_stat_data[cntr_i,"ts_cumu"] += ts - cg_stat_data[cntr_i,"ts_prev"];
          cg_stat_data[cntr_i,"prev"] = v;
          cg_stat_data[cntr_i,"ts_prev"] = ts;
          continue;
        }
      }
    }
  }
#__uhostd_containers__ 1617299715 1617328515
  /^__uhostd_/ {
    ts = $2 + 0;
    ts_skip = 0;
    if ((beg_ts > 0.0 && ts < beg_ts) || (end_ts > 0.0 && ts > end_ts)) {
      ts_skip = 1;
      while ( getline  > 0) {
        if ($0 == "" || substr($0, 1, 2) == "__") {
          break;
        }
      }
    }
    if (ts_skip == 0) {
    getline;
    while ( getline  > 0) {
      if ($0 == "") {
         next;
      }
      hostd_bytes += length($0);
      nw = 0;
      if ($1 == "\"id\":") {
        nm2="";
        did_names = 0;
        gsub("\"", "", $2);
        gsub(",", "", $2);
        cntr = $2;
        is_infra = 0;
        added = 0;
        #printf("uhostd: got cntr id= %s, uhostd_cntr_list_mx= %d\n", cntr, uhostd_cntr_list_mx);
        if (!(cntr in uhostd_cntr_list)) {
          uhostd_cntr_list[cntr] = ++uhostd_cntr_list_mx;
          uhostd_cntr_lkup[uhostd_cntr_list_mx,"cntr"] = cntr;
          printf("uhostd: new_cntr[%d]= %s\n", uhostd_cntr_list_mx, cntr);
          nw = 1;
          added = 1;
        }
        cntr_i = uhostd_cntr_list[cntr];
      }
      if (did_names == 0 && $1 == "\"names\":") {
        did_names = 1;
        getline;
        gsub("\"", "", $1);
        gsub(",", "", $1);
        name = $1;
        if (substr(name, 1, 1) == "/") {
          name = substr(name, 2, length(name));
        }
        uhostd_cntr_lkup[cntr_i,"name"] = name;
      }
      if ($1 == "\"cgroup_parent\":" && index($2, "system.slice") > 0) {
        #"/system.slice/m3collector_default-compute.service"
        is_infra = 1;
        nm2 = substr($2, 16);
        #gsub(/.service\".*$/, "", nm2);
        gsub(/.service".*$/, "", nm2);
        uhostd_cntr_lkup[cntr_i,"nm2"] = nm2;
        uhostd_cntr_lkup[cntr_i,"is_infra"] = 1;
        if (added == 1) {
          printf("uhostd_cntr_lkup nm2= %s cntr_i= %d cntr= %s is_infra= %d\n", nm2, cntr_i, cntr, is_infra);
        }
      }
      if ($1 == "\"com.uber.supported_app_id\":" || $1 == "\"com.uber.service_name\":") {
        gsub("\"", "", $2);
        gsub(",", "", $2);
        nm   = $2;
        uhostd_cntr_lkup[cntr_i,"nm"] = nm;
        if (added == 1) {
          printf("uhostd_cntr_lkup nm= %s cntr_i= %d cntr= %s\n", nm, cntr_i, cntr);
        }
      }
      #"SVC_ID": "roadrunner-proxy",
      if ($1 == "\"SVC_ID\":") {
        gsub("\"", "", $2);
        gsub(",", "", $2);
        svc   = $2;
        uhostd_cntr_lkup[cntr_i,"svc"] = svc;
      }
    }
    }
  }
#__net_snmp_udp__ 1602432740 1602432780
#Tcp: RtoAlgorithm RtoMin RtoMax MaxConn ActiveOpens PassiveOpens AttemptFails EstabResets CurrEstab InSegs OutSegs RetransSegs InErrs OutRsts InCsumErrors
#Tcp: 1 200 120000 -1 521191991 454317201 51842064 362196675 22957 91893628805 206234253530 24434738 187 251797531 0
#Udp: InDatagrams NoPorts InErrors OutDatagrams RcvbufErrors SndbufErrors InCsumErrors IgnoredMulti
#Udp: 25821967258 6786602 322210586 26150968358 322210586 0 0 7287

#__systemd_cgtop__ 1617582237 1617596637

  /^__systemd_cgtop__ /{
    ts = $2 + 0;
    ts_skip = 0;
    if ((beg_ts > 0.0 && ts < beg_ts) || (end_ts > 0.0 && ts > end_ts)) {
      ts_skip = 1;
      while ( getline  > 0) {
        if ($0 == "" || substr($0, 1, 2) == "__") {
          break;
        }
      }
    }
    if (ts_skip == 0) {
    ++cg_mx;
    cg_dt[cg_mx] = $2;
    #getline;
    while ( getline  > 0) {
      if ($0 == "") {
         next;
      }
      cg_subgrp = "";
      cg = $1;
      if (cg == "/") {
        cg = "_all_";
        cg_subgrp = "/";
      } else {
        cg = substr(cg, 2, length(cg));
        cgl = length(cg);
        if (cgl > 8 && substr(cg, cgl-7, cgl) == ".service") {
          cg = substr(cg, 1, cgl-8);
          cgl = length(cg);
          cg_subgrp = "srvc";
        }
        if (cgl > 13 && substr(cg, 1, 13) == "system.slice/") {
          cg = substr(cg, 14, cgl);
          if (cg_subgrp == "") {
            cg_subgrp = "sys";
          } else {
            cg_subgrp = "sys." cg_subgrp;
          }

        }
      }
      cg_pids = $2;
      tm = 0;
      for (i=3; i <= (NF-3); i++) {
        v = $(i);
        vl = length(v);
        if (substr(v, vl, vl) == "y") {
          num = substr(v, 1, vl-1);
          v1 = num * 365 * 24 * 3600;
          tm += v1;
        } else if (vl > 5 && substr(v, vl-4, vl) == "month") {
          num = substr(v, 1, vl-5);
          # use avg number of days in month = 365.25/12 = 30.437
          # avg days/mon=	30.4375
	  # days	hours	minutes	secs
	  #  30 	10.5	30
          v1 = num * ((30 * 24 * 3600) + (10 * 3600) + (1800))
          tm += v1;
        } else if (vl > 1 && substr(v, vl, vl) == "w") {
          num = substr(v, 1, vl-1);
          v1 = num * 7 * 24 * 3600;
          tm += v1;
        } else if (vl > 1 && substr(v, vl, vl) == "d") {
          num = substr(v, 1, vl-1);
          v1 = num * 24 * 3600;
          tm += v1;
        } else if (vl > 1 && substr(v, vl, vl) == "h") {
          num = substr(v, 1, vl-1);
          v1 = num * 3600;
          tm += v1;
        } else if (vl > 1 && substr(v, vl-2, vl) == "min") {
          num = substr(v, 1, vl-3);
          v1 = num * 60;
          tm += v1;
        } else if (vl > 2 && substr(v, vl-1, vl) == "ms") {
          num = substr(v, 1, vl-2);
          v1 = num * 0.001;
          tm += v1;
        } else if (vl > 2 && substr(v, vl, vl) == "s") {
          num = substr(v, 1, vl-1);
          v1 = num;
          tm += v1;
        } else {
          printf("unhandled time field %s in line %s\n", v, $0);
        }
      }
      if (!(cg in cg_list)) {
        if (cg == "/") {
          printf("added cg %s\n", cg);
        }
        cg_list[cg] = ++cg_list_mx;
        cg_infra = 0;
        if (index($1, "system.slice") > 0) { cg_infra = 1; }
        printf("added cg[%d] %s, cg_infra= %d $1= %s\n", cg_list_mx, cg, cg_infra, $1);
        cg_lkup[cg_list_mx] = cg;
        cg_lkup[cg_list_mx,"orig"] = $1;
        cg_lkup[cg_list_mx,"subgrp"] = cg_subgrp;
        cg_lkup[cg_list_mx,"tm_tot"] = 0;
        cg_lkup[cg_list_mx,"is_infra"] = cg_infra;
        qklk = "";
        if (substr(cg, 1, 7) == "docker/") {
          # for this to work the uhostd_cntr_lkup has to have already been filled in. may not have been done yet
          #cntr = substr(cg, 8, length(cg));
          cntr = substr(cg, 8);
          if (cntr in uhostd_cntr_list) {
          c_i = uhostd_cntr_list[cntr];
          } else {
          c_i = "";
          }
          if (c_i != "") {
            qklk = uhostd_cntr_lkup[c_i,"nm"];
            cg_lkup[cg_list_mx,"qklk"] = qklk;
          }
          printf("got docker = %s, c_i= %s, qklk= %s, cntr= %s\n", cg, c_i, qklk, cntr);
        }
      }
      cg_i = cg_list[cg];
      cg_data[cg_mx,cg_i,"tm"] = tm;
      if (cg_mx > 1 && tm > cg_data[cg_mx-1,cg_i,"tm"]) {
        cg_lkup[cg_i,"tm_tot"] += tm - cg_data[cg_mx-1,cg_i,"tm"];
      }
      qklk = cg_lkup[cg_i,"qklk"];
      if (qklk == nm_lkfor) {
        v = 0;
        dint = 1.0;
        v1 = cg_data[cg_mx,cg_i,"tm"] - cg_data[1,cg_i,"tm"];
        if (cg_mx > 1) { v = tm - cg_data[cg_mx-1,cg_i,"tm"]; dint = cg_dt[cg_mx]-cg_dt[cg_mx-1];}
        printf("cg_data[%d, %s, tm]= %.3f, dtm= %.3f, dtm/intrvl= %.3f tot_diff= %.3f, tm_tot= %.3f\n", cg_mx, qklk, tm, v, v/dint, v1, cg_lkup[cg_i,"tm_tot"] );
      }
      cg_data[cg_mx,cg_i,"mem"] = $(NF-2);
      #printf("tm= %10.3f ln= %s\n", tm, cg);
    }
    }
  }

  /^__date__/ {
    ts = $2 + 0;
    ts_skip = 0;
    if ((beg_ts > 0.0 && ts < beg_ts) || (end_ts > 0.0 && ts > end_ts)) {
      ts_skip = 1;
      while ( getline  > 0) {
        if ($0 == "" || substr($0, 1, 2) == "__") {
          break;
        }
      }
    }
    if (ts_skip == 0) {
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
      got_kw = -1;
      for (i=1; i <= plst_mx; i++) {
        if (index(proc, plst[i]) == 1) {
         if (!(plst[i] in proc_list)) {
           proc_list[plst[i]] = ++proc_mx;
           proc_lkup[proc_mx] = plst[i];
           proc_kw = proc_mx;
         }
         got_kw = proc_kw;
         proc_i = proc_kw;
         break;
        }
      }
      if (got_kw == -1) {
        if (!(proc in proc_list)) {
           proc_list[proc] = ++proc_mx;
           proc_lkup[proc_mx] = proc;
        }
        proc_i = proc_list[proc];
      }
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
        v = (secs - secs_prev)/dt_diff;
        if (v < 0.0) { v = 0.0; }
        use_proc_i = proc_i;
        if (got_kw != -1) {
          use_proc_i = proc_kw;
        }
        sv[mx, use_proc_i] += v;
        if (col_rss != -1) {
          sv_rss[mx, use_proc_i] += rss;
        }
        if (col_vsz != -1) {
          sv_vsz[mx, use_proc_i] += vsz;
        }
        tot[use_proc_i] += (secs - secs_prev);
        tot_n[use_proc_i]++;
      }
      pid_prev[pid_i,"secs"] = secs
      pid_prev[pid_i,"proc"] = proc;
    }
    }
    }
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
function pse_tot_compare(i1, v1, i2, v2,    l, r)
{
    m1 = pse_tot[i1];
    m2 = pse_tot[i2];
    if (m2 < m1)
        return -1
    else if (m1 == m2)
        return 0
    else
        return 1
}
function mutt_tot_compare(i1, v1, i2, v2,    l, r)
{
    m1 = mutt_calls_tot[i1];
    m2 = mutt_calls_tot[i2];
    if (m2 < m1)
        return -1
    else if (m1 == m2)
        return 0
    else
        return 1
}
function compare_ncg(i1, v1, i2, v2,    m1, m2)
{
    m1 = ncg_lkup[i1,"tm"];
    m2 = ncg_lkup[i2,"tm"];
    if (m2 < m1)
        return -1
    else if (m1 == m2)
        return 0
    else
        return 1
}

function mutt_tot2_compare(i1, v1, i2, v2,    l, r)
{
    m1 = mutt_calls_tot2[i1];
    m2 = mutt_calls_tot2[i2];
    if (m2 < m1)
        return -1
    else if (m1 == m2)
        return 0
    else
        return 1
}

function do_cgrps_val_arr(cg,      ii, nm, my_n, str, nstr, j, kk, strp) {
    for (ii=1; ii <= cgrps_val_arr["cat_mx"]; ii++) {
        nm   = cgrps_val_arr["cat_nm",ii];
        my_n = cgrps_val_arr["vals_mx",ii,nm];
        #printf("got cgrps_val_arr[%d] nm= %s my_n= %s\n", ii, nm, my_n) >> "tmp.jnk";

        if (do_this_one_time == "") {
          do_this_one_time = 1;
          for (k=1; k <= 2; k++) {
               if (k == 1) { styp = 1; snm = "tot_docker_services";}
               if (k == 2) { styp = 2; snm = "tot_infra_agent"; }
        delete arr_in;
        delete res_i;
        delete idx;
        calls = 0;
        new_n = 0;
        nnstr = "";
               #cgrps_val_tarr["cat_mx"] = styp;
               snm = cgrps_val_tarr["cat_nm",styp];
               #cgrps_val_tarr["str",styp] = "%cpu";
               my_vals_mx = cgrps_val_tarr["vals_mx",styp,snm];
               for (kk=2; kk <= my_vals_mx; kk++) {
                 v = cgrps_val_tarr["val",styp,kk,1];
                 #cgrps_val_tarr["val",styp,kk,2] += sum;
                 #cgrps_val_tarr["val",styp,kk,3] += calls;
                 #cgrps_val_tarr["val",styp,kk,4] += tdff;
                 #cgrps_val_tarr["val",styp,kk,5] = vld;
                 if (v == "") { continue; }
                 new_n++;
                 nnstr = nnstr "" sprintf("\t%f", v);
                 idx[new_n] = new_n;
                 arr_in[new_n] = v;
                 #printf("tot_cgrp %s kk= %d v= %f\n", snm, kk, v);
              }
        asorti(idx, res_i, "arr_in_compare");
        nstr = sprintf("%s\t%s\t%f\t%s val_arr", "cgrp_val_arr", "cgrps_val_arr", new_n, "tot_%cpu "snm);
        printf("%s%s\n", nstr, nnstr) > sum_file;
        for (kk=1; kk <= px_mx; kk++) {
          uval = compute_pxx(kk, new_n, res_i, arr_in);
          strp = "tot_%cpu " snm " p" px[kk];
          printf("%s\t%s\t%f\t%s\n", "cgrp_per_hst", "cgrp_per_hst", uval, strp) > sum_file;
        }
          }
        }
        if (my_n == 0) {
          continue;
        }
        str  = cgrps_val_arr["str",ii];
        #printf("at104 cg= %d ii= %d nm= %s\n", cg, ii, nm);
        #fflush();
        delete arr_in;
        delete res_i;
        delete idx;
        calls = 0;
        new_n = 0;
        nnstr = "";
        for(j=1; j <= my_n; j++) {
           v = cgrps_val_arr["val",ii,j,1];
           if (v == "") { continue; }
           new_n++;
           calls += cgrps_val_arr["val",ii,j,3];
           nnstr = nnstr "" sprintf("\t%f", v);
           idx[new_n] = new_n;
           arr_in[new_n] = v;
        }
        nstr = sprintf("%s\t%s\t%f\t%s val_arr", "cgrp_val_arr", "cgrps_val_arr", new_n, str " " nm);
        if (index(str, "ms_per_call") == 0 || calls > 0) {
          printf("%s%s\n", nstr, nnstr) > sum_file;
        }
        #fflush();
        if (calls > 0) {
        asorti(idx, res_i, "arr_in_compare");
        for (kk=1; kk <= px_mx; kk++) {
          uval = compute_pxx(kk, my_n, res_i, arr_in);
          strp = "ms_per_call " nm " p" px[kk];
          printf("%s\t%s\t%f\t%s\n", "cgrp_per_hst", "cgrp_per_hst", uval, strp) > sum_file;
        }
        }

        delete arr_in;
        delete res_i;
        delete idx;
        new_n = 0;
        nnstr = "";
        for(j=1; j <= my_n; j++) {
           v1 = cgrps_val_arr["val",ii,j,2];
           if (v1 == "") { continue; }
           new_n++;
           tdff = cgrps_val_arr["val",ii,j,4];
           v2 = top_fctr * v1/tdff;
           if (nm == nm_lkfor) { printf("val_arr[%d]= \"%s\" nm= %s\n", j, v2, nm); }
           #nnstr = nnstr ""  sprintf("\t%f", v2);
           nnarr[new_n] = v2;
           nnstr = nnstr ""  sprintf("%f\t", v2);
           idx[new_n] = new_n;
           arr_in[new_n] = v2;
        }
        nstr = sprintf("%s\t%s\t%f\t%s val_arr", "cgrp_val_arr", "cgrps_val_arr", new_n, "%cpu " nm);
        #gsub(/ /, "\t", nnstr);
        #nnstr = gensub(/ /, "\t", "g", nnstr);
        printf("%s", nstr) > sum_file;
        #mstr = join(nnarr, 1, new_n, "\t");
        mstr = "";
        for (j=1; j <= new_n; j++) {
           mstr = mstr "\t" sprintf("%f", nnarr[j]);
        }
        #gsub(/\t/, ";", mstr);
        #gsub(/;/, "\t", mstr);
        printf("%s\n", mstr) > sum_file;
        #printf("%s", nstr) > "tmp.jnk";
        #printf("%s\n", mstr) > "tmp.jnk";

        #printf("%s\t%s\n", nstr, nnstr) > sum_file;
        #if (nm == nm_lkfor) { printf("__aabb val_arr= %s%s\n", nstr, nnstr);}
        #printf("%s\n", nstr);
        asorti(idx, res_i, "arr_in_compare");
        for (kk=1; kk <= px_mx; kk++) {
          uval = compute_pxx(kk, my_n, res_i, arr_in);
          strp = "%cpu " nm " p" px[kk];
          printf("%s\t%s\t%f\t%s\n", "cgrp_per_hst", "cgrp_per_hst", uval, strp) > sum_file;
        }

        if (calls > 0) {
        delete arr_in;
        delete res_i;
        delete idx;
        new_n = 0;
        nnstr = 0;
        for(j=1; j <= my_n; j++) {
           vld = cgrps_val_arr["val",ii,j,5];
           v1 = cgrps_val_arr["val",ii,j,3];
           if (v1 == "" || vld == 0) { continue; }
           new_n++;
           tdff = cgrps_val_arr["val",ii,j,4];
           v2 = v1/tdff;
           nnstr = nnstr "" sprintf("\t%f", v2);
           idx[new_n] = new_n
           arr_in[new_n] = v2;
        }
        nstr = sprintf("%s\t%s\t%f\t%s val_arr", "cgrp_val_arr", "cgrps_val_arr", new_n, "RPS " nm);
        printf("%s%s\n", nstr, nnstr) > sum_file;
        #fflush();
        asorti(idx, res_i, "arr_in_compare");
        for (kk=1; kk <= px_mx; kk++) {
          #uval = compute_pxx(kk, my_n, res_i, arr_in);
          uval = compute_pxx(kk, ju, res_i, arr_in);
          strp = "RPS " nm " p" px[kk];
          printf("%s\t%s\t%f\t%s\n", "RPS_per_hst", "RPS_per_hst", uval, strp) > sum_file;
        }
        }
    }
}

  END {
    #ofile="tmp.tsv";
    if (rc != 0) {
      printf("got rc= %s for script_nm= %s. bye\n", rc, script_nm) > "/dev/stderr";
      exit(rc);
    }
    if (idle_mx > 0) {
      elap_tm = sv_uptm[idle_mx]-sv_uptm[1];
      sum = 0.0;
      if (elap_tm == 0.0) {
         printf("skipping infra_file do to idle_mx= %s, arg[1]= %s, cur_dir= %s\n", idle_mx, ARGV[1], cur_dir);
         exit 3;
      }
      for (i=1; i <= proc_mx; i++) {
         if (elap_tm > 0.0) {
         tot[i] /= elap_tm;
         sum += tot[i];
         }
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
        if (busy < 0.0) { busy = 0.0; }
        proc = "__other_busy__";
        printf("%s cpus= %s\n", proc, busy);
        proc_list[proc] = ++proc_mx;
        proc_lkup[proc_mx] = proc;
        tot[proc_mx] = busy;
        tot_n[proc_mx] = idle_mx;
        busy_idx = proc_mx;
      }
    }
    trow = -1;
    if (muttley_mx > 2) {
      for(i=1; i <= mutt_mx; i++) {
        mutt_idx[i] = i;
      }
      asorti(mutt_idx, mutt_res_i, "mutt_tot_compare")
      mutt_other = 100; # combine everything after N columns
      mutt_floor = 1.0; # combine everthing with less than X RPS
      # find which is smaller
      tm_diff = muttley_dt[muttley_mx]-muttley_dt[1];
      k = -1;
      for(j=1; j <= mutt_mx; j++) {
         i = mutt_res_i[j];
         v = mutt_calls_tot[i]/tm_diff;
         if (v < mutt_floor) {
            k = i;
            break;
         }
      }
      printf("mutt_mx= %d, mutt_other= %d, cols w rps > %.3f = %d\n", mutt_mx, mutt_other, mutt_floor, k);
      use_mutt_mx = mutt_mx;
      if (use_mutt_mx > mutt_other) {
          use_mutt_mx = mutt_other;
      }
      if (k != -1 && use_mutt_mx > k) {
         use_mutt_mx = k;
      }
      mutt_other_str = "__muttley_other__";
      use_mutt_mx = mutt_mx; # cant do the mutt_other stuff here or we wont be able to do the pXX (p99 etc) stuff when we combine hosts
      trow++;
      hstr = sprintf("epoch\tts");
      for(j=1; j <= mutt_mx; j++) {
          i = mutt_res_i[j];
          if (j == use_mutt_mx && mutt_mx > use_mutt_mx) {
             hstr = hstr sprintf("\t%s", mutt_other_str);
             break;
          }
        hstr = hstr sprintf("\t%s", mutt_lkup[i]);
      }
      hstr = hstr sprintf("\n");
      n_hstr = split(hstr, harr, "\t");
      printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "muttley calls RPS", "infra procs") > ofile;
      trow++;
      drop_host_calls_nm = "host.calls";
      printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, n_hstr-1, 1) > ofile;
      #printf("net_mx= %d\n", net_mx);
      cols = 3

      printf("%s", hstr) > ofile
      trow++;
      for(k=2; k <= muttley_mx; k++) {
        printf("%s\t%d", muttley_dt[k], muttley_dt[k]-muttley_dt[1]) > ofile;
        tm_diff = muttley_dt[k]-muttley_dt[k-1];
        for(j=1; j <= mutt_mx; j++) {
          i = mutt_res_i[j];
          if (j == use_mutt_mx && mutt_mx > use_mutt_mx) {
             v = mutt_calls[k,i];
             for(jj=j+1; jj <= mutt_mx; jj++) {
                ii = mutt_res_i[jj];
                v += mutt_calls[k,ii];
             }
             if (tm_diff > 0.0) {
               v /= tm_diff;
             } else {
               v = 0.0;
             }
             if (mutt_host_calls_max < v) {
                 mutt_host_calls_max = v;
             }
             printf("\t%f", v) > ofile;
             break;
          }
          if (tm_diff > 0.0) {
            v = mutt_calls[k,i] / tm_diff;
            #v = mutt_calls[k,i];
          } else {
            v = 0.0;
          }
          if (i == mutt_host_calls_i) {
             if (mutt_host_calls_n++ == 0) {
               mutt_host_calls_str = v;
             } else {
               mutt_host_calls_str = mutt_host_calls_str "\t" v;
             }
             mutt_host_calls_arr[k] = v;
          }
          if (mutt_host_calls_max < v) {
              mutt_host_calls_max = v;
          }
          printf("\t%f", v) > ofile;
        }
        printf("\n") > ofile;
        trow++;
      }
      trow++;
      printf("\n") > ofile;
      if (sum_file != "") {
         tm_diff = muttley_dt[muttley_mx]-muttley_dt[1];
         if (1 == 1) {
         for(j=1; j <= mutt_mx; j++) {
           i = mutt_res_i[j];
           if (j == use_mutt_mx && mutt_mx > use_mutt_mx) {
             v = mutt_calls_tot[i]/tm_diff;
             for(jj=j+1; jj <= mutt_mx; jj++) {
                ii = mutt_res_i[jj];
                v += mutt_calls_tot[ii]/tm_diff;
             }
             if (tm_diff > 0.0) {
               v /= tm_diff;
             } else {
               v = 0.0;
             }
             printf("infra_procs\tmuttley calls avg\t%f\t%s\n", v, "RPS " mutt_other_str) > sum_file;
             break;
          }
           avg = mutt_calls_tot[i]/tm_diff;
           printf("infra_procs\tmuttley calls avg\t%f\t%s\n", avg, "RPS " mutt_lkup[i]) > sum_file;
           printf("infra_procs\tmuttley calls avg\t%f\t%s\ttotal\t%.0f\ttm\t%f\n", avg, "RPS " mutt_lkup[i], mutt_calls_tot[i], tm_diff);
         }
         }
         printf("infra_procs\tmuttley host.calls max\t%f\t%s\n", mutt_host_calls_max, "RPS host.calls max") > sum_file;
      }
      if (sum_file != "" && mutt_host_calls_n > 0) {
        printf("mutt_RPS_host_calls_val_arr\tmutt_RPS_host_calls_val_arr\t%f\t%s\t%s\n", mutt_host_calls_n, "RPS host.calls val_arr", mutt_host_calls_str) > sum_file;
        delete arr_in;
        delete res_i;
        delete idx;
        my_n = 0;
        for(k=2; k <= muttley_mx; k++) {
           idx[++my_n] = k;
           arr_in[my_n] = mutt_host_calls_arr[k];
        }
        asorti(idx, res_i, "arr_in_compare");
        for (kk=1; kk <= px_mx; kk++) {
          uval = compute_pxx(kk, my_n, res_i, arr_in);
          strp = "mutt_RPS_host_calls_per_hst p" px[kk];
          printf("%s\t%s\t%f\t%s\n", "cpu_util_per_hst", "mutt_RPS_host_calls_per_hst", uval, strp) > sum_file;
        }
      }
#abc  write complete list to mutt_ofile
      for(i=1; i <= mutt_mx2; i++) {
        mutt_idx[i] = i;
      }
      tm_diff = muttley_dt[muttley_mx]-muttley_dt[1];
      asorti(mutt_idx, mutt_res_i, "mutt_tot2_compare")
      for(k=2; k <= muttley_mx; k++) {
        tm_diff = muttley_dt[k]-muttley_dt[k-1];
        if (tm_diff > 0.0) {
          for(j=1; j <= mutt_mx2; j++) {
            if (mutt_ok[j] == 1) {continue;}
            if (mutt_calls2[k,j] >= tm_diff) { mutt_ok[j] = 1; }
          }
        }
      }
      str = sprintf("epoch\tts");
      for(j=1; j <= mutt_mx2; j++) {
         i = mutt_res_i[j];
         if (mutt_ok[i] != 1) {continue;}
         str = str "" sprintf("\t%s", mutt_lkup2[i]);
      }
      nmutt_n = 0;
      nmutt_ln[++nmutt_n] = str;
      printf("%s\n", str) > mutt_ofile;
      mutt_host_calls_max = -1
      for(k=2; k <= muttley_mx; k++) {
        str = sprintf("%s\t%d", muttley_dt[k], muttley_dt[k]-muttley_dt[1]);
        tm_diff = muttley_dt[k]-muttley_dt[k-1];
        for(j=1; j <= mutt_mx2; j++) {
          i = mutt_res_i[j];
          if (mutt_ok[i] != 1) {continue;}
          if (tm_diff > 0.0) {
            v = mutt_calls2[k,i] / tm_diff;
          } else {
            v = 0.0;
          }
          str = str "" sprintf("\t%f", v);
        }
        nmutt_ln[++nmutt_n] = str;
        printf("%s\n", str) > mutt_ofile;
      }
      printf("\n") > mutt_ofile;
      close(mutt_ofile);

      nn = split(nmutt_ln[1], mutt_arr, "\t");
      for (i=1; i <= nn; i++) {
        v = mutt_arr[i];
        gsub(".calls$", "", v);
        v = tolower(v);
        # assume muttley name is like a.b where a is uservice_which_is_sending and b is uservice_to_send_to
        #per = index(v1, ".");
        #if (per > 0 && v1 != "host.calls") {
        #  v = substr(v1, 1, per-1);
        #} else {
        #  v = v1;
        #}
        if (!(v in nmutt_list)) {
          nmutt_list[v] = ++nmutt_mx;
          nmutt_col_2_i[i] = nmutt_mx;
          nmutt_i_2_col[nmutt_mx] = i;
          nmutt_lkup[nmutt_mx,"nm"] = v;
          nmutt_lkup[nmutt_mx,"col"] = i;
          nmutt_lkup[nmutt_mx,"tot"] = 0;
          printf("added nmuttley nm[%d]= %s\n", nmutt_mx, v);
        }
      }
      nmutt_rws = 0;
      nmutt_elap_prev = 0;
      nmutt_calls_tot = 0;
      for (k=2; k <= nmutt_n; k++) {
        ++nmutt_rws;
        nn = split(nmutt_ln[k], mutt_arr, "\t");
        tdff = mutt_arr[2] - nmutt_elap_prev;
        nmutt_elap_prev = mutt_arr[2];
        for (i=1; i <= nn; i++) {
          nmutt_data[nmutt_rws,i] = mutt_arr[i];
          j = nmutt_col_2_i[i];
          if (j >= 3) {
            v = mutt_arr[j]*tdff;
            #printf("ck_nmutt_lkup_tot: v= %d, mutt_arr[%d]= %d, tdff= %d\n", v, j, mutt_arr[j], tdff);
            nmutt_lkup[j,"tot"] += v;
            if (j > 3) { # skip host.calls
            nmutt_calls_tot += v;
            }
          }
        }
      }
    }
    printf("cntr_mx = %d, nmutt_calls_tot= %d\n", cntr_mx, nmutt_calls_tot);
    sum = 0.0;
    other_tm_mx = 0;
    got_tm = 0.0;
    if (cntr_mx > 0) {
      for (j=1; j <= ps_tree_mx; j++) {
        got_it = 0;
        pid2 = ps_tree_lkup[j,"pid"] + 0;
        pid2_beg= pid2;
        while(pid2 != "" && pid2 > 2) {
          kk++;
          pid3 = ps_tree2[pid2];
          cntr_i = ps_cntr2[pid3];
          if (cntr_i != "") {
            got_it = 1;
            v = ps_tree_tm[pid2_beg];
            cntr_tm[cntr_i] += v;
            got_tm += v;
            break;
          }
          if (pid3 == "" || pid3 < 3) {break;}
          pid2 = pid3;
        }
        if (got_it == 0) {
          v = ps_tree_tm[pid2_beg];
          if (v > 0) {
            pp = ps_proc2[pid2_beg];
            ln = ps_line2[pid2_beg];
            n = split(ln, arr, " ");
            usr = arr[1];
            if (index(pp, "kworker") > 0) {
              nm = "kworker";
            } else if (usr != "root" && usr != "nobody" && usr != "uber" && usr != "www-data") {
              nm = usr;
            } else if (index(pp, "[") == 0) {
              n = split(pp, arr, "/");
              nm = arr[n];
            }
            if (!(nm in other_tm_list)) {
              other_tm_list[nm] = ++other_tm_mx;
              other_tm_lkup[other_tm_mx,"nm"] = nm;
              other_tm_lkup[other_tm_mx,"tm"] = 0;
            }
            o_i = other_tm_list[nm];
            other_tm_lkup[o_i,"tm"] += v;
            printf("missd %5d tm= %5d nm= %16s cmd= %s line= %s\n", pid2_beg, v, nm, ps_proc2[pid2_beg], ps_line2[pid2_beg]);
            other_tm += v;
          }
        }
      }
    }
    for (i=1; i <= cntr_mx; i++) {
      cntr =  cntr_lkup[i,"cntr"];
      if (cntr in uhostd_cntr_list) {
        cntr_i = uhostd_cntr_list[cntr];
      } else {
        cntr_i = "";
      }
      #cntr_i = uhostd_cntr_list[cntr];
      svc = uhostd_cntr_lkup[cntr_i,"svc"];
      nm  = uhostd_cntr_lkup[cntr_i,"nm"];
      nm2 = uhostd_cntr_lkup[cntr_i,"nm2"];
      is_infra = uhostd_cntr_lkup[cntr_i,"is_infra"];
      sum += cntr_tm[i];
      printf("cntr_tm[%d]= %6d  svc= %s, nm= %s, cntr_i= %d cntr= %s nm2= %s, is_infra= %d,\n", i, cntr_tm[i], svc, nm, cntr_i, cntr, nm2, is_infra);
    }
    for (i=1; i <= other_tm_mx; i++) {
      printf("nm= %16s tm= %5d\n", other_tm_lkup[i,"nm"], other_tm_lkup[i,"tm"]);
    }
    printf("\n");
    printf("container tot tm= %d secs\n", sum);
    printf("        got   tm= %d secs\n", got_tm);
    printf("      other   tm= %d secs\n", other_tm);
    sum = tot_tm - sum;
    printf("          tot tm= %d secs\n", tot_tm);
    printf("tot_elap-tot_idl= %d secs\n", num_cpus * (sv_uptm[idle_mx]-sv_uptm[1]) - (sv_idle[idle_mx]-sv_idle[1]));
    printf("      elapsed tm= %d secs\n", sv_uptm[idle_mx]-sv_uptm[1]);
    tot_cpu_secs = num_cpus * (sv_uptm[idle_mx]-sv_uptm[1]);
    printf("  tot cpu secs  = %d secs\n", tot_cpu_secs);
    printf("         idle tm= %d secs\n", sv_idle[idle_mx]-sv_idle[1]);
    printf("++++++++++pse_proc_mx= %d\n", pse_proc_mx);
    printf("    elap_tm  %.2f secs\n", elap_tm);
    printf(" sv_uptm dff %.2f secs\n", (sv_uptm[idle_mx]-sv_uptm[1]));

    printf("cg_stat_max= %d\n", cg_stat_mx);
    cg_stat_elap_tm = cg_stat_ts[cg_stat_ts_mx]-cg_stat_ts[2]; # start from 2 since the 1st interval is used as prev
    if ( cg_stat_elap_tm > 0) {
      printf("cg_stat_tot_tm= %f elap_tm= %f %%cpu_busyTL= %f\n", cg_stat_tot_tm, cg_stat_elap_tm, 100*cg_stat_tot_tm/cg_stat_elap_tm);
      printf("cg_stat_tot_tm= %f elap_tm= %f %%cpu_busyTL= %f %%cpu_usrTL= %f %%cpu_sysTL= %f\n",
        cg_stat_tot_tm, cg_stat_elap_tm,
        100*cg_stat_tot_tm/cg_stat_elap_tm,
        100*cg_stat_tot_tm_usr/cg_stat_elap_tm,
        100*cg_stat_tot_tm_sys/cg_stat_elap_tm);
    } else {
     printf("problem: cg_stat_elap_tm= %s cg_stat_ts[%s]= %s cg_stat_ts[2]= %s, elap_tmc= %s\n",
       cg_stat_elap_tm, cg_stat_ts_mx, cg_stat_ts[cg_stat_ts_mx], cg_stat_ts[2], elap_tm);
     #cg_stat_elap_tm = elap_tm;
    }
    v_tot = 0;
    v_tot1 = 0;
    v_tot2 = 0;
    v_tot3 = 0;
    v_tot_thr = 0;
    for (i=1; i <= cg_stat_mx; i++) {
      v = cg_stat_lkup[i];
      nm = "";
      if (v in uhostd_cntr_list) {
        v_i = uhostd_cntr_list[v];
        nm = uhostd_cntr_lkup[v_i, "nm"];
      }
      cg_cntr_typ = cg_stat_lkup[i, "cntr_typ"];
      if (nm  == "" && cg_cntr_typ == cg_cntr_typ_sys) {
        nm = cg_stat_lkup[i, "cntr_typ_sys_srvc"];
      }
      if (!(nm in cg_stat_nm_list)) {
        cg_stat_nm_list[nm] = ++cg_stat_nm_list_mx;
        cg_stat_nm_lkup[cg_stat_nm_list_mx] = nm;
      }
      v  = cg_stat_data[i, "cumu"];
      #v1 = cg_stat_data[i, "ts_cumu"];
      v1 = cg_stat_elap_tm;
      v_thr = cg_stat_data[i, "thr_cumu"];
      v2 = 0.0;
      if (v1 > 0) {
        v2 = v / v1;
      }
      v3     = 0;
      v3_usr = 0;
      v3_sys = 0;
      if (v1 > 0) {
      v3     = 100.0* v / v1
      v3_usr = 100.0* cg_stat_data[i, "cumu_usr"] / v1;
      v3_sys = 100.0* cg_stat_data[i, "cumu_sys"] / v1;
      }
      v_tot += v;
      v_tot1 += v1;
      v_tot2 += v2;
      v_tot3 += v3;
      cntr_typ_cumu[cg_cntr_typ] += v3;
      if (v3 > 0) {
        cntr_typ_gt0[cg_cntr_typ]++;
      }
      cntr_typ_got[cg_cntr_typ]++;
      v_tot3_usr += v3_usr;
      v_tot3_sys += v3_sys;
      v_tot3_bsy += v3_sys + v3_usr;
      v_tot_thr += v_thr;
      cg_stat_i = cg_stat_nm_list[nm];
      #printf("cg_stat[%d] tot_cpu_secs= %10.2f thr_secs= %10.4f nm= %s tm= %3.f, %%busy= %.3f\n", i,  v, v_thr, nm, v1, v2, v3);
      printf("cg_stat[%d] tot_cpu_secs= %10.2f thr_secs= %10.4f %%busy= %7.2f %%usr= %7.2f %%sys= %7.2f srvc1_sys2= %d nm= %s tm= %3.f\n",
         i,  v, v_thr, v3, v3_usr, v3_sys, cg_cntr_typ, nm, v1, v2);
      cg_stat_nm_data[cg_stat_i, "occurs"] += cg_stat_data[i, "occurs"];
      cg_stat_nm_data[cg_stat_i, "cumu"] += v;
      cg_stat_nm_data[cg_stat_i, "ts_cumu"] += v1;
      cg_stat_nm_data[cg_stat_i, "thr_cumu"] += v_thr;
    }
    if (cg_stat_elap_tm > 0) {
      printf("cg_stat v_tot= %.3f v_tot1= %.3f v_tot2= %.3f v_throttle_secs= %.6f\n", v_tot, v_tot1, v_tot2, v_tot_thr);
      cg_stat_elap_tm = cg_stat_ts[cg_stat_ts_mx]-cg_stat_ts[2];
      printf("cg_stat %busy= %.3f%%\n", 100.0 * v_tot/(num_cpus * cg_stat_elap_tm));
      printf("cg_stat elap_tm= %.3f\n", cg_stat_ts[cg_stat_ts_mx]-cg_stat_ts[1]);

      printf("cg_stat v_tot= %.3f v_tot1= %.3f v_tot2= %.3f v_throttle_secs= %.6f v3_%%cpu= %.3f v_tot3_bsy= %.3f\n", v_tot, v_tot1, v_tot2, v_tot_thr, v_tot3, v_tot3_bsy);
      #cg_stat_elap_tm = cg_stat_ts[cg_stat_ts_mx]-cg_stat_ts[1];
      for (i=1; i <= 2; i++) {
        printf("cntr_typ: srvc1_sys2= %d tot_%%busyTL= %8.2f non_zero_cntrs= %d, tot_cpu_cntrs= %d\n", i, cntr_typ_cumu[i], cntr_typ_gt0[i], cntr_typ_got[i]);
      }
    }
  area = "cpu_stat";
  subarea = "throttled_time";
  cumu = area "_" subarea "_cumu";
  tm_series = area "_" subarea "_arr";
  tm_series_mx = area "_" subarea "_mx";
  tm_series_ts_idx = area "_" subarea "_arr_ts_idx";
  area2 = "cpuacct_usage";
  subarea2 = "usage"
  cumu2 = area2 "_" subarea2 "_cumu";
  tm_series2 = area2 "_" subarea2 "_arr";
  tm_series_mx2 = area2 "_" subarea2 "_mx";
  tm_series_ts_idx2 = area2 "_" subarea2 "_arr_ts_idx";
  tm_seriesu = "cpuacct_stat" "_" "user" "_arr";
  tm_seriess = "cpuacct_stat" "_" "system" "_arr";
    for (i=1; i <= cg_stat_mx; i++) {
      v = cg_stat_lkup[i];
      nm = "";
      if (v in uhostd_cntr_list) {
        v_i = uhostd_cntr_list[v];
        nm = uhostd_cntr_lkup[v_i, "nm"];
      }
      cg_cntr_typ = cg_stat_lkup[i, "cntr_typ"];
      if (nm  == "" && cg_cntr_typ == cg_cntr_typ_sys) {
        nm = cg_stat_lkup[i, "cntr_typ_sys_srvc"];
      }
      #if (index(nm, "spire-agent") > 0 || index(nm, "auditbeat") > 0) {;} else {continue;}
      #printf("got nm[%d]= %s\n", i, nm);
  #ts_mx = ++tm_cg_stat_data[cntr_i,tm_series_mx];
  #tm_cg_stat_data[cntr_i,tm_series, ts_mx] = tv;
  #tm_cg_stat_data[cntr_i,tm_series_ts_idx, ts_mx] = cur_ts_idx;
      ck_tot= 0;
      ts_mx = tm_cg_stat_data[i, tm_series_mx];
      for (j=2; j <= ts_mx; j++) {
        vt = tm_cg_stat_data[i, tm_series, j];
        ts = tm_cg_stat_data[i, tm_series_ts_idx, j];
        vc = tm_cg_stat_data[i, tm_series2, j];
        vu = tm_cg_stat_data[i, tm_seriesu, j];
        vs = tm_cg_stat_data[i, tm_seriess, j];
        ck_tot += v;
        cg_tot[i,1] += vc;
        cg_tot[i,2] += vt;
        cg_tot[i,3] += vu;
        cg_tot[i,4] += vs;
      }
        cg_ttot[1] += cg_tot[i,1];
        cg_ttot[2] += cg_tot[i,2];
        cg_ttot[3] += cg_tot[i,3];
        cg_ttot[4] += cg_tot[i,4];
      printf("cg_tot[%d] vc= %10.2f vt = %10.2f vu= %10.2f vs= %10.2f nm= %s\n", i, cg_tot[i,1], cg_tot[i,2], cg_tot[i,3], cg_tot[i,4], nm);
      if (cg_tot[i,1] > 0.0) {
      if (!(nm in cg_stat2_nm_list)) {
        cg_stat2_nm_list[nm] = ++cg_stat2_nm_list_mx;
        cg_stat2_nm_lkup[cg_stat2_nm_list_mx] = nm;
      }
      cg_stat2_i = cg_stat2_nm_list[nm];
      cg_stat2_nm_data[cg_stat2_i, "occurs"]++;
      cg_stat2_nm_data[cg_stat2_i, 1] += cg_tot[i,1];
      cg_stat2_nm_data[cg_stat2_i, 2] += cg_tot[i,2];
      cg_stat2_nm_data[cg_stat2_i, 3] += cg_tot[i,3];
      cg_stat2_nm_data[cg_stat2_i, 4] += cg_tot[i,4];
      }
      #break;
    }
    do_kk[1] = 1; do_kk[2] = 2; do_kk[3] = 4;
    do_ks[1] = "tot"; do_ks[2] = "%throttled"; do_ks[3] = "system";
    for (bk=1; bk <= 2; bk++) {
    for (kk=1; kk <= 3; kk++) {
       mk = do_kk[kk];
       ms = do_ks[kk];
        delete arr_in;
        delete res_i;
        delete idx;
    ck_tot = 0;
    new_n = 0;
    for (i=1; i <= cg_stat2_nm_list_mx; i++) {
      nm = cg_stat2_nm_lkup[i];
      v = cg_stat2_nm_data[i, mk];
      if (mk == 2) {
        v = v / cg_stat2_nm_data[i,1];
      }
      if (bk == 2) {
        v = v / cg_stat2_nm_data[i,"occurs"];
      }
      idx[i] = i;
      arr_in[i] = -v;
      ck_tot += v;
    }
    asorti(idx, res_i, "arr_in_compare");
    if (cg_stat_elap_tm > 0) {
    for (j=1; j <= cg_stat2_nm_list_mx; j++) {
      i = res_i[j];
      if (cg_stat_elap_tm > 0) {
        fctr = 100.0/cg_stat_elap_tm;
      } else {
        fctr = 0;
      }
      nm = cg_stat2_nm_lkup[i];
      v = cg_stat2_nm_data[i,mk];
      ck_v = v / cg_ttot[mk];
      hdr = "cpuTL_per_cgrp_nm_" ms;
      if (((mk == 1 || mk == 4) && ck_v < 0.01) || (mk == 2 && (v/cg_stat2_nm_data[i,1]) < 0.05)) { continue; }
      if (mk == 2) {
        v = 100* cg_stat2_nm_data[i,2] /cg_stat2_nm_data[i,1];
        fctr = 1.0;
        hdr = "cpu_per_cgrp_nm_" ms;
        hdr2 = "cgrp_nm_cpu_" ms " " nm;
      } else {
        hdr = "cpuTL_per_cgrp_nm_" ms;
        hdr2 = "cgrp_nm_cpuTL_" ms " " nm;
      }
      if (bk == 2) {
      if (mk == 2) {
        #v = 100*v/cg_stat2_nm_data[i,1];
        fctr = 1.0;
        hdr = "cpu_per_cgrp_nm_per_cntr_" ms;
        hdr2 = "cgrp_nm_cpu_" ms " " nm;
      } else {
        hdr = "cpuTL_per_cgrp_nm_per_cntr_" ms;
        hdr2 = "cgrp_nm_cpuTL_" ms " " nm;
        fctr = fctr / cg_stat2_nm_data[i,"occurs"];
      }
      }
      printf("cg_stat2_nm_data[%d] vc= %10.2f vt = %10.2f vu= %10.2f vs= %10.2f nm= %s\n", j,
         fctr*cg_stat2_nm_data[i,1], fctr*cg_stat2_nm_data[i,2], fctr*cg_stat2_nm_data[i,3], fctr*cg_stat2_nm_data[i,4], nm);
      printf("%s\t%s\t%f\t%s\n", hdr, hdr, fctr*v, hdr2) > sum_file;
    }
    }
    printf("above cg_stat2_nm_data table is total cpu_usageTL %s for that service. Doesnt take into account you might have > 1 container for service. tot cpuTL= %.3f\n", ms, fctr*ck_tot);
    }
    }

    if (cg_stat_elap_tm > 0) {
    for (i=1; i <= cg_stat_nm_list_mx; i++) {
      nm = cg_stat_nm_lkup[i];
      v_rps = 0;
      if (nm in mutt_list) {
        mutt_i = mutt_list[nm];
        v_rps = mutt_calls_tot[mutt_i];
      }
      ms_per_req = 0;
      v1 = cg_stat_nm_data[i, "cumu"];
      if (v_rps > 0) {
        ms_per_req = 1000.0 * v1/v_rps;
      }
      v3 = 100.0* v1 / (cg_stat_elap_tm);
      v4 = cg_stat_nm_data[i, "occurs"];
      printf("cg_stat_nm[%d] cpu_secs= %10.2f thr_secs= %8.4f  rps= %8d ms_per_req= %8.2f %%busy= %8.2f ms/req/cntr= %8.2f %%busy/cntr= %8.2f cntr_occurs= %4d nm= %s\n", i,
        cg_stat_nm_data[i, "cumu"], cg_stat_nm_data[i, "thr_cumu"],  v_rps, ms_per_req, v3, ms_per_req/v4, v3/v4,  v4, nm);
    }
    }

        delete arr_in;
        delete res_i;
        delete idx;
        my_n = 0;
        for(j=2; j <= idle_mx; j++) {
           v0 = num_cpus * (sv_uptm[j]-sv_uptm[j-1]);
           v1 = v0 - (sv_idle[j]-sv_idle[j-1]);
           v2 = 100.0*num_cpus*v1/v0;
           idx[++my_n] = j;
           arr_in[my_n] = v2;
        }
        asorti(idx, res_i, "arr_in_compare");
        for (kk=1; kk <= px_mx; kk++) {
          uval = compute_pxx(kk, my_n, res_i, arr_in);
          strp = "%cpu_util p" px[kk];
          printf("%s\t%s\t%f\t%s\n", "cpu_util_per_hst", "cpu_util_per_hst", uval, strp) > sum_file;
        }

    dckr_all = "_docker_all_";
    sum = 0.0;
    sum_sys = 0.0;
    ncg_list_mx = 0;
    for (i=1; i <= cg_list_mx; i++) {
      cg = cg_lkup[i];
      cgl = length(cg);
      if (cgl > 7 && substr(cg, 1, 7) == "docker/") {
        cntr = substr(cg, 8, cgl);
        if (cntr in uhostd_cntr_list) {
          c_i = uhostd_cntr_list[cntr];
        } else {
          c_i = "";
        }
        #c_i = uhostd_cntr_list[cntr];
        svc = uhostd_cntr_lkup[c_i,"svc"];
        name = uhostd_cntr_lkup[c_i,"name"];
        unm  = uhostd_cntr_lkup[c_i,"nm"];
        if (svc != "") {
          nm = svc;
        } else if (unm != "") {
          nm = unm;
        } else if (name != "") {
          nm = name;
        }
      } else {
        nm = cg;
      }
      cg_sg = cg_lkup[i,"subgrp"];
      qklk = cg_lkup[i,"qklk"];
      v = cg_lkup[i,"tm_tot"];
      if (qklk == nm_lkfor) {
        printf("lkfor: cg_lkup[%d,tm_tot]= %.3f nm= %s\n", i, v, nm);
      }
      printf("lkfor: cg_lkup[%d,tm_tot]= %.3f is_infra= %s nm= %s\n", i, v, cg_lkup[i,"is_infra"],  nm);
      sum2 = 0.0;
      if (1==2) {
      for (ii=2; ii <= cg_mx; ii++) {
        if (cg_data[ii,i,"tm"] >= cg_data[ii-1,i,"tm"]) {
          v2 = cg_data[ii,i,"tm"] - cg_data[ii-1,i,"tm"];
          sum2 += v2;
          printf("pos cg_data[%d,%d,tm]= %.3f cg_data[%d,%d,tm]= %f nm= %s, v2= %.3f mx-mn= %.3f\n", ii, i, cg_data[ii,i,"tm"], ii-1,i, cg_data[ii-1,i,"tm"], nm, v2, v);
        } else {
          printf("neg cg_data[%d,%d,tm]= %.3f cg_data[%d,%d,tm]= %f nm= %s\n", ii, i, cg_data[ii,i,"tm"], ii-1,i, cg_data[ii-1,i,"tm"], nm);
        }
      }
      }
      if (v < 0.0)  { v = 0.0;}
      if(cg != "_all_" && cg != "system.slice") {
        sum += v;
        if (index(cg_sg, "sys.") == 1) {
          sum_sys += v;
        }
      }
      if (nm == "") {
        nm = cg_lkup[i,"orig"];
      }
      if (!(nm in ncg_list)) {
        ncg_list[nm] = ++ncg_list_mx;
        printf("added ncg_list[%s] = %d\n", nm, ncg_list_mx);
        ncg_lkup[ncg_list_mx,"nm"] = nm;
        ncg_lkup[ncg_list_mx,"tm"] = 0.0;
        ncg_lkup[ncg_list_mx,"mx"] = 0;
        ncg_lkup[ncg_list_mx,"subgrp"] = cg_lkup[i,"subgrp"];
        if (nm == "_all_") { sv_i_all = i; sv_ni_all = ncg_list_mx; }
        if (nm == "system.slice") { sv_i_sys_slc = i; sv_ni_sys_slc = ncg_list_mx; }
        if (ncg_list_mx == 1) {
          nm_t = dckr_all;
          ncg_list[nm_t] = ++ncg_list_mx;
          ncg_lkup[ncg_list_mx,"nm"] = nm_t;
          ncg_lkup[ncg_list_mx,"tm"] = 0.00001; # give it some time so it doesnt get dropped
          ncg_lkup[ncg_list_mx,"mx"] = 0;
          ncg_lkup[ncg_list_mx,"subgrp"] = cg_lkup[i,"subgrp"];
          sv_ni_dckr = ncg_list_mx;
        }
      }
      if (qklk == nm_lkfor) {
        printf("qklk= %s, nm= %s, v= %.3f\n", qklk, nm, v);
      }
      ncg_i = ncg_list[nm];
      ncg_n = ++ncg_lkup[ncg_i,"mx"];
      ncg_lkup[ncg_i,"list",ncg_n] = i;
      ncg_lkup[ncg_i,"tm"] += v;
      #printf("cg_cntr[%d]= %10.3f nm= %s, %s, sum2= %.3f, tm_tot= %.3f\n", i, v, nm, cg_lkup[i,"subgrp"], sum2, cg_lkup[i,"tm_tot"]);
      #printf("ncg_lkup[%d,tm]= %.3f nm= %s\n", ncg_i, ncg_lkup[ncg_i,"tm"], nm);
    }
    ncg_lkup[sv_ni_dckr,"tm"] = ncg_lkup[sv_ni_all,"tm"] - ncg_lkup[sv_ni_sys_slc,"tm"];
    printf("cg_cntr all tm= %10.3f\n", sum);
    printf("cg_cntr sys tm= %10.3f\n", sum_sys);
    delete idx;
    delete res_i;
    for (i=1; i <= ncg_list_mx; i++) {
      idx[i] = i;
    }
    asorti(idx, res_i, "compare_ncg")
    svc_nm0 = "system.slice";
    svc_nm1 = "services";
    for (j=1; j <= ncg_list_mx; j++) {
      i = res_i[j];
      nm = ncg_lkup[i,"nm"];
      tm = ncg_lkup[i,"tm"];
      sgrp = ncg_lkup[i,"subgrp"];
      if (nm == svc_nm0) { nm = svc_nm1;}
      printf("sorted ncg_cntr[%2d]= %10.3f nm= %s, %s\n", i, tm, nm, sgrp);
    }
      for (j=1; j <= nmutt_mx; j++) {
        printf("nmutt_lkup[%d,nm]= %s, tot= %d\n", j, nmutt_lkup[j,"nm"], nmutt_lkup[j,"tot"]);
      }
      for(j=1; j <= ncg_list_mx; j++) {
        i = res_i[j];
        v = ncg_lkup[i,"tm"];
        nm = ncg_lkup[i,"nm"];
        if (nm == "docker" || nm == dckr_all || nm == "_all_" || nm == "system.slice") { continue; }
        sgrp = ncg_lkup[i,"subgrp"];
        #printf("ck ncg_list[%d] nm= %s sgrp= %s\n", i, nm, sgrp);
        #if (sgrp == "sys.srvc") { continue; }
        if (sgrp != "") { continue; }
        v0 = tolower(nm);
        if (v0 != dckr_all && !(v0 in srvcs_list)) {
           srvcs_list[v0] = ++srvcs_mx;
           srvcs_lkup[srvcs_mx,"nm"] = v0;
           srvcs_lkup[srvcs_mx,"tm"] = 0.0;
           printf("add srvcs_lkup[%d,nm]= %s\n", srvcs_mx, v0);
         }
      }
      for (i=1; i <= srvcs_mx; i++) {
        svc = srvcs_lkup[i,"nm"];
        if (svc in nmutt_list) {
          printf("srvc[%d]= %s     found in muttley list nmutt_mx= %s\n", i, svc, nmutt_mx);
          for (j=3; j <= nmutt_mx; j++) {
            #printf("srvc[%d]= \"%s\"  ck  if found in nmutt_lkup[%d,nm]= \"%s\" list nmutt_mx= %s\n", i, svc, j, nmutt_lkup[j,"nm"],  nmutt_mx);
            if(nmutt_lkup[j,"nm"] == svc) {
              n = ++srvcs_lkup[i,"mutt_mx"];
              srvcs_lkup[i,"mutt_list",n] = j;
              printf("srvc[%d]= %s yes found in muttley list[%d]\n", i, svc, j);
              got_it = 1;
            }
          }
        } else {
          got_it = 0;
          nm = svc ".";
          nml = length(nm);
          str = "";
          for (j=3; j <= nmutt_mx; j++) {
            #if(substr(nmutt_lkup[j,"nm"], 1, nml) == nm)
            if(nmutt_lkup[j,"nm"] == nm) {
              n = ++srvcs_lkup[i,"mutt_mx"];
              srvcs_lkup[i,"mutt_list",n] = j;
              printf("srvc[%d]= %s yes found in muttley list[%d]\n", i, nm, j);
              got_it = 1;
            }
          }
          if (got_it == 0) {
            printf("srvc[%d]= %s not found in muttley list, nm= %s\n", i, svc, nm);
          }
        }
      }

    tdiff = cg_dt[cg_mx] - cg_dt[1];
    printf("cgroup tdiff %d secs\n", tdiff);
    #trow = -1;
    #srvcs_mx = 0;
    if (ncg_list_mx > 0) {
    for (cg=1; cg <= 4; cg++) {
      if (cg == 1) { str1 = "docker all"; }
      if (cg == 2) { str1 = "services"; }
      if (cg == 3) { str1 = "services & docker"; }
      if ( use_top_pct_cpu == 0) {
        str = "cgrps "str1" cpu usage (1==1cpu_busy)";
      } else {
        str = "cgrps "str1" %cpu usage (100=1cpu_busy)";
      }
      if (cg == 4) {
        str1 = "docker all";
        str = "cgrps "str1" ms/call";
      }
      if (cg == 5) {
        str1 = "services & docker";
        str = "cgrps "str1" %cpu throttled usage (100=1cpu_busy)";
      }
      title_text = sprintf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", str, "infra procs");
      hstr = sprintf("epoch\tts");
      cg_cols=0;
      for(j=1; j <= ncg_list_mx; j++) {
        i = res_i[j];
        v = ncg_lkup[i,"tm"];
        if (v == 0) { continue; }
        nm = ncg_lkup[i,"nm"];
        sgrp = ncg_lkup[i,"subgrp"];
        if (cg == 1) {
          if (nm == "docker" || nm == dckr_all || nm == "_all_" || nm == "system.slice") { continue; }
          sgrp = ncg_lkup[i,"subgrp"];
          if (sgrp == "sys.srvc") { continue; }
          if (sgrp != "") { continue; }
          v0 = tolower(nm);
          k = ++bycg_list[cg,"mx"];
          bycg_list[cg,"list",k] = i;
          printf("cg= %d, nm= %s, ttl= %s\n", cg, nm, str);
        }
        if (cg == 2) {
          sgrp = ncg_lkup[i,"subgrp"];
          #if (nm == "system.slice" || sgrp == "sys.srvc") {;} else { continue; }
          if (sgrp == "sys.srvc") {;} else { continue; }
          k = ++bycg_list[cg,"mx"];
          bycg_list[cg,"list",k] = i;
        }
        if (cg == 3) {
          sgrp = ncg_lkup[i,"subgrp"];
          if (nm  == "_all_" || nm == "system.slice" || nm == dckr_all) { ;} else { continue; }
          k = ++bycg_list[cg,"mx"];
          bycg_list[cg,"list",k] = i;
        }
        if (cg == 4) {
          if (nm == "docker" || nm == dckr_all || nm == "_all_" || nm == "system.slice") { continue; }
          sgrp = ncg_lkup[i,"subgrp"];
          if (sgrp == "sys.srvc") { continue; }
          if (sgrp != "") { continue; }
          if (!(nm in srvcs_list)) {
            continue;
          }
          srvcs_i = srvcs_list[nm];
          #printf("got ms_per_call cg4 nm= %s srvcs_i= %s\n", nm, srvcs_i);
          if (!((srvcs_i,"mutt_mx") in srvcs_lkup)) {
            continue;
          }
          nn = srvcs_lkup[srvcs_i,"mutt_mx"];
          if (nn == "" || nn == 0) { continue; }
          k = ++bycg_list[cg,"mx"];
          bycg_list[cg,"list",k] = i;
        }
        if (cg == 5) {
          sgrp = ncg_lkup[i,"subgrp"];
          #if (nm == "system.slice" || sgrp == "sys.srvc") {;} else { continue; }
          #if (sgrp == "sys.srvc") {;} else { continue; }
          k = ++bycg_list[cg,"mx"];
          bycg_list[cg,"list",k] = i;
        }
        if (nm == svc_nm0) { nm = svc_nm1;}
        if (cg < 4 && 1==1 && sum_file != "") {
            v = v / tdiff;
            unm = nm;
            if (unm == "services") { unm = "services all";}
            if ( use_top_pct_cpu == 0) {
              printf("cgrps_cpu\tcgrps cpus %s\t%.3f\t%s %s\n", str1, v , str1, unm) > sum_file;
            } else {
              v *= 100.0;
              printf("cgrps_cpu\tcgrps %%cpu %s\t%.3f\t%s %s\n", str1, v, str1, unm) > sum_file;
            }
        }
        ++cg_cols;
        #printf("ch hdr[%d] cg= %d, nm= %s title= %s\n", cg_cols, cg, nm, str);
        hstr = hstr sprintf("\t%s", nm);
      }
      if (cg_cols == 0) { continue; }
      trow++;
      printf("%s", title_text) > ofile;
      if ( use_top_pct_cpu == 0) {
        top_fctr = 1.0;
      } else {
        top_fctr = 100.0;
      }
      n_hstr = split(hstr, harr, "\t");
      trow++;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, n_hstr-1, 1) > ofile;
      trow++;
      printf("%s\n", hstr) > ofile;

      tm_attributable_to_cntr = 0;
      tm_attributable_to_cntr_and_mutt = 0;
      for (k=2; k <= cg_mx; k++) {
        elap = cg_dt[k] - cg_dt[1];
        tdff = cg_dt[k] - cg_dt[k-1];
        printf("%.0f\t%.0f", cg_dt[k], elap) > ofile;
        for(j=1; j <= ncg_list_mx; j++) {
           i = res_i[j];
           v = ncg_lkup[i,"tm"];
           if (v == 0) { continue; }
           nm = ncg_lkup[i,"nm"];
           sgrp = ncg_lkup[i,"subgrp"];
           ck_imx = bycg_list[cg,"mx"];
           for (iii=1; iii <= ck_imx; iii++) {
             if (i == bycg_list[cg,"list",iii]) {
               break;
             }
           }
           if (iii > ck_imx) {
             continue;
           }
           ncg_n = ncg_lkup[i,"mx"];
           sum = 0.0;
           vld = 0;
           for(kk=1; kk <= ncg_n; kk++) {
             lkup_i = ncg_lkup[i,"list",kk];
             v1 = cg_data[k,lkup_i,"tm"];
             if (v1 != "") { vld = 1;}
             v0 = cg_data[k-1,lkup_i,"tm"];
             v = v1 - v0;
             if (v < 0.0) { v = 0.0; }
             sum += v;
             if (nm == nm_lkfor) { printf("k= %d, %s v= %.3f sum= %.3f, kk= %d, lkup_I= %d, cg_nm= %s, tdff= %f v0= %f v1= %f v/tdff= %.3f\n", k, nm, v, sum, kk, lkup_i, cg_lkup[lkup_i,"qklk"], tdff, v0, v1, v/tdff); }
           }
           sv_sum = sum;
           if (cg == 3 && nm == dckr_all) {
             sum = 0.0;
             if (cg_data[k,sv_i_all,"tm"] != "") { vld = 1;}
             v1 = cg_data[k,sv_i_all,"tm"] - cg_data[k,sv_i_sys_slc,"tm"]
             v0 = cg_data[k-1,sv_i_all,"tm"] - cg_data[k-1,sv_i_sys_slc,"tm"]
             v = v1 - v0;
             if (v < 0.0) { v = 0.0; }
             sum += v;
           }
           if (1==2 && cg == 2 && sgrp == "sys.srvc") {
             #sum = 0.0;
             #v1 = cg_data[k,sv_i_all,"tm"] - cg_data[k,sv_i_sys_slc,"tm"]
             #v0 = cg_data[k-1,sv_i_all,"tm"] - cg_data[k-1,sv_i_sys_slc,"tm"]
             #v = v1 - v0;
             #if (v < 0.0) { v = 0.0; }
             #sum += v;
               cgrps_val_arr["cat_mx"] = iii;
               cgrps_val_arr["cat_nm",iii] = nm;
               cgrps_val_arr["str",iii] = "%cpu";
               kk = ++cgrps_val_arr["vals_mx",iii,nm];
               cgrps_val_arr["val",iii,kk,1] = sum;
               cgrps_val_arr["val",iii,kk,2] = sum;
               cgrps_val_arr["val",iii,kk,3] = 0;
               cgrps_val_arr["val",iii,kk,4] = tdff;
               cgrps_val_arr["val",iii,kk,5] = vld;
           }
           if (cg == 1) {
             if (nm in srvcs_list) {
               srvcs_i = srvcs_list[nm];
               v1 = sum/tdff;
               srvcs_lkup[srvcs_i,"tm"] += sum;
               srvcs_lkup[srvcs_i,"tdff"] += tdff;
               if (nm == nm_lkfor) {sum_eats += sum; printf("k= %d srvcs_lkup[%s,tm]= %.3f tdff= %.3f sum_eats= %.3f\n", k, nm, sum, tdff, sum_eats);}
             }
           }
           v2 = top_fctr * sum/tdff;
           if (cg == 4 || (cg == 2 && sgrp == "sys.srvc")) {
             tm_attributable_to_cntr += sum;
             srvcs_i = srvcs_list[nm];
             calls = 0;
             nn = srvcs_lkup[srvcs_i,"mutt_mx"];
             for (jj=1; jj <= nn; jj++) {
               ik = srvcs_lkup[srvcs_i,"mutt_list",jj];
               c1 = nmutt_data[k-1,ik] * (nmutt_data[k,2] - nmutt_data[k-1,2]);
               if (c1 != "" && c1 > 0) {
                 calls += c1;
               }
               #printf("ck_ms_call: k= %d jj= %d, nm= %s, calls= %d, mutt_nm= %s nn= %d\n", k, jj, nm, calls, nmutt_lkup[ik,"nm"], nn);
             }
             #printf("got to ms_per_call ck0 v2= %s sum= %s calls %s tdff %s nm %s\n", v2, sum, calls, tdff, nm);
             v2 = "";
             if (cg == 2 && sgrp == "sys.srvc") {
               v2 = sum;
             }
             if (calls > 0) {
               calls_attributable_to_cntr_mutt += calls;
               if (sum > 0.0) {
                 v2 = 1000.0* sum/calls;
               }
               tm_attributable_to_cntr_mutt += sum;
               #printf("ck_ms_call: k= %d nm= %s, calls= %d, mutt_nm= %s nn= %d\n", k, nm, calls, nmutt_lkup[ik,"nm"], nn);
             } else {
               v2 = "";
             }
             if (cg == 2 && sgrp == "sys.srvc") {
               v2 = top_fctr * sum/tdff;
             }
             #printf("got to ms_per_call ck v2= %s sum= %f calls %f tdff %f nm %s\n", v2, sum, calls, tdff, nm);
        #printf("at103 cg= %d iii= %d sum= %s nm= %s\n", cg, iii, sum, nm);
               cgrps_val_arr["cat_mx"] = iii;
               cgrps_val_arr["cat_nm",iii] = nm;
               cgrps_val_arr["str",iii] = "ms_per_call";
               ++cgrps_val_arr["vals_mx",iii,nm];
               kk = cgrps_val_arr["vals_mx",iii,nm];
               cgrps_val_arr["val",iii,kk,1] = (cg == 4 ? v2 : v);
               cgrps_val_arr["val",iii,kk,2] = sum;
               cgrps_val_arr["val",iii,kk,3] = calls;
               cgrps_val_arr["val",iii,kk,4] = tdff;
               cgrps_val_arr["val",iii,kk,5] = vld;
           }

             #if (cg == 3) {
               styp = 1;
               snm = "tot_docker_services";
               if (sgrp == "sys.srvc") {
                 styp = 2;
                 snm = "tot_infra_agent";
               }
               #printf("got into cgrps_val_tarr stuff\n");
               cgrps_val_tarr["cat_mx"] = styp;
               cgrps_val_tarr["cat_nm",styp] = snm
               cgrps_val_tarr["str",styp] = "ms_per_call";
               cgrps_val_tarr["vals_mx",styp,snm] = k;
               kk = cgrps_val_tarr["vals_mx",styp,snm];
               v2 = top_fctr * sv_sum/tdff;
               cgrps_val_tarr["val",styp,kk,1] += v2;
               cgrps_val_tarr["val",styp,kk,2] += sv_sum;
               cgrps_val_tarr["val",styp,kk,3] += calls;
               cgrps_val_tarr["val",styp,kk,4] += tdff;
               cgrps_val_tarr["val",styp,kk,5] = vld;
             #}
               #printf("got to ms_per_call v2= %f sum= %f calls %f tdff %f kk= %d nm %s\n", v2, sum, calls, tdff, kk, nm) >> "tmp.jnk";
             #}
           printf("\t%.3f", v2) > ofile;
           if (nm == nm_lkfor) { printf("k= %d, %s v2= %.3f top_fctr= %.3f, sum= %.3f, tdff= %f\n", k, nm, v2, top_fctr, sum, tdff); }
        }
        printf("\n") > ofile;
        trow++;
      }
      printf("\n") > ofile;
      trow++;
      if (cg == 2 || cg == 4) {
         do_cgrps_val_arr(cg);
      }

    }
    }
     #printf("cg= %d cgrps_val_arr["cat_mx"] = %d\n", cg, cgrps_val_arr["cat_mx"]);
    if (1==1) {
        delete arr_in;
        delete res_i;
        delete idx;
        mutt_host_calls = -1;
        for(j=1; j <= mutt_mx2; j++) {
          if (mutt_lkup[j] == "host.calls") {
            mutt_host_calls = j;
            break;
          }
        }
        my_n = 0;
        for(k=2; k <= muttley_mx; k++) {
          tm_diff = muttley_dt[k]-muttley_dt[k-1];
          if (tm_diff > 0.0) {
            ++my_n;
            v = mutt_calls2[k,j] / tm_diff;
            idx[my_n] = j;
            arr_in[my_n] = v;
          }
        }
        asorti(idx, res_i, "arr_in_compare");
        for (kk=1; kk <= px_mx; kk++) {
          uval = compute_pxx(kk, my_n, res_i, arr_in);
          strp = "RPS _all_ p" px[kk];
          printf("%s\t%s\t%f\t%s\n", "RPS_per_hst", "RPS_per_hst", uval, strp) > sum_file;
        }
        #mutt_lkup[mutt_mx] = mutt_nm;
    }



    if (proc_mx > 0) {
    delete idx;
    delete res_i;
    for(i=1; i <= proc_mx; i++) {
      idx[i] = i;
    }
    asorti(idx, res_i, "tot_compare")
    #trow = -1;
    trow++;
    if ( use_top_pct_cpu == 0) {
      str = "infra procs cpus (1==1cpu_busy)";
    } else {
      str = "infra procs %cpus (100=1cpu_busy)";
    }
    printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", str, "infra procs") > ofile;
    printf("proc_mx= %d\n", proc_mx);
    hstr = sprintf("epoch\tts");
    idle_i = -1;
    for(i=1; i <= proc_mx; i++) {
      j = res_i[i];
      if (tot[j] == 0) { continue; }
      if (proc_lkup[j] == "idle") {
        idle_i = j;
        continue;
      }
      hstr = hstr sprintf("\t%s", proc_lkup[j]);
    }
    trow++;
    n_hstr = split(hstr, harr, "\t");
    printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, n_hstr-1, 1) > ofile;
    trow++;
    printf("%s\n", hstr) > ofile;

    printf("mutt_file= %s\n", mutt_file);
    if (mutt_file != "") {
      sum = 0.0;
      nsum = 0.0;
      gsum = 0.0;
      calls_not_acctd_for = 0;
      for (i=1; i <= srvcs_mx; i++) {
        tm = srvcs_lkup[i,"tm"];
        gsum += tm;
      }
      mutt_calls_used = 0;
      for (i=1; i <= srvcs_mx; i++) {
        svc = srvcs_lkup[i,"nm"];
        tm = srvcs_lkup[i,"tm"];
        n = srvcs_lkup[i,"mutt_mx"];
        calls = 0;
        for (j=1; j <= n; j++) {
           k = srvcs_lkup[i,"mutt_list",j];
           calls += nmutt_lkup[k,"tot"];
        }
        printf("ck_svc[%d]= %s, tm= %.3f, n= %d calls= %d\n", i, svc, tm, n, calls);
        if (calls > 0) {
          srvcs_lkup[i,"mutt_calls"] = calls;
          sum += tm;
          mutt_calls_used += calls;
        } else {
          nsum += tm;
          #printf("cntr_nomap_to_muttley\tcntr_nomap %%tot_cntr_cpusecs %s %.3f%%, no muttley,                 %s\n", i, 100.0* tm / gsum, svc);
          if (sum_file != "") {
            printf("cntr_nomap_to_muttley\tcntr_nomap_to_muttley_pct_of_tot_cntr_cpusecs\t%.3f\tcntr_nomap %s\n", 100.0*tm/gsum, svc) > sum_file;
          }
        }
      }
      total_busy_cpusecs = num_cpus * (sv_uptm[idle_mx]-sv_uptm[1]) - (sv_idle[idle_mx]-sv_idle[1]);
      total_elapsed_time = sv_uptm[idle_mx]-sv_uptm[1];
      if (sum_file != "") {
        printf("elapsed time secs\telapsed time secs\t%.3f\telapsed_time\n", total_elapsed_time) > sum_file;
        printf("total busy cpusecs\ttotal_busy_cpusecs\t%.3f\ttot_cpusecs\n", total_busy_cpusecs) > sum_file;
        printf("total %%cpu_utilization\ttotal_%%cpu_utilization\t%.3f\t%%cpu_util\n", 100.0*total_busy_cpusecs/(num_cpus*total_elapsed_time)) > sum_file;
        printf("total mapped cntr cpusecs\ttot_map_cntr_cpusecs\t%.3f\ttot_map_cntr_cpusecs\n", sum) > sum_file;
        printf("total notmapped cntr cpusecs\ttot_notmap_cntr_cpusecs\t%.3f\ttot_notmap_cntr_cpusecs\n", nsum) > sum_file;
        printf("total cntr cpusecs\ttot_cntr_cpusecs\t%.3f\ttot_cntr_cpusecs\n", gsum) > sum_file;
        for (j=1; j <= 4; j++) {
          for (i=1; i <= srvcs_mx; i++) {
            calls = srvcs_lkup[i,"mutt_calls"];
            if (calls == 0) {continue;}
            svc   = srvcs_lkup[i,"nm"];
            tm    = srvcs_lkup[i,"tm"];
            n     = srvcs_lkup[i,"mutt_mx"];
            if (j == 1) {
              printf("cntr_map_to_muttley\tcntr_cpu_ms_per_call\t%.3f\tms/call %s\n", 1000.0*tm/calls, svc) > sum_file;
            }
            if (j == 2) {
              printf("cntr_map_to_muttley_pct\tcntr_pct_of_tot_cntr_secs\t%.3f\tcntr_%%sec %s\n", 100.0*tm/gsum, svc) > sum_file;
            }
            if (j == 3) {
              printf("cntr_map_to_muttley_tm\tcntr_secs\t%.3f\tcntr_cpusecs %s\n", tm, svc) > sum_file;
            }
            if (j == 4) {
              printf("cntr_map_to_muttley_calls\tcntr_calls\t%.3f\tcntr_calls %s\n", calls, svc) > sum_file;
            }
#printf("cgrp[%d] cpu_usage %.3f%%, cpu_ms/call= %.3f tm= %.3f, calls= %3.f %s\n", i, 100.0*tm/gsum, 1000.0* tm / calls, tm, calls, svc);
          }
        }
      }
      v = 0.0;
      if (tm_attributable_to_cntr > 0) {
        v = 100.0* tm_attributable_to_cntr_mutt/tm_attributable_to_cntr;
      }
      printf("total cgrp cpu_time attributable to muttley calls = %.3f%% or %.3f of %.3f, tot time not attributable to muttley calls= %.3f%%, gsum= %.3f\n",
         v , tm_attributable_to_cntr_mutt, tm_attributable_to_cntr, 100.0 - v, gsum);
      v = 0.0;
      if (nmutt_calls_tot > 0) {
        v = 100.0* calls_attributable_to_cntr_mutt/nmutt_calls_tot;
      }
      printf("total %%mutt_calls attributable to cgrs= %.3f%% or %.3f of %.3f, calls not attributable to cgrps= %.3f%%\n",
        v, calls_attributable_to_cntr_mutt, nmutt_calls_tot, 100.0 - v);
    }
    }

    for(i=1; i <= pse_proc_mx; i++) {
      pse_idx[i] = i;
    }
    asorti(pse_idx, pse_res_i, "pse_tot_compare")
#title   perf stat       sheet   perf stat       type    scatter_straight
#hdrs    4       5       -1      31      1
#epoch   ts      rel_ts  interval
    #trow++;
    #if ( use_top_pct_cpu == 0) {
    #  str = "infra procs cpus_tot (1==1cpu_busy)";
    #} else {
    #  str = "infra procs %cpus_tot (100=1cpu_busy)";
    #}
    #printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", str, "infra procs") > ofile;
    #trow++;
    #printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, pse_proc_mx+1, 1) > ofile;
    #printf("proc_mx= %d\n", pse_proc_mx);
    #printf("epoch\tts") > ofile
    pse_fctr = 1.0;
    pse_idle = 0.0;
    pse_fmt_str = "%%";
    if (pse_mx > 1) {
      pse_elap_tm = pse_dt[pse_mx] - pse_dt[1];
      pse_fctr = pse_elap_tm /100.0;
      if ( num_cpus > 0 && use_top_pct_cpu == 0) {
        pse_fctr *= num_cpus;
      }
      pse_idle = (idle_mx > 0 ? (sv_idle[idle_mx]-sv_idle[1]): 0.0);
      fctr = 100.0;
    }
    pse_t = 0.0;
    for(i=1; i <= pse_proc_mx; i++) {
      j = pse_res_i[i];
      pse_t += (pse_tot[j] >= 0.0 ? pse_tot[j] : 0.0);
    }
    v = pse_t/pse_fctr;
    v_idl = pse_idle/pse_fctr;
    printf("%.3f%%\t_total_busy_ps_ef\n", v);
    printf("%.3f%%\t_idle_ps_ef\n", v_idl);
    for(i=1; i <= pse_proc_mx; i++) {
      j = pse_res_i[i];
      if (pse_tot[j] == 0) { continue; }
      v = pse_tot[j]/pse_fctr;
      printf("%.3f%s\tpid= %s\n", v, pse_fmt_str, pse_proc_lkup[j]);
      if (v < 1.0) { break; };
    }
    #printf("\n") > ofile;
    #trow++;

    fctr = 1.0;
    if ( use_top_pct_cpu == 1) {
      fctr = 100.0;
    }

    # if we are doing max values and if there are multiple values that make up the max
    # then we have to careful to make sure all the values come from the same interval.
    # Othewise we can have max values that sum to more than # of cpus.
    busy_mx = 0;
    busy_infra              = ++busy_mx;
    busy_infra_str[busy_mx] = "busy infra"
    busy_non_infra          = ++busy_mx;
    busy_infra_str[busy_mx] = "busy non-infra"
    busy_muttley            = ++busy_mx;
    busy_infra_str[busy_mx] = "busy muttley"
    for(i=1; i <= proc_mx; i++) {
      nm = proc_lkup[i];
      if (nm == "muttley" || nm == "muttley-active") {
        is_busy_muttley[i] = 1;
      } else {
        is_busy_muttley[i] = 0;
      }
      if (nm != "idle" && (nm == "__other_busy__" || nm == "java" || nm == "python2.7")) {
        is_busy_non_infra[i] = 1;
      } else {
        is_busy_non_infra[i] = 0;
        if (nm != "idle") {
          is_busy_infra[i] = 1;
        } else {
          is_busy_infra[i] = 0;
        }
      }
    }
    for(k=2; k <= mx; k++) {
      tm_off = dt[k]-dt[1];
      printf("%s\t%d", dt[k], tm_off) > ofile;
      sum = 0.0;
      for(i=1; i < idle_idx; i++) {
         sum += sv[k,i];
      }
      sv[k,idle_idx] = idle[k];
      if (num_cpus > 0) {
        i = idle_idx+1;
        busy = uptm[k] - idle[k] - sum;
        if (busy < 0.0) { busy = 0.0; }
        sv[k,i] = busy;
      }
      for(i=1; i <= proc_mx; i++) {
        j = res_i[i];
        if (tot[j] == 0) { continue; }
        v = fctr*sv[k,j];
        cv[j] = v;
        if (sv_max[j] < v) {
           #printf("new[%d,%d]= %f infra max %f\n", k, j, tm_off, v) > "/dev/stderr";
           sv_max[j] = v;
        }
        if (j == idle_i) {
          continue;
        }
        printf("\t%.3f", v) > ofile;
      }
      for (i=1; i <= busy_mx; i++) {
        inf_sum[i] = 0.0;
      }
      for(i=1; i <= proc_mx; i++) {
        if (is_busy_muttley[i] == 1) {
          inf_sum[busy_muttley] += cv[i];
        }
        if (is_busy_non_infra[i] == 1) {
          inf_sum[busy_non_infra] += cv[i];
        }
        if (is_busy_infra[i] == 1) {
          inf_sum[busy_infra] += cv[i];
        }
      }
      for (i=1; i <= busy_mx; i++) {
        if (inf_max[i] < inf_sum[i]) {
          inf_max[i] = inf_sum[i];
        }
      }
      printf("\n") > ofile;
      trow++;
    }
    trow++;
    printf("\n") > ofile;
    if (sum_file != "") {
      printf("-------------sum_file= %s, proc_mx= %d\n", sum_file, proc_mx);
      printf("sum_file= %s\n", sum_file);
      for(i=1; i <= proc_mx; i++) {
         j = res_i[i];
         if (tot[j] == 0) { continue; }
         if ( use_top_pct_cpu == 0) {
           printf("infra_procs\tinfra procs cpus\t%.3f\t%s\n", tot[j], proc_lkup[j]) > sum_file;
         } else {
           v = 100.0 * tot[j];
           printf("infra_procs\tinfra procs %%cpu\t%.3f\t%s\n", v, proc_lkup[j]) > sum_file;
         }
      }
      for(i=1; i <= proc_mx; i++) {
         j = res_i[i];
         if (tot[j] == 0) { continue; }
         v = sv_max[j];
         if ( use_top_pct_cpu == 0) {
           printf("infra_procs\tinfra procs max cpus\t%.3f\t%s\n", v, proc_lkup[j]) > sum_file;
         } else {
           # v = 100.0 * sv_max[j];
           printf("infra_procs\tinfra procs max %%cpu\t%.3f\t%s\n", v, proc_lkup[j]) > sum_file;
         }
      }
      for (i=1; i <= busy_mx; i++) {
         str = busy_infra_str[i];
         v   = inf_max[i];
         if ( use_top_pct_cpu == 0) {
           printf("infra_procs\tinfra procs max cpus\t%.3f\t%s\n", v, str) > sum_file;
         } else {
           printf("infra_procs\tinfra procs max %%cpu\t%.3f\t%s\n", v, str) > sum_file;
         }
      }
      #close(sum_file);
      #printf("%f\n", 1.0/0.0); # force an error
    }
    if (docker_mx > 2) {
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
         printf("infra_procs\tcontainers avg\t%.3f\t%s\n", avg, "total") > sum_file;
         for(i=1; i <= dckr_hdr_mx; i++) {
           avg = dckr_sum[i]/dckr_n;
           printf("infra_procs\tcontainers avg\t%.3f\t%s\n", avg, dckr_hdr[i]) > sum_file;
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
           printf("infra_procs\tinfra TCP\t%.3f\t%s/sec\n", (tcp[net_mx,i]-tcp[1,i])/dff, tcp_hdrs[i]) > sum_file;
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
           printf("infra_procs\tinfra UDP\t%.3f\t%s/sec\n", (udp[net_mx,i]-udp[1,i])/dff, udp_hdrs[i]) > sum_file;
         }
      }
    }
    if (netdev_mx > 0) {
      trow++;
      printf("\n") > ofile
      trow++;
      printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "infra net device MB/s & packets Kp/s", "infra procs") > ofile;
      trow++;
      devs = netdev_lns[1];
      printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, 2+(4*devs), 1) > ofile;
      printf("epoch\tts") > ofile
      j = 0;
      for(i=1; i <= devs; i++) {
        dv = netdev_data[1,i,"device"];
        printf("\tMB/s read %s", dv) > ofile;
        vsum[++j] = 0.0;
        vnum[j] = 0;
        printf("\tpkts_read Kp/s %s", dv) > ofile;
        vsum[++j] = 0.0;
        vnum[j] = 0;
        printf("\tMB/s write %s", dv) > ofile;
        vsum[++j] = 0.0;
        vnum[j] = 0;
        printf("\tpkts_write Kp/s %s", dv) > ofile;
        vsum[++j] = 0.0;
        vnum[j] = 0;
      }
      printf("\n") > ofile;
      trow++;
      j=0;
      for(k=2; k <= netdev_mx; k++) {
        printf("%s\t%d", netdev_dt[k], netdev_dt[k]-netdev_dt[1]) > ofile;
        tm_diff = netdev_dt[k]-netdev_dt[k-1];
        if (tm_diff == 0.0) {
#abcd
          printf("got tm_diff= 0 at script= %s, k= %d netdev_dt[k]= %f netdev_dt[k-1]= %f filename= %s cur_dir= %s\n", script_nm, k, netdev_dt[k], netdev_dt[k-1], ARGV[ARGIND], cur_dir);
          exit(1);
        }
        for(i=1; i <= devs; i++) {
          fld = "bytes_rd";
          diff = (netdev_data[k,i,fld]-netdev_data[k-1,i,fld])/(1024.0*1024.0);
          val = diff / tm_diff;
          ck_netdev_max_val(val, i, fld);
          vsum[++j] += val;
          vnum[j]++;
          printf("\t%.3f", val) > ofile;
          fld = "packets_rd";
          diff = (netdev_data[k,i,fld]-netdev_data[k-1,i,fld])/1024.0;
          val = diff / tm_diff;
          ck_netdev_max_val(val, i, fld);
          vsum[++j] += val;
          vnum[j]++;
          printf("\t%.3f", val) > ofile;
          fld = "bytes_wr";
          diff = (netdev_data[k,i,fld]-netdev_data[k-1,i,fld])/(1024.0*1024.0);
          val = diff / tm_diff;
          ck_netdev_max_val(val, i, fld);
          vsum[++j] += val;
          vnum[j]++;
          printf("\t%.3f", val) > ofile;
          fld = "packets_wr";
          diff = (netdev_data[k,i,fld]-netdev_data[k-1,i,fld])/1024.0;
          val = diff / tm_diff;
          ck_netdev_max_val(val, i, fld);
          vsum[++j] += val;
          vnum[j]++;
          printf("\t%.3f", val) > ofile;
        }
        printf("\n") > ofile;
        trow++;
      }
      trow++;
      printf("\n") > ofile;
      if (sum_file != "") {
         scl  = 1024.0*1024.0;
         scl2 = 1024.0;
         for(i=1; i <= devs; i++) {
          fld = "bytes_rd";
          do_netdev_print("infra_procs\tnet stats\t%.3f\tMB/s read %s", i, fld, netdev_mx, 1, scl);
          fld = "packets_rd";
          do_netdev_print("infra_procs\tnet stats\t%.3f\tpackets Kpkts/s read %s", i, fld, netdev_mx, 1, scl2);
          #printf("infra_procs\tnet stats\t%.3f\tpackets Kpkts/s read %s\n", v, netdev_data[1,i,"device"]) > sum_file;
          fld = "bytes_wr";
          do_netdev_print("infra_procs\tnet stats\t%.3f\tMB/s write %s", i, fld, netdev_mx, 1, scl);
          #printf("infra_procs\tnet stats\t%.3f\tMB/s write %s\n", v, netdev_data[1,i,"device"]) > sum_file;
          fld = "packets_wr";
          do_netdev_print("infra_procs\tnet stats\t%.3f\tpackets/s Kpkts/s write %s", i, fld, netdev_mx, 1, scl2);
         }
      }
    }
    printf("_________ diskstats_mx= %d\n", diskstats_mx);
    if (diskstats_mx > 0) {
      if (1 == 2) {
      trow++;
      compute_diskstats(1,0, 1);
      printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "infra disk total IO stats", "infra procs") > ofile;
      trow++;
      devs = diskstats_lns[1];
      printf("diskstats devs= %s\n", devs);
      cols = diskstats_hdrs_mx;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, 2+cols, 1) > ofile;
      printf("epoch\tts") > ofile
      for(i=2; i <= cols; i++) {
         printf("\t%s", diskstats_hdrs[i]) > ofile;
         for (j=1; j <= devs; j++) {
           max_arr[j,i] = 0.0;
         }
      }
      printf("\n") > ofile;
      trow++;
      for(k=2; k <= diskstats_mx; k++) {
        compute_diskstats(k,k-1, 1);
        printf("%s\t%d", diskstats_dt[k], diskstats_dt[k]-diskstats_dt[1]) > ofile;
        tm_diff = diskstats_dt[k]-diskstats_dt[k-1];
        for(i=2; i <= cols; i++) {
          val = diskstats_vals[i];
          if (options_get_max_val == 1) {
             max_arr[i] = 0.0;
          }
          printf("\t%.3f", val) > ofile;
        }
        printf("\n") > ofile;
        trow++;
      }
      trow++;
      printf("\n") > ofile;
      }
      compute_diskstats(1,0, 1);
      devs = diskstats_lns[1];
      for (i=1; i <= devs; i++) {
        dev = diskstats_data[1,i,"device"];
      trow++;
      printf("title\t%s %s\tsheet\t%s\ttype\tscatter_straight\n", "infra disk IO stats device", dev, "infra procs") > ofile;
      trow++;
      cols = diskstats_hdrs_mx;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, 2+(cols), 1) > ofile;
      printf("epoch\tts") > ofile
         for(j=2; j <= cols; j++) {
           printf("\t%s %s", diskstats_hdrs[j],  diskstats_data[1,i,"device"]) > ofile;
           max_arr[i,j] = 0.0;
         }
      printf("\n") > ofile;
      trow++;
      for(k=2; k <= diskstats_mx; k++) {
        dev = diskstats_data[1,i,"device"];
        compute_diskstats(k,k-1, i);
        printf("%s\t%d", diskstats_dt[k], diskstats_dt[k]-diskstats_dt[1]) > ofile;
        for(j=2; j <= cols; j++) {
          val = diskstats_vals[j];
          ck_diskstats_max_val(val, i, j);
          printf("\t%.3f", val) > ofile;
        }
        printf("\n") > ofile;
        trow++;
      }
      trow++;
      printf("\n") > ofile;
      }
      for (i=1; i <= devs; i++) {
        prt_diskstats(i, cols);
        if (1==2) {
        compute_diskstats(diskstats_mx,1, i);
        dev = diskstats_data[1,i,"device"];
        for (k=2; k <= cols; k++) {
          v = diskstats_vals[k];
          printf("infra_procs\tIO stats\t%.4f\t%s %s\n", v, diskstats_hdrs[k], dev) > sum_file;
          if (options_get_max_val == 1) {
              v = diskstats_max[i,k];
              printf("infra_procs\tIO stats\t%.4f\t%s %s peak\n", v, diskstats_hdrs[k], dev) > sum_file;
          }
        }
        }
      }
      if (1==2) {
      if (sum_file != "") {
         for(i=1; i <= devs; i++) {
          tm_diff = diskstats_dt[diskstats_mx]-diskstats_dt[1];
          MB_diff = 1.0e-6 * (diskstats_data[diskstats_mx,i,"total_bytes"]-diskstats_data[1,i,"total_bytes"]);
          v = MB_diff / tm_diff;
           #v = 0.0;
           #if (vnum[i] > 0) {
           #  v = vsum[i]/vnum[i];
           #}
           printf("infra_procs\tIO stats\t%.3f\tIO MBs/sec %s\n", v, diskstats_data[1,i,"device"]) > sum_file;
         }
      }

      trow++;
      printf("\n") > ofile;
      trow++;
      printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "infra disk IOPS", "infra procs") > ofile;
      trow++;
      devs = diskstats_lns[1];
      printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, 2+(3*devs), 1) > ofile;
      printf("epoch\tts") > ofile
      j = 0;
      for(i=1; i <= devs; i++) {
        printf("\ttot_iops %s", diskstats_data[1,i,"device"]) > ofile;
        vsum[++j] = 0.0;
        vnum[j] = 0;
        printf("\trd_iops %s", diskstats_data[1,i,"device"]) > ofile;
        vsum[++j] = 0.0;
        vnum[j] = 0;
        printf("\twr_iops %s", diskstats_data[1,i,"device"]) > ofile;
        vsum[++j] = 0.0;
        vnum[j] = 0;
      }
      printf("\n") > ofile;
      trow++;
      j=0;
      for(k=2; k <= diskstats_mx; k++) {
        printf("%s\t%d", diskstats_dt[k], diskstats_dt[k]-diskstats_dt[1]) > ofile;
        tm_diff = diskstats_dt[k]-diskstats_dt[k-1];
        for(i=1; i <= devs; i++) {
          IOS_diff = 1.0e-6 * (diskstats_data[k,i,"total_ios"]-diskstats_data[k-1,i,"total_ios"]);
          val = IOS_diff / tm_diff;
          vsum[++j] += val;
          vnum[j]++;
          printf("\t%.3f", val) > ofile;
          IOS_diff = (diskstats_data[k,i,"total_ios_rd"]-diskstats_data[k-1,i,"total_ios_rd"]);
          val = IOS_diff / tm_diff;
          vsum[++j] += val;
          vnum[j]++;
          printf("\t%.3f", val) > ofile;
          IOS_diff = (diskstats_data[k,i,"total_ios_wr"]-diskstats_data[k-1,i,"total_ios_wr"]);
          val = IOS_diff / tm_diff;
          vsum[++j] += val;
          vnum[j]++;
          printf("\t%.3f", val) > ofile;
        }
        printf("\n") > ofile;
        trow++;
      }
      trow++;
      printf("\n") > ofile;
      if (sum_file != "") {
         for(i=1; i <= devs; i++) {
          tm_diff = diskstats_dt[diskstats_mx]-diskstats_dt[1];
          IOS_diff = 1.0e-6 * (diskstats_data[diskstats_mx,i,"total_ios"]-diskstats_data[1,i,"total_ios"]);
          v = IOS_diff / tm_diff;
          printf("infra_procs\tIO stats\t%.3f\tIOPS %s\n", v, diskstats_data[1,i,"device"]) > sum_file;
          IOS_diff = 1.0e-6 * (diskstats_data[diskstats_mx,i,"total_ios_rd"]-diskstats_data[1,i,"total_ios_rd"]);
          v = IOS_diff / tm_diff;
          printf("infra_procs\tIO stats\t%.3f\tIOPS read %s\n", v, diskstats_data[1,i,"device"]) > sum_file;
          IOS_diff = 1.0e-6 * (diskstats_data[diskstats_mx,i,"total_ios_wr"]-diskstats_data[1,i,"total_ios_wr"]);
          v = IOS_diff / tm_diff;
          printf("infra_procs\tIO stats\t%.3f\tIOPS write %s\n", v, diskstats_data[1,i,"device"]) > sum_file;
         }
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
        if (tot[j] == 0) { continue; }
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
        if (tot[j] == 0) { continue; }
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
          if (tot[j] == 0) { continue; }
          avg = 0.0;
          if (rss_n[j] > 0) {
            avg = rss_sum[j]/rss_n[j];
          }
          printf("infra_procs\trss avg MBs\t%.3f\t%s\n", avg/1024.0, proc_lkup[j]) > sum_file;
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
        if (tot[j] == 0) { continue; }
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
          if (tot[j] == 0) { continue; }
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
          if (tot[j] == 0) { continue; }
          avg = 0.0;
          if (rss_n[j] > 0) {
            avg = vsz_sum[j]/vsz_n[j];
          }
          printf("infra_procs\tvsz avg MBs\t%.3f\t%s\n", avg/1024.0, proc_lkup[j]) > sum_file;
         }
      }
    }
    if (proc_mx > 0) {
    if ( use_top_pct_cpu == 0) {
      str = "top infra procs cpus (1=1cpu_busy)";
      str2 = "cpu_secs";
    } else {
      str = "top infra procs avg %cpus (100=1cpu_busy)";
      str2 = "%cpu";
    }
    trow++;
    printf("title\t%s\tsheet\t%s\ttype\tcolumn\n", str, "infra procs") > ofile;
    trow++;
    printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 0, -1, proc_mx-2, proc_mx) > ofile;
    for(i=1; i <= proc_mx; i++) {
      j = res_i[i];
      if (tot[j] == 0) { continue; }
      if (j == idle_i) {
        continue;
      }
      printf("%s\t", proc_lkup[j]) > ofile;
    }
    printf("%%cpus\n") > ofile;
    trow++;
    for(i=1; i <= proc_mx; i++) {
      j = res_i[i];
      if (tot[j] == 0) { continue; }
      v = tot[j];
      fctr = 1.0;
      if ( use_top_pct_cpu == 1) {
        fctr = 100.0;
      }
      v = v * fctr;
      if (j == idle_i) {
        continue;
      }
      printf("%.3f\t", v) > ofile;
    }
    trow++;
    printf("%%cpus\n") > ofile;
    if ( use_top_pct_cpu == 0) {
      str = "top infra procs max cpus (1=1cpu_busy)";
      str2 = "cpu_secs";
    } else {
      str = "top infra procs max %cpus (100=1cpu_busy)";
      str2 = "%cpu";
    }
    trow++;
    printf("\n") > ofile;
    trow++;
    printf("title\t%s\tsheet\t%s\ttype\tcolumn\n", str, "infra procs") > ofile;
    trow++;
    printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 0, -1, proc_mx-2, proc_mx) > ofile;
    for(i=1; i <= proc_mx; i++) {
      j = res_i[i];
      if (tot[j] == 0) { continue; }
      if (j == idle_i) {
        continue;
      }
      printf("%s\t", proc_lkup[j]) > ofile;
    }
    printf("%%cpus\n") > ofile;
    trow++;
    for(i=1; i <= proc_mx; i++) {
      j = res_i[i];
      if (tot[j] == 0) { continue; }
      v = sv_max[j];
      if (j == idle_i) {
        continue;
      }
      printf("%.3f\t", v) > ofile;
    #  if (sum_file != "") {
    #     if ( use_top_pct_cpu == 0) {
    #       printf("infra_procs\tinfra procs max cpus\t%.3f\t%s\n", v, proc_lkup[j]) > sum_file;
    #     } else {
    #       # v = 100.0 * sv_max[j];
    #       printf("infra_procs\tinfra procs max %%cpu\t%.3f\t%s\n", v, proc_lkup[j]) > sum_file;
    #     }
    #  }
    }
    printf("%%cpus\n") > ofile;
    trow++;
    }
    if (sum_file != "") {
      close(sum_file);
    }
    printf("%s got to end rc= %s\n", script_nm, rc);
    printf("%s got to end rc= %s\n", script_nm, rc) > "/dev/stderr";
    close(ofile);
    exit(0);
  }
  ' $IN_FL > $my_tmp_output_file
  RC=$?
  ck_last_rc $RC $LINENO
exit $RC

