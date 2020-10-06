      function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
      function rtrim(s) { sub(/[ \t\r\n,]+$/, "", s); return s }
      function trim(s) { return rtrim(ltrim(s)); }
  BEGIN {
    if (sep_in == "") {
      sep_in = ",";
    }
    flds[++flds_mx] = "benchmarkParameters;cpus";
    flds[++flds_mx] = "benchmarkParameters;connections";
    flds[++flds_mx] = "benchmarkParameters;concurrency";
    flds[++flds_mx] = "benchmarkParameters;maxRequests";
    flds[++flds_mx] = "benchmarkParameters;maxDuration";
    flds[++flds_mx] = "benchmarkParameters;maxRPS";
    flds[++flds_mx] = "latencies;0.5000";
    flds[++flds_mx] = "latencies;0.9000";
    flds[++flds_mx] = "latencies;0.9500";
    flds[++flds_mx] = "latencies;0.9900";
    flds[++flds_mx] = "latencies;0.9990";
    flds[++flds_mx] = "latencies;0.9995";
    flds[++flds_mx] = "latencies;1.0000";
    flds[++flds_mx] = "summary;elapsedTimeSeconds";
    flds[++flds_mx] = "summary;totalRequests";
    flds[++flds_mx] = "summary;rps";
    yb_lst[++yb_lst_mx] = "req;ignoredPayload";
    yb_lst[++yb_lst_mx] = "req;responseSize";
    yb_lst[++yb_lst_mx] = "req;latencyMinNanos";
    yb_lst[++yb_lst_mx] = "req;latencyMaxNanos";
    for (i=1; i <= flds_mx; i++) {
      n = split(flds[i], arr, ";");
      str2 = arr[2];
      if (index(str2, ".") > 0) {
        str2 = "\""str2"\"";
      }
      flds_str[i,1]=arr[1];
      flds_str[i,2]=str2;
    }
    cmd="cat "infile ;
    infile_lines_mx=0;
    while ((cmd | getline) > 0) {
      ++infile_lines_mx;
      infile_lines[infile_lines_mx] = $0;
    }
    close(cmd);
    for (i=1; i <= flds_mx; i++) {
      str1 = flds_str[i,1];
      str2 = flds_str[i,2];
      cmd="cat "infile" | jq '.|delpaths([path(..?) as $p | select(getpath($p) == null) | $p])|select(."str1")|."str1"."str2"'";
      j = 0;
      structs_mx = 0;
      while ((cmd | getline) > 0) {
         structs_mx++;
         v = $0;
         if (str2 == "maxDuration") {
            gsub("\"", "", v);
            mn = 0;
            sc = 0;
            idx= index(v, "m");
            if (idx > 0) {
              mn = v + 0;
              v = substr(v, idx+1, length(v));
            }
            idx= index(v, "s");
            if (idx > 0) {
              sc = v + 0;
              #v = substr(v, idx+1, length(v));
            }
            v = mn * 60 + sc;
            #printf("mn= %s, v= %s, 0= %s\n", mn, v, $0);
         }
         if (str1 == "latencies") {
            idx= index(v, "µs");
            if (idx > 0) {
               gsub("µs", "", v);
               gsub("\"", "", v);
               v *= 0.001;
               #printf("v= %s, %f 0= %s\n", v, v, $0);
            }
            idx= index(v, "ms");
            if (idx > 0) {
               gsub("ms", "", v);
               gsub("\"", "", v);
               v += 0.0;
               #printf("v= %s, %f 0= %s\n", v, v, $0);
            }
         }
         if (verbose > 0) {
           printf("fld[%d,%d][%s,%s] = %s\n", i, structs_mx, str1, str2, v);
         }
         ln[i,structs_mx] = v;
      }
      #printf("cmd= %s\n", cmd);
      #system(cmd);
      close(cmd);
    }

    nfile="";
    i = length(infile);
    sb = substr(infile, i-4, i);
    if (sb == ".json") {
      nfile=substr(infile, 1, i-5) ".txt";
    }
    if (verbose > 0) {
      printf("nfile= %s, sb= %s\n", nfile, sb);
    }
str3="yab -P uns:...ompute-0:tchannel -t womfile   --concurrency 1  --per-peer-stats --service womf --procedure Womf::benchmarkHelper -r \"{\"req\": {\"ignoredPayload\":aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa, \"responseSize\":256, \"latencyMinNanos\":10000000, \"latencyMaxNanos\":10000001}}\" --rps 8000 -d 10s";
    cmd = "grep '^yab ' " nfile;
    j=0;
    while ((cmd | getline) > 0) {
      j++; # if (j==1){$0=str3;}
      n = split($0, arr, "");
      b = -1;
      e = -1;
      for (i=1; i <= n; i++) {
        if (b == -1 && arr[i] == "{") { b = i; }
        if (arr[i] == "}") { e = i; }
      }
      str = substr($0, b, e-b+1);
      #cmd="echo "str" | jq '.|delpaths([path(..?) as $p | select(getpath($p) == null) | $p])|select(."arr[1]")|."arr[1]"."str2"'";
      yb_cmds[++yb_cmds_mx] = str;
      yb_cmd_lines[yb_cmds_mx] = $0;
      #printf("n= %s b= %d e= %d str= %s\n", n, b, e, str);
      if (verbose > 0) {
        printf("yb_cmds[%d]= %s\n", yb_cmds_mx, yb_cmds[yb_cmds_mx]);
      }
    }
    close(cmd);
#$0 = "yab -P uns:...ompute-0:tchannel -t womfile   --concurrency 1  --per-peer-stats --service womf --procedure Womf::benchmarkHelper -r "{"req": {"ignoredPayload":aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa, "responseSize":256, "latencyMinNanos":10000000, "latencyMaxNanos":10000001}}" --rps 8000 -d 10s";
    cmd = "grep ' beg yab ' " nfile;
    while ((cmd | getline) > 0) {
      ++yab_beg_mx;
      yab_beg[yab_beg_mx,1] = $1+0.0;
      yab_beg[yab_beg_mx,2] = $4+0;
      if (verbose > 0) {
        printf("yab_beg[%d]= %s, rps= %s\n", yab_beg_mx, $1, $4);
      }
    }
    close(cmd);
    cmd = "grep ' end yab ' " nfile;
    while ((cmd | getline) > 0) {
      ++yab_end_mx;
      yab_end[yab_end_mx,1] = $1+0.0;
      yab_end[yab_end_mx,2] = $4+0;
      if (verbose > 0) {
        printf("yab_end[%d]= %s, rps= %s\n", yab_end_mx, $1, $4);
      }
    }
    close(cmd);
    if (infra_fl != "") {
      cmd = "cat " infra_fl;
      b = 0;
      mut_col = -1;
      while ((cmd | getline) > 0) {
        if ($0 == "") {
          break;
        }
        if ($1 == "epoch") {
          for (i=1; i <= NF; i++) {
           mut_hdr[i] = $(i);
           if (verbose > 0) {
             printf("mut_hdr[%d]= %s\n", i, mut_hdr[i]);
           }
           if ($(i) == "muttley") {
              mut_col = i;
           }
          }
          b= 1;
        } else if (b == 1) {
          ++mut_mx;
          for (i=1; i <= NF; i++) {
           infra_ln[mut_mx,i] = $(i) + 0;
          }
          mut_arr[mut_mx,1] = $1;
          if (mut_col > -1) {
            mut_arr[mut_mx,2] = $(mut_col) + 0.0;
          }
          #printf("infra_ln[%d]= %s\n", mut_mx, $0);
          if (verbose > 0) {
            printf("mut_arr[%d]= %s, %s\n", mut_mx, mut_arr[mut_mx,1], mut_arr[mut_mx,2]);
          }
        }
      }
      close(cmd);
    }
    if (yab_beg_mx > 0 && yab_end_mx > 0 && yab_beg_mx == yab_end_mx && mut_mx > 0) {
       if (verbose > 0) {
         printf("yab_beg_mx= %d yab_end_mx= %d mut_mx= %d\n", yab_beg_mx, yab_end_mx, mut_mx);
       }
       for (i=1; i <= yab_beg_mx; i++) {
          b = yab_beg[i,1];
          e = yab_end[i,1];
          cpu_sum[i] = 0.0;
          cpu_n[i] = 0;
          for(j=2; j <= mut_mx; j++) {
             mb = mut_arr[j-1,1];
             me = mut_arr[j,1];
             if (mb >= b && me <= e) {
                cpu_sum[i] += mut_arr[j,2];
                cpu_n[i]++;
             }
          }
          if (cpu_n[i] > 0) {
            cpu_avg[i] = cpu_sum[i]/cpu_n[i];
          } else {
            cpu_avg[i] = 0.0;
          }
       }
    }
    host_num_cpus="";
    host_cpu_model="";
    if (lscpu_file != "") {
      cmd = "cat " lscpu_file;
      while ((cmd | getline) > 0) {
        if ($1 == "CPU(s):") {
          host_num_cpus = $2;
        }
        if (index($0, "Model name:") == 1) {
          $1 = ""; $2 = "";
          host_cpu_model = trim($0);
        }
      }
      close(cmd);
    }
    #str = "{\"req\": {\"ignoredPayload\":aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa, \"responseSize\":256, \"latencyMinNanos\":10000000, \"latencyMaxNanos\":10000001}}";
    #yb_cmds[++yb_cmds_mx] = str;
    for (yb=1; yb <= yb_cmds_mx; yb++) {
      lkfor = "ignoredPayload";
      str = yb_cmds[yb];
      i = index(str, lkfor);
      if (i > 0) {
        n = split(str, arr, "");
        k = i+length(lkfor);
        for (j=k; j < n; j++) {
          if (arr[j] == "," || arr[j] == "}") {
             break;
          }
        }
        lhs = substr(str, 1, k+1);
        mid = substr(str, k+2, j-(k)-2);
        rhs = substr(str, j, length(str));
        str = lhs"\""mid"\""rhs;
        #printf("lhs= '%s', mid= '%s', rhs= '%s'\n", lhs, mid, rhs);
      }
      for (i=1; i <= yb_lst_mx; i++) {
        n = split(yb_lst[i], arr, ";");
        str2 = arr[2];
        if (index(str2, ".") > 0) {
          str2 = "\""str2"\"";
        }
        yb_lst_str[i,1]=arr[1];
        yb_lst_str[i,2]=str2;
        cmd="echo '"str"' | jq '."arr[1]"."str2"'";
        #printf("cmd= %s\n", cmd);
        while ((cmd | getline) > 0) {
           v = $0;
           if (str2 == "ignoredPayload") {
             yb_lst_str[i,2]=str2 "Size";
              if (v == "null") {
                v = 0;
              } else {
                v = length(v);
              }
           }
           yb_out[yb,i] = v;
           if (verbose > 0) {
             printf("yb_out[%d,%d][%s,%s]= %s\n", yb, i, arr[1],str2, $0);
           }
        }
        #system(cmd);
        close(cmd);
      }
    }
    if (verbose > 0) {
      printf("yb_lst_mx= %d, structs_mx= %d, yb_cmds_mx= %d, flds_mx= %d\n", yb_lst_mx, structs_mx, yb_cmds_mx, flds_mx);
    }
#title   summary sheet   summary type    copy
#hdrs    2       0       -1      7       -1
    trow++;
    printf("title\t%s\tsheet\t%s\ttype\tcopy\n", "yab table", "yab results") > ofile;
    trow++;
    printf("hdrs\t%d\t%d\t%d\t%d\t-1\n", trow+3, 0, -1, flds_mx+yb_lst_mx+2) > ofile;
    printf("lscpu_num_cpus%s%s\n", sep_in, host_num_cpus) > ofile;
    printf("lscpu_cpu_model%s%s\n", sep_in, host_cpu_model) > ofile;
    sep = sep_in;
    printf("%s%s", sep, "yab") > ofile; 
    printf("%s%s", sep, "CPUs used") > ofile;
    for (i=1; i <= flds_mx; i++) {
       str1 = flds_str[i,1];
       str = flds_str[i,2];
       printf("%s%s", sep, str1) > ofile;
    }
    for (i=1; i <= yb_lst_mx; i++) {
       str = yb_lst_str[i,1];
       printf("%s%s", sep, str) > ofile;;
    }
    printf("\n") > ofile;;
    printf("%s%s%s", "run_num", sep, "host_num") > ofile;;
    printf("%s%s", sep, "avg.cpus") > ofile;
    sep = sep_in;
    for (i=1; i <= flds_mx; i++) {
       str1 = flds_str[i,1];
       str = flds_str[i,2];
       if (str1 == "latencies") {
         if (index(str, "0.5000") > 0) { str = "p50";}
         if (index(str, "0.9000") > 0) { str = "p90";}
         if (index(str, "0.9500") > 0) { str = "p95";}
         if (index(str, "0.9900") > 0) { str = "p99";}
         if (index(str, "0.9990") > 0) { str = "p99.9";}
         if (index(str, "0.9995") > 0) { str = "p99.95";}
         if (index(str, "1.0000") > 0) { str = "p100";}
       }
       printf("%s%s", sep, str) > ofile;;
    }
    for (i=1; i <= yb_lst_mx; i++) {
       str = yb_lst_str[i,2];
       printf("%s%s", sep, str) > ofile;;
    }
    printf("\n") > ofile;;
    sep = sep_in;
    for (j=1; j <= structs_mx; j++) {
      printf("%s%s%s", j-1, sep, host_num) > ofile;;
      printf("%s%.3f", sep, cpu_avg[j]) > ofile;
      for (i=1; i <= flds_mx; i++) {
        str = ln[i,j];
        if (str == "null") { str = ""; }
        printf("%s%s", sep, str) > ofile;;
      }
      for (i=1; i <= yb_lst_mx; i++) {
        str = yb_out[j,i];
        if (str == "null") { str = ""; }
        printf("%s%s", sep, str) > ofile;;
      }
      printf("\n") > ofile;;
    }
    printf("\n") > ofile;;
    for (i=1; i <= yb_cmds_mx; i++) {
      printf("%s%s%s\n", i-1, sep, yb_cmd_lines[i]) > ofile;;
      got_beg = 0;
      for (j=1; j <= infile_lines_mx; j++) {
        if (infile_lines[j] == "{" && index(infile_lines[j+1], "\"body\"") > 0) {
          got_beg++;
        }
        if (got_beg > i) {
           break;
        }
        if (got_beg == i) {
           gsub("\"", "", infile_lines[j]);
           printf("%s\"%s\"\n", sep_in, infile_lines[j]) > ofile;
        }
      }
    }
    exit;
  }
function tot_compare(i1, v1, i2, v2,    l, r)
{
    m1 = tot[i1];
    m2 = tot[i2];
    if (m2 < m1)
        return -1
    else if (m1 == m2)
        return 0
    else
        return 1
}
END {
    exit;
    if (sum_file != "") {
      printf("-------------sum_file= %s, proc_mx= %d\n", sum_file, proc_mx) > "/dev/stderr";
      printf("sum_file= %s\n", sum_file);
      for(i=1; i <= proc_mx; i++) {
         j = res_i[i];
         printf("infra_procs\tinfra procs cpusecs\t%.3f\t%s\n", tot[j], proc_lkup[j]) >> sum_file;
      }
      close(sum_file);
      #printf("%f\n", 1.0/0.0); # force an error
    }

}
