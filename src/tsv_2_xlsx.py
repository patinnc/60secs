#######################################################################
#
# An example of creating Excel Line charts with Python and XlsxWriter.
#
# Copyright 2013-2020, John McNamara, jmcnamara@cpan.org
#
# need to install xlsxwriter in python
# pip install xlsxwriter
# old: python tsv_2_xlsx.py sys_00_uptime.txt.tsv sys_01_dmesg.txt.tsv sys_02_vmstat.txt.tsv sys_03_mpstat.txt.tsv sys_04_pidstat.txt.tsv sys_05_iostat.txt.tsv sys_06_free.txt.tsv sys_07_sar_dev.txt.tsv sys_08_sar_tcp.txt.tsv sys_09_top.txt.tsv sys_10_perf_stat.txt.tsv
# python tsv_2_xlsx.py -o tst.xlsx -i "*.png" sys_*.txt.tsv
#   The optional '-i "*.png"' image file glob is in dbl quotes so it won't get expanded on the command line.
#   The glob gets expanded in the script. If you don't enclose the glob in quotes then only 1 image file name gets passed to the -i option and the rest get treated as tsv files.


from __future__ import print_function
import xlsxwriter
import csv
import getopt
import sys
import glob
import os

output_filename = 'chart_line.xlsx'
opened_wkbk = False
closed_wkbk = False

options_filename = ""

options, remainder = getopt.getopt(sys.argv[1:], 'f:i:o:p:s:v', ['file=', 'images=',
                                                         'output=',
                                                         'prefix=',
                                                         'size=',
                                                         'verbose',
                                                         ])
for opt, arg in options:
    if opt in ('-f', '--file'):
        options_filename = arg

opt_fl = []
fl_options = []
file_list1 = []

if options_filename != "":
   opt_fl = []
   with open(options_filename) as tsv:
       for line in csv.reader(tsv, dialect="excel-tab"):
           opt_fl.append(line)

if len(opt_fl) > 0:
   fl_opt = 0
   fl_options.append([sys.argv[0]])
   for i in range(len(opt_fl)):
       if len(opt_fl[i]) == 0:
          fl_opt = fl_opt + 1
          fl_options.append([sys.argv[0]])
          continue
       if len(opt_fl[i]) == 1:
          print("path? try= ", opt_fl[i][0])
          base = os.path.basename(opt_fl[i][0])
          file_list1.append({"fl_opt":fl_opt, "flnm":opt_fl[i][0], "base":base, "done":0})
       for j in range(len(opt_fl[i])):
           fl_options[fl_opt].append(opt_fl[i][j])
else:
   fl_opt = 0
   fl_options.append([])
   for i in range(len(sys.argv)):
       fl_options[fl_opt].append(sys.argv[i])


file_list = sorted(file_list1, key=lambda x: (x["base"], x["fl_opt"]))
#print(file_list)

fake_file_list = len(file_list)
if fake_file_list == 0:
   file_list.append([])

prefix_dict = {}
img_added = []

