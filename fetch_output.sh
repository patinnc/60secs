#!/bin/bash

PROJ_DIR=
hostname

while getopts "hvmc:p:t:" opt; do
  case ${opt} in
    c )
      CFG_DIR=$OPTARG
      ;;
    p )
      PROJ_DIR=$OPTARG
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 get results on a host in /root/output/* or (if -p proj_dir) /proj_dir/"
      echo "Usage: $0 [-h] [ -p proj_dir] [-v]"
      echo "   -p project_dir"
      echo "     by default the host results dir name /root/output"
      echo "     If you specify a project dir the benchmark results are looked for"
      echo "     under /project_dir/"
      echo "   -v verbose mode"
      echo "   -c config_dir not used by don't want an error if passed"
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

if [ "$PROJ_DIR" == "" -o ! -d "$PROJ_DIR" ]; then
   echo "must pass valid '-p proj_dir'. Dir $PROJ_DIR not found"
   exit
fi

pushd $PROJ_DIR
DIRNM=$(basename `pwd`)
RESP=`find . -type d -print | grep "specint/benchspec/CPU$" | sed 's/^.\///; s/$/\/*/'`
excl_file=
if [ "$RESP" == "" ]; then
  echo "no specint/benchspec/CPU dir"
else
  excl_file=dyno_fetch_tar_exclude_dirs.txt
  echo "got specint/benchspec/CPU resp= $RESP"
  echo "$RESP" > $excl_file
  pwd
fi
RESP=`find . -type d -print | grep "specint/tmp$" | sed 's/^.\///; s/$/\/*/'`
#excl_file=
if [ "$RESP" == "" ]; then
  echo "no specint/tmp dir"
else
  echo "got specint/tmp resp= $RESP"
  if [ "$excl_file" != "" ]; then
  echo "$RESP" >> $excl_file
  else
  excl_file=dyno_fetch_tar_exclude_dirs.txt
  echo "$RESP" > $excl_file
  fi
fi
cd ..
echo "DIRNM= $DIRNM"
TAR_FILE=/tmp/${DIRNM}.tar.gz
echo "got TAR_FILE= $TAR_FILE excl_file= $excl_file"
if [ "$excl_file" == "" ]; then
  echo "do tar -czvf $TAR_FILE $DIRNM"
  tar -czvf $TAR_FILE $DIRNM
else
  pwd
  echo cat $DIRNM/$excl_file
       cat $DIRNM/$excl_file
  echo "do tar -czv --exclude-from=$DIRNM/$excl_file -f $TAR_FILE $DIRNM"
  tar -czv --exclude-from=$DIRNM/$excl_file -f $TAR_FILE $DIRNM
fi
ls -l $TAR_FILE
pwd
popd
