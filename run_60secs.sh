#!/bin/bash

PROJ_DIR=/root/output
SCR_DIR=`dirname $(readlink -e $0)`
# don't need cfg_dir but it might get passed
CFG_DIR=
echo "args= $*"
DURA=1m
PREFIX_DIR=0
TASK_IN=
ADD_IN=
INTRVL=1
EXCL=
EVT_IN=
DO_CONTAINER=

while getopts "hPa:c:C:d:E:i:p:t:W:x:" opt; do
  case ${opt} in
    a )
      ADD_IN=$OPTARG
      ;;
    c )
      CFG_DIR=$OPTARG
      ;;
    C )
      DO_CONTAINER=$OPTARG
      ;;
    d )
      DURA=$OPTARG
      ;;
    E )
      EVT_IN=$OPTARG
      ;;
    i )
      INTRVL=$OPTARG
      ;;
    t )
      TASK_IN=$OPTARG
      ;;
    P )
      PREFIX_DIR=1
      ;;
    p )
      PROJ_DIR=$OPTARG
      ;;
    x )
      EXCL=$OPTARG
      ;;
    W )
      WATCH_IN="$OPTARG"
      echo "in $0 getopts: WATCH_IN= $WATCH_IN"
      ;;
    h )
      echo "$0 run compute and disk benchmarks using config files in cfg_dir and put results in results dir"
      echo "Usage: $0 [-h] [ -p project_dir]"
      echo "   -p project_dir"
      echo "     by default the host results dir name $PROJ_DIR"
      echo "     If you specify a project dir the benchmark results are looked for"
      echo "     under /project_dir/"
      echo "   -C Container_string  if you are doing a container flamegraph, add a string for 'docker ps | grep string' to get the container id."
      echo "   -c config_dir"
      echo "   -i interval for collection in seconds."
      echo "   -d duration of run in secs. Append 'm' for minutes"
      echo "   -P prefix output dir with timestamp YY-MM-DD_HHMMSS_"
      echo "   -a add_in_tasks  some tasks like flamegraphs are not in the default list"
      echo "   -t tasks_to_run  comma separated list of tasks to run. Overrides the default list."
      echo "   -x tasks_not_to_run comma separated list of tasks (from default task list) to not run"
      echo "   -E event event for flamegraphs (lock or itimer). default is itimer."
      echo "   -W watch_cmd"
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

mkdir -p $PROJ_DIR
PROJ_DIR=`realpath -e $PROJ_DIR`

timestamp=$(date '+%y-%m-%d_%H%M%S')
extra_dir=60secs
if [ "$PREFIX_DIR" == "1" ]; then
  extra_dir=${timestamp}_${extra_dir}
fi
result="$PROJ_DIR/${extra_dir}"
mkdir -p $result

echo "using output dir= $result"

pushd $result

hostname > hostname.txt

if [ "$DO_CONTAINER" != "" ]; then
  CNTNR=`docker ps | grep $DO_CONTAINER | awk '{print $1;exit}'`
fi

TASK=all
if [ "$TASK_IN" != "" ]; then
  TASK=$TASK_IN
fi

ADD=
if [ "$ADD_IN" != "" ]; then
  ADD=" -a $ADD_IN "
fi

OPT_EX=" -x do_top,interrupts "
if [ "$EXCL" != "" ]; then
  OPT_EX=" -x $EXCL "
fi
echo "in $0: WATCH_IN= $WATCH_IN"
if [ "$WATCH_IN" == "" ]; then
  WATCH_IN="null"
fi

OPT_EV=
if [ "$EVT_IN" != "" ]; then
  OPT_EV=" -E $EVT_IN "
fi

if [ "$CNTNR" != "" ]; then
echo $SCR_DIR/60secs.sh -t $TASK $OPT_EX -b -w -c -d $DURA -i $INTRVL -p $SCR_DIR/perf -C $CNTNR $OPT_EV -W "$WATCH_IN" $ADD
     $SCR_DIR/60secs.sh -t $TASK $OPT_EX -b -w -c -d $DURA -i $INTRVL -p $SCR_DIR/perf -C $CNTNR $OPT_EV -W "$WATCH_IN" $ADD
else
echo $SCR_DIR/60secs.sh -t $TASK $OPT_EX -b -w -d $DURA -i $INTRVL -p $SCR_DIR/perf $OPT_EV -W "$WATCH_IN" $ADD
     $SCR_DIR/60secs.sh -t $TASK $OPT_EX -b -w -d $DURA -i $INTRVL -p $SCR_DIR/perf $OPT_EV -W "$WATCH_IN" $ADD
fi

popd

exit

