#!/bin/bash
FILE_LIST=
SHEET=
NLIMIT=
METRIC="avg"
ROWS_MAX="-1"
VERBOSE=0
OPTIONS=

while getopts "hvc:f:g:m:n:o:O:r:s:t:" opt; do
  case ${opt} in
    c )
      CHRT_TYP=$OPTARG
      ;;
    f )
      FILE_LIST=$OPTARG
      ;;
    g )
      GREP_STR=$OPTARG
      ;;
    m )
      METRIC=$OPTARG
      ;;
    n )
      NLIMIT=$OPTARG
      ;;
    o )
      FL_OUT=$OPTARG
      ;;
    O )
      OPTIONS=$OPTARG
      ;;
    r )
      ROWS_MAX=$OPTARG
      ;;
    s )
      SHEET=$OPTARG
      ;;
    t )
      TITLE=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 read chart table from files in -f file_list, match columns across files, average the data, sort by hi to low, regen table."
      echo "Usage: $0 -f file_list [ -g grep_str ] -o out_file -s sheet_nm_to_find -t title_chart -c chart_typ"
      echo "   -c chart_type  chart_type to look for in TSV 'title' line. like column or scatter_line or line_stacked or line"
      echo "   -f file_list   this is the input file to tsv_2_xlsx.py"
      echo "   -g grep_str    string to use to grep the file_list to avoid reading all the TSVs."
      echo "   -m metric      compute 'avg', 'sum' 'sum_per_server'. default is avg"
      echo "   -n file_select_list  select files: enter string like 1 for file 1 in list (first file is 0) or 10-20 (for files 10 to 20) or 0,2,5-100 etc"
      echo "   -o output_file   filename for rebuilt chart table"
      echo "   -O options     currently only 'nosort' is supported"
      echo "   -r rows_max    you can get more rows or cols due to hashing the categories across multiple files"
      echo "                  use -r rows_max to increase the number of rows displayed. The default is to display rows == max number of rows in any input table"
      echo "   -s sheet_name  sheet name to look for in TSV 'title' line"
      echo "   -t title_of_chart  chart title to look for in TSV 'title' line"
      echo "   -v verbose mode"
      exit 1
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument. cmdline= ${@}" 1>&2
      exit 1
      ;;
    \? )
      echo "Invalid option: $OPTARG, cmdline= ${@} " 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ "$FILE_LIST" == "" ]; then
  echo "$0: you must specify -f input_file_list (like -f tmp1.jnk)"
  exit 1
fi
if [ ! -e $FILE_LIST ]; then
  echo "didn't find file -f $FILE_LIST"
  exit 1
fi
FLS=()
RESP=0
if [ "$GREP_STR" != "" ]; then
  RESP=`grep $GREP_STR $FILE_LIST|wc -l|awk '{$1=$1;print($1)}'`
  if [ "$VERBOSE" != "0" ]; then
  echo "got $RESP lines from grep $GREP_STR $FILE_LIST"
  fi
  if [ "$RESP" == "0" ]; then
    echo "$0: didn't find any line for grep $GREP_STR $FILE_LIST"
    #exit 1
  else
  FILES=`grep $GREP_STR $FILE_LIST`
  FLS=(`echo $FILES`)
  fi
fi
if [ "$RESP" == "0" ]; then
  FILES=`awk '{if ($0 != ""){v=substr($1, 1,1); if (v != "-" && v != "#") {print($0);}}}' $FILE_LIST`
  RESP=`echo "$FILES" |wc -l| awk '{$1=$1;print($1);}'`
  echo "got $RESP files"
  FLS+=(`echo $FILES`)
fi
if [ "$VERBOSE" != "0" ]; then
  echo "FLS= ${#FLS[@]}"
fi
#echo "FLS= ${FLS[@]}"


if [ "$FL_OUT" == "" ]; then
  echo "$0: have to specify output file. -o out_file"
  exit 1
fi

if [ "$TITLE" == "" ]; then
  echo "$0: have to specify -t chart_title"
  exit 1
