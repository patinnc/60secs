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

ck_last_rc() {
   local RC=$1
   local FROM=$2
   if [ $RC -gt 0 ]; then
      echo "$0: got non-zero RC=$RC at $LINENO. called from line $FROM" > /dev/stderr
      exit $RC
   fi
}

while getopts "hvb:d:e:i:l:n:o:r:s:S:t:u:w:x:" opt; do
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
    w )
      WORK_DIR=$OPTARG
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
      echo "   -w work_dir     output tsvs"
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

CK_LST="$SCR_DIR $SCR_DIR/../repos $SCR_DIR/.."
CK_GAWK=$(which gawk)
if [ "$CK_GAWK" == "" ]; then
  for i in $CK_LST; do
    if [ -d "$i/patrick_fay_bin" ]; then
      SCR_BIN_DIR=$i/patrick_fay_bin
      export PATH=$($SCR_BIN_DIR):$PATH
      break
    fi
  done
fi
export LC_ALL=C
CK_GAWK=$(which gawk)
echo "$0.$LINENO got gawk path $CK_GAWK"
AWK="awk"
if [ "$CK_GAWK" != "" ]; then
  AWK=$CK_GAWK
fi

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
  RESP=`find $DIR_IN -name $LOOKFOR | wc -l | $AWK '{$1=$1;print $1}'`
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
PROFILE=" --profile "
PROFILE=

