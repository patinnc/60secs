#!/bin/bash

#sysctl kernel.nmi_watchdog=0 && python pmu-tools-master/toplev.py -l2 --per-core -x, --no-multiplex  -o tmp.txt -v  --nodes +CPU_Utilization,+Turbo_Utilization  -- /root/60secs/extras/spin.x -w freq -t 5
# ./top_lev_flame.sh tmp.txt
#

SCR_DIR=`dirname "$(readlink -f "$0")"`
USE_UNIT="% Slots"
FL=

while getopts "hvf:u:" opt; do
  case ${opt} in
    f )
      FL=$OPTARG
      ;;
    u )
      USE_UNIT="$OPTARG"
      ;;
    v )
      VERBOSE=$((VERBOSE+1))
      ;;
    h )
      echo "$0 read toplev .csv and create .collaped file for flamegraph"
      echo "Usage: $0 -f toplev.csv  [ -u use_unit ]"
      echo "   -f toplev csv file"
      echo "   -u use_unit. default is \"% Slots\" "
      echo "   -v verbose mode"
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

if [ "$FL" == "" ]; then
 echo "you must enter a file name like -f l3.csv"
 exit
fi
if [ ! -e $FL ]; then
  echo "can't find file -f $FL"
  exit
fi
#TSC_FREQ=`lscpu |grep "Model name:" | awk '{for (i=1;i<=NF;i++){pos=index($i,"GHz");if (pos > 0){frq=substr($i,1,pos-1);printf("%s\n",frq);exit;}}}'`
#echo "TSC_FREQ= $TSC_FREQ"
#SLOTS=8
#CPU_ARCH=`$SCR_DIR/decode_cpu_fam_mod.sh`

echo "use_unit= $USE_UNIT" > /dev/stderr
printf "%s\n%s\n\n\n", $USE_UNIT, $USE_INIT > /dev/stderr


