#!/usr/bin/env bash

SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
VERBOSE=0
SERVICE=
DOCKER=
#20211126 23:32:41:88



GOT_QUIT=0
# function called by trap
catch_signal() {
    printf "\rSIGINT caught      "
    GOT_QUIT=1
}
trap 'catch_signal' SIGINT

INTERVAL=10
FREQ_SMPL=99


while getopts "hvd:f:I:p:s:t:" opt; do
  case ${opt} in
    d )
      DOCKER=$OPTARG
      ;;
    f )
      FREQ_SMPL=$OPTARG
      ;;
    I )
      INTERVAL=$OPTARG
      ;;
    p )
      PROJ=$OPTARG
      ;;
    s )
      SERVICE=$OPTARG
      ;;
    t )
      TIME_MX=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "usage: $0 -p proj_output_dir [ -d docker_container | -s service_name ] -t time_to_run_in_secs -i interval_in_secs"
      echo "       $0 monitor docker container or service for throttling "
      echo "   -d docker_container (long or short name) (comma separated list if more than 1)"
      echo "   -f freq_samples      samples per second (per cpu on which the container is running). Default = 99. Higher freq -> more overhead"
      echo "   -I interval_in_secs  sleep interval between get stats"
      echo "   -s service_name (as it appears in the docker ps output (selects all containers for service on host)"
      echo "   -p proj_dir     output dir for stat file"
      echo "   -t time_to_run_in_secs   time in seconds_to_run"
      echo "   -v              verbose mode"
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


if [ "$PROJ" == "" ]; then
  echo "$0.$LINENO -p project_output_dir must be specified"
  exit 1
fi

if [ "$TIME_MX" == "" ]; then
  echo "$0.$LINENO -t time_to_run_in_seconds must be specified"
  exit 1
fi

if [[ "$INTERVAL" == "" ]] || [[ "$INTERVAL" -le "0" ]]; then
  echo "$0.$LINENO -I interval_to_sleep_in_seconds must be specified and be > 0"
  exit 1
fi

if [[ "$DOCKER" == "" ]] && [[ "$SERVICE" == "" ]]; then
  echo "$0.$LINENO must supply -d docker_container or -s service_name"
  exit 1
fi
if [[ "$DOCKER" != "" ]] && [[ "$SERVICE" != "" ]]; then
  echo "$0.$LINENO must supply either -d or -s service_name"
  exit 1
fi
MYPID=$$
echo $MYPID > $SCR_DIR/../monitor_docker_throttling.pid
STOPFILE="$SCR_DIR/../monitor_docker_throttling.stop"
if [ -e "$STOPFILE" ]; then
  rm "$STOPFILE"
fi


