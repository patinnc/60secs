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
IMAGE_STR=
XLSX_FILE="chart_line.xlsx"

while getopts "hvd:o:i:x:" opt; do
  case ${opt} in
    d )
      DIR=$OPTARG
      ;;
    i )
      IMAGE_STR=$OPTARG
      ;;
    o )
      OPTIONS=$OPTARG
      ;;
    x )
      XLSX_FILE=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 split data files into columns"
      echo "Usage: $0 [-h] -d sys_data_dir [-v]"
      echo "   -d dir containing sys_XX_* files created by 60secs.sh"
      echo "   -i \"image_file_name_str\" this option is passed to tsv_2_xlsx.py to identify image files to be inserted into the xlsx"
      echo "      For instance '-i \"*.png\"'. Note the dbl quotes around the glob. This keeps the cmdline from expanding the files. python will expand the glob."
      echo "   -o options   currently only '-o dont_sum_sockets' is supported to not sum the perf stat per socket events to the system"
      echo "      this optional option is passed to perf_stat_scatter.sh"
      echo "      default is to sum the per socket events to the system level"
      echo "   -x xlsx_filename  This is passed to tsv_2_xlsx.py as the name of the xlsx. (you need to add the .xlsx)"
      echo "      The default is chart_line.xlsx"
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
trows++; printf("\t$ uptime\n") > NFL;
trows++; printf("\t23:51:26 up 21:31, 1 user, load average: 30.02, 26.43, 19.02\n") > NFL;
trows++; printf("\tThis is a quick way to view the load averages, which indicate the number of tasks (processes) wanting to\n") > NFL;
trows++; printf("\trun. On Linux systems, these numbers include processes wanting to run on CPU, as well as processes\n") > NFL;
trows++; printf("\tblocked in uninterruptible I/O (usually disk I/O). This gives a high level idea of resource load (or demand), but\n") > NFL;
trows++; printf("\tcan\x27t be properly understood without other tools. Worth a quick look only.\n") > NFL;
trows++; printf("\tThe three numbers are exponentially damped moving sum averages with a 1 minute, 5 minute, and 15\n") > NFL;
trows++; printf("\tminute constant. The three numbers give us some idea of how load is changing over time. For example, if\n") > NFL;
trows++; printf("\tyou\x27ve been asked to check a problem server, and the 1 minute value is much lower than the 15 minute\n") > NFL;
trows++; printf("\tvalue, then you might have logged in too late and missed the issue.\n") > NFL;
trows++; printf("\tIn the example above, the load averages show a recent increase, hitting 30 for the 1 minute value, compared\n") > NFL;
trows++; printf("\tto 19 for the 15 minute value. That the numbers are this large means a lot of something: probably CPU\n") > NFL;
trows++; printf("\tdemand; vmstat or mpstat will confirm, which are commands 3 and 4 in this sequence.\n") > NFL;
trows++; printf("\n") > NFL;

       printf("title\tuptime\tsheet\tuptime\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t0\t%d\t2\n", trows+2, trows+mx+1) > NFL;
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
trows=0;
trows++; printf("\tShort for virtual memory stat, vmstat(8) is a commonly available tool (first created for BSD decades ago). It\n") > NFL;
trows++; printf("\tprints a summary of key server statistics on each line.\n") > NFL;
trows++; printf("\tvmstat was run with an argument of 1, to print one second summaries. The first line of output (in this version\n") > NFL;
trows++; printf("\tof vmstat) has some columns that show the average since boot, instead of the previous second. For now,\n") > NFL;
trows++; printf("\tskip the first line, unless you want to learn and remember which column is which.\n") > NFL;
trows++; printf("\tColumns to check:\n") > NFL;
trows++; printf("\tr: Number of processes running on CPU and waiting for a turn. This provides a better signal than\n") > NFL;
trows++; printf("\tload averages for determining CPU saturation, as it does not include I/O. To interpret: an \"r\" value\n") > NFL;
trows++; printf("\tgreater than the CPU count is saturation.\n") > NFL;
trows++; printf("\tfree: Free memory in kilobytes. If there are too many digits to count, you have enough free\n") > NFL;
trows++; printf("\tmemory. The \"free -m\" command, included as command 7, better explains the state of free\n") > NFL;
trows++; printf("\tmemory.\n") > NFL;
trows++; printf("\tsi, so: Swap-ins and swap-outs. If these are non-zero, you\x27re out of memory.\n") > NFL;

