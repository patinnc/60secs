#!/bin/bash

#sysctl kernel.nmi_watchdog=0 && python pmu-tools-master/toplev.py -l2 --per-core -x, --no-multiplex  -o tmp.txt -v  --nodes +CPU_Utilization,+Turbo_Utilization  -- /root/60secs/extras/spin.x -w freq -t 5
# ./top_lev_flame.sh tmp.txt
#

SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
FL=

while getopts "hvc:f:u:" opt; do
  case ${opt} in
    c )
      CSV_FILE="$OPTARG"
      ;;
    f )
      FL=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 read toplev .csv and create .collaped file for flamegraph"
      echo "Usage: $0 -f toplev.csv [ -c csv_callstack_file ]"
      echo "   -c output_callstack_csv file"
      echo "   -f input_itp_csv file"
      echo "   -v verbose mode"
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
shift $((OPTIND -1))

if [ "$FL" == "" ]; then
 echo "you must enter a file name like -f l3.csv"
 exit
fi
if [ ! -e $FL ]; then
  echo "can't find file -f $FL"
  exit
fi

if [ "$CSV_FILE" == "" ]; then
  CSV_FILE="/dev/stdout"
fi

awk -v csv_file="$CSV_FILE" '
    BEGIN{
      got_fe = 0;
    }
    /metric_TMAM_Frontend_Bound/{
      got_fe = 1;
    }
    /metric_TMAM_/ {
        if (got_fe == 0) {
          next;
        }
        # allow for metric_out.average file
        if (index($0, ",") > 0) {
           n = split($0, arr, ",");
           key = arr[1];
           val = arr[2] + 0.0;
        } else {
           # assume the line is already separated by default seperator
           key = $1;
           val = $2 + 0.0;
        }
        nm = substr(key, length("metric_TMAM_")+1, length(key));
        dpth = 1;
        tnm = nm;
        while(substr(tnm, 1,2) == "..") {
           dpth++;
           tnm = substr(tnm, 3, length(tnm));
        }
        nd_mx++;
        if (d_arr[dpth] == "") {
           d_arr[dpth] = 1;
           d_sum[dpth] = 0.0;
           dad[dpth] = nd_mx-1;
        } else {
           d_arr[dpth]++;
        }
        d_sum[dpth] += val;
        tree="";
        for (i=1; i<= dpth; i++) { tree = tree "" d_arr[i] ",";}
        if (dpth <  dpth_prev) { dir="up"; }
        if (dpth == dpth_prev) { dir="side"; }
        if (dpth >  dpth_prev) { dir="down"; }
        nd[nd_mx,"str"]  = tnm;
        nd[nd_mx,"fstr"] = nm;
        nd[nd_mx,"tree"] = tree;
        nd[nd_mx,"dpth"] = dpth;
        nd[nd_mx,"dir"]  = dir;
        nd[nd_mx,"sum"]  = d_sum[dpth];
        nd[nd_mx,"dad"]  = dad[dpth];
        nd[nd_mx,"val"]  = val;
        nd_lkup[tree] = nd_mx;
        if (dir == "up") {
           for (i=dpth_prev; i > dpth; i--) {
              d_arr[i] = "";
              d_sum[i] = 0.0;
           }
        }
        if (lvl_mx[dpth] == "") {
           lvl_mx[dpth] = d_arr[dpth];
        }
        if (d_arr[dpth] > lvl_mx[dpth]) {
           d_arr[dpth] = lvl_mx[dpth];
        }
        if (dpth_mx == "" || dpth_mx < dpth) { dpth_mx = dpth; }
        printf("%2d\t%2d\t%8.4f\t%8.4f\t%s\t%s\t%d\t%s\n", nd_mx, dad[dpth], nd[nd_mx,"sum"], val, nm, dir, dpth, tree);
        dpth_prev = dpth;
    }
    END{
      printf("dpth_mx= %d\n", dpth_mx);
      # There is a problem if the data at the next level sums to > than the parent node
      # so for each parent node, sum the children and, if the sum is > than the parent then
      # scale the children values such that sum of the children == parent.
      # do this for each level.
      for ( dpth=1; dpth < dpth_mx; dpth++) {
        for ( n=1; n <= nd_mx; n++) {
           if (nd[n,"dpth"] != dpth) {
              continue;
           }
           sum = 0.0;
           nds = 0;
           val = nd[n,"val"];
           for ( m=n+1; m <= nd_mx; m++) {
               m_dad = nd[m,"dad"];
               if (m_dad != n) {
                  continue;
               }
               sum += nd[m,"val"];
               nds++;
           }
           if (nds > 0 && sum > val && val > 0.0) {
             fctr = val/sum
             sum2=0.0;
             for ( m=n+1; m <= nd_mx; m++) {
               m_dad = nd[m,"dad"];
               if (m_dad != n) {
                  continue;
               }
               nd[m,"val"] *= fctr;
               sum2 += nd[m,"val"];
               nd[m,"sum"] = sum2;
             }
             printf("adjust fctr= %8.4f val= %8.4f, sum= %8.4f sum2= %8.4f n= %d str= %s\n", fctr, val, sum, sum2, n, nd[n,"fstr"]);
           }
        }
      }
      # print the new table
      for ( n=1; n <= nd_mx; n++) {
        printf("%2d\t%2d\t%8.4f\t%8.4f\t%s\t%s\n", n, nd[n,"dad"], nd[n,"sum"], nd[n,"val"], nd[n,"fstr"], nd[n,"tree"]);
      }
      # the flamegraph assumes that all the "counts" are in the right most unit
      # That is, say have a hierarchy like
      #   A 100
      #     B 20
      #     C 80
      # The flamegraph logic propagates the children time to the parent. so we need to subtract the child total from the parent.
      # So B+C should sum to A... it does that good. but flamegraph.pl wants a callstack like:
      #  A;B 20
      #  A;C 80
      # For the case like:
      #   A 100
      #     B 10
      #     C 70
      # the call stack looks like:
      #   A 20
      #   A;B 10
      #   A;C 70
      # so the children total cant exceed the parent total. The above section ensured that the children total are <= parent total.
      # Now subtract the child value from the parent. We can get -0.000 values so if < 0.0 then set it to 0.0.
      for ( dpth=dpth_mx; dpth > 1; dpth--) {
        for ( n=1; n <= nd_mx; n++) {
           if (nd[n,"dpth"] == dpth) {
              nd_dad = nd[n,"dad"];
              val = nd[n,"val"];
              while(nd_dad != 0) {
                 nd[nd_dad,"val"] -= val;
                 if (nd[nd_dad,"val"] < 0.0) {
                   nd[nd_dad,"val"] = 0.0;
                 }
                 nd_dad = nd[nd_dad,"dad"]
              }
           }
        }
      }
      # print out the new table
      for ( n=1; n <= nd_mx; n++) {
        printf("%2d\t%2d\t%8.4f\t%8.4f\t%s\t%s\t%d\t%s\n", n, nd[n,"dad"], nd[n,"sum"], nd[n,"val"], nd[n,"fstr"], nd[n,"dir"], nd[n,"dpth"], nd[n,"tree"]);
      }
      # print the ; separated call stack file
      for ( n=1; n <= nd_mx; n++) {
        dpth = nd[n,"dpth"];
        dstr[dpth] = nd[n,"str"];
        fstr = "";
        sep = ";";
        for (d=1; d <= dpth; d++) {
          if (d==dpth) { sep = ""; }
          fstr = fstr "" dstr[d] "" sep;
        }
        fstr = fstr " " sprintf("%.0f", nd[n,"val"] * 1000.0);
        printf("%s\n", fstr) > csv_file;
      }
    }
    ' $FL
exit

