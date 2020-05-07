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
PFX=
SUM_FILE=
PHASE_FILE=
END_TM=

while getopts "hvd:e:o:P:p:i:s:x:" opt; do
  case ${opt} in
    d )
      DIR=$OPTARG
      ;;
    e )
      END_TM=$OPTARG
      ;;
    i )
      IMAGE_STR=$OPTARG
      ;;
    o )
      OPTIONS=$OPTARG
      ;;
    p )
      PFX=$OPTARG
      ;;
    P )
      PHASE_FILE=$OPTARG
      ;;
    s )
      SUM_FILE=$OPTARG
      ;;
    x )
      XLSX_FILE=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 split data files into columns"
      echo "Usage: $0 [-h] -d sys_data_dir [-v] [ -p prefix ]"
      echo "   -d dir containing sys_XX_* files created by 60secs.sh"
      echo "   -i \"image_file_name_str\" this option is passed to tsv_2_xlsx.py to identify image files to be inserted into the xlsx"
      echo "      For instance '-i \"*.png\"'. Note the dbl quotes around the glob. This keeps the cmdline from expanding the files. python will expand the glob."
      echo "   -o perf_stat_scatter_options   options for perf_stat_scatter.sh script"
      echo "      '-o dont_sum_sockets' option to not sum the perf stat per socket events to the system"
      echo "      '-o chart_new' option to start the perf_stat chart at the first new computed event column"
      echo "         The default is to start the chart at the 1st event so you get a y axis between 0 and 1e10 or so."
      echo "         If you do just the new computed events then the scale is usually 0-100 or so."
      echo "      You can pass both options with '-o dont_sum_sockets,chart_new'"
      echo "      These optional options are passed to perf_stat_scatter.sh"
      echo "      default is to sum the per socket events to the system level and chart all the events"
      echo "   -x xlsx_filename  This is passed to tsv_2_xlsx.py as the name of the xlsx. (you need to add the .xlsx)"
      echo "      The default is chart_line.xlsx"
      echo "   -p prefix   string to be prefixed to each sheet name"
      echo "   -P prefix   list of phases for data. fmt is 'phasename beg_time end_time'"
      echo "   -s sum_file summary_file"
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

if [ "$SUM_FILE" != "" ]; then
  printf "title\tsummary\tsheet\tsummary\ttype\tcopy\n"  > $SUM_FILE;
  printf "hdrs\t2\t0\t-1\t3\t-1\n" >> $SUM_FILE;
  printf "Resource\tTool\tMetric\tValue\tUSE\tComments\n" >> $SUM_FILE;
fi

PH_TM_END=0
if [ "$PHASE_FILE" != "" ]; then
  PH_TM_END=`awk '{if ($3 != "") {last= $3;}} END{printf("%s\n", last);}' $PHASE_FILE`
  echo "PH_TM_END= $PH_TM_END" > /dev/stderr
fi

TDIR=$DIR
if [ "$TDIR" == "." ]; then
  TDIR=${PWD##*/}  
fi
RPS=`echo $TDIR | sed 's/rps_v/rpsv/' | sed 's/rps.*_.*/rps/' | sed 's/.*_//'`
RPS="${RPS}"
FCTR=`echo $RPS | sed 's/rps//'`
printf "RPS= %s\n", $RPS > "/dev/stderr"

BEG=`cat $DIR/60secs.log | awk '{n=split($0, arr);printf("%s\n", arr[n]);exit;}'`
FILES=`ls -1 $DIR/sys_*_*.txt`
#echo "FILES = $FILES"
for i in $FILES; do
 echo $i
  if [[ $i == *"_uptime.txt"* ]]; then
    echo "do uptime"
    awk -v pfx="$PFX" '
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
       printf("hdrs\t%d\t0\t%d\t2\t-1\n", trows+2, trows+mx+1) > NFL;
       for (i=1; i <= mx; i++) {
          printf("%s\n", sv[i]) > NFL;
       }
       close(NFL);
     }
   ' $i
   SHEETS="$SHEETS $i.tsv"
  fi
  if [[ $i == *"_power.txt"* ]]; then
    echo "do power"
    #RESP=`grep "Power Consumption History" $i | wc -l`
    #if [ "$RESP" != "0" ]; then
      # delloem format data
    #else
      # ipmitool sdr format

    UEND_TM=
    if [ "$END_TM" != "" ]; then
      UEND_TM=$END_TM
    else
      if [ "$PH_TM_END" == "" ]; then
        UEND_TM=$PH_TM_END
      fi
    fi

    awk -v ts_beg="$BEG" -v ts_end="$UEND_TM" -v pfx="$PFX" -v sum_file="$SUM_FILE" -v sum_flds="avg_60secs{avg_power_60sec_mvg_avg|power|%stdev},max_60secs{max_power_60sec_mvg_avg|power},min_60secs{min_power_60sec_mvg_avg|power},SysFan_Power{|power},MB_HSC_Pwr_Out{|power},Total_Power{|power},Power_CPU{|power},Power_Memory{|power},PSU0_Input{|power},PSU0_Output{|power},PSU1_Input{|power},PSU1_Output{|power},HSC_Input_Power{|power},HSC_Output_Power{|power},PDB_HSC_POUT{|power},P0_Pkg_Power{|power},P1_Pkg_Power{|power},CPU0_VR0_Pout{|power},CPU0_VR1_Pout{|power},CPU1_VR0_Pout{|power},CPU1_VR1_Pout{|power},PCH_VR_POUT{|power},CPU0_DM_VR0_POUT{|power},CPU0_DM_VR1_POUT{|power},CPU1_DM_VR0_POUT{|power},CPU1_DM_VR1_POUT{|power},PSU0_POUT{|power},PSU1_POUT{|power},PSU0_PIN{|power},PSU1_PIN{|power},power{power_inst|power|stdev}" '
      BEGIN{
        beg=1;
        mx=0;
        rw=1;
        ts_end += 0.0;
        delloem=0;
        area1_idx=0;
       if (sum_file != "" && sum_flds != "") {
         n_sum = split(sum_flds, sum_arr, ",");
         for (i_sum=1; i_sum <= n_sum; i_sum++) {
            sum_type[i_sum] = 0;
            sum_opt[i_sum] = "";
            str = sum_arr[i_sum];
            pos = index(str, "{");
            if (pos > 0) {
               pos1 = index(str, "}");
               if (pos1 == 0) { pos1= length(str)+1; }
               sum_str = substr(str, pos+1, pos1-pos-1);
               n_sum2 = split(sum_str, sum_arr2, "|");
               if (sum_arr2[1] != "") {
                 sum_prt[i_sum] = sum_arr2[1];
               } else {
                 #sum_prt[i_sum] = str;
                 sum_prt[i_sum] = substr(str, 1, pos-1);
               }
               if (sum_arr2[2] != "") {
                 sum_res[i_sum] = sum_arr2[2];
               }
               if (sum_arr2[3] != "") {
                 sum_opt[i_sum] = sum_arr2[3];
               }
               #sum_prt[i_sum] = substr(str, pos+1, pos1-pos-1);
               sum_arr[i_sum] = substr(str, 1, pos-1);
            } else {
               sum_prt[i_sum] = str;
            }
            printf("pwr: sum_prt[%d]= %s, sum_res= %s\n", i_sum, sum_prt[i_sum], sum_res[i_sum]) > "/dev/stderr";
            if (index(str, "%") > 0) {
               sum_type[i_sum] = 0;
            }
         }
       }
      }
      function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
      function rtrim(s) { sub(/[ \t\r\n,]+$/, "", s); return s }
      function trim(s) { return rtrim(ltrim(s)); }
#==beg 0 date 1585614813.506068153
#NIC_Temp         | 81 degrees C      | ok
#HSC_Input_Power  | 119.00 Watts      | ok
#HSC_Output_Power | 119.00 Watts      | ok
#PDB_HSC_POUT     | 264.00 Watts      | ok
#P0_Pkg_Power     | 34.00 Watts       | ok
#P1_Pkg_Power     | 33.00 Watts       | ok

      /^==beg / {
         tm_bdt = $4 + 0.0;
         if (ts_end > 0.0 && tm_bdt > ts_end) { exit; }
      }
      /^==end / {
         tm_edt = $4 + 0.0;
         tm[rw] = tm_edt;
         rw++;
      }
      /Instantaneous power reading:/ {
        delloem=2; 
         area = "power";
         pwr  = $4;
         typ=1
         if (!(area in area1_lkup)) {
            area1_idx++
            area1_lkup[area] = area1_idx;
            area1_list[area1_idx] = area;
         }
         i = area1_lkup[area];
         rows[rw,typ,i] = pwr + 0.0;
         next;
      }
