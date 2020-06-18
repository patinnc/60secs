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

while getopts "hvASd:e:m:N:P:x:X:" opt; do
  case ${opt} in
    A )
      AVERAGE=1
      ;;
    d )
      DIR=$OPTARG
      ;;
    e )
      END_TM=$OPTARG
      ;;
    m )
      MAX_VAL=$OPTARG
      ;;
    N )
      NUM_DIR=$OPTARG
      ;;
    S )
      SKIP_XLS=1
      ;;
    P )
      PHASE_FILE=$OPTARG
      ;;
    x )
      XLSX_FILE=$OPTARG
      ;;
    X )
      AXLSX_FILE=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 split data files into columns"
      echo "Usage: $0 [-h] -d sys_data_dir [-v] [ -p prefix ]"
      echo "   -A   flag indicating you want to average the same file from multiple dirs into 1 sheet."
      echo "          The default is to create 1 sheet per file per directory"
      echo "   -d dir containing sys_XX_* files created by 60secs.sh"
      echo "   -m max_val    any value in chart > this value will be replaced by 0.0"
      echo "   -N number_of_dirs  if you have more than 1 directories then you can limit the num of dirs with this option. Default process all"
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

INPUT_DIR=$DIR


if [ ! -e $DIR/60secs.log ]; then
   DIR_ORIG=$DIR
   RESP=`find $DIR -name 60secs.log | wc -l | awk '{$1=$1;print}'`
   if [ $RESP -eq 0 ]; then
     echo "didn't find 60secs.log file under dir $DIR. Bye"
     CKF="metric_out"
     RESP=`find $DIR -name $CKF | wc -l | awk '{$1=$1;print}'`
     if [ "$RESP" != "0" ]; then
       echo "found $RESP $CKF file(s) under dir $DIR. Using the dir of first one if more than one."
       RESP=`find $DIR -name $CKF`
       echo "found $CKF file in dir $RESP"
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
         echo "found $CKF file in dir $RESP" | head -10
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
         echo "using DIR= $DIR, orig DIR= $DIR_ORIG"
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



LST=$DIR

CDIR=`pwd`
ALST=$CDIR/tmp1.jnk
echo "ALST= $ALST"
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

echo "LST= $LST" > /dev/stderr

NUM_DIRS=0
for i in $LST; do
  NUM_DIRS=$((NUM_DIRS+1))
done
oIFS=$IFS
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
 OPT_A=
 if [ "$AVERAGE" != "" ]; then
   if [ $NUM_DIRS -gt 1 ]; then
     OPT_A=" -A "
   fi
 fi
 if [ $VERBOSE -gt 0 ]; then
 echo "$SCR_DIR/sys_2_tsv.sh $OPT_A -p \"$RPS\" $OPT_SKIP $OPT_M -d . $OPT_BEG_TM $OPT_END_TM -i \"*.png\" -s $SUM_FILE -x $XLS.xlsx -o chart_new,dont_sum_sockets $OPT_PH -t $DIR &> tmp.jnk"
 fi
       $SCR_DIR/sys_2_tsv.sh $OPT_A -p "$RPS" $OPT_SKIP $OPT_M -d . $OPT_BEG_TM $OPT_END_TM -i "*.png" -s $SUM_FILE -x $XLS.xlsx -o chart_new,dont_sum_sockets $OPT_PH -t $DIR &> tmp.jnk
 SM_FL=
 if [ -e $SUM_FILE ]; then
   SM_FL=$i/$SUM_FILE
 fi
 echo -e "-p\t\"$RPS\"" >> $ALST
 echo -e "-s\t2,2" >> $ALST
 if [ "$AVERAGE" == "1" ]; then
    echo -e "-A" >> $ALST
 fi
 echo -e "-i\t\"$i/*.png\"" >> $ALST
 #echo -e "-x\t$i.xlsx" >> $ALST
 #echo -e "-o\tchart_new,dont_sum_sockets" >> $ALST
 popd
 FLS=`ls -1 $SM_FL $i/*txt.tsv`
 echo -e "${FLS}" >> $ALST
 echo -e "FLS: ${FLS}" > /dev/stderr
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
echo "got to end of $0" > /dev/stderr
if [ "$SVGS" != "" ]; then
  $SCR_DIR/svg_to_html.sh $SVGS -r $FCTRS > tmp.html
fi
  
if [ $NUM_DIRS -gt 1 ]; then
  SUM_ALL=sum_all.tsv
  if [ -e $SUM_ALL ]; then
    rm $SUM_ALL
  fi
  awk -v input_file="$ALST" -v sum_all="$SUM_ALL" -v sum_file="$SUM_FILE" '
    BEGIN{sum_files=0;fls=0;}
    { if (index($0, sum_file) > 0) {
        flnm = $0;
        fls++;
        printf("got sumfile= %s\n", flnm) > "/dev/stderr";
        ln = -1;
        while ((getline line < flnm) > 0) {
           ln++;
           if (ln <= 2) {
              continue;
           }
           n = split(line, arr, /\t/);
           mtrc = arr[3];
           if (!(mtrc in mtrc_list)) {
              mtrc_list[mtrc] = ++mtrc_mx;
              mtrc_lkup[mtrc_mx] = mtrc;
           }
           mtrc_i = mtrc_list[mtrc];
           mtrc_arr[fls,mtrc_i] = arr[4];
        }
        close(flnm)
      }
    }
    END {
      ofile = sum_all;
      printf("ofile= %s\n", ofile) > "/dev/stderr";
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
        printf("\titp\t%s", mtrc) > ofile;
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
  echo "find $INPUT_DIR -name muttley?.json | wc -l | awk '{$1=$1;print}'"
  RESP=`find $INPUT_DIR -name "muttley?.json" | wc -l | awk '{$1=$1;print}'`
  echo "find muttley RESP= $RESP"
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
  OPT_M=
  if [ "$MAX_VAL" != "" ]; then
    OPT_M=" -m $MAX_VAL "
  fi
      
  echo "about to do tsv_2_xls.py" > /dev/stderr
  echo "python $SCR_DIR/tsv_2_xlsx.py $OPT_A $OPT_M -f $ALST > tmp2.jnk"
        python $SCR_DIR/tsv_2_xlsx.py $OPT_A $OPT_M -f $ALST $SHEETS > tmp2.jnk
fi

