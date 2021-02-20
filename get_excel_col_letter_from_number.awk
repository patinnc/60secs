function get_excel_col_letter_from_number(column,   letter, j, chr_str, c_in, res, rem, cpos)
{
  letter = "";
  chr_str="ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  for (j=0; j < length(chr_str); j++) {
   chr[j] = substr(chr_str, j+1, 1);
  }
  
  c = column;
  if (column == 0) { return "A";}
  cpos = 0;
  while ( column > 0) {
     c_in= column;
     res = column / 26;
     rem = column % 26;
     column = int(res);
     cpos++;
     if (cpos > 1 && rem > 0) { rem--; }
     letter = chr[rem] "" letter;
     #printf("col_in= %d, res= %d, rem= %d, col= %d, let= %s\n", c_in, res, rem, column, letter);
  }
  return letter;
}

