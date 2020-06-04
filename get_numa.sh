#!/bin/bash

PID=83301

if [ "$1" != "" ]; then
  PID=$1
fi

cat /proc/$PID/numa_maps | awk '
   BEGIN{n0mx=0; n1mx=0;}
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
         printf("alloc[%2d] MBs= %8.2f\n", nf_mx, marr[1]/(1024));
         if (nf_mx > mx_lines) {
           break;
         }
       } 
       close(cmd)
       return nf_mx;
   }
   /kB=/{
    if (NF < 4) { printf("nf= %s for %s\n", NF, $0);next;}
    if (index($3, "file=") == 1) {next;}
    #if (index($3, "anon=") != 1) {printf("arg3 not anon: got %s\n", $0); next;}
    pg_sz = 4;
    i = NF;
    if (index($i, "kB=") > 0) {
      n=split($i, arr, "=");
      pg_sz = arr[2];
    }
    if (pg_sz != 4) {
      printf("pg_sz= %d for line= %s\n",pg_sz,$0);
    }
    for (i=3; i <= NF; i++) {
       if (index($i, "anon=") == 1) {
         n=split($3, arr, "=");
         pgs += pg_sz * arr[2];
       }
       if (index($i, "N0=") == 1) {
         n=split($i, arr, "=");
         pg = pg_sz * (arr[2] + 0);
         node0 += pg;
         n0[++n0mx] = pg;
         continue;
       }
       if (index($i, "N1=") == 1) {
         n=split($i, arr, "=");
         pg = pg_sz * (arr[2] + 0);
         node1 += pg;
         n1[++n1mx] = pg;
         continue;
       }
    }
   }
   END{
     printf("memory on node0= %d, node1= %d, tot %d MBs\n", node0/1024, node1/1024, pgs/1024);
     printf("%%memory on node0= %.3f%% node1= %.3f%%  tot= %d MBs\n", 100.0*node0/pgs, 100.0*node1/pgs, pgs/1024);
     printf("top node0 sizes\n");
     sort_data(n0, n0mx, 10);
     printf("top node1 sizes\n");
     sort_data(n1, n1mx, 10);
   }'