for fn in range(len(file_list)):
 #if fake_file_list > 0:
   #print("fn= ", fn, " file_list= ",file_list[fn])
 for fo2 in range(len(fl_options)):
   fo = fo2
   if fake_file_list > 0:
      fo = file_list[fn]["fl_opt"]
   #if fake_file_list > 0 and fo != file_list[fn]["fl_opt"]:
   #   print("skip fo= ", fo, ", fn= ", fn, " file_list= ",file_list[fn])
   #   continue
   print("fo= ", fo)
   #options, remainder = getopt.getopt(sys.argv[1:], 'i:o:p:v', ['images=',
   options, remainder = getopt.getopt(fl_options[fo][1:], 'i:o:p:s:v', ['images=',
                                                            'output=',
                                                            'prefix=',
                                                            'size=',
                                                            'verbose',
                                                            ])
   verbose = False
   image_files=[]
   prefix = ""
   ch_size = [1.0, 1.0, 15.0]
   
   print('OPTIONS   :', options)
   ch_array = []
   
   for opt, arg in options:
       if opt in ('-i', '--images'):
           for x in glob.glob(arg):
              image_files.append(x)
       elif opt in ('-o', '--output'):
           output_filename = arg
       elif opt in ('-p', '--prefix'):
           prefix = arg
           prefix_dict[fo] = prefix
       elif opt in ('-s', '--size'):
           # chart size width,height in 'excel 2007 pixels' which apparently aren't exactly pixels
           ch_tsize = arg.split(",")
           if len(ch_tsize) == 0:
              print("tsv_2_xlsx.py: sorry but the option '-s %s' seems invalid. Need something like '-s 2,2'. Bye." % (arg), file=sys.stderr)
           if len(ch_tsize) == 1:
              ch_size[0] = float(ch_tsize[0])
              ch_size[1] = float(ch_tsize[0])
           if len(ch_tsize) >= 2:
              ch_size[0] = float(ch_tsize[0])
              ch_size[1] = float(ch_tsize[1])
           if len(ch_tsize) == 3:
              ch_size[2] = float(ch_tsize[2])
       elif opt in ('-v', '--verbose'):
           verbose = True
   
   if opened_wkbk == False:
       workbook = xlsxwriter.Workbook(output_filename)
       opened_wkbk = True
   
   def is_number(s):
       try:
           float(s)
           return True
       except ValueError:
           return False
   
   if fake_file_list > 0:
      remainder = [file_list[fn]["flnm"]]

   #print("file list remainder= ", remainder)
   for x in remainder:
      
      do_it = True
      if fake_file_list > 0:
         for ck in range(len(file_list)):
             if file_list[ck]["flnm"] == x:
                if file_list[ck]["done"] == 1:
                   do_it = False
                else:
                   file_list[ck]["done"] = 1
         if do_it == False:
            continue

      data = []
      with open(x) as tsv:
          for line in csv.reader(tsv, dialect="excel-tab"):
              data.append(line)
      
      chrts = 0
      ch_arr = []
      sheet_nm = "sheet1"
      ch_type  = "line"
      for i in range(len(data)):
          for j in range(len(data[i])):
              if j == 0 and data[i][j] == "title":
                 print("got title for x= %s\n" % (x))
                 chrts = chrts + 1
                 ch = []
                 ch.append(["title", i, j])
                 if len(data[i]) >= 4:
                    sheet_nm = data[i][3]
                 if len(data[i]) >= 6:
                    ch_type = data[i][5]
                    ch[0].append(ch_type)
              if j == 0 and data[i][j] == "hdrs":
                 print("got hdrs for x= %s\n" % (x))
                 ch.append(["hdrs", i])
                 ch_arr.append(ch)
              #print(data[i][j])
          print("")
      
      prefix = prefix_dict[fo]
      print("prefix2= ", prefix, ", fo= ", fo, ", file_list[",fn,"]= ", file_list[fn], ", x= ",x)
      print("sheet_nm= %s\n" % (sheet_nm))
      wrksh_nm = sheet_nm
      if len(prefix) > 0:
         wrksh_nm = sheet_nm + "_" + prefix
      worksheet = workbook.add_worksheet(wrksh_nm)
      bold = workbook.add_format({'bold': 1})
   
      for c in range(chrts):
          print("got chrt[%d] for x= %s\n" % (c, x))
          title_rw = ch_arr[c][0][1]
          title_cl = ch_arr[c][0][2]
          if len(ch_arr[c][0]) > 3:
             ch_type = ch_arr[c][0][3]
          drw  = ch_arr[c][1][1]
          hrow_beg = int(data[drw][1])
          hcol_beg = int(data[drw][2])
          hrow_end = int(data[drw][1])
          hcol_end = int(data[drw][4])+1
          drow_beg = int(data[drw][1])+1
          dcol_beg = int(data[drw][2])
          drow_end = int(data[drw][3])
          if drow_end == -1:
             for i in range(drow_beg, len(data)):
                 drow_end = i
                 if len(data[i]) == 0:
                    break
             data[drw][3] = str(drow_end)
          dcol_end = int(data[drw][4])+1
          mx = drow_end+1
          if mx > len(data):
             print("dude, mx= ", mx, ", len(data)= ", len(data))
        
          for i in range(drow_end-drow_beg+1):
              for h in range(hcol_end):
                  if (len(data[i+drow_beg]) > h):
                      if h >= len(data[i+drow_beg]):
                         print("dude, idx= ", i+drow_beg, ", h= ", h, ", len(data[idx])= ", len(data[i+drow_beg]), " drow: ", data[i+drow_beg])
                      is_num = is_number(data[i+drow_beg][h])
                      if is_num:
                         data[i+drow_beg][h] = float(data[i+drow_beg][h])
      
      for i in range(len(data)):
          worksheet.write_row(i, 0, data[i])
      
      for c in range(chrts):
          title_rw = ch_arr[c][0][1]
          title_cl = ch_arr[c][0][2]
          if len(ch_arr[c][0]) > 3:
             ch_type = ch_arr[c][0][3]
          title = data[title_rw][title_cl+1]
          drw  = ch_arr[c][1][1]
          hrow_beg = int(data[drw][1])
          hcol_beg = int(data[drw][2])
          hrow_end = int(data[drw][1])
          hcol_end = int(data[drw][4])+1
          drow_beg = int(data[drw][1])+1
          dcol_beg = int(data[drw][2])
          drow_end = int(data[drw][3])
          dcol_end = int(data[drw][4])+1
          use_cats = False
          if len(data[drw]) > 5:
             dcol_cat = int(data[drw][5])
             use_cats = True
          headings = []
          for h in range(hcol_end):
              if (h >= hcol_beg):
                 headings.append(data[hrow_beg][h])
          #worksheet.write_row(hrow_beg, hcol_beg, headings, bold)
          print("sheet= %s ch= %d hro= %d hc= %d hce= %d, dr= %d, dre= %d" % (sheet_nm, c, hrow_beg, hcol_beg, hcol_end, drow_beg, drow_end))
          if ch_type == "scatter_straight":
             chart1 = workbook.add_chart({'type': 'scatter', 'subtype': 'straight'})
          else:
             chart1 = workbook.add_chart({'type': ch_type})
          # Configure the first series.
          for h in range(hcol_end):
              if (h >= hcol_beg):
                  if use_cats:
                     chart1.add_series({
                         'name':       [wrksh_nm, hrow_beg, h],
                         'categories': [wrksh_nm, drow_beg, dcol_cat, drow_end, dcol_cat],
                         'values':     [wrksh_nm, drow_beg, h, drow_end, h],
                     })
                  else:
                     chart1.add_series({
                         'name':       [wrksh_nm, hrow_beg, h],
                         'values':     [wrksh_nm, drow_beg, h, drow_end, h],
                     })
          chart1.set_title ({'name': title})
          chart1.set_style(10)
          ch_opt = {'x_offset': 25, 'y_offset': 10}
          if len(ch_size) >= 2:
             ch_opt = {'x_offset': 25, 'y_offset': 10, 'x_scale': ch_size[0], 'y_scale': ch_size[1]}
             #chart1.set_size(ch_size)
          #rc = worksheet.insert_chart(hrow_beg+1, 0, chart1, {'x_offset': 25, 'y_offset': 10})
          ch_top_at_row = hrow_beg+1
          ch_left_at_col = 0
          if len(ch_array) > 0:
             ch_ln_prev = len(ch_array)-1
             if ch_array[ch_ln_prev][0] == sheet_nm:
                ch_top_at_row = ch_array[ch_ln_prev][1] + int(ch_size[2]*ch_size[1])
                ch_left_at_col = ch_array[ch_ln_prev][2] + 0
          rc = worksheet.insert_chart(ch_top_at_row, ch_left_at_col, chart1, ch_opt)
          if rc == -1:
             print("insert chart failed for sheet= %s, chart= %s, row_beg= %d hcol_end= %d\n" % (sheet_nm, title, hrow_beg, hcol_end), file=sys.stderr)
          ch_array.append([sheet_nm, ch_top_at_row, ch_left_at_col])


   if len(image_files) > 0:
      rw = len(image_files)
      cl = 0
      wks_nm = prefix+'_images'
      if not wks_nm in img_added:
         worksheet = workbook.add_worksheet(wks_nm)
         img_added.append(wks_nm)
         for x in image_files:
            worksheet.insert_image(rw, cl, x)
            rw = rw - 1
            cl = cl + 1
   
if closed_wkbk == False:
    workbook.close()
    closed_wkbk = True
    
sys.exit(0)