#    Instantaneous power reading:                   138 Watts
#Statistic                   Last Minute     Last Hour     Last Day     Last Week
#Average Power Consumption   137 W           137 W         119 W        119 W   
#Max Power Consumption       174 W           174 W         174 W        180 W   
#Min Power Consumption       112 W           112 W         112 W        110 W   
      /^Power Consumption History/ {
        delloem=1; 
      }
      /^Average Power Consumption|^Max Power Consumption|^Min Power Consumption/ {
         if ($1 == "Average") { str= "avg"; }
         if ($1 == "Max")     { str= "max"; }
         if ($1 == "Min")     { str= "min"; }
         area = str "_60secs";
         pwr  = $4;
         typ=1
         if (!(area in area1_lkup)) {
            area1_idx++
            area1_lkup[area] = area1_idx;
            area1_list[area1_idx] = area;
         }
         i = area1_lkup[area];
         rows[rw,typ,i] = pwr + 0.0;
      }
      {
	FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        if (delloem >= 1) {
          next;
        }
        n = split($0, arr, "|");
        for (i=1; i <= n; i++) {
           arr[i] = trim(arr[i]);
        }
        if (arr[3] != "ok") {
           next;
        }
        nn = split(arr[2], va, " ");
        area = arr[1];
        typ=0;
        if ( va[2] == "Watts") {
          typ=1;
        }
        if (va[2] == "degrees" ) {
          typ=2;
        }
        if (va[2] == "RPM" ) {
          typ=3;
        }
        if ( typ > 0) {
          if (typ==1) {
          if ((!(area in area1_lkup))) {
             area1_idx++
             area1_lkup[area] = area1_idx;
             area1_list[area1_idx] = area;
          }
          i = area1_lkup[area];
          }
          if (typ==2) {
          if ((!(area in area2_lkup))) {
             area2_idx++
             area2_lkup[area] = area2_idx;
             area2_list[area2_idx] = area;
          }
          i = area2_lkup[area];
          }
          if (typ==3) {
          if ((!(area in area3_lkup))) {
             area3_idx++
             area3_lkup[area] = area3_idx;
             area3_list[area3_idx] = area;
          }
          i = area3_lkup[area];
          }
          rows[rw,typ,i] = va[1] + 0.0;
        }
	FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
      }
