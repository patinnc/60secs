#!/bin/bash

#SCR_DIR=`dirname $(readlink -e $0)`
#SCR_DIR=`dirname $0`
SCR_DIR=`dirname "$(readlink -f "$0")"`
SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo "SCR_DIR= $SCR_DIR" > /dev/stderr

DIR=
PHASE_FILE=
XLSX_FILE=

while getopts "hvd:P:x:" opt; do
  case ${opt} in
    d )
      DIR=$OPTARG
      ;;
    P )
      PHASE_FILE=$OPTARG
      ;;
    x )
      XLSX_FILE=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 split data files into columns"
      echo "Usage: $0 [-h] -d sys_data_dir [-v] [ -p prefix ]"
      echo "   -d dir containing sys_XX_* files created by 60secs.sh"
      echo "   -P phase_file"
      echo "   -x xlsx_filename  This is passed to tsv_2_xlsx.py as the name of the xlsx. (you need to add the .xlsx)"
      echo "      The default is chart_line.xlsx"
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


LST=$DIR

CDIR=`pwd`
ALST=$CDIR/tmp1.jnk
echo "ALST= $ALST"
if [ -e $ALST ]; then
  rm $ALST
fi
OXLS=tmp.xlsx

shopt -s nullglob
echo -e "-o\t$OXLS" >> $ALST
j=0
FCTRS=
SVGS=
SUM_FILE=sum.tsv

echo "LST= $LST" > /dev/stderr

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
 OPT_PH=
 if [ "$PHASE_FILE" != "" ]; then
    OPT_PH=" -P $PHASE_FILE "
 fi
 $SCR_DIR/sys_2_tsv.sh -p "$RPS" -d . -i "*.png" -s $SUM_FILE -x $XLS.xlsx -o chart_new,dont_sum_sockets $OPT_PH $> tmp.jnk
 SM_FL=
 if [ -e $SUM_FILE ]; then
   SM_FL=$i/$SUM_FILE
 fi
 echo -e "-p\t\"$RPS\"" >> $ALST
 echo -e "-s\t2,2" >> $ALST
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
 j=$((j+1))
done
echo "got to end of $0" > /dev/stderr
if [ "$SVGS" != "" ]; then
  $SCR_DIR/svg_to_html.sh $SVGS -r $FCTRS > tmp.html
fi
if [ $j -gt 1 ]; then
  echo "about to do tsv_2_xls.py" > /dev/stderr
  python $SCR_DIR/tsv_2_xlsx.py -f $ALST > tmp2.jnk
fi

