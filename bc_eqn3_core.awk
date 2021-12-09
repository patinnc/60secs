BEGIN {
   bc_eqn_err_msgs_mx =0;
   bc_eqn_err_msgs[++bc_eqn_err_msgs_mx] = "divide by zero";                   # 1
   bc_eqn_err_div_by_zero = bc_eqn_err_msgs_mx;
   bc_eqn_err_msgs[++bc_eqn_err_msgs_mx] = "unbalanced paren";                 # 2
   bc_eqn_err_msgs[++bc_eqn_err_msgs_mx] = "unsupported field";                # 3
   bc_eqn_err_msgs[++bc_eqn_err_msgs_mx] = "unbalanced variable brackets";     # 4
   bc_eqn_err_msgs[++bc_eqn_err_msgs_mx] = "missed {} variable lookup";        # 5
   bc_eqn_err_msgs[++bc_eqn_err_msgs_mx] = "missed [] variable lookup";        # 6

   bc_eqn_curl_brkt     = 1;
   bc_eqn_3_sqre_brkt   = 2;
   bc_eqn_2_sqre_brkt   = 3;
   bc_eqn_sqre_brkt     = 4;
   bc_eqn_dlm[bc_eqn_curl_brkt,1] = "{";
   bc_eqn_dlm[bc_eqn_curl_brkt,2] = "}";
   bc_eqn_dlm[bc_eqn_3_sqre_brkt,1] = "[[[";
   bc_eqn_dlm[bc_eqn_3_sqre_brkt,2] = "]]]";
   bc_eqn_dlm[bc_eqn_2_sqre_brkt,1] = "[[";
   bc_eqn_dlm[bc_eqn_2_sqre_brkt,2] = "]]";
   bc_eqn_dlm[bc_eqn_sqre_brkt,1] = "[";
   bc_eqn_dlm[bc_eqn_sqre_brkt,2] = "]";
   bc_eqn_dlm_min = bc_eqn_curl_brkt;
   bc_eqn_dlm_max = bc_eqn_sqre_brkt;
   for (i=bc_eqn_dlm_min; i <= bc_eqn_dlm_max; i++) {
     bc_eqn_dlm_list[bc_eqn_dlm[i,1]] = i;
     bc_eqn_dlm_list[bc_eqn_dlm[i,2]] = i;
   }
}
BEGIN{
  if (var_list != "" && val_list != "") {
   n_var_list = split(var_list, vrarr, ",");
   n_val_list = split(val_list, vlarr, ",");
   if (n_var_list != n_val_list) {
     printf("var_list has %d elements: = %s\n", n_var_list, var_list);
     printf("val_list has %d elements: = %s\n", n_val_list, val_list);
     printf("number of elements in each comma separated list must be the same\n");
     exit(1);
   } 
   for (i=1; i <= n_var_list; i++) {
    v = vrarr[i];
    gsub("[ ]", "", v);
    bc_eqn_glbl_var_arr[v] = vlarr[i];
    #printf("set bc_eqn_glbl_var_arr[%s] = %s\n", v, bc_eqn_glbl_var_arr[v]);
   }
  }
  if (row_hdr != "" && row_val != "") {
   n_row_hdr = split(row_hdr, vrarr, ",");
   n_row_val = split(row_val, vlarr, ",");
   if (n_row_hdr != n_row_val) {
     printf("row_hdr has %d elements: = %s\n", n_row_hdr, row_hdr);
     printf("row_val has %d elements: = %s\n", n_row_val, row_val);
     printf("number of elements in each comma separated list must be the same\n");
     exit(1);
   } 
   for (i=1; i <= n_row_hdr; i++) {
    v = vrarr[i];
    gsub("[ ]", "", v);
    bc_eqn_col_hdr[i] = v;
    bc_eqn_row_data[i] = vlarr[i];
    printf("set bc_eqn_col_hdr[%s] = %s, bc_eqn_row_data[%d]= %s\n", v, i, i, vlarr[i]);
   }
   bc_eqn_col_hdr_mx = n_row_hdr;
  }
}
function bc_eqn2_get_list_of_variables(kmx_in, vrb,     arg_arr, mode, i, j, k, m) {
   arg_arr[1]= "";
   mode = 0;
   v = bc_eqn_evalArithmeticExp(bc_eqn_arr[kmx_in, "eqn"], mode, arg_arr, vrb, kmx_in);
   if (vrb > 0) {
     printf("%s: new_eqn var_mx= %s eqn= %s\n", script, bc_eqn_var_mx[kmx_in,bc_eqn_sqre_brkt], bc_eqn_arr[kmx_in, "eqn"]) > "/dev/stderr";
   }
   j = 0;
   for (k=bc_eqn_3_sqre_brkt; k <= bc_eqn_sqre_brkt; k++) {
     for (i=1; i <= bc_eqn_var_mx[kmx_in,k]; i++) {
       for (m=1; m <= j; m++) {
         # make sure we havent already added the variable
         if (lkfor[kmx_in,m] == bc_eqn_var_lkup[k,i]) {
           break;
         }
       }
       if (m > j) {
           lkfor[kmx_in,++j]= bc_eqn_var_lkup[k,i];
           if (vrb > 0) {
             printf("%s: new_eqn uses lkfor[%d,%d]= %s\n", script, kmx_in, j, lkfor[kmx_in,j]) > "/dev/stderr";
           }
       }
     }
   }
   bc_eqn_arr[kmx_in,"uses_row_vars"]= j; # num of fields to look for
}
function bc_eqn_arr_init(kmx_in, eqn) {
  bc_eqn_arr[kmx_in,"got_row_vars"]=0; # 0 if no fields found or 1 if 1 or more of these fields found
  bc_eqn_arr[kmx_in,"uses_row_vars"]=0; # num of fields to look for
  #bc_eqn_arr[kmx_in,3]=1.0;
  bc_eqn_arr[kmx_in,"eqn_typ"]="bc_eqn2";
  #bc_eqn_arr[kmx_in,5]=1; # instances
  #bc_eqn_arr[kmx_in,6]="";
  bc_eqn_arr[kmx_in, "eqn"]= eqn;
  bc_eqn_err_num = 0;
  bc_eqn2_get_list_of_variables(kmx_in, verbose);
  return;
}
function mymatch(s, r, myarr,   rc) {
    delete myarr;
    rc = match(s, r);
    if (rc != 0) {
       myarr[0] = substr(s,RSTART,RLENGTH);
    }
    return rc;
}
function ps_bc_eqn_ck_var_val(grp, var_evt_nm, k4, vrb, parr,       lc, val1, val2) {
  parr[1] = 0; # 0 indicates variable not found (the default). 1 -> variable found
  if (grp == bc_eqn_curl_brkt) {
    if (!(var_evt_nm in bc_eqn_glbl_var_arr)) {
      bc_eqn_err_num = 5;
      bc_err = bc_eqn_err_msgs[bc_eqn_err_num] " missed_col for column_hdr " val2 ", var= " var_evt_nm " in bc_eqn_glbl_var_arr";
      #printf("ck bc_err= %s\n", bc_err);
      return -1;
    }
    parr[1] = 1;
    bc_eqn_glbl_var_arr_used[var_evt_nm]++;
    return bc_eqn_glbl_var_arr[var_evt_nm];
  } else if (grp == bc_eqn_sqre_brkt || grp == bc_eqn_2_sqre_brkt || grp == bc_eqn_3_sqre_brkt) {
        val1= "";
        val2 = var_evt_nm;
        if (!((k4,"lkup_col",val2) in bc_eqn_arr)) {
          for (lc=1; lc <= bc_eqn_col_hdr_mx; lc++) {
            if (tolower(bc_eqn_col_hdr[lc]) == val2) {
             bc_eqn_arr[k4,"lkup_col",val2] = lc;
             break;
            }
          }
          if (!((k4,"lkup_col",val2) in bc_eqn_arr)) {
            bc_eqn_arr[k4,"lkup_col",val2] = -1;
            if (bc_eqn_arr[k4,"typ_match"] == "require_any") {
                return 0;
            }
            bc_eqn_err_num = 6;
            bc_err = bc_eqn_err_msgs[bc_eqn_err_num] " missed_col for column_hdr " val2;
            #printf("bc_eqn2.awk got bc_err2a = %s for bc_eqn_col_hdr[%d]= %s, typ_match= %s\n", bc_err, k4, bc_eqn_arr[k4,"hdr"], bc_eqn_arr[k4,"typ_match"]) > "/dev/stderr";
            return 0;
          }
        }
        if (bc_eqn_arr[k4,"lkup_col",val2] != -1) {
          lc = bc_eqn_arr[k4,"lkup_col",val2];
          if (grp == bc_eqn_3_sqre_brkt) {
            if (!(lc in bc_eqn_inst_data)) {
              bc_eqn_err_num = 6;
              bc_err = bc_eqn_err_msgs[bc_eqn_err_num] " missed_col for column_hdr " val2 ", found in bc_eqn_col_hdr but data col " lc " not found in bc_eqn_inst_data for [[[]]] brackets";
              #printf("bc_eqn2.awk got bc_err2a = %s for bc_eqn_col_hdr[%d]= %s, typ_match= %s\n", bc_err, k4, bc_eqn_arr[k4,"hdr"], bc_eqn_arr[k4,"typ_match"]) > "/dev/stderr";
              return -1;
            }
            val1=bc_eqn_inst_data[lc]+0.0;
            bc_eqn_col_hdr_used[var_evt_nm]++;
            bc_eqn_col_hdr_used_idx[lc]++;
            parr[1] = 1;
            return val1;
          }
          if (grp == bc_eqn_2_sqre_brkt) {
            if (!(lc in bc_eqn_tmr_data)) {
              bc_eqn_err_num = 6;
              bc_err = bc_eqn_err_msgs[bc_eqn_err_num] " missed_col for column_hdr " val2 ", found in bc_eqn_col_hdr but data col " lc " not found in bc_eqn_tmr_data for [[]] brackets";
              #printf("bc_eqn2.awk got bc_err2a = %s for bc_eqn_col_hdr[%d]= %s, typ_match= %s\n", bc_err, k4, bc_eqn_arr[k4,"hdr"], bc_eqn_arr[k4,"typ_match"]) > "/dev/stderr";
              return -1;
            }
            val1=bc_eqn_tmr_data[lc]+0.0;
            bc_eqn_col_hdr_used[var_evt_nm]++;
            bc_eqn_col_hdr_used_idx[lc]++;
            parr[1] = 1;
            return val1;
          }
          if (grp == bc_eqn_sqre_brkt) {
            if (!(lc in bc_eqn_row_data)) {
              bc_eqn_err_num = 6;
              bc_err = bc_eqn_err_msgs[bc_eqn_err_num] " missed_col for column_hdr " val2 ", found in bc_eqn_col_hdr but data col " lc " not found in bc_eqn_row_data for [] brackets";
              #printf("bc_eqn2.awk got bc_err2a = %s for bc_eqn_col_hdr[%d]= %s, typ_match= %s\n", bc_err, k4, bc_eqn_arr[k4,"hdr"], bc_eqn_arr[k4,"typ_match"]) > "/dev/stderr";
              return -1;
            }
            val1=bc_eqn_row_data[lc]+0.0;
            bc_eqn_col_hdr_used[var_evt_nm]++;
            bc_eqn_col_hdr_used_idx[lc]++;
            parr[1] = 1;
            return val1;
          }
        } else {
            bc_eqn_err_num = 6;
            bc_err = bc_eqn_err_msgs[bc_eqn_err_num] " missed_col for column_hdr " val2;
        }
        return 0;
  }
  return 0;
}
function bc_eqn_smatch2(s, r, myarr, vrb,   m, n, sv) {
    if (match(s, r)) {
        if (vrb > 0) {
         printf("smatch.1 s= %s, r= %s, pos= %s, len= %s\n", s, r, RSTART, RLENGTH);
        }
        sv = substr(s,RSTART,RLENGTH);
        myarr[0] = sv;
        m = RSTART
        do {
            n = RLENGTH
            sv = myarr[0];
        } while (match(substr(s, m, n - 1), r))
        RSTART = m
        RLENGTH = n
        myarr[0] = substr(s, m, n);
        if (vrb > 0) {
        printf("smatch.2 s= %s, r= %s, pos= %s, len= %s myarr[0]= %s\n", s, r, RSTART, RLENGTH, myarr[0]);
        }
        return RSTART
    } else return 0
}
function bc_eqn_smatch(s, r, myarr, vrb,   m, n, sv) {
    if (mymatch(s, r, myarr)) {
        if (vrb > 0) {
         printf("smatch.1 s= %s, r= %s, pos= %s, len= %s\n", s, r, RSTART, RLENGTH);
        }
        sv = myarr[0];
        m = RSTART
        do {
            n = RLENGTH
            sv = myarr[0];
        } while (mymatch(substr(s, m, n - 1), r, myarr))
        RSTART = m
        RLENGTH = n
        myarr[0] = sv;
        if (vrb > 0) {
        printf("smatch.2 s= %s, r= %s, pos= %s, len= %s myarr[0]= %s\n", s, r, RSTART, RLENGTH, myarr[0]);
        }
        return RSTART
    } else return 0
}
function bc_eqn_repl(s, v1, pos, len,   lhs, rhs, s1) {
      lhs = (pos == 1 ? "" : substr(s, 1, pos-1));
      rhs = substr(s, pos+len, length(s));
      s1 = lhs v1 rhs;
      return s1;
}
function is_number(x)   {
   return x+0 == x
}
function bc_eqn_ck_var_cmp_val(v, cmp_oper, cmp_val, vrb,   rc, v1, c1) {
      if (is_number(v) || is_number(cmp_val)) {
        v1 = v+0;
        c1 = cmp_val+0;
      } else {
        v1 = v;
        c1 = cmp_val;
      }
      rc = 0;
      if      (cmp_oper == "==") { if (v1 == c1) { rc = 1; } }
      else if (cmp_oper == "!=") { if (v1 != c1) { rc = 1; } }
      else if (cmp_oper == "<=") { if (v1 <= c1) { rc = 1; } }
      else if (cmp_oper == ">=") { if (v1 >= c1) { rc = 1; } }
      else if (cmp_oper == "<")  { if (v1 <  c1) { rc = 1; } }
      else if (cmp_oper == ">")  { if (v1 >  c1) { rc = 1; } }
      else {
        printf("bc_eqn_ck_var_cmp_val got invalid cmp_oper= %s\n", cmp_oper);
        exit(1);
      }
      if (vrb > 0) {
        printf("cmp_val: lhs: in=%s num=%s oper= %s rhs %s rc= %d\n", v, v1, cmp_oper, c1, rc);
      }
      return rc;
}
function bc_eqn_ck_var_val_def(grp, var_evt_nm, cmp_oper, cmp_val, vrb,    i, v, rc) {
  bc_eqn_err_num = 0;
  if (grp == bc_eqn_curl_brkt) {
    if (!(var_evt_nm in bc_eqn_glbl_var_arr)) {
      bc_eqn_err_num = 5;
      return -1;
    }
    bc_eqn_glbl_var_arr_used[var_evt_nm]++;
    if (cmp_oper != "") {
      v  = bc_eqn_glbl_var_arr[var_evt_nm];
      rc = bc_eqn_ck_var_cmp_val(v, cmp_oper, cmp_val, vrb);
      return rc;
    }
    return bc_eqn_glbl_var_arr[var_evt_nm];
  } else {
    for(i=1; i <= bc_eqn_col_hdr_mx; i++) {
      #printf("bc_eqn_col_hdr[%d]= %s  and  var_evt_nm= %s\n", i, bc_eqn_col_hdr[i], var_evt_nm);
      if (bc_eqn_col_hdr[i] == var_evt_nm) {
        bc_eqn_col_hdr_used[var_evt_nm]++;
        bc_eqn_col_hdr_used_idx[i]++;
        if (cmp_oper != "") {
          v  = bc_eqn_row_data[i];
          rc = bc_eqn_ck_var_cmp_val(v, cmp_oper, cmp_val, vrb);
          return rc;
        }
        return bc_eqn_row_data[i];
      }
    }
    bc_eqn_err_num = 6;
    return -1;
  }
}
function bc_eqn_ck_if_got(kmx_in, vrb_in,    skip_eqn, use_eqn) {
  skip_eqn = bc_eqn_ck_skip_or_use_if_got(kmx_in, "skip", 0);
  if (skip_eqn == 1) { return 0; }
  use_eqn = bc_eqn_ck_skip_or_use_if_got(kmx_in,"use", 0);
  if (use_eqn != 1) { return 0; }
  return 1;
}

