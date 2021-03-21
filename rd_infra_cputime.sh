#!/bin/bash

#arg1 is infra_cputime.txt filename
VERBOSE=0

while getopts "hvf:m:n:o:O:S:" opt; do
  case ${opt} in
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
  OUT_FL="${IN_FL}.tsv"
fi
#NUM_CPUS=$2
#PID RSS    VSZ     TIME COMMAND
CUR_DIR=`pwd`

awk -v script_nm="$0.$LINENO.awk" -v mutt_ofile="$MUTT_OUT_FL" -v cur_dir="$CUR_DIR" -v options="$OPTIONS" -v num_cpus="$NUM_CPUS" -v sum_file="$SUM_FILE" -v ofile="$OUT_FL" '
  BEGIN {
   num_cpus += 0;
   col_pid = -1;
   col_rss = -1;
   col_vsz = -1;
   col_tm  = -1;
   col_cmd = -1;
   muttley_use_nm = "host.calls";
   use_top_pct_cpu = 0;
   if (index(options, "%cpu_like_top") > 0) {
     use_top_pct_cpu = 1;
   }
   options_get_max_val = 0;
   if (index(options, "get_max_val") > 0) {
     options_get_max_val = 1;
   }
   printf("use_top_pct_cpu= %d, options= \"%s\"\n", use_top_pct_cpu, options) > "/dev/stderr";
   plst[1] = "ksoftirqd/";
   plst[2] = "cpuhp/";
   plst[3] = "watchdog/";
   plst[4] = "migration/";
   plst[5] = "ksoftirqd/";
   plst[6] = "cpuhp/";
   plst[7] = "kworker/";
   plst[8] = "ksoftirqd/";
   plst_mx = 8;
  }
