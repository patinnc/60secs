#!/bin/bash

# ./sys_2_tsv.sh -d some_dir_with_files_created_by_60secs_sh
# 60secs.sh creates the sys_*.txt files which are read by sys_2_tsv.sh and.
# sys_2_tsv.sh then creates sys_*.txt.tsv files.
# '-d dir' is expected to have file sys_00_uptime.txt sys_01_dmesg.txt sys_02_vmstat.txt sys_03_mpstat.txt sys_04_pidstat.txt sys_05_iostat.txt sys_06_free.txt sys_07_sar_dev.txt sys_08_sar_tcp.txt sys_09_top.txt sys_10_perf_stat.txt
# and output files in the are sys_00_uptime.txt.tsv sys_01_dmesg.txt.tsv sys_02_vmstat.txt.tsv sys_03_mpstat.txt.tsv sys_04_pidstat.txt.tsv sys_05_iostat.txt.tsv sys_06_free.txt.tsv sys_07_sar_dev.txt.tsv sys_08_sar_tcp.txt.tsv sys_09_top.txt.tsv sys_10_perf_stat.txt.tsv
#
DIR=
SHEETS=
SCR_DIR=`dirname $0`

while getopts "hd:vm:p:r:s:t:" opt; do
  case ${opt} in
    d )
      DIR=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 split data files into columns"
      echo "Usage: $0 [-h] -d sys_data_dir [-v]"
      echo "   -d dir containing sys_XX_* files created by 60secs.sh"
      echo "   -v verbose mode"
      exit
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

if [ "$DIR" == "" ]; then
  echo "you must enter a dir '-d dir_path' containing sys_*_*.txt files created by 60secs.sh"
  exit
fi
if [ ! -d $DIR ]; then
  echo "didn't find dir $DIR"
  exit
fi
echo "dir= $DIR"

FILES=`ls -1 $DIR/sys_*_*.txt`
#echo "FILES = $FILES"
for i in $FILES; do
 echo $i
  if [[ $i == *"_uptime.txt"* ]]; then
    echo "do uptime"
    awk '
      BEGIN{beg=1;mx=0}
      function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
      function rtrim(s) { sub(/[ \t\r\n,]+$/, "", s); return s }
      function trim(s) { return rtrim(ltrim(s)); }
#title	mpstat cpu= all
#hdrs	2	1	62	10
#CPU	%usr	%nice	%sys	%iowait	%irq	%soft	%steal	%guest	%gnice	%idle
#all	10.66	10.44	3.84	0.22	0.00	0.13	0.00	0.00	0.00	74.72

      /load average/ {
	FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        n = split($0, arr, /[ ,]/);
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
       printf("title\tuptime\tsheet\tuptime\ttype\tline\n") > NFL;
       printf("hdrs\t2\t0\t%d\t2\n", mx+1) > NFL;
       for (i=1; i <= mx; i++) {
          printf("%s\n", sv[i]) > NFL;
       }
       close(NFL);
     }
   ' $i
   SHEETS="$SHEETS $i.tsv"
  fi
  if [[ $i == *"_vmstat.txt"* ]]; then
    echo "do vmstat"
#procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
# r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
# 4  0      0 1329084 842316 44802156    0    0    51    37    0    0 16  2 81  0  0
# 4  0      0 1319472 842316 44802156    0    0     0    12 20779 58660 14  1 85  0  0
# 2  0      0 1384300 842320 44802160    0    0     0   356 17266 81860 11  1 88  0  0

    awk '
     BEGIN{beg=1;col_mx=-1;mx=0}
     /^procs/{
       next;
     }
     {
	FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
     }
     /swpd/{
        if (beg == 0) { next; }
        beg = 0;
        for (i=1; i <= NF; i++) {
         hdrs[i]=$i;
        }
        tab="";
        hdr="";
        for (i=1; i <= NF; i++) {
          col_mx++;
          hdr=hdr "" sprintf("%s%s", tab, hdrs[i]);
          tab="\t";
        }
        sv[++mx]=hdr;
        #printf("\n") > NFL;
        next;
     }
     {
        tab="";
        ln="";
        for (i=1; i <= NF; i++) {
          ln=ln "" sprintf("%s%s", tab, $i);
          tab="\t";
        }
        sv[++mx]=ln;
        #printf("\n") > NFL;
     }
     END{
       printf("title\tvmstat\tsheet\tvmstat\ttype\tline\n") > NFL;
       printf("hdrs\t2\t0\t%d\t%d\n", mx+1, col_mx) > NFL;
       for (i=1; i <= mx; i++) {
          printf("%s\n", sv[i]) > NFL;
       }
       close(NFL);}
   ' $i
   SHEETS="$SHEETS $i.tsv"
  fi
  if [[ $i == *"_mpstat.txt"* ]]; then
    echo "do mpstat"
#Linux 4.14.131 (agent-dedicated1812-phx2) 	01/21/2020 	_x86_64_	(32 CPU)
#12:01:01 AM  CPU    %usr   %nice    %sys %iowait    %irq   %soft  %steal  %guest  %gnice   %idle
#12:01:02 AM  all   10.66   10.44    3.84    0.22    0.00    0.13    0.00    0.00    0.00   74.72
#12:01:02 AM    0   10.10    4.04    2.02    0.00    0.00    0.00    0.00    0.00    0.00   83.84
#12:01:02 AM    1    1.03    6.19    2.06    0.00    0.00    0.00    0.00    0.00    0.00   90.72

    awk '
     BEGIN{beg=1;
        grp_mx=0;
        hdr_mx=0;
      }
     /^Linux/{
       next;
     }
     {
	FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
        if (NF==0) { next; }
     }
     /%idle/{
        if (beg == 0) { next; }
        beg = 0;
        for (i=3; i <= NF; i++) {
         hdrs[++hdr_mx]=$i;
        }
        next;
     }
     {
        grp=$3;
        if (index($0, "Average") == 1) {
		next;
	}
        if (grps[grp] == "") {
          grps[grp] = ++grp_mx;
          grp_nm[grp_mx] = grp;
          printf("grps[%s]= %d\n", grp, grp_mx);
          grp_row[grp_mx] = 0;
        }
        g = grps[grp];
        rw = ++grp_row[g];
        j=0;
        for (i=3; i <= NF; i++) {
          grp_list[g,rw,++j] = $i;
        }
        grp_col[g] = j;
        
     }
     END{
        #printf("grp_mx= %d\n", grp_mx) > NFL;
        row=-1;
	for (g=1; g <= grp_mx; g++) {
          row++;
          printf("title\tmpstat cpu= %s\tsheet\tmpstat\ttype\tline\n", grp_nm[g]) > NFL;
          row++;
          printf("hdrs\t%d\t%d\t%d\t%d\n", row+1, 1, 1+row+grp_row[g], hdr_mx-1) > NFL;
          tab="";
          for (i=1; i <= hdr_mx; i++) {
            printf("%s%s", tab, hdrs[i]) > NFL;
            tab="\t";
          }
           row++;
          printf("\n") > NFL;
          for (r=1; r <= grp_row[g]; r++) {
            tab="";
            for (c=1; c <= hdr_mx; c++) {
              printf("%s%s", tab, grp_list[g,r,c]) > NFL;
              tab="\t";
            }
            row++;
            printf("\n") > NFL;
          }
          row++;
          printf("\n") > NFL;
        }
       close(NFL);
     }
   ' $i
   SHEETS="$SHEETS $i.tsv"
  fi
  if [[ $i == *"_pidstat.txt"* ]]; then
    echo "do pidstat"
