#!/bin/bash

ODIR="."
if [ "$1" != "" ]; then
 ODIR=$1
 if [ ! -d $ODIR ]; then
   mkdir -p $ODIR
 fi
 if [ ! -d $ODIR ]; then
   echo "$0.$LINENO couldn't find/create output dir \"$ODIR\""
   exit 1
 fi
fi
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
#export LC_ALL=C
WRK=" sleep 1 "
WRK=" ./60secs/extras/spin.x -w freq -t 1 -n 1"
WRK=" ./60secs/extras/spin.x -w freq_sml -t 10 -n 1"
WRK=" ./60secs/extras/spin.x -w freq_sml -t 1 -L 0,48"
WRK=" ./60secs/extras/spin.x -w mem_bw -t 1 -n 1 -s 100m -b 64"
WRK=" ./60secs/extras/spin.x -w spin -t 1 -n 1"
WRK=" ./60secs/extras/spin.x -w spin -t 1 -L 0,32"
WRK=" ./60secs/extras/spin.x -w freq_sml -t 1 -n 1"
WRK=" ./60secs/extras/spin.x -w freq_sml -t 1 -L 0"
WRK=" ./60secs/extras/spin.x -w freq_sml -t 1 -L 0,32"
WRK=" ./60secs/extras/spin.x -w spin -t 1 -L 0"
WRK=" ./60secs/extras/spin.x -w spin -t 1 -L 0,32"
WRK=" ./60secs/extras/spin.x -w mem_bw -t 1 -s 100m -b 64 -L 0"
WRK=" ./60secs/extras/spin.x -w mem_bw -t 1 -s 100m -b 64 -L 0,32"
WRK=" ./60secs/extras/spin.x -w mem_bw_2rdwr -t 1 -s 100m -b 64 -L 0,32"

RET_INST_CYCLES="-e cpu/name='ret_inst_cycles',event=0xc0,cmask=0x1,inv=0/"
RET_UOPS="-e cpu/name='ret_uops',event=0xc1/"
RET_UOPS_CYCLES="-e cpu/name='ret_uops_cycles',event=0xc1,cmask=0x1,inv=0/"
CYCLES_ANY="-e cpu/name='cycles_any',event=0x76,cmask=0x1,inv=0/"
EVTS=" -e cycles -e instructions  $RET_INST_CYCLES $RET_UOPS $RET_UOPS_CYCLES "

PBIN=/root/60secs/perf
#perf record -R -a -e ibs_fetch//pp -e ibs_op//pp sleep 1
#$PBIN record -R -a -e ibs_fetch// -e ibs_op// sleep 1
#perf record -R -a -e ibs_fetch//pp -e ibs_op//pp $WRK &> spn.txt
perf record -R -a -o $ODIR/perf.dat $EVTS -e ibs_fetch//pp -e ibs_op//pp $WRK &> $ODIR/spn.txt

#-F, --fields <str>    comma separated output fields prepend with 'type:'. +field to add and -field to remove.Valid types: hw,sw,trace,raw,synth. Fields: comm,tid,pid,time,cpu,event,trace,ip,sym,dso,addr,symoff,srcline,period,iregs,uregs,brstack,brstacksym,flags,bpf-output,brstackinsn,brstackoff,callindent,insn,insnlen,synth,phys_addr,metric,misc,ipc,tod

$PBIN report -D -I -i $ODIR/perf.dat       --header --stdio > $ODIR/perf_out_rep.txt
$PBIN script -D -I -i $ODIR/perf.dat  --ns --header -F comm,tid,pid,time,cpu,period,event,ip,sym,dso,symoff,flags,callindent  > $ODIR/perf_out_scr1.txt
$PBIN script    -I -i $ODIR/perf.dat  --ns --header -F comm,tid,pid,time,cpu,period,event,ip,sym,dso,symoff,flags,callindent  > $ODIR/perf_out_scr2.txt