function get_max(a, b) {
  if (a > b) {
    return a;
  };
  return b;
}
function ck_netdev_max_val(val, i, fld,    my_n) {
  if (netdev_max[i,fld,"peak"] == "" || netdev_max[i,fld,"peak"] < val) {
     netdev_max[i,fld,"peak"] = val;
  }
  if (val != "") {
    my_n = ++netdev_max[i,fld,"val_n"];
    netdev_max[i,fld,"val_arr",my_n] = val;
  }
  netdev_max[i,fld,"sum_sq"] += val*val;
  netdev_max[i,fld,"sum"] += val;
  netdev_max[i,fld,"n"]++;
}
function ck_diskstats_max_val(val, i, j,    my_n) {
  # v = diskstats_max[i,k];
  if (diskstats_max[i,j,"peak"] == "" || diskstats_max[i,j,"peak"] < val) {
    diskstats_max[i,j,"peak"] = val;
  }
  if (val != "") {
    diskstats_max[i,j,"val_n"]++;
    my_n = diskstats_max[i,j,"val_n"];
    diskstats_max[i,j,"val_arr",my_n] = val;
  }
  diskstats_max[i,j,"sum_sq"] += val*val;
  diskstats_max[i,j,"sum"] += val;
  diskstats_max[i,j,"n"]++;
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
       printf(fmt_str "\n", mtrcm1, v, hdr, dev) >> sum_file;
       my_n     = diskstats_max[i,k,"n"];
       #printf(fmt_str"\n", v, hdr, dev) >> sum_file;
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
       printf(fmt_str" avg\n", mtrcm1, my_avg, hdr, dev) >> sum_file;
       printf(fmt_str" peak\n", mtrcm1, my_peak, hdr, dev) >> sum_file;
        delete arr_in;
        delete res_i;
        delete idx;
        n = diskstats_max[i,k,"val_n"];
        my_n     = n;
        for(j=1; j <= n; j++) {
          idx[j] = j;
          arr_in[j] = diskstats_max[i,k,"val_arr",j];
        }
        asorti(idx, res_i, "arr_in_compare");
        printf("%s\t%s\t%f\t%s val_arr", grp, mtrcm1, my_n, mtrc) >> sum_file;
        for(j=1; j <= n; j++) {
          printf("\t%f", arr_in[res_i[j]]) >> sum_file;
        }
        printf("\n") >> sum_file;
        # https://www.dummies.com/education/math/statistics/how-to-calculate-percentiles-in-statistics/
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
        printf("++++++++____________++++++++++++ io %s %s my_y= %d\n", mtrcm1, mtrc, my_n) > "/dev/stderr";
        for (kk=1; kk <= px_mx; kk++) {
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
          str = mtrc " p" px[kk] " ";
          printf("%s\t%s\t%f\t%s\n", grp, mtrcm1, uval, str) >> sum_file;
          printf("%s\t%s\t%f\t%s\n", grp, mtrcm1, uval, str) > "/dev/stderr";
        }
        }
    }
    #v = diskstats_max[i,k];
    #printf("infra_procs\tIO stats\t%.4f\t%s %s peak\n", v, diskstats_hdrs[k], dev) >> sum_file;
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
   printf(fmt_str"\n", v, dev) >> sum_file;
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
   printf(fmt_str" avg+3stdev\n", my_p997, dev) >> sum_file;
   printf(fmt_str" peak\n", my_peak, dev) >> sum_file;
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
        printf("%s\t%s\t%f\t%s %s val_arr", grp, mtrcm1, my_n, mtrc, dev) >> sum_file;
        for(j=1; j <= n; j++) {
          printf("\t%f", arr_in[res_i[j]]) >> sum_file;
        }
        printf("\n") >> sum_file;
        # https://www.dummies.com/education/math/statistics/how-to-calculate-percentiles-in-statistics/
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
          printf("infra_procs\t%s\t%s\t%s %s\n", mtrcm1, my_sum, str, dev) >> sum_file;
        }
        if (1==2) {
        printf("++++++++____________++++++++++++ io %s %s my_y= %d\n", mtrcm1, mtrc, my_n) > "/dev/stderr";
        for (kk=1; kk <= px_mx; kk++) {
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
          str = mtrc " p" px[kk] " ";
          printf("infra_procs\t%s\t%f\t%s %s\n", mtrcm1, uval, str, dev) >> sum_file;
          printf("infra_procs\t%s\t%f\t%s %s\n", mtrcm1, uval, str, dev) > "/dev/stderr";
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
#__net_dev__ 1613325090 1613361090
#Inter-|   Receive                                                |  Transmit
# face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
#    lo: 23718376346263 49951651466    0    0    0     0          0         0 23718376346263 49951651466    0    0    0     0       0          0
#  eth1:       0       0    0    0    0     0          0         0        0       0    0    0    0     0       0          0
#docker0:       0       0    0    0    0     0          0         0        0       0    0    0    0     0       0          0
#  eth0: 1789224819997486 3969195799626   14    0    0    14          0  24714218 2735699337437607 4819718487079    0    0    0     0       0          0
  /^__net_dev__ /{
    i = 0;
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
        if (i == 1) { continue; }
        if (i == 2) {
            if ($1 != "face") { printf("%s expected \"face\" as 1st word of 2nd net_dev line, got= %s\n", script_nm, $1); exit 1;}
              #printf(".0= %s\nFS= %s\n", $0, FS) > "/dev/stderr";
            gsub(/\|/, " ");
              #printf(".0= %s\nFS= %s, NF= %d\n", $0, FS, NF) > "/dev/stderr";
            #n = split($0, arr);
            for (k=1; k <= NF; k++) {
              arr[k] = $k;
              if(netdev_mx == 1) {printf("fld[%d]= %s\n", k, arr[k]) > "/dev/stderr";}
              if (arr[k] == "bytes") {
                if (rd_bytes_col == 0) {
                  rd_bytes_col = k;
                } else {
                  wr_bytes_col = k;
                  break;
                }
              }
            }
          if(netdev_mx == 1) {printf("=========---------_________ got rd_bytes_col= %d, wr_bytes_col= %d\n", rd_bytes_col, wr_bytes_col) > "/dev/stderr";}
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
      #if ($2  == 0 && $3 != "dm-0") {
      dev = $3;
      dev_len = length(dev);
     

#		if (NF >= 14) {
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
#			if (NF >= 18) {
#				#/* Discard I/O */
#				sdev.dc_ios     = dc_ios;
#				sdev.dc_merges  = dc_merges;
#				sdev.dc_sectors = dc_sec;
#				sdev.dc_ticks   = dc_ticks;
#			}
#
#			if (NF >= 20) {
#				# Flush I/O 
#				sdev.fl_ios     = fl_ios;
#				sdev.fl_ticks   = fl_ticks;
#			}
#		}
#		else if (NF == 7) {
#			#/* Partition without extended statistics */
#			#if (DISPLAY_EXTENDED(flags))
#		#		continue;
#
#			sdev.rd_ios     = rd_ios;
#			sdev.rd_sectors = rd_merges_or_rd_sec;
#			sdev.wr_ios     = rd_sec_or_wr_ios;
#			sdev.wr_sectors = rd_ticks_or_wr_sec;
#		}

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
  /^__muttley__ /{
    ++muttley_mx;
    muttley_dt[muttley_mx] = $2;
    while ( getline  > 0) {
      if ($0 == "" || (length($1) > 2 && substr($1, 1, 2) == "__")) {
        break;
      }
      mutt_nm = $1;
      mutt_num = $2+0;
      if (muttley_use_nm != "" && mutt_nm == muttley_use_nm) {
        if (!(mutt_nm in mutt_list)) {
           mutt_list[mutt_nm] = ++mutt_mx;
           mutt_lkup[mutt_mx] = mutt_nm;
           mutt_calls_prev[mutt_mx] = mutt_num;
        }
        mutt_i = mutt_list[mutt_nm];
        dff = mutt_num - mutt_calls_prev[mutt_i];
        if (dff < 0) {
           printf("%s: got neg diff= %s for mutt_nm= %s, file= %s, cur_dir= %s, timestamp= %s\n", script_nm, dff, mutt_nm, ARGV[ARGIND], cur_dir, muttley_dt[muttley_mx]) > "/dev/stderr";
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
      }
      mutt_i = mutt_list2[mutt_nm];
      dff = mutt_num - mutt_calls_prev2[mutt_i];
      if (dff < 0) {
         printf("%s: got neg diff= %s for mutt_nm= %s, file= %s, cur_dir= %s, timestamp= %s\n", script_nm, dff, mutt_nm, ARGV[ARGIND], cur_dir, muttley_dt[muttley_mx]) > "/dev/stderr";
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
  END {
    #ofile="tmp.tsv";
    if (idle_mx > 0) {
      elap_tm = sv_uptm[idle_mx]-sv_uptm[1];
      sum = 0.0;
      if (elap_tm == 0.0) {
         printf("skipping infra_file do to idle_mx= %s, arg[1]= %s, cur_dir= %s\n", idle_mx, ARGV[1], cur_dir) > "/dev/stderr";
         exit;
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
      if (tot[j] == 0) { continue; }
      printf("\t%s", proc_lkup[j]) > ofile;
    }
    printf("\n") > ofile;
    trow++;
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
      printf("-------------sum_file= %s, proc_mx= %d\n", sum_file, proc_mx) > "/dev/stderr";
      printf("sum_file= %s\n", sum_file);
      for(i=1; i <= proc_mx; i++) {
         j = res_i[i];
         if (tot[j] == 0) { continue; }
         if ( use_top_pct_cpu == 0) {
           printf("infra_procs\tinfra procs cpus\t%.3f\t%s\n", tot[j], proc_lkup[j]) >> sum_file;
         } else {
           v = 100.0 * tot[j];
           printf("infra_procs\tinfra procs %%cpu\t%.3f\t%s\n", v, proc_lkup[j]) >> sum_file;
         }
      }
      for(i=1; i <= proc_mx; i++) {
         j = res_i[i];
         if (tot[j] == 0) { continue; }
         v = sv_max[j];
         if ( use_top_pct_cpu == 0) {
           printf("infra_procs\tinfra procs max cpus\t%.3f\t%s\n", v, proc_lkup[j]) >> sum_file;
         } else {
           # v = 100.0 * sv_max[j];
           printf("infra_procs\tinfra procs max %%cpu\t%.3f\t%s\n", v, proc_lkup[j]) >> sum_file;
         }
      }
      for (i=1; i <= busy_mx; i++) {
         str = busy_infra_str[i];
         v   = inf_max[i];
         if ( use_top_pct_cpu == 0) {
           printf("infra_procs\tinfra procs max cpus\t%.3f\t%s\n", v, str) >> sum_file;
         } else {
           printf("infra_procs\tinfra procs max %%cpu\t%.3f\t%s\n", v, str) >> sum_file;
         }
      }
      #close(sum_file);
      #printf("%f\n", 1.0/0.0); # force an error
    }
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
      printf("mutt_mx= %d, mutt_other= %d, cols w rps > %.3f = %d\n", mutt_mx, mutt_other, mutt_floor, k) > "/dev/stderr";
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
      printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "muttley calls RPS", "infra procs") > ofile;
      trow++;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 2, -1, 2+use_mutt_mx, 1) > ofile;
      #printf("net_mx= %d\n", net_mx);
      cols = 3
      printf("epoch\tts") > ofile
      for(j=1; j <= mutt_mx; j++) {
          i = mutt_res_i[j];
          if (j == use_mutt_mx && mutt_mx > use_mutt_mx) {
             printf("\t%s", mutt_other_str) > ofile;
             break;
          }
        printf("\t%s", mutt_lkup[i]) > ofile;
      }
      printf("\n") > ofile;
      trow++;
      mutt_host_calls_max = -1
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
         if (1 == 20) {
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
             printf("infra_procs\tmuttley calls avg\t%f\t%s\n", v, "RPS " mutt_other_str) >> sum_file;
             break;
          }
           avg = mutt_calls_tot[i]/tm_diff;
           printf("infra_procs\tmuttley calls avg\t%f\t%s\n", avg, "RPS " mutt_lkup[i]) >> sum_file;
         }
         }
         printf("infra_procs\tmuttley host.calls max\t%f\t%s\n", mutt_host_calls_max, "RPS host.calls max") >> sum_file;
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
      printf("epoch\tts") > mutt_ofile
      for(j=1; j <= mutt_mx2; j++) {
         i = mutt_res_i[j];
         if (mutt_ok[i] != 1) {continue;}
         printf("\t%s", mutt_lkup2[i]) > mutt_ofile;
      }
      printf("\n") > mutt_ofile;
      mutt_host_calls_max = -1
      for(k=2; k <= muttley_mx; k++) {
        printf("%s\t%d", muttley_dt[k], muttley_dt[k]-muttley_dt[1]) > mutt_ofile;
        tm_diff = muttley_dt[k]-muttley_dt[k-1];
        for(j=1; j <= mutt_mx2; j++) {
          i = mutt_res_i[j];
          if (mutt_ok[i] != 1) {continue;}
          if (tm_diff > 0.0) {
            v = mutt_calls2[k,i] / tm_diff;
          } else {
            v = 0.0;
          }
          printf("\t%f", v) > mutt_ofile;
        }
        printf("\n") > mutt_ofile;
      }
      printf("\n") > mutt_ofile;
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
          #printf("infra_procs\tnet stats\t%.3f\tpackets Kpkts/s read %s\n", v, netdev_data[1,i,"device"]) >> sum_file;
          fld = "bytes_wr";
          do_netdev_print("infra_procs\tnet stats\t%.3f\tMB/s write %s", i, fld, netdev_mx, 1, scl);
          #printf("infra_procs\tnet stats\t%.3f\tMB/s write %s\n", v, netdev_data[1,i,"device"]) >> sum_file;
          fld = "packets_wr";
          do_netdev_print("infra_procs\tnet stats\t%.3f\tpackets/s Kpkts/s write %s", i, fld, netdev_mx, 1, scl2);
         }
      }
    }
    if (diskstats_mx > 0) {
      if (1 == 2) {
      trow++;
      compute_diskstats(1,0, 1);
      printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "infra disk total IO stats", "infra procs") > ofile;
      trow++;
      devs = diskstats_lns[1];
      printf("diskstats devs= %s\n", devs) > "/dev/stderr";
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
          printf("infra_procs\tIO stats\t%.4f\t%s %s\n", v, diskstats_hdrs[k], dev) >> sum_file;
          if (options_get_max_val == 1) {
              v = diskstats_max[i,k];
              printf("infra_procs\tIO stats\t%.4f\t%s %s peak\n", v, diskstats_hdrs[k], dev) >> sum_file;
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
           printf("infra_procs\tIO stats\t%.3f\tIO MBs/sec %s\n", v, diskstats_data[1,i,"device"]) >> sum_file;
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
          printf("infra_procs\tIO stats\t%.3f\tIOPS %s\n", v, diskstats_data[1,i,"device"]) >> sum_file;
          IOS_diff = 1.0e-6 * (diskstats_data[diskstats_mx,i,"total_ios_rd"]-diskstats_data[1,i,"total_ios_rd"]);
          v = IOS_diff / tm_diff;
          printf("infra_procs\tIO stats\t%.3f\tIOPS read %s\n", v, diskstats_data[1,i,"device"]) >> sum_file;
          IOS_diff = 1.0e-6 * (diskstats_data[diskstats_mx,i,"total_ios_wr"]-diskstats_data[1,i,"total_ios_wr"]);
          v = IOS_diff / tm_diff;
          printf("infra_procs\tIO stats\t%.3f\tIOPS write %s\n", v, diskstats_data[1,i,"device"]) >> sum_file;
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
          printf("infra_procs\tvsz avg MBs\t%.3f\t%s\n", avg/1024.0, proc_lkup[j]) >> sum_file;
         }
      }
    }
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
    printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 0, -1, proc_mx-1, proc_mx) > ofile;
    for(i=1; i <= proc_mx; i++) {
      j = res_i[i];
      if (tot[j] == 0) { continue; }
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
    printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", trow+1, 0, -1, proc_mx-1, proc_mx) > ofile;
    for(i=1; i <= proc_mx; i++) {
      j = res_i[i];
      if (tot[j] == 0) { continue; }
      printf("%s\t", proc_lkup[j]) > ofile;
    }
    printf("%%cpus\n") > ofile;
    trow++;
    for(i=1; i <= proc_mx; i++) {
      j = res_i[i];
      if (tot[j] == 0) { continue; }
      v = sv_max[j];
      printf("%.3f\t", v) > ofile;
    #  if (sum_file != "") {
    #     if ( use_top_pct_cpu == 0) {
    #       printf("infra_procs\tinfra procs max cpus\t%.3f\t%s\n", v, proc_lkup[j]) >> sum_file;
    #     } else {
    #       # v = 100.0 * sv_max[j];
    #       printf("infra_procs\tinfra procs max %%cpu\t%.3f\t%s\n", v, proc_lkup[j]) >> sum_file;
    #     }
    #  }
    }
    printf("%%cpus\n") > ofile;
    trow++;
    if (sum_file != "") {
      close(sum_file);
    }
  }
  ' $IN_FL
  RC=$?
exit $RC