#Average:      UID       PID    %usr %system  %guest    %CPU   CPU  Command
#Average:        0         1    0.32    0.37    0.00    0.68     -  systemd
#Average:        0         2    0.00    0.02    0.00    0.02     -  kthreadd
#Average:        0         8    0.00    0.05    0.00    0.05     -  ksoftirqd/0
#Average:        0         9    0.00    0.17    0.00    0.17     -  rcu_sched
#
#Average:      UID       PID   cswch/s nvcswch/s  Command
#Average:        0         1     11.16      0.00  systemd
#Average:        0         2      0.05      0.00  kthreadd
#
#Average:      UID       PID threads   fd-nr  Command
#Average:        0     38184      64      70  collector
#Average:      112     43282      17      80  muttley-active
#Average:    100001     51570      18     776  m3collector
    awk -v typ="pidstat" '
     BEGIN{beg=1;
        grp_mx=0;
        hdr_mx=0;
        chart=typ;
      }
      function bar_data(row, arr_in, arr_mx, title, hdr, mx_lines) {
       srt_lst="";
       for (i=2; i <= arr_mx; i++) {
           srt_lst=srt_lst "" arr_in[i] "\n";
       }
       #printf("======== beg %s =========\n%s\n======== end %s =========\n", title, srt_lst, title);
       cmd = "printf \"" srt_lst "\" | sort -t '\t' -r -n -k 1";
       #printf("cmd= %s\n", cmd);
       #printf("======== end cmd=========\n");
       nf_mx=0;
       while ( ( cmd | getline result ) > 0 ) {
         sv_nf[++nf_mx] = result;
         printf("sv_nf[%d]= %s\n", nf_mx, result);
         if (nf_mx > mx_lines) {
           break;
         }
       } 
       close(cmd)
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tcolumn\n", title, chart) > NFL;
       ++row;
       n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\n", row+1, 0, 1+row+nf_mx, n-1) > NFL;
       ++row;
       printf("%s\n", hdr) > NFL;
       for (i=1; i <= nf_mx; i++) {
         ++row;
         printf("%s\n", sv_nf[i]) > NFL;
       }
       return row;
     }
     {
        str="";
        tab="";
        for (i=1; i <= NF; i++) {
          str = str "" sprintf("%s%s", tab, $i);
          tab = "\t";
        }
        sv[++sv_mx] = str;
     }
     /^Average:/{
	FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
        if (index($0, "%CPU") > 1) {
          area="cpu"; 
          mx_cpu=1;
          sv_cpu[mx_cpu]=sprintf("%CPU\tProcess");
          next;
        }
        if (index($0, "nvcswch") > 1) {
          area="cs";
          mx_cs=1;
          sv_cs[mx_cs]=sprintf("cswch/s\tnvcswch/s\tProcess");
          next;
        }
        if (index($0, "threads") > 1) {
          area="threads";
          mx_threads=1;
          sv_threads[mx_threads]=sprintf("threads\tfd-nr\tProcess");
          next;
        }
        if (area == "cpu") {
          sv_cpu[++mx_cpu]=sprintf("%s\t%s", $7, $9 " " $3);
        }
        if (area == "cs") {
          sv_cs[++mx_cs]=sprintf("%s\t%s\t%s", $4, $5, $6 " " $3);
        }
        if (area == "threads") {
          sv_threads[++mx_threads]=sprintf("%s\t%s\t%s", $4, $5, $6 " " $3);
        }
     }
     END{
       row = -1;
       row = bar_data(row, sv_cpu, mx_cpu, chart " %CPU", sv_cpu[1], 40);
       ++row;
       printf("\n") > NFL;
       row = bar_data(row, sv_cs, mx_cs, chart " CSWTCH", sv_cs[1], 40);
       ++row;
       printf("\n") > NFL;
       row = bar_data(row, sv_threads, mx_threads, chart " threads, fd", sv_threads[1], 40);
       ++row;
       printf("\n") > NFL;
       for (i=1; i <= sv_mx; i++) {
          printf("%s\n", sv[i]) > NFL;
       }
       close(NFL);
     }
   ' $i
   SHEETS="$SHEETS $i.tsv"
 fi
  if [[ $i == *"_iostat.txt"* ]]; then
