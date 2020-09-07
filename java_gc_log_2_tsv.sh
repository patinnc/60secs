#!/bin/bash

while getopts "hvf:b:e:s:" opt; do
  case ${opt} in
    f )
      FILE=$OPTARG
      ;;
    b )
      BEG_IN=$OPTARG
      ;;
    e )
      END_IN=$OPTARG
      ;;
    s )
      SUM_FILE=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 split data files into columns"
      echo "Usage: $0 [-h] -f json_file -t header [ -b beg_timestamp -e end_timestamp ] -s summary_filename [-v]"
      echo "   -v verbose mode"
      exit 1
      ;;
    : )
      echo "$0: Invalid option: $OPTARG requires an argument. cmdline= ${@}" 1>&2
      exit 1
      ;;
    \? )
      echo "Invalid option: $OPTARG. cmdline= ${@}" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

FL=$FILE
if [ "$FL" == "" ]; then
  echo "arg1 (path to java gc log file) is missing. Bye"
  exit 1
fi
if [ ! -e "$FL" ]; then
  echo "can't find file $FL. Bye"
  exit 1
fi
PRF_FILE=(sys_*_perf_stat.txt)
if [ ! -e $PRF_FILE ]; then
  echo "sorry but $0 depends (currently) on the $PRF_FILE existing in the cur dir"
  exit 1
fi
BEG=`cat 60secs.log | awk '{n=split($0, arr);printf("%s\n", arr[n]);exit;}'`
DURA=`tail -1 $PRF_FILE | awk '{n=split($0, arr, ";");printf("%s\n", arr[1]);exit;}'`
if [ "$END_IN" == "" ]; then
  END=`awk -v beg="$BEG" -v dura="$DURA" 'BEGIN{printf("%f\n", beg+dura);exit;}'`
else
  END=$END_IN
  echo "============ GC end= $END" > /dev/stderr
fi

# start perf at Wed Feb  5 22:53:31 PST 2020 1580972011.851953818
TZ=`tail -1 60secs.log | awk '{printf("%s\n", $8);}'`
#echo "TZ= $TZ"

awk -v tm_beg="$BEG" -v tm_end="$END" -v tz="$TZ" 'BEGIN{
     tm_beg = tm_beg + 0.0;
     tm_end = tm_end + 0.0;
     #printf("TZ= %s beg= %f, end= %f\n", tz, tm_beg, tm_end);
     printf("title\tjava gc\tsheet\tjava gc\ttype\tscatter_straight\n");
     printf("hdrs\t2\t2\t-1\t5\t1\n");
     printf("TS\tts_off\tuser\tsys\ttot_cpu_tm\treal\n");
  }
  function dt_to_epoch(date_in) {
     #2020-02-03T08:00:59.619+0000: 84.005: [GC pause (G1 Evacuation Pause) (young)
     if (date_in  == "") {
        return 0.0;
     }
     pos = index(date_in, ": ");
     if (pos == 0) {
        return 0.0;
     }
     n=split(date_in, warr);
     date_str = warr[1];
     rel_tm   = warr[2];
     n=split(date_str, darr, /[ :\-T+]+/);
     n=split(rel_tm, darrb, /[ :]+/);
     rel_tm = darrb[1]+0.0;
     #return 0.0;
     #for(i in darr) printf("darr[%d]= %s\n", i,  darr[i]);
     #mnth_num = sprintf("%d", index(months, darr[1])/3);
     #printf("mnth_num= %d\n", mnth_num);
     secs = darr[6];
     n = split(secs, sarr, ".");
     secs_int = sarr[1];
     secs_frc = "0." sarr[2];
     #printf("scs %s %s\n", secs_int, secs_frc);
     dt_str = darr[1] " " darr[2] " " darr[3] " " darr[4] " " darr[5] " " secs_int;
     # 83301 Mon Feb  3 07:59:34 2020 
     #dt_str = "2020 02 03 07 59 34";
     #printf("dt_str= %s\n", dt_str);
     #"YYYY MM DD HH MM SS [DST]"
     epoch = mktime(dt_str, -1);
     epoch = epoch + secs_frc;
     #epoch += rel_tm;
     #if (tz == "PST") { epoch -= 8*3600; }
     #else if (tz == "PDT") { epoch -= 7*3600; }
     #printf("epoch= %f yr= %s, mon= %s, dy= %s, hr=%s min= %s sec= %s\n", epoch, darr[1], darr[2], darr[3], darr[4], darr[5], secs_int);
     return epoch;
  }
  /^2020-.*: / {
     epoch = dt_to_epoch($0);
     #printf("epoch= %f\n", epoch);
  }
  / \[Times: user=/ {
     if (epoch < tm_beg || epoch > tm_end) {
        next;
     }
     n = split($2, arr, /[ =,]+/);
     usr= arr[2];
     n = split($3, arr, /[ =,]+/);
     sys= arr[2];
     n = split($4, arr, /[ =,]+/);
     real= arr[2];
     printf("%f\t%f\t%f\t%f\t%f\t%f\n", epoch, epoch-tm_beg, usr, sys, usr+sys, real);
     #/ [Times: user=0.15 sys=0.05, real=0.02 secs] 
  }
 END {;}
  ' $FL
  RC=$?
  exit $RC
