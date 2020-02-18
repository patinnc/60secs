#!/bin/bash

# arg1 is container
# arg2 is start or stop
if [ "$1" == "" ]; then
  echo "1st arg must be container id for java to be profiled"
  docker ps
  exit
fi

if [ "$2" != "start" -a "$2" != "stop" ]; then
  echo "2nd arg must be either 'start' or 'stop'"
  exit
fi

SCR_DIR=`dirname "$(readlink -f "$0")"`
ACT=$2

CNTR=$1
RESP=`docker ps | awk -v cntr="$CNTR" 'BEGIN{rc=0;}{if ($1 == cntr) {rc=1;}} END{printf("%d\n", rc);}'`
echo "got docker cntr= $RESP"
if [ "$RESP" == "1" ]; then
  echo "got match on docker cntr= $CNTR"
else
  echo "missed match on docker cntr= $CNTR"
fi

RESP=$(docker exec -t -i  $CNTR /bin/bash -c "ps -ef |grep java |grep -v grep |grep gmatch")
echo "java str= $RESP"
JPID=`echo $RESP | awk '{print $2}'`
echo "java str= $JPID"

if [ "$ACT" == "start" ]; then
  docker cp ${SCR_DIR}/java_profiling.tar.gz $CNTR:/tmp
  docker exec -t -i  $CNTR /bin/bash -c "cd /tmp && tar xzvf java_profiling.tar.gz"
  #docker exec -t -i  $CNTR /bin/bash -c "cd /tmp/profile/ && ./profiler.sh collect -e itimer -d 20 -f /tmp/t.dat -o collapsed $JPID"
  echo docker exec -t -i  $CNTR /bin/bash -c "cd /tmp/profile/ && ./profiler.sh start -i 10ms -e itimer $JPID"
       docker exec -t -i  $CNTR /bin/bash -c "cd /tmp/profile/ && ./profiler.sh start -i 10ms -e itimer $JPID"
  echo "profiling started and will continue until you do 'stop' cmd:"
  DRY_RUN=1
fi

echo docker exec -t -i  $CNTR /bin/bash -c "cd /tmp/profile/ && ./profiler.sh stop -f /tmp/java.collapsed -o collapsed $JPID"

if [ "$ACT" == "stop" ]; then
  if [ "$DRY_RUN" != "1" ]; then
     docker exec -t -i  $CNTR /bin/bash -c "cd /tmp/profile/ && ./profiler.sh stop -f /tmp/java.collapsed -o collapsed $JPID"
     docker exec -t -i  $CNTR /bin/bash -c "cd /tmp && ls -ltr"
     docker cp $CNTR:/tmp/java.collapsed .
     ls -l java.collapsed
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