#avg-cpu:  %user   %nice %system %iowait  %steal   %idle
#           1.32    3.52    0.76    0.16    0.00   94.24
#
#Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
#sda               0.00     0.00  567.00    0.00  7100.00     0.00    25.04     0.06    0.11    0.11    0.00   0.11   6.00
#dm-0              0.00     0.00  567.00    0.00  7100.00     0.00    25.04     0.06    0.11    0.11    0.00   0.11   6.40

    echo "do iostat"
    awk -v typ="iostat" '
     BEGIN{beg=1;
        grp_mx=0;
        hdr_mx=0;
        chart=typ;
        mx_cpu=0;
        mx_io=0;
        mx_dev=0;
      }
      function line_data(row, arr_in, arr_mx, title, hdr) {
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tline\n", title, chart) > NFL;
       ++row;
       n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\n", row+1, 0, row+arr_mx, n-1) > NFL;
       ++row;
       printf("%s\n", hdr) > NFL;
       for (i=2; i <= arr_mx; i++) {
         ++row;
         printf("%s\n", arr_in[i]) > NFL;
       }
       return row;
     }
     {
        FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
     }
     /^avg-cpu:/{
        if (mx_cpu == 0) {
          mx_cpu=1;
          sv_cpu[mx_cpu]="";
          sv_cpu_cols = NF-1;
          tab=""
          for (i=2; i <= NF; i++) {
            sv_cpu[mx_cpu]=sv_cpu[mx_cpu] "" tab "" $i;
            tab="\t"
          }
        }
        area="cpu"; 
        hdr_NR=NR;
        next;
     }
     /^Device:/{
        if (mx_io == 0) {
          mx_io=1;
          sv_io[mx_io]="";
          sv_io_cols = NF;
          tab = "";
          for (i=1; i <= NF; i++) {
            sv_io[mx_io]=sv_io[mx_io] "" tab "" $i;
            tab="\t"
          }
        }
        area="io"; 
        delete got_dev;
        hdr_NR=NR;
        next;
     }
     {
        if (NF == 0) {
          if (area == "io") {
            # insert zeroes for missing dev
            for (i=1; i <= mx_dev; i++) {
               if (got_dev[i] == 1) { continue; }
               ++mx_io;
               sv_io[mx_io]=dev_lst[i];
               sv_io_dev_ids[mx_io] = dev_lst[i];
               for (j=2; j <= sv_io_cols; j++) {
                 sv_io[mx_io]=sv_io[mx_io] "\t0.0";
               }
            }
          }
          area = "";
          next;
        }
        str="";
        tab="";
        for (i=1; i <= NF; i++) {
          str = str "" sprintf("%s%s", tab, $i);
          tab = "\t";
        }
        if (area == "cpu") {
           sv_cpu[++mx_cpu] = str;
        }
        if (area == "io") {
           if (!($1 in sv_dev)) {
             ++mx_dev;
             dev_lst[mx_dev]=$1;
             sv_dev[$1]=mx_dev;
             printf("dev_lst[%d]= %s\n", mx_dev, $1);
           }
           dev_id = sv_dev[$1];
           got_dev[dev_id] = 1;
           sv_io[++mx_io] = str;
           sv_io_dev_ids[mx_io] = $1;
        }
        sv[++sv_mx] = str;
        next;
     }
     END{
       row = -1;
       row = line_data(row, sv_cpu, mx_cpu, chart " %CPU", sv_cpu[1]);
       ++row;
       printf("\n") > NFL;
       for (ii=1; ii <= mx_dev; ii++) {
          ttl=chart " dev " dev_lst[ii];
          delete narr;
          narr[1] = sv_io[1];
          mx_arr=1;
          for (jj=2; jj <= mx_io; jj++) {
             if (sv_io_dev_ids[jj] == dev_lst[ii]) {
                narr[++mx_arr] = sv_io[jj];
             }
          }
          row = line_data(row, narr, mx_arr, ttl, narr[1]);
          ++row;
          printf("\n") > NFL;
       }
       #row = bar_data(row, sv_threads, mx_threads, chart " threads, fd", sv_threads[1], 40);
       #++row;
       #printf("\n") > NFL;
       for (i=1; i <= sv_mx; i++) {
          printf("%s\n", sv[i]) > NFL;
       }
       close(NFL);
     }
   ' $i
   SHEETS="$SHEETS $i.tsv"
 fi
  if [[ $i == *"_sar_dev.txt"* ]]; then
