#!/bin/bash
# ./compare_summary_table.sh ./compare_summary_table3.tsv > compare_summary_table3.csv
# then open compare_summary_table3.csv and save as xlsm (if you save as xlsx then you get errors when you try to open in google sheets)
N_LIMIT=0
RATIO_COLS=2
SEPARATOR=","
LOOKFOR=sum.tsv
INF=
NUM_INF=0
NUM_SKU=0
SKU_IN=()
XLS_IN=()

while getopts "hvb:d:e:i:l:n:o:r:s:S:t:u:x:" opt; do
  case ${opt} in
    i )
      INF="$INF $OPTARG"
      NUM_INF=$(($NUM_INF+1))
      ;;
    b )
      BEG_IN=$OPTARG
      ;;
    e )
      END_IN=$OPTARG
      ;;
    d )
      DIR_IN=$OPTARG
      ;;
    l )
      LOOKFOR=$OPTARG
      ;;
    n )
      N_LIMIT=$OPTARG
      ;;
    o )
      OPTIONS=$OPTARG
      ;;
    r )
      RATIO_COLS_IN=$OPTARG
      ;;
    s )
      OUT_FILE=$OPTARG
      ;;
    S )
      SEPARATOR=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    u )
      SKU_IN+=("$OPTARG")
      echo "skuin= $OPTARG"
      NUM_SKU=$(($NUM_SKU+1))
      ;;
    x )
      XLS_IN+=("$OPTARG")
      echo "xlsin= $OPTARG"
      NUM_XLS=$(($NUM_XLS+1))
      ;;
    h )
      echo "$0 combine summary files columns"
      echo "Usage: $0 [-h] TBD [-v]"
      echo "   -v verbose mode"
      echo "   -i input_file   this is expected to be a tsv file with 2 columns of the summary info from sheets. Can be specified more than once."
      echo "   -d dir_in       look for the summary files ($LOOKFOR) under this dir. This overrides -i input_file."
      echo "   -n num_files_to_limit   for the -d dir_in option, limit the number of files to the first '-n x' files."
      echo "   -r ratio_cols   add this number of ratio columns. Say if we are comparing 3 pairs of results... then it might be useful to have 3 ratio columns"
      echo "   -s out_file     output file. This would be a csv file that you can open with excel."
      echo "   -S separator_char  separator used in the out_file. Default is comma ','"
      echo "   -l look_for_file   file to use in each dir. default is sum.tsv. Could use sum_all.tsv too."
      echo "   -u list of skus    this is to add a sku string to each input file"
      exit 1
      ;;
    : )
      echo "$0: Invalid option: $OPTARG requires an argument. cmdline= ${@}" 1>&2
      exit 1
      ;;
    \? )
      echo "$0: Invalid option: $OPTARG, cmdline= ${@}" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

