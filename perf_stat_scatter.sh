/#!/bin/bash

# arg1 is prf stat file
# arg2 (optional) is specint .log
# for example:
# ../perf_stat_scatter.sh B20a_specint_prf/prf_data_specint.txt B20a_specint_prf/20-01-15_130627_specint/result/CPU2017.001.log  > tmp.tsv
FILES=
SPECINT_LOG=
CHART_IN=
SHEET_IN=
PFX_IN=
OPTIONS=
BEG=
SUM_FILE=
END_TM=

while getopts "hvb:c:e:f:o:p:s:S:l:" opt; do
  case ${opt} in
    b )
      BEG=$OPTARG
      ;;
    c )
      CHART_IN=$OPTARG
      ;;
    e )
      END_TM=$OPTARG
      ;;
    p )
      PFX_IN=$OPTARG
      ;;
    s )
      SHEET_IN=$OPTARG
      ;;
    S )
      SUM_FILE=$OPTARG
      ;;
    o )
      if [[ $OPTARG == *"dont_sum_sockets"* ]]; then
        OPTIONS=$OPTARG
      else
        if [[ $OPTARG == *"chart_new"* ]]; then
           OPTIONS=$OPTARG
        else
        if [ "$OPTARG" != "" ]; then
          echo "sorry but only -o option supported now is '-o dont_sum_sockets'. You entered -o $OPTARG"
          exit
        fi
        fi
      fi
      ;;
    f )
      if [ "$OPTARG" == "" ]; then
         echo "option -f requires a filename arg"
         exit
      fi
      if [ ! -e $OPTARG ]; then
         echo "option \"-f $OPTARG\" didn't find file $OPTARG"
         exit
      fi
      FILES="$FILES $OPTARG"
      ;;
    l )
      if [ "$OPTARG" == "" ]; then
         echo "option -l requires a filename arg"
         exit
      fi
      if [ ! -e $OPTARG ]; then
         echo "option \"-l $OPTARG\" didn't find file $OPTARG"
         exit
      fi
      SPECINT_LOG=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 split perf stat data files into columns"
      echo "Usage: $0 [-h] -f perf_stat_txt_file [ -f ...] [ -s sheetname ] [ -p prefix ] [ -c chart_name ] [ -l specInt_logfile ] [-v]"
      echo "   -f perf_stat_txt_file  perf stat data file"
      echo "      currently only 1 '-f filename' option is supported"
      echo "   -c chart title. Used by tsv_2_xlsx.py"
      echo "   -e end_timestamp. drop data after this timestamp"
      echo "   -o options_str  Currently only option is \"dont_sum_sockets\" to not sum S0 & S1 to the system"
      echo "   -p prefix_str.  prefix each sheet name with this string."
      echo "   -s sheet_name.  Used by tsv_2_xlsx.py. string has to comply with Excel sheet name rules"
      echo "   -S sum_file     Output summary stats to this file"
      echo "   -l SpecInt CPU2017 log (like result/CPU2017.001.log)"
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

CHART="perf stat"
if [ "$CHART_IN" != "" ]; then
  CHART=$CHART_IN
fi

SHEET="perf stat"
if [ "$SHEET_IN" != "" ]; then
  SHEET=$SHEET_IN
fi

# didn't collect lscpu.log for most of the data
TSC_FREQ="2.1"
THR_PER_CORE=2
LSCPU_FL="lscpu.log lscpu.txt"
for i in $LSCPU_FL; do
  if [ -e $i ]; then
    TSC_FREQ=`cat $i |awk '/^Model name/{for (i=1;i<=NF;i++){pos=index($i, "GHz");if (pos > 0){print substr($i,1,pos-1);}}}'`
    NUM_CPUS=`cat $i |awk '/^CPU.s.:/{printf("%s\n",$2);}'`
    THR_PER_CORE=`cat $i |awk '/^Thread.s. per core:/{printf("%s\n",$4);}'`
    #CPU(s):                32
  fi
done
echo "TSC_FREQ= $TSC_FREQ NUM_CPUS= $NUM_CPUS" > /dev/stderr