#12:04:59 AM     IFACE   rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s   %ifutil
#12:05:00 AM      eth1      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
#12:05:00 AM   docker0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
#12:05:00 AM      ifb1      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
#12:05:00 AM      eth0   1047.00   1666.00     87.55   1278.60      0.00      0.00      0.00      0.30
#12:05:00 AM        lo   1251.00   1251.00    259.82    259.82      0.00      0.00      0.00      0.00
#12:05:00 AM      ifb0      0.00      0.00      0.00      0.00      0.00      0.00      0.00      0.00
    echo "do sar_dev"
    awk -v typ="sar network IFACE" '
     BEGIN{beg=1;
        grp_mx=0;
        hdr_mx=0;
        chart=typ;
        mx_cpu=0;
        mx_io=0;
        mx_dev=0;
      }
      function line_data(row, arr_in, arr_mx, title, hdr) {
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tline\n", title, chart) > NFL;
       ++row;
       n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\n", row+1, 0, row+arr_mx, n-1) > NFL;
       ++row;
       printf("%s\n", hdr) > NFL;
       for (i=2; i <= arr_mx; i++) {
         ++row;
         printf("%s\n", arr_in[i]) > NFL;
       }
       return row;
     }
     {
        FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
     }
     /^Average:/ {
        # could make a bar chart of this but...
        next;
     }
     / rxpck\/s /{
        if (mx_io == 0) {
          mx_io=1;
          sv_io[mx_io]="";
          sv_io_cols = NF-2;
          tab = "";
          for (i=3; i <= NF; i++) {
            sv_io[mx_io]=sv_io[mx_io] "" tab "" $i;
            tab="\t"
          }
        }
        area="io"; 
        delete got_dev;
        hdr_NR=NR;
        next;
     }
     {
        if (NF == 0) {
          area = "";
          next;
        }
        str="";
        tab="";
        got_nonzero = 0;
        for (i=3; i <= NF; i++) {
          str = str "" sprintf("%s%s", tab, $i);
          if (($i+0.0) > 0.0) {
             got_nonzero = 1;
          }
          tab = "\t";
        }
        if (area == "io") {
           if (!($3 in sv_dev)) {
             ++mx_dev;
             dev_lst[mx_dev]=$3;
             sv_dev[$3]=mx_dev;
             printf("dev_lst[%d]= %s\n", mx_dev, $3);
             io_nonzero[mx_dev] = 0;
           }
           dev_id = sv_dev[$3];
           got_dev[dev_id] = 1;
           if (io_nonzero[dev_id] == 0 && got_nonzero == 1) {
              io_nonzero[dev_id] = 1;
           }
           sv_io[++mx_io] = str;
           sv_io_dev_ids[mx_io] = $3;
        }
        sv[++sv_mx] = str;
        next;
     }
     END{
       row = -1;
       for (ii=1; ii <= mx_dev; ii++) {
          if (io_nonzero[ii] == 0) {
             ++row;
             printf("data for sar_dev IFACE %s is all zeroes.\n", dev_lst[ii]) > NFL;
             ++row;
             printf("\n") > NFL;
             continue;
          }
          ttl=chart " dev " dev_lst[ii];
          delete narr;
          narr[1] = sv_io[1];
          mx_arr=1;
          for (jj=2; jj <= mx_io; jj++) {
             if (sv_io_dev_ids[jj] == dev_lst[ii]) {
                narr[++mx_arr] = sv_io[jj];
             }
          }
          row = line_data(row, narr, mx_arr, ttl, narr[1]);
          ++row;
          printf("\n") > NFL;
       }
       for (i=1; i <= sv_mx; i++) {
          printf("%s\n", sv[i]) > NFL;
       }
       close(NFL);
     }
   ' $i
   SHEETS="$SHEETS $i.tsv"
 fi
  if [[ $i == *"_sar_tcp.txt"* ]]; then
    echo "do sar_tcp"
    awk -v typ="sar tcp stats" '
     BEGIN{beg=1;
        grp_mx=0;
        hdr_mx=0;
        chart=typ;
        mx_cpu=0;
        mx_io=0;
        mx_io1=0;
        mx_dev=0;
      }
      function line_data(row, arr_in, arr_mx, title, hdr) {
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tline\n", title, chart) > NFL;
       ++row;
       n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\n", row+1, 0, row+arr_mx, n-1) > NFL;
       ++row;
       printf("%s\n", hdr) > NFL;
       for (i=2; i <= arr_mx; i++) {
         ++row;
         printf("%s\n", arr_in[i]) > NFL;
       }
       return row;
     }
     {
        FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
     }
