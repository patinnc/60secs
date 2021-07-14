      BEGIN{
        do_perlbench_subphase = 0;
        if (index(options, "do_perlbench_subphase{1}") > 0) {
          if (verbose > 0) {
            printf("got do_perlbench_subphase{1}\n") > "/dev/stderr";
          }
          do_perlbench_subphase = 1;
        }
        if (out_file == "") {
          out_file = "/dev/stdout";
        }
      }
      /  Rate Start: / {
        bm_nm = "";
        copies = 0;
        v = substr($5, 2, length($5)-2);
        tm_beg = v;
      }
      /  Rate End: / {
        v = substr($5, 2, length($5)-2);
        tm_end = v;
      }
    #Workload elapsed time (copy 24 workload 3) = 213.587487 seconds
    /Workload elapsed time .copy .* workload .*. = .* seconds/ {
      pos = index($7, ")");
      subphs = $7; if (pos > 1) { subphs = substr(subphs, 1, pos); }
      subphs += 0;
      subphs_arr[subphs] = $9+0;
      subphs_mx = subphs;
    }
      / base refrate ratio=/ {
        #printf("got cpu2017.001.log line= %s\n", $0) > "/dev/stderr";
        gsub(",", "", $0);
        bm_nm = $2;
        for (i=3; i <= NF; i++) {
          n = split($i, arr, "=");
          if (index($i, "ratio=") == 1)   { ratio = arr[2]; }
          if (index($i, "runtime=") == 1) { run_tm = arr[2]; }
          if (index($i, "copies=") == 1)  { copies = arr[2]; }
        }
        if (bm_nm != "" && (copies+0) >= 1) {
          if (!(bm_nm in bm_list)){
            bm_list[bm_nm] = ++bm_mx;
            bm_lkup[bm_mx] = bm_nm;
            bm_arr[bm_mx,"mx"] = 0;
          }
          bm_i = bm_list[bm_nm];
          bm_occ = ++bm_arr[bm_i,"mx"];
          ++b_mx;
          b_arr[b_mx,1] = bm_i;
          b_arr[b_mx,2] = bm_occ;
          b_arr[b_mx,"ratio"] = ratio;
          b_arr[b_mx,"run_tm"] = run_tm;
          b_arr[b_mx,"copies"] = copies;
          b_arr[b_mx,"beg"] = tm_beg;
          b_arr[b_mx,"end"] = tm_end;
          b_arr[b_mx, "subphs_mx"] = subphs_mx;
          for (i=1; i <= subphs_mx; i++) {
            b_arr[b_mx, "subphs", i] = subphs_arr[i];
          }
        }
      }
      END{
      if (verbose > 0) {
        printf("specint b_mx= %d\n", b_mx) > "/dev/stderr";
      }
        for(i=1; i <= b_mx; i++) {
          bm_i = b_arr[i,1];
          bm_o = b_arr[i,2];
          nm = bm_lkup[bm_i];
          ratio  = b_arr[i,"ratio"];
          run_tm = b_arr[i,"run_tm"];
          copies = b_arr[i,"copies"];
          tm_beg = b_arr[i,"beg"];
          tm_end = b_arr[i,"end"];
          if (sum_file != "") {
            printf("specint\tspecint\t%s\t\"SI %s %s %s\"\n", ratio, nm, "ratio", bm_o) >> sum_file;
            printf("specint\tspecint\t%s\t\"SI %s %s %s\"\n", run_tm, nm, "run_tm", bm_o) >> sum_file;
            printf("specint\tspecint\t%s\t\"SI %s %s %s\"\n", copies, nm, "copies", bm_o) >> sum_file;
            printf("specint\tspecint\t%s\t\"SI %s %s %s\"\n", tm_beg, nm, "beg_ts", bm_o) >> sum_file;
            printf("specint\tspecint\t%s\t\"SI %s %s %s\"\n", tm_end, nm, "end_ts", bm_o) >> sum_file;
          }
          if (do_perlbench_subphase == 1 && index(nm, "perlbench") > 0) {
            tm_off = 0.0;
            sfx[1] = "aaaa";
            sfx[2] = "bbbb";
            sfx[3] = "cccc";
            ev = b_arr[i,"subphs_mx"];
            #printf("%s_%s %.3f %.3f %.3f\n", "perlb", ev, tm_beg, tm_beg, 0.0);
            for (j=1; j <= ev; j++) {
              v = b_arr[i,"subphs", j];
              nml = "500.perl" sfx[j] "" j;
              printf("%s %.3f %.3f %.3f\n", nml, tm_beg, tm_beg+v, v) > out_file;
              if (sum_file != "") {
                printf("specint\tspecint\t%s\t\"SI %s %s %s\"\n", v, nml, "run_tm", bm_o) >> sum_file;
              }
              tm_beg += v;
            }
          } else {
            printf("%s_%s %.3f %.3f %.3f\n", nm, bm_o, tm_beg, tm_end, tm_end-tm_beg) > out_file;
          }
        }
        if (out_file != "/dev/stdout") {
          close(out_file);
        }
        if (sum_file != "") {
          close(sum_file);
        }
      }
