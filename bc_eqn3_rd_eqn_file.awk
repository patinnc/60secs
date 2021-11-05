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
FILENAME == eqn_file {
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
  }
  if ($1 == "hdr:") {
    if (use_this_eqn != 1) { next;}
    pos = index($0, $1);
    v = substr($0, pos+4, length($0));
    gsub(/^[ ]+/, "", v);
    gsub(/[ ]+$/, "", v);
    bc_eqn_arr[kmx,"hdr"]= v;
    #printf("eqn[%d] hdr= %s\n", kmx, v);
  }
  if ($1 == "options:") {
    if (use_this_eqn != 1) { next;}
    pos = index($0, $1);
    v = substr($0, pos+8, length($0));
    gsub(/^[ ]+/, "", v);
    gsub(/[ ]+$/, "", v);
    bc_eqn_arr[kmx,"options"]= v;
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
    skip_eqn = bc_eqn_ck_skip_or_use_if_got(i,"skip", verbose);
    if (skip_eqn == 1) { continue; }
    use_eqn = bc_eqn_ck_skip_or_use_if_got(i,"use", verbose);
    if (use_eqn != 1) { continue; }
    bc_eqn_arr[i,"got_row_vars"] = bc_eqn_arr[i,"uses_row_vars"];
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
         printf("bc_eqn_glbl_var_arr[%s] = %s\n", "itp_denom", bc_eqn_glbl_var_arr["itp_demon"]);
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
  if (tm_mx >= 1) {
    #printf("tm_mx= %d, tm_lkup[%d]= %f\n", tm_mx, tm_mx, tm_lkup[tm_mx]);
    hdr_str = "time";
    for (j=1; j <= tm_mx; j++) {
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
        bc_eqn_row_data[k] = evt_data[k,j];
        bc_eqn_tmr_data[k] = evt_data[k,j,"ns"];
        bc_eqn_inst_data[k] = evt_data[k,j,"inst"];
      }
      if (j == 1) {
        bc_eqn_glbl_var_arr["interval"] = tm_lkup[j]+0.0;
      } else {
        bc_eqn_glbl_var_arr["interval"] = tm_lkup[j]-tm_lkup[j-1];
      }
      det_str = sprintf("%.3f", tm_lkup[j]);
      for (i=1; i <= kmx; i++) {
        skip_eqn = bc_eqn_ck_skip_or_use_if_got(i, "skip", 0);
        if (skip_eqn == 1) { continue; }
        use_eqn = bc_eqn_ck_skip_or_use_if_got(i,"use", 0);
        if (use_eqn != 1) { continue; }
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
             printf("bc_eqn_glbl_var_arr[%s] = %s\n", "itp_denom", bc_eqn_glbl_var_arr["itp_demon"]);
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
}
