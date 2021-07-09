#!/usr/bin/env bash

SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
VERBOSE=0
CPU2017_LOG=
OUTFILE=
SUMFILE=
OPTIONS=

while getopts "hvi:o:O:s:" opt; do
  case ${opt} in
    i )
      CPU2017_LOG=$OPTARG
      ;;
    o )
      OUTFILE=$OPTARG
      ;;
    O )
      OPTIONS=$OPTARG
      ;;
    s )
      SUMFILE=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "usage: $0 generate phase file from CPU2017.00*.log file"
      echo "   -i input CPU2017.00*.log file"
      echo "   -o phase_file.txt. Default is just print to stdout."
      echo "   -O options_string."
      echo "   -s sum_file        print summary sheet stats sh at the end"
      echo "   -v verbose mode. display each file after creating it."
      echo "   -z use dcmi power reading cmd"
      exit
      ;;
    : )
      echo "$0.$LINENO Invalid option: $OPTARG requires an argument" 1>&2
      exit 1
      ;;
    \? )
      echo "$0.$LINENO Invalid option: $OPTARG" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ "$CPU2017_LOG" == "" ]; then
  echo "$0.$LINENO missing -i cpu2017.001.log file option"
  exit 1
fi
if [ ! -e "$CPU2017_LOG" ]; then
  echo "$0.$LINENO didn't find file from -i $CPU2017_LOG file"
  exit 1
fi

#echo "$0.$LINENO hi" > /dev/stderr
export AWKPATH=$SCR_DIR

awk -v out_file="$OUTFILE" -v sum_file="$SUMFILE" -v options="$OPTIONS" -f $SCR_DIR/cpu2017_2_phasefile.awk $CPU2017_LOG
exit $!


