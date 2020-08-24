function read_specint_line() {
       if (index($0, "  Rate Start: ") == 1) {
	   FNM=ARGV[ARGIND];
	   if(FNM != runs_FNM) {
             runs = -1;
           }
	   runs_FNM = FNM;
           ++runs;
           rate_beg=substr($5, 2, length($5)-2);
           return;
       }
       if (index($0, "  Rate End: ") == 1) {
           rate_end=substr($5, 2, length($5)-2);
           return;
       }
       if (match($0, /^ Run .* base refrate ratio=.*, runtime=.*, copies=.*, /)) {
        #/^ Run .* base refrate ratio=.*, runtime=.*, copies=.*, / 
        # Run 531.deepsjeng_r base refrate ratio=2.40, runtime=477.559603, copies=1, threads=1, power=0.00W, temp=0.00 degC, humidity=0.00%
        #if (match(FNM, /CPU2017.[0-9][0-9][0-9].log$/)) {
           bm_mx++;
           bm_arr[bm_mx,"nm"] = $2;
           n = split($5, arr, /[=,]/);
           bm_arr[bm_mx,"score"] = arr[2];
           n = split($6, arr, /[=,]/);
           bm_arr[bm_mx,"runtm"] = arr[2];
           n = split($7, arr, /[=,]/);
           bm_arr[bm_mx,"copies"] = arr[2];
           bm_arr[bm_mx,"runs"] = runs;
           bm_arr[bm_mx,"rate_beg"] = rate_beg;
           bm_arr[bm_mx,"rate_end"] = rate_end;
           return;
           #printf("got cpu2017.001.log[%d] bm= %s, ratio= %s, run_tm= %s, copies= %s ln= %s file= %s\n",
           #   bm_mx, bm_arr[bm_mx,"nm"], bm_arr[bm_mx,"score"], bm_arr[bm_mx,"runtm"], bm_arr[bm_mx,"copies"], $0, FNM);
           #exit;
        #}
      }
}

function write_specint_summary(sum_file2,  ii, n, bm_nm, arr, out_lines) {
       out_lines="";
       if (bm_mx > 0) {
          #printf("write_specint_summary: sum_file= %s, bm_mx= %d\n", sum_file2, bm_mx) > "/dev/stderr";
          for (ii=1; ii <= bm_mx; ii++) {
          bm_nm = bm_arr[ii,"nm"];
          n = split(bm_arr[ii,"nm"], arr, "."); if (n == 2) { bm_nm = arr[2]; }
          printf("\tspecint\t%s\t%s\n", bm_nm, "specint_substest") >> sum_file2;
          printf("\tspecint\t%s\t%s\n", bm_arr[ii,"score"], "specint_score") >> sum_file2;
          printf("\tspecint\t%s\t%s\n", bm_arr[ii,"runtm"], "specint_run_time") >> sum_file2;
          printf("\tspecint\t%s\t%s\n", bm_arr[ii,"copies"], "specint_copies") >> sum_file2;
          printf("\tspecint\t%s\t%s\n", bm_arr[ii,"runs"], "specint_run") >> sum_file2;
          printf("\tspecint\t%s\t%s\n", bm_arr[ii,"rate_beg"], "specint_beg_ts") >> sum_file2;
          printf("\tspecint\t%s\t%s\n", bm_arr[ii,"rate_end"], "specint_end_ts") >> sum_file2;
          }
       }
}
