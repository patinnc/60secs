#!/usr/bin/env bash

# install, setup, config, test, run, fetch, report, combine benchmarks on a list of servers
# use -h option to see options

RES=res.txt
PROJ_DIR=
BMARK_SUBDIR=DynoInstallFolder
SCR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
WORK_DIR=./work_dir
WORK_TMP="cmd_%04d.txt"
SCR_BASENAME=`basename $0`

SSH_MODE="root"
IFS_SV=$IFS

# the hard-coded lists of 5x/aws/gcp/onprem host names has been replaced with the files:
# hosts_5x.lst
# hosts_aws.lst
# hosts_gcp.lst
# hosts_onprem.lst
declare -a CFG_OPTS
cfg_opts_arr=()
CFG_FL="$SCR_DIR/${SCR_BASENAME}_cfg"
if [ ! -e $CFG_FL ]; then
  CFG_FL="$SCR_DIR/60secs/${SCR_BASENAME}_cfg"
fi
if [ -e $CFG_FL ]; then
readarray -t cfg_opts_arr < <(awk '
        {
          if (NF == 0) { next;}
          printf("%s\n", $0);
        }
        ' $CFG_FL)
fi
if [ "${#cfg_opts_arr[@]}" -gt "0" ]; then
  for ((i_coa=0; i_coa < ${#cfg_opts_arr[@]}; i_coa++)); do
    RESP=`echo "${cfg_opts_arr[$i_coa]}" | awk -v want="wxy_str" '/^wxy_str: / { printf("%s\n", $2);exit(0);}'`
    if [ "$RESP" != "" ]; then
      wxy_str="$RESP"
    fi
    RESP=`echo "${cfg_opts_arr[$i_coa]}" | awk -v want="wxy_hs" '/^wxy_hs: / { printf("%s\n", substr($0, length($1)+1));exit(0);}'`
    if [ "$RESP" != "" ]; then
      wxy_hs="$RESP"
    fi
    RESP=`echo "${cfg_opts_arr[$i_coa]}" | awk -v want="wxy_hl" '/^wxy_hl: / { printf("%s\n", substr($0, length($1)+1));exit(0);}'`
    if [ "$RESP" != "" ]; then
      wxy_hl="$RESP"
    fi
    RESP=`echo "${cfg_opts_arr[$i_coa]}" | awk -v want="wxy_flds" '/^wxy_flds: / { printf("%s\n", substr($0, length($1)+1));exit(0);}'`
    if [ "$RESP" != "" ]; then
      wxy_flds="$RESP"
    fi
  done
fi
if [ "$wxy_str" == "" ]; then
  wxy_str="wxy";
  wxy_hs="wxy_hs";
  wxy_hl="wxy_hl";
  wxy_flds="wxy_flds";
fi

CFG_DIR=./AUTOGEN_config_UNDEFINED
TAR_GZ=
DRY_RUN=n
RUN_CMDS="ping,screen,shell,command,pcmd,lcl_cmd,pssh_test,ssh_test,opt_reboot,popt_${wxy_str}_info,opt_${wxy_str}_info,nameserver_test,scp_tar,untar,opt_install_jdk8,opt_install_jdk11,setup,opt_free_up_disk,config,post,run_cpu,run_ncu,run_cmd,run_disk,run_fio,run_both,run_custom,run_multi,run_specjbb,run_specint,run_sysinfo,run_stream,run_geekbench,peek,pfetch_untar,fetch_untar,get,get_untar,get_recur,report,combine"
SV_CMDS=$RUN_CMDS  # save them off because they get updated in getopts and if the user does -h they won't see the list
VERBOSE=0
BMARK_ROOT=/root

DID_n=0
DID_bmark_root=0
RPT_FILE=
CMB_FILE=
DID_RPT_FILE_init="0"
DID_CMB_FILE_init="0"
CMB_CNTR=0
ARCHIVE_DIR=
COMMAND=
HOST_NUM=
RUN_CMDS_LOG="$SCR_DIR/dyno_run_cmds.log"
RUN_CMDS=
FETCH_WORKED=
FETCH_FAILED=
USERNM_DEF=root
DISK_MIN_SZ_BYTES=100000000
SCP_BIN=scp
SCP_SEP=":"
SSH_BIN=ssh
DIR_60SECS_SCRIPTS=
SCRIPT=
DURA=
ITERS=
BKGRND_TASKS_MAX=30
BKGRND_TASKS_CUR=0


GOT_QUIT=0
# function called by trap
catch_signal() {
    printf "\rSIGINT caught      "
    GOT_QUIT=1
}

trap 'catch_signal' SIGINT

#echo "HOSTS before options: $HOSTS" | cut -c1-200

myInvocation="$(printf %q "$BASH_SOURCE")$((($#)) && printf ' %q' "$@")"
echo "cmd line: $myInvocation"
LOGGED_INVOKE=0

dyno_log() {
  tstmp=`date "+%Y%m%d_%H%M%S"`
  if [ $LOGGED_INVOKE -eq 0 ]; then
    LOGGED_INVOKE=1
    echo "$tstmp START $myInvocation"     >> $RUN_CMDS_LOG
    echo "$tstmp HOSTS $HOSTS"            >> $RUN_CMDS_LOG
    echo "$tstmp BMARK_ROOT $BMARK_ROOT"  >> $RUN_CMDS_LOG
    echo "$tstmp CFG_DIR $CFG_DIR"        >> $RUN_CMDS_LOG
    echo "$tstmp PROJ_DIR $PROJ_DIR"      >> $RUN_CMDS_LOG
    echo "$tstmp TAR_GZ $TAR_GZ"          >> $RUN_CMDS_LOG
  fi
  myArgs="$((($#)) && printf ' %q' "$@")"
  echo "$tstmp CMD $myArgs"  >> $RUN_CMDS_LOG
}

function print_help() {
      echo "$0 does an tar xvf Dyn*.tar.gz on each host, setup.sh, post setup and run_compute_and_disk.sh"
      echo "Usage: $0 [-h] [ -t Dyno tar.gz file ] [ -n \"host_name_list\"] [ -p proj_dir ] [ -c config_dir ] [-v] [ -b benchmark_root_dir] [ -o out_file] -r cmd_to_be_run"
      echo "   -t dyno.tar.gz file"
      echo "     The DynoInstallFolder_*.tar.gz file to be 'cd BMARK_ROOT_DIR; tar xzvf dyno.tar.gz'"
      echo "   -a archive_dir   for '-r fetch' or '-r get' the tar.gz file will be put in archive_dir/hostname/"
      echo "     The default dir is ./dyno_archive"
      echo "     use 'fetch_untar' to fetch the tar.gz and untar it. fetch is for a dyno output dir."
      echo "     use 'pfetch_untar' to fetch_untar in parallel"
      echo "     use 'get_untar' to fetch the tar.gz and untar it. get/get_untar is for just scp a tar.gz from remote host to the archive dir"
      echo "     use 'get_recur' to recursively get the output dir to the archive dir"
      echo "     You can untar.gz all the files in the archive dir withdult dir is ./dyno_archive"
      echo "     cd ./dyno_archive; find . -name \"*tar.gz\" -printf 'pushd %h; tar xzvf %f; popd\n' > tmp.sh; bash ./tmp.sh"
      echo "   -b bmark_root_dir"
      echo "     This is where DynoInstallFolder will be put"
      echo "     The default is /root. For example, if you enter '-b /bmark' then DynoInstallFolder will be put in /bmark and specjbb & cpu2017 will be in /bmark."
      echo "     This option is used when there isn't enough room on /root to install the benchmarks"
      echo "   -B bmark_root_subdir"
      echo "     For dyno, this is the DynoInstallFolder subdir"
      echo "     For some other system, this is the main folder of the .tar.gz file you installed with '-r scp_tar,untar'"
      echo "     The default is DynoInstallFolder below the bmark_root_dir. For example, if you enter '-b /bmark' then DynoInstallFolder will be put in /bmark and specjbb & cpu2017 will be in /bmark."
      echo "     This option is used when there isn't enough room on /root to install the benchmarks or you are doing something besides dyno"
      echo "   -c config_dir"
      echo "     The config dir to be used on the host"
      echo "     By default this is /root/$CFG_DIR  . Assumes you've already run DynoInstallFolder/DynoConfig. "
      echo "     See DynoInstallFolder/README.txt"
      echo "   -C command_to_be_run"
      echo "     Used with the '-r command' or '-r pcmd' run options. The command_to_be_run will be run on each host"
      echo "     Enclose in quotes if the command contains spaces"
      echo "     If the string contains %HOST% then %HOST% is replaced with the hostname."
      echo "     If the string contains %HOST_NUM% then %HOST_NUM% is replaced with the host number in the list."
      echo "     If the string contains %HOST_ARR{x}% then %HOST_ARR{x}% is replaced with the x'th field of the line for that host from the hostS_*.lst"
      echo "   -D 60secs script dir if you are processing 60sec data dirs too"
      echo "   -l host_list_file  everything after a # is a comment. 1 or more host names per line"
      echo "   -m max_background_tasks. Default is $BKGRND_TASKS_MAX. '-m 0' disables running jobs in the background"
      echo "   -M min_size_in_bytes_for_disks_to_be_considered_in_disk_tests"
      echo "     This option is for the 'config' step. DynoConfig will look at the list of disks and ask you if you want to use each disk in the IO tests"
      echo "     Some OS's have 47+ other devices that look like disks and so you have to type y/n to 47 devices you don't care about"
      echo "     This option lets you say 'only show me disks >= x number of bytes' for consideration in the disk tests."
      echo "     I usually do '-r command -C \"lsblk\"' before the config step, find the smallest disk that I want to use for the IO tests"
      echo "     And then do '-r command -C \"lsblk -b\"' to get that system's disk size in bytes and then run the config step with that byte size"
      echo "     The default min size is '-M 100000000' (100 Million). You can't enter m or g or t for the size, sorry."
      echo "   -n hostname_list"
      echo "     replace the default host namae list with the quoted 'hostname_list'"
      echo "     If there is more than 1 host, separate the hosts with a space and enclose the list with dbl quotes"
      echo "   -N x   use host number x from the list. Can enter list like 0,3 (just hosts 0 & 3) or 0,2-4,8 (does 0,2,3,4,8)"
      echo "   -o report_file"
      echo "     The output file for the '-r report' data and input file for the '-r combine' step. The file will be set to zero length and the output from each server concatenated to it."
      echo "   -O report_file"
      echo "     Same as above but the file will not be set to zero length first... so be careful not to let old content confuse you."
      echo "   -z combine_file"
      echo "     This file is the output of the '-r combine' without some extra lines separating the output (such as the host name). The file will be initially set to 0 length."
      echo "   -Z combine_file"
      echo "     This file is the output of the '-r combine' without some extra lines separating the output (such as the host name). This file will not be set to 0 length so be careful about old data."
      echo "   -p project_dir"
      echo "     by default the host results dir name /root/output"
      echo "     If you specify a project dir, then 'project_dir' will be created under /root/output and all"
      echo "     results will be under /root/output/project_dir/"
      echo "   -r run_commands"
      echo "     by default no cmds are run."
      echo "     All cmds executed are recorded in $RUN_CMDS_LOG file (you -R run_cmd_log_file to change)"
      echo "     the command avail: $SV_CMDS"
      echo "     This lets you do say, just the scp_tar over all the machines, then the untar, etc"
      echo "     The cmds are layed out in the order that you usually run them beginning with scp_tar."
      echo "     You can combine cmds if you are pretty sure they work. For example you can do '-r scp_tar,untar,setup'."
      echo "     The install steps are: 'scp_tar,untar,setup'."
      echo "     The config  steps are: 'config,post'."
      echo "     The run benchmarks steps are 'run_both|run_cpu|run_ncu|run_disk|run_fio|run_specjbb|run_stream|run_geekbench|run_sysinfo|run_config'"
      echo "     The 'checking to see if things are running' steps are 'peek' or 'shell' or 'screen' (if using screen)"
      echo "     The 'collecting output from boxes' step is 'report'"
      echo "     The 'combine results into table' step is 'combine'"
      echo "     The 'fetch output files from server' step is 'fetch' or 'fetch_untar'"
      echo "     The 'pfetch_untar' is parallel version of 'fetch_untar'"
      echo "     The 'scp an output file from server' step is 'get' or 'get_untar'"
      echo "     The 'scp an output dir recursively' step is 'get_recur'"
      echo "     Below is more detail on each '-r cmd'"
      echo "     'ping' run ping host to see if we can find the server. Note that GCP boxes don't respond to ping. This cmd is optional"
      echo "     'shell' ssh's to the box and opens a bash shell so you can do something not done by this script. This cmd is optional."
      echo "     'screen' ssh's to the box and opens a bash, can does 'screen -r' to reconnect to detached screen session. This cmd is optional."
      echo "     'command' ssh's to the box and opens a bash shell and runs the command from '-C command_to_be_run'."
      echo "     'pcmd' ssh's to the box and opens a bash shell and runs the command from '-C command_to_be_run', sends output to work_dir/cmd_xxxx.txt"
      echo "     'lcl_cmd' runs (locally) the command from '-C command_to_be_run' and optionally redirects output to -o file"
      echo "        If the string contains %HOST% then %HOST% is replaced with the hostname."
      echo "     'ssh_test' ssh to each box and runs some commands to see if you can ssh to the box. A report of 'worked' 'failed' is produced at the end. Optional cmd"
      echo "     'pssh_test' do above ssh_test in parallel"
      echo "     'opt_${wxy_str}_info' runs \"${wxy_str} ${wxy_hs}\" on each host and outputs results to -o output_file"
      echo "     'popt_${wxy_str}_info' runs \"${wxy_str} ${wxy_hs}\" on each host in parallel and outputs results to -o output_file"
      echo "     'opt_reboot' runs 'ipmi hostname chassis power reset' on each host"
      echo "     'nameserver_test' run 'ping google.com' on each host to see if it has nameserver properly setup. Install won't work if the server doesn't have a nameserver."
      echo "         This cmd is optional. A report of which boxes worked okay and which boxes failed is printed at the end"
      echo "     'scp_tar' does an scp of the '-t dyno.tar.gz' file to each server and puts it in BMARK_DIR (/root by default or -b BMARK_DIR). Must be done at least once."
      echo "         Sometimes if all I have is updates to the DynoInstallFolder/*.sh scripts then I just '-t Dyno_scripts_vYY.tar.gz -r scp_tar,untar' to update the scripts."
      echo "     'untar' does 'cd BMARK_DIR; tar xzvf Dynoxxx.tar.gz'"
      echo "     'opt_install_jdk8' will install java jdk8 (into /opt/ ) as the default java on the host and copy DynoInstallFolder/extras/jdk8.sh to /etc/profile.d/"
      echo "         This is an optional step intended for boxes with no java installed. After this step if you do 'java -version' on the box it should say jdk8."
      echo "         You have to run this after the untar step since the jdk8 is in the tarfile."
      echo "     'opt_install_jdk11' will install java jdk11 (into /opt/ ) as the default java on the host and copy DynoInstallFolder/extras/jdk11.sh to /etc/profile.d/"
      echo "     'setup' does '(optionally export DYNO_ROOT=BMARK_DIR); cd BMARK_DIR/DynoInstallFolder; ./setup.sh' to build/install the benchmarks"
      echo "     'opt_free_up_disk' cmd deletes the BMARK_DIR/DynoInstallFolder_v*.tar.gz and DynoInstallFolder/specint dir"
      echo "         This is an optional step. It can be useful if the /root disk is small or almost full"
      echo "     'config' run cmd runs an interactive DynoConfig on each server. You get asked whether you want to use each disk in the IO tests"
      echo "         If there are already files in the config dir from previous DynoConfig runs then you will be prompted to delete them. The old files can mess up the benchmarks"
      echo "     'post' runs a script to fixup issues with DynoConfig files and install some extra stuff (where I don't want to run setup again)"
      echo "     "
      echo "     For each 'run_*' a script in BMARK_DIR/DynoInstallFolder/run_*.sh is run in the background."
      echo "     The '-c config_dir' and the '-p project_dir' (output dir) is passed to each run_* script"
      echo "     'run_cpu' runs the CPU benchmarks (stream, specjbb, specint_rate (cpu2017)). Stream takes a couple minutes, specjbb 2.25 hours, specint 6+ hours. run_cpu is also done by 'run_both'"
      echo "     'run_ncu' runs the NCU CPU benchmark. run_ncu takes about 40 minuts for 1 level. It will needs 4-6 levels, so it takes 2.67-4 hours."
      echo "        proj_dir like 'proj_dir/run_XXcpus' will be used for ncu runs."
      echo "     'run_cmd' runs the file passed in the '-C cmd_to_run'. If the only -r option is 'run_cmd' then up to $BKGRND_TASKS_MAX will be run in the background"
      echo "     'run_disk' runs the disk benchmarks (fio, vdbench). run_disk is also done by 'run_both'"
      echo "     'run_fio' runs the disk benchmark fio."
      echo "     'run_both' runs both the CPU and disk benchmarks. Note that if you didn't select any disks on a server then the disk tests won't do anything."
      echo "     'run_custom' runs BMARK_DIR/DynoInstallFolder/run_custom.sh. See the file to see what it is set to do."
      echo "        say the specjbb test fails everywhere due to no java installed. you could modify run_custom.sh to run specjbb, save it to tar.gz file, then use '-r scp_tar,untar' to copy it each box, then '-r run_custom' to it on each box".
      echo "     'run_multi' runs BMARK_DIR/DynoInstallFolder/run_multi.sh. run_multi accepts -I iters or -T duration and -s script_to_run"
      echo "        This lets you do multple runs of the same script"
      echo "     'run_sysinfo' runs BMARK_DIR/DynoInstallFolder/run_sysinfo.sh. This gets run in run_cpu/run_both/run_disk but I frequently add more 'get sysinfo' cmds and want to recollect the sysinfo data again."
      echo "     'run_specjbb' runs BMARK_DIR/DynoInstallFolder/run_specjbb.sh. This gets run in 'run_cpu' and 'run_both' but it is useful (since it is sort of short ~2 hours) to see the directories are setup. You could run this on each box then to 'peek' to see if it running and in the right output dir"
      echo "     'run_stream' runs BMARK_DIR/DynoInstallFolder/run_stream.sh. This gets run in 'run_cpu' and 'run_both' but it is useful (since it is short) to see the directories are setup. You could run this on each box then to 'peek' to see if it running and in the right output dir"
      echo "     'run_geekbench|run_gb' runs BMARK_DIR/DynoInstallFolder/run_geekbench.sh. This gets run in 'run_cpu' and 'run_both' but it is useful (since it is short) to see the directories are setup. You could run this on each box then to 'peek' to see if it running and in the right output dir"
      echo "     The 'peek' run cmd looks to see what is in the output dir (-p project_dir) and the does top on each server to see if it still running something"
      echo "     The 'report' copies gen_report.sh from the install_and_run dir on the techops box to each box and does get_output for each box. You can specify an output file with -o out_file."
      echo "        If you've fetched the output already and it is in the -a archive_dir then get_ouput.sh is run against the archive dir"
      echo "     The 'combine' extracts summary info from the output report file (-o outfile) and creates a ';' delimited report from each box suitable for pasting into a spreadsheet"
      echo "     The 'fetch' gets the output dir (-p proj_dir) from each box and puts in the dyno_archive dir (-a dyno_archive_dir by default ./dyno_archive)"
      echo "        Use the -a archive_dir to specify a dir into which the tar.gz file will be put."
      echo "        If you have '-p /root/output/pat_tst06 -r fetch -a archive' then the tar gz will be:"
      echo "        ./archive/host_name/pat_tst06.tar.gz"
      echo "     The 'fetch_untar' does the above get and untars the file"
      echo "     The 'pfetch_untar' a parallel version of fetch_untar"
      echo "     The 'get' justs gets the -t targz file from remote host, puts it in the archive dir"
      echo "     The 'get_untar' justs gets the -t targz file from remote host, puts it in the archive dir and untars it"
      echo "     The 'get_recur' gets the last level of the remote host output dir and puts it in the archive dir"
      echo "   -s scriptname    for -r run_multi and -T duration_in_secs. This lets you repeat scriptname for duration seconds"
      echo "      For -r run_custom then -s scriptname is passed to run_custom as a script option"
      echo "   -T duration_in_secs with -r run_multi and -s scriptname. This lets you repeat scriptname for duration seconds"
      echo "      so you do: -r run_multi -s run_stream.sh -T 3600 to do run_stream.sh for 3600 secs."
      echo "      If you append 'm' to the duration then the duration is treated as minutes and converted to seconds"
      echo "      If you append 'h' to the duration then the duration is treated as hours and converted to seconds"
      echo "      This also works for -r run_custom (but you might have to change run_custom.sh)"
      echo "   -I iterations      run script iterations times. for use with -s and -r run_multi"
      echo "   -R run_cmd_log_file  all cmds executed are recorded in this file. By default the name is 'dyno_run_cmds.log' in same dir as this script."
      echo "   -d do a dry run. Don't execute cmds, just show what it will do"
      echo "   -g use GCP host list"
      echo "   -G use sudo ssh mode (if you can't ssh root@host then do a 'ssh host su -l -s /bin/bash ...)"
      echo "   -u user_name   run ssh command as user_name. Default is root. This is for cases where you have to login as yourself"
      echo "      If you use '-u none' then no user@ prefix will be added to hostname. This is for crane zone hosts."
      echo "   -v verbose mode"
      echo "   -q pass -q to run_cmd script to get script to stop 60secs monitoring after the script ends"
}


WATCH_IN=
USE_LIST=
USE_LIST_IN=
QUIT_IN=

while getopts "dgGhqva:b:B:c:C:D:I:l:m:M:n:N:o:O:p:r:R:s:t:T:u:W:z:Z:" opt; do
  case ${opt} in
    h )
      print_help
      exit 0
      ;;
    q )
      QUIT_IN=1
      ;;
    a )
      ARCHIVE_DIR=$OPTARG
      ;;
    b )
      BMARK_ROOT=$OPTARG
      DID_bmark_root=1
      ;;
    B )
      BMARK_SUBDIR=$OPTARG
      DID_bmark_root_subdir=1
      ;;
    c )
      CFG_DIR=$OPTARG
      ;;
    C )
      COMMAND=$OPTARG
      ;;
    d )
      DRY_RUN=y
      ;;
    D )
      DIR_60SECS_SCRIPTS=$OPTARG
      ;;
    g )
      if [ $DID_n -eq 0 ]; then
        HOSTS="$GCP_IP"
      fi
      ;;
    G )
      SSH_MODE="sudo"
      ;;
    I )
      ITERS=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    l )
      USE_LIST_IN=$OPTARG
      ;;
    m )
      BKGRND_TASKS_MAX_IN=$OPTARG
      ;;
    M )
      DISK_MIN_SZ_BYTES=$OPTARG
      ;;
    n )
      HOSTS=$OPTARG
      DID_n=1
      ;;
    N )
      HOST_NUM=$OPTARG
      DID_n=1
      ;;
    o )
      RPT_FILE=$OPTARG
      ;;
    O )
      RPT_FILE=$OPTARG
      DID_RPT_FILE_init="1"
      ;;
    z )
      CMB_FILE=$OPTARG
      ;;
    Z )
      CMB_FILE=$OPTARG
      DID_CMB_FILE_init="1"
      ;;
    p )
      PROJ_DIR=$OPTARG
      ;;
    r )
      RUN_CMDS=$OPTARG
      ;;
    R )
      RUN_CMDS_LOG=$OPTARG
      ;;
    s )
      SCRIPT=$OPTARG
      ;;
    t )
      TAR_GZ=$OPTARG
      ;;
    T )
      DURA=$OPTARG
      ;;
    u )
      USERNM_IN=$OPTARG
      ;;
    W )
      WATCH_IN="$OPTARG"
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument, cmdline= ${@}" 1>&2
      exit 1
      ;;
    \? )
      echo "Invalid option: $OPTARG, cmdline= ${@}" 1>&2
      exit 1
      ;;
  esac
