#!/bin/bash

#arg1 is infra_cputime.txt filename
VERBOSE=0
export LC_ALL=C

ck_last_rc() {
   local RC=$1
   local FROM=$2
   if [ $RC -gt 0 ]; then
      echo "$0: got non-zero RC=$RC at $LINENO. called from line $FROM" > /dev/stderr
      exit $RC
   fi
}


while getopts "hvf:m:n:O:R:S:t:w:" opt; do
  case ${opt} in
    f )
      IN_FL=$OPTARG
      ;;
    t )
      TMP_FL=$OPTARG
      ;;
    O )
      OPTIONS=$OPTARG
      ;;
    R )
      REDUCE=$OPTARG
      ;;
    w )
      WORK_DIR=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 read infra_cputime.txt file"
      echo "Usage: $0 [ -v ] -f input_file [ -o out_file ] [ -n num_cpus ] [ -S sum_file ]"
      echo "   -f input_file  like infra_cputime.txt.tsv"
      echo "   -m muttley_out_file    muttley complete table of calls over time. format is like chart table without hdrs titles rows"
      echo "   -O options     comma separated list of options. No spaces"
      echo "   -t tmp_file    read input file, create new tmp file and cp tmp file to input file"
      echo "   -R x,y         reduce data size by dropping x of y samples"
      echo "   -S sum_file    summary file"
      echo "   -w work_dir    all tsv output files go in this dir"
      echo "   -v verbose mode"
      exit 1
      ;;
    : )
      echo "$0 Invalid option: $OPTARG requires an argument. cmdline= ${@}" 1>&2
      exit 1
      ;;
    \? )
      echo "$0 Invalid option: $OPTARG, cmdline= ${@} " 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

#IN_FL=$1


if [ "$REDUCE" == "" ]; then
  exit 0
fi
if [ "$IN_FL" == "" ]; then
  echo "must pass -i input_file where the input filename (path_to/infra_cputime.txt)"
  exit 1
fi

if [ ! -e "$IN_FL" ]; then
  echo "can't find arg1 file $IN_FL"
  exit 1
fi
TMP_FL="${IN_FL}.tmp"
if [ "$TMP_FL" == "" ]; then
  TMP_FL="${WORK_DIR}/$(mktemp)"
fi
echo "$0.$LINENO TMP_FL= $TMP_FL"
#NUM_CPUS=$2
#PID RSS    VSZ     TIME COMMAND
CUR_DIR=`pwd`

AWK_BIN=awk  # awk is a link to gawk
BSNM=`basename $IN_FL`
echo "$0.$LINENO basename= $BSNM"

GOT_REDUCE=`$AWK_BIN -v script="$0.$LINENO.awk" -v reduce="$REDUCE" -v ck_fl="$BSNM" -v options="$OPTIONS" '
  BEGIN {
   drop_every[1]=0;
   drop_every[2]=0;
   if (reduce != "") {
     n = split(reduce, drop_every, ",");
     for (i=1; i <= n; i+= 2) {
       v = drop_every[i];
       pos = index(v, ":");
       if (pos > 0) {
         str1 = substr(v, 1, pos-1);
         printf("%s: ck_str= %s\n", script, str1) > "/dev/stderr";
         if (index(ck_fl, str1) > 0) {
           str2 = substr(v, pos+1, length(v));
           printf("%s: ck_str= %s, drop= %s\n", script, str1, str2) > "/dev/stderr";
           drop_every[1] = str2;
           drop_every[2] = drop_every[i+1];
           break;
         }
       } else {
         drop_every[1] = drop_every[i];
         drop_every[2] = drop_every[i+1];
         break;
       }
     }
   }
   str = "";
   if (drop_every[1] != 0) {
     str = drop_every[1] "," drop_every[2];
   }
   printf("%s\n", str);
   exit(0);
  }'`
RC=$?
ck_last_rc $RC $LINENO
echo "$0.$LINENO got_reduce= $GOT_REDUCE"
if [ "$GOT_REDUCE" == "" ]; then
  echo "$0.$LINENO didn't get match on reduce string, BSNM= $BSNM, reduce= $REDUCE"
  exit 0
fi

