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


while getopts "hvd:I:p:s:t:" opt; do
  case ${opt} in
    d )
      DOCKER=$OPTARG
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
      echo "   -i interval_in_secs  sleep interval between get stats"
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
docker_short=$(docker ps)
echo "$0.$LINENO $?"
docker_long=$(docker ps --no-trunc)
echo "$0.$LINENO $?"
declare -a dckr_arr
SV_IFS="$IFS"
if [ "$DOCKER" != "" ]; then
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
  RESP=$(echo "$docker_long"  | grep "${SERVICE}")
  if [ "$RESP" == "" ]; then
    echo "$0.$LINENO no containers with the service \"$SERVICE\" found"
    exit 1
  fi
  #echo "$0.$LINENO resp= $RESP"
  dckr_arr=($(echo "$RESP" | awk '{if ($1 == "NAME") {next;} printf("%s\n", $1);}'))
fi
echo "dckr_arr= ${dckr_arr[@]}"
#root@dca1-3tx:/tmp# cat /sys/fs/cgroup/cpu,cpuacct/docker/b6715b80b4b5a00918b72d0e7afd4280cd27af5b1ad7d1a04768dbb5741c867d/cpu.stat
#nr_periods 2950474
#nr_throttled 104
#throttled_time 122999595615

if [ ! -d "$PROJ" ]; then
  mkdir -p $PROJ
fi

PRF_ARR=()
thr_arr=()
declare -A dckr_stat_prv
declare -A dckr_stat_cur
for ((i=0; i < ${#dckr_arr[@]}; i++)); do
  echo "$0.$LINENO stats for container $i"
  ARR=($(cat /sys/fs/cgroup/cpu,cpuacct/docker/${dckr_arr[$i]}/cpu.stat | awk '{print $2;}'))
  for ((j=0; j < ${#ARR[@]}; j++)); do
    dckr_stat_prv[$i,$j]=${ARR[$j]}
  done
  nohup $SCR_DIR/perf record -F 99 -e cpu-clock --cgroup=docker/${dckr_arr[$i]} -g -a -o "$PROJ/prf_${i}.dat" --switch-output --overwrite  -- sleep $TIME_MX &> $PROJ/prf_${i}.log  &
  PID_ARR[$i]=$!
done


#./perf  stat -x \; -e cpu-clock,cycles,instructions,duration_time --for-each-cgroup docker/b6715b80b4b5a00918b72d0e7afd4280cd27af5b1ad7d1a04768dbb5741c867d,docker/1c4a1a7bf5d9f264d5d7934c05a504f7c65ff362a7d68aaebc6a4660ddd96a11  -a -e cpu-clock,cycles,instructions sleep 5

#./perf record -F 99 -e cpu-clock --cgroup=docker/1c4a1a7bf5d9f264d5d7934c05a504f7c65ff362a7d68aaebc6a4660ddd96a11 -g -a -o prf.dat --switch-output --overwrite  -- sleep 100 &
#kill -SIGUSR2 101823
#./perf script -i prf.dat.2021112620112836 > tmp1.txt

tm_beg=$(date "+%s")
tm_cur=$tm_beg
tm_end=$((tm_beg+TIME_MX))
OFILE=$PROJ/docker_cpu_stats.txt
#  echo "tm_beg= $tm_beg tm_end= $tm_end"
while [[ "$tm_cur" -lt "$tm_end" ]] && [[ "$GOT_QUIT" == "0" ]]; do
  tm_cur=$(date "+%s")
  tm_dff=$((tm_cur-tm_beg))
  echo "tm_elap= $tm_dff"
  TM_STR=$(date "+%Y%m%d%H%M%S")
  EPCH="$EPOCHREALTIME"
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
    fi
  done
  sleep $INTERVAL
done

echo "$0.$LINENO kill perf jobs if any"
for ((i=0; i < ${#dckr_arr[@]}; i++)); do
  if [ "${PID_ARR[$i]}" != "" ]; then
     echo "__docker_sigint $i $tm_dff $EPCH $TM_STR" >> $OFILE
     kill -2 ${PID_ARR[$i]}
  fi
done
echo "$0.$LINENO begin wait"
wait
for ((i=0; i < ${#dckr_arr[@]}; i++)); do
  find $PROJ -name "prf_${i}.dat*"
  prf_dat_arr=($(find $PROJ -name "prf_${i}.dat*" | grep -v dat.old))
  for ((j=0; j < ${#prf_dat_arr[@]}; j++)); do
    echo $SCR_DIR/perf script -i ${prf_dat_arr[$j]} _ ${prf_dat_arr[$j]}.txt
    $SCR_DIR/perf script -i ${prf_dat_arr[$j]} > ${prf_dat_arr[$h]}.txt
  done
done

exit 0