fi

if [ "$TITLE" != "__all__" ]; then
  if [ "$CHRT_TYP" == "" ]; then
    echo "$0: have to specify chart type: -c chart_type"
    exit 1
  fi
  
  if [ "$SHEET" == "" ]; then
    echo "$0: have to specify -s sheet_nm"
    exit 1
  fi
  
  if [ "$METRIC" != "avg" -a "$METRIC" != "sum" -a "$METRIC" != "sum_per_server" ]; then
    echo "$0: metric must be avg, sum or sum_per_server. got -m $METRIC"
    exit 1
  fi
fi

USE_FLS=()
HOST_NUM_LIST=
if [ "$NLIMIT" != "" ]; then
  NUM_HOST=${#FLS[@]}
  HOST_NUM=$NLIMIT
  HOST_NUM_LIST=(`awk -v beg="0" -v end="$NUM_HOST" -v str="$HOST_NUM" '
     BEGIN{
        # handle 1 or 0-2 or 0,3 or 0,1-3,7
        # return array of value
        nc=split(str, carr, ",");
        mx=0;
        for (i=1; i <= nc; i++) {
          if (index(carr[i], "-") == 0) {
            varr[++mx] = carr[i];
          } else {
            nd=split(carr[i], ndarr, "-");
            nb = -1;
            ne = -1;
            if (nd == 2) { nb=ndarr[1]; ne =ndarr[2];} 
            if (nd < 2) {
               if (substr(carr[i], 1, 1) == "-") {
                 nb = beg;
               }
               if (substr(carr[i], length(carr[i]),1) == "-") {
                 nb = end;
               }
            }
            if (nb == -1) { nb = beg;}
            if (ne == -1) { ne = end;}
            for (j=nb; j <= ne; j++) {
              varr[++mx] = j;
            }
          }
        }
        # get rid of dupes
        vmx = -1;
        drop_lst="";
        drops =0;
        for (i=1; i <= mx; i++) {
          varr[i] += 0;
          if (varr[i] < beg) { drop_lst= drop_lst " " varr[i]; drops++; }
          if (varr[i] > end) { drop_lst= drop_lst " " varr[i]; drops++; }
          if (varr[i] < beg) { continue; }
          iarr[varr[i]] = 1;
          if (varr[i] > vmx) {
            vmx = varr[i];
          }
        }
        if (drops > 0) { printf("dropping %d values: %s\n", drops, drop_lst) > "/dev/stderr"; }
        if (vmx == -1) {
           printf("didnt find valid system numbers for option \"-N %s\". Expected them to be between %s and %s. Bye\n", str, beg, end) > "/dev/stderr";
           printf("-1\n");
           exit 1;
        }
        lstr="";
        ostr="";
        for (i=0; i <= vmx; i++) {
          if (iarr[i] == 1) {
            ostr = ostr "" i "\n";
            lstr = lstr " " i;
          }
        }
        #printf("%f\n", 1.0/0.0); # force error for checking error handling
        printf(ostr);
        if (verbose > 0) {
          printf("%s\n", lstr) > "/dev/stderr";
        }
        exit 0;
     }'`)
     RC=$?
     if [ "$RC" != "0" ]; then
        echo "$0: got error on select files awk code. RC= $RC at line= $LINENO" > /dev/stderr
        exit $RC
     fi
     if [ "${HOST_NUM_LIST[0]}" == "-1" ]; then
        echo "$0: didn't find valid system numbers in cmdline option -N $HOST_NUM. Bye" > /dev/stderr
        exit 1
     fi
  echo "entries in HOST_NUM_LIST= ${#HOST_NUM_LIST[@]}"
  if [ $VERBOSE -gt 0 ]; then
    echo "entries in HOST_NUM_LIST= ${#HOST_NUM_LIST[@]}  HOST_NUM_LIST= ${HOST_NUM_LIST[@]}"
  fi
  HOST_NUM_BEG=${HOST_NUM_LIST[0]}
  HOST_NUM_END=${HOST_NUM_LIST[${#HOST_NUM_LIST[@]}-1]}
  echo "HOST_NUM_BEG= $HOST_NUM_BEG, HOST_NUM_END= $HOST_NUM_END"
  for ((i=0; i < ${#HOST_NUM_LIST[@]}; i++)); do
    echo "use file $i  FLNUM= ${HOST_NUM_LIST[$i]}"
    USE_FLS[${HOST_NUM_LIST[i]}]=1;
  done
fi

mx=${#FLS[@]}
#if [ $NLIMIT -gt 0 -a $mx -gt $NLIMIT ]; then
#  echo "limiting $mx number of files to $NLIMIT"
#  mx=$NLIMIT
#fi

FILE_STR=
j=0
for ((i=0; i < $mx; i++)); do
  if [ "${#USE_FLS[@]}" == "0" -o "${USE_FLS[$i]}" == "1" ]; then
    j=$((j+1))
    FILE_STR="$FILE_STR ${FLS[$i]}"
  fi
done

if [ $j -lt 10 ]; then
  echo "file_str= $FILE_STR"
fi

awk -v options="$OPTIONS" -v out_file="$FL_OUT" -v verbose="$VERBOSE" -v rows_max="$ROWS_MAX" -v metric="$METRIC" -v chrt_typ="$CHRT_TYP" -v sheet="$SHEET" -v title="$TITLE" '
   BEGIN {
     search = sprintf("^title\t%s\tsheet\t%s\ttype\t%s", title, sheet, chrt_typ);
     if (title == "__all__") {
        search = "";
     }
     #printf("use search= \"%s\"\n", search);
     got_tbl = 0;
     rows_max += 0;
     if (out_file == "") {
        out_file = "/dev/stdout";
     }
   }
function sort_desc(i1, v1, i2, v2,   lhs, rhs)
{
    lhs = avg[i1,dindx];
    rhs = avg[i2,dindx];
    if (lhs > rhs)
        return -1
    else if (lhs == rhs)
        return 0
    else
        return 1
}
function sort_a_desc(i1, v1, i2, v2,   lhs, rhs)
{
    lhs = avg[i1];
    rhs = avg[i2];
    if (lhs > rhs)
        return -1
    else if (lhs == rhs)
        return 0
    else
        return 1
}
   {
     rw = ++rows[ARGIND];
     if (mx_fls < ARGIND) {
       mx_fls = ARGIND;
     }
     if (ARGIND != prev_ARGIND) {
       got_tbl = 0;
       got_hdr = 0;
       flnm[ARGIND] = ARGV[ARGIND];
       if (verbose > 0) {
         printf("flnm[%d]= %s\n", ARGIND, flnm[ARGIND]);
       }
       prev_ARGIND = ARGIND;
       delete ch_rw;
     }
     n = split($0, arr, "\t");
     if (arr[1] == "title") {
       if (search != ""){
          if (match($0, search) == 0) {
            next;
          }
       }
       tbls[ARGIND]++;
       tbls_this_file = tbls[ARGIND];
       ch_title = arr[2];
       if (!(ch_title in ch_list)) {
         ++ch_mx;
         ch_list[ch_title] = ch_mx;
         ch_lkup[ch_mx] = ch_title;
         ch_file[ch_mx] = ARGIND;
       }
       chrt = ch_list[ch_title];
       ky = ARGIND","chrt;
       tbls_list[ky] = 1;
       tbls[ARGIND, "list", tbls_this_file] = chrt;
       #printf("got tbls[%d]= %d\n", ARGIND, chrt);
       got_tbl = 1;
       got_hdr=0;
     }
     if (got_tbl == 1) {
       #printf("got line= %s\n", $0);
       #  printf("rw= %d row_beg= %d row_end= %d\n", rw, row_beg, row_end);
       n = split($0, arr, "\t");
       if (arr[1] == "title") {
         hdrs[ARGIND,chrt,"title"] = $0;
         hdrs[ARGIND,chrt,"title_row"] = rw;
         drw=0
       }
       #hdrs    829     0       870     1       0
       if (arr[1] == "hdrs") {
         got_hdr=1;
         row_beg = arr[2]+0;
         row_end = arr[4]+0;
         hdrs[ARGIND,chrt,"hdrs"] = $0;
         hdrs[ARGIND,chrt,"hdrs_row"] = rw;
         if (!(row_beg in ch_rw)) {
            ch_rw[row_beg] = chrt;
            if (verbose > 0) {
              printf("chrt %d at rw= %d new reference chart %d\n", chrt, rw, chrt);
            }
         } else {
            if (verbose > 0) {
              printf("chrt %d at rw= %d references chart %d\n", chrt, rw, ch_rw[row_beg]);
            }
         }
         hdrs[ARGIND,chrt,"chrt_ref"] = ch_rw[row_beg];
         diff = (row_beg+1) - rw;
         hdrs[ARGIND,chrt,"data_row_diff"] = diff;
         if (ARGIND == 1) {
           if (verbose > 0) {
             printf("ARGIND= %d, chrt= %d rw= %d row_beg= %d row_end= %d, data_row_diff= %d\n", ARGIND, chrt, rw, row_beg, row_end, diff);
           }
         }
       }
       if (got_hdr == 1 && row_end == -1 && rw >= row_beg && $0 == "") {
         got_tbl = 0;
       }
       if (got_hdr == 1 && row_end != -1 && rw >= row_end) {
         got_tbl = 0;
       }
       drw++;
       tbl[ARGIND,chrt,"tbl", drw] = $0;
       tbl[ARGIND,chrt,"rows"] = drw;
     }
     ftbl[ARGIND,"got_tbl",rw] = got_tbl;
     ftbl[ARGIND,"chrt_num",rw]  = chrt;
     ftbl[ARGIND,"row_data",rw] = $0;
   }
   END {
       # ---------- above all the data has been read in
#title   pidstat average %CPU    sheet   pidstat type    column
#hdrs    829     0       870     1       0
     #printf("tbls[1]= %d\n", tbls[1]);
     #k = tbls[1];
     #for(i=2; i <= mx_fls; i++) {
     #   if (tbls[i] != k) {
     #     printf("expected %d tables. got %d tbls in %s. Bye\n", k, tbls[i], flnm[i]);
     #     exit 1;
     #   }
     #}
     if (verbose > 0) {
       printf("ch_mx= %d\n", ch_mx);
     }
     for(c=1; c <= ch_mx; c++) {
       mx_rws = -1;
       mn_rws = -1;
       cat_mx = 0;
       delete cat_list;
       delete cat_lkup;
       delete col_lkup;
       delete val;
       delete num;
       delete rnum;
       delete rval;
       for(i=1; i <= mx_fls; i++) {
         rws = tbl[i,c,"rows"];
         if (nm_rws == -1 || mn_rws > rws) {
           mn_rws = rws;
         }
         if (mx_rws < rws) {
           mx_rws = rws;
         }
       }
       #printf("tbls[%d] min_rows= %d max_rows= %d, cmdline ROWS_MAX to be displayed= %d\n", c, mn_rws, mx_rws, rows_max);
       if (rows_max != -1 && rows_max > mx_rws) {
          mx_rws = rows_max;
       }
       # ---------- now, for each chart, read each files data and hash the column names
       # ---------- store each files row/col data in the appropriate hash box.
       for(i=1; i <= mx_fls; i++) {
         ky = i","c;
         if (!(ky in tbls_list)) {
            continue;
         }
         rws = tbl[i,c,"rows"];
         got_hdrs= 0;
         for (j=1; j <= rws; j++) {
           #printf("tbl[%d,%d]= %s\n", i, j, tbl[i,c,"tbl",j]);
           n = split(tbl[i,c,"tbl",j], arr, "\t");
           if (arr[1] == "title") {
              title= arr[2];
              sheet= arr[4];
              need_col_hdr = 0;
              ch_typ= arr[6];
              if (ch_typ == "column") {
                need_col_hdr = 1;
              }
              trow = hdrs[i,c,"title_row"];
              #printf("trow[%d]= %d\n", c, trow);
              got_hdrs= 0;
              continue;
           }
           if (got_hdrs == 0 && arr[1] == "hdrs") {
              got_hdrs = 1;
              row_beg = arr[2];
              col_beg = arr[3];
              row_end = arr[4];
              col_end = arr[5];
              col_cat = arr[6];
              #printf("row_beg= %d, col_beg= %d, row_end= %d, col_end= %d\n", row_beg, col_beg, row_end, col_end);
              continue;
           }
           if (need_col_hdr == 1) {
              gcol_category_line[c] = tbl[i,c,"tbl",j];
              need_col_hdr = 0;
              continue;
           }
           crow = trow + j - 2;
           if (n == 0) { continue; }
           if (ch_typ == "scatter_straight" || ch_typ == "line" || ch_typ == "line_stacked") {
             #if(j < 10) {
             #  printf("crow= %d, row_beg= %d, trow= %d\n", crow, row_beg, trow);
             #}
             if (crow == row_beg) {
               for (k=col_beg+1; k <= n; k++) {
                cat = arr[k];
                if (cat == "") {
                  cat = "__unk__";
                }
                if (!(cat in cat_list)) {
                   cat_list[cat] = ++cat_mx;
                   cat_lkup[cat_mx] = cat;
                   gcat_list[c,cat] = cat_mx;
                   gcat_lkup[c,cat_mx] = cat;
                   gcat_mx[c] = cat_mx;
                   #printf("add cat[%d][%d]= %s\n", c, cat_mx, cat);
                }
                col_lkup[k] = cat_list[cat];
               }
               continue;
             }
             #if (crow >= (row_beg+10)) { exit; }
             if (crow > row_beg && n > 0 && (row_end == -1 || crow <= row_end)) {
               for (k=col_beg+1; k <= (col_end+1); k++) {
                  cat_i = col_lkup[k];
                  val[cat_i] += arr[k];
                  num[cat_i]++;
                  rval[cat_i,j] += arr[k];
                  rnum[cat_i,j]++;
               }
             }
           }
           if (ch_typ == "column" && col_cat != "") {
              cat = arr[col_cat+1];
              if (cat == "") {
                cat = "__unk__";
              }
              if (!(cat in cat_list)) {
                 cat_list[cat] = ++cat_mx;
                 cat_lkup[cat_mx] = cat;
                 gcat_list[c,cat] = cat_mx;
                 gcat_lkup[c,cat_mx] = cat;
                 gcat_mx[c] = cat_mx;
              }
              cat_i = cat_list[cat];
              for (k=1; k <= (col_end+1); k++) {
                if (k == (col_cat+1)) { continue; }
                val[cat_i,k] += arr[k];
                num[cat_i,k]++;
              }
           }
         }
       }  # end of loop over files
       # ---------- summary tables have been created. hashes of variable names stored.
       # ---------- sort the values descending order
       i=1; 
       i = ch_file[c]; # the first file that this chart appears in
         rws = tbl[i,c,"rows"];
         got_hdrs= 0;
         for (j=1; j <= rws; j++) {
           n = split(tbl[i,c,"tbl",j], arr, "\t");
           if (arr[1] == "title") {
              title= arr[2];
              sheet= arr[4];
              need_col_hdr = 0;
              ch_typ= arr[6];
              if (ch_typ == "column") {
                need_col_hdr = 1;
              }
              trow = hdrs[i,c,"title_row"];
              if (verbose > 0) {
                printf("file= %d, ch= %d, title= %s trow= %d\n", i, c, arr[2], c, trow);
              }
              got_hdrs= 0;
              continue;
           }
           if (got_hdrs == 0 && arr[1] == "hdrs") {
              got_hdrs = 1;
              row_beg = arr[2];
              col_beg = arr[3];
              row_end = arr[4];
              col_end = arr[5];
              col_cat = arr[6];
              if (verbose > 0) {
                printf("row_beg= %d, col_beg= %d, row_end= %d, col_end= %d\n", row_beg, col_beg, row_end, col_end);
              }
              break;
           }
         }
       delete indx;
       delete srt_indx;
       dindx = -1;
       if (ch_typ == "column") {
         for(i=1; i <= gcat_mx[c]; i++) {
           indx[i]=i;
           for(k=1; k <= (col_end+1); k++) {
              avg[i,k] = 0;
              if ( dindx == -1 && num[i,k] > 0) {
                dindx = k;
              }
              if (metric == "avg" && num[i,k] > 0) {
                avg[i,k] = val[i,k]/num[i,k];
              }
              if (metric == "sum" && num[i,k] > 0) {
                avg[i,k] = val[i,k];
              }
              if (metric == "sum_per_server" && num[i,k] > 0) {
                avg[i,k] = val[i,k]/mx_fls;
              }
           }
         }
         if (index(options, "nosort") > 0) {
           for(i=1; i <= gcat_mx[c]; i++) {
             srt_indx[i]=i;
           }
         } else {
           asorti(indx, srt_indx, "sort_desc");
         }
         for(i=1; i <= gcat_mx[c]; i++) {
           gsrt_indx[c,i] = srt_indx[i];
         }
       }
       if (ch_typ == "scatter_straight" || ch_typ == "line" || ch_typ == "line_stacked") {
         for(i=1; i <= gcat_mx[c]; i++) {
           indx[i]=i;
           avg[i] = 0;
           if (metric == "avg" && num[i] > 0) {
               avg[i] = val[i]/num[i];
           }
           if (metric == "sum" && num[i] > 0) {
              avg[i] = val[i];
           }
           if (metric == "sum_per_server" && num[i] > 0) {
              avg[i] = val[i]/mx_fls;
           }
           for (j=1; j <= rws; j++) {
             if (metric == "avg" && rnum[i,j] > 0) {
                 ravg[i,j] = rval[i,j]/rnum[i,j];
             }
             if (metric == "sum" && rnum[i,j] > 0) {
                ravg[i,j] = rval[i,j];
             }
             if (metric == "sum_per_server" && rnum[i,j] > 0) {
                ravg[i,j] = rval[i,j]/mx_fls;
             }
           }
         }
         if (index(options, "nosort") > 0) {
           for(i=1; i <= gcat_mx[c]; i++) {
             srt_indx[i]=i;
           }
         } else {
           asorti(indx, srt_indx, "sort_a_desc");
         }
         for(i=1; i <= gcat_mx[c]; i++) {
           gsrt_indx[c,i] = srt_indx[i];
         }
       }
       #for(i=1; i <= gcat_mx[c]; i++) {
       #  printf("srt[%d]= %d\n", i, gsrt_indx[c,i]);
       #}
       # -------------- create tab separated strings for each row of data for each chart
       if (verbose > 0) {
          printf("-------- averaged cat_mx= %d ===========\n", gcat_mx[c]);
       }
       fl = 1;
       fl = ch_file[c];
       trow = hdrs[fl,c,"title_row"];
       data_row_diff = hdrs[fl,c,"data_row_diff"];

       if (ch_typ == "scatter_straight" || ch_typ == "line" || ch_typ == "line_stacked") {
         #if (c==2) {
         #  for(m=1; m <= gcat_mx[c]; m++) {
         #    ii = gsrt_indx[c,m];
         #    printf("hdr[%d][%d]= %s\n", c,m,gcat_lkup[c,ii]);
         #  }
         #}
         cr = 0;
         if (verbose > 0) {
           printf("trow= %d, row_beg= %d\n", trow, row_beg);
         }
         ctbl[c,++cr] = sprintf("title\t%s\tsheet\t%s\ttype\t%s\n", title " " metric, sheet, ch_typ);
         blnk_rows = 0;
         for (j=rws-1; j > 0; j--) {
           n = split(tbl[fl,c,"tbl",j], arr, "\t");
           if (arr[1] == "" ) {
              blnk_rows++;
           } else {
              break;
           }
         }
         ctbl[c,++cr] = sprintf("ln hdrs\t%d\t%d\t%d\t%d\t%d\n", row_beg, col_beg, row_beg+rws-blnk_rows, col_end, col_cat);
         if (verbose > 0) {
           printf("ch[%d], rw[%d] = %s\n", c, cr, ctbl[c,cr]);
         }
         do_1st_data_row = -1;
         if (data_row_diff > 0) {
           do_1st_data_row = cr + data_row_diff;
         }
          
         for (j=3; j < rws-blnk_rows; j++) {
           n = split(tbl[fl,c,"tbl",j], arr, "\t");
           crow = trow + j -2;
           sep = "";
           ctbl[c,++cr] = "";
           if (crow < row_beg) {
              n = split(ftbl[fl,"row_data",j+1], arr, "\t");
              #if (j==3){for(jj=0; jj <= 10; jj++){printf("jj= %d %s\n", jj, ftbl[fl,"row_data",jj]);}}

              #printf("j= %d, i=%d\t%s\n", j, crow, ftbl[fl,c,"row_data",crow+1]);
              #printf("j= %d, i=%d\t%s\n", j, j+1, ftbl[fl,c,"row_data",j+1]);
              #printf("j= %d, i=%d\t%s\n", j, j+2, ftbl[fl,c,"row_data",j+2]);
              if (verbose > 0) {
                printf("chrt= %d, trow= %d j= %d\n", c, trow, j);
              }
              ctbl[c,cr] = ctbl[c,cr] " ab ";
              for(m=1; m <= (n); m++) {
                ctbl[c,cr] = ctbl[c,cr] "" sprintf("%s%s", sep, arr[m]);
                sep = "\t";
              }
              ctbl[c,cr] = ctbl[c,cr] "" sprintf("\n");
              continue;
           }
           for(m=1; m <= (col_beg); m++) {
              ctbl[c,cr] = ctbl[c,cr] "" sprintf("%s%s", sep, arr[m]);
              sep = "\t";
           }
           for(m=1; m <= gcat_mx[c]; m++) {
             ii = gsrt_indx[c,m];
             if (do_1st_data_row > -1 && do_1st_data_row == cr) {
                ctbl[c,cr] = ctbl[c,cr] "" sprintf("%s%s", sep, gcat_lkup[c,ii]);
              } else {
                vl = ravg[ii,j];
                ivl = int(vl);
                if (vl == ivl) {
                  ctbl[c,cr] = ctbl[c,cr] "" sprintf("%s%d", sep, ivl);
                } else {
                  ctbl[c,cr] = ctbl[c,cr] "" sprintf("%s%f", sep, vl);
                }
              }
              sep = "\t";
           }
           ctbl[c,cr] = ctbl[c,cr] "" sprintf("\n");
         }
         ctbl[c,"max"] = cr -2;
         if (verbose > 0) {
           printf("line chart= %d, max= %d, for file= %d\n", c, cr, fl);
         }
       }
       if (ch_typ == "column") {
         cr = 0;
         #printf("column chart= %d\n", c);
         ctbl[c,++cr] = sprintf("title\t%s\tsheet\t%s\ttype\t%s\n", title " " metric, sheet, ch_typ);
         #printf("column chart: %s", ctbl[c,cr]);
         ctbl[c,++cr] = sprintf("col hdrs\t%d\t%d\t%d\t%d\t%d\n", trow, col_beg, trow+gcat_mx[c], col_end, col_cat);
         mrws = 0;
         for(m=1; m <= gcat_mx[c]; m++) {
           sep = "";
           ctbl[c,++cr] = "";
           i = gsrt_indx[c,m];
           for(k=1; k <= (col_end+1); k++) {
              if (k == (col_cat+1)) {
                ctbl[c,cr] = ctbl[c,cr] "" sprintf("%s%s", sep, gcat_lkup[c,i]);
              } else {
                ctbl[c,cr] = ctbl[c,cr] "" sprintf("%s%f", sep, avg[i,k]);
              }
              sep = "\t";
           }
           ctbl[c,cr] = ctbl[c,cr] "" sprintf("\n");
           mrws++;
           if (mrws >= mx_rws) { break; }
         }
         ctbl[c,"max"] = cr;
         if (verbose > 0) {
           printf("column chart= %d, max= %d, for file= %d\n", c, cr, fl);
         }
       }
     } # charts on page
     #ftbl[ARGIND,"file_row",rw] = got_tbl;
     #ftbl[ARGIND,"chrt_num",rw]  = chrt_num;
     #ftbl[ARGIND,"row_data",rw] = $0;
     #
     # -------------- now try to recreate the page printing non-table rows and table rows
     #
     last_chrt = -1;
     trow = 0;
     for (cc=1; cc <= ch_mx; cc++) {
     rw = 1;
     #fl = 2;
     fl = ch_file[cc];
     if (fl != 1) {
       break;
     }
     while (rw < rows[fl]) {
        if (ftbl[fl,"got_tbl",rw] == 0) {
           if (fl == 1) {
             printf("%s\n", ftbl[fl,"row_data",rw]) > out_file;
             ++trow;
           }
        } else {
          if (ftbl[fl,"chrt_num",rw] != last_chrt) {
            last_chrt = ftbl[fl,"chrt_num",rw];
            cc = last_chrt;
            #printf("%s", ctbl[cc,1]);

            n = split(hdrs[fl,cc,"title"], arr, "\t");
            ch_typ= arr[6];
            if (ch_typ == "column") {
              if (index(arr[2], " cpus") > 0) {
                gsub(" cpus", " cpu_secs", arr[2]);
              }
            }
            arr[2] = arr[2] " " metric;
            nstr = arr[1];
            for (ij=2; ij <= n; ij++) { nstr = nstr "\t" arr[ij]; }
            printf("%s\n", nstr) > out_file;
            ++trow;

            hr = hdrs[fl,cc,"hdrs_row"];
            chrt_ref = hdrs[fl,cc,"chrt_ref"];
            n = split(hdrs[fl,cc,"hdrs"], arr, "\t");
            rw_diff = arr[2] - hr;
            #printf("rw_diff[%d]= %d\n", cc, rw_diff);
            arr[2] = trow + rw_diff + 1;
            if (chrt_ref != cc) {
              ncr = split(hdrs[fl,chrt_ref,"hdrs"], cr_arr, "\t");
              arr[2] = cr_arr[2];
            }
            row_end= arr[4];
            mx = ctbl[cc,"max"];
            if (row_end != -1) {
               arr[4] = trow+1 + mx;
            }
            if (ch_typ == "column") {
              n2 = split(ctbl[cc,3], arr2, "\t");
              arr[5] = n2-1;
            } else {
              arr[5] = gcat_mx[cc] + arr[3] -1;
              if (chrt_ref != cc) {
                arr[5] = cr_arr[5];
              }
            }
            str = arr[1];
            for (j=2; j <= n; j++) {
               str = str "" sprintf("\t%s", arr[j]);
            }
            printf("%s\n", str) > out_file;
            ++trow;
            if (ch_typ == "column") {
               printf("%s\n", gcol_category_line[cc]) > out_file;
               ++trow;
            }
            #printf("chart[%d], max= %d\n", cc, mx);
            for (j=3; j <= mx; j++) {
              #printf("ch[%d] rw[%d] %s", cc, j, ctbl[cc,j]) > out_file;
              printf("%s", ctbl[cc,j]) > out_file;
              ++trow;
            }
          }
        }
        if (cc == ch_mx) {
          break;
        }
        ++rw;
     }
     }
     if (out_file != "") {
       close(out_file);
     }
   }
   ' $FILE_STR
   RC=$?
   if [ "$RC" != "0" ]; then
     echo "$0: got error in awk script. RC= $RC. script line= $LINENO" > /dev/stderr
   fi
   exit $RC