#awk -v cpu_arch="$CPU_ARCH" -v tsc_freq="$TSC_FREQ" -v dura="$DURA" '
awk -v use_unit="$USE_UNIT" '
    BEGIN{
    i=0;
    printf("inside awk use_unit= %s\n", use_unit) > "/dev/stderr";
    ev[++i,1]="Backend_Bound"; ev[i,2]="Lack of required resources such as data-cache misses or stalls"; ev[i,3]="Stalled";
    ev[++i,1]="Backend_Bound.Core_Bound"; ev[i,2]="Sub-optimal execution ports utilization"; ev[i,3]="Stalled";
    ev[++i,1]="Backend_Bound.Core_Bound.Ports_Utilization"; ev[i,2]="Execution Unit Port utilization"; ev[i,3]="Stalled";
    ev[++i,1]="Backend_Bound.Memory_Bound"; ev[i,2]="Execution stalls related to the memory subsystem"; ev[i,3]="Stalled";
    ev[++i,1]="Backend_Bound.Memory_Bound.DRAM_Bound"; ev[i,2]="DRAM Bound"; ev[i,3]="Stalled";
    ev[++i,1]="Backend_Bound.Memory_Bound.L1_Bound"; ev[i,2]="L1 Bound"; ev[i,3]="Stalled";
    ev[++i,1]="Backend_Bound.Memory_Bound.L2_Bound"; ev[i,2]="L2 Bound"; ev[i,3]="Stalled";
    ev[++i,1]="Backend_Bound.Memory_Bound.L3_Bound"; ev[i,2]="L3 Bound"; ev[i,3]="Stalled";
    ev[++i,1]="Frontend_Bound"; ev[i,2]="Branch predictor predicts the next address to fetch, cache lines are fetched, parsed into instructions, and decoded into micro-ops"; ev[i,3]="Stalled";
    ev[++i,1]="Frontend_Bound.Frontend_Bandwidth"; ev[i,2]="Instruction decoders"; ev[i,3]="Stalled";
    ev[++i,1]="Frontend_Bound.Frontend_Latency"; ev[i,2]="I-Cache miss"; ev[i,3]="Stalled";
    ev[++i,1]="Frontend_Bound.Frontend_Latency.ICache_Misses"; ev[i,2]="I-Cache miss"; ev[i,3]="Stalled";
    ev[++i,1]="Bad_Speculation"; ev[i,2]="Slots used to issue uops that do not eventually retire; as well as slots in which the issue pipeline was blocked due to recovery from earlier miss-speculations."; ev[i,3]="Not_Stalled";
    ev[++i,1]="Bad_Speculation.Branch_Mispredicts"; ev[i,2]="Branch mispredicts"; ev[i,3]="Not_Stalled";
    ev[++i,1]="Bad_Speculation.Machine_Clears"; ev[i,2]="Incorrect data speculation"; ev[i,3]="Not_Stalled";
    ev[++i,1]="Retiring"; ev[i,2]="Issued uops that eventually get retired. Retiring of 50% means an IPC of 2"; ev[i,3]="Not_Stalled";
    ev[++i,1]="Retiring.Base"; ev[i,2]="Slots fraction where the CPU was retiring uops not originated from the microcode-sequencer"; ev[i,3]="Not_Stalled";
    ev[++i,1]="Retiring.Microcode_Sequencer"; ev[i,2]="Microcode sequences such as Floating Point (FP) assists bottleneck"; ev[i,3]="Not_Stalled";
    ev[++i,1]="Halted"; ev[i,2]="Based on CPU_Utilization metric. Fraction (0 to 1.0) of time that CPU is unhalted"; ev[i,3]="Idle";
    ev_mx = i;
    for (i=1; i <= ev_mx; i++) {
      str = ev[i,1];
      n=split(str, arr, ".");
      ev_lkup[str] = i;
      ev[i,4] = n;
      ev_count[i] = 0.0;
      for (j=1; j <= n; j++) {
        ev_lvls[i,j] = arr[j];
      }
      #printf("ev[%d,1]= %s, lvls= %d\n", i, str, ev[i,4]);
    }
      ev_mx_init = ev_mx;
      turbo_ratio = 0.0;
    }
    # this selector assumes input like the example data at the end of this script.
    /^S[0-9]+-C[0-9]/ {
      #printf("Got %s\n", $0);
      n = split($0, arr, ",");
      sct  = arr[1];
      area = arr[2];
      val  = arr[3]+0.0;
      unit = arr[4];
      ck_unit = index(unit, use_unit);
      ck_unit_stalls = index(unit, "% Stalls");
      ck_unit_slots  = index(unit, "% Slots");
      ck_unit_clocks = index(unit, "% Clocks");
      ck_unit_uops   = index(unit, "% Uops");
      if (area == "CPU_Utilization" || ck_unit > 0 || (use_unit == "% Slots" && (ck_unit_stalls > 0 || ck_unit_slots > 0 || ck_unit_clocks || ck_unit_uops)) ) {
         #printf("use  unit= \"%s\" use_unit= \"%s\"\n", unit, use_unit) > "/dev/stderr";
         ;
      } else {
         #printf("skip unit= \"%s\" use_unit= \"%s\"\n", unit, use_unit) > "/dev/stderr";
         next;
      }
      if (area == "CPU_Utilization") {
        area = "Halted";
        util = val;
        tpos = index(sct, "-T");
        if (tpos == 0) {
          # HT disabled?
          usct = sct;
        } else {
          usct = substr(sct, 1, tpos-1);
        }
        if (!(usct in util_lkup)) {
           util_idx++;
           util_lkup[usct] = util_idx;
           util_list[util_idx] = usct;
        }
        #sv_util[usct,1] = (sv_util[usct,1]+0.0 < util ? util: sv_util[usct,1]+0.0);
        sv_util[usct,1] = util;
        sv_util[usct,2]++;
        if (util > 0.0) {
            val = 100.0*(1.0-util)/util
        } else {
            val = 100.0;
        }
        ttsum+=val;
        printf("sct= %s util= %f val= %f ttsum= %f\n", sct, util, val, ttsum) > "/dev/stderr";
        #val *= dura * tsc_freq * turbo_ratio * 1.0e9;
        next;
      }
      desc = arr[5];
      smpl = arr[5];
      stdev= arr[6];
      multi= arr[7];
      bottl= arr[8];
      # handle lines for the thread level data like "S0-C0-T0,"
      pos = match(sct, /-T[0-1]/);
      if (pos > 0) {
         sct = substr(sct, 1, pos);
      }
      if (!(area in ev_lkup)) {
         printf("missed area= %s\n", area) > "/dev/stderr";
         ev_mx++;
         ev[ev_mx,1]=area;
         ev[ev_mx,2]="unknown";
         n=split(area, arr, ".");
         if (arr[1] == "Backend_Bound" || arr[1] == "Frontend_Bound") {
            ev[ev_mx,3]="Stalled";
         } else {
            ev[ev_mx,3]="Not_Stalled";
         }
         ev_lkup[area] = ev_mx;
         ev[ev_mx,4] = n;
         for (j=1; j <= n; j++) {
           ev_lvls[ev_mx,j] = arr[j];
         }
      }
      if (area == "Halted") {
         next;
      }
      i = ev_lkup[area];
      if (use_unit == "% Slots" && (ck_unit_stalls > 0 || ck_unit_slots > 0 || ck_unit_clocks > 0 || ck_unit_uops > 0) ) {
         if (ev[i,4] == 2) {
            ev_core[usct,area] = val;
            area_lvl1 = ev_lvls[i,1];
            j = ev_lkup[area_lvl1];
            ev_count[j] -= val;
         }
         if (ev[i,4] == 3) {
           area_lvl1 = ev_lvls[i,1];
           area_lvl2 = "";
           sep="";
           for (j=1; j <= 2; j++) {
             area_lvl2 = area_lvl2 "" sep "" ev_lvls[i,j];
             sep = ".";
           }
           if (!(area_lvl2 in ev_lkup)) {
              printf("====> missed lookup of levl2 area %s in ev_lkup for area= %s, usct= %s\n", area_lvl2, area, usct) > "/dev/stderr";
           } else {
              j = ev_lkup[area_lvl2];
              l2_val = ev_core[usct,area_lvl2];
              oval = val;
              val = 0.01 * l2_val * oval;
              printf("___ got lvl2_area %s area= %s, l2_val= %f, oval= %f, nval= %f, usct= %s\n", area_lvl2, area, l2_val, oval, val, usct) > "/dev/stderr";
              ev_count[j] -= val;
              j = ev_lkup[area_lvl1];
              ev_count[j] -= val;
              if (area_lvl1== "Retiring") {
                printf("___ got ret area= %s, val= %f, lvl= %d\n", area, val, ev[i,4]) > "/dev/stderr";
              }
           }
         }
      }
      i = ev_lkup[area];
      ev_count[i] += val;
      if (area == "Retiring.Base.Other") { printf("%s= %f\n", ev[i,1], ev_count[i]) > "/dev/stderr"; }
      #if (use_unit == "% Stalls") {
      #  printf("stalls[%d] val = %d tot= %d\n", i, val, ev_count[i]) > "/dev/stderr";
      #}
    }
    END{
      area = "Retiring.Base.Other";
      ev_mx_init = ev_mx;
      i = ev_lkup[area];
      if (area == "Retiring.Base.Other") { printf("end: %s= %f\n", ev[i,1], ev_count[i]) > "/dev/stderr"; }
      sv_ev_count_tot = 0.0;
      for (i=1; i <= ev_mx_init; i++) {
         sv_ev_count_tot += ev_count[i];
      }
      i = ev_lkup["Retiring"];
      printf("Retiring count= %f\n", ev_count[i]) > "/dev/stderr";
      #if (ev_count[i] == 0 && (use_unit == "% Stalls" || use_unit == "% Clocks")) {
      #   ev_count[i] = util_idx * 100.0 - sv_evt_count_tot;
      #}
      
      #ev[++i,1]="Retiring"; ev[i,2]="Issued uops that eventually get retired. Retiring of 50% means an IPC of 2"; ev[i,3]="Not_Stalled";
      tu = 0.0;
      tutil=0.0;
      for (i=1; i <= util_idx; i++) {
        usct = util_list[i];
        autil = sv_util[usct,1];
        tutil += autil;
      }
      printf("tutil= %f, avg.tutil= %f\n", tutil, tutil/util_idx) > "/dev/stderr";
      tot_stall = 0.0;
      tot_unstall = 0.0;
      tot_halted = 0.0;
      for (i=1; i <= ev_mx_init; i++) {
          sum2 = 100.0*ev_count[i];
          if (sum2 <= 0.0) {
             continue;
          }
          printf("%s", ev[i,3]);
          for (j=1; j <= ev[i,4]; j++) {
            printf(";%s", ev_lvls[i,j]);
          }
          printf(" %d\n", sum2);
                 if (ev[i,3] == "Stalled") {
                    tot_stall += sum2;
                 }
                 if (ev[i,3] == "Not_Stalled") {
                    tot_unstall += sum2;
                  }
                  if (ev[i,3] == "Idle") {
                    tot_halted += sum2;
                  }
      }
      tot= tot_stall + tot_unstall + tot_halted;
      autil=tutil/util_idx;
        area = "Halted";
        if (autil > 0.0) {
            val = tot*(1.0-autil)/autil
        } else {
            val = tot;
        }
        tot_halted = val;
        printf("%s;%s %d\n", "Idle", "Halted", val);
      tot= tot_stall + tot_unstall + tot_halted;
      sv_ev_count_tot /= util_idx;
      printf("tot= %f, halted= %f, not_halted= %f, stall= %f, not_st= %f, sv_ev_count_tot= %f\n", tot, tot_halted, tot_stall+tot_unstall, tot_stall, tot_unstall, sv_ev_count_tot) > "/dev/stderr";
      printf("%%tot= %f, halted= %f, not_halted= %f, stall= %f, not_st= %f\n", tot/tot, tot_halted/tot, (tot_stall+tot_unstall)/tot, tot_stall/tot, tot_unstall/tot) > "/dev/stderr";
    }
    ' $FL
exit

