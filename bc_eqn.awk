# https://web.archive.org/web/20081020065322/http://cm.bell-labs.com/cm/cs/who/bwk/awkcode.txt
# search for calc3

function bc_rtn(val, k4, got_rpn_eqn, col_hdr_mx, col_hdr, rw_data, glbl_row_arr,    la, val1, lc, prt_it, oper, val2, ii, vv, vv2, vv3, n, str, myv) {
   val =  0.0;
   prt_it=1;
   bc_err = "";
   bc_str = "";
   str = "";
   for(la=1; la <= got_rpn_eqn[k4,1,"max"]; la++) {
      bc_err = "";
      oper = got_rpn_eqn[k4,la,"opr"];
      val2 = got_rpn_eqn[k4,la,"val"];
      if (oper == "push_val") {
        val1=val2+0.0;
        bc_str = bc_str " " val1;
        if (bc_err != "") { printf("bc_err1= %s\n", bc_err) > "/dev/stderr"; }
        continue;
      }
      if (oper == "push_interval") {
        val1=interval+0.0;
        bc_str = bc_str " " val1;
        if (bc_err != "") { printf("bc_err1= %s\n", bc_err) > "/dev/stderr"; }
        continue;
      }
      if (oper == "push_sv_avg_freq_ghz") {
        val1=sv_avg_freq_ghz+0.0;
        bc_str = bc_str " " val1;
        if (bc_err != "") { printf("bc_err1= %s\n", bc_err) > "/dev/stderr"; }
        continue;
      }
      if (oper == "push_str") {
        val1=val2+0.0;
        bc_str = bc_str " " val2;
        if (bc_err != "") { printf("bc_err1= %s\n", bc_err) > "/dev/stderr"; }
        continue;
      }
      if (oper == "push_glbl_row_arr") {
          if (glbl_row_arr[val2] == "") {
            bc_err = "missed col " val2 " for glbl_row_arr for row " la;
            printf("bc_eqn.awk got bc_err4 = %s\n", bc_err) > "/dev/stderr";
            return 0;
          } else {
            val1 = glbl_row_arr[val2];
            bc_str = bc_str " " val1;
            #printf("got for eqn %d glbl_row_arr[%s]= %g\n", k4, val2, val1) > "/dev/stderr";
          }
          continue;
      }
      if (oper == "push_row_val" || oper == "push_row_val2" || oper == "push_row_tmr") {
        val1= "";
        if (got_rpn_eqn[k4,la,"lkup_col"]=="") {
          for (lc=0; lc <= col_hdr_mx; lc++) {
            if (col_hdr[lc] == val2) {
             got_rpn_eqn[k4,la,"lkup_col"] = lc;
             break;
            }
          }
          if (got_rpn_eqn[k4,la,"lkup_col"]=="") {
            got_rpn_eqn[k4,la,"lkup_col"] = -1;
            bc_err = "missed_col " la " " val2;
            printf("bc_eqn.awk got bc_err2 = %s\n", bc_err) > "/dev/stderr";
          }
        }
        if (got_rpn_eqn[k4,la,"lkup_col"] != -1) {
          lc = got_rpn_eqn[k4,la,"lkup_col"];
          if (oper == "push_row_tmr") {
            val1=tmr_data[lc]+0.0;
          } else {
            val1=rw_data[lc]+0.0;
          }
          bc_str = bc_str " " val1;
          if (bc_err != "") { printf("bc_eqn.awk after push bc_err3= %s\n", bc_err) > "/dev/stderr"; }
        }
        if (val1 == "") {
           prt_it = 0;
           break;
        }
        continue;
      }
   }
   if (1==2) {
     # doing system call to bc is slower but provides a way to check results
     cmd = "echo \"scale=8; " bc_str "\" | bc -l ";
     cmd | getline val;
     close(cmd);
     printf("bc_eqn.awk: cmd= \"%s\", val= %f\n", cmd, val) > "/dev/stderr";
   } else {
     # val = sprintf("%f", bc_str);
     str = bc_str;
     n = split(str, arr, " ");
     NF = n;
     for (ii=1; ii <= n; ii++) { 
       $ii = arr[ii]; 
     }
     #printf("ret eqn line= %s\n", $0);
     for (ii=1; ii <= n; ii++) { 
       vv=try_calc3(arr[ii]);
     } 
     #printf("calc3 vv= %s\n", vv) > "/dev/stderr";
     val = vv;
     #printf("bc_eqn: bc_str= \"%s\", val= %f\n", bc_str, val) > "/dev/stderr";
   }
   return val;
}

# https://web.archive.org/web/20081020065322/http://cm.bell-labs.com/cm/cs/who/bwk/awkcode.txt
# search for calc3
function try_calc3( e) {
    #NF > 0 
    f = 1;
    e = expr();
    if (f <= NF) { 
        printf("bc_eqn.awk: error at %s\n, args= %s\n", $f, $0) 
        bc_err = sprintf("bc_eqn.awk: error at %s\n", $f) 
    }
    #else {printf("\t%.8g\n", e); return e;}
    else {return e;}
}

function expr(  e) {        # term | term [+-] term
    e = term();
    while ($f == "+" || $f == "-")
        e = $(f++) == "+" ? e + term() : e - term();
    return e;
}

function term(  e) {        # factor | factor [*/] factor
    e = factor();
    vv2 = e;
    vv3 = f;
    while ($f == "*" || $f == "/")
      if ($f == "/") {
        f++;
        myv = factor();
        if (myv == "" || myv == 0.0) {
          printf("bc_eqn.awk: div %s f= %s by 0 error at \"%s\", line= %s\n", vv2, vv3, $e $f, $0);
          bc_err = sprintf("bc_eqn.awk: error at %s\n", $f); 
          #return 0;
        }
        e = e / myv;
      } else {
        e = $(f++) == "*" ? e * factor() : e / factor();
      }
    return e;
}

function factor(  e) {      # number | (expr)
    isnum = 0;
    if ($f != "(") {
      # 5.61541e-09 
      v = $f + 0.0;
      if (v != 0.0) {
        isnum = 1;
      }
    }
    if (($f ~ /^[+-]?([0-9]+[.]?[0-9]*|[.][0-9]+)$/) || isnum == 1) {
        return $(f++);
    } else if ($f == "(") {
        f++;
        e = expr();
        if ($(f++) != ")") {
            printf("bc_eqn.awk error: missing ) at %s\nargs= %s\n", $f, $0);
            bc_err = sprintf("bc_eqn.awk error: missing ) at %s\n", $f);
        }
        return e;
    } else {
        printf("bc_eqn.awk error: expected number or ( at \"%s\"\n", $f);
        bc_err = sprintf("bc_eqn.awk error: expected number or ( at \"%s\"\n", $f);
        return 0;
    }
}