$AWK $PROFILE -v xls_str="$XLS_STR" -v sku_str="$SKU_STR" -v ratio_cols="$RATIO_COLS" -v out_file="$OUT_FILE" -v layout="$LAYOUT" -v sep="$SEPARATOR" '
 BEGIN{
      need_SI_ncu_combined = 0;
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
  /val_arr all_vals|val_arr avg|val_arr0 all_vals|val_arr0 avg/ {
    next;
  }
  /Metric|metric/{
    n = split($0, arr, "\t");
    if (did_metric == 0) {
     for (i=1; i <= NF; i++) {
      if (tolower($i) == "metric") {
         sm1 = "";
         sp1 = "";
         if (i > 1) { sm1 = tolower($(i-1)); }
         if (i < NF) { sp1 = tolower($(i+1)); }
         if (i > 1 && (sm1 == "average" || sm1 == "value" || index(sm1, "avg") > 0) ) {
           did_metric = 1;
           ky=i;
           vl = i-1;
           break;
         }
         if (NF > 1 && (sp1 == "average" || sp1 == "value" || index(sp1, "avg") > 0) ) {
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
    if (arr[ky] == "num_cpus") {
      num_cpus[mx_fl] = ck_for_eq_sign(arr[vl]) + 0.0;
    }
    if (arr[ky] == "SI NCU score_v3") {
      SI_ncu_score_v3[mx_fl] = ck_for_eq_sign(arr[vl]) + 0.0;
    }
    if (arr[ky] == "SI cpus") {
      cv = ck_for_eq_sign(arr[vl]) + 0.0;
      SI_cpus[mx_fl] = cv;
      if (num_cpus[mx_fl] != "") {
        v25 = num_cpus[mx_fl]/4;
        v50 = num_cpus[mx_fl]/2;
        v75 = v25*3;
        v100= num_cpus[mx_fl];
        if (cv == v25) {
          need_SI_ncu_combined_pct[mx_fl] = 25;
        }
        if (cv == v50) {
          need_SI_ncu_combined_pct[mx_fl] = 50;
        }
        if (cv == v75) {
          need_SI_ncu_combined_pct[mx_fl] = 75;
        }
        if (cv == v100) {
          need_SI_ncu_combined_pct[mx_fl] = 100;
        }
        need_SI_ncu_combined_arr[mx_fl] = 0;
        printf("_____tst need_SI_ncu_combined, v25= %s v50= %f v75= %f v100= %f, cv= %f\n", v25, v50, v75, v100, cv) > "/dev/stderr";
        if (cv == (v25 - 4) || cv == (v25 + 4) ||
            cv == (v75 - 4) || cv == (v75 + 4)) {
            need_SI_ncu_combined_arr[mx_fl] = 1;
            need_SI_ncu_combined = 1;
            need_SI_ncu_combined_pct[mx_fl] = "";
            printf("_____got need_SI_ncu_combined = %d\n", need_SI_ncu_combined) > "/dev/stderr";
            if ((cv == (v25 + 4) && SI_cpus[mx_fl-1] == (v25-4)) ||
                (cv == (v75 + 4) && SI_cpus[mx_fl-1] == (v75-4))) {
              printf("_____use need_SI_ncu_combined = %d\n", mx_fl) > "/dev/stderr";
              need_SI_ncu_combined_arr[mx_fl] = 2;
              if (cv == (v25 + 4)) {
                need_SI_ncu_combined_pct[mx_fl] = 25;
              }
              if (cv == (v75 + 4)) {
                need_SI_ncu_combined_pct[mx_fl] = 75;
              }
            }
            
        }
      }
      if (mx_fl == 20) {
        printf("++++++++++++ SI_cpus[%d]= %d, num_cpus[%d]= %d, pct= %s\n", mx_fl, SI_cpus[mx_fl], mx_fl, num_cpus[mx_fl], need_SI_ncu_combined_pct[mx_fl]) > "/dev/stderr";
      }
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
         if (index(arr[1], "MATCH(MAX") > 0) {
           arr[1] = "";
         }
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
function ck_for_eq_sign(str)
{
    if (index(str, "=") == 1) {
      return substr(str, 2, length(str));
    } else {
      return str;
    }
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
         gi =  sv[i,fl,3];
         a2 = gstr_lkup2[gi];
         slbl = a2 " " lbl;
         ulbl = lbl;
         if (lbl != "") {
           if (!(lbl in myhsh)) {
             ulbl = lbl;
             myhsh[ulbl] = 0;
           } else {
             ulbl = slbl;
             if (!(ulbl in myhsh)) {
               myhsh[ulbl] = 0;
             } else {
               #printf("slbl= \"%s\", lbl= %s a2= %s, gi= %s, gs= %s\n", slbl, lbl, a2, gi, gstr_lkup[gi]) > "/dev/stderr";
               ++myhsh[ulbl];
               ulbl = ulbl "_" myhsh[ulbl];
             }
           }
           if (!(ulbl in lbl_list)) {
             lbl_list[ulbl] = ++lbl_mx;
             lbl_lkup[lbl_mx] = ulbl;
           }
           lbl_i = lbl_list[ulbl];
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
SI_mx = 0;
SI_arr[++SI_mx]="SI 500.perlbench_r ratio 1";
SI_arr[++SI_mx]="SI 500.perlbench_r ratio 2";
SI_arr[++SI_mx]="SI 500.perlbench_r ratio 3";
SI_arr[++SI_mx]="SI 500.perlbench_r copies 1";
SI_arr[++SI_mx]="SI 500.perlbench_r copies 2";
SI_arr[++SI_mx]="SI 500.perlbench_r copies 3";
SI_arr[++SI_mx]="SI 500.perlbench_r run_time 1";
SI_arr[++SI_mx]="SI 500.perlbench_r run_time 3";
SI_arr[++SI_mx]="SI 500.perlbench_r run_time 2";
SI_arr[++SI_mx]="SI 520.omnetpp_r ratio 1";
SI_arr[++SI_mx]="SI 520.omnetpp_r ratio 2";
SI_arr[++SI_mx]="SI 520.omnetpp_r ratio 3";
SI_arr[++SI_mx]="SI 520.omnetpp_r copies 1";
SI_arr[++SI_mx]="SI 520.omnetpp_r copies 2";
SI_arr[++SI_mx]="SI 520.omnetpp_r copies 3";
SI_arr[++SI_mx]="SI 520.omnetpp_r run_time 1";
SI_arr[++SI_mx]="SI 520.omnetpp_r run_time 2";
SI_arr[++SI_mx]="SI 520.omnetpp_r run_time 3";
SI_arr[++SI_mx]="SI 523.xalancbmk_r ratio 1";
SI_arr[++SI_mx]="SI 523.xalancbmk_r ratio 2";
SI_arr[++SI_mx]="SI 523.xalancbmk_r ratio 3";
SI_arr[++SI_mx]="SI 523.xalancbmk_r ratio 4";
SI_arr[++SI_mx]="SI 523.xalancbmk_r copies 1";
SI_arr[++SI_mx]="SI 523.xalancbmk_r copies 2";
SI_arr[++SI_mx]="SI 523.xalancbmk_r copies 3";
SI_arr[++SI_mx]="SI 523.xalancbmk_r copies 4";
SI_arr[++SI_mx]="SI 523.xalancbmk_r run_time 1";
SI_arr[++SI_mx]="SI 523.xalancbmk_r run_time 2";
SI_arr[++SI_mx]="SI 523.xalancbmk_r run_time 3";
SI_arr[++SI_mx]="SI 523.xalancbmk_r run_time 4";
SI_arr[++SI_mx]="SI new score_v2 valid? omnetpp.perlbench.xalanc";
SI_arr[++SI_mx]="SI new score_v2";
SI_arr[++SI_mx]="SI NCU score_v3";
SI_arr[++SI_mx]="SI cpus";
SI_arr[++SI_mx]="SI NCU score_average"; SI_sc_avg= SI_mx;
SI_arr[++SI_mx]="SI NCU score_pct_sys"; SI_sc_pct= SI_mx;
SI_arr[++SI_mx]="SI NCU score_avg_of_4pcts"; SI_sc_avg_of_avg= SI_mx;
SI_arr[++SI_mx]="SI NCU score_sum_at_pct"; SI_sc_sum_at_pct= SI_mx;
     
     SI_did = 0;
     SI_cur = 0;
     tm_beg = systime();
     for (g=1; g <= gstr_mx; g++) {
      #for (i=1; i <= lbl_mx; i++) 
      ii = 0;
      if ((g % 1000) == 0) {
        tm_cur = systime();
        printf("elap_secs= %d g/s= %.3f g= %d of %d, str= %s\n", tm_cur-tm_beg, g/(tm_cur-tm_beg), g, lbl_mx, gstr_lkup2[g]) > "/dev/stderr";
      }
      if (gstr_lkup2[g] == "SI benchmark") {
        if (++SI_did > 1) {continue; }
      }
      while (ii <= lbl_mx) {
        #  ++ii;
        doing_SI = 0;
        #if (did_ii[ii] == mx_fl) { continue; } # doesnt work
        #if (ckd_ii_has_ck_gstr_g_1y_2n[ii,g] == 2) { continue; }
        if (gstr_lkup2[g] == "SI benchmark") {
          SI_cur++;
          doing_SI_sc_avg=0;
          doing_SI_sc_pct=0;
          doing_SI_sc_avg_of_avg=0;
          doing_SI_sc_sum_at_pct=0;
          if ((SI_cur == SI_sc_avg || SI_cur == SI_sc_pct || SI_cur == SI_sc_avg_of_avg || SI_cur == SI_sc_sum_at_pct) && need_SI_ncu_combined == 0) {
            SI_cur++; # skip the line
            printf("__________skip %s\n", SI_arr[SI_cur]) > "/dev/stderr";
          }
          if (SI_cur == SI_sc_avg && need_SI_ncu_combined == 1) {
             printf("__________got  %s, layout= %d\n", SI_arr[SI_cur], layout) > "/dev/stderr";
             doing_SI_sc_avg=1;
          }
          if (SI_cur == SI_sc_pct && need_SI_ncu_combined == 1) {
             printf("__________got  %s, layout= %d\n", SI_arr[SI_cur], layout) > "/dev/stderr";
             doing_SI_sc_pct=1;
          }
          if (SI_cur == SI_sc_avg_of_avg && need_SI_ncu_combined == 1) {
             printf("__________got  %s, layout= %d\n", SI_arr[SI_cur], layout) > "/dev/stderr";
             doing_SI_sc_avg_of_avg=1;
          }
          if (SI_cur == SI_sc_sum_at_pct && need_SI_ncu_combined == 1) {
             printf("__________got  %s, layout= %d\n", SI_arr[SI_cur], layout) > "/dev/stderr";
             doing_SI_sc_sum_at_pct=1;
          }
          if (SI_cur > SI_mx) {
            break;
          }
          #printf("try SI_B[%d]= %s\n", SI_cur, SI_arr[SI_cur]);
          i = lbl_list[SI_arr[SI_cur]];
          if (i == "" && doing_SI_sc_avg == 0 && doing_SI_sc_pct == 0 && doing_SI_sc_avg_of_avg == 0 && doing_SI_sc_sum_at_pct == 0) {
            #printf("skp SI_B[%d]= %s\n", SI_cur, SI_arr[SI_cur]);
            continue;
          }
          doing_SI = 1;
        } else {
          i = ++ii;
          #i = ii;
        }
        kk = i;
        lbl=lbl_lkup[i];
        got_2 = 0;
        prtd=0;
        if (layout == 1) {
         got_gstr = 0;
         for (fl=1; fl <= mx_fl; fl++) {
          j = lbl_arr[i,fl];
          ck_gstr_g = gstr_lkup2[g];
          ck_gstr_fl = gstr_lkup2[sv[j,fl,3]]
          #if (sv[j,fl,3] == g) 
          if (ck_gstr_g == ck_gstr_fl) {
             ckd_ii_has_ck_gstr_g_1y_2n[i,g] = 1;
             got_gstr = 1;
             break;
          }
         }
         if (doing_SI_sc_avg == 1 || doing_SI_sc_pct == 1) {
          lbl = SI_arr[SI_cur];
          got_gstr = 1;
         }
         if (doing_SI_sc_avg == 1 || doing_SI_sc_avg_of_avg == 1) {
          lbl = SI_arr[SI_cur];
          got_gstr = 1;
         }
         if (doing_SI_sc_avg == 1 || doing_SI_sc_sum_at_pct == 1) {
          lbl = SI_arr[SI_cur];
          got_gstr = 1;
         }
        } else {
          got_gstr = 1;
        }
         if (got_str == 0) {
             ckd_ii_has_ck_gstr_g_1y_2n[i,g] = 2;
         }
        if (got_gstr == 1) {
         if (layout == 1) {
            lstr = lbl;
            ck_str =  gstr_lkup2[g]"\t"lstr;
            if (ck_did_already[ck_str] != "") {
              continue;
            }
            ck_did_already[ck_str] = 1;
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
            #printf("grp= %s lkup= %s, lstr= %s\n", gstr_lkup1[g], gstr_lkup2[g], lstr) > "/dev/stderr";
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
             if (doing_SI_sc_avg == 1 || doing_SI_sc_pct == 1) {
                lbl = SI_arr[SI_cur];
             }
             if (doing_SI_sc_avg == 1 || doing_SI_sc_avg_of_avg == 1) {
                lbl = SI_arr[SI_cur];
             }
             if (lbl == "SI NCU score_v3") {
               printf("______ lbl= %s, cpus= %s, si_cpus= %s, si_ncu_score= %s\n", lbl, num_cpus[fl], SI_cpus[fl], SI_ncu_score_v3[fl]) > "/dev/stderr";
             }
             val[fl] = sv[j,fl,2];
             if (doing_SI_sc_avg == 1) {
               val[fl] = "";
               if (need_SI_ncu_combined_arr[fl] == 2) {
                  val[fl] = 0.5 * (SI_ncu_score_v3[fl] + SI_ncu_score_v3[fl-1]);
               } else if (need_SI_ncu_combined_arr[fl] == 0) {
                  val[fl] = SI_ncu_score_v3[fl];
               }
               SI_ncu_score_v3_sv[fl] = val[fl];
               j = 1;
             } 
             if (doing_SI_sc_pct == 1) {
               val[fl] = "";
               val[fl] = need_SI_ncu_combined_pct[fl];
               j = 1;
             } 
             if (doing_SI_sc_avg_of_avg == 1) {
               val[fl] = "";
               if (need_SI_ncu_combined_pct[fl] == 100) {
                 aoa_n = 0;
                 aoa_sum = 0.0;
                 delete aoa_got_arr;
                 for (aoa_i= fl; aoa_i >= 0; aoa_i--) {
                   v = need_SI_ncu_combined_pct[aoa_i];
                   #printf("ck  pct0= %s\n", v) > "/dev/stderr";
                   if (v == "") { continue; }
                   v = sprintf("%d", v + 0.1) + 0;
                   #printf("got pct1= %s\n", v) > "/dev/stderr";
                   if (v == 100 || v == 75 || v == 50 || v == 25) {
                     if (aoa_got_arr[v] == "") {
                       aoa_got_arr[v] = v;
                       aoa_sum += SI_ncu_score_v3_sv[aoa_i];
                       aoa_n++;
                       #printf("got pct2= %s, n= %d\n", v, aoa_n) > "/dev/stderr";
                     } else {
                       #printf("brk pct3= %s\n", v) > "/dev/stderr";
                       break;
                     }
                   }
                 }
                 if (aoa_n == 4) {
                   val[fl] = aoa_sum/aoa_n;
                 }
               }
               j = 1;
             } 
             if (doing_SI_sc_sum_at_pct == 1) {
               val[fl] = "";
               j = 1;
               v = need_SI_ncu_combined_pct[fl];
               if (v != "") {
                 v1 = num_cpus[fl];
                 v2 = SI_ncu_score_v3_sv[fl];
                 val[fl] = 0.01 * v * v1 * v2;
               }
             } 
             if (lbl == "SI NCU score_average") {
               printf("______ lbl= %s, doing_SI_sc_avg= %d, need_SI_ncu_combined_arr[fl]= %d  cpus= %s, si_cpus= %s, si_ncu_score= %s, comb_val= %f cmb_valm1= %f\n",
                  lbl, doing_SI_sc_avg, need_SI_ncu_combined_arr[fl] , num_cpus[fl], SI_cpus[fl], SI_ncu_score_v3[fl], SI_ncu_score_v3[fl-1], val[fl]) > "/dev/stderr";
             }
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
        did_ii[i]++;
        rows++;
      }
     }
     exit;
  }
   ' $INF
   RC=$?
  ck_last_rc $RC $LINENO

  exit $?