done
shift $((OPTIND -1))

if [ "$BKGRND_TASKS_MAX_IN" != "" ]; then
  BKGRND_TASKS_MAX=$BKGRND_TASKS_MAX_IN
fi
USERNM=$USERNM_IN

if [ "$USE_LIST_IN" != "" ]; then
  USE_LIST=$USE_LIST_IN
  if [ "${USE_LIST:0:4}" == "uns:" ]; then
   echo "USE_LIST= uns $USE_LIST"
  else
  IFS=',' read -ra USE_LISTA <<< "$USE_LIST"
  IFS=$IFS_SV
  USE_LIST=
  SEP=
  for i in "${USE_LISTA[@]}"; do
    if [ ! -e $i ]; then
      echo "didn't find host list file \"-l $USE_LIST_IN\" file $i"
      exit 1
    fi
    USE_LIST="${USE_LIST}${SEP}$i"
    SEP=" "
    # process "$i"
  done
  RESP=`grep -E "^include " $USE_LIST`
  if [ "$RESP" != "" ]; then
    USE_LIST=`echo "$RESP" | awk '{printf("%s ", $2);}'`
  fi
  fi
else
  echo "$0.$LINENO you have to specify host list with -l host_list_file. Bye"
  exit 1
fi
#echo "$0.$LINENO use_list= $USE_LIST"
#exit 1

# check if run_cmds are all valid
RESP=`awk -v cmds_in="$RUN_CMDS" -v cmds_sv="$SV_CMDS" '
   BEGIN{
     nin = split(cmds_in, in_arr, ",");
     nsv = split(cmds_sv, sv_arr, ",");
     for (i=1; i <= nsv; i++) {
       sv_hsh[sv_arr[i]] = i;
     }
     for (i=1; i <= nin; i++) {
       if (!(in_arr[i] in sv_hsh)) {
          printf("suboption \"%s\" of input option \"-r %s\" invalid.\n", in_arr[i], cmds_in) > "/dev/stderr";
          printf("valid -r suboptions are: %s\n", cmds_sv) > "/dev/stderr";
          printf("%s\n", in_arr[i]);
          exit 1;
       }
     }
     printf("\n");
     exit 0;
   }
  '`
if [ "$RESP" != "" ]; then
  echo "error in \"-r $RUN_CMDS\". Bye"
  $FIND_CLOSEST "$RUN_CMDS" "$SV_CMDS"
  exit 1
fi

if [ "$TAR_GZ" != "" ]; then
 if [[ "$RUN_CMDS" == *"scp_tar"* ]]; then
  if [ ! -e $TAR_GZ ]; then
    echo "didn't find file for scp_tar operation -t $TAR_GZ"
    exit 1
  fi
 fi
fi

if [ "$QUIT_IN" == "1" ]; then
  QUIT_STR=" -q "
fi