#12:05:59 AM  active/s passive/s    iseg/s    oseg/s
#12:06:00 AM    118.00      2.00   1200.00   1473.00
#
#12:05:59 AM  atmptf/s  estres/s retrans/s isegerr/s   orsts/s
#12:06:00 AM     44.00     14.00      2.00      0.00     93.00
     /^Average:/ {
        # could make a bar chart of this but...
        next;
     }
     /  active\/s /{
        if (mx_io == 0) {
          mx_io=1;
          sv_io[mx_io]="";
          sv_io_cols = NF-2;
          tab = "";
          for (i=3; i <= NF; i++) {
            sv_io[mx_io]=sv_io[mx_io] "" tab "" $i;
            tab="\t"
          }
        }
        sv[++sv_mx] = $0;
        area="io"; 
        next;
     }
     /  atmptf\/s /{
        if (mx_io1 == 0) {
          mx_io1=1;
          sv_io_cols += NF-2;
          tab="\t"
          for (i=3; i <= NF; i++) {
            sv_io[1]=sv_io[1] "" tab "" $i;
          }
        }
        sv[++sv_mx] = $0;
        area="io1"; 
        next;
     }
     {
        if (NF == 0) {
          area = "";
          sv[++sv_mx] = $0;
          next;
        }
        str="";
        tab="";
        if (area=="io1") {
           tab = "\t"; 
           str = sv_io[mx_io];
        }
        for (i=3; i <= NF; i++) {
          str = str "" sprintf("%s%s", tab, $i);
          tab = "\t";
        }
        if (area == "io") {
           sv_io[++mx_io] = str;
        }
        if (area == "io1") {
           sv_io[mx_io] = str;
        }
        sv[++sv_mx] = str;
        next;
     }
     END{
       row = -1;
       ttl=chart " tcp";
       row = line_data(row, sv_io, mx_io, ttl, sv_io[1]);
       ++row;
       printf("\n") > NFL;
       for (i=1; i <= sv_mx; i++) {
          printf("%s\n", sv[i]) > NFL;
       }
       close(NFL);
     }
   ' $i
   SHEETS="$SHEETS $i.tsv"
 fi
  if [[ $i == *"_perf_stat.txt"* ]]; then
    echo "do perf_stat data"
    $SCR_DIR/perf_stat_scatter.sh $i > $i.tsv
   SHEETS="$SHEETS $i.tsv"
 fi
done
if [ "$SHEETS" != "" ]; then
   echo "python $SCR_DIR/tsv_2_xlsx.py $SHEETS"
   python $SCR_DIR/tsv_2_xlsx.py $SHEETS
fi

