#!/bin/bash


#/root/perf record -a -k CLOCK_MONOTONIC  -g -e sched:sched_switch -o prf_trace.data sleep 10
#/root/perf record -a -k CLOCK_MONOTONIC  -g -e sched:sched_switch -e '{cpu-clock/freq=997/,cycles,instructions}:S'  -o prf_trace.data sleep 10
/root/perf record -a -k CLOCK_MONOTONIC  -g -e sched:sched_switch -e 'cpu-clock/freq=997/'  -o prf_trace.data sleep 10
echo "finished perf record"
sleep 20
echo "finished sleep 20"
/root/do_curl.sh 2
echo "finished do_curl 2"
/root/perf script -I --ns --header -f -F comm,tid,pid,time,cpu,period,event,ip,sym,dso,symoff,trace,flags,callindent -i prf_trace.data  > prf_trace.txt
echo "finished perf script"
