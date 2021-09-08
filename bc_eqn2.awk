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
   bc_eqn_dbl_sqre_brkt = 2;
   bc_eqn_sqre_brkt     = 3;
}
function bc_eqn_smatch(s, r, myarr, vrb,   m, n, sv) {
    if (match(s, r, myarr)) {
        if (vrb > 0) {
         printf("smatch.1 s= %s, r= %s, pos= %s, len= %s\n", s, r, RSTART, RLENGTH);
        }
        sv = myarr[0];
        m = RSTART
        do {
            n = RLENGTH
            sv = myarr[0];
        } while (match(substr(s, m, n - 1), r, myarr))
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
function bc_eqn_ck_var_val_def(grp, var_evt_nm) {
  if (grp == bc_eqn_curl_brkt) {
    if (!(var_evt_nm in var_val_list)) {
      bc_eqn_err_num = 5;
      return -1;
    }
    return var_val_list[var_evt_nm];
  } else {
    if (!(var_evt_nm in var_val_list2)) {
      bc_eqn_err_num = 6;
      return -1;
    }
    return var_val_list2[var_evt_nm];
  }
}
function bc_eqn_evalArithmeticExp(s, mode, inout_arr, vrb, k4,   v, parr, i, j, k, n, psv_pos, psv_len, psv_str, str, lp, rp, arr, len_lp) {

  gsub(/\s/,"", s);
  gsub(/^\+/,"", s);
 
  delete bc_eqn_var_list;
  delete bc_eqn_var_lkup;
  bc_eqn_err_num = 0;
  # check if variables found and substitute values
  parr[bc_eqn_curl_brkt,1] = "{";
  parr[bc_eqn_curl_brkt,2] = "}";
  parr[bc_eqn_dbl_sqre_brkt,1] = "[[";
  parr[bc_eqn_dbl_sqre_brkt,2] = "]]";
  parr[bc_eqn_sqre_brkt,1] = "[";
  parr[bc_eqn_sqre_brkt,2] = "]";

  for (k=bc_eqn_curl_brkt; k <= bc_eqn_sqre_brkt; k++) {
    bc_eqn_var_mx[k] = 0;
    while (1) {
      lp = index(s, parr[k,1]);
      rp = index(s, parr[k,2]);
      len_lp = length(parr[k,1]);
      if (lp == 0 && rp == 0) {break;}
      if (rp < lp) {
        printf("right bracket %s appears before left bracket %s in eqn %s\n", parr[k,2], parr[k,1], s);
        bc_eqn_err_num = 4;
        return 0;
      }
      if (lp > 0) {
        psv_str = substr(s, lp+len_lp, rp-(lp+len_lp));
        if (!((k,psv_str) in bc_eqn_var_list)) {
          bc_eqn_var_list[k,psv_str] = ++bc_eqn_var_mx[k];
          bc_eqn_var_lkup[k,bc_eqn_var_mx[k]] = psv_str;
        }
        i = bc_eqn_var_list[k,psv_str];
        if (vrb > 0) {
          printf("var[%d,%d]= %s\n", k, i, bc_eqn_var_lkup[k,i]);
        }
        if (and(mode , 1) != 0) {
          v = @bc_eqn_ck_var_val_fncn(k,psv_str, k4, vrb);
          if (bc_eqn_err_num != 0) {
            if (vrb > 0) {
              printf("didnt find variable %s var_val_list for eqn= %s\n", psv_str, s);
            }
            return -1
          }
          if (vrb > 0) {
            printf("replace str %s with var_val_values= %s pos= %s len= %s in eqn %s\n", substr(s, lp, rp-lp+len_lp), v, lp, rp-lp+len_lp, s);
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
  if (and(mode, 2) == 0) {
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
    v = bc_eqn_evalExp(arr[0], vrb);
    if (bc_eqn_err_num > 0) {
      return v;
    }
    if (vrb > 0) {
      printf("paren.1: v= %s, arr[0]= %s  s= %s\n", v, arr[0], s);
    }

    s = bc_eqn_repl(s, v, psv_pos, psv_len);
    if (vrb > 0) {
      printf("paren.2: v= %s, arr[0]= %s  s= %s\n", v, arr[0], s);
    }
  }
  return bc_eqn_evalExp(s, vrb);
}
function bc_eqn_prt_list(str_in, mx, arr_num, arr_opr, vrb,    k) {
  if (vrb > 0) {
    printf("%s\n", str_in);
    for(k=1; k <= mx; k++) { printf("num[%d]= %s, oper= %s\n", k, arr_num[k], arr_opr[k]); }
  }
}
function bc_eqn_evalExp(s, vrb,    op, ln, reSNA, reNA, reUN, sv_mx, sva,
          rc, rc2, rc3, crr, sv_num, sv_opr, got_md, go_as, i, j, v) {
    gsub(/[()]/, "", s);
    if (vrb > 0) {
      printf("bc_eqn_evalExp.0 s= %s\n", s);
    }
 
    reSNA = @/^[-]?[0-9]+[.]?[0-9]*[eE]+[\+-]?[0-9]+[\+-\/*|]+/;
    reNA = @/^[-]?[0-9]+[.]?[0-9]*[\+-\/*|]+/;
    reUN = @/^.+[\+-\/*|]+/; # unknown
    sv_mx = 0;
    sva = s "|"; # add end terminator
    rc = rc2 = rc3 = 0;
    while (( rc = bc_eqn_smatch(sva, reSNA, crr, vrb)) != 0 || (rc2 = match(sva, reNA, crr)) != 0 || (rc3 = bc_eqn_smatch(sva, reUN, crr, vrb)) != 0) {
      ln = length(crr[0]);
      op = substr(crr[0], ln, 1);
      if (vrb > 0) {
      printf("bc_eqn_evalExp: SNA rc= %s, rc2= %s, rc3= %s, crr[0]= %s  s= %s len= %s\n", rc, rc2, rc3, crr[0], sva, length(crr[0]));
      printf("nw bef sva= %s\n", sva);
      }
      if (rc3 > 0) {
        bc_eqn_err_num = 3; # unknown operand
        gsub(/\|$/, "", crr[0]);
        gsub(/\|$/, "", sva);
        printf("error: unknown operand %s in equation, sva= %s\n", crr[0], sva);
        return 0;
      }
      ++sv_mx;
      sv_num[sv_mx] = substr(crr[0], 1, ln-1);
      sva = substr(sva, ln+1, length(sva));
      if (op == "|") {
        sv_opr[sv_mx] = "";
        sva = substr(sva, 1, length(sva)-1);
      } else {
        sv_opr[sv_mx] = substr(crr[0], ln, 1);
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
    bc_eqn_prt_list("bef md list:", sv_mx, sv_num, sv_opr, vrb);
    v = 0;
    got_md = 1;
    while (got_md == 1) {
      got_md = 0;
      for (i=1; i < sv_mx; i++) {
        if (sv_opr[i] == "*" || sv_opr[i] == "/") {
          got_md = 1;
          if (sv_opr[i] == "*") { sv_num[i] = sv_num[i] * sv_num[i+1]; }
          else if (sv_opr[i] == "/") {
            if (sv_num[i+1] == 0.0) {
              bc_eqn_err_num = 1;
              sv_num[i] = 0;
              return 0;
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
        bc_eqn_prt_list("md cur_list:", sv_mx, sv_num, sv_opr, vrb);
      }
    }
    got_as = 1;
    bc_eqn_prt_list("bef as list:", sv_mx, sv_num, sv_opr, vrb);
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
        bc_eqn_prt_list("as cur_list:", sv_mx, sv_num, sv_opr, vrb);
      }
    }
    return sprintf("%g", sv_num[1]);
}
 