SKU_STR=
for ((i=0; i < ${#SKU_IN[@]}; i++)); do
  SKU_STR="$SKU_STR;${SKU_IN[$i]}"
  #echo "sku_in \"${SKU_IN[$i]}\""
done
echo "sku_str= $SKU_STR"

XLS_STR=
for ((i=0; i < ${#XLS_IN[@]}; i++)); do
  XLS_STR="$XLS_STR;${XLS_IN[$i]}"
  #echo "sku_in \"${XLS_IN[$i]}\""
done
echo "xls_str= $XLS_STR"

if [ "$OUT_FILE" == "" ]; then
  echo "$0: you must specify output file '-s out_file'"
  exit 1
fi
if [ "$INF" == "" -a "$DIR_IN" == "" ]; then
  echo "$0: need input file '-i file' or '-d dir'"
  exit 1
fi
echo "file= $INF" > /dev/stderr
if [ "$RATIO_COLS_IN" != "" ]; then 
  if [ $RATIO_COLS_IN -gt 0 ]; then
    RATIO_COLS=$RATIO_COLS_IN
  fi
fi

LAYOUT=0
DIR_LST=()
if [ "$DIR_IN" != "" ]; then
  RESP=`find $DIR_IN -name $LOOKFOR | wc -l | awk '{$1=$1;print $1}'`
  echo "RESP= $RESP"
  if [ "$RESP" != "0" ]; then
    DIR_LST=(`find $DIR_IN -name $LOOKFOR | sort`)
    echo "DIR_LST= ${#DIR_LST[@]}"
    INF=
    j=1
    for i in ${DIR_LST[@]}; do
       INF="$INF $i"
       if [ "$N_LIMIT" != "0" ]; then
         if [ $j -ge $N_LIMIT ]; then
            break
         fi
       fi
       j=$((j+1))
    done
    LAYOUT=1
  fi
fi
echo "INF= $INF"
#exit
if [ $NUM_INF -gt 1 ]; then
  LAYOUT=1
fi

awk -v xls_str="$XLS_STR" -v sku_str="$SKU_STR" -v ratio_cols="$RATIO_COLS" -v out_file="$OUT_FILE" -v layout="$LAYOUT" -v sep="$SEPARATOR" '
 BEGIN{
      did_metric = 0;
      ky = 2;
      vl = 1; 
      grp = -1;
      if (layout == 1) {
          ky = 4;
          vl = 3;
          grp = 2;
      }
      if (sku_str != "" && substr(sku_str, 1, 1) == ";") {
         sku_str = substr(sku_str, 2, length(sku_str));
      }
      n=split(sku_str, sku_arr, ";");
      if (xls_str != "" && substr(xls_str, 1, 1) == ";") {
         xls_str = substr(xls_str, 2, length(xls_str));
      }
      n=split(xls_str, xls_arr, ";");
    }
function _ord_init(    low, high, i, t) {
    low = sprintf("%c", 7) # BEL is ascii 7
    if (low == "\a") {    # regular ascii
        low = 0
        high = 127
    } else if (sprintf("%c", 128 + 7) == "\a") {
        # ascii, mark parity
        low = 128
        high = 255
    } else {        # ebcdic(!)
        low = 0
        high = 255
    }

    for (i = low; i <= high; i++) {
        t = sprintf("%c", i)
        _ord_[t] = i
    }
}
  /Metric|metric/{
    n = split($0, arr, "\t");
    if (did_metric == 0) {
     for (i=1; i <= NF; i++) {
      if (tolower($i) == "metric") {
         if (i > 1 && (tolower($(i-1)) == "average" || tolower($(i-1)) == "value") ) {
           did_metric = 1;
           ky=i;
           vl = i-1;
           break;
         }
         if (NF > 1 && (tolower($(i+1)) == "average" || tolower($(i+1)) == "value") ) {
           did_metric = 1;
           ky=i;
           vl = i+1;
           break;
         }
      }
     }
     n = (vl < ky ? vl : ky );
     #for (i=1; i < n; i++) {
     #}
       
    }
    #printf("%s\n", $0);
  }
  {
    if (index($0, "specint_beg_ts") > 0 || index($0, "specint_end_ts") > 0) {
        next;
    }
    if (length($0) > 0 && substr($0, 1,1) == "#") {
      next;
    }
    if (layout == 1) {
       if (ARGIND != prev_ARGIND) {
          mx_fl++;
          if (sku_str != "") {
            sku[mx_fl]=sku_arr[mx_fl];
          }
          if (xls_str != "") {
            got_xlsx = 1;
            xls[mx_fl]=xls_arr[mx_fl];
          }
          prev_ARGIND = ARGIND;
       }
    }
    if ($0 == "key0") {
       ky = 1; vl = 2;
       next;
    }
    if ($0 == "key1") {
       ky = 2; vl = 1;
       next;
    }
    n = split($0, arr, "\t");
    if (n > 1 && (arr[1] == "hdrs" || arr[1] == "title")) {
       next;
    }
    got_xlsx = 0;
    if (index($0, "xlsx") > 0) {
      #printf("got xlsx= %s\n", $0); 
      got_xlsx = 1;
      xls[mx_fl]=arr[vl];
    }
    if (arr[ky] == "sku") {
      mx_fl++;
      sku[mx_fl]=arr[vl];
      printf("sku[%d]= %s, mx_fl= %d\n", mx_fl, arr[vl], mx_fl) > "/dev/stderr";
      next;
    }
    if (n <= 1) {
      next;
    }
    lnm = ++ln[mx_fl];
    #if (got_xlsx == 1) {
    #   printf("got xlsx at2, fl= %d\n", mx_fl);
    #}
    sv[lnm,mx_fl,1]=arr[ky];
    if (layout == 1 && arr[1] == "pidstat") {
      if (arr[vl] > (100*100)){
         # max value is 100 * num_cpus
         arr[vl] = 0;
      }
    }
    sv[lnm,mx_fl,2]=arr[vl];
    if (layout == 1) {
      gstr = arr[1] " " arr[2];
      if (!(gstr in gstr_list)) {
         gstr_list[gstr]     = ++gstr_mx;
         gstr_lkup[gstr_mx]  = gstr;
         gstr_lkup1[gstr_mx] = arr[1];
         gstr_lkup2[gstr_mx] = arr[2];
      }
      gstr_i = gstr_list[gstr];
      sv[lnm,mx_fl,3]  = gstr_i;
      if (arr[1] == "pidstat") {
        if (!(arr[ky] in pidstat_list)) {
           pidstat_list[arr[ky]] = ++pidstat_mx;
           pidstat_lkup[pidstat_mx] = arr[ky];
        }
        pi = pidstat_list[arr[ky]];
        pidstat_tot[pi] += arr[vl];
        pidstat_arr[pi,mx_fl] = arr[vl];
      }
      sv[lnm,mx_fl,4] += arr[vl];
      #printf("grp= %s\tvl= %s\n", gstr, arr[vl]);
    }
   }
function tot_compare(i1, v1, i2, v2,    l, r)
{
    m1 = pidstat_tot[i1];
    m2 = pidstat_tot[i2];
    if (m2 < m1)
        return -1
    else if (m1 == m2)
        return 0
    else
        return 1
}
   END {
     _ord_init(1, 127, i, t); 
     mx = 0;
     for (fl=1; fl <= mx_fl; fl++) {
        if (mx < ln[fl]) {
          mx = ln[fl];
        }
     }
     for (i=1; i <= pidstat_mx; i++) {
        ai[i] = 1;
        #printf("pidstat_tot[%d]= %f\n", i, pidstat_tot[i]);
     }
     asorti(ai, result, "tot_compare")
     for (i=1; i <= (pidstat_mx> 20 ? 20: pidstat_mx); i++) {
        j = result[i];
        printf("pidstat_res[%d]= %f %s\n", j, pidstat_tot[j], pidstat_lkup[j]);
     }


     m=1; n=1;
     for (fl=1; fl <= mx_fl; fl++) {
       delete myhsh;
       for (i=1; i <= mx; i++) {
         lbl = sv[i,fl,1];
         if (lbl != "") {
           if (!(lbl in myhsh)) {
             myhsh[lbl] = 0;
           } else {
             ++myhsh[lbl];
             lbl = lbl "_" myhsh[lbl];
           }
           if (!(lbl in lbl_list)) {
             lbl_list[lbl] = ++lbl_mx;
             lbl_lkup[lbl_mx] = lbl;
           }
           lbl_i = lbl_list[lbl];
           lbl_arr[lbl_i,fl]=i;
         }
       }
     }
     offset = 0;
     printf("title\tsum_all\tsheet\tsum_all\ttype\tcopy\n")  > out_file;
     printf("hdrs\t2\t0\t-1\t%d\t-1\n", fls+3) > out_file;
     rows = 2;
     if (layout == 1) {
        offset = 6;
       printf("%s%s%s%s%s%s", "", sep, "", sep, "", sep) > out_file;
       printf("%s%s%s%s", "average", sep, "", sep) > out_file;
       lc = 5;
     } else {
      lc = 0;
      for (fl=1; fl <= mx_fl-1; fl++) {
        printf("%s%s", "", sep) > out_file;
        lc++;
      }
     }
     printf("ratio numer col") > out_file;
     lc++;
     for (i=1; i <= ratio_cols; i++) {
       printf("%s%d", sep, i+ratio_cols+lc) > out_file;
     }
     for (fl=1; fl < mx_fl; fl++) {
        printf("%s", sep) > out_file;
     }
     printf("\n") > out_file;
# excel subtotal
#101 AVERAGE
#102 COUNT
#103 COUNTA
#104 MAX
#105 MIN
#106 PRODUCT
#107 STDEV
#108 STDEVP
#109 SUM
#110 VAR
#111 VARP
     rows++;
     lc = 0;
     row_top=rows;
     if (layout == 1) {
       printf("%s%s%s%s%s%s", "", sep, "", sep, "", sep) > out_file;
       lc = 3;
       CLL="D"row_top;
       printf("\"=IF(%s=\"\"average\"\",101,IF(%s=\"\"SUM\"\",109,IF(%s=\"\"COUNT\"\",102,NA())))\"%s%s%s", CLL, CLL, CLL, sep, "", sep) > out_file;
       lc += 2;
     } else {
      for (fl=1; fl <= mx_fl-1; fl++) {
        printf("%s%s", "", sep) > out_file;
        lc++;
      }
     }
     printf("ratio denom col") > out_file;
     lc++;
     for (i=1; i <= ratio_cols; i++) {
       printf("%s%d", sep, 1+i+lc+ratio_cols) > out_file;
     }
     #if (layout == 1) {
     #  for (i=1; i <= ratio_cols; i++) {
     #    printf("%s%d", sep, i+1+offset) > out_file;
     #  }
     #}
     printf("\n") > out_file;
     rows++;
     lc = 0;
     if (layout == 0) {
      for (fl=1; fl <= mx_fl; fl++) {
        printf("col %d%s", fl, sep) > out_file;
        lc++;
      }
      printf("\n") > out_file;
      rows++;
      lc = 0;
     }
     if (layout == 1) {
       printf("%s%s%s%s%s%s", "", sep, "", sep, "", sep) > out_file;
       printf("%s%s%s%s%s%s", "", sep, "", sep, "", sep) > out_file;
       lc = 6;
     } else {
      for (fl=1; fl <= mx_fl; fl++) {
        printf("%s%s", sku[fl], sep) > out_file;
        lc++;
      }
     }
     for (i=1; i <= ratio_cols; i++) {
       printf("ratio %d%s", i, sep) > out_file;
       lc++;
     }
     if (layout == 1) {
      for (fl=1; fl <= mx_fl; fl++) {
        printf("col %s%s", lc+fl, sep) > out_file;
      }
     }
     plst = 0;
     printf("desc\n") > out_file;
     rows++;
     lc = 0;
     if (layout == 1 && sku_str != "") {
       if (layout == 1) {
         printf("%s%s%s%s%s%s", "", sep, "", sep, "", sep) > out_file;
         printf("%s%s%s%s%s%s", "", sep, "", sep, "", sep) > out_file;
         lc += 6;
       } else {
        for (fl=1; fl <= mx_fl; fl++) {
          printf("%s%s", sku[fl], sep) > out_file;
          lc++;
        }
       }
       for (i=1; i <= ratio_cols-1; i++) {
         printf("%s", sep) > out_file;
         lc++;
       }
       if (layout == 1) {
        printf("sku%s", sep) > out_file;
        for (fl=1; fl <= mx_fl; fl++) {
          printf("%s%s", sku[fl], sep) > out_file;
          lc++;
        }
       }
       printf("desc\n") > out_file;
       rows++;
       lc =0;
     }
     if (layout == 0) {
        gstr_mx = 1;
     }
     for (g=1; g <= gstr_mx; g++) {
      for (i=1; i <= lbl_mx; i++) {
        kk = i;
        lbl=lbl_lkup[i];
        got_2 = 0;
        prtd=0;
        if (layout == 1) {
         got_gstr = 0;
         for (fl=1; fl <= mx_fl; fl++) {
          j = lbl_arr[i,fl];
          if (sv[j,fl,3] == g) {
             got_gstr = 1;
             break;
          }
         }
        } else {
          got_gstr = 1;
        }
        if (got_gstr == 1) {
         if (layout == 1) {
            lstr = lbl;
            if (gstr_lkup1[g] == "pidstat") {
               ++plst;
               kk = result[plst];
               lbl=pidstat_lkup[kk];
               lstr = lbl;
               #printf("j= %d k= %d\n", plst, kk);
               sub("%cpu ", "", lstr);
            }
            if (gstr_lkup1[g] == "Resource") {
              frm_avg="=D"row_top;
              frm_min="min";
              frm_max="max";
            } else {
              fnc_avg=109; # sum
              fnc_avg=101; # avg
              fnc_avg="D"(row_top+1); # cell holding number
              cbeg=3+ratio_cols;
              cend=cbeg+mx_fl;
              frm_avg="=SUBTOTAL("fnc_avg", INDIRECT(ADDRESS(ROW(), COLUMN()+"cbeg", 1)):INDIRECT(ADDRESS(ROW(), COLUMN()+"cend",1)))"
              cbeg=2+ratio_cols;
              cend=cbeg+mx_fl;
              frm_min="=SUBTOTAL(105, INDIRECT(ADDRESS(ROW(), COLUMN()+"cbeg", 1)):INDIRECT(ADDRESS(ROW(), COLUMN()+"cend",1)))"
              cbeg=1+ratio_cols;
              cend=cbeg+mx_fl;
              frm_max="=SUBTOTAL(104, INDIRECT(ADDRESS(ROW(), COLUMN()+"cbeg", 1)):INDIRECT(ADDRESS(ROW(), COLUMN()+"cend",1)))"
            }
            printf("%s%s%s%s%s%s\"%s\"%s\"%s\"%s\"%s\"%s", gstr_lkup1[g], sep, gstr_lkup2[g], sep, lstr, sep, frm_avg, sep, frm_min, sep, frm_max, sep) > out_file;
            lc = 6;
         for (fl=1; fl <= ratio_cols; fl++) {
          if (1==1) {
            col = sprintf("%c", fl+lc-1+ _ord_["a"]);
            CLL = col""row_top;
            CLL2 = col""(row_top+1);
            #printf("\"=IF(AND(ISNUMBER(INDIRECT(ADDRESS(ROW(),%s1,4,1))),ISNUMBER(INDIRECT(ADDRESS(ROW(),%s2,4,1))),INDIRECT(ADDRESS(ROW(),%s2,4,1))>0),INDIRECT(ADDRESS(ROW(),%s1,4,1))/INDIRECT(ADDRESS(ROW(),%s2,4,1)),\"\"\"\")\"%s", col,col,col, col, col, sep) > out_file;;
            printf("\"=IF(AND(ISNUMBER(INDIRECT(ADDRESS(ROW(),%s,4,1))),ISNUMBER(INDIRECT(ADDRESS(ROW(),%s,4,1))),INDIRECT(ADDRESS(ROW(),%s,4,1))>0),INDIRECT(ADDRESS(ROW(),%s,4,1))/INDIRECT(ADDRESS(ROW(),%s,4,1)),\"\"\"\")\"%s", CLL,CLL2,CLL2, CLL, CLL2, sep) > out_file;;
          } else {
            printf("%s", sep) > out_file;;
          }
         }
         }
         for (fl=1; fl <= mx_fl; fl++) {
          if (gstr_lkup1[g] == "pidstat") {
             kk = result[plst];
             lbl=pidstat_lkup[kk];
             val[fl] = pidstat_arr[kk,fl];
             str = (val[fl] == "" ? "" : val[fl])
          } else {
             j = lbl_arr[i,fl];
             lbl=lbl_lkup[i];
             val[fl] = sv[j,fl,2];
             str = (j == "" ? "" : val[fl])
          }
          if ((val[fl] + 0.0) != 0.0) {
             got_2++;
          }
          if (layout == 1 && gstr_lkup1[g] == "time") {
            if (index(str, "\"") == 0) {
               printf("\"%s\"%s", str, sep) > out_file;
            } else {
               printf("%s%s", str, sep) > out_file;
               printf("%s%s\n", str, sep) > "/dev/stderr"
            }
          } else {
            printf("%s%s", str, sep) > out_file;
          }
          prtd=1;
         }
        }
        if (prtd == 0) {continue;}
         if (layout == 0) {
        for (fl=1; fl <= ratio_cols; fl++) {
          if (1==1) {
            col = sprintf("%c", mx_fl+fl-1 +offset+ _ord_["a"]);
            CLL = col""row_top;
            CLL2 = col""(row_top+1);
            #printf("\"=IF(AND(ISNUMBER(INDIRECT(ADDRESS(ROW(),%s1,4,1))),ISNUMBER(INDIRECT(ADDRESS(ROW(),%s2,4,1))),INDIRECT(ADDRESS(ROW(),%s2,4,1))>0),INDIRECT(ADDRESS(ROW(),%s1,4,1))/INDIRECT(ADDRESS(ROW(),%s2,4,1)),\"\"\"\")\"%s", col,col,col, col, col, sep) > out_file;;
            printf("\"=IF(AND(ISNUMBER(INDIRECT(ADDRESS(ROW(),%s,4,1))),ISNUMBER(INDIRECT(ADDRESS(ROW(),%s,4,1))),INDIRECT(ADDRESS(ROW(),%s,4,1))>0),INDIRECT(ADDRESS(ROW(),%s,4,1))/INDIRECT(ADDRESS(ROW(),%s,4,1)),\"\"\"\")\"%s", CLL,CLL2,CLL2, CLL, CLL2, sep) > out_file;;
            #printf("%.5f,", val[1]/val[fl]);
          } else {
            printf("%s", sep) > out_file;;
          }
        }
        }
        printf("%s\n", lbl) > out_file;;
        rows++;
      }
     }
     exit;
  }
   ' $INF
  exit $?
