#!/bin/bash

#SCR_DIR=`dirname $(readlink -e $0)`
#SCR_DIR=`dirname $0`
#SCR_DIR=`dirname "$(readlink -f "$0")"`
SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo "SCR_DIR= $SCR_DIR" > /dev/stderr

DIR=
PHASE_FILE=
XLSX_FILE=
END_TM=
SKIP_XLS=0
NUM_DIR=0
AVERAGE=0
MAX_VAL=
TS_INIT=
VERBOSE=0
CLIP=
G_SUM=()
OPTIONS=
INPUT_FILE_LIST=
echo "$0 ${@}"

while getopts "hvASc:D:d:e:g:I:m:N:o:P:X:x:" opt; do
  case ${opt} in
    A )
      AVERAGE=1
      ;;
    S )
      SKIP_XLS=1
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    c )
      CLIP=$OPTARG
      ;;
    D )
      DEBUG_OPT=$OPTARG
      ;;
    d )
      DIR=$OPTARG
      echo "input DIR= $DIR"
      ;;
    e )
      END_TM=$OPTARG
      ;;
    g )
      G_SUM+=("$OPTARG")
      ;;
    I )
      INPUT_FILE_LIST=$OPTARG
      ;;
    m )
      MAX_VAL=$OPTARG
      ;;
    N )
      NUM_DIR=$OPTARG
      ;;
    o )
      OPTIONS=$OPTARG
      ;;
    P )
      PHASE_FILE=$OPTARG
      ;;
    X )
      AXLSX_FILE=$OPTARG
      ;;
    x )
      XLSX_FILE=$OPTARG
      ;;
    h )
      echo "$0 split data files into columns"
      echo "Usage: $0 [-h] -d sys_data_dir [-v] [ -p prefix ]"
      echo "   -A   flag indicating you want to average the same file from multiple dirs into 1 sheet."
      echo "          The default is to create 1 sheet per file per directory"
      echo "   -d dir containing sys_XX_* files created by 60secs.sh"
      echo "   -D debug_opt_strings    used for debugging"
      echo "   -g key=val    key value pairs to be added to summary sheet. use multiple -g k=v options to specify multiple key value pairs"
      echo "   -I file_with_list_of_input_files   used for getting a specify list of file proccessed"
      echo "   -m max_val    any value in chart > this value will be replaced by 0.0"
      echo "   -N number_of_dirs  if you have more than 1 directories then you can limit the num of dirs with this option. Default process all"
      echo "   -o options       comma separated options."
      echo "         'drop_summary' is supported which drops summary sheets if you have more than 1 (since the data will be in sum_all sheet"
      echo "         'dont_sum_sockets' if the perf stat data is per-socket then don't sum per-socket data to the system level"
      echo "         'line_for_scatter' substitute line charts for the scatter plots"
      echo "         'drop_summary' don't add a sheet for each summary sheet (if you are doing more than 1 dir). Just do the sum_all sheet"
      echo "   -P phase_file"
      echo "   -S    skip creating detail xlsx file, just do the summary all spreadsheet"
      echo "   -x xlsx_filename  This is passed to tsv_2_xlsx.py as the name of the xlsx. (you need to add the .xlsx)"
      echo "      The default is chart_line.xlsx"
      echo "   -X xlsx_filename  like above but assume path relative to current dir"
      echo "   -e ending_timestamp  cut off data files at this timestamp"
      echo "      useful for runs that mess up before the expected end time"
      echo "   -v verbose mode"
      exit
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument ${@}" 1>&2
      exit
      ;;
    \? )
      echo "Invalid option: $OPTARG ${@}" 1>&2
      exit
      ;;
  esac
done
shift $((OPTIND -1))
remaining_args="$@"

if [ "$remaining_args" != "" ]; then
  echo "remaining args= $remaining_args"
  echo "got args leftover. Usually due to * in -d dir_name option"
  exit
fi


INPUT_DIR=$DIR

echo "SKIP_XLS= $SKIP_XLS"

if [ "$INPUT_FILE_LIST" != "" ]; then
  if [ -e $INPUT_FILE_LIST ]; then
    echo "got input_file_list= $INPUT_FILE_LIST"
  fi
