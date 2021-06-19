#!/bin/bash

export LC_ALL=C
while getopts "hf:t:" opt; do
  case ${opt} in
    f )
      FILE_IN=$OPTARG
      ;;
    t )
      TYP_IN=$OPTARG
      if [ "$TYP_IN" != "time" -a "$TYP_IN" != "count" ]; then
        echo "must enter -t count or -t time. Got -t $OPTARG. Bye"
        exit
      fi
      ;;
    h )
      echo "$0 gen flamegraph hotspots from async-profiler java files"
      echo "Usage: $0 [-h] -f java.collapsed or java.coll_traces file -t count|time"
      echo "   -f input collapsed file or collapsed+traces file"
      echo "   -t count or time. which type of hotspot file to make."
      echo "      if count then this is usual collapsed file."
      echo "      if time then look for '--- nanoseconds_per_callstack'"
      echo "        this format of data is the 'traces' output from the async-profiler"
      exit
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      exit
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      exit
      ;;
  esac
done

if [ "$FILE_IN" == "" ]; then
 echo "must enter name of perf flamegraph java.collapsed file"
 exit
fi
if [ "TYP_IN" == "" ]; then
 echo "must enter -t count or -t time"
 exit
fi
FL=$FILE_IN
if [ ! -e $FL ]; then
  echo "didn't find file $FL"
  exit
fi

#grep 98.map prf_trace.txt > tmp.jnk
gawk -v typ="$TYP_IN" '
   BEGIN { mx=0; }
   function rindex(str,c)
   {
     return match(str,"\\" c "[^" c "]*$")? RSTART : 0
   }
   function compare_nums(i1, v1, i2, v2,    l, r)
   {
       l = v1
       r = v2
   
       if (l < r)
           return 1
       else if (l == r)
           if (hs_lkup[i1] < hs_lkup[i2]) {
               return -1;
           } else {
               return 1;
           }
           #return 0
       else
           return -1
   }
   {
     if (typ == "count") {
       if ($1 == "---") {
          # this marks the beginning of the traces section of a combined collapsed and traces file from async profiler
          exit;
       }
       i = NF;
       samples = $i;
       n = split($0, arr, ";");
       fnc = arr[n];
       str = substr(fnc, 1, length(fnc)-length(samples)-1); 
       if (!(str in hs_list)) {
         hs_mx++;
         hs_list[str] = hs_mx;
         hs_lkup[hs_mx] = str;
       }
       idx = hs_list[str];
       hs_count[idx] += samples;
       #printf("%s\n", str);
       next;
     }
   }
   {
     if (typ == "time" && $1 != "---") {
        # this marks the beginning of the traces section of a combined collapsed and traces file from async profiler
        next;
     }
     mx++;
     tm = $2+0;
     tm_sv = tm;
     unit = $3;
     ln_in = $0;
     if (unit == "ns") {
       tm *= 1.0e-9;
     }
     if (unit == "us") {
       tm *= 1.0e-6;
     }
     if (unit == "ms") {
       tm *= 1.0e-3;
     }
     samples = $5;
     getline;
     str = substr($0, index($0, "]")+2, length($0));
     #printf("tm= %f secs, %s= %d line= %s\n", tm, unit, tm_sv, ln_in) > "/dev/stderr";
     if (!(str in hs_list)) {
       hs_mx++;
       hs_list[str] = hs_mx;
       hs_lkup[hs_mx] = str;
     }
     idx = hs_list[str];
     hs_count[idx] += tm;
     next;
     #printf("%s\n", str);
   }
   END {
     total=0;
     for (i=1; i <= hs_mx; i++) {
       #printf("%6d\t%s\n", hs_count[i], hs_lkup[i]);
       total += hs_count[i];
     }
     asorti(hs_count, dest, "compare_nums");
     cumu = 0.0;
     val = total;
     rw = -1;
     if (evt == "cpu-clock:") {
         val *= 1e-9;
         printf("%9.3f\t%s\n", val, "__total__");
     } else {
       if (typ == "count") {
         printf("%d\t%s\tcount\n", total, "__total__");
       } else {
         printf("%f\t%s\tseconds\n", total, "__total__");
       }
     }
     rw++;
     if (typ == "count") {
       fmt= "%9d";
       sheet= "top_100_funcs";
       col_nm = "samples";
     } else {
       fmt= "%16.5f";
       sheet= "top_100_secs";
       col_nm = "seconds";
     }
     printf("title\t%s\tsheet\t%s\ttype\tcolumn\n", sheet, sheet);
     rw++;
     printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", rw+2, 1, -1, 2, 3);
     printf(col_nm "\t%%tot\tcumu %%tot\tfunction\n");
     mx_funcs = hs_mx;
     if (mx_funcs > 100) {
       mx_funcs = 100;
     }
     for (j=1; j <= mx_funcs; j++) {
       i = dest[j];
       #printf("dest[%d]= %s\n", j, dest[j]);
       cumu += hs_count[i];
       val = hs_count[i];
       if (evt == "cpu-clock:") {
         val *= 1e-9;
         printf("%9.3f\t%7.3f\t%7.3f\t%s\n", val, 100.0*hs_count[i]/total, 100.0*cumu/total, hs_lkup[i]);
       } else {
           printf(fmt "\t%7.3f\t%7.3f\t%s\n", val, 100.0*hs_count[i]/total, 100.0*cumu/total, hs_lkup[i]);
       }
     }
   } 
   ' $FL

#sort -nrk 1,1 < tmp1.jnk > tmp2.jnk
#ls -ltr tmp1.jnk tmp2.jnk