function bc_eqn_ck_skip_or_use_if_got(kmx_in, skip_or_use, vrb_in,   ck, rc, rc2, pos, pos0, pos1, str, str2, lkfor, lkfor_len, dlm, i, cmp_oper, cmp_val) {
  # return 1 if variable found and need to not use this eqn
  # else return 0 
  rc = (skip_or_use == "skip" ? 0 : 1);
  pos = 1;
  lkfor = skip_or_use "_if_got";
  lkfor_ln = length(lkfor);
  str = bc_eqn_arr[kmx_in,"options"];
  pos = index(str, lkfor);
  if (pos == 0) {
    return rc;
  }
  #if (pos > 0) {
  #  printf("_________ck_%s_if_got= %s\n", skip_or_use,  str);
  #}
  while((pos = index(str, lkfor)) > 0) {
    pos0 = pos;
    for(i=bc_eqn_dlm_min; i <= bc_eqn_dlm_max; i++) {
      dlm = bc_eqn_dlm[i,1];
      str2 = substr(str, pos+lkfor_ln, length(dlm));
      if (vrb_in > 0) {
        printf("str2= %s, dlm= %s\n", str2, dlm);
      }
      if (str2 == dlm) {
        str = substr(str, pos+lkfor_ln+length(dlm), length(str));
        pos = index(str, bc_eqn_dlm[i,2]);
        str2 = substr(str, 1, pos-1);
        if (vrb_in > 0) {
          printf("str= %s, str2= %s\n", str, str2);
          printf("%s_if_got var= \"%s\"\n", skip_or_use, str2);
        }
        cmp_oper = "";
        cmp_val  = "";
        pos1 = match(str2, "[!<=>]+");
        if (pos1 != 0) {
          cmp_oper = substr(str2, RSTART, RLENGTH);
          cmp_val  = substr(str2, RSTART+RLENGTH, length(str2));
          if (vrb_in > 0) {
            printf("skip_or_use got cmp in \"%s\", cmp_oper= %s cmp_val= %s, var= %s\n", str2, cmp_oper, cmp_val, substr(str2, 1, RSTART-1))
          }
          str2 = substr(str2, 1, RSTART-1);
        }
        str2 = tolower(str2);
        str = substr(str, pos+1, length(str));
        rc2 = bc_eqn_ck_var_val_def(i, str2, cmp_oper, cmp_val, vrb_in);
        if (cmp_oper != "" && vrb_in > 0) {
          printf("cmp_var= %s cmp_oper= %s cmp_val= %s rc2= %s\n", str2, cmp_oper, cmp_val, rc2);
        }
        if (bc_eqn_err_num == 0 && (cmp_oper == "" || rc2 == 1)) {
          if (vrb_in > 0) {
            printf("ck_skip_or_use found var= %s\n", str2);
          }
          rc = 1;
          if (skip_or_use == "skip") {
            str = "";
          }
        }
        else {
          if (vrb_in > 0) {
            printf("ck_skip_or_use didnt find var= %s\n", str2);
          }
          if (skip_or_use == "use") {
            str = "";
            rc = 0;
          }
        }
        #printf("aft str= %s\n", str);
        break;
      }
    }
    if (pos == pos0) {
      # didn't move forward
      str = substr(str, pos+lkfor_ln+2, length(str));
    }
  }
  if (vrb_in > 0) {
    printf("%s_if_got_rc= %d\n", skip_or_use, rc);
  }
  return rc;
}