else
if [ ! -e $DIR/60SECS.LOG ]; then
   DIR_ORIG=$DIR
   RESP=`find $DIR -name 60secs.log | wc -l | awk '{$1=$1;print}'`
   if [ $RESP -eq 0 ]; then
     echo "didn't find 60secs.log file under dir $DIR. Bye"
     CKF="metric_out"
     RESP=`find $DIR -name $CKF | wc -l | awk '{$1=$1;print}'`
     if [ "$RESP" != "0" ]; then
       echo "found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
       #RESP=`find $DIR -name $CKF -print0 | sort -z | xargs -0 cat`
       RESP=`find $DIR -name $CKF -print | sort | xargs `
       echo "found $CKF file in dir $DIR"
       STR=
       for ii in $RESP; do
         NM=$(dirname $ii)
         STR="$STR $NM"
       done
       DIR=$STR
       #DIR=$(dirname $RESP)
       echo "using DIR= $DIR, orig DIR= $DIR_ORIG"
     else
       CKF="sys_*_perf_stat.txt"
       RESP=`find $DIR -name $CKF | wc -l|awk '{$1=$1;print}'`
       if [ "$RESP" != "0" ]; then
         echo "found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
         RESP=`find $DIR -name $CKF`
         echo "found $CKF file in dir $DIR"
         STR=
         j=0
         for ii in $RESP; do
           NM=$(dirname $ii)
           if [ $j -eq 0 ]; then
             TS_INIT=`awk '
  function dt_to_epoch(offset) {
     if (date_str == "") {
        return 0.0;
     }
     months="  JanFebMarAprMayJunJulAugSepOctNovDec";
     n=split(date_str, darr, /[ :]+/);
     mnth_num = sprintf("%d", index(months, darr[1])/3);
     dt_str = darr[6] " " mnth_num " " darr[2] " " darr[3] " " darr[4] " " darr[5];
     epoch = mktime(dt_str);
     return epoch + offset;
  }
  /^# started on / {
    # started on Fri Jun 12 14:36:31 UTC 2020 1591972591.618156223
    # started on Fri Jun 12 14:36:31 2020
    pos = index($0, " on ")+8;
    date_str = substr($0, pos);
    if ($8 == "UTC") {
       if (NF == 10) {
          ts_initial = $10+0;
          printf("%s\n", $10);
          exit;
       }
       date_str = $5 " " $6 " " $7 " " $9;
    }
    tst_epoch = dt_to_epoch(0.0);
    printf("%s\n", tst_epoch);
       exit
    }' $ii`
             #TS_INIT=
             echo "first sys_*_perf_stat.txt TS_INIT= $TS_INIT" > /dev/stderr
             echo "first sys_*_perf_stat.txt TS_INIT= $TS_INIT"
           fi
           STR="$STR $NM"
           j=$((j+1))
           if [ "$NUM_DIR" != "" -a $NUM_DIR -gt 0 -a $j -ge $NUM_DIR ]; then
              echo "limit number of dirs due to -N $NUM_DIR option"
              break
           fi
         done
         DIR=$STR
         #echo "using DIR= $DIR, orig DIR= $DIR_ORIG"
       else
         echo "didn't find 60secs.log nor metric_out nor sys_*_perf_stat.xt file under dir $DIR. Bye"
         exit
       fi
     fi
   else
     echo "found $RESP 60secs.log file(s) under dir $DIR. Using the dir of first one if more than one."
     RESP=`find $DIR -name 60secs.log | head -1`
     echo "found 60secs.log file in dir $RESP"
     DIR=$(dirname $RESP)
     echo "using DIR= $DIR, orig DIR= $DIR_ORIG"
   fi
fi
fi



LST=$DIR

CDIR=`pwd`
ALST=$CDIR/tmp1.jnk
#echo "ALST= $ALST"
if [ -e $ALST ]; then
  rm $ALST
fi
OXLS=tmp.xlsx
if [ "$AXLSX_FILE" != "" ]; then
  OXLS=${AXLSX_FILE}_all.xlsx
fi

shopt -s nullglob
echo -e "-o\t$OXLS" >> $ALST
FCTRS=
SVGS=
SUM_FILE=sum.tsv

#echo "LST= $LST" > /dev/stderr

if [ "$INPUT_FILE_LIST" == "" ]; then
  NUM_DIRS=0
  for i in $LST; do
    NUM_DIRS=$((NUM_DIRS+1))
  done
fi

TS_BEG=`date +%s`
if [ "$INPUT_FILE_LIST" == "" ]; then
oIFS=$IFS
DIR_NUM_MX=0
for i in $LST; do
 DIR_NUM_MX=$(($DIR_NUM_MX+1))