$AWK_BIN -v script="$0.$LINENO.awk" -v reduce="$GOT_REDUCE" -v tmp_file="$TMP_FL" -v cur_dir="$CUR_DIR" -v options="$OPTIONS" '
  BEGIN {
   drop_every[1]=0;
   drop_every[2]=0;
   if (reduce != "") {
     n = split(reduce, drop_every, ",");
   }
   orw= -1;
  }
  {
    sv[++orw] = $0;
    #n = split(sv[orw], arr, "\t");
    #printf("rw[%d]: n= %d, arr[1]= %s\n", orw, n, arr[1]);
  }
  END{
    nrw= -1;
    i = -1;
    ck_mx=0;
    #printf("reduce script= %s, orw= %d sv0= %s\n", script, orw, sv[0]);
    while (i <= orw) {
      ++i;
      if (sv[i] == "") {
        nln[++nrw] = sv[i];
        continue;
      }
      n = split(sv[i], arr, "\t");
      #printf("rw[%d]: n= %d, arr[1]= %s, sv[%s]= %s\n", i, n, arr[1], i, sv[i]);
      if (arr[1] == "title") {
        ch_typ = arr[6];
        nln[++nrw] = sv[i];
        continue;
      }
      if (arr[1] == "hdrs") {
        rw_beg = arr[2]+0;
        rw_end = arr[4]+0;
        rw_off = rw_beg - i;
        ++nrw;
        str = "";
        cma = "";
        if (rw_beg > i) {
          old_row_num_2_new_row_num[arr[2]] = nrw+rw_off;
          arr[2] = nrw + rw_off;
        } else {
          arr[2] = old_row_num_2_new_row_num[arr[2]];
        }
        for (j=1; j <= n; j++) {
          str = str cma arr[j];
          cma = "\t";
        }
        nln[nrw] = str;
        ck_ln[++ck_mx] = nrw;
        printf("reduce ck_mx= %d orow= %d, nrw= %d off= %s\n", ck_mx, i, nrw, rw_off, sv[i]);
        nln_off[nrw] = rw_off;
        tbl_pfx_mx = 0;
        for (j=1; j <= rw_off; j++) {
            tbl_pfx[++tbl_pfx_mx] = sv[++i];
            printf("cpy ck_mx= %d orow= %d, nrw= %d off[%d]= %s\n", ck_mx, i, nrw, j, sv[i]);
        }
        if (rw_end == -1) {
          ck_beg[ck_mx] = nrw+1;
          j = -1;
          tbl_mx = 0;
          odata_rows = 0;
          ndata_rows = 0;
          while(i <= orw) {
            j++;
            rw_mod = j % drop_every[2];
            i++;
            if (sv[i] != "") {
              ++odata_rows;
            }
            if (ch_typ == "column" || sv[i] == "" || rw_mod >= drop_every[1]) {
              tbl[++tbl_mx] = sv[i];
              if (sv[i] != "") {
                ++ndata_rows;
              }
            }
            if (sv[i] == "") {
              ck_end[ck_mx] = nrw-1;
              break;
            }
          }
          printf("cpy ck_row[%d] beg= %d end= %d, tbl_pfx_mx= %d tbl_mx= %d odata_rows= %d, ndata_rows= %d\n",
               ck_mx, ck_beg[ck_mx], ck_end[ck_mx], tbl_pfx_mx, tbl_mx, odata_rows, ndata_rows);
          ostr = "+" odata_rows ",";
          nstr = "+" ndata_rows ",";
          for (j=1; j <= tbl_pfx_mx; j++) {
            v = tbl_pfx[j];
            if (index(v, ostr) > 0) {
              gsub(ostr, nstr, v);
            }
            nln[++nrw] = v;
          }
          for (j=1; j <= tbl_mx; j++) {
            nln[++nrw] = tbl[j];
          }
          continue;
        }
        continue;
      }
      nln[++nrw] = sv[i];
    }
    if (tmp_file != "") {
      for (i=0; i <= nrw; i++) {
        printf("%s\n", nln[i]) > tmp_file;
      }
      close(tmp_file);
    }
    exit(0);
  }' $IN_FL

RC=$?
ck_last_rc $RC $LINENO

if [ "$RC" == "0" ]; then
  mv $IN_FL $IN_FL.old
  mv $TMP_FL $IN_FL
fi
  
exit $RC