awk -v thr_per_core="$THR_PER_CORE" -v num_cpus="$NUM_CPUS" -v ts_beg="$BEG" -v ts_end="$END_TM" -v tsc_freq="$TSC_FREQ" -v pfx="$PFX_IN" -v options="$OPTIONS" -v chrt="$CHART" -v sheet="$SHEET" -v sum_file="$SUM_FILE" -v sum_flds="unc_read_write{Mem BW GB/s/skt|memory},LLC-misses PKI{|memory},IPC{InstPerCycle|CPU},%not_halted{|CPU},avg_freq{avg_freq GHz|CPU},QPI_BW{QPI_BW GB/s/skt|memory interconnect},Instructions*1e-9/s{Instructions*1e-9/s/skt|CPU}" 'BEGIN{
     row=0;
     evt_idx=-1;
     months="  JanFebMarAprMayJunJulAugSepOctNovDec";
     date_str="";
     ts_initial = 0.0;
     ts_beg += 0.0;
     ts_end += 0.0;
     num_cpus += 0;
     st_beg=0; 
     st_mx=0;
     ts_prev = 0.0;
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
            printf("got sum_arr[%d]= %s, prt= %s\n", i_sum, sum_arr[i_sum], sum_prt[i_sum]) > "/dev/stderr";
         }
       }
  }
  function do_summary(colms, v, epch, intrvl) {
     if (n_sum > 0 && hdr_lkup[colms] != -1) {
        i_sum = hdr_lkup[colms];
        sum_occ[i_sum] += 1;
        #printf("colms= %d, v= %f, epch= %f, intrvl= %f, i_sum= %d typ= %d\n", colms, v, epch, intrvl, i_sum, sum_type[i_sum]) >> sum_file;
        if (sum_type[i_sum] == 1) {
           if (sum_tmin[i_sum] == 0)   { sum_tmin[i_sum] = epch; sum_tmax[i_sum] = sum_tmin[i_sum]; }
           if (sum_tmax[i_sum] < epch) { sum_tmax[i_sum] = epch; }
           sum_tot[i_sum] += v * intrvl;
        } else {
           sum_tot[i_sum] += v;
        }
     }
  }
  function dt_to_epoch(offset) {
   # started on Tue Dec 10 23:23:30 2019
   # Dec 10 23:23:30 2019
     if (date_str == "") {
        return 0.0;
     }
     n=split(date_str, darr, /[ :]+/);
     #for(i in darr) printf("darr[%d]= %s\n", i,  darr[i]);
     mnth_num = sprintf("%d", index(months, darr[1])/3);
     #printf("mnth_num= %d\n", mnth_num);
     dt_str = darr[6] " " mnth_num " " darr[2] " " darr[3] " " darr[4] " " darr[5];
     #printf("dt_str= %s\n", dt_str);
     epoch = mktime(dt_str);
     #printf("epoch= %s offset= %s\n", epoch, offset);
     return epoch + offset;
  }
  FILENAME==ARGV[2]{
     #/^Issuing command .*\/benchspec\/.* -f speccmds.cmd / 
  if (match($0, /^Issuing command .*\/benchspec\/.* -f speccmds.cmd /) == 1) {
    #printf("got %s\n", $0);
    n = split($0, arr, /\//);
    for (i=1; i < n; i++) {
      #printf("arr[%d]= %s\n", i, arr[i]);
      if (arr[i] == "CPU") {
       sub_test = arr[i+1];
       #printf("sub_test= %s\n", sub_test);
       break;
      }
    }
    getline;
    if (index($0, "Start command: ") == 1) {
      n = split($0, arr, /[()]/);
      beg = arr[2];
      #printf("beg= %s\n",beg);
      getline;
      if (index($0, "Stop command: ") == 1) {
        n = split($0, arr, /[()]/);
        end = arr[2];
        ++st_mx;
        st_sv[st_mx,1]=sub_test;
        st_sv[st_mx,2]=beg+0.0;
        st_sv[st_mx,3]=end+0.0;
      printf("%f\t%s\n", st_sv[st_mx,2], st_sv[st_mx,1]);
        next;
      }
    }
    next;
  } else {
    next;
  }
  }

  /^# started on / {
# started on Fri Jun 12 14:36:31 UTC 2020 1591972591.618156223
# started on Fri Jun 12 14:36:31 2020
    pos = index($0, " on ")+8;
    if (date_str != "") {
       # I prepend a more complete date time stamp as the first line
       next;
    }
    date_str = substr($0, pos);
    if ($8 == "UTC") {
       if (NF == 10) {
          ts_initial = $10+0;
       }
       date_str = $5 " " $6 " " $7 " " $9;
    }
    #printf("data_str = '%s'\n", date_str);
    tst_epoch = dt_to_epoch(0.0);
    #printf("tst_epoch= %s\n", tst_epoch);
# works
#   darr[1]= Dec
#   darr[2]= 12
#   darr[3]= 10
#   darr[4]= 38
#   darr[5]= 31
#   darr[6]= 2019
#   dt_str= 2019 12 12 10 38 31
#   epoch= 1576175911 offset= 0
#   tst_epoch= 1576175911
# fails
#   darr[1]= Jan
#   darr[2]= 
#   darr[3]= 6
#   darr[4]= 13
#   darr[5]= 36
#   darr[6]= 55
#   darr[7]= 2020
#   dt_str= 55 1  6 13 36
#   epoch= -1 offset= 0
#   tst_epoch= -1
    next;
  }
  /;/{
#          1        2          3   4          5           6
# 120.003961364;1919857.169339;;cpu-clock;1919864513706;100.00;;

#          1    2  3     4       5    6            7           8   9     10
#  1.004420989;S1;16;30384313506;;instructions;16051372488;100.00;0.84;insn per cycle

   n=split($0,arr,";");
   ts=arr[1];
   skt=arr[2];
   skt_incr = 2;
   if (skt != "S0" && skt != "S1" && skt != "S2" && skt != "S3") {
     skt="S0";
     skt_incr = 0;
     inst = num_cpus;
     if (options != "" && index(options, "dont_sum_sockets") > 0) {
         printf("options before= %s\n", options) > "/dev/stderr";
         gsub("dont_sum_sockets", "", options);
         printf("options after = %s\n", options) > "/dev/stderr";
         printf("ts_end= %s\n", ts_end) > "/dev/stderr";
     }
   } else {
     inst=arr[3];
   }
   val=arr[2+skt_incr];
   evt=arr[4+skt_incr];
   if (evt == "") {
     next;
   }
   if (options != "" && skt_inc != 0 && index(options, "dont_sum_sockets") > 0) {
      evt = evt " " skt;
   }
   tmr=arr[5+skt_incr];
   pct=arr[6+skt_incr];
   if ( ck_row[ts,skt] != ts","skt) {
      row++;
      ck_row[ts,skt] = ts","skt;
   }
   if ( skts[skt] != skt) {
     skts[skt] = skt;
     skt_idx++;
     skt_num[skt]=skt_idx;
     skt_lkup[skt_idx]=skt;
   }
   if ( evts[evt] != evt) {
     evts[evt] = evt;
     evt_idx++;
     evt_num[evt]=evt_idx;
     evt_lkup[evt_idx]=evt;
     evt_inst[evt_idx]=0;
     evt_inst_ts[evt_idx]=ts;
   }
   j=evt_num[evt];
   if (ts_initial > 0.0) {
      epch = ts_initial + ts;
   } else {
      epch = dt_to_epoch(ts);
   }
   if (evt_inst_ts[j] == ts) {
     if (evt_inst[j] == 0 || inst > 1){ # if summing per socket events, then summing to system, just put 1 for instance
        evt_inst[j] += inst;
     }
   }
     
   sv[row,0]=epch;
   sv[row,1]=ts;
   sv[row,2]=skt;
   hdr[3+j*2]=evt;
   sv[row,3+j]=val;
   #if (row < 8) {printf("row= %d, j= %d, evt= %s, val= %s\n", row, j, evt, val);}
   }
   END{
    #for (ii=1; ii <= st_mx; ii++) {
    #  printf("%s\t%f\t%f\n", st_sv[ii,1], st_sv[ii,2], st_sv[ii,3]);
    #}
     kmx = 1;
     got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
     got_lkfor[kmx,2]=6; # num of fields to look for
     got_lkfor[kmx,3]=64e-9; # a factor
     got_lkfor[kmx,4]="sum"; # operation
     got_lkfor[kmx,5]=1; # instances
     got_lkfor[kmx,6]="div_by_interval"; # 
     got_lkfor[kmx,"typ_match"]="require_any"; # 
     lkfor[kmx,1]="unc0_read_write";
     lkfor[kmx,2]="unc1_read_write";
     lkfor[kmx,3]="unc2_read_write";
     lkfor[kmx,4]="unc3_read_write";
     lkfor[kmx,5]="unc4_read_write";
     lkfor[kmx,6]="unc5_read_write";
     nwfor[kmx,1]="unc_read_write (GB/s)";

     kmx++;
     got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
     got_lkfor[kmx,2]=2; # num of fields to look for
     got_lkfor[kmx,3]=1000.0; # a factor
     got_lkfor[kmx,4]="div"; # operation
     got_lkfor[kmx,5]=1; # instances
     lkfor[kmx,1]="LLC-load-misses";
     lkfor[kmx,2]="instructions";
     nwfor[kmx,1]="LLC-misses PKI";

     kmx++;
     got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
     got_lkfor[kmx,2]=2; # num of fields to look for
     got_lkfor[kmx,3]=1.0; # a factor
     got_lkfor[kmx,4]="div"; # operation
     got_lkfor[kmx,5]=1; # instances
     lkfor[kmx,1]="instructions";
     lkfor[kmx,2]="cycles";
     nwfor[kmx,1]="IPC";

     kmx++;
     got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
     got_lkfor[kmx,2]=2; # num of fields to look for
     got_lkfor[kmx,3]=100.0/(tsc_freq*1.0e9); # a factor
     got_lkfor[kmx,4]="div"; # operation x/y
     got_lkfor[kmx,5]=1; # instances
     got_lkfor[kmx,6]="div_by_interval"; # 
     lkfor[kmx,1]="ref-cycles";
     lkfor[kmx,2]="instances";  # get the instances from the first lkfor event
     nwfor[kmx,1]="%not_halted";

     kmx++;
     got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
     got_lkfor[kmx,2]=2; # num of fields to look for
     got_lkfor[kmx,3]=1.0e-9; # a factor
     got_lkfor[kmx,4]="div"; # operation x/y/z
     got_lkfor[kmx,5]=1; # instances
     got_lkfor[kmx,6]="div_by_non_halted_interval"; # 
     lkfor[kmx,1]="cycles";
     lkfor[kmx,2]="instances";  # get the instances from the first lkfor event
     nwfor[kmx,1]="avg_freq (GHz)";

     kmx++;
     got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
     got_lkfor[kmx,2]=1; # num of fields to look for
     got_lkfor[kmx,3]=1e-9; # a factor
     got_lkfor[kmx,4]="sum"; # operation
     got_lkfor[kmx,5]=1; # instances
     got_lkfor[kmx,6]="div_by_interval"; # 
     lkfor[kmx,1]="qpi_data_bandwidth_tx";
     nwfor[kmx,1]="QPI_BW (GB/sec)";

     kmx++;
     got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
     got_lkfor[kmx,2]=3; # num of fields to look for
     got_lkfor[kmx,3]=8.0e-9; # a factor
     got_lkfor[kmx,4]="sum"; # operation
     got_lkfor[kmx,5]=1; # instances
     got_lkfor[kmx,6]="div_by_interval"; # 
     got_lkfor[kmx,"typ_match"]="require_any"; # 
     lkfor[kmx,1]="qpi0_data_bandwidth_tx";
     lkfor[kmx,2]="qpi1_data_bandwidth_tx";
     lkfor[kmx,3]="qpi2_data_bandwidth_tx";
     nwfor[kmx,1]="QPI_BW (GB/sec)";

     kmx++;
     got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
     got_lkfor[kmx,2]=1; # num of fields to look for
     got_lkfor[kmx,3]=1.0; # a factor
     got_lkfor[kmx,4]="sum"; # operation
     got_lkfor[kmx,5]=1; # instances
     got_lkfor[kmx,6]="div_by_interval"; # 
     lkfor[kmx,1]="power/energy-pkg/";
     nwfor[kmx,1]="power_pkg (watts)";

     kmx++;
     got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
     got_lkfor[kmx,2]=1; # num of fields to look for
     got_lkfor[kmx,3]=1.0e-9; # a factor
     got_lkfor[kmx,4]="sum"; # operation
     got_lkfor[kmx,5]=1; # instances
     got_lkfor[kmx,6]="div_by_interval"; # 
     lkfor[kmx,1]="instructions";
     nwfor[kmx,1]="Instructions*1e-9/s)";

#                        "name"       : "metric_TMAM_Frontend_Bound(%)",
#                        "expression" : "100 * [IDQ_UOPS_NOT_DELIVERED.CORE] / (4 * ([cpu-cycles] / [const_thread_count]))"
     kmx++;
     got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
     got_lkfor[kmx,2]=2; # num of fields to look for
     got_lkfor[kmx,3]=25.0*thr_per_core; # a factor 100.0 / 4
     got_lkfor[kmx,4]="div"; # operation x/y/z
     got_lkfor[kmx,5]=1; # instances
     got_lkfor[kmx,6]=""; # 
     lkfor[kmx,1]=tolower("IDQ_UOPS_NOT_DELIVERED.CORE");
     lkfor[kmx,2]="cycles";  # get the instances from the first lkfor event
     nwfor[kmx,1]="TMAM_Frontend_Bound(%)";

#                        "name"       : "metric_TMAM_Retiring(%)",
#                        "expression" : "100 * [UOPS_RETIRED.RETIRE_SLOTS] / (4 * ([CPU_CLK_UNHALTED.THREAD_ANY] / [const_thread_count]))"
     kmx++;
     got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
     got_lkfor[kmx,2]=2; # num of fields to look for
     got_lkfor[kmx,3]=25.0*thr_per_core; # a factor 100.0 / 4
     got_lkfor[kmx,4]="div"; # operation x/y/z
     got_lkfor[kmx,5]=1; # instances
     got_lkfor[kmx,6]=""; # 
     lkfor[kmx,1]=tolower("UOPS_RETIRED.RETIRE_SLOTS");
     lkfor[kmx,2]=tolower("CPU_CLK_UNHALTED.THREAD_ANY");  # get the instances from the first lkfor event
     nwfor[kmx,1]="TMAM_Retiring(%)";

     kmx++;
     got_lkfor[kmx,1]=0; # 0 if no fields found or 1 if 1 or more of these fields found
     got_lkfor[kmx,2]=4; # num of fields to look for
     got_lkfor[kmx,3]="=100 - (INDIRECT(ADDRESS(ROW(), COLUMN()-2, 4)) +INDIRECT(ADDRESS(ROW(), COLUMN()-1, 4)))"; # 
     got_lkfor[kmx,4]="formula"; # operation x/y/z
     got_lkfor[kmx,5]=1; # instances
     got_lkfor[kmx,6]=""; # 
     lkfor[kmx,1]=tolower("UOPS_RETIRED.RETIRE_SLOTS");
     lkfor[kmx,2]=tolower("CPU_CLK_UNHALTED.THREAD_ANY");  # get the instances from the first lkfor event
     lkfor[kmx,3]=tolower("IDQ_UOPS_NOT_DELIVERED.CORE");
     lkfor[kmx,4]="cycles";  # get the instances from the first lkfor event
     nwfor[kmx,1]="TMAM_Backend_Bound_BadSpec(%)";


     if (options != "" && index(options, "dont_sum_sockets") > 0) {
       kmx_nw = kmx;
       for (k=1; k <= kmx; k++) { 
          got_it=0;
          for (kk=1; kk <= got_lkfor[k,2]; kk++) {
             if (lkfor[k,kk] != "interval" && lkfor[k,kk] != "instances") {
               got_it = 1;
               break;
             }
          }
          if (got_it == 1) {
            for (sk=2; sk <= skt_idx; sk++) {
              #skt_lkup[skt_idx]=skt;
              kmx_nw++;
              got_lkfor[kmx_nw,1]= got_lkfor[k,1];
              got_lkfor[kmx_nw,2]= got_lkfor[k,2];
              got_lkfor[kmx_nw,3]= got_lkfor[k,3];
              got_lkfor[kmx_nw,4]= got_lkfor[k,4];
              got_lkfor[kmx_nw,5]= got_lkfor[k,5];
              got_lkfor[kmx_nw,6]= got_lkfor[k,6];
              got_lkfor[kmx_nw,"typ_match"]= got_lkfor[k,"typ_match"];
              got_lkfor[kmx_nw,7]= sk; # skt_idx
              got_lkfor[kmx_nw,8]= nwfor[k,1]; # save off original result name so we only have to ck 1 name
              for (kk=1; kk <= got_lkfor[k,2]; kk++) {
                 if (lkfor[k,kk] != "interval" && lkfor[k,kk] != "instances") {
                   lkfor[kmx_nw,kk]=lkfor[k,kk] " " skt_lkup[sk];
                 } else {
                   lkfor[kmx_nw,kk]=lkfor[k,kk];
                 }
              }
              nwfor[kmx_nw,1]=nwfor[k,1] " " skt_lkup[sk];
            }
            for (kk=1; kk <= got_lkfor[k,2]; kk++) {
               if (lkfor[k,kk] != "interval" && lkfor[k,kk] != "instances") {
                   lkfor[k,kk]=lkfor[k,kk] " " skt_lkup[1];
               }
            }
            got_lkfor[k,7]= 1; # skt idx
            got_lkfor[k,8]= nwfor[k,1]; # save off original result name so we only have to ck 1 name
            nwfor[k,1]=nwfor[k,1] " " skt_lkup[1];
          }
       }
       kmx = kmx_nw;
     }

     NO_MATCH = -1000;
     for (k=1; k <= kmx; k++) { 
         for (j=1; j <= got_lkfor[k,2]; j++) { 
             lkup[k,j] = NO_MATCH;
         }
     }
     for(i=0; i <= evt_idx; i++) {
       for (k=1; k <= kmx; k++) { 
         for (j=1; j <= got_lkfor[k,2]; j++) { 
           if (evt_lkup[i] == lkfor[k,j]) {
             lkup[k,j] = i
             got_lkfor[k,1]++;
           }
         }
       }
     }
     extra_cols=0;
     for (k=1; k <= kmx; k++) { 
       for (j=1; j <= got_lkfor[k,2]; j++) { 
         if ("interval" == lkfor[k,j]) {
             lkup[k,j] = -1
             got_lkfor[k,1]++;
         }
         if ("instances" == lkfor[k,j]) {
             lkup[k,j] = -2
             got_lkfor[k,1]++;
         }
         #if (nwfor[k,1] == lkfor[k,j]) {
         #    lkup[k,j] = -100-k
         #    got_lkfor[k,1]++;
         #}
       }
       if (got_lkfor[k,1] == got_lkfor[k,2] || (got_lkfor[k,"typ_match"] == "require_any" && got_lkfor[k,1] > 0)) {
          extra_cols++;
       }
     }

#abcd
     printf("epoch\tts\trel_ts\tinstances:");
     for(i=0; i <= evt_idx; i++) {
       printf("\t%s", evt_inst[i]);
     }
     for (k=1; k <= kmx; k++) { 
       if (got_lkfor[k,1] == got_lkfor[k,2] || (got_lkfor[k,"typ_match"] == "require_any" && got_lkfor[k,1] > 0)) {
          printf("\t%s", got_lkfor[k,5]);
       }
     }
     rows=1;
     printf("\n");
     rows++;
     printf("title\t%s\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet);
     bcol = 4;
     if (options != "" && index(options, "chart_new") > 0 && extra_cols > 0) {
       bcol += evt_idx;
     }
     printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", rows+1, bcol+1, -1, evt_idx+extra_cols+4, 2);
#title	sar network IFACE dev eth0	sheet	sar network IFACE	type	line
#hdrs	8	0	68	8
     bw_cols_mx = 0;
     ipc_cols_mx = 0;not_halted
     unhalted_cols_mx = 0;
     col_hdr[0] = "epoch";
     col_hdr[1] = "ts";
     col_hdr[2] = "rel_ts";
     col_hdr[3] = "interval";
     printf("epoch\tts\trel_ts\tinterval");
     cols = 4;
     for(i=0; i <= evt_idx; i++) {
       printf("\t%s", evt_lkup[i]);
       col_hdr[cols] = evt_lkup[i];
       cols++;
     }
     for (k=1; k <= kmx; k++) { 
       if (got_lkfor[k,1] == got_lkfor[k,2] || (got_lkfor[k,"typ_match"] == "require_any" && got_lkfor[k,1] > 0)) {
          printf("\t%s", nwfor[k,1]);
          col_hdr[cols] = nwfor[k,1];
          if (index(nwfor[k,1], "GB/s") > 0) {
            bw_cols[++bw_cols_mx] = cols;
          }
          if (index(nwfor[k,1], "not_halted") > 0) {
            unhalted_cols[++unhalted_cols_mx] = cols;
          }
          if (index(nwfor[k,1], "not_halted") > 0 || index(nwfor[k,1], "TMAM") > 0 || index(nwfor[k,1], "power_pkg (watts)") > 0) {
            TMAM_cols[++TMAM_cols_mx] = cols;
          }
          if (index(nwfor[k,1], "IPC") > 0 || index(nwfor[k,1], "GHz") > 0 || index(nwfor[k,1], "PKI") > 0) {
            ipc_cols[++ipc_cols_mx] = cols;
          }
          cols++;
       }
     }
     printf("\n");
     col_hdr_mx = cols;
     if (n_sum > 0) {
            for (k=0; k <= col_hdr_mx; k++) {
              hdr_lkup[k] = -1;
            }
            for (k=0; k <= col_hdr_mx; k++) {
              #printf("ck col_hdr[%d]= %s\n", k, col_hdr[k]) > "/dev/stderr";
              for (i_sum=1; i_sum <= n_sum; i_sum++) {
                 if (index(col_hdr[k], sum_arr[i_sum]) > 0) {
                    hdr_lkup[k] = i_sum;
                    printf("match col_hdr[%d]= %s with sum_arr[%d]= %s\n", k, col_hdr[k], i_sum, sum_arr[i_sum]) > "/dev/stderr";
                 }
              }
            }
     }
     epoch_next=0;
     ts_prev = 0.0;
     printf("perf stat rows= %d, skt_incr= %d, ts_beg= %f, ts_end= %f\n", row, skt_incr, ts_beg, ts_end) > "/dev/stderr";
     for(i=1; i <= row; i++) {
       if (skt_incr != 0 && sv[i,2] == "S0" && i < row) {
           # sum each evt to s0 for now
           for(ii=i+1; ii <= row; ii++) {
             if (sv[ii,1] != sv[i,1]) { 
                epoch_next=sv[ii,0];
                break;
             }
             for(j=0; j <= evt_idx; j++) {
                sv[i,3+j] += sv[ii,3+j];
             }
           }
       }
       if (skt_incr != 0 && sv[i,2] != "S0") {
         continue;
       }
       interval = sv[i,1] - ts_prev;
       ts_prev = sv[i,1]
       use_epoch = sv[i,0];
       #if (ts_beg > 0.0 && use_epoch < ts_beg) {
          #continue; # TBD, this is a different use of tm_beg
       #}
       if (ts_beg > 0.0) {
          use_epoch = ts_beg + sv[i,1];
       }
       if (ts_end > 0.0 && use_epoch > ts_end) {
         continue;
       }
       printf("%.4f\t%s\t%s\t%.4f", use_epoch, sv[i,1], sv[i,1], interval);
       cols = 4;
       for (k=1; k <= kmx; k++) { 
         sum[k]=0.0;
         numer[k]=0.0;
         denom[k]=0.0;
         for(j=0; j <= evt_idx; j++) {
           if (k == 1) {
             printf("\t%s", sv[i,3+j]);
             do_summary(cols, sv[i,3+j]+0.0, use_epoch+0.0, interval);
             cols++;
           }
           if (got_lkfor[k,4] == "sum") {
             for (kk=1; kk <= got_lkfor[k,2]; kk++) { 
               if (lkup[k,kk] == NO_MATCH) { continue; }
               if (lkup[k,kk] == j) {
                 sum[k] += sv[i,3+j];
               }
               if (lkup[k,kk] == -1) {
                 sum[k] += interval;
               }
               if (lkup[k,kk] == -2) {
                 aaa = lkup[k,1];
                 sum[k] += evt_inst[aaa]; # instances
               }
             }
           }
           if (got_lkfor[k,4] == "div") {
             if (lkup[k,1] == j) { numer[k] = sv[i,3+j]; }
             if (lkup[k,2] == j) { denom[k] = sv[i,3+j]; }
             if (lkup[k,1] == -1) { numer[k] = interval; }
             if (lkup[k,2] == -1) { denom[k] = interval; }
             if (lkup[k,1] == -2) { numer[k] = evt_inst[lkup[k,1]]; }
             if (lkup[k,2] == -2) { denom[k] = evt_inst[lkup[k,1]]; }
           }
         }
       }
       for (sk=1; sk <= skt_idx; sk++) { not_halted_fctr[sk] = 0.0; }
       for (k=1; k <= kmx; k++) { 
         prt_it=0;
         if ((got_lkfor[k,4] == "div" || got_lkfor[k,4] == "div_and_by_interval") && got_lkfor[k,1] == got_lkfor[k,2]) {
           val = numer[k]/denom[k] * got_lkfor[k,3];
           if (got_lkfor[k,4] == "div_and_by_interval") {
             val /= interval;
           }
           prt_it=1;
         }

         if (got_lkfor[k,4] == "sum" && got_lkfor[k,1] > 0) {
           val = sum[k] * got_lkfor[k,3];
           prt_it=1;
         }
         if (prt_it == 1) {
           if (got_lkfor[k,6] == "div_by_interval") {
              val = val / interval;
           }
           if (index(nwfor[k,1], "%not_halted") == 1) {
             #printf("%not_halted 03: prt_it= %s got_lkfor[%d,%s]= %s\n", prt_it, k, 7, got_lkfor[k,7]) > "/dev/stderr";
             sk = got_lkfor[k,7];
             if (sk == "") { sk= 1; }
             not_halted_fctr[sk] = val/100.0;
             #printf("b sk= %d, nhf= %f\n", sk, not_halted_fctr[sk]) > "/dev/stderr";
           }
         }
       }
       for (k=1; k <= kmx; k++) { 
         prt_it=0;
         if (got_lkfor[k,4] == "div" && got_lkfor[k,1] == got_lkfor[k,2]) {
           val = numer[k]/denom[k] * got_lkfor[k,3];
           prt_it=1;
         }

         if (got_lkfor[k,4] == "sum" && got_lkfor[k,1] > 0) {
           val = sum[k] * got_lkfor[k,3];
           prt_it=1;
         }
         if (got_lkfor[k,4] == "formula" && got_lkfor[k,1] > 0) {
           val =  got_lkfor[k,3];
           prt_it=1;
         }
         if (prt_it == 1) {
           if (got_lkfor[k,6] == "div_by_interval") {
              val = val / interval;
           }
           if (index(newfor[k,1],"%not_halted") == 1) {
             sk = got_lkfor[k,7];
              if (sk == "") { sk= 1; }
             not_halted_fctr[sk] = val/100.0;
             #printf("b sk= %d, nhf= %f\n", sk, not_halted_fctr[sk]) > "/dev/stderr";
           }
           if (got_lkfor[k,6] == "div_by_non_halted_interval") {
              sk = got_lkfor[k,7];
              if (sk == "") { sk= 1; }
             #not_halted_fctr[sk] = val/100.0;
              nhf = not_halted_fctr[sk];
             #printf("a sk= %s, nhf= %f, skt_idx= %s interval= %f\n", sk, not_halted_fctr[sk], skt_idx, interval) > "/dev/stderr";
              val = val / (interval*nhf);
           }
           printf("\t%s", val);
           do_summary(cols, val+0.0, use_epoch+0.0, interval);
           cols++;
         }
       }
       if (st_mx > 0 && i < row && sv[i,0]+0.0 > 0 && st_sv[1,2]+0.0 > 0.0) {
          epb = sv[i,0]+0;
          epe = epoch_next+0;
          #printf("epb= %f, epe= %f, st_mx= %d\n", epb, epe, st_mx);
          for (ii=1; ii < st_mx; ii++) {
            if (epb <= st_sv[ii,2] && st_sv[ii,2] < epe) {
		printf("\t%s", st_sv[ii,1]);
                do_summary(cols, st_sv[ii,1]+0.0, use_epoch+0.0, interval);
                cols++;
                break;
            }
          }
       }
       printf("\n");
     }
     if (TMAM_cols_mx > 0) {
       printf("\ntitle\t%s Top Lev: %%cpus Back/Front End Bound, Retiring\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet);
       printf("hdrs\t%d\t%d\t%d\t%d\t%d", rows+1, bcol+1, -1, evt_idx+extra_cols+4, 2);
       for (i=1; i <= TMAM_cols_mx; i++) {
         printf("\t%d\t%d", TMAM_cols[i], TMAM_cols[i]);
       }
       printf("\n");
     }
     if (bw_cols_mx > 0) {
       printf("\ntitle\t%s mem bw\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet);
       printf("hdrs\t%d\t%d\t%d\t%d\t%d", rows+1, bcol+1, -1, evt_idx+extra_cols+4, 2);
       for (i=1; i <= bw_cols_mx; i++) {
         printf("\t%d\t%d", bw_cols[i], bw_cols[i]);
       }
       printf("\n");
     }
     if (ipc_cols_mx > 0) {
       printf("\ntitle\t%s mem IPC, CPU freq, LLC misses\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet);
       printf("hdrs\t%d\t%d\t%d\t%d\t%d", rows+1, bcol+1, -1, evt_idx+extra_cols+4, 2);
       for (i=1; i <= ipc_cols_mx; i++) {
         printf("\t%d\t%d", ipc_cols[i], ipc_cols[i]);
       }
       printf("\n");
     }
     if (unhalted_cols_mx > 0) {
       printf("\ntitle\t%s %%cpus not halted (running)\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet);
       printf("hdrs\t%d\t%d\t%d\t%d\t%d", rows+1, bcol+1, -1, evt_idx+extra_cols+4, 2);
       for (i=1; i <= unhalted_cols_mx; i++) {
         printf("\t%d\t%d", unhalted_cols[i], unhalted_cols[i]);
       }
       printf("\n");
     }
       if (n_sum > 0) {
          printf("got perf_stat n_sum= %d\n", n_sum) >> "/dev/stderr";
          for (i_sum=1; i_sum <= n_sum; i_sum++) {
             divi = sum_occ[i_sum];
             if (sum_type[i_sum] == 1) {
                divi = sum_tmax[i_sum] - sum_tmin[i_sum];
             }
             printf("%s\t%s\t%s\t%f\n", sum_res[i_sum], "perf_stat", sum_prt[i_sum], (divi > 0 ? sum_tot[i_sum]/divi : 0.0)) >> sum_file;
          }
       }
   }' $FILES $SPECINT_LOG