docker_short=$(docker ps)
echo "$0.$LINENO $?"
docker_long=$(docker ps --no-trunc)
echo "$0.$LINENO $?"
declare -a dckr_arr
SV_IFS="$IFS"
if [ "$DOCKER" != "" ]; then
#
# given container find the long and short container name
#
  IFS=', ' read -r -a dckr_arr <<< "$DOCKER"
  echo "dckr_arr= ${dckr_arr[@]}"
  IFS="$SV_IFS"
  for ((i=0; i < ${#dckr_arr[@]}; i++)); do
    if [ "${#dckr_arr[$i]}" == "12" ]; then
      #echo "$docker_short"
      #echo "$docker_short" | grep "^${dckr_arr[$i]} "
      RESP=$(echo "$docker_short" | grep "^${dckr_arr[$i]} ")
    else
      #echo $docker_long  | grep "^${dckr_arr[$i]} "
      RESP=$(echo "$docker_long"  | grep "^${dckr_arr[$i]} ")
    fi
    if [ "$RESP" == "" ]; then
      echo "$0.$LINENO didn't find container ${dckr_arr[$i]} in 'docker ps' output"
      exit 1
    fi
  done
else
#
# given service name, find container name for it.
#
  RESP=$(echo "$docker_long"  | grep "${SERVICE}")
  if [ "$RESP" == "" ]; then
    echo "$0.$LINENO no containers with the service \"$SERVICE\" found"
    exit 1
  fi
  #echo "$0.$LINENO resp= $RESP"
  dckr_arr=($(echo "$RESP" | awk '{if ($1 == "NAME") {next;} printf("%s\n", $1);}'))
fi
echo "dckr_arr= ${dckr_arr[@]}"
# cat /sys/fs/cgroup/cpu,cpuacct/docker/b6715b80b4b5a00918b72d0e7afd4280cd27af5b1ad7d1a04768dbb5741c867d/cpu.stat
#nr_periods 2950474
#nr_throttled 104
#throttled_time 122999595615

if [ ! -d "$PROJ" ]; then
  mkdir -p $PROJ
fi

#
# I need to know the tsc freq and the cpu freq... run for 0.01 second
#
$SCR_DIR/../60secs/extras/spin.x -w freq_sml -n 1 -t 0.01 -l 1000 > $PROJ/spin.x.txt

#
# for each container get starting cpu.stat
# And start perf sampling call stacks on container but put the samples in round robin memory buffer.
# Don't write the output file till perf gets the kill -2 perf_pid signal.
# you can set the sampling rate (def 100 samples/sec). We are trying to monitor what goes on in a 0.1 sec docker cpu slot so this will only give us 10 samples per 0.1 cpu bucket.
# Also have timeout $TIME_MX for perf to run. Event we use is cpu-clock (software event). But we could use clockticks.
#
OFILE=$PROJ/docker_cpu_stats.txt
PRF_ARR=()
thr_arr=()
declare -A dckr_stat_prv
declare -A dckr_stat_cur
prf_dat_lst=()
for ((i=0; i < ${#dckr_arr[@]}; i++)); do
  echo "__container $i ${dckr_arr[$i]}" >> $OFILE
  ARR=($(cat /sys/fs/cgroup/cpu,cpuacct/docker/${dckr_arr[$i]}/cpu.stat | awk '{print $2;}'))
  for ((j=0; j < ${#ARR[@]}; j++)); do
    dckr_stat_prv[$i,$j]=${ARR[$j]}
  done
  prf_dat_lst[$i]="$PROJ/prf_${i}.dat"
  nohup $SCR_DIR/perf record -k CLOCK_MONOTONIC -F $FREQ_SMPL -e cpu-clock --cgroup=docker/${dckr_arr[$i]} -g -a -o "${prf_dat_lst[$i]}" --switch-output --overwrite  -- sleep $TIME_MX &> $PROJ/prf_${i}.log  &
  PID_ARR[$i]=$!
done


#./perf  stat -x \; -e cpu-clock,cycles,instructions,duration_time --for-each-cgroup docker/b6715b80b4b5a00918b72d0e7afd4280cd27af5b1ad7d1a04768dbb5741c867d,docker/1c4a1a7bf5d9f264d5d7934c05a504f7c65ff362a7d68aaebc6a4660ddd96a11  -a -e cpu-clock,cycles,instructions sleep 5

#./perf record -F 99 -e cpu-clock --cgroup=docker/1c4a1a7bf5d9f264d5d7934c05a504f7c65ff362a7d68aaebc6a4660ddd96a11 -g -a -o prf.dat --switch-output --overwrite  -- sleep 100 &
#kill -SIGUSR2 101823
#./perf script -i prf.dat.2021112620112836 > tmp1.txt

tm_beg=$(date "+%s")
tm_cur=$tm_beg
tm_end=$((tm_beg+TIME_MX))
#  echo "tm_beg= $tm_beg tm_end= $tm_end"
did_sigusr2=()
has_java=()
#
# for each container, get initial docket stats.
# also check if the container is running java. If it is then copy the code to get the java symbol file into the container.
# And get the mapping of the java pid in the container to the java pid outside the container.
#
declare -A has_java_det
for ((i=0; i < ${#dckr_arr[@]}; i++)); do
  did_sigusr2[$i]=0
  RESP=$(cat /sys/fs/cgroup/cpu,cpuacct/docker/${dckr_arr[$i]}/cpu.cfs_quota_us)
  echo "__cpu.cfs_quota_us $i $RESP" >> $OFILE
  RESP=$(cat /sys/fs/cgroup/cpu,cpuacct/docker/${dckr_arr[$i]}/cpu.cfs_period_us)
  echo "__cpu.cfs_period_us $i $RESP" >> $OFILE
  ARR=($(cat /sys/fs/cgroup/cpu,cpuacct/docker/${dckr_arr[$i]}/cpu.stat | awk '{print $2;}'))
  for ((j=0; j < ${#ARR[@]}; j++)); do
     dckr_stat_prv[$i,$j]=${ARR[$j]}
  done
  ARR=($(cat /sys/fs/cgroup/cpu,cpuacct/docker/${dckr_arr[$i]}/cpuacct.stat | awk '{print $2;}'))
  for ((j=0; j < ${#ARR[@]}; j++)); do
     dckr_acctstat_prv[$i,$j]=${ARR[$j]}
  done
  cat /sys/fs/cgroup/cpu,cpuacct/docker/${dckr_arr[$i]}/cgroup.procs | xargs -I '{}' ps  -p {} -o pid,comm > $PROJ/cgroup.procs_short.txt
  cat /sys/fs/cgroup/cpu,cpuacct/docker/${dckr_arr[$i]}/cgroup.procs | xargs -I '{}' ps  -p {} -f > $PROJ/cgroup.procs_long.txt
  has_java[$i]=$(grep java $PROJ/cgroup.procs_short.txt | wc -l)
  if [ "${has_java[$i]}" -gt "0" ]; then
    ARR=($(grep java $PROJ/cgroup.procs_short.txt | awk '{printf("%s\n", $1);}'))
    for ((j=0; j < ${has_java[$i]}; j++)); do
      has_java_det[$i,$j,"host_pid"]=${ARR[$j]}
      has_java_det[$i,$j,"dckr_pid"]=$(grep NSpid /proc/${ARR[$j]}/status | awk '{printf("%s", $3);}')
      has_java_det[$i,"user"]=$(grep java $PROJ/cgroup.procs_long.txt | grep ${ARR[$j]} | tail -1 |  awk '{printf("%s", $1);}')
      echo docker $i, java $j, host_pid= ${has_java_det[$i,$j,"host_pid"]}, dckr_pid= ${has_java_det[$i,$j,"dckr_pid"]}, usr= ${has_java_det[$i,"user"]}
    done
    docker cp $SCR_DIR/get_symbol_map_for_perf_from_java_in_container.tar.gz ${dckr_arr[$i]}:/tmp/
    docker exec -it ${dckr_arr[$i]} bash -c "cd /tmp; tar xzf /tmp/get_symbol_map_for_perf_from_java_in_container.tar.gz"
  fi
  # ps -ef |grep java |grep deepeta
  # grep NSpid /proc/335930/status
  cpuacct_usage_prv[$i]=$(cat /sys/fs/cgroup/cpu,cpuacct/docker/${dckr_arr[$i]}/cpuacct.usage)
done


#
# this is the main monitoring loop. Ends if time exceeds max time or if script caught sigint (sometimes miss signal if sleeping) or if stopfile is found.
# Data is output each interval but it is just docker cpu stats for each container.
# for each container:
#   1) check if the container is gone (then tell perf for that container to quit.
#   2) Check if I've sent a sigusr2 to a container (because we previously saw throttling in step 3) below).
#      I delay doing the 'perf script' post-processing of the perf dat file till 30 seconds after sending the 'kill -SIGUSR2 perf_pid' to make sure perf has finished writing the file.
#      And I generate the java symbol file (if java used) before doing the 'perf script' cmd
#        have to go into container, generate the java map file, copy the map file out to /tmp with the 'not container' java pid.
#        perf looks for map files in /tmp name /tmp/perf-{host_java_pid].map
#      Then do perf script to convert the .dat file to .txt
#   3) check if the cpu throttling has occurred (via docker cpu.stat). If so then send sigusr2 to perf to dump call stacks to .dat file.
#      Won't process the dump file right away... wait 30 seconds since the last sigusr2 to be sure everything is done and we haven't gotten a storm of throttling.
#      We could be sending a sigusr2 every 1 second if the containers keep throttling. But there would be only 1 second of samples in the file.
#      The sigusr2 doesn't terminate perf, just tells perf to write its buffers out.
#   4) write more stats to the output file (including a message if we did a sigusr2)
# so, if no throttling then we just read the docker stat files, write the stats to a text file, sleep 1, repeat
# 


while [[ "$tm_cur" -lt "$tm_end" ]]; do
  if [ "$GOT_QUIT" == "1" ]; then
      echo "$0.$LINENO quit due to got sigint"
      break
  fi
  if [ -e "$STOPFILE" ]; then
      RESP=$(cat $STOPFILE)
      if [ "$RESP" == "$MYPID" ]; then
          echo "$0.$LINENO quit due to found $STOPFILE"
          rm $STOPFILE
          break
      fi
  fi
  tm_cur=$(date "+%s")
  tm_dff=$((tm_cur-tm_beg))
  echo "tm_elap= $tm_dff"
  TM_STR=$(date "+%Y%m%d%H%M%S")
  EPCH=$(date "+%s.%N")
  echo "__docker_time $tm_dff $EPCH $TM_STR" >> $OFILE
  thr_ck=()
  thr_dff=()
  for ((i=0; i < ${#dckr_arr[@]}; i++)); do
    if [ ! -e /sys/fs/cgroup/cpu,cpuacct/docker/${dckr_arr[$i]}/cpu.stat ]; then
      if [ "${PID_ARR[$i]}" != "" ]; then
	       # the container is gone, kill the perf process
         echo "__docker_sigint $tm_dff $EPCH $TM_STR" >> $OFILE
         kill -2 ${PID_ARR[$i]}
         PID_ARR[$i]=""
      fi
      continue
    fi
    EPCHSECS=$(date "+%s")
    if [[ "${did_sigusr2[$i]}" != "0" ]]; then
      sig_dff=$((EPCHSECS - did_sigusr2[$i]))
      if [ "$sig_dff" -gt "30" ]; then
        did_sigusr2[$i]=0
        prf_dat_arr=($(find $PROJ -name "prf_${i}.dat*" | sort | grep -v dat.old | grep -v ".txt"))
        opt_symfs=
        if [ "${has_java[$i]}" -gt "0" ]; then
          juser=${has_java_det[$i,"user"]}
          if [ "$juser" != "" ]; then
          echo docker exec -it --user $juser  ${dckr_arr[$i]} bash -c 'cd /tmp; ./fg_jmaps.sh'
          docker exec -it --user $juser ${dckr_arr[$i]} bash -c 'cd /tmp; ./fg_jmaps.sh'
          #opt_symfs=" --symfs /tmp "
          for ((j=0; j < ${has_java[$i]}; j++)); do
            hpid=${has_java_det[$i,$j,"host_pid"]}
            dpid=${has_java_det[$i,$j,"dckr_pid"]}
            echo docker cp ${dckr_arr[$i]}:/tmp/perf-${dpid}.map /tmp/perf-${hpid}.map
            docker cp ${dckr_arr[$i]}:/tmp/perf-${dpid}.map /tmp/perf-${hpid}.map
          done
          fi
        fi
        for ((j=0; j < ${#prf_dat_arr[@]}; j++)); do
          if [ ! -e ${prf_dat_arr[$j]}.txt ]; then
            echo $SCR_DIR/perf script -i ${prf_dat_arr[$j]} --kallsyms=/proc/kallsyms  _ ${prf_dat_arr[$j]}.txt
            $SCR_DIR/perf script -i ${prf_dat_arr[$j]} --kallsyms=/proc/kallsyms > ${prf_dat_arr[$j]}.txt &
          fi
        done
      fi
    fi
    if [ "$VERBOSE" -gt "0" ]; then
      echo "$0.$LINENO stats for container $i"
      cat /sys/fs/cgroup/cpu,cpuacct/docker/${dckr_arr[$i]}/cpu.stat
    fi
    ARR=($(cat /sys/fs/cgroup/cpu,cpuacct/docker/${dckr_arr[$i]}/cpu.stat | awk '{print $2;}'))
    str=""
    for ((j=0; j < ${#ARR[@]}; j++)); do
       dckr_stat_cur[$i,$j]=${ARR[$j]}
       thr_dff[$j]=$((dckr_stat_cur[$i,$j] - dckr_stat_prv[$i,$j]))
       str="$str ${thr_dff[$j]}"
       dckr_stat_prv[$i,$j]=${dckr_stat_cur[$i,$j]}
    done
    echo "__docker_stat $EPCH $i $str" >> $OFILE
    if [ "${thr_dff[1]}" -gt "0" ]; then
      echo "$0.$LINENO dckr[$i] throttled $thr_dff"
      echo "__docker_sigusr2 $i $tm_dff $EPCH $TM_STR" >> $OFILE
      kill -SIGUSR2 ${PID_ARR[$i]}
      did_sigusr2[$i]="$EPCHSECS"
    fi
    ARR=($(cat /sys/fs/cgroup/cpu,cpuacct/docker/${dckr_arr[$i]}/cpuacct.stat | awk '{print $2;}'))
    str=""
    for ((j=0; j < ${#ARR[@]}; j++)); do
       dckr_acctstat_cur[$i,$j]=${ARR[$j]}
       thr_dff[$j]=$((dckr_acctstat_cur[$i,$j] - dckr_acctstat_prv[$i,$j]))
       str="$str ${thr_dff[$j]}"
       dckr_acctstat_prv[$i,$j]=${dckr_acctstat_cur[$i,$j]}
    done
    echo "__docker_cpuacct_stat $EPCH $i $str" >> $OFILE
    RESP=$(cat /sys/fs/cgroup/cpu,cpuacct/docker/${dckr_arr[$i]}/cpuacct.usage)
    v=$((RESP-cpuacct_usage_prv[$i]))
    echo "__docker_cpuacct_usage $EPCH $i $v" >> $OFILE
    cpuacct_usage_prv[$i]="$RESP"
  done
  #sleep $INTERVAL
  sleep 1
done
# fctr = 1e-9 # to convert cpuacct.usage and throttling to cpus = fctr * 'cpuacct.usage diff'/time_diff

#
# now we've exited the monitoring loop so stop all the perf processes.
#
echo "$0.$LINENO kill perf jobs if any"
for ((i=0; i < ${#dckr_arr[@]}; i++)); do
  if [ "${PID_ARR[$i]}" != "" ]; then
     echo "__docker_sigint $i $tm_dff $EPCH $TM_STR" >> $OFILE
     kill -2 ${PID_ARR[$i]}
  fi
done

#
# wait for perf to exit
#
echo "$0.$LINENO begin wait"
wait

#
# now for each container, we need to check if we sent a sigusr2 to get a call stack .dat file but we haven't yet post processed the output.
# If so we have to do the 'get java map file' stuff and 'perf script' now
#
for ((i=0; i < ${#dckr_arr[@]}; i++)); do
  find $PROJ -name "prf_${i}.dat*"
  prf_dat_arr=($(find $PROJ -name "prf_${i}.dat*" | sort | grep -v dat.old | grep -v ".txt"))
        if [ "${has_java[$i]}" -gt "0" ]; then
          juser=${has_java_det[$i,"user"]} # assume all java is same user
          if [ "$juser" != "" ]; then
          echo docker exec -it --user $juser ${dckr_arr[$i]} bash -c 'cd /tmp; ./fg_jmaps.sh'
          docker exec -it --user $juser ${dckr_arr[$i]} bash -c 'cd /tmp; ./fg_jmaps.sh'
          for ((j=0; j < ${has_java[$i]}; j++)); do
            hpid=${has_java_det[$i,$j,"host_pid"]}
            dpid=${has_java_det[$i,$j,"dckr_pid"]}
            echo docker cp ${dckr_arr[$i]}:/tmp/perf-${dpid}.map /tmp/perf-${hpid}.map
            docker cp ${dckr_arr[$i]}:/tmp/perf-${dpid}.map /tmp/perf-${hpid}.map
          done
          fi
        fi
  for ((j=0; j < ${#prf_dat_arr[@]}; j++)); do
    if [ ! -e ${prf_dat_arr[$j]}.txt ]; then
      echo $SCR_DIR/perf script -i ${prf_dat_arr[$j]} --kallsyms=/proc/kallsyms  _ ${prf_dat_arr[$j]}.txt
      $SCR_DIR/perf script -i ${prf_dat_arr[$j]} --kallsyms=/proc/kallsyms  > ${prf_dat_arr[$j]}.txt
    fi
  done
done

exit 0