if [ "$USE_LIST" != "" ]; then
    file=$USE_LIST
    HOSTS=
    SEP=
    if [ "${USE_LIST:0:4}" == "uns:" ]; then
      HOSTS=`uns $USE_LIST | awk '
        BEGIN{str=""; sep="";}
function tot_compare(i1, v1, i2, v2,    l, r)
{
    m1 = hlkup[i1];
    m2 = hlkup[i2];
    if (m1 < m2)
        return -1
    else if (m1 == m2)
        return 0
    else
        return 1
}
        {
          h=$2;
          if (!(h in hlist)) {
            ++mx;
            hlist[h] = mx;
            hlkup[mx] = h;
          }
        }
        END{
         for (i=1; i <= mx; i++){ idx[i]=i;}
         asorti(idx, sidx, "tot_compare")
         sep="";
         str="";
         for (i=1; i <= mx; i++){
           j=sidx[i];
           str = str ""sep"" hlkup[j];
           sep = " ";
         }
         printf("%s\n", str);
        }'`
      #echo "HOSTS= $HOSTS"
    else
      HOSTS=`awk 'BEGIN{ sep=""; }
        /^#/{
            next;
        }
        {
            pos = index($0, "#");
            if (pos > 1) {
                $0 = substr($0, 1, pos-1);
            }
            if (($1 == "GCP" || $1 == "UBER" || $1 == "UBER_LAB" || $1 == "AWS") && $2 == ":") {
                $1 = "";
                $2 = "";
            }
            gsub(/^[ \t]+|[ \t]+$/, "");
            str=str""sep""$0;sep=" ";
        }
        END{printf("%s\n", str);
            #printf("hosts= %s\n", str) > "/dev/stderr";
        }' $file`
        declare -a HOST_ARR
        readarray -t HOST_ARR < <(awk '
        {
          if (NF == 0) { next;}
            if (($1 == "GCP" || $1 == "UBER" || $1 == "UBER_LAB" || $1 == "AWS") && $2 == ":") {
                $1 = "";
                $2 = "";
            }
          printf("%s\n", $0);
        }
        ' $file)
      echo "$0.$LINENO HOST_ARR= ${#HOST_ARR[@]}"
    fi
fi
if [[ "$RUN_CMDS" == *"report"* ]]; then
  if [ "$HOSTS" == "" -a "$ARCHIVE_DIR" != "" ]; then
    BASE_DIR=$(basename $PROJ_DIR)
    USE_DIR=$ARCHIVE_DIR/$BASE_DIR/
    HOSTS=`ls -1 $USE_DIR`
    echo "doing report: no -l host_list_file, look for host names in $USE_DIR. Got HOSTS= $HOSTS" > /dev/stderr
  fi
fi
if [ "$HOSTS" == "" ]; then
  echo "you must select a host list with -l host_list_file"
  exit 1
fi

if [ "$DURA" != "" -a "$ITERS" != "" ]; then
  echo "You can't enter duration -T $DURA and num_iterations -I $ITERS both. One or the other but not both. bye"
  exit 1
fi

if [ "$RUN_CMDS" != "run_custom" ]; then
if [ "$SCRIPT" != "" -o "$DURA" != "" ]; then
  if [ "$DURA" != "" ]; then
  if [ "$SCRIPT" == "" -o "$DURA" == "" ]; then
    echo "$0.$LINENO if you enter -s $SCRIPT or -T $DURA then you must enter both options. Bye"
    exit 1
  fi
  if [ "$RUN_CMDS" != "run_multi" ]; then
    echo "Note that if you enter -s $SCRIPT and/or -T $DURA the options have no effect unless you have -r run_multi."
  fi
  RESP=`echo $DURA | sed 's/m//i'`
  if [ "$RESP" != "$DURA" ]; then
    DURA=$((RESP*60))
  fi
  RESP=`echo $DURA | sed 's/h//i'`
  if [ "$RESP" != "$DURA" ]; then
    DURA=$((RESP*3600))
  fi
  fi
fi

if [ "$ITERS" != "" -a "$RUN_CMDS" != "run_multi" ]; then
if [ "$SCRIPT" != "" -o "$ITERS" != "" ]; then
  if [ "$ITERS" != "" ]; then
  if [ "$SCRIPT" == "" -o "$ITERS" == "" ]; then
    echo "if you enter -s $SCRIPT or -I $ITERS then you must enter both options. Bye"
    exit 1
  fi
  if [ "$RUN_CMDS" != "run_multi" ]; then
    echo "Note that if you enter -s $SCRIPT and/or -I $ITERS the options have no effect unless you have -r run_cpu."
  fi
  fi
fi
fi
fi

if [ $VERBOSE -gt 0 ]; then
  echo "HOSTS= $HOSTS" | cut -c1-200
  printf "Using dyno tar.gz file= %s\n" $TAR_GZ
  printf "Using BMARK_ROOT= %s\n" $BMARK_ROOT
fi
#printf "Using HOSTS= %s\n" $HOSTS
NUM_HOST=-1
for i in $HOSTS; do
  NUM_HOST=$((NUM_HOST+1))
  if [ $VERBOSE -gt 0 ]; then
    echo "HOSTS $NUM_HOST $i"
  fi
done
if [ $VERBOSE -gt 0 ]; then
  printf "Using CFG_DIR %s\n" $CFG_DIR
  printf "Using PROJ_DIR %s\n" $PROJ_DIR
fi

if [ "$USERNM" == "" ]; then
  USERNM=$USERNM_DEF
fi

if [ "$RUN_CMDS" == "" ]; then
  print_help
  exit 1
fi

PING_WORK=
PING_FAIL=
SSH_WORK=
SSH_FAIL=

SSH_HOST=
SSH_CMD=
SSH_PFX=


ssh_cmd()
{
  if [ "$SSH_MODE" == "sudo" ]; then
    SSH_PFX="ssh -t "
    if [ "$USERNM" == "none" ]; then
      SSH_HOST=$1
    else
      SSH_HOST=$USERNM@$1
    fi
    local load_env=
    if [ "$3" != "" ]; then
       load_env="-l"
    fi
    SSH_CMD="sudo su $load_env -c \"$2\""
  else
    SSH_PFX="ssh -t "
    if [ "$1" == "127.0.0.1" ]; then
      SSH_CMD=$2
      SSH_PFX=
    else
    if [ "$USERNM" == "none" ]; then
      SSH_HOST=$1
    else
      SSH_HOST=$USERNM@$1
    fi
    #SSH_CMD="$2"
    local load_env=
    if [ "$3" != "" ]; then
       load_env="-l"
    fi
    #SSH_CMD="su $load_env -s /bin/bash -c \"$2\""  # works but get no ioctl msg
    SSH_CMD="/bin/bash -l -c \"$2\""
    # below works
    #SSH_HOST=root@$1
    #SSH_CMD="$2"
    fi
  fi
}

mk_run_fl()
{
  RUN_FL_CMD="$1"
  RUN_FL_BASE=$(basename "$RUN_FL_CMD")
  LOG_FL="${2}_${RUN_FL_BASE}.log"
}

HOST_NUM_LIST=
if [ "$HOST_NUM" != "" ]; then
  HOST_NUM_LIST=(`awk -v beg="0" -v end="$NUM_HOST" -v str="$HOST_NUM" '
     BEGIN{
        # handle 1 or 0-2 or 0,3 or 0,1-3,7
        # return array of value
        nc=split(str, carr, ",");
        mx=0;
        for (i=1; i <= nc; i++) {
          if (index(carr[i], "-") == 0) {
            varr[++mx] = carr[i];
          } else {
            nd=split(carr[i], ndarr, "-");
            nb = -1;
            ne = -1;
            if (nd == 2) { nb=ndarr[1]; ne =ndarr[2];}
            if (nd < 2) {
               if (substr(carr[i], 1, 1) == "-") {
                 nb = beg;
               }
               if (substr(carr[i], length(carr[i]),1) == "-") {
                 nb = end;
               }
            }
            if (nb == -1) { nb = beg;}
            if (ne == -1) { ne = end;}
            for (j=nb; j <= ne; j++) {
              varr[++mx] = j;
            }
          }
        }
        # get rid of dupes
        vmx = -1;
        for (i=1; i <= mx; i++) {
          varr[i] += 0;
          if (varr[i] < beg) { printf("dropping -N %s value from -N %s since < %d\n", varr[i], str, beg) > "/dev/stderr";  continue; }
          if (varr[i] > end) { printf("dropping -N %s value from -N %s since > %d\n", varr[i], str, end) > "/dev/stderr";  continue; }
          if (varr[i] < beg) { continue; }
          iarr[varr[i]] = 1;
          if (varr[i] > vmx) {
            vmx = varr[i];
          }
        }
        if (vmx == -1) {
           printf("didnt find valid system numbers for option \"-N %s\". Expected them to be between %s and %s. Bye\n", str, beg, end) > "/dev/stderr";
           printf("-1\n");
           exit 1;
        }
        lstr="";
        ostr="";
        for (i=0; i <= vmx; i++) {
          if (iarr[i] == 1) {
            ostr = ostr "" i "\n";
            lstr = lstr " " i;
          }
        }
        printf(ostr);
        printf("%s\n", lstr) > "/dev/stderr";
        exit 0;
     }'`)
     if [ "${HOST_NUM_LIST[0]}" == "-1" ]; then
        echo "didn't find valid system numbers in cmdline option -N $HOST_NUM. Bye" > /dev/stderr
        exit 1
     fi
  #echo "HOST_NUM_LIST= ${HOST_NUM_LIST[@]}"
  HOST_NUM_BEG=${HOST_NUM_LIST[0]}
  HOST_NUM_END=${HOST_NUM_LIST[${#HOST_NUM_LIST[@]}-1]}
  #echo "HOST_NUM_BEG= $HOST_NUM_BEG, HOST_NUM_END= $HOST_NUM_END"
fi

TOT_HOSTS=$NUM_HOST

if [ -e $SCR_DIR/60secs/gen_report.sh ]; then
  GEN_RPT=$SCR_DIR/60secs/gen_report.sh
else
  GEN_RPT=$SCR_DIR/gen_report.sh
fi
if [ -e $SCR_DIR/60secs/find_closest_run_cmd_match.sh ]; then
  FIND_CLOSEST=$SCR_DIR/60secs/find_closest_run_cmd_match.sh
else
  FIND_CLOSEST=$SCR_DIR/find_closest_run_cmd_match.sh
fi
if [ -e $SCR_DIR/60secs/fetch_output.sh ]; then
  FTCH_OUTPUT=$SCR_DIR/60secs/fetch_output.sh
else
  FTCH_OUTPUT=$SCR_DIR/fetch_output.sh
fi

if [ "$HOST_NUM" == "" ]; then
   HOST_NUM_BEG=0
   HOST_NUM_END=$TOT_HOSTS
fi
DO_OVER=1
CMD_ARR=()
if [ "$RUN_CMDS" == "scp_tar,untar" ]; then
  CMD_ARR=(scp_tar untar)
else
  if [ "$RUN_CMDS" == "fetch" ]; then
    CMD_ARR=(ftchp1 ftchp2 ftchp3 ftchp4 ftchp5 ftchp6 ftchp7 ftchp8 ftchp9)
  fi
  if [ "$RUN_CMDS" == "fetch_untar" ]; then
    CMD_ARR=(ftchp1 ftchp2 ftchp3 ftchp4 ftchp5 ftchp6 ftchp7 ftchp8 ftchp9 ftchpA)
  else
    CMD_ARR=($RUN_CMDS)
  fi
fi
SV_SSH_MODE=$SSH_MODE
SV_USERNM=$USERNM
SV_USERNM_IN=$USERNM_IN
echo "==== begin ====" > $RES
for RN_CM in ${CMD_ARR[@]}; do
  if [ "$RN_CM" == "" ]; then
    break
  fi
NUM_HOST=-1
for i in $HOSTS; do
  RUN_CMDS=$RN_CM
  NUM_HOST=$((NUM_HOST+1))
  if [ "$HOST_NUM" != "" ]; then
    if [ "$NUM_HOST" -lt "$HOST_NUM_BEG" ]; then
       continue
    fi
    if [ "$NUM_HOST" -gt "$HOST_NUM_END" ]; then
       continue
    fi
    got_it=0
    hl_end=$((${#HOST_NUM_LIST[@]}-1))
    for (( hl_i=0; hl_i <= $hl_end; hl_i++ )); do
       if [ "${HOST_NUM_LIST[$hl_i]}" == "$NUM_HOST" ]; then
         got_it=1
         break
       fi
    done
    if [ "$got_it" == "0" ]; then
       echo "skip host num $NUM_HOST, not in -N list"
       continue
    fi
    #echo "do host $NUM_HOST"
  fi
  if [ -e stop ]; then
    echo "quitting loop due presence of 'stop' file. You need to delete the file"
    exit 0
  fi
  echo ============== $i , host_num $NUM_HOST of $TOT_HOSTS, beg= $HOST_NUM_BEG end= $HOST_NUM_END , host_list= $USE_LIST ===================
  nm=$i
  USERNM=$SV_USERNM
  USERNM_IN=$SV_USERNM_IN
  SSH_MODE=$SV_SSH_MODE
  if [ "${#cfg_opts_arr[@]}" -gt "0" ]; then
    #echo "$0.$LINENO ${cfg_opts_arr[@]}"
    for ((i_coa=0; i_coa < ${#cfg_opts_arr[@]}; i_coa++)); do
      RESP=`echo "${cfg_opts_arr[$i_coa]}" | awk -v want="hst_beg" '/^alt_user: / { printf("%s\n", $2);exit(0);}'`
      if [ "$RESP" != "" ]; then
        hst_beg="$RESP"
      fi
      RESP=`echo "${cfg_opts_arr[$i_coa]}" | awk -v want="hst_usr" '/^alt_user: / { printf("%s\n", $3);exit(0);}'`
      if [ "$RESP" != "" ]; then
        hst_usr="$RESP"
      fi
      RESP=`echo "${cfg_opts_arr[$i_coa]}" | awk -v want="hst_ssh" '/^alt_user: / { printf("%s\n", $4);exit(0);}'`
      if [ "$RESP" != "" ]; then
        hst_ssh="$RESP"
      fi
    if [[ $nm =~ ^($hst_beg).* ]]; then
        USERNM=$hst_usr
        USERNM_IN=$hst_usr
        SSH_MODE=$hst_ssh
        #echo "$0.$LINENO set username= $USERNM"
        break
    fi
    done
    #echo "$0.$LINENO bye"
    #exit
  fi

  do_bkgrnd=0
  if [ $RUN_CMDS == "command" -o $RUN_CMDS == "pcmd" -o "$RUN_CMDS" == "pfetch_untar" -o "$RUN_CMDS" == "popt_${wxy_str}_info" -o "$RUN_CMDS" == "pssh_test" ]; then
    do_bkgrnd=1
  fi
  got_pcmd_or_pfetch=0
  if [ $RUN_CMDS == "pcmd" -o "$RUN_CMDS" == "pfetch_untar" -o "$RUN_CMDS" == "popt_${wxy_str}_info" -o "$RUN_CMDS" == "pssh_test" ]; then
    got_pcmd_or_pfetch=1
  fi
  if [ $BKGRND_TASKS_MAX -le 0 ]; then
    do_bkgrnd=0
  fi
  if [ "$nm" == "127.0.0.1" ]; then
    do_bkgrnd=0
  fi

  if [[ $RUN_CMDS == *"ping"* ]]; then
    echo ping -c -W 2 ${nm}
    if [ "$DRY_RUN" == "n" ]; then
         CMD="ping -c 1 -W 2 ${nm}"
         RESP=`$CMD`
         dyno_log $CMD
         echo $RESP
         if [[ $RESP == *" 0% packet loss"* ]]; then
            echo ping worked
            PING_WORK="$PING_WORK $nm"
         else
            echo ping failed
            PING_FAIL="$PING_FAIL $nm"
         fi
    fi
  fi
  if [ $RUN_CMDS == "ssh_test" ]; then
    #ssh_cmd $nm "uname -a;lsblk;fdisk -l" "-l"
    SSH_TIMEOUT=" -o ConnectTimeout=10 -o BatchMode=yes "
    ssh_cmd $nm "uname -a" "-l"
    echo ssh $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
         ssh $SSH_TIMEOUT $SSH_HOST "$SSH_CMD"
         dyno_log ssh $SSH_TIMEOUT $SSH_HOST "$SSH_CMD"
         RESP=`ssh $SSH_HOST "$SSH_CMD"`
         if [[ $RESP == *"Linux"* ]]; then
            echo ssh worked
            SSH_WORK="$SSH_WORK $nm"
         else
            echo ssh failed
            SSH_FAIL="$SSH_FAIL $nm"
         fi
    fi
  fi
  if [ "$RUN_CMDS" == "opt_${wxy_str}_info" ]; then
    echo "$0.$LINENO ${wxy_str} ${wxy_hs} $nm"
    if [ "$DRY_RUN" == "n" ]; then
         dyno_log ${wxy_str} ${wxy_hs} $nm
         #RESP=`${wxy_str} ${wxy_hs} $nm`
         #RESP_LNS=`echo "$RESP" | wc -l`
         #if [ $RESP_LNS -lt 3 ]; then
           RESP=`${wxy_str} ${wxy_hs} $nm`
         #fi
         if [ "$RPT_FILE" != "" -a "$DID_RPT_FILE_init" == "0" ]; then
           echo "" > $RPT_FILE
           DID_RPT_FILE_init=1
         fi
         if [ "$RPT_FILE" == "" ]; then
           echo "$RESP"
         else
           echo "$RESP" >> $RPT_FILE
         fi
    fi
  fi
  if [[ $RUN_CMDS == *"opt_reboot"* ]]; then
    echo "ipmi $nm chassis power reset"
    if [ "$DRY_RUN" == "n" ]; then
         dyno_log ipmi $nm chassis power reset
         RESP=`ipmi $nm chassis power reset`
         if [ "$RPT_FILE" != "" -a "$DID_RPT_FILE_init" == "0" ]; then
           echo "" > $RPT_FILE
           DID_RPT_FILE_init=1
         fi
         if [ "$RPT_FILE" == "" ]; then
           echo "$RESP"
         else
           echo "$RESP" >> $RPT_FILE
         fi
    fi
  fi
  if [[ $RUN_CMDS == *"nameserver_test"* ]]; then
    ssh_cmd $nm "ping -c 1 -W 2 google.com"  "-l"
    echo ssh $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
         ssh $SSH_HOST "$SSH_CMD"
         dyno_log ssh $SSH_HOST "$SSH_CMD"
         RESP=`ssh $SSH_HOST "$SSH_CMD"`
         if [[ $RESP == *" 0% packet loss"* ]]; then
            echo ping worked
            PING_WORK="$PING_WORK $nm"
         else
            echo ping failed
            PING_FAIL="$PING_FAIL $nm"
         fi
    fi
  fi
  if [[ $RUN_CMDS == *"shell"* ]]; then
    ssh_cmd $nm "bash"  "-l"
    echo $SSH_PFX $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
          if [ "$nm" == "127.0.0.1" ]; then
            $SSH_CMD
          else
            $SSH_PFX $SSH_HOST "$SSH_CMD"
          fi
        dyno_log $SSH_PFX $SSH_HOST "$SSH_CMD"
    fi
  fi
  if [[ $RUN_CMDS == *"screen"* ]]; then
    ssh_cmd $nm "screen -r"  "-l"
    echo $SSH_PFX $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
          if [ "$nm" == "127.0.0.1" ]; then
            $SSH_CMD
          else
            $SSH_PFX $SSH_HOST "$SSH_CMD"
          fi
        dyno_log $SSH_PFX $SSH_HOST "$SSH_CMD"
    fi
  fi
  GOT_DO_CMD=0
  SSH_TIMEOUT=
  if [[ $RUN_CMDS == *"command"* ]]; then
    SSH_TIMEOUT=" -o ConnectTimeout=10 -o BatchMode=yes "
    GOT_DO_CMD=1
  fi
  if [ $got_pcmd_or_pfetch == 1 ]; then
    if [ $VERBOSE -gt 0 ]; then
      echo "$0.$LINENO got pcmd $RUN_CMDS"
    fi
    if [ "$RUN_CMDS" == "pfetch_untar" ]; then
      COMMAND=`echo "$myInvocation" | sed 's/pfetch_untar/fetch_untar/'`
      echo "new cmd= \"$COMMAND\""
    fi
    if [ "$RUN_CMDS" == "pssh_test" ]; then
      COMMAND=`echo "$myInvocation" | sed 's/pssh_test/ssh_test/'`
      echo "new cmd= \"$COMMAND\""
    fi
    if [ "$RUN_CMDS" == "popt_${wxy_str}_info" ]; then
      if [ $VERBOSE -gt 0 ]; then
        echo "$0.$LINENO $RUN_CMDS"
      fi
      if [ "$DRY_RUN" == "n" ]; then
         dyno_log ${wxy_str} ${wxy_hs} $nm
         if [ "$RPT_FILE" != "" -a "$DID_RPT_FILE_init" == "0" ]; then
           rm $RPT_FILE
           DID_RPT_FILE_init=1
         fi
         COMMAND="${wxy_str} ${wxy_hs} $nm"
      fi
    fi
    SSH_TIMEOUT=" -o ConnectTimeout=10 -o BatchMode=yes "
    if [ ! -e $WORK_DIR ]; then
       mkdir $WORK_DIR
    fi
    if [ "$DID_CLEAR_WORK_DIR" == "" -a "$WORK_DIR" != "" ]; then
      rm $WORK_DIR/cmd_*.txt
      DID_CLEAR_WORK_DIR=1
    fi
    GOT_DO_CMD=2
  fi
  if [ "$GOT_DO_CMD" == "1" -o "$GOT_DO_CMD" == "2" ]; then
    if [ $VERBOSE -gt 0 ]; then
     echo "$0.$LINENO got pcmd"
    fi
    if [ "$COMMAND" == "" ]; then
      echo "if you use '-r command' or '-r pcmd' then you have to add '-C cmd_to_be_run' like '-C \"ls /root\"'"
      exit 1
    fi
    CMD="$COMMAND"
    if [ "$RUN_CMDS" == "pfetch_untar" ]; then
      CMD="$COMMAND -N $NUM_HOST -m 0"
    fi
    if [ "$RUN_CMDS" == "pssh_test" ]; then
      CMD="$COMMAND -N $NUM_HOST -m 0"
    fi
    if [ $VERBOSE -gt 0 ]; then
      echo "$0.$LINENO cmd= $CMD"
    fi
    if [ "${#HOST_ARR[@]}" -gt 0 ]; then
    re='(.*)(%HOST_ARR\{.\}%)(.*)'
    for ((ki=0; ki < ${#HOST_ARR[@]}; ki++)); do
      HOST_ARR_ARGS=(`echo "${HOST_ARR[$ki]}" | awk -v str_in="$str" -v nm="$nm" 'BEGIN{;} {if ($1 == nm) {printf("%s\n", $0);}}'`)
      if [ "${#HOST_ARR_ARGS[@]}" -gt "0" ]; then
        break
      fi
    done
    while [[ $CMD =~ $re ]]; do
      #echo "0= ${BASH_REMATCH[0]}"
      #echo "1= ${BASH_REMATCH[1]}"
      str_in="${BASH_REMATCH[2]}"
      fld_idx=`awk -v str_in="$str_in" 'BEGIN{pos=index(str_in, "{");idx=substr(str_in, pos+1)+0;printf("%s\n",idx);;exit(0);}'`
      str_out="${HOST_ARR_ARGS[$fld_idx]}"
      #echo "3= ${BASH_REMATCH[3]}"
      #echo "4= ${BASH_REMATCH[4]}"
      CMD=${BASH_REMATCH[1]}$str_out${BASH_REMATCH[3]}
      #break
    done
    fi
    #echo "$0.$LINENO bye, cmd = $CMD , orig= $COMMAND"
    #exit 1
    re='(.*)%HOST%(.*)'
    while [[ $CMD =~ $re ]]; do
      CMD=${BASH_REMATCH[1]}$nm${BASH_REMATCH[2]}
    done
    re='(.*)%HOST_NUM%(.*)'
    while [[ $CMD =~ $re ]]; do
      CMD=${BASH_REMATCH[1]}$NUM_HOST${BASH_REMATCH[2]}
    done
    ssh_cmd $nm "$CMD"  "-l"
    if [ "$DRY_RUN" == "n" ]; then
        if [ $BKGRND_TASKS_CUR -ge $BKGRND_TASKS_MAX ]; then
          wait
          BKGRND_TASKS_CUR=0
        fi
        if [ "$RUN_CMDS" == "pfetch_untar" ]; then
          OUT_FILE=`printf "$WORK_DIR/$WORK_TMP" $NUM_HOST`
          if [ "$do_bkgrnd" == "1" ]; then
            $CMD &> $OUT_FILE &
            BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
          else
            $CMD &> $OUT_FILE
          fi
          dyno_log $SSH_HOST "$CMD"
        elif [ "$RUN_CMDS" == "pssh_test" ]; then
          OUT_FILE=`printf "$WORK_DIR/$WORK_TMP" $NUM_HOST`
          if [ "$do_bkgrnd" == "1" ]; then
            $CMD &> $OUT_FILE &
            BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
          else
            $CMD &> $OUT_FILE
          fi
          dyno_log $SSH_HOST "$CMD"
        elif [ "$RUN_CMDS" == "popt_${wxy_str}_info" ]; then
          if [ $VERBOSE -gt 0 ]; then
            echo "$0.$LINENO hi"
          fi
          if [ "$RPT_FILE" != "" ]; then
             OUT_FILE=$RPT_FILE
          else
             OUT_FILE=`printf "$WORK_DIR/$WORK_TMP" $NUM_HOST`
          fi
          if [ "$do_bkgrnd" == "1" ]; then
            {(${wxy_str} ${wxy_hs} $nm | awk '{sv[++mx]=$0;if($1=="UUID"){uuid=$2;}}END{ cmd="metalcli asset get " uuid " --format={{.Sku}}"; while((cmd | getline metalout[++mx2]) > 0); close(cmd);  for(i=1;i <= mx; i++) {printf("%s\n", sv[i]);}  printf("SKU:  %s\n", metalout[1]); printf("-------------------\n");}' >> $OUT_FILE)  &}
            BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
          else
            #echo $CMD &>> $OUT_FILE
            (${wxy_str} ${wxy_hs} $nm | awk '{sv[++mx]=$0;if($1=="UUID"){uuid=$2;}}END{ cmd="metalcli asset get " uuid " --format={{.Sku}}"; while((cmd | getline metalout[++mx2]) > 0); close(cmd);  for(i=1;i <= mx; i++) {printf("%s\n", sv[i]);}  printf("SKU:  %s\n", metalout[1]);printf("-------------------\n");}' >> $OUT_FILE)
          fi
          dyno_log $SSH_HOST "$CMD"
        else
         echo $SSH_PFX $SSH_HOST "$SSH_CMD"
         if [[ "$SSH_CMD" == *"nohup "* ]]; then
          ADD_T=" -n "
         fi
         ADD_T="$ADD_T $SSH_TIMEOUT "
         if [ "$do_bkgrnd" == "1" ]; then
          if [ "$GOT_DO_CMD" == "2" ]; then
            OUT_FILE=`printf "$WORK_DIR/$WORK_TMP" $NUM_HOST`
            $SSH_PFX $ADD_T $SSH_HOST "$SSH_CMD" &> $OUT_FILE &
          else
            $SSH_PFX $ADD_T $SSH_HOST "$SSH_CMD" &
          fi
          BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
         else
          #$SSH_PFX $SSH_HOST "$SSH_CMD"
          if [ "$nm" == "127.0.0.1" ]; then
            $SSH_CMD
          else
            $SSH_PFX $ADD_T $SSH_HOST "$SSH_CMD"
          fi
         fi
         dyno_log $SSH_PFX $ADD_T $SSH_HOST "$SSH_CMD"
        fi
    fi
  fi
  if [[ $RUN_CMDS == *"lcl_cmd"* ]]; then
    if [ "$COMMAND" == "" ]; then
      echo "if you use '-r lcl_cmd' then you have to add '-C cmd_to_be_run' like '-C \"ls /root\"'"
      exit 1
    fi
    CMD=$COMMAND
    re='(.*)%HOST%(.*)'
    while [[ $CMD =~ $re ]]; do
      CMD=${BASH_REMATCH[1]}$nm${BASH_REMATCH[2]}
    done
    RFILE=$RPT_FILE
    if [ "$RFILE" != "" ]; then
    while [[ $RFILE =~ $re ]]; do
      RFILE=${BASH_REMATCH[1]}$nm${BASH_REMATCH[2]}
    done
    fi
    if [ "$DRY_RUN" == "n" ]; then
      if [ "$RFILE" != "" ]; then
        echo "$CMD > $RFILE"
        $CMD > $RFILE
        dyno_log "$CMD > $RFILE"
      else
        echo "$CMD"
        $CMD
        dyno_log "$CMD"
      fi
    fi
  fi
  if [[ $RUN_CMDS == *"scp_tar"* ]]; then
    do_bkgrnd=0
    if [ $RUN_CMDS == "scp_tar" ]; then
      do_bkgrnd=1
    fi
  if [ $BKGRND_TASKS_MAX -le 0 ]; then
    do_bkgrnd=0
  fi
  if [ "$nm" == "127.0.0.1" ]; then
    do_bkgrnd=0
  fi
    ssh_cmd $nm "$TAR_GZ ${SCP_USERNM}${nm}:$BMARK_ROOT/"
    if [ "$USERNM_IN" == "none" ]; then
      SCP_USERNM=
      SSH_HOST=$nm
      SSH_CMD="/bin/bash -l -c \"$TAR_GZ $tm:$BMARK_ROOT\""
      echo "$0.$LINENO scp_usernm= $SCP_USERNM"
    else
      SCP_USERNM="$USERNM@"
    fi
    echo $0.$LINENO scp $nm  $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
         #scp $SSH_HOST "$SSH_CMD"
         if [ $BKGRND_TASKS_CUR -ge $BKGRND_TASKS_MAX ]; then
           wait
           BKGRND_TASKS_CUR=0
         fi
         if [ "$nm" == "127.0.0.1" ]; then
           cp $TAR_GZ $BMARK_ROOT/
         else
         if [ "$SSH_MODE" == "sudo" ]; then
           echo $0.$LINENO  scp $TAR_GZ ${SSH_HOST}:
                if [ "$do_bkgrnd" == "1" ]; then
                  scp $TAR_GZ ${SSH_HOST}:${BMARK_ROOT} &
                  BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
                else
                  scp $TAR_GZ ${SSH_HOST}:${BMARK_ROOT}
                fi
           dyno_log scp $TAR_GZ ${SSH_HOST}:$BMARK_ROOT
           filenm=$(basename $TAR_GZ)
           echo "filenm= $filenm"
           #ssh_cmd $nm "mv $filenm $BMARK_ROOT/"
           #echo ssh $SSH_HOST "$SSH_CMD"
           #     ssh $SSH_HOST "$SSH_CMD"
           dyno_log ssh $SSH_HOST "$SSH_CMD"
         else
           if [ "$do_bkgrnd" == "1" ]; then
             echo $0.$LINENO scp $TAR_GZ ${SCP_USERNM}${nm}:$BMARK_ROOT/
             scp $TAR_GZ ${SCP_USERNM}${nm}:$BMARK_ROOT/ &
             BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
           else
             if [ "$nm" == "127.0.0.1" ]; then
               scp $TAR_GZ $BMARK_ROOT/
             else
               echo $0.$LINENO scp $TAR_GZ ${SCP_USERNM}${nm}:$BMARK_ROOT/
               scp $TAR_GZ ${SCP_USERNM}${nm}:$BMARK_ROOT/
             fi
           fi
           dyno_log scp $TAR_GZ ${SCP_USERNM}${nm}:$BMARK_ROOT/
         fi
         fi
    fi
  fi
  do_untar=0
  if [[ $RUN_CMDS == *"^untar"* ]]; then
    do_untar=1
  fi
  do_bkgrnd=0
  if [ "$RUN_CMDS" == "untar" ]; then
    do_untar=1
    do_bkgrnd=1
  fi
  if [ "$RUN_CMDS" == "setup" ]; then
    do_bkgrnd=1
  fi
  if [ "$RUN_CMDS" == "run_cmd" ]; then
    do_bkgrnd=1
  fi
  if [ $BKGRND_TASKS_MAX -le 0 ]; then
    do_bkgrnd=0
  fi
  if [[ $RUN_CMDS == *",untar"* ]]; then
    do_untar=1
  fi
  if [ "$nm" == "127.0.0.1" ]; then
    do_bkgrnd=0
  fi
  if [ "$do_untar" == "1" ]; then
    #echo ssh root@${nm} "cd $BMARK_ROOT/; tar xzvf $TAR_GZ"
    filenm=$(basename $TAR_GZ)
    TAR_RT=
    if [ "$USERNM" == "none" ]; then
      TAR_RT=$BMARK_ROOT/
    fi
    ssh_cmd $nm "tar xzf ${TAR_RT}$filenm -C $BMARK_ROOT"  "-l"
    echo $0.$LINENO ssh $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
         if [ $BKGRND_TASKS_CUR -ge $BKGRND_TASKS_MAX ]; then
           wait
           BKGRND_TASKS_CUR=0
         fi
         if [ "$do_bkgrnd" == "1" ]; then
           ssh $SSH_HOST "$SSH_CMD" &
           BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
         else
          # ssh $SSH_HOST "$SSH_CMD"
          echo "note that prev ver of untar \"$SSH_CMD\" cmd didn't have ssh -t" > /dev/stderr
          if [ "$nm" == "127.0.0.1" ]; then
            echo "untar cmd: $SSH_CMD"
            $SSH_CMD
          else
            $SSH_PFX $SSH_HOST "$SSH_CMD"
          fi
         fi
         dyno_log ssh $SSH_HOST "$SSH_CMD"
         #ssh root@${nm} "cd $BMARK_ROOT/; tar xzvf $TAR_GZ"
    fi
  fi
  if [[ $RUN_CMDS == *"opt_install_jdk8"* ]]; then
    ssh_cmd $nm "cd /opt; tar xzvf $BMARK_ROOT/${BMARK_SUBDIR}/extras/OpenJDK8U-jdk_x64_linux_hotspot_8u232b09.tar.gz; cp $BMARK_ROOT/${BMARK_SUBDIR}/extras/jdk8.sh /etc/profile.d/; rm /etc/profile.d/jdk11.sh"  "-l"
    echo ssh $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
         #ssh $SSH_HOST "$SSH_CMD"
          echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
          if [ "$nm" == "127.0.0.1" ]; then
            cd /opt; tar xzvf $BMARK_ROOT/${BMARK_SUBDIR}/extras/OpenJDK8U-jdk_x64_linux_hotspot_8u232b09.tar.gz; cp $BMARK_ROOT/${BMARK_SUBDIR}/extras/jdk8.sh /etc/profile.d/; rm /etc/profile.d/jdk11.sh
          else
            $SSH_PFX $SSH_HOST "$SSH_CMD"
          fi
         dyno_log ssh $SSH_HOST "$SSH_CMD"
    fi
  fi
  if [[ $RUN_CMDS == *"opt_install_jdk11"* ]]; then
    ssh_cmd $nm "cd /opt; tar xzvf $BMARK_ROOT/${BMARK_SUBDIR}/extras/OpenJDK11U-jdk_x64_linux_hotspot_11.0.5_10.tar.gz; cp $BMARK_ROOT/${BMARK_SUBDIR}/extras/jdk11.sh /etc/profile.d/; rm /etc/profile.d/jdk8.sh"  "-l"
    echo ssh $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
         #ssh $SSH_HOST "$SSH_CMD"
          echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
          if [ "$nm" == "127.0.0.1" ]; then
            #$SSH_CMD
            cd /opt; tar xzvf $BMARK_ROOT/${BMARK_SUBDIR}/extras/OpenJDK11U-jdk_x64_linux_hotspot_11.0.5_10.tar.gz; cp $BMARK_ROOT/${BMARK_SUBDIR}/extras/jdk11.sh /etc/profile.d/; rm /etc/profile.d/jdk8.sh
          else
            $SSH_PFX $SSH_HOST "$SSH_CMD"
          fi
         dyno_log ssh $SSH_HOST "$SSH_CMD"
    fi
  fi
  if [[ $RUN_CMDS == *"setup"* ]]; then
    #echo ssh root@${nm} "cd $BMARK_ROOT/${BMARK_SUBDIR}; ./setup.sh"
    SET_BM=
    if [ $DID_bmark_root -eq 1 ]; then
      SET_BM="export DYNO_ROOT=$BMARK_ROOT; "
      echo "set_bm= $SET_BM"
    fi
    ssh_cmd $nm "${SET_BM}cd $BMARK_ROOT/${BMARK_SUBDIR}; ./setup.sh"  "-l"
    #exit
    echo $SSH_PFX $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
       echo $SSH_PFX $SSH_HOST "$SSH_CMD"
           # $SSH_PFX  $SSH_HOST "$SSH_CMD"
          echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
          if [ "$nm" == "127.0.0.1" ]; then
            #$SSH_CMD
            ${SET_BM}; cd $BMARK_ROOT/${BMARK_SUBDIR}; ./setup.sh
          else
                if [ "$do_bkgrnd" == "1" ]; then
                  $SSH_PFX $SSH_HOST "$SSH_CMD" &
                  BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
                else
                  $SSH_PFX $SSH_HOST "$SSH_CMD"
                fi
          fi
            dyno_log $SSH_PFX $SSH_HOST "$SSH_CMD"
         #ssh root@${nm} "cd $BMARK_ROOT/${BMARK_SUBDIR}; ./setup.sh"
    fi
  fi
  if [ "$CFG_DIR" == "" ]; then
    CFG_DIR="$BMARK_ROOT/AUTOGEN_config_UNDEFINED"
  fi
  if [[ $RUN_CMDS == *"config"* ]]; then
    #echo ssh root@${nm} "cd $BMARK_ROOT/; ./${BMARK_SUBDIR}/pre_DynoConfig_rm_cfg_files.sh -c $CFG_DIR"
    #echo ssh root@${nm} "cd $BMARK_ROOT/; lsblk; ./${BMARK_SUBDIR}/DynoConfig -user -fiobs 4k,1m"
    #MYCMD="cd \"$BMARK_ROOT\"; ./${BMARK_SUBDIR}/pre_DynoConfig_rm_cfg_files.sh -c $CFG_DIR"
    ssh_cmd $nm "cd $BMARK_ROOT; ./${BMARK_SUBDIR}/pre_DynoConfig_rm_cfg_files.sh -c $CFG_DIR"  "-l"
    echo $SSH_PFX $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
          # $SSH_PFX $SSH_HOST "$SSH_CMD"
          if [ "$nm" == "127.0.0.1" ]; then
            #$MYCMD
            cd $BMARK_ROOT; ./${BMARK_SUBDIR}/pre_DynoConfig_rm_cfg_files.sh -c $CFG_DIR
          else
            $SSH_PFX $SSH_HOST "$SSH_CMD"
          fi
         dyno_log $SSH_PFX $SSH_HOST "$SSH_CMD"
    fi
    #ssh_cmd $nm "cd $BMARK_ROOT/; lsblk; ./${BMARK_SUBDIR}/DynoConfig -user -fiobs 4k,1m -drivemin $DISK_MIN_SZ_BYTES"  "-l"
    ssh_cmd $nm "cd $BMARK_ROOT; lsblk; ./${BMARK_SUBDIR}/DynoConfig -user -fiobs 4k,1m "  "-l"
    echo ssh $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
         echo "=========== run config on $nm ==============="
          # $SSH_PFX $SSH_HOST "$SSH_CMD"
          if [ "$nm" == "127.0.0.1" ]; then
            #$SSH_CMD
            cd $BMARK_ROOT; lsblk; ./${BMARK_SUBDIR}/DynoConfig -user -fiobs 4k,1m
          else
            $SSH_PFX $SSH_HOST "$SSH_CMD"
          fi
         dyno_log $SSH_PFX $SSH_HOST "$SSH_CMD"
    fi
  fi
  if [[ $RUN_CMDS == *"post"* ]]; then
    #echo ssh root@${nm} "cd $BMARK_ROOT/; ${BMARK_SUBDIR}/post_DynoConfig_fixup.sh -c ./AUTOGEN_config_UNDEFINED"
    ssh_cmd $nm "cd $BMARK_ROOT/; ${BMARK_SUBDIR}/post_DynoConfig_fixup.sh -c $CFG_DIR"  "-l"
    echo ssh $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
         #ssh root@${nm} "cd $BMARK_ROOT/; ${BMARK_SUBDIR}/post_DynoConfig_fixup.sh -c ./AUTOGEN_config_UNDEFINED"
          echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
          #ssh $SSH_HOST "$SSH_CMD"
          if [ "$nm" == "127.0.0.1" ]; then
            #$SSH_CMD
            cd $BMARK_ROOT/; ${BMARK_SUBDIR}/post_DynoConfig_fixup.sh -c $CFG_DIR
          else
            $SSH_PFX $SSH_HOST "$SSH_CMD"
          fi
         dyno_log ssh $SSH_HOST "$SSH_CMD"
    fi
  fi
  if [[ $RUN_CMDS == *"free_up_disk"* ]]; then
    #echo ssh root@${nm} "cd $BMARK_ROOT/; ${BMARK_SUBDIR}/post_DynoConfig_fixup.sh -c ./AUTOGEN_config_UNDEFINED"
    ssh_cmd $nm "cd $BMARK_ROOT/; rm ${BMARK_SUBDIR}*.tar.gz; rm uber*.deb; rm ${BMARK_SUBDIR}/specint/cpu2017.tar.gz"  "-l"
    echo ssh $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
                  ssh $SSH_HOST "$SSH_CMD"
         dyno_log ssh $SSH_HOST "$SSH_CMD"
    fi
  fi
  LOG_TS=`date "+%Y%m%d_%H%M%S"`
  LOG_FL_PFX="bmark_${LOG_TS}"
  #echo "LOG_TS= $LOG_TS, LOG_FL_PFX= $LOG_FL_PFX"

  NW_PROJ=$PROJ_DIR
  re='(.*)%HOST%(.*)'
  while [[ $NW_PROJ =~ $re ]]; do
    NW_PROJ=${BASH_REMATCH[1]}$nm${BASH_REMATCH[2]}
  done
    if [ "${#HOST_ARR[@]}" -gt 0 ]; then
    re='(.*)(%HOST_ARR\{.\}%)(.*)'
    for ((ki=0; ki < ${#HOST_ARR[@]}; ki++)); do
      HOST_ARR_ARGS=(`echo "${HOST_ARR[$ki]}" | awk -v str_in="$str" -v nm="$nm" 'BEGIN{;} {if ($1 == nm) {printf("%s\n", $0);}}'`)
      if [ "${#HOST_ARR_ARGS[@]}" -gt "0" ]; then
        break
      fi
    done
    while [[ $NW_PROJ =~ $re ]]; do
      #echo "0= ${BASH_REMATCH[0]}"
      #echo "1= ${BASH_REMATCH[1]}"
      str_in="${BASH_REMATCH[2]}"
      fld_idx=`awk -v str_in="$str_in" 'BEGIN{pos=index(str_in, "{");idx=substr(str_in, pos+1)+0;printf("%s\n",idx);;exit(0);}'`
      str_out="${HOST_ARR_ARGS[$fld_idx]}"
      #echo "3= ${BASH_REMATCH[3]}"
      #echo "4= ${BASH_REMATCH[4]}"
      NW_PROJ=${BASH_REMATCH[1]}$str_out${BASH_REMATCH[3]}
      #break
    done
    fi

  if [[ "$RUN_CMDS" == *"run_"* ]]; then
    if [ "$PROJ_DIR" == "" ]; then
       echo "$0.$LINENO for the run_* cmds you have to enter '-p proj_dir'. Bye"
       exit 1
    fi
  fi
  if [[ $RUN_CMDS == *"run_both"* ]]; then
    ADD_T=" -n "
    RUN_FL="./${BMARK_SUBDIR}/run_compute_and_disk.sh"
    mk_run_fl "$RUN_FL" "$LOG_FL_PFX"

    ssh_cmd $nm "cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR &> ${LOG_FL} &"  "-l"
    echo ssh $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
          # ssh $SSH_HOST "$SSH_CMD"
          echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
          if [ "$nm" == "127.0.0.1" ]; then
            #$SSH_CMD
            cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR &> ${LOG_FL} &
          else
            $SSH_PFX $ADD_T $SSH_HOST "$SSH_CMD"
          fi
         dyno_log RUN ssh $SSH_HOST "$SSH_CMD"
    fi
  else
    ADD_T=" -t "
    if [[ "$RUN_CMDS" == *"run_"* ]]; then
       ADD_T=" -n "
    fi
    DR_O=
    if [ "$DURA" != "" ]; then
      DR_O=" -d $DURA -s $SCRIPT "
    fi
    if [ "$ITERS" != "" ]; then
      DR_O=" -n $ITERS -s $SCRIPT "
    fi
    if [[ $RUN_CMDS == *"run_multi"* ]]; then
      RUN_FL="./${BMARK_SUBDIR}/run_multi.sh"
      mk_run_fl "$RUN_FL" "$LOG_FL_PFX"
      ssh_cmd $nm "cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $DR_O $QUIT_STR &> ${LOG_FL} &"  "-l"
      echo ssh $SSH_HOST "$SSH_CMD"
      if [ "$DRY_RUN" == "n" ]; then
          # ssh $SSH_HOST "$SSH_CMD"
          echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
          if [ "$nm" == "127.0.0.1" ]; then
            #$SSH_CMD
            cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $DR_O $QUIT_STR &> ${LOG_FL} &
          else
            $SSH_PFX $ADD_T $SSH_HOST "$SSH_CMD"
          fi
         dyno_log RUN ssh $SSH_HOST "$SSH_CMD"
      fi
    fi
    if [[ $RUN_CMDS == *"run_cpu"* ]]; then
      RUN_FL="./${BMARK_SUBDIR}/run_compute.sh"
      mk_run_fl "$RUN_FL" "$LOG_FL_PFX"
      ssh_cmd $nm "cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $DR_O $QUIT_STR &> ${LOG_FL} &"  "-l"
      echo ssh $SSH_HOST "$SSH_CMD"
      if [ "$DRY_RUN" == "n" ]; then
          # ssh $SSH_HOST "$SSH_CMD"
          echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
          if [ "$nm" == "127.0.0.1" ]; then
            #$SSH_CMD
            cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $DR_O $QUIT_STR &> ${LOG_FL} &
          else
            $SSH_PFX  $ADD_T $SSH_HOST "$SSH_CMD"
          fi
         dyno_log RUN ssh $SSH_HOST "$SSH_CMD"
      fi
    else
      if [[ $RUN_CMDS == *"run_fio"* ]]; then
        RUN_FL="./${BMARK_SUBDIR}/run_fio.sh"
        mk_run_fl "$RUN_FL" "$LOG_FL_PFX"
        ssh_cmd $nm "cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR &> ${LOG_FL} &"  "-l"
        echo ssh $SSH_HOST "$SSH_CMD"
        if [ "$DRY_RUN" == "n" ]; then
          # ssh $SSH_HOST "$SSH_CMD"
          echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
          if [ "$nm" == "127.0.0.1" ]; then
            # $SSH_CMD
            cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR &> ${LOG_FL} &
          else
            $SSH_PFX  $ADD_T $SSH_HOST "$SSH_CMD"
          fi
         dyno_log RUN ssh $SSH_HOST "$SSH_CMD"
        fi
      fi
      if [[ $RUN_CMDS == *"run_disk"* ]]; then
        RUN_FL="./${BMARK_SUBDIR}/run_disk.sh"
        mk_run_fl "$RUN_FL" "$LOG_FL_PFX"
        ssh_cmd $nm "cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ  $QUIT_STR &> ${LOG_FL} &"  "-l"
        echo ssh $SSH_HOST "$SSH_CMD"
        if [ "$DRY_RUN" == "n" ]; then
             #ssh root@${nm} "cd $BMARK_ROOT; nohup ./${BMARK_SUBDIR}/run_disk.sh -c $CFG_DIR -p $NW_PROJ &> ${LOG_FL} &"
          # ssh $SSH_HOST "$SSH_CMD"
          echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
          if [ "$nm" == "127.0.0.1" ]; then
            #$SSH_CMD
            cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ  $QUIT_STR &> ${LOG_FL} &
          else
            $SSH_PFX  $ADD_T $SSH_HOST "$SSH_CMD"
          fi
         dyno_log RUN ssh $SSH_HOST "$SSH_CMD"
        fi
      else
        if [[ $RUN_CMDS == *"run_custom"* ]]; then
          SCRIPT_OPT=
          if [ "$SCRIPT" != "" ]; then
            SCRIPT_OPT=" -s $SCRIPT "
          fi
          RUN_FL="./${BMARK_SUBDIR}/run_custom.sh"
          mk_run_fl "$RUN_FL" "$LOG_FL_PFX"
          ssh_cmd $nm "cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $DR_O $QUIT_STR $SCRIPT_OPT &> ${LOG_FL} &"  "-l"
          echo ssh $SSH_HOST "$SSH_CMD"
          if [ "$DRY_RUN" == "n" ]; then
          #              ssh $SSH_HOST "$SSH_CMD"
          echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
          if [ "$nm" == "127.0.0.1" ]; then
            # $SSH_CMD
            cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $DR_O $QUIT_STR $SCRIPT_OPT &> ${LOG_FL} &
          else
            $SSH_PFX  $ADD_T $SSH_HOST "$SSH_CMD"
          fi
          dyno_log RUN ssh $SSH_HOST "$SSH_CMD"
          fi
        fi
        if [[ $RUN_CMDS == *"run_cmd"* ]]; then
         if [ "$WATCH_IN" == "" ]; then
            WATCH_IN="null"
         else
            WATCH_IN="$(printf '%q' "$WATCH_IN")"
              #"$((($#)) && printf ' %q' "$@")"
         fi
         if [ "$COMMAND" == "" ]; then
           echo "if you use '-r run_cmd' then you have to add '-C cmd_to_be_run' like '-C \"run_60secs.sh\"'"
           exit 1
         fi
          RUN_FL="./${BMARK_SUBDIR}/$COMMAND"
          mk_run_fl "run_cmd" "$LOG_FL_PFX"
          ssh_cmd $nm "cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR -W $WATCH_IN &> ${LOG_FL} &"  "-l"
          echo ssh $SSH_HOST "$SSH_CMD"
          if [ "$DRY_RUN" == "n" ]; then
              if [ "$do_bkgrnd" == "1" ]; then
                if [ $BKGRND_TASKS_CUR -ge $BKGRND_TASKS_MAX ]; then
                  wait
                  BKGRND_TASKS_CUR=0
                fi
                ssh $SSH_HOST "$SSH_CMD" &
                BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
              else
                #      ssh $SSH_HOST "$SSH_CMD"
                echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
                if [ "$nm" == "127.0.0.1" ]; then
                  #$SSH_CMD
                  cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR -W $WATCH_IN &> ${LOG_FL} &
                else
                  $SSH_PFX  $ADD_T $SSH_HOST "$SSH_CMD"
                fi
              fi
              #          ssh $SSH_HOST "$SSH_CMD"
               dyno_log RUN ssh $SSH_HOST "$SSH_CMD"
          fi
        fi
        if [[ $RUN_CMDS == *"run_sysinfo"* ]]; then
          RUN_FL="$BMARK_ROOT/${BMARK_SUBDIR}/run_sysinfo.sh"
          mk_run_fl "$RUN_FL" "$LOG_FL_PFX"
          #ssh_cmd $nm "cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR &> ${LOG_FL} &" "-l"
          #( ( command ) & )
          ssh_cmd $nm "cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR &> ${LOG_FL} &" "-l"
          echo ssh $SSH_HOST "$SSH_CMD"
          if [ "$DRY_RUN" == "n" ]; then
             # ssh $SSH_HOST "$SSH_CMD"
             echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
             if [ "$nm" == "127.0.0.1" ]; then
               #$SSH_CMD
               cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR &> ${LOG_FL} &
             else
               $SSH_PFX  $ADD_T $SSH_HOST "$SSH_CMD"
             fi
             dyno_log RUN ssh $SSH_HOST "$SSH_CMD"
          fi
        fi
        if [[ $RUN_CMDS == *"run_specjbb"* ]]; then
          RUN_FL="./${BMARK_SUBDIR}/run_specjbb.sh"
          mk_run_fl "$RUN_FL" "$LOG_FL_PFX"
          OPT_S=
          if [ "$SCRIPT" != "" ]; then
            OPT_S=" -s $SCRIPT"
          fi
          if [ "$ITERS" != "" ]; then
            OPT_S=" $OPT_S -n $ITERS "
          fi
          ssh_cmd $nm "cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR $OPT_S &> ${LOG_FL} &"  "-l"
          echo ssh $SSH_HOST "$SSH_CMD"
          if [ "$DRY_RUN" == "n" ]; then
             #           ssh $SSH_HOST "$SSH_CMD"
             echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
             if [ "$nm" == "127.0.0.1" ]; then
               #$SSH_CMD
               cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR $OPT_S &> ${LOG_FL} &
             else
               $SSH_PFX  $ADD_T $SSH_HOST "$SSH_CMD"
             fi
             dyno_log RUN ssh $SSH_HOST "$SSH_CMD"
          fi
        fi
        if [[ $RUN_CMDS == *"run_specint"* ]]; then
          RUN_FL="./${BMARK_SUBDIR}/run_specint.sh"
          mk_run_fl "$RUN_FL" "$LOG_FL_PFX"
          ssh_cmd $nm "cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR &> ${LOG_FL} &"  "-l"
          echo ssh $SSH_HOST "$SSH_CMD"
          if [ "$DRY_RUN" == "n" ]; then
             # ssh $SSH_HOST "$SSH_CMD"
             echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
             if [ "$nm" == "127.0.0.1" ]; then
               #$SSH_CMD
               cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR &> ${LOG_FL} &
             else
               $SSH_PFX  $ADD_T $SSH_HOST "$SSH_CMD"
             fi
             dyno_log RUN ssh $SSH_HOST "$SSH_CMD"
          fi
        fi
        if [[ $RUN_CMDS == *"run_stream"* ]]; then
          RUN_FL="./${BMARK_SUBDIR}/run_stream.sh"
          mk_run_fl "$RUN_FL" "$LOG_FL_PFX"
          ssh_cmd $nm "cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR &> ${LOG_FL} &"  "-l"
          echo ssh $SSH_HOST "$SSH_CMD"
          if [ "$DRY_RUN" == "n" ]; then
             # ssh $SSH_HOST "$SSH_CMD"
             echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
             if [ "$nm" == "127.0.0.1" ]; then
               #$SSH_CMD
               cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR &> ${LOG_FL} &
             else
               $SSH_PFX  $ADD_T $SSH_HOST "$SSH_CMD"
             fi
             dyno_log RUN ssh $SSH_HOST "$SSH_CMD"
          fi
        fi
        if [[ $RUN_CMDS == *"run_ncu"* ]]; then
          RUN_FL="./${BMARK_SUBDIR}/run_ncu.sh"
          mk_run_fl "$RUN_FL" "$LOG_FL_PFX"
          ssh_cmd $nm "cd $BMARK_ROOT; nohup $RUN_FL -p $NW_PROJ/ncu_run &> ${LOG_FL} &"  "-l"
          echo ssh $SSH_HOST "$SSH_CMD"
          if [ "$DRY_RUN" == "n" ]; then
             # ssh $SSH_HOST "$SSH_CMD"
             echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
             if [ "$nm" == "127.0.0.1" ]; then
               #$SSH_CMD
               cd $BMARK_ROOT; nohup $RUN_FL -p $NW_PROJ/run &> ${LOG_FL} &
             else
               $SSH_PFX  $ADD_T $SSH_HOST "$SSH_CMD"
             fi
             dyno_log RUN ssh $SSH_HOST "$SSH_CMD"
          fi
        fi
        DO_GB=0
        if [[ $RUN_CMDS == *"run_geekbench"* ]]; then
          DO_GB=1
        fi
        if [[ $RUN_CMDS == *"run_gb"* ]]; then
          DO_GB=1
        fi
        if [ "$DO_GB" == "1" ]; then
          RUN_FL="./${BMARK_SUBDIR}/run_geekbench.sh"
          mk_run_fl "$RUN_FL" "$LOG_FL_PFX"
          ssh_cmd $nm "cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR &> ${LOG_FL} &"  "-l"
          echo ssh $SSH_HOST "$SSH_CMD"
          if [ "$DRY_RUN" == "n" ]; then
             # ssh $SSH_HOST "$SSH_CMD"
             echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
             if [ "$nm" == "127.0.0.1" ]; then
               #$SSH_CMD
               cd $BMARK_ROOT; nohup $RUN_FL -c $CFG_DIR -p $NW_PROJ $QUIT_STR &> ${LOG_FL} &
             else
               $SSH_PFX  $ADD_T $SSH_HOST "$SSH_CMD"
             fi
             dyno_log RUN ssh $SSH_HOST "$SSH_CMD"
          fi
        fi
      fi
    fi
  fi
  if [[ $RUN_CMDS == *"peek"* ]]; then
    #echo $SSH_PFX root@${nm} "cd $BMARK_ROOT/; top; ls -ltr $PROJ_DIR;"
    ssh_cmd $nm "cd $BMARK_ROOT/; top; ls -ltr $PROJ_DIR;"  "-l"
    echo $SSH_PFX $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
         echo "=========== run peek on $nm ==============="
         #$SSH_PFX root@${nm} "cd $BMARK_ROOT/; top; ls -ltr $PROJ_DIR"
             # $SSH_PFX $SSH_HOST "$SSH_CMD"
             echo "note that prev ver of cmd at $LINENO didn't have ssh -t" > /dev/stderr
             if [ "$nm" == "127.0.0.1" ]; then
               #$SSH_CMD
               cd $BMARK_ROOT/; top; ls -ltr $PROJ_DIR;
             else
               $SSH_PFX $SSH_HOST "$SSH_CMD"
             fi
             dyno_log $SSH_PFX $SSH_HOST "$SSH_CMD"
    fi
  fi
  DO_FTCH=0
  if [[ $RUN_CMDS == *"fetch"* ]]; then
    DO_FTCH=0
  fi
  if [[ $RUN_CMDS == *"ftchp1"* ]]; then
    do_bkgrnd=0
    if [ "$NUM_HOST" == "0" ]; then
      declare -A FTCH_ARR
      FTCH_ERR=()
      FTCH_SV=()
      FTCH_OK=()
      FTCH_NW_PROJ=()
      FTCH_USE_DIR=()
      FTCH_BASE_DIR=()
      FTCH_TAR_GZ=()
      FTCH_RSP1=()
      FTCH_RSP2=()
    fi
    DO_FTCH=1
  fi
  if [[ $RUN_CMDS == *"ftchp2"* ]]; then
    DO_FTCH=2
  fi
  if [[ $RUN_CMDS == *"ftchp3"* ]]; then
    DO_FTCH=3
  fi
  if [[ $RUN_CMDS == *"ftchp4"* ]]; then
    DO_FTCH=4
  fi
  if [[ $RUN_CMDS == *"ftchp5"* ]]; then
    DO_FTCH=5
  fi
  if [[ $RUN_CMDS == *"ftchp6"* ]]; then
    DO_FTCH=6
  fi
  if [[ $RUN_CMDS == *"ftchp7"* ]]; then
    DO_FTCH=7
  fi
  if [[ $RUN_CMDS == *"ftchp8"* ]]; then
    DO_FTCH=8
  fi
  if [[ $RUN_CMDS == *"ftchp9"* ]]; then
    DO_FTCH=9
  fi
  if [[ $RUN_CMDS == *"ftchpA"* ]]; then
    DO_FTCH=10
  fi
  if [ "$GOT_QUIT" != "0" ]; then
    echo "$0.$LINENO quiting due to signal"
    exit 1
  fi

  if [ "$DO_FTCH" -gt "0" ]; then
    if [ $BKGRND_TASKS_MAX -gt 0 ]; then
      #do_bkgrnd=1
      do_bkgrnd=0
    fi
              if [ "$do_bkgrnd" == "1" ]; then
                if [ "$NUM_HOST" == "0" ]; then
                  wait
                  BKGRND_TASKS_CUR=0
                fi
                if [ $BKGRND_TASKS_CUR -ge $BKGRND_TASKS_MAX ]; then
                  wait
                  BKGRND_TASKS_CUR=0
                fi
              fi
              if [ 1 -eq 2 ]; then
                if [ "$do_bkgrnd" == "1" ]; then
                  $SSH_PFX $SSH_HOST "$SSH_CMD" &
                  BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
                else
                  $SSH_PFX $SSH_HOST "$SSH_CMD"
                fi
              fi
    if [ "$DO_FTCH" -eq "1" ]; then
      # copy fetch_output.sh to remote host
      #echo $SSH_PFX root@${nm} "cd $BMARK_ROOT/; top; ls -ltr $NW_PROJ;"
      FTCH_NW_PROJ[$NUM_HOST]=$NW_PROJ
      ssh_cmd $nm "cd $NW_PROJ; "
      if [ "$nm" == "127.0.0.1" ]; then
         cp $FTCH_OUTPUT $BMARK_ROOT/${BMARK_SUBDIR}/
         dyno_log FETCH cp $FTCH_OUTPUT $BMARK_ROOT/${BMARK_SUBDIR}/
      else
       if [ "$SSH_MODE" == "sudo" ]; then
         echo scp $FTCH_OUTPUT ${SSH_HOST}:$BMARK_ROOT/${BMARK_SUBDIR}/
         if [ "$DRY_RUN" == "n" ]; then
              scp $FTCH_OUTPUT ${SSH_HOST}:$BMARK_ROOT/${BMARK_SUBDIR}
              dyno_log FETCH scp $FTCH_OUTPUT ${SSH_HOST}:
         fi
         #ssh_cmd $nm "mv $FTCH_OUTPUT $BMARK_ROOT/${BMARK_SUBDIR}/"
         #echo     ssh $SSH_HOST "$SSH_CMD"
         #         ssh $SSH_HOST "$SSH_CMD"
         dyno_log FETCH ssh $SSH_HOST "$SSH_CMD"
       else
         pwd
         echo    "scp $FTCH_OUTPUT ${SSH_HOST}:$BMARK_ROOT/${BMARK_SUBDIR}/fetch_output.sh"
         if [ "$DRY_RUN" == "n" ]; then
           if [ "$do_bkgrnd" == "1" ]; then
             FTCH_ARR[$NUM_HOST,1,0]=$SSH_HOST
             echo scp $FTCH_OUTPUT ${FTCH_ARR[$NUM_HOST,1,0]}:$BMARK_ROOT/${BMARK_SUBDIR}/fetch_output.sh
                  scp $FTCH_OUTPUT ${FTCH_ARR[$NUM_HOST,1,0]}:$BMARK_ROOT/${BMARK_SUBDIR}/fetch_output.sh  &
             #scp $FTCH_OUTPUT ${FCSSH_HOST}:$BMARK_ROOT/${BMARK_SUBDIR}/ &
             BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
           else
             scp $FTCH_OUTPUT ${SSH_HOST}:$BMARK_ROOT/${BMARK_SUBDIR}/fetch_output.sh
           fi
           dyno_log FETCH scp $FTCH_OUTPUT ${SSH_HOST}:$BMARK_ROOT/${BMARK_SUBDIR}/fetch_output.sh
         fi
       fi
      fi
      continue
    fi
    echo "DO_FTCH= $DO_FTCH do_bkgrnd= $do_bkgrnd"
    if [ "$DO_FTCH" -eq "2" ]; then
      # tar up the proj dir
      NW_PROJ=${FTCH_NW_PROJ[$NUM_HOST]}
      #if [ "$do_bkgrnd" == "1" ]; then
      #   ssh_cmd $nm "cd $BMARK_ROOT; ./${BMARK_SUBDIR}/fetch_output.sh -p $NW_PROJ" &
      #   BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
      #else
         ssh_cmd $nm "cd $BMARK_ROOT; ./${BMARK_SUBDIR}/fetch_output.sh -p $NW_PROJ"
         FTCH_ARR[$NUM_HOST,2,0]=$SSH_HOST
         FTCH_ARR[$NUM_HOST,2,1]=$SSH_CMD
      #fi
      echo sv_cmd ssh $SSH_HOST "$SSH_CMD"
      FTCH_SVH[$NUM_HOST]=$SSH_HOST
      FTCH_SV[$NUM_HOST]=$SSH_CMD
      continue
    fi
    #echo $SSH_PFX $SSH_HOST "$SSH_CMD"
    if [ "$DRY_RUN" == "n" ]; then
       if [ "$DO_FTCH" -eq "3" ]; then
         # check if the proj dir is found on remote host
         NW_PROJ=${FTCH_NW_PROJ[$NUM_HOST]}
         #SV_SSH_CMD=$SSH_CMD
         ssh_cmd $nm "cd $BMARK_ROOT; if [ -d $NW_PROJ ]; then echo got it; else echo not found; fi"
         OUT_FILE=`printf "$WORK_DIR/$WORK_TMP" $NUM_HOST`
         echo "ssh_cmd= $SSH_CMD  out_file= $OUT_FILE"
         if [ "$nm" == "127.0.0.1" ]; then
           RESP=`bash -c "$SSH_CMD"`
         else
           if [ "$do_bkgrnd" == "1" ]; then
             echo ssh -n ${SSH_HOST} "$SSH_CMD" __ $OUT_FILE
             ssh -n ${SSH_HOST} "$SSH_CMD" &> $OUT_FILE &
             #ssh -n ${FTCH_ARR[$NUM_HOST,2,0]} "${FTCH_ARR[$NUM_HOST,2,1]}" &> $OUT_FILE &
             BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
           else
             FTCH_RSP1[$NUM_HOST]=`ssh ${SSH_HOST} "$SSH_CMD"`
           fi
         fi
         #FTCH_RSP[$NUM_HOST]=$RESP
       fi
       if [ "$DO_FTCH" -eq "4" ]; then
         # read resp to check if output proj dir exists on remote host
         if [ "$do_bkgrnd" == "1" ]; then
           OUT_FILE=`printf "$WORK_DIR/$WORK_TMP" $NUM_HOST`
           RESP=`cat $OUT_FILE | grep "got it"`
         else
           RESP=${FTCH_RSP1[$NUM_HOST]}
         fi
         echo "DO_FTCH $DO_FTCH resp= $RESP"
         if [ "$RESP" != "got it" ]; then
           FETCH_MSG="{invalid proj dir, $nm, $NUM_HOST, $NW_PROJ}"
           FETCH_FAILED="$FETCH_FAILED, $FETCH_MSG"
           dyno_log FETCH_FAILED_INV_NW_PROJ "$FETCH_MSG"
           FTCH_ERR[$NUM_HOST]=$FETCH_FAILED
         fi
         continue
       fi
       if [ "${FTCH_ERR[$NUM_HOST]}" != "" ]; then
          continue
       fi
       if [ "$DO_FTCH" -eq "5" ]; then
         # check if the proj dir tar file is found on remote host
         #SSH_CMD=$SV_SSH_CMD
         SSH_HOST=${FTCH_SVH[$NUM_HOST]}
         SSH_CMD=${FTCH_SV[$NUM_HOST]}
         echo "=========== run fetch_output.sh on $nm ============do_sv_cmd $SSH_CMD ==="
         if [ "$nm" == "127.0.0.1" ]; then
            bash -c "$SSH_CMD"
         else
            if [ "$do_bkgrnd" == "1" ]; then
              OUT_FILE=`printf "$WORK_DIR/a$WORK_TMP" $NUM_HOST`
              echo $SSH_PFX -n $SSH_HOST "$SSH_CMD" __ $OUT_FILE
              $SSH_PFX -n $SSH_HOST "$SSH_CMD" &> $OUT_FILE &
              BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
            else
              $SSH_PFX $SSH_HOST "$SSH_CMD"
            fi
         fi
         dyno_log FETCH $SSH_PFX $SSH_HOST "$SSH_CMD"
         continue
       fi
       if [ "$DO_FTCH" -eq "6" ]; then
         if [ "$ARCHIVE_DIR" == "" ]; then
           ARCHIVE_DIR="./dyno_archive"
         fi
         NW_PROJ=${FTCH_NW_PROJ[$NUM_HOST]}
         BASE_DIR=$(basename $NW_PROJ)
         USE_DIR=$ARCHIVE_DIR/$BASE_DIR/$nm
         TAR_GZ=$BASE_DIR.tar.gz
         FTCH_USE_DIR[$NUM_HOST]=$USE_DIR
         FTCH_BASE_DIR[$NUM_HOST]=$BASE_DIR
         FTCH_TAR_GZ[$NUM_HOST]=$TAR_GZ
         SSH_HOST=${FTCH_SVH[$NUM_HOST]}
         if [ -e "$USE_DIR/$TAR_GZ" ]; then
                           mv $USE_DIR/$TAR_GZ $USE_DIR/$TAR_GZ.old
            dyno_log FETCH mv $USE_DIR/$TAR_GZ $USE_DIR/$TAR_GZ.old
         fi
         ssh_cmd $nm "cd $BMARK_ROOT; if [ -e $NW_PROJ/../$TAR_GZ ]; then echo got it; else echo not found; fi"
         OUT_FILE=`printf "$WORK_DIR/$WORK_TMP" $NUM_HOST`
         echo "$0.$LINENO ssh_cmd= $SSH_CMD"
         if [ "$nm" == "127.0.0.1" ]; then
           RESP=`bash -c "$SSH_CMD"`
         else
           #RESP=`ssh ${SSH_HOST} "$SSH_CMD"`
           if [ "$do_bkgrnd" == "1" ]; then
              echo ssh -n ${SSH_HOST} "$SSH_CMD" __ $OUT_FILE
              ssh -n ${SSH_HOST} "$SSH_CMD" &> $OUT_FILE &
              BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
           else
              FTCH_RSP2[$NUM_HOST]=`ssh ${SSH_HOST} "$SSH_CMD"`
           fi
         fi
         continue
       fi
       if [ "$DO_FTCH" -eq "7" ]; then
           USE_DIR=${FTCH_USE_DIR[$NUM_HOST]}
           BASE_DIR=${FTCH_BASE_DIR[$NUM_HOST]}
           TAR_GZ=${FTCH_TAR_GZ[$NUM_HOST]}
           NW_PROJ=${FTCH_NW_PROJ[$NUM_HOST]}
           SSH_HOST=${FTCH_SVH[$NUM_HOST]}
         if [ "$do_bkgrnd" == "1" ]; then
           OUT_FILE=`printf "$WORK_DIR/$WORK_TMP" $NUM_HOST`
           RESP=`cat $OUT_FILE | grep "got it"`
         else
           RESP=${FTCH_RSP2[$NUM_HOST]}
         fi
         echo "DO_FTCH $DO_FTCH resp= $RESP"
         if [ "$RESP" != "got it" ]; then
           FETCH_MSG="{$nm, $NUM_HOST, $NW_PROJ/../$TAR_GZ}"
           FETCH_FAILED="$FETCH_FAILED, $FETCH_MSG"
           dyno_log FETCH_FAILED_ON_HOST "$FETCH_MSG"
           FTCH_ERR[$NUM_HOST]=$FETCH_FAILED
         fi
         continue
       fi
       if [ "$DO_FTCH" -eq "8" ]; then
           USE_DIR=${FTCH_USE_DIR[$NUM_HOST]}
           BASE_DIR=${FTCH_BASE_DIR[$NUM_HOST]}
           TAR_GZ=${FTCH_TAR_GZ[$NUM_HOST]}
           NW_PROJ=${FTCH_NW_PROJ[$NUM_HOST]}
           SSH_HOST=${FTCH_SVH[$NUM_HOST]}
           echo    "mkdir -p $USE_DIR"
                    mkdir -p $USE_DIR
           dyno_log FETCH "mkdir -p $USE_DIR"
           #echo "ck if created tar.gz on host Got $NW_PROJ/../$TAR_GZ $RESP"
           if [ "$nm" == "127.0.0.1" ]; then
              echo    "cp $NW_PROJ/../$TAR_GZ $USE_DIR"
                       cp $NW_PROJ/../$TAR_GZ $USE_DIR
              dyno_log FETCH cp $NW_PROJ/../$TAR_GZ $USE_DIR
           else
             if [ "$SSH_MODE" == "sudo" ]; then
                echo    "scp ${SSH_HOST}:$NW_PROJ/../$TAR_GZ $USE_DIR"
                         scp ${SSH_HOST}:$NW_PROJ/../$TAR_GZ $USE_DIR
                dyno_log FETCH scp ${SSH_HOST}:$NW_PROJ/../$TAR_GZ $USE_DIR
             else
                echo    "scp ${SSH_HOST}:$NW_PROJ/../$TAR_GZ $USE_DIR"
                if [ "$do_bkgrnd" == "1" ]; then
                         scp ${SSH_HOST}:$NW_PROJ/../$TAR_GZ $USE_DIR &
                         BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
                else
                         scp ${SSH_HOST}:$NW_PROJ/../$TAR_GZ $USE_DIR
                fi
                dyno_log FETCH scp ${SSH_HOST}:$NW_PROJ/../$TAR_GZ $USE_DIR
             fi
           fi
           continue
       fi
       if [ "$DO_FTCH" -eq "9" ]; then
           USE_DIR=${FTCH_USE_DIR[$NUM_HOST]}
           BASE_DIR=${FTCH_BASE_DIR[$NUM_HOST]}
           TAR_GZ=${FTCH_TAR_GZ[$NUM_HOST]}
           NW_PROJ=${FTCH_NW_PROJ[$NUM_HOST]}
           SSH_HOST=${FTCH_SVH[$NUM_HOST]}
#abcd
           WXY_LST="$wxy_flds"
           WXY_CMA=";"
           WXY_DLM=
           WXY_STR=
           WXY_HDR=
           for WXY_i in $WXY_LST; do
              WXY_STR="${WXY_STR}${WXY_DLM}{{.$WXY_i}}"
              WXY_HDR="${WXY_HDR}${WXY_DLM}${WXY_i}"
              WXY_DLM=$WXY_CMA
           done
           echo ${wxy_str} ${wxy_hl} -n $nm -f "$WXY_STR" > /dev/stderr
           echo "$WXY_HDR" >> $ARCHIVE_DIR/do_${wxy_str}_info.txt
           ${wxy_str} ${wxy_hl} -n $nm -f "$WXY_STR" >> $ARCHIVE_DIR/do_${wxy_str}_info.txt
           FETCH_MSG="{$nm, $NUM_HOST, $USE_DIR/$TAR_GZ}"
           if [ ! -e "$USE_DIR/$TAR_GZ" ]; then
             FETCH_FAILED="$FETCH_FAILED, $FETCH_MSG"
             dyno_log FETCH_FAILED_LOCAL "$FETCH_MSG"
             FTCH_ERR[$NUM_HOST]=$FETCH_FAILED
           fi
             FETCH_WORKED="$FETCH_WORKED, $FETCH_MSG"
             FTCH_OK[$NUM_HOST]=$FETCH_WORKED
             dyno_log FETCH_WORKED "$FETCH_MSG"
             continue
       fi
       if [ "$DO_FTCH" -eq "10" ]; then
           echo "do_ftch $DO_FTCH"
           USE_DIR=${FTCH_USE_DIR[$NUM_HOST]}
           TAR_GZ=${FTCH_TAR_GZ[$NUM_HOST]}
                   echo  "num_host= $NUM_HOST pushd $USE_DIR && tar xzvf $TAR_GZ && popd"
                         pushd $USE_DIR
                         tar xzvf $TAR_GZ
                         echo "num_host= $NUM_HOST"
                         pwd
                         ls -l
                         popd
                dyno_log FETCH "num_host= $NUM_HOST pushd $USE_DIR && tar xzvf $TAR_GZ && popd"
             continue
       fi
    fi
  fi
  if [[ $RUN_CMDS == *"get_recur"* ]]; then
         if [ "$ARCHIVE_DIR" == "" ]; then
           ARCHIVE_DIR="./dyno_archive"
         fi
#abc
         BASE_DIR=$(basename $NW_PROJ)
         USE_DIR=$ARCHIVE_DIR/$nm
         #TAR_GZ=$BASE_DIR.tar.gz # comes from -t option
         #ssh_cmd $nm "if [ -e $NW_PROJ ]; then echo got it; else echo not found; fi"
         #echo "ssh_cmd= $SSH_CMD"
         #if [ "$nm" == "127.0.0.1" ]; then
         #  RESP=`bash -c "$SSH_CMD"`
         #else
         #  RESP=`ssh ${SSH_HOST} "$SSH_CMD"`
         #fi
         #if [ "$RESP" != "got it" ]; then
         #  FETCH_MSG="{$nm, $NUM_HOST, $TAR_GZ}"
         #  FETCH_FAILED="$FETCH_FAILED, $FETCH_MSG"
         #  dyno_log FETCH_FAILED_ON_HOST "$FETCH_MSG"
         #else
           echo    "mkdir -p $USE_DIR"
                    mkdir -p $USE_DIR
           dyno_log FETCH "mkdir -p $USE_DIR"
           #echo "ck if created tar.gz on host Got $NW_PROJ/../$NW_PROJ $RESP"
           ssh_cmd $nm "uname"
           if [ "$nm" == "127.0.0.1" ]; then
              echo    "cp -rp $NW_PROJ $USE_DIR"
                       cp -rp $NW_PROJ $USE_DIR
              dyno_log FETCH cp $NW_PROJ $USE_DIR
           else
             if [ "$SSH_MODE" == "sudo" ]; then
                echo    "scp -rp ${SSH_HOST}:$NW_PROJ $USE_DIR"
                         scp -rp  ${SSH_HOST}:$NW_PROJ $USE_DIR
                dyno_log FETCH scp ${SSH_HOST}:$NW_PROJ $USE_DIR
             else
                echo    "scp -rp ${SSH_HOST}:$NW_PROJ $USE_DIR"
                         scp -rp ${SSH_HOST}:$NW_PROJ $USE_DIR
                dyno_log FETCH scp -rp ${SSH_HOST}:$NW_PROJ $USE_DIR
             fi
           fi
           RESP=$(basename $NW_PROJ)
           FETCH_MSG="{$nm, $NUM_HOST, $USE_DIR/$RESP}"
           if [ ! -e "$USE_DIR/$RESP" ]; then
             FETCH_FAILED="$FETCH_FAILED, $FETCH_MSG"
             dyno_log FETCH_FAILED_LOCAL "$FETCH_MSG"
           else
             FETCH_WORKED="$FETCH_WORKED, $FETCH_MSG"
             dyno_log FETCH_WORKED "$FETCH_MSG"
           fi
         #fi
  else
  if [[ $RUN_CMDS == *"get"* ]]; then
    if [ $BKGRND_TASKS_MAX -gt 0 ]; then
      do_bkgrnd=1
    fi
         if [ "$ARCHIVE_DIR" == "" ]; then
           ARCHIVE_DIR="./dyno_archive"
         fi
#abc
         BASE_DIR=$(basename $NW_PROJ)
         USE_DIR=$ARCHIVE_DIR/$nm
         #TAR_GZ=$BASE_DIR.tar.gz # comes from -t option
         ssh_cmd $nm "if [ -e $TAR_GZ ]; then echo got it; else echo not found; fi"
         if [ 1 == 2 ]; then
           ssh_cmd $nm "if [ -e $TAR_GZ ]; then echo got it; else echo not found; fi"
           echo "ssh_cmd= $SSH_CMD"
           if [ "$nm" == "127.0.0.1" ]; then
             RESP=`bash -c "$SSH_CMD"`
           else
             echo ssh ${SSH_HOST} "$SSH_CMD"
             RESP=`ssh ${SSH_HOST} "$SSH_CMD"`
           fi
         else
           RESP="got it"
         fi
         if [ "$RESP" != "got it" ]; then
           FETCH_MSG="{$nm, $NUM_HOST, $TAR_GZ}"
           FETCH_FAILED="$FETCH_FAILED, $FETCH_MSG"
           dyno_log FETCH_FAILED_ON_HOST "$FETCH_MSG"
         else
           echo    "mkdir -p $USE_DIR"
                    mkdir -p $USE_DIR
           dyno_log FETCH "mkdir -p $USE_DIR"
           #echo "ck if created tar.gz on host Got $NW_PROJ/../$TAR_GZ $RESP"
           if [ "$nm" == "127.0.0.1" ]; then
              echo    "cp $TAR_GZ $USE_DIR"
                       cp $TAR_GZ $USE_DIR
              dyno_log FETCH cp $TAR_GZ $USE_DIR
           else
             if [ "$SSH_MODE" == "sudo" ]; then
                echo    "scp ${SSH_HOST}:$TAR_GZ $USE_DIR"
                         scp ${SSH_HOST}:$TAR_GZ $USE_DIR
                dyno_log FETCH scp ${SSH_HOST}:$TAR_GZ $USE_DIR
             else
                echo    "scp ${SSH_HOST}:$TAR_GZ $USE_DIR"
                if [ "$do_bkgrnd" == "1" ]; then
                   scp ${SSH_HOST}:$TAR_GZ $USE_DIR &
                   BKGRND_TASKS_CUR=$((BKGRND_TASKS_CUR+1))
                else
                   scp ${SSH_HOST}:$TAR_GZ $USE_DIR
                fi
                dyno_log FETCH scp ${SSH_HOST}:$TAR_GZ $USE_DIR
             fi
           fi
           RESP=$(basename $TAR_GZ)
           FETCH_MSG="{$nm, $NUM_HOST, $USE_DIR/$RESP}"
           if [ ! -e "$USE_DIR/$RESP" ]; then
             FETCH_FAILED="$FETCH_FAILED, $FETCH_MSG"
             dyno_log FETCH_FAILED_LOCAL "$FETCH_MSG"
           else
             FETCH_WORKED="$FETCH_WORKED, $FETCH_MSG"
             dyno_log FETCH_WORKED "$FETCH_MSG"
             if [[ $RUN_CMDS == *"get_untar"* ]]; then
                   echo  "pushd $USE_DIR && tar xzvf $RESP && popd"
                         pushd $USE_DIR
                         tar xzvf $RESP
                         popd
                dyno_log FETCH "pushd $USE_DIR && tar xzvf $RESP && popd"
             fi
           fi
         fi
  fi
  fi
  if [[ $RUN_CMDS == *"report"* ]]; then
    if [ "$RPT_FILE" != "" -a "$DID_RPT_FILE_init" == "0" ]; then
      echo "" > $RPT_FILE
      DID_RPT_FILE_init=1
    fi
    if [ "$ARCHIVE_DIR" == "" ]; then
    ssh_cmd $nm "cd $BMARK_ROOT/"
    if [ "$DRY_RUN" == "n" ]; then
      if [ "$nm" == "127.0.0.1" ]; then
         echo    "cp $GEN_RPT $BMARK_ROOT/${BMARK_SUBDIR}/"
                  cp $GEN_RPT $BMARK_ROOT/${BMARK_SUBDIR}/
         dyno_log cp $GEN_RPT $BMARK_ROOT/${BMARK_SUBDIR}/
      else
        if [ "$SSH_MODE" == "sudo" ]; then
           echo     scp $GEN_RPT ${SSH_HOST}:
                    scp $GEN_RPT ${SSH_HOST}:
           dyno_log scp $GEN_RPT ${SSH_HOST}:
           ssh_cmd $nm "mv $GEN_RPT $BMARK_ROOT/${BMARK_SUBDIR}/"
           echo     ssh $SSH_HOST "$SSH_CMD"
                    ssh $SSH_HOST "$SSH_CMD"
           dyno_log ssh $SSH_HOST "$SSH_CMD"
        else
           echo    "scp $GEN_RPT ${SSH_HOST}:$BMARK_ROOT/${BMARK_SUBDIR}/"
                    scp $GEN_RPT ${SSH_HOST}:$BMARK_ROOT/${BMARK_SUBDIR}/
           dyno_log scp $GEN_RPT ${SSH_HOST}:$BMARK_ROOT/${BMARK_SUBDIR}/
        fi
      fi
    fi
    fi
    VRB=
    if [ $VERBOSE -gt 0 ]; then
      VRB=" -v"
    fi
    echo try ${wxy_str} ${wxy_hs} $nm
    if [[ $nm =~ ^[0-9]+ ]]; then
      echo "nm $nm starts with a number so skip ${wxy_str} ${wxy_hs} cmd"
      SKU="N/A"
      SKU_MAKE="N/A"
      SKU_MODEL="N/A"
      if [ "$USE_LIST" == "gcp" ]; then
        SKU=${GCP_HOSTS_ARR[$NUM_HOST]}
        SKU=`echo $SKU | sed 's/benchmark-//;'`
      fi
    else
      clsto_file=$ARCHIVE_DIR/${wxy_str}_info.lst
      WXY_OUT=`${wxy_str} ${wxy_hs} $nm`
      if [ "$WXY_OUT" != "" ]; then
        if [ ! -e $clsto_file ]; then
           ${wxy_str} ${wxy_hs} $nm > $clsto_file
        fi
        RESP=`grep $nm $clsto_file | wc -l`
        if [ "$RESP" == "0" ]; then
           ${wxy_str} ${wxy_hs} $nm >> $clsto_file
        fi
        if [ -e $clsto_file ];then
          CLUSTO=`awk -v nm="$nm" 'BEG{doit=0;str=""}/^----/{if (doit==1) {printf("%s\n", str);exit;}}{if (index($0, nm) > 0) { doit=1;};if (doit==1) {str=str ""$0"\n";}}' $clsto_file`
          echo "from $clsto_file ${wxy_str}= $CLUSTO"
        else
          CLUSTO=`${wxy_str} ${wxy_hs} $nm`
        fi
      fi
      echo did ${wxy_str} ${wxy_hs} $nm
      SKU=`echo "$CLUSTO" | awk '/^Sku/{printf("%s\n", $2);}'`
      SKU_MAKE=`echo "$CLUSTO" | awk '/^Make/{printf("%s\n", $2);}'`
      SKU_MODEL=`echo "$CLUSTO" | awk '/^Model/{printf("%s\n", $2);}'`
      if [ "$SKU" == "" ]; then
        SKU="N/A"
      fi
      if [ "$SKU_MAKE" == "" ]; then
        SKU_MAKE="N/A"
      fi
      if [ "$SKU_MODEL" == "" ]; then
        SKU_MODEL="N/A"
      fi
      echo did ${wxy_str} ${wxy_hs} $nm
    fi
    if [ "$ARCHIVE_DIR" == "" ]; then
      ssh_cmd $nm "cd $BMARK_ROOT/; ${BMARK_SUBDIR}/gen_report.sh -p $NW_PROJ -s \"$SKU\" -m \"$SKU_MAKE\" -t \"$SKU_MODEL\"  $VRB"  "-l"
      if [ "$RPT_FILE" != "" ]; then
        echo $SSH_HOST "$SSH_CMD >> $RPT_FILE"
      else
        echo $SSH_HOST "$SSH_CMD"
      fi
      if [ "$DRY_RUN" == "n" ]; then
           if [ "$RPT_FILE" != "" ]; then
             USE_FILE=$RPT_FILE
           else
             USE_FILE=/dev/stdout
           fi
           echo "============= begin $nm =========================" >> $USE_FILE
           if [ "$nm" == "127.0.0.1" ]; then
                    bash -c "$SSH_CMD" >> $USE_FILE
           dyno_log bash -c "$SSH_CMD" ">>" $USE_FILE
           else
                    ssh $SSH_HOST "$SSH_CMD" >> $USE_FILE
           dyno_log ssh $SSH_HOST "$SSH_CMD" ">>" $USE_FILE
           fi
           echo "============= end   $nm =========================" >> $USE_FILE
      fi
    else
      #echo "archdir= $ARCHIVE_DIR  nm=$nm  bsnm_projdir= $(basename $NW_PROJ)"
      USE_DIR=$ARCHIVE_DIR/$nm/$(basename $NW_PROJ)
      if [ ! -e $USE_DIR ]; then
        USE_DIR=$ARCHIVE_DIR/$(basename $NW_PROJ)/$nm/$(basename $NW_PROJ)
      fi
      USE_ARR=()
      if [ ! -e $USE_DIR ]; then
        USE_ARR=( `find $ARCHIVE_DIR -name $nm -type d | sort` )
        echo "$0.$LINENO: ____USE_ARR= ${USE_ARR[@]}" > /dev/stderr
        #if [ "$USE_DIR" != "" ]; then
        #fi
      else
        USE_ARR[0]=$USE_DIR
      fi
      for ((jj=0; jj < ${#USE_ARR[@]}; jj++)); do
        USE_DIR=${USE_ARR[$jj]}
      DIR_60=
      if  [ "$DIR_60SECS_SCRIPTS" != "" ]; then
         DIR_60=" -D $DIR_60SECS_SCRIPTS "
      fi
      CMB_O=
      if  [ "$CMB_FILE" != "" ]; then
        CMB_O=" -z $CMB_FILE "
        CMD=$CMB_O
        IFS="/" read -ra PARTS <<< "$ARCHIVE_DIR"
        IFS=$IFS_SV
        ARCD=${PARTS[0]}
        if [ "$ARCD" == "." ]; then
          ARCD=${PARTS[1]}
        fi
        echo "CMD_FILE= $CMB_FILE, arcd= $ARCD" > /dev/stderr
        re='(.*)%ARCHIVE%(.*)'
        while [[ $CMD =~ $re ]]; do
          CMD=${BASH_REMATCH[1]}$ARCD${BASH_REMATCH[2]}
        done
        echo "aft CMD= $CMD, arcd= $ARCD" > /dev/stderr
        CMB_O=$CMD
      fi
      SSH_CMD="$GEN_RPT -p $USE_DIR -s \"$SKU\" -m \"$SKU_MAKE\" -t \"$SKU_MODEL\" -H $nm  $VRB $CMB_O $DIR_60"
      if [ "$RPT_FILE" != "" ]; then
        echo "$SSH_CMD >> $RPT_FILE"
      else
        echo "$SSH_CMD"
      fi
      if [ "$DRY_RUN" == "n" ]; then
           if [ "$RPT_FILE" != "" ]; then
             USE_FILE=$RPT_FILE
           else
             USE_FILE=/dev/stdout
           fi
           echo "============= begin $nm =========================" >> $USE_FILE
                    $SSH_CMD  >> $USE_FILE
           dyno_log "$SSH_CMD >> $USE_FILE"
           echo "============= end   $nm =========================" >> $USE_FILE
      fi
      done
    fi
  fi
  #echo "sleep 1 sec to try and catch cntrl+c"
  #sleep 1
  if [ "$GOT_QUIT" != "0" ]; then
    echo "got quit"
    exit 0
  fi
done

if [ $BKGRND_TASKS_CUR -gt 0 ]; then
  wait
  BKGRND_TASKS_CUR=0
fi
done

  if [[ $RUN_CMDS == *"combine"* ]]; then
    USE_FILE=/dev/stdout
    if [ "$CMB_FILE" != "" ]; then
      USE_FILE=$CMB_FILE
        CMD=$USE_FILE
        IFS="/" read -ra PARTS <<< "$ARCHIVE_DIR"
        IFS=$IFS_SV
        ARCD=${PARTS[0]}
        if [ "$ARCD" == "." ]; then
          ARCD=${PARTS[1]}
        fi
        echo "bef CMD= $CMD, arcd= $ARCD" > /dev/stderr
        re='(.*)%ARCHIVE%(.*)'
        while [[ $CMD =~ $re ]]; do
          CMD=${BASH_REMATCH[1]}${ARCD}${BASH_REMATCH[2]}
        done
        echo "aft CMD= $CMD, arcd= $ARCD" > /dev/stderr
        USE_FILE=$CMD
    if [ "$DID_CMB_FILE_init" == "0" ]; then
      echo "" > $USE_FILE
      DID_CMB_FILE_init="1"
    fi
    fi
    echo "USE_FILE= $USE_FILE"
    #echo $SSH_PFX root@${nm} "cd $BMARK_ROOT/; top; ls -ltr $NW_PROJ;"
    if [ "$RPT_FILE" == "" -o ! -e "$RPT_FILE" ]; then
      echo "You must specify the '-r report -o report_file' and then use '-c combine -o report_file' together"
      exit 1
    fi
    awk -v cmb="$CMB_CNTR" '
    BEGIN{hdr=cmd;}
    /^__key__;/ {if(hdr==0) {printf("%s\n", substr($0, 9)); hdr=1;}}
    /^__val__;/ {printf("%s\n", substr($0, 9));}
    ' $RPT_FILE >> $USE_FILE
    awk -v cmb="$CMB_CNTR" '
    BEGIN{hdr=cmd;}
    /^__val2__;/ {printf("%s\n", substr($0, 10));}
    ' $RPT_FILE >> $USE_FILE
    CMB_CNTR=$((CMB_CNTR+1))
  fi

  if [[ $RUN_CMDS == *"ping"* ]]; then
    echo "ping worked: $PING_WORK"
    echo "ping failed: $PING_FAIL"
  fi
  if [[ $RUN_CMDS == *"nameserver_test"* ]]; then
    echo "ping worked: $PING_WORK"
    echo "ping failed: $PING_FAIL"
    if [ "$PING_FAIL" != "" ]; then
      echo "you need to put 'nameserver 8.8.8.8' in /etc/resolv.conf on the failed hosts"
    fi
  fi
  if [[ $RUN_CMDS == *"ssh_test"* ]]; then
    echo "ssh worked: $SSH_WORK"
    echo "ssh failed: $SSH_FAIL"
  fi
  if [ "$FETCH_WORKED" != "" -o "$FETCH_FAILED" != "" ]; then
    echo "fetch_worked: $FETCH_WORKED"
    echo "fetch_failed: $FETCH_FAILED"
  fi

exit 0

