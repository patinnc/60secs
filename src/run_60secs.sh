#!/bin/bash

PROJ_DIR=/root/output
SCR_DIR=`dirname $(readlink -e $0)`
# don't need cfg_dir but it might get passed
CFG_DIR=
echo "args= $*"
DURA=1m

while getopts "hc:d:p:" opt; do
  case ${opt} in
    c )
      CFG_DIR=$OPTARG
      ;;
    d )
      DURA=$OPTARG
      ;;
    p )
      PROJ_DIR=$OPTARG
      ;;
    h )
      echo "$0 run compute and disk benchmarks using config files in cfg_dir and put results in results dir"
      echo "Usage: $0 [-h] [ -p project_dir]"
      echo "   -p project_dir"
      echo "     by default the host results dir name $PROJ_DIR"
      echo "     If you specify a project dir the benchmark results are looked for"
      echo "     under /project_dir/"
      echo "   -d duration of run in secs. Append 'm' for minutes"
      exit
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

mkdir -p $PROJ_DIR
PROJ_DIR=`realpath -e $PROJ_DIR`

timestamp=$(date '+%y-%m-%d_%H%M%S')
result="$PROJ_DIR/${timestamp}_60secs"
mkdir -p $result

pushd $result

CNTNR=`docker ps | grep gmat | awk '{print $1;exit}'`

$SCR_DIR/60secs.sh -t all -x top,interrupts -b -w -c -d $DURA -i 1 -p $SCR_DIR/perf -C $CNTNR

popd