function bc_eqn_got_all_needed_variables(kmx_in, result_arr,   need_vars, got_vars, k, j, rc) {
    rc = -1; # need_vars == got_vars or -1 if need_vars != got_vars;
    need_vars = 0;
    got_vars = 0;
    for (k=bc_eqn_dlm_min; k <= bc_eqn_dlm_max; k++) {
      for (j=1; j <= bc_eqn_var_mx[kmx_in,k]; j++) {
        need_vars++;
        got_vars += bc_eqn_var_found[kmx_in,k,j];
        #printf("bef eqn[%d], dlm[%d]= %s%s var_str[%d]= %s\n", kmx_in, k, bc_eqn_dlm[k,1], bc_eqn_dlm[k,2], j, bc_eqn_var_lkup[kmx_in,k,j]);
      }
    }
    result_arr["need_vars"] = need_vars;
    result_arr["got_vars"] = got_vars;
    if (need_vars == got_vars) {
      rc = 0;
    }
    return rc;
}
function bc_eqn_evalArithmeticExp(s_eqn_in, mode, inout_arr, vrb, k4,   s, v, parr, i, j, k, n, psv_pos, psv_len, psv_str, str, lp, rp, arr, len_lp) {

  bc_eqn_err_num = 0;
  bc_err = "";
  s = s_eqn_in;
  bc_opers = "+-*/^|<=>!(}[]{}";
  bc_opers_arr_n = split(bc_opers, bc_opers_arr, "");
  #printf("eqn before= %s, opers_n= %d\n", s, bc_opers_arr_n);
  for (k=1; k <= bc_opers_arr_n; k++) {
      v0 = " " bc_opers_arr[k];
      v1 = bc_opers_arr[k];
      while((pos = index(s, v0)) > 0) {
         s = substr(s, 1, pos-1) "" bc_opers_arr[k] "" substr(s, pos+2);
      }
      v0 = bc_opers_arr[k] " ";
      while((pos = index(s, v0)) > 0) {
         s = substr(s, 1, pos-1) "" bc_opers_arr[k] "" substr(s, pos+2);
      }
  }
  #printf("eqn after= %s\n", s);
    #while (( rc = bc_eqn_smatch(sva, "^[-]?[0-9]+[.]?[0-9]*[eE]+[\\+-]?[0-9]+[\\+-\\/*\\^|<=>]", crr, vrb)) != 0 || (rc2 = mymatch(sva, "^[-]?[0-9]+[.]?[0-9]*[\\+-\\/*\\^|<=>]", crr)) != 0 || (rc3 = bc_eqn_smatch(sva, "^.+[\\+-\\/*\\^|<=>]", crr, vrb)) != 0) {
  gsub(/^[ ]+/,"", s);
  gsub(/[ ]+$/,"", s);
  #gsub(/^[ ]/,"", s);
 
  #delete bc_eqn_var_list;
  #delete bc_eqn_var_lkup;
  # check if variables found and substitute values

  for (k=bc_eqn_curl_brkt; k <= bc_eqn_sqre_brkt; k++) {
    #bc_eqn_var_mx[k4,k] = 0;
    while (1) {
      lp = index(s, bc_eqn_dlm[k,1]);
      rp = index(s, bc_eqn_dlm[k,2]);
      len_lp = length(bc_eqn_dlm[k,1]);
      if (lp == 0 && rp == 0) {break;}
      if (rp < lp) {
        printf("right bracket %s appears before left bracket %s in eqn %s\n", bc_eqn_dlm[k,2], bc_eqn_dlm[k,1], s);
        bc_eqn_err_num = 4;
        return 0;
      }
      if (lp > 0) {
        psv_str = tolower(substr(s, lp+len_lp, rp-(lp+len_lp)));
        if (!((k4,k,psv_str) in bc_eqn_var_list)) {
          bc_eqn_var_list[k4,k,psv_str] = ++bc_eqn_var_mx[k4,k];
          bc_eqn_var_lkup[k4,k,bc_eqn_var_mx[k4,k]] = psv_str;
          #printf("eqn[%d] added new used variable %s for type %s%s, mx= %d\n", k4, psv_str, bc_eqn_dlm[k,1], bc_eqn_dlm[k,2], bc_eqn_var_mx[k4,k]);
        }
        i = bc_eqn_var_list[k4,k,psv_str];
        if (vrb > 0) {
          printf("var[%d,%d,%d]= %s\n", k4,k, i, bc_eqn_var_lkup[k4,k,i]);
        }
        #if (and(mode , 1) != 0) {
        parr[1] = 0;
        bc_eqn_err_num = 0;
        v = ps_bc_eqn_ck_var_val(k,psv_str, k4, vrb, parr);
        bc_eqn_var_found[k4,k,i] = parr[1];
        if (mode == 1 || mode == 3) {
          if (bc_eqn_err_num != 0) {
            if (vrb > 0) {
              printf("didnt find variable %s bc_eqn_glbl_var_arr  for eqn= %s\n", psv_str, s);
            }
            return -1
          }
          if (vrb > 0) {
            printf("replace str %s with bc_eqn_glbl_var_arr= %s pos= %s len= %s in eqn %s\n", substr(s, lp, rp-lp+len_lp), v, lp, rp-lp+len_lp, s);
          }
        } else {
          v = 1;
        }
        s = bc_eqn_repl(s, v, lp, rp-lp+len_lp);
        if (vrb > 0) {
          printf("new eqn after replace %s\n", s);
        }
      }
      if (lp == 0 && rp == 0) {
        break;
      }
      if ((lp == 0 && rp != 0) || (lp != 0 && rp == 0)) {
        bc_eqn_err_num = 4;
        return 0;
      }
    }
  }
  #if (and(mode, 2) == 0) {
  if (mode < 2) {
    inout_arr[1] = s;
    return 1;
  }
  while (1) {
    lp = index(s, "(");
    rp = index(s, ")");
    if ((lp == 0 && rp > 0) || (lp > 0 && rp == 0)) {
      printf("unbalanced parens: s= %s\n", s);
      bc_eqn_err_num = 2;
      return 0;
    }
    if (lp == 0 && rp == 0) {
      break;
    }
    n = split(s, parr, "");
    for (i=rp-1; i > 0; i--) {
      if(parr[i] == "(") {
        psv_pos = i;
        psv_len = rp - i + 1;
        psv_str = arr[0] = substr(s, i, psv_len);
        break;
      }
    }
    v = bc_eqn_evalExp(arr[0], vrb, k4);
    if (bc_eqn_err_num > 0) {
      return v;
    }
    if (vrb > 0) {
      printf("paren.1: v= %s, arr[0]= %s  s= %s\n", v, arr[0], s);
    }
    if (bc_eqn_sv_func_operands_mx == 2) {
      if (psv_pos > 3) {
        if (substr(s, psv_pos-3, 3) == "max") {
          v = ( bc_eqn_sv_func_operands[1] > bc_eqn_sv_func_operands[2] ? bc_eqn_sv_func_operands[1] : bc_eqn_sv_func_operands[2] );
          psv_pos -= 3;
          psv_len += 3;
        }
        else if (substr(s, psv_pos-3, 3) == "min") {
          v = ( bc_eqn_sv_func_operands[1] < bc_eqn_sv_func_operands[2] ? bc_eqn_sv_func_operands[1] : bc_eqn_sv_func_operands[2] );
          psv_pos -= 3;
          psv_len += 3;
        }
      }
      bc_eqn_sv_func_operands_mx = 0;
    }
    if (bc_eqn_sv_func_operands_mx == 1) {
      if (psv_pos > 4) {
        if (substr(s, psv_pos-4, 4) == "sqrt") {
          v = sqrt(bc_eqn_sv_func_operands[1]);
          psv_pos -= 4;
          psv_len += 4;
        }
      }
      bc_eqn_sv_func_operands_mx = 0;
    }

    s = bc_eqn_repl(s, v, psv_pos, psv_len);
    if (vrb > 0) {
      printf("paren.2: v= %s, arr[0]= %s  s= %s\n", v, arr[0], s);
    }
  }
  return bc_eqn_evalExp(s, vrb, k4);
}
function bc_eqn_prt_list(str_in, mx, arr_num, arr_opr, sva_in, vrb,    k) {
  if (vrb > 0) {
    printf("%s: eqn= %s\n", str_in, sva_in);
    for(k=1; k <= mx; k++) { printf("num[%d]= %s, oper= %s\n", k, arr_num[k], arr_opr[k]); }
  }
}
#function bc_eqn_evalExp(s, vrb,    op, ln, reSNA, reNA, reUN, sv_mx, sva,
function bc_eqn_evalExp(s, vrb, k4,   op, ln, sv_mx, sva,
          rc, rc2, rc3, crr, sv_num, sv_opr, got_md, go_as, i, j, v) {
    gsub(/[()]/, "", s);
    if (vrb > 0) {
      printf("bc_eqn_evalExp.0 s= %s\n", s);
    }
 
    #reSNA = @/^[-]?[0-9]+[.]?[0-9]*[eE]+[\+-]?[0-9]+[\+-\/*|]+/;
    #reNA = @/^[-]?[0-9]+[.]?[0-9]*[\+-\/*|]+/;
    #reUN = @/^.+[\+-\/*|]+/; # unknown
    sv_mx = 0;
    sva = s "|"; # add end terminator
    rc = rc2 = rc3 = 0;
    crr[0] = "";
    #while (( rc = bc_eqn_smatch(sva, /^[-]?[0-9]+[.]?[0-9]*[eE]+[\+-]?[0-9]+[\+-\/*|]+/, crr, vrb)) != 0 || (rc2 = mymatch(sva, /^[-]?[0-9]+[.]?[0-9]*[\+-\/*|]+/, crr)) != 0 || (rc3 = bc_eqn_smatch(sva, /^.+[\+-\/*|]+/, crr, vrb)) != 0) {
    #while (( rc = bc_eqn_smatch(sva, "^[-]?[0-9]+[.]?[0-9]*[eE]+[\\+-]?[0-9]+[\\+-\\/*|]+", crr, vrb)) != 0 || (rc2 = mymatch(sva, "^[-]?[0-9]+[.]?[0-9]*[\\+-\\/*|]", crr)) != 0 || (rc3 = bc_eqn_smatch(sva, "^.+[\\+-\\/*|]+", crr, vrb)) != 0) {
    #while (( rc = bc_eqn_smatch(sva, "^[-]?[0-9]+[.]?[0-9]*[eE]+[\\+-]?[0-9]+[\\+-\\/*|]", crr, vrb)) != 0 || (rc2 = mymatch(sva, "^[-]?[0-9]+[.]?[0-9]*[\\+-\\/*|]", crr)) != 0 || (rc3 = bc_eqn_smatch(sva, "^.+[\\+-\\/*|]+", crr, vrb)) != 0) {
    #while (( rc = bc_eqn_smatch(sva, "^[-]?[0-9]+[.]?[0-9]*[eE]+[\\+-]?[0-9]+[\\+-\\/*|]", crr, vrb)) != 0 || (rc2 = mymatch(sva, "^[-]?[0-9]+[.]?[0-9]*[\\+-\\/*|]", crr)) != 0 || (rc3 = bc_eqn_smatch(sva, "^.+[\\+-\\/*|]", crr, vrb)) != 0) {
    #while (( rc = bc_eqn_smatch(sva, "^[-]?[0-9]+[.]?[0-9]*[eE]+[\\+-]?[0-9]+[\\+-\\/*\\^|]", crr, vrb)) != 0 || (rc2 = mymatch(sva, "^[-]?[0-9]+[.]?[0-9]*[\\+-\\/*\\^|]", crr)) != 0 || (rc3 = bc_eqn_smatch(sva, "^.+[\\+-\\/*\\^|]", crr, vrb)) != 0) {
    while (( rc = bc_eqn_smatch(sva, "^[-]?[0-9]+[.]?[0-9]*[eE]+[\\+-]?[0-9]+[\\+-\\/*\\^|<=>]", crr, vrb)) != 0 || (rc2 = mymatch(sva, "^[-]?[0-9]+[.]?[0-9]*[\\+-\\/*\\^|<=>]", crr)) != 0 || (rc3 = bc_eqn_smatch(sva, "^.+[\\+-\\/*\\^|<=>]", crr, vrb)) != 0) {
      #if (index(crr[0], "<") > 0 || index(crr[0], ">") > 0 || index(crr[0], "=") > 0) {
      #  ln = length(crr[0]);
      #  op = substr(crr[0], ln-2, 2);
      #  ln = length(crr[0])-1;
      #} else {
        ln = length(crr[0]);
        op = substr(crr[0], ln, 1);
      #}
      op_len = 1;
      if (op == "<" || op == "=" || op == ">") {
        if (length(sva) > ln) {
          ckop = substr(sva, ln+1, 1);
          if (ckop == "<" || ckop == "=" || ckop == ">") {
             op = op ckop;
             ln++;
             pos = (rc > 0 ? rc : (rc2 > 0 ? rc2 : rc3));
             crr[0] = substr(sva, pos, ln);
             op_len = 2;
          }
        }
      }
      if (vrb > 0) {
      printf("bc_eqn_evalExp: SNA rc= %s, rc2= %s, rc3= %s, crr[0]= %s  s= %s len= %s op= %s\n", rc, rc2, rc3, crr[0], sva, length(crr[0]), op);
      printf("nw bef sva= %s\n", sva);
      }
      if (rc3 > 0) {
        if (crr[0] == sva && match(sva, "^[01]\\?.+:.+\\|")) {
           i = split(substr(sva, 3, length(sva)), drr, ":")
           drr[2] = substr(drr[2], 1, length(drr[2])-1);
           if (substr(sva, 1,1) == 1) {
              v = drr[1];
           } else {
              v = drr[2];
           }
           #printf("got probable logic cmp, sva= %s, v= %s, drr[1]= %s drr2= %s\n", sva, v, drr[1], drr[2]);
           sva = v "|";
           crr[0] = sva;
           ln = length(sva);
           op = "|";
           op_len = 1;
        } else {
        bc_eqn_err_num = 3; # unknown operand
        gsub(/\|$/, "", crr[0]);
        gsub(/\|$/, "", sva);
        printf("error: unknown operand \"%s\" in equation, sva= \"%s\"\n", crr[0], sva);
        return 0;
        }
      }
      ++sv_mx;
      sv_num[sv_mx] = substr(crr[0], 1, ln-op_len);
      sva = substr(sva, ln+1, length(sva));
      if (op == "|") {
        sv_opr[sv_mx] = "";
        sva = substr(sva, 1, length(sva)-1);
      } else {
        if (op_len == 2) {
          sv_opr[sv_mx] = substr(crr[0], ln-1, 2);
        } else {
          sv_opr[sv_mx] = substr(crr[0], ln, 1);
        }
      }
      if (vrb > 0) {
        printf("nw aft sva= %s\n", sva);
      }
      rc = 0;
      rc2 = 0;
      rc3 = 0;
      if (op == "|") {
        break;
      }
    }
    if (sv_mx == 2 && sv_opr[1] == ",") {
       bc_eqn_sv_func_operands[1] = sv_num[1];
       bc_eqn_sv_func_operands[2] = sv_num[2];
       bc_eqn_sv_func_operands_mx = 2;
    }
    if (sv_mx == 1 && sv_opr[1] == "") {
       bc_eqn_sv_func_operands[1] = sv_num[1];
       bc_eqn_sv_func_operands_mx = 1;
    }
    v = 0;
    bc_eqn_prt_list("bef cmp list:", sv_mx, sv_num, sv_opr, s, vrb);
    got_cmp = 1;
    while (got_cmp == 1) {
      got_cmp = 0;
      for (i=1; i < sv_mx; i++) {
        if (sv_opr[i] == "<=" || sv_opr[i] == "==" || sv_opr[i] == ">=") {
          got_cmp = 1;
          if (sv_opr[i] == "<=") {
            sv_num[i] = (sv_num[i] <= sv_num[i+1] ? 1 : 0);
          }
          else if (sv_opr[i] == "==") {
            sv_num[i] = (sv_num[i] == sv_num[i+1] ? 1 : 0);
          }
          else if (sv_opr[i] == ">=") {
            sv_num[i] = (sv_num[i] >= sv_num[i+1] ? 1 : 0);
          }
          for (j=i+1; j < sv_mx; j++) { sv_num[j] = sv_num[j+1]; sv_opr[j-1] = sv_opr[j];}
          sv_opr[sv_mx-1] = "";
          break;
        }
      }
      if (got_cmp == 1) {
        sv_mx--;
        bc_eqn_prt_list("cmp cur_list:", sv_mx, sv_num, sv_opr, s, vrb);
      }
    }
    bc_eqn_prt_list("bef power list:", sv_mx, sv_num, sv_opr, s, vrb);
    got_pwr = 1;
    while (got_pwr == 1) {
      got_pwr = 0;
      for (i=1; i < sv_mx; i++) {
        if (sv_opr[i] == "^") {
          got_pwr = 1;
          if (sv_opr[i] == "^") {
            sv_num[i] = sv_num[i] ^ sv_num[i+1];
          }
          for (j=i+1; j < sv_mx; j++) { sv_num[j] = sv_num[j+1]; sv_opr[j-1] = sv_opr[j];}
          sv_opr[sv_mx-1] = "";
          break;
        }
      }
      if (got_pwr == 1) {
        sv_mx--;
        bc_eqn_prt_list("pwr cur_list:", sv_mx, sv_num, sv_opr, s, vrb);
      }
    }
    bc_eqn_prt_list("bef md list:", sv_mx, sv_num, sv_opr, s, vrb);
    got_md = 1;
    while (got_md == 1) {
      got_md = 0;
      for (i=1; i < sv_mx; i++) {
        if (sv_opr[i] == "*" || sv_opr[i] == "/") {
          got_md = 1;
          if (sv_opr[i] == "*") { sv_num[i] = sv_num[i] * sv_num[i+1]; }
          else if (sv_opr[i] == "/") {
            if (sv_num[i+1] == 0.0) {
              if (index(bc_eqn_arr[k4,"options"], "if_denom_zero_return_zero") > 0) {
                sv_num[i] = 0;
              } else {
                 bc_eqn_err_num = 1;
                 sv_num[i] = 0;
                 return 0;
              }
            } else {
              sv_num[i] = sv_num[i] / sv_num[i+1];
            }
          }
          for (j=i+1; j < sv_mx; j++) { sv_num[j] = sv_num[j+1]; sv_opr[j-1] = sv_opr[j];}
          sv_opr[sv_mx-1] = "";
          break;
        }
      }
      if (got_md == 1) {
        sv_mx--;
        bc_eqn_prt_list("md cur_list:", sv_mx, sv_num, sv_opr, s, vrb);
      }
    }
    got_as = 1;
    bc_eqn_prt_list("bef as list:", sv_mx, sv_num, sv_opr, s, vrb);
    while (got_as == 1) {
      got_as = 0;
      for (i=1; i < sv_mx; i++) {
        if (sv_opr[i] == "+" || sv_opr[i] == "-") {
          got_as = 1;
          if (sv_opr[i] == "+") { sv_num[i] = sv_num[i] + sv_num[i+1]; }
          else if (sv_opr[i] == "-") { sv_num[i] = sv_num[i] - sv_num[i+1]; }
          for (j=i+1; j < sv_mx; j++) { sv_num[j] = sv_num[j+1]; sv_opr[j-1] = sv_opr[j];}
          sv_opr[sv_mx-1] = "";
          break;
        }
      }
      if (got_as == 1) {
        sv_mx--;
        bc_eqn_prt_list("as cur_list:", sv_mx, sv_num, sv_opr, s, vrb);
      }
    }
    return sprintf("%g", sv_num[1]);
}