function columnToLetter(column)
{
  letter = "";
  chr_str="ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  for (j=0; j < length(chr_str); j++) {
   chr[j] = substr(chr_str, j+1, 1);
  }
  
  c = column;
  if (column == 0) { return "A";}
  cpos = 0;
  while ( column > 0) {
     c_in= column;
     res = column / 26;
     rem = column % 26;
     column = int(res);
     cpos++;
     if (cpos > 1 && rem > 0) { rem--; }
     letter = chr[rem] "" letter;
     #printf("col_in= %d, res= %d, rem= %d, col= %d, let= %s\n", c_in, res, rem, column, letter);
  }
  return letter;
}

     END{
       add_col = 1;
       if (delloem >= 1) {
         rw--;
         add_col = 0;
       }
       brw = 6;
       if (n_sum > 0) {
            for (k=1; k <= area1_idx; k++) {
              hdr_lkup[k] = -1;
            }
            for (k=1; k <= area1_idx; k++) {
              for (i_sum=1; i_sum <= n_sum; i_sum++) {
                 if ( area1_list[k] == sum_arr[i_sum]) {
                    hdr_lkup[k] = i_sum;
                    break; # so if hdr appears more than one in sum_flds, it will be skipped
                 }
              }
            }
       }
       hdr_mx = area1_idx;
trows++; printf("\t$ power") > NFL;
       for (i=2; i <= hdr_mx+area2_idx+area3_idx+1; i++) {
         let = columnToLetter(i+add_col);
         printf("\t=subtotal(1,%s%d:%s%d)", let, brw, let, brw+rw) > NFL;
       }
       printf("\n") > NFL;
trows++; printf("\t$ power") > NFL;
       for (i=2; i <= hdr_mx+area2_idx+area3_idx+1; i++) {
         let = columnToLetter(i+add_col);
         printf("\t=subtotal(4,%s%d:%s%d)", let, brw, let, brw+rw) > NFL;
       }
       printf("\n") > NFL;

       trows++;
       printf("title\tpower\tsheet\tpower\ttype\tscatter_straight\n") > NFL;
       printf("hdrs\t%d\t%d\t%d\t%d\t1\n", trows+1, 2, -1, area1_idx+1) > NFL;
       tab="";
       printf("TS\tts_rel\t") > NFL;
       for (i=1; i <= hdr_mx; i++) {
            printf("%s%s", tab, area1_list[i]) > NFL;
            tab="\t";
       }
       for (i=1; i <= area2_idx; i++) {
            printf("%s%s", tab, area2_list[i]) > NFL;
            tab="\t";
       }
       for (i=1; i <= area3_idx; i++) {
            printf("%s%s", tab, area3_list[i]) > NFL;
            tab="\t";
       }
       row++;
       printf("\n") > NFL;
       for (r=1; r <= rw; r++) {
          tab="";
          if (r == 1) {
             intrvl = tm[r]-ts_beg;
          } else {
             if (tm[r] == 0) {
               continue;
             }
             intrvl = tm[r]-tm[r-1];
          }
          printf("%.3f\t%.4f\t", tm[r], tm[r]-ts_beg) > NFL;
          for (c=1; c <= area1_idx; c++) {
              printf("%s%s", tab, rows[r,1,c]) > NFL;
              tab="\t";
                 if (hdr_lkup[c] != -1) {
                   i_sum = hdr_lkup[c];
#abcd power
                   sum_occ[i_sum] += 1;
                   if (sum_type[i_sum] == 1) {
                     if (sum_tmin[i_sum] == 0) { sum_tmin[i_sum] = tm[r]; sum_tmax[i_sum] = sum_tmin[i_sum]; }
                     if (sum_tmax[i_sum] < tm[r]) { sum_tmax[i_sum] = tm[r]; }
                     if (r > 1) {intrvl = tm[r] - tm[r-1]; } else { intrvl = tm[r]-ts_beg; };
                     sum_x = rows[r,1,c] * intrvl;
                   } else {
                     sum_x = rows[r,1,c]
                   }
                   sum_tot[i_sum] += sum_x
                   sum_x2[i_sum]  += sum_x * sum_x
                 }
          }
          for (c=1; c <= area2_idx; c++) {
              printf("%s%s", tab, rows[r,2,c]) > NFL;
              tab="\t";
          }
          for (c=1; c <= area3_idx; c++) {
              printf("%s%s", tab, rows[r,3,c]) > NFL;
              tab="\t";
          }
          printf("\n") > NFL;
          row++;
       }
       printf("\n") > NFL;
       if (area2_idx > 0) {
       printf("title\ttemperature\tsheet\tpower\ttype\tscatter_straight\n") > NFL;
       printf("hdrs\t%d\t%d\t%d\t%d\t1\n", trows+1, area1_idx+2, -1, area2_idx+area1_idx+1) > NFL;
       printf("\n") > NFL;
       }
       if (area3_idx > 0) {
       printf("title\tFans RPM\tsheet\tpower\ttype\tscatter_straight\n") > NFL;
       printf("hdrs\t%d\t%d\t%d\t%d\t1\n", trows+1, area1_idx+area2_idx+2, -1, area3_idx+area2_idx+area1_idx+1) > NFL;
       }
       close(NFL);
          tool = "ipmitool";
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
             if (sum_occ[i_sum] == 0) {
                continue;
             }
             n = sum_occ[i_sum];
             if (sum_type[i_sum] == 1) {
                n = sum_tmax[i_sum] - sum_tmin[i_sum];
             }
             avg = (n > 0.0 ? sum_tot[i_sum]/n : 0.0);
             printf("%s\t%s\t%s\t%f\n", sum_res[i_sum], tool, sum_prt[i_sum], avg) >> sum_file;
#abcd power
             stdev = 0.0;
             if (index(sum_opt[i_sum], "stdev") > 0) {
                if (n > 0.0) {
                  #     stdev = sqrt((sum_x2 / n) - (mean * mean))
                  stdev = sqrt((sum_x2[i_sum] / n) - (avg * avg))
                }
             }
             if (index(sum_opt[i_sum], "%stdev") > 0) {
                printf("%s\t%s\t%s %%stdev\t%f\n",  sum_res[i_sum], tool, sum_prt[i_sum], 100.0*stdev/avg) >> sum_file;
             }
             else if (index(sum_opt[i_sum], "stdev") > 0) {
                printf("%s\t%s\t%s stdev\t%f\n",  sum_res[i_sum], tool, sum_prt[i_sum], stdev) >> sum_file;
             }
          }
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

    DURA=`awk -v ts_beg="$BEG" -v ts_end="$END_TM" 'BEGIN{ts_beg+=0.0;ts_end+=0.0; if (ts_beg > 0.0 && ts_end > 0.0) {printf("%d\n", ts_end-ts_beg); } else {printf("-1\n");};exit;}'`
    awk -v pfx="$PFX" -v max_lines="$DURA" -v sum_file="$SUM_FILE" -v sum_flds="runnable{vmstat runnable PIDs|OS},interrupts/s{|OS},context switch/s{|OS},%user{|CPU},%idle{|CPU|%stdev}" '
     BEGIN{beg=1;col_mx=-1;mx=0;
        n_sum = 0;
        max_lines += 0;
       if (sum_file != "" && sum_flds != "") {
         n_sum = split(sum_flds, sum_arr, ",");
         for (i_sum=1; i_sum <= n_sum; i_sum++) {
            sum_type[i_sum] = 0;
            sum_res[i_sum] = "";
            sum_opt[i_sum] = "";
            str = sum_arr[i_sum];
            pos = index(str, "{");
            if (pos > 0) {
               pos1 = index(str, "}");
               if (pos1 == 0) { pos1= length(str)+1; }
               sum_str = substr(str, pos+1, pos1-pos-1);
               n_sum2 = split(sum_str, sum_arr2, "|");
               if (sum_arr2[1] != "") {
                 sum_prt[i_sum] = sum_arr2[1];
               } else {
                 #sum_prt[i_sum] = str;
                 sum_prt[i_sum] = substr(str, 1, pos-1);
               }
               if (sum_arr2[2] != "") {
                 sum_res[i_sum] = sum_arr2[2];
               }
               if (sum_arr2[3] != "") {
                 sum_opt[i_sum] = sum_arr2[3];
               }
               #sum_prt[i_sum] = substr(str, pos+1, pos1-pos-1);
               sum_arr[i_sum] = substr(str, 1, pos-1);
            } else {
               sum_prt[i_sum] = str;
            }
            if (index(tolower(str), "/s") > 0) {
               sum_type[i_sum] = 1;
            }
         }
       }
     }
     /^procs/{
       next;
     }
     {
	FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        if (max_lines > 0.0 && mx > max_lines) {
          exit;
        }
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

       printf("title\tvmstat all\tsheet\tvmstat\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t0\t%d\t%d\t-1\n", 2+trows, mx+1+trows, col_mx) > NFL;
       r_col = -1;
       b_col = -1;
       us_col = -1;
       in_col = -1;
       cs_col = -1;
       bi_col = -1;
       bo_col = -1;
       cache_col = -1;
       free_col = -1;
       buff_col = -1;
       nhdr["r"] = "runnable";
       nhdr["b"] = "blocked";
       nhdr["swpd"] = "swapped";
       nhdr["free"] = "free";
       nhdr["buff"] = "buffers";
       nhdr["cache"] = "cached";
       nhdr["si"] = "mem swapped in/s";
       nhdr["so"] = "mem swapped out/s";
       nhdr["in"] = "interrupts/s";
       nhdr["cs"] = "context switch/s";
       nhdr["bi"] = "blocks in/s";
       nhdr["bo"] = "blocks out/s";
       nhdr["us"] = "%user";
       nhdr["sy"] = "%system";
       nhdr["id"] = "%idle";
       nhdr["wa"] = "%waitingIO";
       nhdr["st"] = "%stolen";
        #r b swpd free buff cache si so bi bo in cs us sy id wa st
       n = split(sv[1], arr, "\t");
       nwln = "";
       sep  = "";
       for (i=1; i <= n; i++) {
          if (arr[i] == "r")  { r_col  = i-1; }
          if (arr[i] == "b")  { b_col  = i-1; }
          if (arr[i] == "us") { us_col = i-1; }
          if (arr[i] == "in") { in_col = i-1; }
          if (arr[i] == "cs") { cs_col = i-1; }
          if (arr[i] == "bi") { bi_col = i-1; }
          if (arr[i] == "bo") { bo_col = i-1; }
          if (arr[i] == "cache") { cache_col = i-1; }
          if (arr[i] == "free")  { free_col  = i-1; }
          if (arr[i] == "buff")  { buff_col  = i-1; }
          if (arr[i] in nhdr) { str = nhdr[arr[i]]; } else { str = arr[i]; }
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
              if (str == sum_arr[i_sum]) {
                 sum_lkup[i_sum] = i;
              }
          }
          nwln = nwln "" sep "" str;
          sep = "\t";
       }
       printf("%s\n", nwln) > NFL;
       for (i=2; i <= mx; i++) {
          if (n_sum > 0) {
            n = split(sv[i], arr, "\t");
            for (i_sum=1; i_sum <= n_sum; i_sum++) {
              j = sum_lkup[i_sum];
              sum_occ[i_sum] += 1;
              sum_tot[i_sum] += arr[j];
              sum_x2[i_sum] += arr[j]*arr[j];

            }
          }
          printf("%s\n", sv[i]) > NFL;
       }
       printf("\ntitle\tvmstat cpu\tsheet\tvmstat\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t0\t%d\t%d\t-1\t%d\t%d\t%d\t%d\t%d\t%d\n", 2+trows, mx+1+trows, col_mx, r_col, r_col, b_col, b_col, us_col, col_mx) > NFL;
       printf("\ntitle\tvmstat interrupts & context switches\tsheet\tvmstat\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t0\t%d\t%d\t-1\t%d\t%d\t%d\t%d\n", 2+trows, mx+1+trows, col_mx, in_col, in_col, cs_col, cs_col) > NFL;
       printf("\ntitle\tvmstat memory cache, free & buffers\tsheet\tvmstat\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t0\t%d\t%d\t-1\t%d\t%d\t%d\t%d\t%d\t%d\n", 2+trows, mx+1+trows, col_mx, cache_col, cache_col, free_col, free_col, buff_col, buff_col) > NFL;
       printf("\ntitle\tvmstat IO blocks in & blocks out\tsheet\tvmstat\ttype\tline\n") > NFL;
       printf("hdrs\t%d\t0\t%d\t%d\t-1\t%d\t%d\t%d\t%d\n", 2+trows, mx+1+trows, col_mx, bi_col, bi_col, bo_col, bo_col) > NFL;
       close(NFL);
       if (n_sum > 0) {
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
             n = sum_occ[i_sum];
             avg = (n > 0.0 ? sum_tot[i_sum]/n : 0.0);
             printf("%s\t%s\t%s\t%f\n",  sum_res[i_sum], "vmstat", sum_prt[i_sum], avg) >> sum_file;
#abcd vmstat
             stdev = 0.0;
             if (index(sum_opt[i_sum], "stdev") > 0) {
                if (n > 0.0) {
                  #     stdev = sqrt((sum_x2 / n) - (mean * mean))
                  stdev = sqrt((sum_x2[i_sum] / n) - (avg * avg))
                }
             }
             if (index(sum_opt[i_sum], "%stdev") > 0) {
                printf("%s\t%s\t%s %%stdev\t%f\n",  sum_res[i_sum], "vmstat", sum_prt[i_sum], 100.0*stdev/avg) >> sum_file;
             }
             else if (index(sum_opt[i_sum], "stdev") > 0) {
                printf("%s\t%s\t%s stdev\t%f\n",  sum_res[i_sum], "vmstat", sum_prt[i_sum], stdev) >> sum_file;
             }
          }
       }
       }
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

    awk -v ts_beg="$BEG" -v ts_end="$END_TM" -v pfx="$PFX" '
     BEGIN{
        beg=1;
        grp_mx=0;
        hdr_mx=0;
        ts_beg += 0;
        ts_end += 0;
        epoch_init = 0;
      }
      function dt_to_epoch(hhmmss, ampm) {
         # the epoch seconds from the date time info in the file is local time,not UTC.
         # so just use the calc"d epoch seconds to calc the elapsed seconds since the start.
         # THe real timestamp is the input ts_beg + elapsed_seconds.
         # hhmmss fmt= hh:mm:ss (w leading 0
         if (dt_beg["yy"] == "") {
            return 0.0;
         }
         dt_tm["hh"] = substr(hhmmss,1,2) + 0;
         dt_tm["mm"] = substr(hhmmss,4,2) + 0;
         dt_tm["ss"] = substr(hhmmss,7,2) + 0;
         if (ampm == "PM" && dt_tm["hh"] < 12) {
            dt_tm["hh"] += 12;
         }
         dt_str = dt_beg["yy"] " " dt_beg["mm"] " " dt_beg["dd"] " " dt_tm["hh"] " " dt_tm["mm"] " " dt_tm["ss"];
         #printf("dt_str= %s\n", dt_str) > "/dev/stderr";
         epoch = mktime(dt_str);
         #printf("epoch= %s offset= %s\n", epoch, offset);
         if (epoch_init == 0) {
             epoch_init = epoch;
         }
         epoch = ts_beg + (epoch - epoch_init + 1); # the plus 1 assumes a 1 second interval.
         if ((epoch-ts_beg) < 0.0) {
            printf("epoch= %f, hhmmss= %s, dt_str= %s ts_beg= %f. epoch-ts_beg= %f ampm= %s bye\n", epoch, hhmmss, dt_str, ts_beg, epoch-ts_beg, ampm) > "/dev/stderr";
            exit;
         }
         return epoch;
      }
     /^Linux/{
        if (NR == 1) {
          for (i=1; i <= NF; i++) {
             if (match($i, /^[0-9][0-9]\/[0-9][0-9]\/[0-9][0-9][0-9][0-9]/)) {
                dt_beg["yy"] = substr($i, 7);
                dt_beg["mm"] = substr($i, 1, 2);
                dt_beg["dd"] = substr($i, 4, 2);
                printf("beg_date= mm.dd.yyyy %s.%s.%s\n", dt_beg["mm"], dt_beg["dd"], dt_beg["yy"]) > "/dev/stderr";
                #break;
             }
             if (i == NF && $i == "CPU)") {
                num_cpus = substr(fld_prv, 2)+0;
                num_cpus_pct = num_cpus * 100.0;
             }
             fld_prv = $i;
          }
        }
       next;
     }
     {
	FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
        if (NF==0) { next; }
     }
     /%idle/{
        if (beg == 1 && ($2 == "AM" || $2 == "PM")) {
           epoch = dt_to_epoch($1, $2);
           tm_beg = epoch;
        }
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
        if ($2 == "AM" || $2 == "PM") {
           epoch = dt_to_epoch($1, $2);
        }
        if (ts_end > 0.0 && epoch > ts_end) {
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
        tm_rw[rw] = epoch;
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
          printf("title\tmpstat cpu= %s\tsheet\tmpstat\ttype\tscatter_straight\n", grp_nm[g]) > NFL;
          row++;
          printf("hdrs\t%d\t%d\t%d\t%d\t1\n", trows+row+1, 3, trows+1+row+grp_row[g], hdr_mx+1) > NFL;
          tab="";
          printf("TS\tts_rel\t") > NFL;
          for (i=1; i <= hdr_mx; i++) {
            printf("%s%s", tab, hdrs[i]) > NFL;
            tab="\t";
          }
          row++;
          printf("\n") > NFL;
          for (r=1; r <= grp_row[g]; r++) {
            tab="";
            printf("%.3f\t%.4f\t", tm_rw[r], tm_rw[r]-ts_beg) > NFL;
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
#aaaa
    awk -v ts_beg="$BEG" -v ts_end="$END_TM" -v pfx="$PFX" -v typ="pidstat" '
     BEGIN{beg=1;
        grp_mx=0;
        hdr_mx=0;
        chart=typ;
        did_notes=0;
        tm_rw = 0;
        tm_beg += 0;
        tm_end += 0;
        epoch_init = 0;
        num_cpus = 0;
        num_cpus_pct = 0;
        tot_first=1;
      }
      function dt_to_epoch(hhmmss, ampm) {
         # the epoch seconds from the date time info in the file is local time,not UTC.
         # so just use the calc"d epoch seconds to calc the elapsed seconds since the start.
         # THe real timestamp is the input ts_beg + elapsed_seconds.
         # hhmmss fmt= hh:mm:ss (w leading 0
         if (dt_beg["yy"] == "") {
            return 0.0;
         }
         dt_tm["hh"] = substr(hhmmss,1,2) + 0;
         dt_tm["mm"] = substr(hhmmss,4,2) + 0;
         dt_tm["ss"] = substr(hhmmss,7,2) + 0;
         if (ampm == "PM" && dt_tm["hh"] < 12) {
            dt_tm["hh"] += 12;
         }
         dt_str = dt_beg["yy"] " " dt_beg["mm"] " " dt_beg["dd"] " " dt_tm["hh"] " " dt_tm["mm"] " " dt_tm["ss"];
         #printf("dt_str= %s\n", dt_str) > "/dev/stderr";
         epoch = mktime(dt_str);
         #printf("epoch= %s offset= %s\n", epoch, offset);
         if (epoch_init == 0) {
             epoch_init = epoch;
         }
         epoch = ts_beg + (epoch - epoch_init + 1); # the plus 1 assumes a 1 second interval.
         return epoch;
      }
      function sort_data(arr_in, arr_mx, mx_lines) {
       srt_lst="";
       for (i=1; i <= arr_mx; i++) {
           srt_lst=srt_lst "" arr_in[i] "\n";
       }
       cmd = "printf \"" srt_lst "\" | sort -t '\t' -r -n -k 1";
       #printf("cmd= %s\n", cmd);
       #printf("======== end cmd=========\n");
       nf_mx=0;
       while ( ( cmd | getline result ) > 0 ) {
         n = split(result, marr, "\t");
         sv_nf[++nf_mx] = marr[2];
         #printf("asv_nf[%d]= %s, m1= %s m2= %s\n", nf_mx, result, marr[1], marr[2]) > "/dev/stderr";
         if (nf_mx > mx_lines) {
           break;
         }
       } 
       close(cmd)
       return nf_mx;
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
       printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", row+1, 0, -1, n-2, n-1) > NFL;
       ++row;
       printf("%s\n", hdr) > NFL;
       for (i=1; i <= nf_mx; i++) {
         ++row;
         printf("%s\n", sv_nf[i]) > NFL;
       }
       return row;
     }
     {
	FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
        str="";
        tab="";
        for (i=1; i <= NF; i++) {
          str = str "" sprintf("%s%s", tab, $i);
          tab = "\t";
        }
        sv[++sv_mx] = str;
        if (NR == 1) {
          for (i=1; i <= NF; i++) {
             if (match($i, /^[0-9][0-9]\/[0-9][0-9]\/[0-9][0-9][0-9][0-9]/)) {
                dt_beg["yy"] = substr($i, 7);
                dt_beg["mm"] = substr($i, 1, 2);
                dt_beg["dd"] = substr($i, 4, 2);
                printf("beg_date= mm.dd.yyyy %s.%s.%s\n", dt_beg["mm"], dt_beg["dd"], dt_beg["yy"]) > "/dev/stderr";
                #break;
             }
             if (i == NF && $i == "CPU)") {
                num_cpus = substr(fld_prv, 2)+0;
                num_cpus_pct = num_cpus * 100.0;
             }
             fld_prv = $i;
          }
          next;
        }
        if (NF == 0) {
           area="cpu";
           next;
        }
        if ($2 == "AM" || $2 == "PM") {
           if (index($0, "%CPU") > 1) {
              area="cpu";
              epoch = dt_to_epoch($1, $2);
              tm_rw = tm_rw+1;
              tm_arr[tm_rw] = epoch;
              next;
           }
           if (index($0, " kB_rd/s ") > 1) {
              area="io";
              epoch = dt_to_epoch($1, $2);
              tm_rw_io = tm_rw_io+1;
              tm_arr_io[tm_rw_io] = epoch;
              next;
           }
           if (ts_end > 0.0 && epoch > ts_end) {
              next;
           }
           if ( area == "cpu" && $1 != "Average:") {
             nm  = $10 " " $4; # process_name + pid
             if (!(nm in nm_arr)) {
               if (tot_first == 1) {
                 tot_first = 0;
                 nmt = "__tot__";
                 nm_idx++
                 nm_arr[nmt] = nm_idx;
                 nm_lkup[nm_idx] = nmt;
                 nm_tot[nm_idx] = 0;
                 nm_tot_io[nm_idx] = 0;
               }
               nm_idx++
               nm_arr[nm] = nm_idx;
               nm_lkup[nm_idx] = nm;
               nm_tot[nm_idx] = 0;
             }
             nmi = nm_arr[nm];
             pct = $8+0; # %cpu
             if (pct > num_cpus_pct) {
               # it is misleading to set it to 0 as it makes me think the process is blocked and not running in this interval.
               # The numbers "look like" they could be 1000x too big...this is a real hack
               npct = pct * 0.001;
               if (npct > num_cpus_pct) { npct = 0.0; }
               printf("pidstat: trying to fixup too high %CPU: pct= %f num_cpus_pct= %f, npct= %f, tm_rw= %d, i= %d, pid[%d,%s]= %s, nm= %s\n", pct, num_cpus_pct, npct, tm_rw, i, i,nmi, pid[i,nmi], nm) > "/dev/stderr";
               pct = npct;
             }
             pid[tm_rw,nmi] = pct;
             nm_tot[nmi] += pct;
           }
           if ( area == "io" && $1 != "Average:") {
             nm  = $9 " " $4; # process_name + pid
             if (!(nm in nm_arr)) {
               if (tot_first == 1) {
                 tot_first = 0;
                 nmt = "__tot__";
                 nm_idx++
                 nm_arr[nmt] = nm_idx;
                 nm_lkup[nm_idx] = nmt;
                 nm_tot[nm_idx] = 0;
                 nm_tot_io[nm_idx] = 0;
               }
               nm_idx++
               nm_arr[nm] = nm_idx;
               nm_lkup[nm_idx] = nm;
               nm_tot_io[nm_idx] = 0;
             }
             nmi = nm_arr[nm];
             kbr = $5+0; # kBread/s
             kbw = $6+0; # kBwrite/s
             if ((kbr + kbw) < 20.0e6) { # pidstat has some bogus numbers at times
             pid_io[tm_rw_io,nmi,"rd"] = kbr;
             pid_io[tm_rw_io,nmi,"wr"] = kbw;
             nm_tot_io[nmi] += kbr+kbw;
             nmi = nm_arr[nmt];
             pid_io[tm_rw_io,nmi,"rd"] += kbr;
             pid_io[tm_rw_io,nmi,"wr"] += kbw;
             nm_tot_io[nmi] += kbr+kbw;
             }
           }
        }
     }
     /^Average:/{
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
        next;
     }
     END{
       row = -1;

trows++; printf("\tpidstat is a little like top\x27s per-process summary, but prints a rolling summary instead of clearing the screen.\n") > NFL;
trows++; printf("\tThis can be useful for watching patterns over time, and also recording what you saw (copy-n-paste) into a\n") > NFL;
trows++; printf("\trecord of your investigation.\n") > NFL;
trows++; printf("\tThe above example identifies two java processes as responsible for consuming CPU. The %%CPU column is\n") > NFL;
trows++; printf("\tthe total across all CPUs; 1591%% shows that that java processes is consuming almost 16 CPUs.\n") > NFL;

       row += trows;
       for (k=1; k <= nm_idx; k++) {
          my_cpu[k]=sprintf("%d\t%s", nm_tot[k], nm_lkup[k]);
       }
       my_nms = sort_data(my_cpu, nm_idx, 20);
       for (k=1; k <= my_nms; k++) {
         my_order[k] = sv_nf[k];
       }
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "pid_stat %CPU by proc", "pat") > NFL;
       ++row;
       #n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", row+1, 2, -1, my_nms+1, 1) > NFL;
       ++row;
       printf("TS\trel_t") > NFL;
       for (k=1; k <= my_nms; k++) {
          printf("\t%s", my_order[k]) > NFL;
       }
       printf("\n") > NFL;
       for (j=1; j <= tm_rw; j++) {
          printf("%d\t%d", tm_arr[j], tm_arr[j]-ts_beg) > NFL;
          for (k=1; k <= my_nms; k++) {
             nmi = nm_arr[my_order[k]];
             printf("\t%d", pid[j,nmi]) > NFL;
          }
          ++row;
         printf("\n") > NFL;
       }
       ++row;
       printf("\n") > NFL;

       # IO segment
       for (k=1; k <= nm_idx; k++) {
          my_cpu[k]=sprintf("%f\t%s", nm_tot_io[k], nm_lkup[k]);
          #printf("my_cpu[%d]= %s\n", k, my_cpu[k]) > "/dev/stderr";
       }
       my_nms = sort_data(my_cpu, nm_idx, 20);
       for (k=1; k <= my_nms; k++) {
         my_order[k] = sv_nf[k];
       }
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", "pid_stat IO (MB/s) by proc. Proc IO might not get to disk", "pat") > NFL;
       ++row;
       #n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", row+1, 2, -1, my_nms+1, 1) > NFL;
       ++row;
       printf("TS\trel_t") > NFL;
       for (k=1; k <= my_nms; k++) {
          printf("\t%s", my_order[k]) > NFL;
       }
       printf("\n") > NFL;
       for (j=1; j <= tm_rw_io; j++) {
          printf("%d\t%d", tm_arr_io[j], tm_arr_io[j]-ts_beg) > NFL;
          for (k=1; k <= my_nms; k++) {
             nmi = nm_arr[my_order[k]];
             printf("\t%f", (pid_io[j,nmi,"rd"]+pid_io[j,nmi,"wr"])/1024.0) > NFL;
          }
          ++row;
         printf("\n") > NFL;
       }
       ++row;
       printf("\n") > NFL;

       row = bar_data(row, sv_cpu, mx_cpu, chart " average %CPU", sv_cpu[1], 40);
       ++row;
       printf("\n") > NFL;
       if (mx_cs > 0) {
         row = bar_data(row, sv_cs, mx_cs, chart " CSWTCH", sv_cs[1], 40);
         ++row;
         printf("\n") > NFL;
       }
       if (mx_threads > 0) {
         row = bar_data(row, sv_threads, mx_threads, chart " threads, fd", sv_threads[1], 40);
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
  if [[ $i == *"_iostat.txt"* ]]; then
#avg-cpu:  %user   %nice %system %iowait  %steal   %idle
#           1.32    3.52    0.76    0.16    0.00   94.24
#
#Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
#sda               0.00     0.00  567.00    0.00  7100.00     0.00    25.04     0.06    0.11    0.11    0.00   0.11   6.00
#dm-0              0.00     0.00  567.00    0.00  7100.00     0.00    25.04     0.06    0.11    0.11    0.00   0.11   6.40

#rkB/s	wkB/s	avgrq-sz	avgqu-sz	await	r_await	w_await	svctm	%util

    echo "do iostat"
    awk -v ts_beg="$BEG" -v ts_end="$END_TM" -v pfx="$PFX" -v typ="iostat"  -v sum_file="$SUM_FILE" -v sum_flds="rkB/s{io RdkB/s|disk},wkB/s{io wrkB/s|disk},avgrq-sz{io avg Req_sz|disk},avgqu-sz{io avg que_sz|disk},%util{io %util|disk}" '
     BEGIN{
        beg=1;
        grp_mx=0;
        hdr_mx=0;
        chart=typ;
        mx_cpu=0;
        mx_io=0;
        mx_dev=0;
        tm_beg = 0;
        ts_beg += 0;
        ts_end += 0;
        epoch_init = 0;
        n_sum = 0;
       if (sum_file != "" && sum_flds != "") {
         n_sum = split(sum_flds, sum_arr, ",");
         for (i_sum=1; i_sum <= n_sum; i_sum++) {
            sum_type[i_sum] = 0;
            str = sum_arr[i_sum];
            pos = index(str, "{");
            if (pos > 0) {
               pos1 = index(str, "}");
               if (pos1 == 0) { pos1= length(str)+1; }
               sum_str = substr(str, pos+1, pos1-pos-1);
               n_sum2 = split(sum_str, sum_arr2, "|");
               if (sum_arr2[1] != "") {
                 sum_prt[i_sum] = sum_arr2[1];
               } else {
                 #sum_prt[i_sum] = str;
                 sum_prt[i_sum] = substr(str, 1, pos-1);
               }
               if (sum_arr2[2] != "") {
                 sum_res[i_sum] = sum_arr2[2];
               }
               #sum_prt[i_sum] = substr(str, pos+1, pos1-pos-1);
               sum_arr[i_sum] = substr(str, 1, pos-1);
            } else {
               sum_prt[i_sum] = str;
            }
            if (index(tolower(str), "/s") > 0) {
               sum_type[i_sum] = 1;
            }
         }
       }
      }
      function dt_to_epoch(hhmmss, ampm) {
         # the epoch seconds from the date time info in the file is local time,not UTC.
         # so just use the calc"d epoch seconds to calc the elapsed seconds since the start.
         # THe real timestamp is the input ts_beg + elapsed_seconds.
         # hhmmss fmt= hh:mm:ss (w leading 0
         if (dt_beg["yy"] == "") {
            return 0.0;
         }
         dt_tm["hh"] = substr(hhmmss,1,2) + 0;
         dt_tm["mm"] = substr(hhmmss,4,2) + 0;
         dt_tm["ss"] = substr(hhmmss,7,2) + 0;
         if (ampm == "PM" && dt_tm["hh"] < 12) {
            dt_tm["hh"] += 12;
         }
         dt_str = dt_beg["yy"] " " dt_beg["mm"] " " dt_beg["dd"] " " dt_tm["hh"] " " dt_tm["mm"] " " dt_tm["ss"];
         #printf("dt_str= %s\n", dt_str) > "/dev/stderr";
         epoch = mktime(dt_str);
         #printf("epoch= %s offset= %s\n", epoch, offset);
         if (epoch_init == 0) {
             epoch_init = epoch;
         }
         epoch = ts_beg + (epoch - epoch_init + 1); # the plus 1 assumes a 1 second interval.
         return epoch;
      }
      function line_data(row, arr_in, arr_mx, title, hdr, mytarr) {
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", title, chart) > NFL;
       ++row;
       n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\t1\n", row+1, 2, row+arr_mx, n+1) > NFL;
       ++row;
       printf("TS\tts_rel\t%s\n", hdr) > NFL;
       for (i=2; i <= arr_mx; i++) {
         ++row;
         printf("%.3f\t%.4f\t%s\n", mytarr[i], mytarr[i]-ts_beg, arr_in[i]) > NFL;
       }
       return row;
     }
     {
        FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
     }
     #02/28/2020 10:34:37 PM
     / AM$| PM$/{
         dt_beg["yy"] = substr($1, 7, 4);
         dt_beg["mm"] = substr($1, 1, 2);
         dt_beg["dd"] = substr($1, 4, 2);
         epoch = dt_to_epoch($2, $3);
         if (ts_end > 0.0 && epoch > ts_end) {
              exit;
         }
         if (tm_beg == 0) {
           tm_beg = epoch;
         }
         #  printf("iostat beg_date= mm.dd.yyyy %s.%s.%s, epoch= %f\n", dt_beg["mm"], dt_beg["dd"], dt_beg["yy"], epoch) > "/dev/stderr";
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
               sv_io_tm[mx_io]=epoch;
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
           sv_cpu_tm[mx_cpu] = epoch;
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
           sv_io_tm[mx_io] = epoch;
           sv_io_dev_ids[mx_io] = $1;
        }
        sv[++sv_mx] = str;
        sv_tm[sv_mx] = epoch;
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
       row = line_data(row, sv_cpu, mx_cpu, chart " %CPU", sv_cpu[1], sv_cpu_tm);
       ++row;
       printf("\n") > NFL;
       if (mx_dev > 0 && n_sum > 0) {
         n = split(sv_io[1], hdr_arr, "\t");
         for (i=1; i <= n; i++) {
           for (i_sum=1; i_sum <= n_sum; i_sum++) {
               if (hdr_arr[i] == sum_arr[i_sum]) {
                  sum_lkup[i_sum] = i;
               }
           }
         }
       }
       for (ii=1; ii <= mx_dev; ii++) {
          ttl=chart " dev " dev_lst[ii];
          delete narr;
          delete tarr;
          narr[1] = sv_io[1];
          tarr[1] = sv_io_tm[1];
          mx_arr=1;
          for (jj=2; jj <= mx_io; jj++) {
             if (sv_io_dev_ids[jj] == dev_lst[ii]) {
                narr[++mx_arr] = sv_io[jj];
                tarr[mx_arr] = sv_io_tm[jj];
                if (n_sum > 0) {
                  n = split(sv_io[jj], tst_arr, "\t");
                  for (i_sum=1; i_sum <= n_sum; i_sum++) {
                    j = sum_lkup[i_sum];
                    sum_occ[i_sum] += 1;
                    if (sum_type[i_sum] == 1) {
                      if (sum_tmin[i_sum] == 0) { sum_tmin[i_sum] = sv_io_tm[jj]; sum_tmax[i_sum] = sv_io_tm[jj]; }
                      if (sum_tmax[i_sum] < sv_io_tm[jj]) { sum_tmax[i_sum] = sv_io_tm[jj]; }
                      if (jj > 2) { intrvl = sv_io_tm[jj] - sv_io_tm[jj-1];} else { intrvl = 1.0; } # a hack for jj=2;
                      sum_tot[i_sum] += tst_arr[j] * intrvl;
                    } else {
                      sum_tot[i_sum] += tst_arr[j];
                    }
                  }
                }
             }
          }
          row = line_data(row, narr, mx_arr, ttl, narr[1], tarr);
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
       if (n_sum > 0) {
          printf("got iostat n_sum= %d\n", n_sum) >> "/dev/stderr";
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
             divi = sum_occ[i_sum];
             if (sum_type[i_sum] == 1) {
                divi = sum_tmax[i_sum] - sum_tmin[i_sum];
             }
             printf("%s\t%s\t%s\t%f\n", sum_res[i_sum], "iostat", sum_prt[i_sum], (divi > 0 ? sum_tot[i_sum]/divi : 0.0)) >> sum_file;
          }
       }
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
    awk -v ts_beg="$BEG" -v ts_end="$END_TM" -v pfx="$PFX" -v typ="sar network IFACE"  -v sum_file="$SUM_FILE" -v sum_flds="rxkB/s{net rdKB/s|network},txkB/s{net wrKB/s|network},%ifutil{net %util|network}" '
     BEGIN{beg=1;
        grp_mx=0;
        hdr_mx=0;
        chart=typ;
        ts_beg += 0.0;
        ts_end += 0.0;
        mx_cpu=0;
        mx_io=0;
        mx_dev=0;
        epoch_init = 0;
        n_sum = 0;
       if (sum_file != "" && sum_flds != "") {
         n_sum = split(sum_flds, sum_arr, ",");
         for (i_sum=1; i_sum <= n_sum; i_sum++) {
            sum_type[i_sum] = 0;
            str = sum_arr[i_sum];
            pos = index(str, "{");
            if (pos > 0) {
               pos1 = index(str, "}");
               if (pos1 == 0) { pos1= length(str)+1; }
               sum_str = substr(str, pos+1, pos1-pos-1);
               n_sum2 = split(sum_str, sum_arr2, "|");
               if (sum_arr2[1] != "") {
                 sum_prt[i_sum] = sum_arr2[1];
               } else {
                 #sum_prt[i_sum] = str;
                 sum_prt[i_sum] = substr(str, 1, pos-1);
               }
               if (sum_arr2[2] != "") {
                 sum_res[i_sum] = sum_arr2[2];
               }
               #sum_prt[i_sum] = substr(str, pos+1, pos1-pos-1);
               sum_arr[i_sum] = substr(str, 1, pos-1);
            } else {
               sum_prt[i_sum] = str;
            }
            if (index(tolower(str), "/s") > 0) {
               sum_type[i_sum] = 1;
            }
         }
       }
      }
      function dt_to_epoch(hhmmss, ampm) {
         # the epoch seconds from the date time info in the file is local time,not UTC.
         # so just use the calc"d epoch seconds to calc the elapsed seconds since the start.
         # THe real timestamp is the input ts_beg + elapsed_seconds.
         # hhmmss fmt= hh:mm:ss (w leading 0
         if (dt_beg["yy"] == "") {
            return 0.0;
         }
         dt_tm["hh"] = substr(hhmmss,1,2) + 0;
         dt_tm["mm"] = substr(hhmmss,4,2) + 0;
         dt_tm["ss"] = substr(hhmmss,7,2) + 0;
         if (ampm == "PM" && dt_tm["hh"] < 12) {
            dt_tm["hh"] += 12;
         }
         dt_str = dt_beg["yy"] " " dt_beg["mm"] " " dt_beg["dd"] " " dt_tm["hh"] " " dt_tm["mm"] " " dt_tm["ss"];
         #printf("dt_str= %s\n", dt_str) > "/dev/stderr";
         epoch = mktime(dt_str);
         #printf("epoch= %s offset= %s\n", epoch, offset);
         if (epoch_init == 0) {
             epoch_init = epoch;
         }
         epoch = ts_beg + (epoch - epoch_init + 1); # the plus 1 assumes a 1 second interval.
         return epoch;
      }

      function line_data(row, arr_in, arr_mx, title, hdr, tmarr_in, dev_str) {
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", title, chart) > NFL;
       ++row;
       n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", row+1, 3, row+arr_mx, n+1, 1) > NFL;
       ++row;
       if (n_sum > 0) {
         nk = split(hdr, hdr_arr, "\t");
         for (ik=1; ik <= nk; ik++) {
           for (i_sum=1; i_sum <= n_sum; i_sum++) {
               if (hdr_arr[ik] == sum_arr[i_sum]) {
                  sum_lkup[i_sum] = ik;
               }
           }
         }
       }
       printf("TS\tts_offset\t%s\n", hdr) > NFL;
       for (i=2; i <= arr_mx; i++) {
         ++row;
         printf("%d\t%d\t%s\n", tmarr_in[i], tmarr_in[i]-ts_beg, arr_in[i]) > NFL;
                if (n_sum > 0) {
                  n = split(arr_in[i], tst_arr, "\t");
                  for (i_sum=1; i_sum <= n_sum; i_sum++) {
                    j = sum_lkup[i_sum];
                    sum_occ[i_sum] += 1;
                    if (sum_type[i_sum] == 1) {
                      if (sum_tmin[i_sum] == 0) { sum_tmin[i_sum] = tmarr_in[i]; sum_tmax[i_sum] = tmarr_in[i]; }
                      if (sum_tmax[i_sum] < tmarr_in[i]) { sum_tmax[i_sum] = tmarr_in[i]; }
                      if (i > 2) { intrvl = tmarr_in[i] - tmarr_in[i-1];} else { intrvl = 1.0; } # a hack for jj=2;
                      sum_tot[i_sum] += tst_arr[j] * intrvl;
                    } else {
                      sum_tot[i_sum] += tst_arr[j];
                    }
                  }
                }
       }
       if (n_sum > 0) {
          printf("got sum net IFACE n_sum= %d\n", n_sum) >> "/dev/stderr";
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
             divi = sum_occ[i_sum];
             if (sum_type[i_sum] == 1) {
                divi = sum_tmax[i_sum] - sum_tmin[i_sum];
             }
             if (dev_str != "lo") {
             printf("%s\t%s %s\t%s\t%f\n", sum_res[i_sum], "sar_net", dev_str, sum_prt[i_sum], (divi > 0 ? sum_tot[i_sum]/divi : 0.0)) >> sum_file;
             }
          }
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
             sum_occ[i_sum] = 0;
             if (sum_type[i_sum] == 1) {
                sum_tmax[i_sum] = 0;
                sum_tmax[i_sum] = 0;
                sum_tot[i_sum] = 0;
             }
          }
       }
       return row;
     }
     {
        FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
        if (NR == 1) {
          for (i=1; i <= NF; i++) {
             if (match($i, /^[0-9][0-9]\/[0-9][0-9]\/[0-9][0-9][0-9][0-9]/)) {
                dt_beg["yy"] = substr($i, 7);
                dt_beg["mm"] = substr($i, 1, 2);
                dt_beg["dd"] = substr($i, 4, 2);
                printf("beg_date= mm.dd.yyyy %s.%s.%s\n", dt_beg["mm"], dt_beg["dd"], dt_beg["yy"]) > "/dev/stderr";
                break;
             }
          }
          next;
        }
     }
     /^Average:/ {
        # could make a bar chart of this but...
        next;
     }
     / rxpck\/s /{
        # 01:08:50 AM
        #printf("epoch= %d\n", epoch) > "/dev/stderr";
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
        epoch = dt_to_epoch($1, $2);
        if (ts_end > 0.0 && epoch > ts_end) {
          exit;
        }
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
           sv_tm[mx_io] = epoch;
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
                tmarr[mx_arr] = sv_tm[jj];
             }
          }
          row = line_data(row, narr, mx_arr, ttl, narr[1], tmarr, dev_lst[ii]);
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
    awk -v ts_beg="$BEG"  -v ts_end="$END_TM" -v pfx="$PFX" -v typ="sar tcp stats" '
     BEGIN{beg=1;
        grp_mx=0;
        hdr_mx=0;
        chart=typ;
        mx_cpu=0;
        mx_io=0;
        mx_io1=0;
        mx_dev=0;
        epoch_init = 0;
        ts_beg += 0;
        ts_end += 0;
      }
# efg
      function dt_to_epoch(hhmmss, ampm, all) {
         # the epoch seconds from the date time info in the file is local time,not UTC.
         # so just use the calc"d epoch seconds to calc the elapsed seconds since the start.
         # THe real timestamp is the input ts_beg + elapsed_seconds.
         # hhmmss fmt= hh:mm:ss (w leading 0
         if (dt_beg["yy"] == "") {
            return 0.0;
         }
         dt_tm["hh"] = substr(hhmmss,1,2) + 0;
         dt_tm["mm"] = substr(hhmmss,4,2) + 0;
         dt_tm["ss"] = substr(hhmmss,7,2) + 0;
         if (ampm == "PM" && dt_tm["hh"] < 12) {
            dt_tm["hh"] += 12;
         }
         dt_str = dt_beg["yy"] " " dt_beg["mm"] " " dt_beg["dd"] " " dt_tm["hh"] " " dt_tm["mm"] " " dt_tm["ss"];
         #printf("dt_str= %s\n", dt_str) > "/dev/stderr";
         epoch = mktime(dt_str);
         #printf("epoch= %s offset= %s\n", epoch, offset);
         if (epoch_init == 0) {
             printf("dt_str= %s, all= %s\n", dt_str, all) > "/dev/stderr";
             epoch_init = epoch;
         }
         epoch = ts_beg + (epoch - epoch_init + 1); # the plus 1 assumes a 1 second interval.
         return epoch;
      }
      function line_data(row, arr_in, arr_mx, title, hdr) {
       ++row;
       printf("title\t%s\tsheet\t%s\ttype\tscatter_straight\n", title, chart) > NFL;
       ++row;
       n = split(hdr, arr, "\t");
       printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", row+1, 2, row+arr_mx, n+1, 1) > NFL;
       ++row;
       printf("TS\tts_rel\t%s\n", hdr) > NFL;
       for (i=2; i <= arr_mx; i++) {
         ++row;
         printf("%d\t%d\t%s\n", sv_tm[i], sv_tm[i]-ts_beg, arr_in[i]) > NFL;
       }
       return row;
     }
     {
        FNM=ARGV[ARGIND];
        NFL=FNM ".tsv";
        NFLA=FNM ".all.tsv";
        if (NR == 1) {
          for (i=1; i <= NF; i++) {
             if (match($i, /^[0-9][0-9]\/[0-9][0-9]\/[0-9][0-9][0-9][0-9]/)) {
                dt_beg["yy"] = substr($i, 7);
                dt_beg["mm"] = substr($i, 1, 2);
                dt_beg["dd"] = substr($i, 4, 2);
                #printf("beg_date= mm.dd.yyyy %s.%s.%s\n", dt_beg["mm"], dt_beg["dd"], dt_beg["yy"]) > "/dev/stderr";
                break;
             }
          }
          next;
        }
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
        epoch = dt_to_epoch($1, $2, $0);
        if (ts_end > 0.0 && epoch > ts_end) {
            exit;
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
        sv_tm[mx_io] = epoch;
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
    $SCR_DIR/perf_stat_scatter.sh -b "$BEG"  -e "$END_TM"  -o "$OPTIONS"  -f $i -S $SUM_FILE > $i.tsv
   SHEETS="$SHEETS $i.tsv"
  fi

  if [[ $i == *"_interrupts.txt"* ]]; then
    echo "do interrupts"
# ==beg 0 date 1580278735.829557760
#            CPU0       CPU1       CPU2       CPU3       CPU4       CPU5       CPU6       CPU7       CPU8       CPU9       CPU10      CPU11      CPU12      CPU13      CPU14      CPU15      CPU16      CPU17      CPU18      CPU19      CPU20      CPU21      CPU22      CPU23      CPU24      CPU25      CPU26      CPU27      CPU28      CPU29      CPU30      CPU31      
#   0:        101          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0  IR-IO-APIC    2-edge      timer
#   3:          2          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0          0  IR-IO-APIC    3-edge    

    awk -v pfx="$PFX" '
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
       printf("hdrs\t%d\t0\t%d\t%d\t-1\n", 2+trows, -1, intr_num-drop_cols) > NFL;
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
#02:53:57    InKB   OutKB   InSeg  OutSeg Reset  AttF %ReTX InConn OutCon Drops
#TCP         0.00    0.00  6570.7  8893.4   161  23.2 0.000   6.10    117  0.00
#02:53:57                    InDG   OutDG     InErr  OutErr
#UDP                       2940.3  2952.9     11.53    0.00
#02:53:57      RdKB    WrKB   RdPkt   WrPkt   IErr  OErr  Coll  NoCP Defer  %Util
#eth0        2833.9  4123.3  4266.9  5099.8   0.00  0.00  0.00  0.00  0.00   0.14
#1581994437:TCP:0.000:0.000:6570.7:8893.4:160.7:23.16:0.000:6.102:117.5:0.000
#1581994437:UDP:2940.3:2952.9:11.53:0.000
#1581994437:eth0:2833.9:4123.3:4266.9:5099.8:0.14:0.01:0.00:0.00:0.00:0.00:0.00

  if [[ $i == *"_nicstat.txt"* ]]; then
    echo "do nicstat"
    awk -v beg_ts="$BEG" -v ts_end="$END_TM" -v pfx="$PFX" -v sum_file="$SUM_FILE" -v sum_flds="InKB{TCP_RdKB/s|network},OutKB{TCP_WrKB/s|network},RdKB{NetDev_RdKB/s|network},WrKB{NetDev_WrKB/s|network},IErr{NetDev_IErr/s|network},OErr{NetDev_OErr/s|network},%Util{NetDev_%Util|network}" '
     BEGIN{
        beg_ts += 0.0;
        ts_end += 0.0;
        n_sum = 0;
       if (sum_file != "" && sum_flds != "") {
         n_sum = split(sum_flds, sum_arr, ",");
         for (i_sum=1; i_sum <= n_sum; i_sum++) {
            sum_type[i_sum] = 1;
            str = sum_arr[i_sum];
            pos = index(str, "{");
            if (pos > 0) {
               pos1 = index(str, "}");
               if (pos1 == 0) { pos1= length(str)+1; }
               sum_str = substr(str, pos+1, pos1-pos-1);
               n_sum2 = split(sum_str, sum_arr2, "|");
               if (sum_arr2[1] != "") {
                 sum_prt[i_sum] = sum_arr2[1];
               } else {
                 #sum_prt[i_sum] = str;
                 sum_prt[i_sum] = substr(str, 1, pos-1);
               }
               if (sum_arr2[2] != "") {
                 sum_res[i_sum] = sum_arr2[2];
               }
               #sum_prt[i_sum] = substr(str, pos+1, pos1-pos-1);
               sum_arr[i_sum] = substr(str, 1, pos-1);
            } else {
               sum_prt[i_sum] = str;
            }
            if (index(str, "%") > 0) {
               sum_type[i_sum] = 0;
            }
         }
       }
     }
     {
        FNM=ARGV[ARGIND];
        if (index(FNM, ".txt.hdr") > 0) {
          if (match($1, /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/)) {
            # hdr row
            for (i=1; i <= NF; i++) {
              cols[i]=$i;
            }
            next;
          } else {
            idx = ++hdr_typs;
            hdr_typ[idx] = $1
            hdr_str[$1] = idx;
            hdr[idx,1] = $1;
            hdr_mx[idx] = NF;
            hdr_row[idx] = 0;
            for (j=2; j <= NF; j++) {
               hdr[idx,j] = cols[j];
            }
          }
        } else {
          NFL = FNM ".tsv";
          n   = split($0, arr, ":");
          ts  = arr[1];
          typ = arr[2];
          idx = hdr_str[typ];
          rw = ++hdr_row[idx];
          ts_row[idx,rw] = ts;
          for (j=3; j <= n; j++) {
            data[idx,rw,j-2] = arr[j];
          }
       }
     }
     END{
       row=-1;
       for (i=1; i <= hdr_typs; i++) {
          if (n_sum > 0) {
            for (k=1; k <= hdr_mx[i]; k++) {
              hdr_lkup[k] = -1;
            }
            for (k=2; k <= hdr_mx[i]; k++) {
              for (i_sum=1; i_sum <= n_sum; i_sum++) {
                 if (hdr[i,k] == sum_arr[i_sum]) {
                    hdr_lkup[k-1] = i_sum;
                    break; # so if hdr appears more than one in sum_flds, it will be skipped
                 }
              }
            }
          }
           row++;
           printf("title\tnicstat %s\tsheet\tnicstat %s\ttype\tscatter_straight\n", hdr_typ[i], hdr_typ[i]) > NFL;
           row++;
           printf("hdrs\t%d\t3\t%d\t%d\t2\n", 1+row, -1, hdr_mx[i]+1) > NFL;
           printf("type\tTimeStamp\tRel_TS") > NFL;
           for (j=2; j <= hdr_mx[i]; j++) {
             printf("\t%s", hdr[i,j]) > NFL;
           }
           row++;
           printf("\n") > NFL;
           for (rw=1; rw <= hdr_row[i]; rw++) {
              if (ts_end > 0.0 && ts_row[i,rw] > ts_end) {
                continue;
              }
              ts_diff = ts_row[i,rw]-beg_ts;
              if (ts_diff < 0.0) {continue;}
              printf("%s\t%.0f\t%.3f", hdr_typ[i], ts_row[i,rw], ts_row[i,rw]-beg_ts) > NFL;
              for (k=1; k <= hdr_mx[i]; k++) {
                 printf("\t%s", data[i,rw,k]) > NFL;
                 if (hdr_lkup[k] != -1) {
                   i_sum = hdr_lkup[k];
                   sum_occ[i_sum] += 1;
                   if (sum_type[i_sum] == 1) {
                     if (sum_tmin[i_sum] == 0) { sum_tmin[i_sum] = ts_row[i,rw]; sum_tmax[i_sum] = sum_tmin[i_sum]; }
                     if (sum_tmax[i_sum] < ts_row[i,rw]) { sum_tmax[i_sum] = ts_row[i,rw]; }
                     if (rw > 1) {intrvl = ts_row[i,rw] - ts_row[i,rw-1]; } else { intrvl = 1.0 };
                     sum_tot[i_sum] += data[i,rw,k] * intrvl;
                   } else {
                     sum_tot[i_sum] += data[i,rw,k];
                   }
                 }
              }
              row++;
              printf("\n") > NFL;
           }
           row++;
           printf("\n") > NFL;
       }
       close(NFL);
       if (n_sum > 0) {
          printf("got nicstat n_sum= %d\n", n_sum) >> "/dev/stderr";
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
             divi = sum_occ[i_sum];
             if (sum_type[i_sum] == 1) {
                divi = sum_tmax[i_sum] - sum_tmin[i_sum];
             }
             printf("%s\t%s\t%s\t%f\n", sum_res[i_sum], "nicstat", sum_prt[i_sum], (divi > 0 ? sum_tot[i_sum]/divi : 0.0)) >> sum_file;
          }
       }
   }
   ' $i.hdr $i
   SHEETS="$SHEETS $i.tsv"
  fi
done
OPT_END_TM=
if [ "$END_TM" != "" ]; then
  OPT_END_TM=" -e $END_TM "
fi
tst_files="latency_histo.log"
for f in $tst_files; do
  if [ -e $f ]; then
     echo "try latency log $f" > /dev/stderr
     $SCR_DIR/resp_2_tsv.sh -f $f -s $SUM_FILE $OPT_END_TM
     if [ -e $f.tsv ]; then
     SHEETS="$SHEETS $f.tsv"
     echo "got latency log $f.tsv" > /dev/stderr
     fi
  fi
done
tst_files="http-status.log"
for f in $tst_files; do
  if [ -e $f ]; then
     echo "try http-status log $f" > /dev/stderr
     $SCR_DIR/resp_2_tsv.sh -f $f -s $SUM_FILE  $OPT_END_TM
     if [ -e $f.tsv ]; then
     SHEETS="$SHEETS $f.tsv"
     echo "got http-status log $f.tsv" > /dev/stderr
     grep title $f.tsv > /dev/stderr
     fi
  fi
done
tst_files="RPS.log response_time.log"
for f in $tst_files; do
  if [ -e $f ]; then
     $SCR_DIR/resp_2_tsv.sh -f $f -s $SUM_FILE  $OPT_END_TM
     if [ -e $f.tsv ]; then
     SHEETS="$SHEETS $f.tsv"
     fi
  fi
done
GC_FILE=gc.log.0.current
if [ -e $GC_FILE ]; then
  $SCR_DIR/java_gc_log_2_tsv.sh -f $GC_FILE $OPT_END_TM  > $GC_FILE.tsv
  SHEETS="$SHEETS $GC_FILE.tsv"
fi
JAVA_COL=java.collapsed
if [ -e $JAVA_COL ]; then
  echo "do flamegraph.pl" 1>&2
  cat $JAVA_COL | perl $SCR_DIR/../flamegraph/flamegraph.pl --title "Flamegraph $RPS" > java.svg
  echo "do svg_to_html.sh " 1>&2
  $SCR_DIR/svg_to_html.sh -r 1 -d . -f java.svg > java.html
  inkscape -z  -w 2400 -j --export-file=java.png  java.svg
  $SCR_DIR/gen_flamegraph_for_java_in_container_function_hotspot.sh $JAVA_COL > $JAVA_COL.tsv
  SHEETS="$SHEETS $JAVA_COL.tsv"
fi
TOPLEV_COL=(sys_*_toplev.csv)
if [ -e $TOPLEV_COL ]; then
  echo "do flamegraph.pl" 1>&2
  #echo "do toplev % Slots" > /dev/stderr
  $SCR_DIR/toplev_flame.sh -u "% Slots" -f $TOPLEV_COL > $TOPLEV_COL.collapsed_slots
  cat $TOPLEV_COL.collapsed_slots | perl $SCR_DIR/../flamegraph/flamegraph.pl --title "Flamegraph toplev $RPS" > toplev_slots.svg
  echo "do svg_to_html.sh " 1>&2
  $SCR_DIR/svg_to_html.sh -r 1 -d . -f toplev_slots.svg > toplev_slots.html
  inkscape -z  -w 2400 -j --export-file=toplev_slots.png  toplev_slots.svg
  $SCR_DIR/gen_flamegraph_for_java_in_container_function_hotspot.sh $TOPLEV_COL > $TOPLEV_COL.tsv
  SHEETS="$SHEETS $TOPLEV_COL.tsv"
fi
if [ "$SUM_FILE" != "" ]; then
   SHEETS="$SUM_FILE $SHEETS"
   RESP=`cat $SUM_FILE`
   echo -e "$RESP" | awk -v sum_file="$SUM_FILE" '
     BEGIN{
       ;
       got_RPS=0;
       #printf("------do_sum_file= %s\n", sum_file) > "/dev/stderr";
     }
     {
        lns[++lns_mx] = $0;
        n = split($0, arr, "\t");
        if (arr[2] == "RPS") {
          got_RPS=1;
          RPS = arr[4];
          if (substr(RPS, 1,1) == "=") {
            RPS = substr(RPS, 2, length(RPS)) + 0.0;
          }
        }
        #printf("%s\taa\n", $0);
     }
     END {
       beg = 0;
       for (i=1; i <= lns_mx; i++) {
        n = split(lns[i], arr, "\t");
        if (arr[1] == "hdrs") {
           beg = 1;
           arr[5] = 7;
        }
        if (arr[1] == "Resource") {
           if (got_RPS == 1) {
              arr[7] = "Val/1000_requests";
              n=7;
              printf("-----got_RPS= %s\n", got_RPS) > "/dev/stderr";
           }
        }
        if (beg == 1) {
          if (arr[1] != "Resource") {
          val = arr[4];
          if (substr(val, 1,1) == "=") {
            val = substr(val, 2, length(val));
          }
          arr[7] = "";
          if (got_RPS == 1 && RPS > 0.0 && index(arr[3], "/s") > 1) {
            nval = val / (0.001*RPS);
            arr[7] = nval;
            n = 7;
          }
          }
          printf("%s", arr[1]) > sum_file;
          for(j=2; j <= n; j++) {
            str = "";
            if (j==7 && arr[7] != "" && arr[1] != "Resource") { str = "=";}
            printf("\t%s%s", str, arr[j]) > sum_file;
          }
          printf("\n") > sum_file;
        } else {
          printf("%s\n", lns[i]) > sum_file;
        }
       }
       #close(sum_file);
     }
   ' 
fi
if [ "$SHEETS" != "" ]; then
   OPT_PH=
   if [ "$PHASE_FILE" != "" ]; then
     OPT_PH=" -P $PHASE_FILE "
   fi
   echo "python $SCR_DIR/tsv_2_xlsx.py $SHEETS" > /dev/stderr
   echo python $SCR_DIR/tsv_2_xlsx.py -s 2,2 -p "$PFX" -o $XLSX_FILE $OPT_PH -i "$IMAGE_STR" $SHEETS > /dev/stderr
   # default chart size is pretty small, scale chart size x,y by 2 each. def 1,1 seems to be about 15 rows high (on my MacBook)
   python $SCR_DIR/tsv_2_xlsx.py -s 2,2 -p "$PFX" -o $XLSX_FILE $OPT_PH -i "$IMAGE_STR" $SHEETS
   if [ "$DIR" == "." ];then
     UDIR=`pwd`
   else
     UDIR=$DIR
   fi
   echo "xls file: " > /dev/stderr
   echo "$UDIR/$XLSX_FILE" > /dev/stderr
fi

