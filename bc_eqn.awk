# https://web.archive.org/web/20081020065322/http://cm.bell-labs.com/cm/cs/who/bwk/awkcode.txt
# search for calc3

function bc_rtn(val, k4, got_rpn_eqn, col_hdr_mx, col_hdr, rw_data,    la, val1, lc, prt_it, oper, val2, ii, vv, n, str) {
   val =  0.0;
   prt_it=1;
   bc_err = "";
   bc_str = "";
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
      if (oper == "push_str") {
        val1=val2+0.0;
        bc_str = bc_str " " val2;
        if (bc_err != "") { printf("bc_err1= %s\n", bc_err) > "/dev/stderr"; }
        continue;
      }
      if (oper == "push_row_val" || oper == "push_row_val2") {
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
            rpn_err = "missed_col " la " " val2;
            printf("got rpn_err2 = %s\n", rpn_err) > "/dev/stderr";
          }
        }
        if (got_rpn_eqn[k4,la,"lkup_col"] != -1) {
          lc = got_rpn_eqn[k4,la,"lkup_col"];
          val1=rw_data[lc]+0.0;
          bc_str = bc_str " " val1;
          if (bc_err != "") { printf("after push bc_err3= %s\n", bc_err) > "/dev/stderr"; }
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
     printf("bc_eqn: cmd= \"%s\", val= %f\n", cmd, val) > "/dev/stderr";
   } else {
     # val = sprintf("%f", bc_str);
     str = bc_str;
     n = split(str, arr, " ");
     NF = n;
     for (ii=1; ii <= n; ii++) { $ii = arr[ii]; }
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
    if (f <= NF) { printf("error at %s\n", $f) }
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
    while ($f == "*" || $f == "/")
        e = $(f++) == "*" ? e * factor() : e / factor();
    return e;
}

function factor(  e) {      # number | (expr)
    if ($f ~ /^[+-]?([0-9]+[.]?[0-9]*|[.][0-9]+)$/) {
        return $(f++);
    } else if ($f == "(") {
        f++;
        e = expr();
        if ($(f++) != ")")
            printf("error: missing ) at %s\n", $f);
        return e;
    } else {
        printf("error: expected number or ( at %s\n", $f);
        return 0;
    }
}
