#!/bin/bash

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

while getopts "hvc:f:o:p:s:l:" opt; do
  case ${opt} in
    c )
      CHART_IN=$OPTARG
      ;;
    p )
      PFX_IN=$OPTARG
      ;;
    s )
      SHEET_IN=$OPTARG
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
      echo "   -o options_str  Currently only option is \"dont_sum_sockets\" to not sum S0 & S1 to the system"
      echo "   -p prefix_str.  prefix each sheet name with this string."
      echo "   -s sheet_name.  Used by tsv_2_xlsx.py. string has to comply with Excel sheet name rules"
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


awk -v pfx="$PFX_IN" -v options="$OPTIONS" -v chrt="$CHART" -v sheet="$SHEET" 'BEGIN{
     row=0;
     evt_idx=-1;
     months="  JanFebMarAprMayJunJulAugSepOctNovDec";
     date_str="";
     st_beg=0; 
     st_mx=0;
     ts_prev = 0.0;
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
#  END{ 
#    for (i=1; i <= st_mx; i++) {
#      printf("%s\t%s\t%s\n", st_sv[i,1], st_sv[i,2], st_sv[i,3]);
#    }
#  }

  /^# started on / {
    pos = index($0, " on ")+8;
    date_str = substr($0, pos);
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
   n=split($0,arr,";");
   ts=arr[1];
   skt=arr[2];
   #sum=arr[3];
   inst=arr[3];
   val=arr[4];
   #not_sure=arr[5];
   evt=arr[6];
   if (evt == "") {
     next;
   }
   if (options != "" && index(options, "dont_sum_sockets") > 0) {
      evt = evt " " skt;
   }
   tmr=arr[7];
   #cyc=arr[7];
   pct=arr[8];
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
   epch = dt_to_epoch(ts);
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
     got_lkfor[kmx,2]=4; # num of fields to look for
     got_lkfor[kmx,3]=64e-9; # a factor
     got_lkfor[kmx,4]="sum"; # operation
     got_lkfor[kmx,5]=1; # instances
     got_lkfor[kmx,6]="div_by_interval"; # 
     lkfor[kmx,1]="unc0_read_write";
     lkfor[kmx,2]="unc1_read_write";
     lkfor[kmx,3]="unc2_read_write";
     lkfor[kmx,4]="unc3_read_write";
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
     got_lkfor[kmx,3]=1.0e-9; # a factor
     got_lkfor[kmx,4]="div"; # operation x/y/z
     got_lkfor[kmx,5]=1; # instances
     got_lkfor[kmx,6]="div_by_interval"; # 
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
                 lkfor[k,kk]=lkfor[k,kk] " S0";
               }
            }
            nwfor[k,1]=nwfor[k,1] " S0";
          }
       }
       kmx = kmx_nw;
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
       if (got_lkfor[k,1] == got_lkfor[k,2]) {
          extra_cols++;
       }
     }

     printf("epoch\tts\tinstances:");
     for(i=0; i <= evt_idx; i++) {
       printf("\t%s", evt_inst[i]);
     }
     for (k=1; k <= kmx; k++) { 
       if (got_lkfor[k,1] == got_lkfor[k,2]) {
          printf("\t%s", got_lkfor[k,5]);
       }
     }
     rows=1;
     printf("\n");
     rows++;
     printf("title\t%s\tsheet\t%s%s\ttype\tline\n", chrt, pfx, sheet);
     bcol = 4;
     if (options != "" && index(options, "chart_new") > 0 && extra_cols > 0) {
       bcol += evt_idx;
     }
     printf("hdrs\t%d\t%d\t%d\t%d\n", rows+1, bcol+1, -1, evt_idx+extra_cols+4);
#title	sar network IFACE dev eth0	sheet	sar network IFACE	type	line
#hdrs	8	0	68	8
     printf("epoch\tts\tskt\tinterval");
     for(i=0; i <= evt_idx; i++) {
       printf("\t%s", evt_lkup[i]);
     }
     for (k=1; k <= kmx; k++) { 
       if (got_lkfor[k,1] == got_lkfor[k,2]) {
          printf("\t%s", nwfor[k,1]);
       }
     }
     printf("\n");
     epoch_next=0;
     ts_prev = 0.0;
     for(i=1; i <= row; i++) {
       if (sv[i,2] == "S0" && i < row) {
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
       if (sv[i,2] != "S0") {
         continue;
       }
       interval = sv[i,1] - ts_prev;
       ts_prev = sv[i,1]
       printf("%.4f\t%s\t%s\t%.4f", sv[i,0], sv[i,1], sv[i,2], interval);
       for (k=1; k <= kmx; k++) { 
         sum[k]=0.0;
         numer[k]=0.0;
         denom[k]=0.0;
         for(j=0; j <= evt_idx; j++) {
           if (k == 1) {
             printf("\t%s", sv[i,3+j]);
           }
           if (got_lkfor[k,4] == "sum") {
             for (kk=1; kk <= got_lkfor[k,2]; kk++) { 
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
         if (prt_it == 1) {
           if (got_lkfor[k,6] == "div_by_interval") {
              val = val / interval;
           }
           printf("\t%s", val);
         }
       }
       if (st_mx > 0 && i < row && sv[i,0]+0.0 > 0 && st_sv[1,2]+0.0 > 0.0) {
          epb = sv[i,0]+0;
          epe = epoch_next+0;
          #printf("epb= %f, epe= %f, st_mx= %d\n", epb, epe, st_mx);
          for (ii=1; ii < st_mx; ii++) {
            if (epb <= st_sv[ii,2] && st_sv[ii,2] < epe) {
		printf("\t%s", st_sv[ii,1]);
                break;
            }
          }
       }
       printf("\n");
     }
   }' $FILES $SPECINT_LOG

