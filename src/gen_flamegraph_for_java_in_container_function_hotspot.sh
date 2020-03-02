#!/bin/bash

if [ "$1" == "" ]; then
 echo "must enter name of perf flamegraph java.collapsed file"
 exit
fi
FL=$1
if [ ! -e $FL ]; then
  echo "didn't find file $FL"
  exit
fi

#grep 98.map prf_trace.txt > tmp.jnk
gawk '
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
# below is format for callstack (but java jar is without frames (I think?)
#java 86998/87788 340730.095902012:        606 LLC-load-misses:
#            7fe65272a0c9 Lcom/graphhopper/storage/GraphHopperStorage;::getEdgeProps+0xa9 (/tmp/perf-86998.map)
#            7fc6185e9b68 [unknown] ([unknown])
# or for sampling hotspot
#            java 86998/87782 347681.584771998:     250000 cpu-clock:                    7fe6532785a5 Lcom/graphhopper/routing/util/FastestWeighting;::calcWeight+0x265 (/tmp/perf-86998.map)
#            java 86998/87782 347681.585019181:     250000 cpu-clock:                    7fe653278657 Lcom/graphhopper/routing/util/FastestWeighting;::calcWeight+0x317 (/tmp/perf-86998.map)
   {
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
         printf("%6d\t%s\n", total, "__total__");
     }
     rw++;
     printf("title\t%s\tsheet\t%s\ttype\tcolumn\n", "top_40_funcs", "top_40_funcs");
     rw++;
     printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", rw+2, 1, -1, 2, 3);
     printf("samples\t%%tot\tcumu %%tot\tfunction\n");
     mx_funcs = hs_mx;
     if (mx_funcs > 40) {
       mx_funcs = 40;
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
         printf("%9d\t%7.3f\t%7.3f\t%s\n", val, 100.0*hs_count[i]/total, 100.0*cumu/total, hs_lkup[i]);
       }
     }
   } 
   ' $FL

#sort -nrk 1,1 < tmp1.jnk > tmp2.jnk
#ls -ltr tmp1.jnk tmp2.jnk