done
DIR_NUM=0
for i in $LST; do
 pushd $i
 IFS="/" read -ra PARTS <<< "$(pwd)"
 XLS=
 for k in "${PARTS[@]}"; do
    if [ "$k" != "60secs" ]; then
       XLS=$k
    fi
 done
 echo "XLS= $XLS" > /dev/stderr
 RPS=`echo $i | sed 's/rps_v/rpsv/' | sed 's/rps.*_.*/rps/' | sed 's/.*_//' | sed 's/\/.*//'`
 RPS="${RPS}"
 if [ "$RPS" == "" ]; then
   RPS="1rps"
 fi
 if [ "$SUM_FILE" != "" ]; then
   if [ -e $SUM_FILE ]; then
     rm $SUM_FILE
   fi
 fi
 FCTR=`echo $RPS | sed 's/rps//'`
 FCTR=`awk -v fctr="$FCTR" 'BEGIN{fctr += 0.0; mby=1.0; if (fctr >= 100.0) {mby=0.001;} if (fctr == 0.0) {fctr=1.0;mby=1.0;} printf("%.3f\n", mby*fctr); exit;}'`
 echo "rps= $RPS, fctr= $FCTR"
 if [ "$XLSX_FILE" != "" ]; then
   XLS=$XLSX_FILE
 fi
 if [ "$AXLSX_FILE" != "" ]; then
   XLS=$CDIR/$AXLSX_FILE
 fi
 OPT_PH=
 if [ "$PHASE_FILE" != "" ]; then
    OPT_PH=" -P $PHASE_FILE "
 fi
 OPT_BEG_TM=
 if [ "$TS_INIT" != "" ]; then
    OPT_BEG_TM=" -b $TS_INIT "
 fi
 OPT_END_TM=
 if [ "$END_TM" != "" ]; then
    OPT_END_TM=" -e $END_TM "
 fi
 OPT_SKIP=
 if [ "$SKIP_XLS" == "1" ]; then
   OPT_SKIP=" -S "
 fi
 OPT_M=
 if [ "$MAX_VAL" != "" ]; then
   OPT_M=" -m $MAX_VAL "
 fi
 OPT_CLIP=
 if [ "$CLIP" != "" ]; then
   OPT_CLIP=" -c $CLIP "
 fi
 OPT_DEBUG=
 if [ "$DEBUG_OPT" != "" ]; then
   OPT_DEBUG=" -D $DEBUG_OPT "
 fi
 OPT_OPT=
 if [ "$OPTIONS" != "" ]; then
   OPT_OPT=",$OPTIONS "
 fi
 OPT_A=
 if [ "$AVERAGE" != "0" ]; then
   if [ $NUM_DIRS -gt 1 ]; then
     OPT_A=" -A "
   fi
 fi
 OPT_G=
 if [ "$G_SUM" != "" ]; then
   for g in "${G_SUM[@]}"; do
      OPT_G+=" -g $g "
      #echo "build g opt= $OPT_G"
   done
   echo "new g opt= $OPT_G"
 fi
 if [ $VERBOSE -gt 0 ]; then
 echo "$SCR_DIR/sys_2_tsv.sh $OPT_A $OPT_G -p \"$RPS\" $OPT_DEBUG $OPT_SKIP $OPT_M -d . $OPT_CLIP $OPT_BEG_TM $OPT_END_TM -i \"*.png\" -s $SUM_FILE -x $XLS.xlsx -o chart_new,dont_sum_sockets$OPT_OPT $OPT_PH -t $DIR &> tmp.jnk"
 fi
       $SCR_DIR/sys_2_tsv.sh $OPT_A $OPT_G -p "$RPS" $OPT_DEBUG $OPT_SKIP $OPT_M -d . $OPT_CLIP $OPT_BEG_TM $OPT_END_TM -i "*.png" -s $SUM_FILE -x $XLS.xlsx -o chart_new,dont_sum_sockets$OPT_OPT $OPT_PH -t $DIR &> tmp.jnk
 SM_FL=
 if [ -e $SUM_FILE ]; then
   SM_FL=$i/$SUM_FILE
 fi
 echo -e "-p\t\"$RPS\"" >> $ALST
 echo -e "-s\t2,2" >> $ALST
 if [ "$AVERAGE" == "1" ]; then
    echo -e "-A" >> $ALST
 fi
 if [ "$CLIP" != "" ]; then
    echo -e "-c $CLIP" >> $ALST
 fi
 echo -e "-i\t\"$i/*.png\"" >> $ALST
 #echo -e "-x\t$i.xlsx" >> $ALST
 #echo -e "-o\tchart_new,dont_sum_sockets" >> $ALST
 popd
 FLS=`ls -1 $SM_FL $i/*txt.tsv`
 echo -e "${FLS}" >> $ALST
 TS_CUR=`date +%s`
 TS_DFF=$(($TS_CUR-$TS_BEG))
 echo -e "FLS: dir_num= ${DIR_NUM} of ${DIR_NUM_MX}, elap_tm= $TS_DFF secs, ${FLS}" > /dev/stderr
 DIR_NUM=$(($DIR_NUM+1))
 MYA=($i/*log.tsv)
 if [ "${#MYA}" != "0" ]; then
   FLS=`ls -1 $i/*log.tsv`
   echo -e "${FLS}" >> $ALST
 fi
 # itp files
 if [ -e $i/metric_out.tsv ]; then
   FLS=`ls -1 $i/metric_out.tsv`
   echo -e "${FLS}" >> $ALST
 fi
 MYSVG=($i/*.svg)
 if [ "${#MYSVG}" != "0" ]; then
   SVG=`ls -1 $i/*.svg`
 fi
 MYA=($i/*current.tsv)
 if [ "${#MYA}" != "0" ]; then
   FLS=`ls -1 $i/*current.tsv`
   echo -e "${FLS}" >> $ALST
 fi
 echo -e "" >> $ALST
 if [ "$FCTRS" != "" ]; then
   FCTRS="$FCTRS,"
 fi
 if [ "$SVG" != "" ]; then
   SVGS="${SVGS} -f ${SVG}"
 fi
 FCTRS="$FCTRS$FCTR"
done
fi

SUM_ALL=sum_all.tsv
if [ "$INPUT_FILE_LIST" != "" ]; then
  echo "$SUM_ALL" >> $ALST
  cat $INPUT_FILE_LIST >> $ALST
  NUM_DIRS=2
fi

if [ "$SVGS" != "" ]; then
  $SCR_DIR/svg_to_html.sh $SVGS -r $FCTRS > tmp.html
fi
  
if [ $NUM_DIRS -gt 1 ]; then
  if [ -e $SUM_ALL ]; then
    rm $SUM_ALL
  fi
  echo "ALST= $ALST" > /dev/stderr
  echo "awk -v input_file=\"$ALST\" -v sum_all=\"$SUM_ALL\" -v sum_file=\"$SUM_FILE\""
  awk -v input_file="$ALST" -v sum_all="$SUM_ALL" -v sum_file="$SUM_FILE" '
    BEGIN{sum_files=0;fls=0; fld_m=3;fld_v=4;}
    { if (index($0, sum_file) > 0) {
        flnm = $0;
        fls++;
        #printf("got sumfile= %s\n", flnm) > "/dev/stderr";
        ln = -1;
        while ((getline line < flnm) > 0) {
           ln++;
           if (ln <= 2) {
              if (ln == 2) {
                nh = split(line, hdrs, /\t/);
                if (hdrs[3] == "Value" && hdrs[4] == "Metric") {
                   fld_m=4; 
                   fld_v=3; 
                }
              }
              continue;
           }
           n = split(line, arr, /\t/);
           mtrc = arr[fld_m];
           if (!(mtrc in mtrc_list)) {
              mtrc_list[mtrc] = ++mtrc_mx;
              mtrc_lkup[mtrc_mx] = mtrc;
           }
           mtrc_i = mtrc_list[mtrc];
           if (mtrc == "goto_sheet") {
              gs=arr[fld_v]; 
              if (!(gs in gs_list)) {
                gs_list[gs] = ++gs_list_mx;
                gs_lkup[gs_list_mx] = gs;
              } else {
                for (i=0; i <= 100; i++) {
                   tnm = gs "_" i;
                   if (!(tnm in gs_list)) {
                     gs_list[tnm] = ++gs_list_mx;
                     gs_lkup[gs_list_mx] = tnm;
                     arr[fld_v] = tnm;
                     break;
                   }
                }
              }
           }
           if (mtrc == "data_sheet") {
              ds=arr[fld_v]; 
              if (!(ds in ds_list)) {
                ds_list[ds] = ++ds_list_mx;
                ds_lkup[ds_list_mx] = ds;
              } else {
                for (i=0; i <= 100; i++) {
                   tnm = ds "_" i;
                   if (!(tnm in ds_list)) {
                     ds_list[tnm] = ++ds_list_mx;
                     ds_lkup[ds_list_mx] = tnm;
                     arr[fld_v] = tnm;
                     break;
                   }
                }
              }
           }
           mtrc_arr[fls,mtrc_i] = arr[fld_v];
        }
        close(flnm)
      }
    }
    END {
      ofile = sum_all;
      #printf("ofile= %s\n", ofile) > "/dev/stderr";
      printf("title\tsum_all\tsheet\tsum_all\ttype\tcopy\n")  > ofile;
      printf("hdrs\t2\t0\t-1\t%d\t-1\n", fls+3) > ofile;
      printf("Resource\tTool\tMetric") > ofile;
      for (j=1; j <= fls; j++) {
         printf("\t%d", j-1) > ofile;
      }
      printf("\n") > ofile;
      for (i=1; i <= mtrc_mx; i++) {
        mtrc = mtrc_lkup[i];
        if (mtrc == "") { continue; }
        if (mtrc == "data_sheet") {
          printf("\t%s\t%s", mtrc_arr[1,i], mtrc) > ofile;
        } else {
          printf("\titp\t%s", mtrc) > ofile;
        }
        for (j=1; j <= fls; j++) {
          val = mtrc_arr[j,i];
          printf("\t%s", val) > ofile;
        }
        printf("\n") > ofile;
      }
      close(ofile);
      flnm = input_file;
      printf("======---- input_file= %s\n", input_file) > "/dev/stderr";
        ln = 0;
        last_non_blank = -1;
        first_blank = -1;
        while ((getline line < flnm) > 0) {
           ln++;
           if (first_blank == -1 && length(line) == 0) {
             first_blank = ln;
           }
           if (length(line) > 0) {
             last_non_blank = ln;
           }
           sv[ln] = line;
        }
        close(flnm)
        if (ln == 0) { exit; }
        printf("%s\n", sv[1]) > flnm;
        for(i=2; i <= ln; i++) {
          if (first_blank == i) {
             printf("%s\n", sum_all) >> flnm;
          }
          printf("%s\n", sv[i]) >> flnm;
          #if (last_non_blank == i) {
          #   printf("%s\n", sum_all) >> flnm;
          #}
        }
        close(flnm)
      }
  ' $ALST

  echo "=========== pwd =========="
  pwd
  if [ "$INPUT_FILE_LIST" != "" ]; then
    RESP=0
  else
    echo "find $INPUT_DIR -name muttley?.json | wc -l | awk '{$1=$1;print}'"
    RESP=`find $INPUT_DIR -name "muttley?.json" | wc -l | awk '{$1=$1;print}'`
    echo "find muttley RESP= $RESP"
  fi
  if [ "$RESP" != "0" ]; then
    RESP=`find $INPUT_DIR -name run.log | head -1 | wc -l | awk '{$1=$1;print}'`
    echo "find run.log RESP= $RESP"
    if [ "$RESP" != "0" ]; then
      RUN_LOG=`find $INPUT_DIR -name run.log | head -1`
      echo "run_log file= $RUN_LOG"
      BEG_TM=`awk '/ start /{printf("%s\n", $2);}' $RUN_LOG`
      END_TM=`awk '/ end /{printf("%s\n", $2);}' $RUN_LOG`
      echo "beg_tm= $BEG_TM end_tm= $END_TM" > /dev/stderr
      
      tst_files=`find $INPUT_DIR -name "muttley?.json"`
      echo "muttley files: $tst_files" > /dev/stderr
      echo -e "-p\t\"$RPS\"" >> $ALST
      echo -e "-s\t2,2" >> $ALST
      for f in $tst_files; do
        echo "try muttley file= $f" > /dev/stderr
        if [ -e $f ]; then
           echo "try muttley log $f" 
           $SCR_DIR/resp_2_tsv.sh -b $BEG_TM -e $END_TM -f $f -s $SUM_FILE
           if [ -e $f.tsv ]; then
           echo -e "$f.tsv" >> $ALST
           #SHEETS="$SHEETS $f.tsv"
           #echo "got latency log $f.tsv" > /dev/stderr
           fi
        fi
      done
      echo -e "" >> $ALST
    fi
  fi
  OPT_A=
  if [ "$AVERAGE" == "1" ]; then
    OPT_A=" -A "
  fi
  OPT_OPTIONS=
  if [ "$OPTIONS" != "" ]; then
    OPT_OPTIONS=" -O $OPTIONS "
  fi
  OPT_M=
  if [ "$MAX_VAL" != "" ]; then
    OPT_M=" -m $MAX_VAL "
  fi
      
  TS_DFF=$(($TS_CUR-$TS_BEG))
  echo "elap_tm= $TS_DFF"
  echo "about to do tsv_2_xls.py" > /dev/stderr
  echo "python $SCR_DIR/tsv_2_xlsx.py $OPT_A $OPT_OPTIONS $OPT_M -f $ALST > tmp2.jnk"
        python $SCR_DIR/tsv_2_xlsx.py $OPT_A $OPT_OPTIONS $OPT_M -f $ALST $SHEETS > tmp2.jnk
  TS_CUR=`date +%s`
  TS_DFF=$(($TS_CUR-$TS_BEG))
  echo "elap_tm= $TS_DFF"
fi
