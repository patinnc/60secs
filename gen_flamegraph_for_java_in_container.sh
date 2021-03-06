#!/bin/bash

# arg1 is container
# arg2 is start or stop
CONTAINER_IN=
EVT_IN=
ACT_IN=

while getopts "ha:C:E:" opt; do
  case ${opt} in
    a )
      ACT_IN=$OPTARG
      ;;
    C )
      CONTAINER_IN=$OPTARG
      ;;
    E )
      EVT_IN=$OPTARG
      ;;
    h )
      echo "$0 gen flamegraph for java in container"
      echo "Usage: $0 [-h] -C container -a start|stop [ -E event]"
      echo "   -a start|stop"
      echo "     start sampling the java process in containerID"
      echo "     stop sampling the java process in containerID"
      echo "   -C containerID_with_java"
      echo "   -E event_name"
      echo "     Tested with itimer and lock"
      echo "     The default is itimer"
      echo "     Although you can in theory use perf events (like cpu-clock) the permissions on the container block perf events"
      echo "     This option is optional."
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


if [ "$CONTAINER_IN" == "" ]; then
  echo "-C arg must be container id for java to be profiled"
  docker ps
  exit
fi

if [ "$ACT_IN" != "start" -a "$ACT_IN" != "stop" ]; then
  echo "-a arg must be either 'start' or 'stop'"
  exit
fi

if [ "$EVT_IN" != "" -a "$EVT_IN" != "itimer" -a "$EVT_IN" != "lock" ]; then
  echo "event arg must be -e itimer or -e lock. Got -e $EVT_IN. Bye."
  exit
fi
if [ "$EVT_IN" == "" ]; then
  EVT_IN="itimer"
fi

SCR_DIR=`dirname "$(readlink -f "$0")"`
ACT=$ACT_IN
CNTR=$CONTAINER_IN

RESP=`docker ps | awk -v cntr="$CNTR" 'BEGIN{rc=0;}{if ($1 == cntr) {rc=1;}} END{printf("%d\n", rc);}'`
echo "got docker cntr= $RESP"
if [ "$RESP" == "1" ]; then
  echo "got match on docker cntr= $CNTR"
else
  echo "missed match on docker cntr= $CNTR"
fi

RESP=$(docker exec -t  $CNTR /bin/bash -c "ps -ef |grep java |grep -v grep |grep gmatch")
echo "java str= $RESP"
JPID=`echo $RESP | awk '{print $2}'`
echo "java str= $JPID"

if [ "$ACT" == "start" ]; then
  EVT=$EVT_IN
  docker cp ${SCR_DIR}/java_profiling.tar.gz $CNTR:/tmp
  docker exec -t $CNTR /bin/bash -c "cd /tmp && tar xzvf java_profiling.tar.gz"
  #docker exec -t $CNTR /bin/bash -c "cd /tmp/profile/ && ./profiler.sh collect -e $EVT -d 20 -f /tmp/t.dat -o collapsed $JPID"
  echo docker exec -t $CNTR /bin/bash -c "cd /tmp/profile/ && ./profiler.sh start -i 10ms -e $EVT $JPID"
       docker exec -t $CNTR /bin/bash -c "cd /tmp/profile/ && ./profiler.sh start -i 10ms -e $EVT $JPID"
  echo "profiling started and will continue until you do 'stop' cmd:"
  DRY_RUN=1
fi

echo docker exec -t $CNTR /bin/bash -c "cd /tmp/profile/ && ./profiler.sh stop -f /tmp/java.collapsed -o collapsed $JPID"

if [ "$ACT" == "stop" ]; then
  if [ "$DRY_RUN" != "1" ]; then
     docker exec -t $CNTR /bin/bash -c "cd /tmp/profile/ && ./profiler.sh stop -f /tmp/java.coll_traces -o collapsed,traces $JPID"
     docker exec -t $CNTR /bin/bash -c "cd /tmp && ls -ltr"
     docker cp $CNTR:/tmp/java.coll_traces .
     ls -l java.coll_traces
  fi
fi
exit

Usage: ./profile/profiler.sh [action] [options] <pid>
Actions:
  start             start profiling and return immediately
  stop              stop profiling
  status            print profiling status
  list              list profiling events supported by the target JVM
  collect           collect profile for the specified period of time
                    and then stop (default action)
Options:
  -e event          profiling event: cpu|alloc|lock|cache-misses etc.
  -d duration       run profiling for <duration> seconds
  -f filename       dump output to <filename>
  -i interval       sampling interval in nanoseconds
  -j jstackdepth    maximum Java stack depth
  -b bufsize        frame buffer size
  -t                profile different threads separately
  -s                simple class names instead of FQN
  -a                annotate Java method names
  -o fmt[,fmt...]   output format: summary|traces|flat|collapsed|svg|tree|jfr
  -v, --version     display version string

  --title string    SVG title
  --width px        SVG width
  --height px       SVG frame height
  --minwidth px     skip frames smaller than px
  --reverse         generate stack-reversed FlameGraph / Call tree

  --all-kernel      only include kernel-mode events
  --all-user        only include user-mode events

<pid> is a numeric process ID of the target JVM
      or 'jps' keyword to find running JVM automatically

Example: ./profile/profiler.sh -d 30 -f profile.svg 3456
         ./profile/profiler.sh start -i 999000 jps
         ./profile/profiler.sh stop -o summary,flat jps

