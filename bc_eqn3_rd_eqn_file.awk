{ 
  if (1==2) {
  eqn = $0;
  arg_arr[1] = 1;
  verbose = 0;
  bc_eqn_arr_init(++kmx, eqn);
  bc_eqn_arr[kmx,"hdr"]="eqn " kmx;
  #bc_eqn_arr[kmx,"typ_match"] = "require_any";
  #printf("bc_eqn_arr[%d,got_row_vars]=%d ==? bc_eqn_arr[%d,uses_row_vars]=%d\n", kmx, bc_eqn_arr[kmx,"got_row_vars"], kmx, bc_eqn_arr[kmx,"uses_row_vars"]);
  bc_eqn_arr[kmx,"got_row_vars"] = bc_eqn_arr[kmx,"uses_row_vars"];
  val = bc_eqn_evalArithmeticExp(bc_eqn_arr[kmx, "eqn"], 3, arg_arr, verbose, kmx) + 0.0;
  printf("got %s \"%s\" = %s\n", bc_eqn_arr[kmx,"hdr"], $0, val);
  #v = "var1";
  #  printf("get bc_eqn_glbl_var_arr[%s] = %s\n", v, bc_eqn_glbl_var_arr[v]);
  }
}  
FILENAME == bc_eqn3_eqn_file {
  #printf("flnm= %s, a, line[%d]= %s\n", FILENAME, FNR, $0);
  if (length($0) == 0 || substr($1, 1,1) == "#") {
    next;
  }
  #printf("flnm= %s, b, line[%d]= %s\n", FILENAME, FNR, $0);
  if ($1 == "exit") {
    exit(0);
  }
  if ($1 == "eqn:") {
    #printf("flnm= %s, c, line[%d]= %s\n", FILENAME, FNR, $0);
    pos = index($0, $1);
    arg_arr[1] = 1;
    use_this_eqn = 1;
    eqn = substr($0, pos+4, length($0));
    gsub(/^[ ]+/, "", eqn);
    gsub(/[ ]+$/, "", eqn);
    arr[1] = "min";
    arr[2] = "max";
    arr[3] = "sqrt";
    str = eqn;
    for (i=1; i <= 3; i++) {
      if (index(eqn, arr[i]"(") > 0) {
        if (index(eqn, arr[i]"((") == 0) {
          printf("if you use %s(x,y) in an equation you have to enclose x and y in parens like %s((x),(x)) so that the values will be resolved before the %s() operation\n",
             arr[i], arr[i], arr[i]);
          printf("see eqn below. skipping this equation\n");
          printf("%s\n", eqn);
          use_this_eqn = 0;
          next;
        }
        if (i < 3 && index(eqn, "),(") == 0) {
          printf("if you use %s(x,y) in an equation you have to enclose x and y in parens like %s((x),(x)) so that the values will be resolved before the %s() operation\n",
             arr[i], arr[i], arr[i]);
          printf("this script expects to see a \"),(\". Didn't find it. see eqn below. skipping this equation\n");
          printf("%s\n", eqn);
          use_this_eqn = 0;
          next;
        }
      }
    }
    if (index(eqn, "^") > 0) {
        pos = index(eqn, ")^(");
        if (pos == 0) {
          pos = index(eqn, "^");
          printf("if you use the ^ exponentiation operator (like x^y for x raised to the power y) then you must enclose the \"x\" and the \"y\" in parens like (x)^(y) so that the values will be resolved before the ^ operation\n");
          printf("this script expects to see a \")^(\". Didn't find it. see eqn below. skipping this equation\n");
          printf("%s\n", eqn);
          use_this_eqn = 0;
          next;
        }
    }
    n = split(eqn, arr, "");
    v = 0;
    j = 0
    for (i=1; i <= n; i++) {
       if (arr[i] == "(") { j=i; v++; }
       if (arr[i] == ")") {
         v--; 
         if (v < 0) {
          use_this_eqn = 0;
          printf("error in equation below. Got more \")\" than \"(\" at pos= %d. skipping equation\n", i);
          printf("%s\n", eqn);
          for (j=1; j < i; j++) { printf(" "); }
          printf("^\n");
          next;
         }
       }
    }
    if (v != 0) {
          use_this_eqn = 0;
          printf("error in equation below. Got more \"(\" than \")\" at pos= %d. skipping equation\n", j);
          printf("%s\n", eqn);
          next;
    }
    bc_eqn_arr_init(++kmx, eqn);
    got_all = bc_eqn_got_all_needed_variables(kmx, res_arr);
    if (verbose > 0) {
    printf("nw kmx= %d, bc_eqn_err_num= %d, uses_row_vars= %d, got_row_vars= %d got_all= %d need_vars= %d, got_vars= %d eqn= %s\n",
        kmx, bc_eqn_err_num, bc_eqn_arr[kmx,"uses_row_vars"], bc_eqn_arr[kmx,"got_row_vars"], got_all, res_arr["need_vars"], res_arr["need_vars"],  eqn);
    }
    next;
  }
  if ($1 == "chart_def:" || $1 == "chart_title:" || $1 == "chart_select_str:") {
    pos = index($0, ":");
    v0 = substr($0, 1, pos-1);
    v = substr($0, pos+1, length($0));
    gsub(/^[ ]+/, "", v0);
    gsub(/[ ]+$/, "", v0);
    gsub(/^[ ]+/, "", v);
    gsub(/[ ]+$/, "", v);
    if ($1 == "chart_def:") {
      bc_eqn_chart_mx++;
    }
    bc_eqn_charts[bc_eqn_chart_mx, v0] = v;
    printf("_bc_eqn_charts[%d]: %s= %s\n", bc_eqn_chart_mx, v0, v);
    next;
  }
  if ($1 == "hdr:" || $1 == "hdr_ps:" || $1 == "hdr_alias:" || $1 == "hdr_alias_factor:" || $1 == "tag_ps:" || $1 == "charts:") {
    if (use_this_eqn != 1) { next;}
    pos = index($0, ":");
    v0 = substr($0, 1, pos-1);
    v = substr($0, pos+1, length($0));
    gsub(/^[ ]+/, "", v0);
    gsub(/[ ]+$/, "", v0);
    gsub(/^[ ]+/, "", v);
    gsub(/[ ]+$/, "", v);
    bc_eqn_arr[kmx,v0]= v;
    if ($1 == "charts:") {
      printf("ck bc_eqn_charts charts tag[%d] chrt= %s\n", kmx, v) > "/dev/stderr";
    }
    #printf("eqn[%d] hdr= %s\n", kmx, v);
    next;
  }
  if ($1 == "options:") {
    if (use_this_eqn != 1) { next;}
    pos = index($0, $1);
    v = substr($0, pos+8, length($0));
    gsub(/^[ ]+/, "", v);
    gsub(/[ ]+$/, "", v);
    bc_eqn_arr[kmx,"options"]= v;
    next;
  }
  {
    printf("unrecognized line %s in equation file %s\n", $0, FILENAME) > "/dev/stderr";
  }
}
END{
  if (verbose > 0) {
  printf("kmx= %d, tm_mx= %d\n", kmx, tm_mx);
  }
  if (monitor_what == "per_sys") {
    bc_eqn_glbl_var_arr["monitor_per_system"] = 1;
  } else if (monitor_what == "per_pid") {
    bc_eqn_glbl_var_arr["monitor_per_thread"] = 1;
  } else if (bc_eqn_glbl_var_arr["thr_per_core"] == 2 &&
    ("power/energy-pkg/" in evt_list || "uncx_read_write" in evt_list || "qpi_data_bandwidth_tx" in evt_list || "qpi_data_bandwidth_txx" in evt_list)) {
    # this enables the topdown equations which assume 2 threads per core
    bc_eqn_glbl_var_arr["monitor_per_system"] = 1;
  } else {
    # this enables the topdown equations which assume collecting per cpu or per pid or 1 thread per core
    bc_eqn_glbl_var_arr["monitor_per_thread"] = 1;
  }
  for (key in bc_eqn_glbl_var_arr) {
     if (verbose > 0) {
       printf("bc_eqn_glbl_var_arr_sv key= %s\n", key);
     }
     bc_eqn_glbl_var_arr_sv[key] = bc_eqn_glbl_var_arr[key];
  }
  if (verbose > 0) {
    for (i=1; i <= evt_mx; i++) {
      printf("evt_lkup[%d]= %s\n", i, evt_lkup[i]);
    }
  }
  sv_verbose = verbose;
  for (i=1; i <= kmx; i++) {
    verbose = sv_verbose;
    if (index(bc_eqn_arr[i,"options"], "verbose") > 0) {
      verbose = 1;
    }
    if (bc_eqn_ck_if_got(i, 0) == 0) {
      continue;
    }
    j = 1;
    bc_eqn_arr[i,"got_row_vars"] = bc_eqn_arr[i,"uses_row_vars"];
      for (k=1; k <= evt_mx; k++) {
        bc_eqn_row_data[k] = evt_data[k,j];
        bc_eqn_tmr_data[k] = evt_data[k,j,"ns"];
        bc_eqn_inst_data[k] = evt_data[k,j,"inst"];
      }
      if (j == 1) {
        bc_eqn_glbl_var_arr["interval"] = tm_lkup[j]+0.0;
      } else {
        bc_eqn_glbl_var_arr["interval"] = tm_lkup[j]-tm_lkup[j-1];
      }
    hdr = bc_eqn_arr[i,"hdr"];
    val = bc_eqn_evalArithmeticExp(bc_eqn_arr[i, "eqn"], 3, arg_arr, verbose, i) + 0.0;
    if (bc_eqn_err_num == 0 || verbose > 0) {
      hdr = bc_eqn_arr[i,"hdr"];
      hdr_lc = tolower(hdr);
      eqn = bc_eqn_arr[i, "eqn"];
      if (bc_eqn_err_num == 0) {
        bc_eqn_glbl_var_arr[hdr_lc] = val;
        bc_eqn_glbl_var_arr_from_eqn[hdr_lc] = i;
        if (verbose > 0) {
          printf("saved val= %s from eqn with hdr= %s in glbl_var_arr[%s]= %s\n", val, hdr, hdr, bc_eqn_glbl_var_arr[hdr_lc]);
        }
      }
      pos = index(bc_eqn_arr[i,"options"], "if_not[");
      if (verbose > 0) {
        printf("got eqn[%d]: bc_err= %d %s \"%s\" = %s\n", i, bc_eqn_err_num, bc_eqn_arr[i,tolower("hdr")], eqn, val);
      }
      if (verbose > 0 && bc_eqn_err_num != 0) {
         if (verbose > 0) {
         printf("eqn[%d] got err %d str= %s\n", i, bc_eqn_err_num, bc_err);
         }
         v_sv = verbose;
         verbose = 1;
         val = bc_eqn_evalArithmeticExp(bc_eqn_arr[i, "eqn"], 3, arg_arr, verbose, i) + 0.0;
         verbose = v_sv;
         if (verbose > 0) {
         printf("bc_eqn_glbl_var_arr[%s] = %s\n", "itp_denom", bc_eqn_glbl_var_arr["itp_denom"]);
         }
      }
    }
  }
  i=0;
  for (key in bc_eqn_glbl_var_arr_used) {
    if (!(key in bc_eqn_glbl_var_arr_from_eqn)) {
      ++i;
      if (verbose > 0) {
        printf("used[%d] bc_eqn_glbl_var_arr[%s]\n", i, key);
      }
    }
  }
  i=0;
  for (key in bc_eqn_glbl_var_arr) {
    if (!(key in bc_eqn_glbl_var_arr_used)) {
      if (!(key in bc_eqn_glbl_var_arr_from_eqn)) {
        ++i;
        if (verbose > 0) {
        printf("not used[%d] bc_eqn_glbl_var_arr[%s]\n", i, key);
        }
      }
    }
  }
  i=0;
  ok_eqn_mx;
  for (i=1; i <= kmx; i++) {
    hdr = bc_eqn_arr[i,"hdr"];
    hdr_lc = tolower(hdr);
    if ((hdr_lc in bc_eqn_glbl_var_arr_from_eqn) && bc_eqn_glbl_var_arr_from_eqn[hdr_lc] == i) {
      if (verbose > 0) {
        printf("used equation[%d]= %s\n", i, hdr);
      }
      cb_mx=0;
      sb_mx=0;
      cb_mx_ii=0;
      sb_mx_ii=0;
      delete cb_list;
      delete cb_lkup;
      delete sb_list;
      delete sb_lkup;
      for (ii=i; ii > 0; ii--) {
        h2 = bc_eqn_arr[ii,"hdr"];
        h2_lc = tolower(h2_lc);
        if (ii == i || (h2_lc in cb_list && bc_eqn_glbl_var_arr_from_eqn[h2_lc] == ii)) {
           ;
        } else {
          continue;
        } 
      for (k=bc_eqn_dlm_min; k <= bc_eqn_dlm_max; k++) {
        for (j=1; j <= bc_eqn_var_mx[ii,k]; j++) {
          #got_vars += bc_eqn_var_found[kmx_in,k,j];
          #printf("bef eqn[%d], dlm[%d]= %s%s var_str[%d]= %s\n", kmx_in, k, bc_eqn_dlm[k,1], bc_eqn_dlm[k,2], j, bc_eqn_var_lkup[kmx_in,k,j]);
          v = bc_eqn_var_lkup[ii,k,j];
          if (k == 1) {
            if (!(v in cb_list)) {
              cb_list[v] = ++cb_mx;
              cb_lkup[cb_mx] = v;
            }
          } else {
            if (!(v in sb_list)) {
              sb_list[v] = ++sb_mx;
              sb_lkup[sb_mx] = v;
            }
          }
        }
      }
      if (verbose > 0) {
      if (cb_mx > 0 && ii == i) {
        cb_mx_ii = cb_mx;
        printf("\tdepends on eqns: ");
        v = "";
        for (k=1; k <= cb_mx; k++) {
          kk = bc_eqn_glbl_var_arr_from_eqn[cb_lkup[k]];
          printf("%seqn[%d]= %s", v, kk, cb_lkup[k]);
          v = ", ";
        }
        printf("\n");
      }
      if (sb_mx > 0 && ii == i) {
        sb_mx_ii = sb_mx;
        printf("\t\tdepends on evts: ");
        v = "";
        for (k=1; k <= sb_mx; k++) {
          printf("%s%s", v, sb_lkup[k]);
          v = ", ";
        }
        printf("\n");
      }
      }
    }
      if (verbose > 0) {
      if (cb_mx > cb_mx_ii) {
        printf("\t\tdepends on eqns: ");
        v = "";
        for (k=1; k <= cb_mx; k++) {
          kk = bc_eqn_glbl_var_arr_from_eqn[cb_lkup[k]];
          printf("%seqn[%d]= %s", v, kk, cb_lkup[k]);
          v = ", ";
        }
        printf("\n");
      }
      if (sb_mx > sb_mx_ii) {
        if (ii == i) { sb_mx_ii = sb_mx;}
        printf("\t\tdepends on evts: ");
        v = "";
        for (k=1; k <= sb_mx; k++) {
          printf("%s%s", v, sb_lkup[k]);
          v = ", ";
        }
        printf("\n");
      }
      }

    }
  }
  if (verbose > 0) {
  for (i=1; i <= bc_eqn_col_hdr_mx; i++) {
    if (i in bc_eqn_col_hdr_used_idx) {
      printf("evt used[%d] %s\n", i, bc_eqn_col_hdr[i]);
    }
  }
  for (i=1; i <= bc_eqn_col_hdr_mx; i++) {
    if (!(i in bc_eqn_col_hdr_used_idx)) {
      printf("evt not used[%d] %s\n", i, bc_eqn_col_hdr[i]);
    }
  }
  }
  i=0;
  if (1==2) {
  for (key in bc_eqn_col_hdr) {
    if (!(key in bc_eqn_col_hdr_used_idx)) {
      printf("evt not used[%d] %s\n", ++i, bc_eqn_col_hdr[key]);
    }
  }
  }
  if (out_file == "" && tm_mx >= 1) {
    #printf("tm_mx= %d, tm_lkup[%d]= %f\n", tm_mx, tm_mx, tm_lkup[tm_mx]);
    hdr_str = "time";
    for (j=0; j <= tm_mx; j++) {
      # delete the computed glbl_var_arr values (the output of the equations) to ensure that the eqn is only used if a prev eqn has initialized it
      delete bc_eqn_glbl_var_arr;
      #for (key in bc_eqn_glbl_var_arr_from_eqn) {
      #  delete bc_eqn_glbl_var_arr[key];
      #}
      # restore the not-computed values to glbl_var_arr
      for (key in bc_eqn_glbl_var_arr_sv) {
        bc_eqn_glbl_var_arr[key] = bc_eqn_glbl_var_arr_sv[key];
      }
      for (k=1; k <= evt_mx; k++) {
        if (j == 0) {
          bc_eqn_row_data[k] = evt_data[k,"tot"];
          bc_eqn_tmr_data[k] = evt_data[k,"tot","ns"];
          bc_eqn_inst_data[k] = evt_data[k,"tot","inst"];
        } else {
          bc_eqn_row_data[k] = evt_data[k,j];
          bc_eqn_tmr_data[k] = evt_data[k,j,"ns"];
          bc_eqn_inst_data[k] = evt_data[k,j,"inst"];
        }
      }
      if (j == 0) {
        bc_eqn_glbl_var_arr["interval"] = tm_lkup[tm_mx]+0.0;
      } else if (j == 1) {
        bc_eqn_glbl_var_arr["interval"] = tm_lkup[j]+0.0;
      } else {
        bc_eqn_glbl_var_arr["interval"] = tm_lkup[j]-tm_lkup[j-1];
      }
      det_str = sprintf("%.3f", tm_lkup[j]);
      for (i=1; i <= kmx; i++) {
        if (bc_eqn_ck_if_got(i, 0) == 0) {
          continue;
        }
        val = bc_eqn_evalArithmeticExp(bc_eqn_arr[i, "eqn"], 3, arg_arr, verbose, i) + 0.0;
        got_all = bc_eqn_got_all_needed_variables(i, res_arr);
        if (got_all == 0) {
          no_prt = index(bc_eqn_arr[i,"options"], "no_print");
          if (j==1 && no_prt == 0) {
            v = bc_eqn_arr[i, "hdr"];
            hlen[i] = length(v);
            if (hlen[i] < 5) { hlen[i] = 5; }
            hdr_str = hdr_str sprintf("\t%s", v);
          }
          if (bc_eqn_err_num != 0) {
             printf("eqn[%d] got err %d str= %s\n", i, bc_eqn_err_num, bc_err);
             v_sv = verbose;
             verbose = 1;
             val = bc_eqn_evalArithmeticExp(bc_eqn_arr[i, "eqn"], 3, arg_arr, verbose, i) + 0.0;
             verbose = v_sv;
             if (verbose > 0) {
             printf("bc_eqn_glbl_var_arr[%s] = %s\n", "itp_denom", bc_eqn_glbl_var_arr["itp_denom"]);
             }
          }
          if (no_prt == 0) {
            fmt = "%" hlen[i] ".3f";
            det_str = det_str sprintf("\t" fmt, val);
          }
          hdr = bc_eqn_arr[i,"hdr"];
          hdr_lc = tolower(hdr);
          bc_eqn_glbl_var_arr[hdr_lc] = val;
          bc_eqn_glbl_var_arr_from_eqn[hdr_lc] = i;
        }
      }
      if (j==1) {
        printf("%s\n", hdr_str);
      }
      printf("%s\n", det_str);
    }
  }
  if (out_file != "" && tm_mx >= 1) {
    prt_to_out_file();
  }
}
function prt_to_out_file(     hdr_arr, col, col_cur, hdr_mx, i, j, k, kk, hdr_col, rows, sv_mx, sv_line, bcol) {
  printf("got prt_to_out_file\n");
  if (out_file != "" && tm_mx >= 1) {
    #printf("tm_mx= %d, tm_lkup[%d]= %f\n", tm_mx, tm_mx, tm_lkup[tm_mx]);
    hdr_mx = -1;
    do_hdr = 1;
    hdr_col = -1;
    trows = 0;
    sv_verbose = verbose;
    sv_mx = 0;
    tm_epoch_beg = bc_eqn3_epoch_time_beg+0;
    # evt_data really begins with j=1 but I'm starting at j=0 and use j=0 to compute the evt_data[*,"tot"] values
    for (j=0; j <= tm_mx; j++) { 
      col_cur = -1;
      kkk_hdr = 0;
      kkk_det = 0;
      kkk_evt = 0;
      # delete the computed glbl_var_arr values (the output of the equations) to ensure that the eqn is only used if a prev eqn has initialized it
      delete bc_eqn_glbl_var_arr;
      #for (key in bc_eqn_glbl_var_arr_from_eqn) {
      #  delete bc_eqn_glbl_var_arr[key];
      #}
      # restore the not-computed values to glbl_var_arr
      for (key in bc_eqn_glbl_var_arr_sv) {
        bc_eqn_glbl_var_arr[key] = bc_eqn_glbl_var_arr_sv[key];
      }
      if (do_hdr == 1) {
        hdr_arr[++hdr_mx,"str"] = "epoch";
        hdr_arr[  hdr_mx,"typ"] = "str";
        hdr_arr[  hdr_mx,"col"] = ++hdr_col;
        hdr_arr[++hdr_mx,"str"] = "ts";
        hdr_arr[  hdr_mx,"typ"] = "str";
        hdr_arr[  hdr_mx,"col"] = ++hdr_col;
        hdr_arr[++hdr_mx,"str"] = "rel_ts";
        hdr_arr[  hdr_mx,"typ"] = "str";
        hdr_arr[  hdr_mx,"col"] = ++hdr_col;
        hdr_arr[++hdr_mx,"str"] = "interval";
        hdr_arr[  hdr_mx,"typ"] = "str";
        hdr_arr[  hdr_mx,"col"] = ++hdr_col;
      }
      if (j == 0) {
        v = sprintf("%.3f", tm_lkup[tm_mx]);
      } else {
        v = sprintf("%.3f", tm_lkup[j]);
      }
      col[++col_cur,"val"] = sprintf("%.3f", (tm_epoch_beg + v)); # epoch
      col[++col_cur,"val"] = v; # ts
      col[++col_cur,"val"] = v; # rel_ts
      if (j == 0) {    # interval
        col[++col_cur,"val"] = v;
      } else if (j == 1) {    # interval
        col[++col_cur,"val"] = v;
      } else {
        col[++col_cur,"val"] = v - tm_lkup[j-1];
      }
      for (k=1; k <= evt_mx; k++) {
        if (do_hdr == 1) {
          hdr_arr[++hdr_mx,"str"]  = evt_lkup[k];
          hdr_arr[  hdr_mx,"typ"]  = "evt";
          hdr_arr[  hdr_mx,"lkup"] = k;
          hdr_arr[  hdr_mx,"col"]  = ++hdr_col;
        } 
        if (j == 0) {
          uj = "tot";
        } else {
          uj = j;
        }
        col[++col_cur,"val"] = evt_data[k,uj];
        bc_eqn_row_data[k]   = evt_data[k,uj];
        bc_eqn_tmr_data[k]   = evt_data[k,uj,"ns"];
        bc_eqn_inst_data[k]  = evt_data[k,uj,"inst"];
        kkk_evt++;
      }
      #printf("kkk_evt= %d\n", kkk_evt) > out_file;
      if (j == 0) {
        bc_eqn_glbl_var_arr["interval"] = tm_lkup[tm_mx]+0.0;
      } else if (j == 1) {
        bc_eqn_glbl_var_arr["interval"] = tm_lkup[j]+0.0;
      } else {
        bc_eqn_glbl_var_arr["interval"] = tm_lkup[j]-tm_lkup[j-1];
      }
      if (do_hdr == 1) {
        printf("aft_evts hdr_mx= %d, hdr_col= %d, col_cur= %d bc_eqn3_epoch_time_beg= %s\n", hdr_mx, hdr_col, col_cur, bc_eqn3_epoch_time_beg) > "/dev/stderr";
      }
      col_last_event = col_cur+1;
      for (i=1; i <= kmx; i++) {
        if (bc_eqn_ck_if_got(i, 0) == 0) {
          continue;
        }
        verbose = sv_verbose;
        if (index(bc_eqn_arr[i,"options"], "verbose") > 0) {
           verbose = 1;
        }
        val = bc_eqn_evalArithmeticExp(bc_eqn_arr[i, "eqn"], 3, arg_arr, verbose, i) + 0.0;
        got_all = bc_eqn_got_all_needed_variables(i, res_arr);
        if (got_all == 0) {
          no_prt = index(bc_eqn_arr[i,"options"], "no_print") +0;
          if (do_hdr == 1) {
            if (bc_eqn_arr[i, "hdr_ps"] != "") {
              v = bc_eqn_arr[i, "hdr_ps"];
            } else {
              v = bc_eqn_arr[i, "hdr"];
            }
            hlen[i] = length(v);
            if (hlen[i] < 5) { hlen[i] = 5; }
            hdr_str = hdr_str sprintf("\t%s", v);
            hdr_arr[++hdr_mx,"str"] = v;
            hdr_arr[  hdr_mx,"typ"] = "eqn";
            hdr_arr[  hdr_mx,"lkup"] = i;
            hdr_arr[  hdr_mx,"no_prt"] = no_prt;
            hdr_arr[  hdr_mx,"col"] = (no_prt == 0 ? ++hdr_col : -1);
            #hdr_arr[  hdr_mx,"col"] = ++hdr_col;
            sv_hdr[i] = v;
          }
          #if (j==1) {
            #printf("j= %d eqn[%d], hdr[%d]= %s val= %f, hdr_col= %d\n", j, i, hdr_mx, hdr_arr[hdr_mx,"str"], val, hdr_col) > "/dev/stderr";
            #if (no_prt == 0) {
              #kkk_hdr++;
              #printf("eqn[%d], hdr= %s, typ= %s, no_prt= %d, col= %d, kkk_hdr= %d\n", i, v, "eqn", no_prt, hdr_arr[  hdr_mx,"col"], kkk_hdr) > out_file;
            #}
          #}
          if (bc_eqn_err_num != 0) {
             printf("eqn[%d] got err %d str= %s\n", i, bc_eqn_err_num, bc_err);
             v_sv = verbose;
             verbose = 1;
             val = bc_eqn_evalArithmeticExp(bc_eqn_arr[i, "eqn"], 3, arg_arr, verbose, i) + 0.0;
             verbose = v_sv;
             if (verbose > 0) {
             printf("bc_eqn_glbl_var_arr[%s] = %s\n", "itp_denom", bc_eqn_glbl_var_arr["itp_denom"]);
             }
          }
          if (no_prt == 0) {
            #fmt = "%" hlen[i] ".3f";
            fmt = "%.3f";
            v = sprintf(fmt, val);
            det_str = det_str v;
            col[++col_cur, "val"] = v;
            col[  col_cur, "eqn"] = i;
            #if (j==1) {
            #kkk_det++;
            #printf("det[%d], hdr= %s, typ= %s, no_prt= %d, col= %d, kkk_det= %d\n", i, v, "eqn", no_prt, hdr_arr[  hdr_mx,"col"], kkk_det) > out_file;
            #}
          }
          #if (j==1) {
          #  printf("j= %d eqn[%d], hdr[%d]= %s val= %f, hdr_col= %d col[%d]= %f\n", j, i, hdr_mx, hdr_arr[hdr_mx,"str"], val, hdr_col, col_cur, v) > "/dev/stderr";
          #}
          hdr = bc_eqn_arr[i,"hdr"];
          hdr_lc = tolower(hdr);
          bc_eqn_glbl_var_arr[hdr_lc] = val;
          bc_eqn_glbl_var_arr_from_eqn[hdr_lc] = i;
          hdr_ps = bc_eqn_arr[i,"hdr_ps"];
          if (hdr_ps != "") {
          hdr_lc = tolower(hdr_ps);
          bc_eqn_glbl_var_arr[hdr_lc] = val;
          bc_eqn_glbl_var_arr_from_eqn[hdr_lc] = i;
          }
        }
      }
      if (do_hdr == 1) {
        do_hdr = 0;
        v = "";
        printf("at bottom of eqn_loop: hdr_mx= %d, hdr_col= %d, col_cur= %d\n", hdr_mx, hdr_col, col_cur) > "/dev/stderr";
        ++sv_mx;
        for (kk=0; kk <= hdr_mx; kk++) {
          if (hdr_arr[kk,"no_prt"] != 0) { continue;}
          sv_line[sv_mx] = sv_line[sv_mx] sprintf("%s%s", v, hdr_arr[kk,"str"]);
          v = "\t";
        }
        trows++;
      }
      #printf("%s\n", det_str) > out_file;
        v = "";
        use_idx = sv_mx;
        if (j == 0) {
          use_idx = 0;
        } else {
          ++sv_mx;
          use_idx = sv_mx;
        }
        for (kk=0; kk <= col_cur; kk++) {
          sv_line[use_idx] = sv_line[use_idx] sprintf("%s%s", v, col[kk,"val"]);
          v = "\t";
        }
        trows++;
    }
    rows = 0;
    rows += 4;
    sheet = bc_eqn3_sheet;
    chrt  = bc_eqn3_chrt;
    pfx = bc_eqn3_pfx;
    bcol = 4;
    ts_col = 1;
    tbl0_beg = rows;
    tbl0_end = trows;
    printf("title\t%s\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet) > out_file;
    printf("hdrs\t%d\t%d\t%d\t%d\t%d\n", tbl0_beg, bcol, -1, hdr_col, ts_col) > out_file;
    printf("\n") > out_file;
    # put the typ of subtotal wanted in col B. 101 is an average over non-hidden rows. 104 is the max
    # so, if the user changes the col B 101 to 104 then the subtotal row will show the max value for each column
    printf("typ_subtotal\t101\t\t\t") > out_file;
    for (k=4; k < col_cur; k++) {
        frm = sprintf("=subtotal(INDIRECT(ADDRESS(ROW(),2, 1)), INDIRECT(ADDRESS(row()+2, column(), 1)):INDIRECT(ADDRESS(row()-1+%d, column(),1)))", tbl0_beg+sv_mx-2);
        printf("\t%s", frm) > out_file;
    }
    printf("\n") > out_file;

    for (k=1; k <= sv_mx; k++) {
      printf("%s\n", sv_line[k]) > out_file;
      rows++;
    }
    printf("\n") > out_file;
    rows++;
    printf("\n") > out_file;
    rows++;
    printf("%s\n", sv_line[1]) > out_file; # header
    rows++;
    printf("%s\n", sv_line[0]) > out_file; # values for whole run (eqns used event totals)
    rows++;
    printf("\n") > out_file;
    rows++;
    printf("\n") > out_file;
    rows++;
    td_cols_str = "";
    bw_cols_str = "";
    ipc_cols_str = "";
    unh_cols_str = "";
    lat_cols_str = "";
    hwpf_cols_str = "";
    printf("bc_eqn_chart_mx = %s\n", bc_eqn_chart_mx) > "/dev/stderr";
    for (jj=1; jj <= bc_eqn_chart_mx; jj++) {
      v = bc_eqn_charts[jj, "chart_def"];
      printf("_++++++++____++++______________bc_eqn_charts: chart cols %s cl= %d\n", v, cl) > "/dev/stderr";
      if (v == "") { continue; }
      printf("_++++++++____++++______________bc_eqn_charts: chart cols %s cl= %d\n", v, cl) > "/dev/stderr";
      for (k=0; k <= hdr_mx; k++) {
        cl = hdr_arr[k,"col"] ;
        if (hdr_arr[k,"typ"] != "eqn" || cl < 0) { continue; }
        i  = hdr_arr[k,"lkup"];
        printf("bc_eqn_chart[%d]: bc_eqn_arr[%d,"charts"]= %s, v= %s\n", jj, i, bc_eqn_arr[i,"charts"], v) > "/dev/stderr";
        if (index(bc_eqn_arr[i,"charts"], v) > 0) {
          str = hdr_arr[k,"str"];
          bc_eqn_charts[jj, "chart_cols_str"] = bc_eqn_charts[jj, "chart_cols_str"] sprintf("\t%s\t%s", cl, cl);
          printf("_++++++++____++++_______________bc_eqn_charts:  chart cols %s cl= %d, col_str= %s\n", v, cl, bc_eqn_charts[jj, "chart_cols_str"]  ) > "/dev/stderr";
        }
      }
    }
    
    for (k=0; k <= hdr_mx; k++) {
       i  = hdr_arr[k,"lkup"];
       cl = hdr_arr[k,"col"] ;
       if (hdr_arr[k,"typ"] != "eqn" || cl < 0) { continue; }
       str = hdr_arr[k,"str"];
       if (index(bc_eqn_arr[i,"charts"], "td_lvl1_chart") > 0) {
          printf("chart cols td_lvl1_chart cl= %d\n", cl) > "/dev/stderr";
          td_cols_str = td_cols_str sprintf("\t%s\t%s", cl, cl);
       }
       if (index(str, "GB/s") > 0) {
          bw_cols_str = bw_cols_str sprintf("\t%s\t%s", cl, cl);
       }
       if (str == "IPC" || index(str, "GHz") > 0 || index(str, "PKI") > 0 || index(str, "PTI") > 0) {
          ipc_cols_str = ipc_cols_str sprintf("\t%s\t%s", cl, cl);
       }
       if (index(str, "not_halted") > 0 || index(str, "%L3_miss") > 0 || index(str, "%LLC misses") > 0 ||  index(str, "%both_HT_threads_active") > 0) {
          if (index(str, "miss") > 0) {
            xtra_str = ", %LLC misses"
          }
          if (index(str, "%both_HT_threads_active") > 0) {
            xtra_str2 = ", %both_HT_threads_active";
          }
          unh_cols_str = unh_cols_str sprintf("\t%s\t%s", cl, cl);
       }
       if (index(str, "latency") > 0) {
          lat_cols_str = lat_cols_str sprintf("\t%s\t%s", cl, cl);
       }
       if (index(str, "hw prefetch") > 0) {
          hwpf_cols_str = hwpf_cols_str sprintf("\t%s\t%s", cl, cl);
       }
    }
    if (td_cols_str != "") {
      printf("title\t%s TopLev Level 1 Percentages\tsheet\t%s\ttype\tline_stacked\n", chrt, sheet) > out_file;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d%s\n", tbl0_beg, bcol, -1, hdr_col, ts_col, td_cols_str) > out_file;
      printf("\n") > out_file;
      rows += 3;
      printf("\ntitle\t%s Top Lev: %%cpus Back/Front End Bound, Retiring\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet) > out_file;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d%s\n", tbl0_beg, bcol, -1, hdr_col, ts_col, td_cols_str) > out_file;
      printf("\n") > out_file;
      rows += 3;
    }
    if (bw_cols_str != "") {
      printf("title\t%s mem bw\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet) > out_file;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d%s\n", tbl0_beg, bcol, -1, hdr_col, ts_col, bw_cols_str) > out_file;
      printf("\n") > out_file;
      rows += 3;
    }
    if (ipc_cols_str != "") {
      printf("\ntitle\t%s IPC, CPU freq, LLC misses\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet) > out_file;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d%s\n", tbl0_beg, bcol, -1, hdr_col, ts_col, ipc_cols_str) > out_file;
      printf("\n") > out_file;
      rows += 3;
    }
    if (unh_cols_str != "") {
      printf("title\t%s %%cpus not halted (running)%s%s\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, xtra_str, xtra_str2, pfx, sheet) > out_file;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d%s\n", tbl0_beg, bcol, -1, hdr_col, ts_col, unh_cols_str) > out_file;
      printf("\n") > out_file;
      rows += 3;
    }
    if (lat_cols_str != "") {
      printf("title\t%s miss latency\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet) > out_file;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d%s\n", tbl0_beg, bcol, -1, hdr_col, ts_col, lat_cols_str) > out_file;
      printf("\n") > out_file;
      rows += 3;
    }
    if (hwpf_cols_str != "") {
      printf("title\t%s hw prefetch bw (GB/s)\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, pfx, sheet) > out_file;
      printf("hdrs\t%d\t%d\t%d\t%d\t%d%s\n", tbl0_beg, bcol, -1, hdr_col, ts_col, hwpf_cols_str) > out_file;
      printf("\n") > out_file;
      rows += 3;
    }
    for (jj=1; jj <= bc_eqn_chart_mx; jj++) {
       str = bc_eqn_charts[jj, "chart_cols_str"];
       if (str != "") {
         v = bc_eqn_charts[jj, "chart_title"];
         printf("title\t%s %s\tsheet\t%s%s\ttype\tscatter_straight\n", chrt, v, pfx, sheet) > out_file;
         printf("hdrs\t%d\t%d\t%d\t%d\t%d%s\n", tbl0_beg, bcol, -1, hdr_col, ts_col, str) > out_file;
         printf("\n") > out_file;
         rows += 3;
       }
    }
    printf("\n") > out_file;
    rows++;
    printf("bc_eqn3 at end: got sum_file= %s\n", sum_file) > "/dev/stderr";
    close(out_file);
    if (sum_file != "") {
      nh = split(sv_line[1], harr, "\t");
      nv = split(sv_line[0], varr, "\t");
      for (i=col_last_event+1; i <= col_cur; i++) {
        printf("average\tperf_stat\t%.6f\t%s\n", varr[i], harr[i]) >> sum_file;
      }
      for (i=col_last_event+1; i <= col_cur; i++) {
        j = col[i, "eqn"];
        if (j != "" && bc_eqn_arr[j,"hdr_alias"] != "") {
          str  = bc_eqn_arr[j,"hdr_alias"];
          fctr = bc_eqn_arr[j,"hdr_alias_factor"];
          if (fctr == "") { fctr = 1.0;}
          printf("itp_metric\tperf_stat\t%.6f\t%s\n", fctr*varr[i], str) >> sum_file;
        }
      }
      for (i=1; i <= evt_mx; i++) {
        str  = evt_lkup[i];
        v    = evt_data[i,"tot"];
        inst = evt_data[i,"tot","inst"];
        if (harr[i] == "cpu-clock") { printf("cpu-clock: tot= %.3f, inst= %.3f avg= %.3f\n", v, inst, v/inst) > "/dev/stderr";}
        if (inst > 0) {
            printf("average\tperf_stat\t%.6f\t%s\n", v/inst, str) >> sum_file;
        }
      }
      close(sum_file);
    }
  }
}
