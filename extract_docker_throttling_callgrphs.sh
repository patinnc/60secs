#!/bin/bash

INF=docker_cpu_stats.txt

if [ "$1" == "" ]; then
IDIR=archive_aura_callgraphs_v01_no_prf_dat
else
IDIR=$1
fi

LIST=($(find $IDIR -name docker_cpu_stats.txt))

for ((i=0; i < ${#LIST[@]}; i++)); do

RESP=$(grep sigusr2 ${LIST[$i]})
if [ "$RESP" == "" ]; then
  continue
fi

IDIR=$(dirname ${LIST[$i]})

echo "___________ onum= $i dir= $IDIR"

awk -v dir="$IDIR" -v onum=$i '
#__docker_stat 1638012722.414496 0  11 1 316373496
  /^__docker_stat / {
    ds_epch = $2;
    # field 4-6 are the docker cpu.stat fields
    #  nr_periods: how many full periods have been elapsed.
    #  nr_throttled: number of times we exausted the full allowed bandwidth
    #  throttled_time: total time the tasks were not run due to being overquota
    ds_period = $4+0;
    ds_intrvl = ds_period * 0.1; # each period is 0.1 seconds
    ds_throttle = $6+0;
    if (ds_throttle > 0) {
      printf("onum= %d %thr= %.6f\n", onum, 100.0 * ds_throttle/(0.1*ds_period * 1e6));
    }
  }
  /^__docker_sigusr2 / {
# so we actually saw throttling and sent sigusr2 to dump call stacks.
# Now we look for a perf*.dat*.txt file at the time (or after the time) of the sigusr2
# we might have back to back dump files if the throttling occurred during 2 consecutive seconds.
# I have a dumb loop to look for dat.txt files with date strings up to 10 seconds after the sigusr2 time. Seems to work.

    cid = $2;
    elap = $3;
    epch = $4;
    dtstr= $5;

# __docker_sigusr2 0 15062 1638012722.414496 20211127113202
#           1 1
# 1   5 7 9 1 3
# 20211127113202
# __docker_sigusr2 0 15062 1638012722.414496 2021/11/27_11:32:02
    dt_rt= substr(dtstr, 1, 8);
    dt2mm= substr(dtstr, 1, 12);
    dt2ss= substr(dtstr, 1, 14);
    dt_hh= substr(dtstr, 9, 2);
    dt_mm= substr(dtstr, 11, 2);
    dt_ss= substr(dtstr, 13, 2);
    printf("hh= %s mm = %s ss= %s, dt= %s\n", dt_hh, dt_mm, dt_ss, dtstr);
    got_it=0;
    for (i=0; i < 10; i++) {
      udt = dt2ss+i;
      ufl = dir "/prf_" cid ".dat." udt "*.txt";
      if (system("test -f " ufl)==0) {
        got_it=1;
        break;
      }
    }
    if (got_it == 1) {
      sv_mx++;
      cmd = "ls " ufl " | head -1";
      cmd | getline line;
      close(cmd);
      print line;
      sv_ufl[sv_mx,"nm"] = line;
      sv_ufl[sv_mx,"epch"] = epch;
      sv_ufl[sv_mx,"interval"] = ds_intrvl;

    } else {
      printf("missed finding match for prf file ufl= %s dt2ss= %s\n", ufl, ddt2ss) > "/dev/stderr";
    }
  }
  END{
#      michelangelo-pr 374019 [005] 9233946.162347:   10101010 cpu-clock: 
# now we have the list of call stack perf .dat.txt files.
# Read each .dat.txt file.
# Now we know that the file was written within a second of the throttling.
# That is, throttling occurred in at least one 0.1 docker time slot.
# but we dont know exactly when that time slot began or ended.
# We do know each time slot interval is 0.1 second.
# So we take the last time stamp and say "this is when we sent the sigusr2"
# and assume the throttling occurred during the previous second (or maybe a little more).
# Now we could just dump the callstack and let the user try to figure out what looks "weird".
# But we can do better than that.
# We can bucket the call stacks by 0.1 second intervals. Then you can just look at a time bucket
# and say "this bucket shows throttling" because if shows >= max allowed cpu usage.
#
# The time bucket is each to do. Just insert a "time_0.xx" string as the bottom-most module name.
# That is: all the call stacks occuring in the interval "sigusr2 time" to "sigusr2 time - 0.1 sec" will be
# in the "time_0.1" bucket, all the calls stacks occurring in the interval sigusr2-0.1 -> sigusr-0.2) will be
# in the "time_0.2" bucket and so on. I think after sigusr2-1.2 seconds I just clump all those call stacks togther.
# The flamegraph scripts treat the "time_0.1" string like a module name.
# All that is great, but the code below also has to parse the perf call stack stuff.

    for (i=1; i <= sv_mx; i++) {
      ufl = sv_ufl[i,"nm"];
      cg=0;
      line_num=-1;
      while ((getline < ufl) > 0) {
        line_num++;
        # this xt-h- stuff just reduces some process name. Instead of see 60 xt-h-xx process just map them to 1 xt-h process
        if ($1 != "" && substr($1, 1, 5) == "xt-h-") {
          $1 = "xt-h";
        }
        sv_lines[i,line_num] = $0;
        if ($0 == "") { continue; }
        if (substr($0, 1, 1) != "\t") {
          # this is not a call graph line. Look for the cpu number line [001]. The process name can have spaces (i think) so get the cpu string and work backwards.
          cg++;
          sv_ufl[i, "cg_mx"] = cg;
          got_it=0;
          cpu_fld = -1;
          for (k=1; k <= NF; k++) {
            if ($k ~ /^\[[0-9][0-9][0-9]\]$/) {
              got_it = 1;
              #printf("match %s\n", $k);
              cpu_fld = k;
              break;
            } 
          }
          if (cpu_fld == -1) {
            printf("missed cpu fld for line[%d]= %s\n", line_num, $0);
            exit(1);
          }
          mod = $1;
          for (k=2; k <= cpu_fld -2; k++) {
            mod = mod " " $k;
          }
          if (substr(mod, 1, 4) == "xt-h") {
            mod = "xt-h";
          }
#line[66562] tm= 3614141.041924, tm_beg[1]= 3614137.655765, str= tcheck 465830 [019] 3614141.041924:   10101010 cpu-clock: 
#line[66584] tm= 0.000000, tm_beg[1]= 3614137.655765, str= Reference Handl 14579 [029] 3614141.045519:   10101010 cpu-clock: 
#line[66591] tm= 3614141.046863, tm_beg[1]= 3614137.655765, str= xt-h 16253 [015] 3614141.046863: 10101010 cpu-clock:

          # get list of modules
          if (!((i,mod) in mod_list)) {
            mod_list[i,mod] = ++mod_mx[i];
            mod_lkup[i,mod_mx[i]] = mod;
            mod_inst[i,mod] = 0;
          }
          ++mod_inst[i,mod];
          # save timestamp module name, init number of call graph lines to 0, save linenumber we are at in file (for debugging).
          tm = $(cpu_fld+1)+0;
          sv_lines_time[i,line_num] = tm;
          cg_arr[i, cg, "tm"]  = tm;
          cg_arr[i, cg, "mod"] = mod;
          cg_arr[i, cg, "mx"]  = 0;
          cg_arr[i, cg, "line_num"]  = line_num;
        } else {
          # so we are in a call graph line. Skip the address offset. save the module/function info
          $1 = "";
          $1 = $1;
          u = ++cg_arr[i, cg, "mx"]
          cg_arr[i, cg, "lines", u ] = $0;
        }
      }
      close(ufl)
      # so we have read the perf dat txt file and got call stacks
      tm_end[i] = tm;
      cg_mx[i] = cg;
      printf("\n\ndir %d module counts for file %d, tm_end= %f\n", onum, i, tm_end[i]);
      for (j=1; j <= mod_mx[i]; j++) {
        v = mod_lkup[i,j];
        printf("%-5d %s\n", mod_inst[i,v], v);
      }
      tm_beg[i] = tm_end[i] - ds_intrvl; # so if the interval is 1 second then the time we want is end_time - 1.0 seconds
      #tm_beg[i] = tm_end[i] - 4*ds_intrvl;
      printf("tm_beg[%d] = %f, tm_end[%d]= %f, ds_intrvl= %f\n", i, tm_beg[i], i, tm_end[i], ds_intrvl);
      sv_line_num[i] = line_num;
      bef=0;
      aft=0;
      bef_line= -1;
      tm_0 = cg_arr[i,1,"tm"];
      tm_1 = cg_arr[i,cg_mx[i],"tm"];
      #
      # find the lines before the sigusr2 time
      for (j=1; j <= cg_mx[i]; j++) {
        v = cg_arr[i,j,"line_num"];
        #printf("line[%d] tm= %f, tm_beg[%d]= %f, str= %s\n",  v, cg_arr[i,j,"tm"],i, tm_beg[i], sv_lines[i,v]);
        if (cg_arr[i,j,"tm"] < tm_beg[i]) {
          bef++;
          bef_line= v;
        } else {
          aft++;
        }
      }
      printf("__onum= %d file %d, bef= %d aft= %d, line_num= %d tm_covered_in_file= %f\n", onum, i, bef, aft, bef_line, tm_1-tm_0);
      for (k=0; k < 2; k++) {
        onum_str = sprintf("%.2d", onum);
        fl = "tmp_" i "_" k".txt";
        flsc = "tmp_" i "_" k"_sc.txt";
        flsc1 = "tmp_" i "_" k"_sc1.txt";
        flsvg = "tmp_" onum_str "_" i "_" k"_sc.svg";
        if (k==0) {
          # This is the case of the call stacks before the interval with the throttling
          # We can just do a standard stackcollapse-perf.pl -> flamegraph.pl for this case
          for (j=0; j < bef_line; j++) {
            printf("%s\n", sv_lines[i, j]) > fl;
          }
          close(fl);
          cmd = "perl ~/repos/FlameGraph/stackcollapse-perf.pl " fl " > " flsc;
          printf("cmd= %s\n", cmd);
          system(cmd);
          close(cmd);
          cmd = "~/repos/FlameGraph/flamegraph.pl " flsc " > " flsvg;
          printf("cmd= %s\n", cmd);
          system(cmd);
          close(cmd);
        }
        if (k==1) {
          # The call stacks for the interval with cpu throttling.
          for (j=bef_line; j <= sv_line_num[i]; j++) {
            # insert the fake "time_xx" prefix to the module name
            if (sv_lines_time[i,j] != "") {
              tm_dff = int(10 * (sv_lines_time[i,j] - tm_beg[i]));
              printf("time_%.2d_%s\n", tm_dff, sv_lines[i,j]) > fl;
            } else {
               printf("%s\n", sv_lines[i, j]) > fl;
            }
          }
          close(fl);
          cmd = "perl ~/repos/FlameGraph/stackcollapse-perf.pl " fl " > " flsc;
          printf("cmd= %s\n", cmd);
          system(cmd);
          close(cmd);
          # read back in the collapsed stack list and break the time_xx_{moduleName} into time_xx;ModuleName so that flamegraph groups everything by time_xx bucket
          while ((getline < flsc) > 0) {
            if (substr($1, 1, 5) == "time_") {
              $1 = substr($1, 1, 7) ";" substr($1, 9);
              $1 = $1;
            }
            printf("%s\n", $0) > flsc1;
          }
          close(flsc1);
          cmd = "~/repos/FlameGraph/flamegraph.pl " flsc1 " > " flsvg;
          printf("cmd= %s\n", cmd);
          system(cmd);
          close(cmd);
        }
      }
    }
  }' $IDIR/$INF

done
