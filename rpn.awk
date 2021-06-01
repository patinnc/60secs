# rpn calc from http://lancelot.pecquet.org/download/science/aesthack/rpn.html#AWK
function rpn_push(x) { ++rpn_sp; rpn_stack[rpn_sp] = x; }
function rpn_pop()   { if(rpn_sp > 0) rpn_sp--; else rpn_err = "rpn Stack underflow"; }
function rpn_top()   { if(rpn_sp > 0) return rpn_stack[rpn_sp]; }

function rpn_eval(x) {
  if(x != "-" && (x ~ /^[-.0-9][0-9]*[.0-9]?[0-9]*$/)) rpn_push(x);
  else {
    rpn_second      = rpn_stack[rpn_sp]; rpn_pop();
    rpn_first       = rpn_stack[rpn_sp]; rpn_pop();
         if(x == "+") rpn_push(rpn_first + rpn_second);
    else if(x == "-") rpn_push(rpn_first - rpn_second);
    else if(x == "*") rpn_push(rpn_first * rpn_second);
    else if(x == "/") { if (rpn_second == 0.0) { rpn_err = "div by 0";} else {rpn_push(rpn_first / rpn_second);} }
    else rpn_err = "Bad operator: " + x;
  }
}

function rpn_rtn(val, k4, got_rpn_eqn, col_hdr_mx, col_hdr, rw_data,    la, val1, lc, prt_it, oper, val2) {
   val =  0.0;
   prt_it=1;
   rpn_err = "";
   rpn_sp = 0;
   for(la=1; la <= got_rpn_eqn[k4,1,"max"]; la++) {
      rpn_err = "";
      oper = got_rpn_eqn[k4,la,"opr"];
      val2 = got_rpn_eqn[k4,la,"val"];
      if (oper == "push_val") {
        val1=val2+0.0;
        rpn_push(val1);
        if (rpn_err != "") { printf("rpn_err1= %s\n", rpn_err) > "/dev/stderr"; }
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
          rpn_push(val1);
          if (rpn_err != "") { printf("after push rpn_err3= %s\n", rpn_err) > "/dev/stderr"; }
        }
        if (val1 == "") {
           prt_it = 0;
           break;
        }
        continue;
      }
      if (oper == "oper") {
        rpn_eval(val2);
        if (rpn_err != "") { printf("rpn_err4= %s, oper= %s, val= %s\n", rpn_err, oper, val2) > "/dev/stderr"; return; }
        continue;
      }
   }
   if (prt_it == 1) {
     val = rpn_top()
   } else {
     printf("rpn_err: %s rpn_eqn k4= %d, la= %d\n", rpn_err, k4, la) > "/dev/stderr";
   }
   return val;
}