trows++; printf("\tus, sy, id, wa, st: These are breakdowns of CPU time, on average across all CPUs. They are\n") > NFL;
trows++; printf("\tuser time, system time (kernel), idle, wait I/O, and stolen time (by other guests, or with Xen, the\n") > NFL;
trows++; printf("\tguest\x27s own isolated driver domain).\n") > NFL;
trows++; printf("\tThe CPU time breakdowns will confirm if the CPUs are busy, by adding user + system time. A constant\n") > NFL;
trows++; printf("\tdegree of wait I/O points to a disk bottleneck; this is where the CPUs are idle, because tasks are blocked\n") > NFL;
trows++; printf("\twaiting for pending disk I/O. You can treat wait I/O as another form of CPU idle, one that gives a clue as to\n") > NFL;
trows++; printf("\twhy they are idle.\n") > NFL;
trows++; printf("\tSystem time is necessary for I/O processing. A high system time average, over 20%, can be interesting to\n") > NFL;
trows++; printf("\texplore further: perhaps the kernel is processing the I/O inefficiently.\n") > NFL;
trows++; printf("\tIn the above example, CPU time is almost entirely in user-level, pointing to application level usage instead.\n") > NFL;
trows++; printf("\tThe CPUs are also well over 90%% utilized on average. This isn\x27t necessarily a problem; check for the degree\n") > NFL;
trows++; printf("\tof saturation using the \"r\" column.\n") > NFL;
trows++; printf("\t\n") > NFL;

       printf("title\tvmstat\tsheet\tvmstat\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t0\t%d\t%d\n", 2+trows, mx+1+trows, col_mx) > NFL;
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
trows++; printf("This command prints CPU time breakdowns per CPU, which can be used to check for an imbalance. A\n") > NFL;
trows++; printf("single hot CPU can be evidence of a single-threaded application.\n") > NFL;
trows++; printf("\n") > NFL;

	for (g=1; g <= grp_mx; g++) {
          row++;
          printf("title\tmpstat cpu= %s\tsheet\tmpstat\ttype\tline\n", grp_nm[g]) > NFL;
          row++;
          printf("hdrs\t%d\t%d\t%d\t%d\n", trows+row+1, 1, trows+1+row+grp_row[g], hdr_mx-1) > NFL;
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
        did_notes=0;
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

trows++; printf("\tpidstat is a little like top\x27s per-process summary, but prints a rolling summary instead of clearing the screen.\n") > NFL;
trows++; printf("\tThis can be useful for watching patterns over time, and also recording what you saw (copy-n-paste) into a\n") > NFL;
trows++; printf("\trecord of your investigation.\n") > NFL;
trows++; printf("\tThe above example identifies two java processes as responsible for consuming CPU. The %%CPU column is\n") > NFL;
trows++; printf("\tthe total across all CPUs; 1591%% shows that that java processes is consuming almost 16 CPUs.\n") > NFL;

       row += trows;

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
trows++; printf("\tThis is a great tool for understanding block devices (disks), both the workload applied and the resulting\n") > NFL;
trows++; printf("\tperformance. Look for:\n") > NFL;
trows++; printf("\tr/s, w/s, rkB/s, wkB/s: These are the delivered reads, writes, read Kbytes, and write Kbytes per\n") > NFL;
trows++; printf("\tsecond to the device. Use these for workload characterization. A performance problem may\n") > NFL;
trows++; printf("\tsimply be due to an excessive load applied.\n") > NFL;
trows++; printf("\tawait: The average time for the I/O in milliseconds. This is the time that the application suffers,\n") > NFL;
trows++; printf("\tas it includes both time queued and time being serviced. Larger than expected average times can\n") > NFL;
trows++; printf("\tbe an indicator of device saturation, or device problems.\n") > NFL;
trows++; printf("\tavgqu-sz: The average number of requests issued to the device. Values greater than 1 can be\n") > NFL;
trows++; printf("\tevidence of saturation (although devices can typically operate on requests in parallel, especially\n") > NFL;
trows++; printf("\tvirtual devices which front multiple back-end disks.)\n") > NFL;
trows++; printf("\t%%util: Device utilization. This is really a busy percent, showing the time each second that the\n") > NFL;
trows++; printf("\tdevice was doing work. Values greater than 60%% typically lead to poor performance (which\n") > NFL;
trows++; printf("\tshould be seen in await), although it depends on the device. Values close to 100%% usually\n") > NFL;
trows++; printf("\tindicate saturation.\n") > NFL;
trows++; printf("\tIf the storage device is a logical disk device fronting many back-end disks, then 100%% utilization may just\n") > NFL;
trows++; printf("\tmean that some I/O is being processed 100%% of the time, however, the back-end disks may be far from\n") > NFL;
trows++; printf("\tsaturated, and may be able to handle much more work.\n") > NFL;
trows++; printf("\tBear in mind that poor performing disk I/O isn\x27t necessarily an application issue. Many techniques are\n") > NFL;
trows++; printf("\ttypically used to perform I/O asynchronously, so that the application doesn\x27t block and suffer the latency\n") > NFL;
trows++; printf("\tdirectly (e.g., read-ahead for reads, and buffering for writes).\n") > NFL;
row += trows;
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
trows++; printf("\tUse this tool to check network interface throughput: rxkB/s and txkB/s, as a measure of workload, and also\n") > NFL;
trows++; printf("\tto check if any limit has been reached. In the above example, eth0 receive is reaching 22 Mbytes/s, which is\n") > NFL;
trows++; printf("\t176 Mbits/sec (well under, say, a 1 Gbit/sec limit).\n") > NFL;
trows++; printf("\tThis version also has %%ifutil for device utilization (max of both directions for full duplex), which is something\n") > NFL;
trows++; printf("\twe also use Brendan\x27s nicstat tool to measure. And like with nicstat, this is hard to get right, and seems to\n") > NFL;
trows++; printf("\tnot be working in this example (0.00).\n") > NFL;
trows++; printf("\t\n") > NFL;
row+= trows;
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
trows++; printf("\tThis is a summarized view of some key TCP metrics. These include:\n") > NFL;
trows++; printf("\tactive/s: Number of locally-initiated TCP connections per second (e.g., via connect()).\n") > NFL;
trows++; printf("\tpassive/s: Number of remotely-initiated TCP connections per second (e.g., via accept()).\n") > NFL;
trows++; printf("\tretrans/s: Number of TCP retransmits per second.\n") > NFL;
trows++; printf("\tThe active and passive counts are often useful as a rough measure of server load: number of new accepted\n") > NFL;
trows++; printf("\tconnections (passive), and number of downstream connections (active). It might help to think of active as\n") > NFL;
trows++; printf("\toutbound, and passive as inbound, but this isn\x27t strictly true (e.g., consider a localhost to localhost\n") > NFL;
trows++; printf("\tconnection).\n") > NFL;
trows++; printf("\tRetransmits are a sign of a network or server issue; it may be an unreliable network (e.g., the public\n") > NFL;
trows++; printf("\tInternet), or it may be due a server being overloaded and dropping packets. The example above shows just\n") > NFL;
trows++; printf("\tone new TCP connection per-second.\n") > NFL;
trows++; printf("\t\n") > NFL;
row += trows;
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
    $SCR_DIR/perf_stat_scatter.sh -o "$OPTIONS"  -f $i > $i.tsv
   SHEETS="$SHEETS $i.tsv"
  fi
  if [[ $i == *"_interrupts.txt"* ]]; then
    echo "do interrupts"
# ==beg 0 date 1580278735.829557760
#            CPU0       CPU1       CPU2       CPU3       CPU4       CPU5       CPU6       CPU7       CPU8       CPU9       CPU10      CPU11      CPU12      CPU13      CPU14      CPU15      CPU16      CPU17      CPU18      CPU19      CPU20      CPU21      CPU22      CPU23      CPU24      CPU25      CPU26      CPU27      CPU28      CPU29      CPU30      CPU31      
#   0:        101          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0  IR-IO-APIC    2-edge      timer
#   3:          2          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0  IR-IO-APIC    3-edge    

    awk '
     BEGIN{beg=1;col_mx=-1;mx=0}
     /^==beg /{
       FNM=ARGV[ARGIND];
       NFL=FNM ".tsv";
       row = $2;
       tm = $4;
       getline;
       hdr_line = $0;
       n = split($0, hdr_cols_arr);
       hdr_cols = NF;
       next;
     }
     { # has to be an interrupt line
        nm = $1;
        if (intr_arr[nm] != nm) {
           intr_num++;
           intr_arr[nm] = nm;
           intr_arr_nms[intr_num] = nm;
           intr_arr_num[nm] = intr_num;
        }
        inum = intr_arr_num[nm];
        for (i=1; i <= NF; i++) {
          sv[row,inum,i] = $i;
        }
        sv_col[row,inum] = NF;
        if ( intr_arr_lng_nms[inum] == "" && NF > (hdr_cols+1) ) {
           for (i=hdr_cols+2; i <= NF; i++) {
             intr_arr_lng_nms[inum] = intr_arr_lng_nms[inum] " " $i;
           }
        }
        if (NF > (hdr_cols+1)) {
          sv_col[row,inum] = hdr_cols+1;
        }
     }
     END{
       for (i=1; i <= intr_num; i++) {
         ck_no_chg[i] = 0;
       }
       for (r=1; r <= row; r++) {
         for (i=1; i <= intr_num; i++) {
            jmx = sv_col[r,i];
            sum = 0;
            for (j=2; j <= jmx; j++) {
               sum += sv[r,i,j];
            }
            sum_arr[r,i] = sum;
         }
       }
       
       for (r=1; r <= row; r++) {
          for (i=1; i <= intr_num; i++) {
             val = sum_arr[r,i];
             if (r == 1) {
                val = 0;
             } else {
                val -= sum_arr[r-1,i];
             }
             ck_no_chg[i] += val;
          }
       }
       drop_cols = 0;
       for (i=1; i <= intr_num; i++) {
         if (ck_no_chg[i] == 0) {
            drop_cols++;
         }
       }
       trows=0;
       printf("title\tinterrupts\tsheet\tinterrupts\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t0\t%d\t%d\n", 2+trows, -1, intr_num-drop_cols) > NFL;
       tab="";
       for (i=1; i <= intr_num; i++) {
          if (ck_no_chg[i] == 0) {
            continue;
          }
          printf("%s%s", tab, intr_arr_nms[i]) > NFL;
          if (intr_arr_lng_nms[i] != "") {
             printf(" %s", intr_arr_lng_nms[i]) > NFL;
          }
          tab="\t";
       }
       trows=2;
       printf("\ttotal\n") > NFL;
       
       for (r=1; r <= row; r++) {
          tab="";
          total=0;
          for (i=1; i <= intr_num; i++) {
             if (ck_no_chg[i] == 0) {
               continue;
             }
             val = sum_arr[r,i];
             if (r == 1) {
                val = 0;
             } else {
                val -= sum_arr[r-1,i];
             }
             printf("%s%d", tab, val) > NFL;
             tab="\t";
             total += val;
          }
          trows++;
          printf("\t%d\n", total) > NFL;
       }
       close(NFL);
   }
   ' $i
   SHEETS="$SHEETS $i.tsv"
  fi
done
if [ "$SHEETS" != "" ]; then
   echo "python $SCR_DIR/tsv_2_xlsx.py $SHEETS"
   python $SCR_DIR/tsv_2_xlsx.py -o $XLSX_FILE -i "$IMAGE_STR" $SHEETS
fi

