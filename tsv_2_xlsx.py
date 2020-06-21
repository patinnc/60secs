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
clip = ""

options, remainder = getopt.getopt(sys.argv[1:], 'Ab:c:e:f:i:m:o:P:p:s:v', [
                                                         'average',
                                                         'begin=',
                                                         'clip=',
                                                         'end=',
                                                         'file=',
                                                         'images=',
                                                         'max=',
                                                         'output=',
                                                         'phase=',
                                                         'prefix=',
                                                         'size=',
                                                         'verbose',
                                                         ])
sv_remainder = remainder
do_avg = False
max_val = 0.0
ts_beg = -1.0
ts_end = -1.0

print("remainder files: ", remainder)

for opt, arg in options:
    if opt in ('-A', '--average'):
        do_avg = True
    elif opt in ('-b', '--begin'):
        ts_beg = float(arg)
    elif opt in ('-c', '--clip'):
        clip   = arg
    elif opt in ('-e', '--end'):
        ts_end = float(arg)
    elif opt in ('-f', '--file'):
        options_filename = arg
    elif opt in ('-o', '--output'):
        output_filename = arg
        #print("output_filename= ", output_filename, file=sys.stderr)
    elif opt in ('-m', '--max'):
        max_val = float(arg)

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
       if len(opt_fl[i]) == 1 and opt_fl[i][0][0] != "-":
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


#file_list = sorted(file_list1, key=lambda x: (x["base"], x["fl_opt"]))
file_list = file_list1
print(file_list)

fake_file_list = len(file_list)
if fake_file_list == 0:
   file_list.append([])

prefix_dict = {}
img_added = []
wksheet_nms = {}

fn_bs_data = {}  # file_number basename data 
fn_bs_lkup = {}
fn_bs_sum  = {}
fn_bs_n    = {}
fn_bs_lkup_mx = -1

#do_avg = False
#do_avg = True

base_lkup = {}
base_list = {}
base_count= {}
base_done= {}
base_fl_opt= {}
base_mx = -1

for fo2 in range(len(fl_options)):
   fo = fo2
   print("fo= ", fo)
   options, remainder = getopt.getopt(fl_options[fo][1:], 'Ac:i:m:o:P:p:s:v', [
                                                            'average',
                                                            'clip=',
                                                            'images=',
                                                            'max=',
                                                            'output=',
                                                            'phase=',
                                                            'prefix=',
                                                            'size=',
                                                            'verbose',
                                                            ])
   for x in remainder:
      base = os.path.basename(x)
      if not base in base_lkup:
         base_mx += 1
         base_lkup[base] = base_mx
         base_list[base_mx] = base
         base_count[base_mx] = 0
         base_done[base_mx] = 0
         base_fl_opt[base_mx] = {}
         print("adding base_lkup[%s]= %d" % (base, base_mx))
      base_i = base_lkup[base]
      base_count[base_i] += 1
      #base_fl_opt[base_i][fo] = 1

for i in range(base_mx+1):
    print("base_lkup[%s] = %d, count= %d" % (base_list[i], i, base_count[i]))

for bmi in range(base_mx+1):

 print("doing bmi= %d of %d" % (bmi, base_mx+1))
 fn_bs_data[bmi] = {}
 #if fake_file_list > 0:
   #print("bmi= ", bmi, " file_list= ",file_list[bmi])
 for fo2 in range(len(fl_options)):
   fo = fo2
   #if fake_file_list > 0:
   #   fo = file_list[fo]["fl_opt"]
   #if fake_file_list > 0 and fo != file_list[fn]["fl_opt"]:
   #   print("skip fo= ", fo, ", fn= ", fn, " file_list= ",file_list[fo])
   #   continue
   print("fo= ", fo)
   #options, remainder = getopt.getopt(sys.argv[1:], 'i:o:p:v', ['images=',
   options, remainder = getopt.getopt(fl_options[fo][1:], 'Ac:i:m:o:P:p:s:v', [
                                                            'average',
                                                            'clip=',
                                                            'images=',
                                                            'max=',
                                                            'output=',
                                                            'phase=',
                                                            'prefix=',
                                                            'size=',
                                                            'verbose',
                                                            ])

   verbose = False
   image_files=[]
   prefix = ""
   ch_size = [1.0, 1.0, 15.0]

   # if orient_vert == true then put charts down same column.
   # if False, put charts across same row (so scroll right to see charts). This is useful if you start data at row 40 then charts won't obscure data.
   # Also, if you put in a filter on the data, some charts might disappear if they are in the rows hidden by the filter.
   # If the 1st hdr row number is > 35 then ch_orient_vert will be set to false.
   ch_orient_vert = True
   
   print('OPTIONS   :', options)
   ch_array = []
   opt_phase = []
   #do_avg = False
   do_avg_write = False
   
   for opt, arg in options:
       if opt in ('-i', '--images'):
           for x in glob.glob(arg):
              image_files.append(x)
       elif opt in ('-c', '--clip'):
           clip = arg
           print("python clip= ", clip)
       elif opt in ('-o', '--output'):
           output_filename = arg
       elif opt in ('-m', '--max'):
           max_val = float(arg)
       elif opt in ('-A', '--average'):
           do_avg = True
       elif opt in ('-P', '--phase'):
           phase = arg
           print("phase file= %s" % (phase), file=sys.stderr)
           with open(phase) as tsv:
              for line in csv.reader(tsv, delimiter=' ', dialect="excel-tab"):
                  line[1] = float(line[1])
                  if len(line) < 3:
                     line.append("-1.0")
                  if len(line[2]) == 0 or line[2] is None:
                     line[2] = "-1.0"
                  print("line2= '%s', len(line)= %d" % (line[2], len(line)), file=sys.stderr)
                  line[2] = float(line[2])
                  opt_phase.append(line)
           print("phase= ", opt_phase, file=sys.stderr)
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
       print("+++open workbook output_filename", output_filename)
       workbook = xlsxwriter.Workbook(output_filename)
       bold0 = workbook.add_format({'bold': 0})
       opened_wkbk = True
   
   def is_number(s):
       try:
           float(s)
           return True
       except ValueError:
           return False
   
#   if fake_file_list > 0:
#      remainder = [file_list[fo]["flnm"]]

   if verbose:
      print("file list remainder= ", remainder, file=sys.stderr)

   for x in remainder:
      if verbose:
         print("do x fo= %d file= %s" % (fo, x), file=sys.stderr)
#      do_it = True
#      if fake_file_list > 0:
#         got_file_list = 0
#         got_file_list_done = 0
#         for ck in range(len(file_list)):
#             if file_list[ck]["flnm"] == x:
#                got_file_list += 1
#                #print("file_list[%d][done]= %d" % (ck, file_list[ck]["done"]), file=sys.stderr)
#                if file_list[ck]["done"] == 1:
#                   do_it = False
#                else:
#                   file_list[ck]["done"] = 1
#         if do_it == False:
#            continue

      base = os.path.basename(x)
      if not base in fn_bs_lkup:
         fn_bs_lkup_mx += 1
         fn_bs_lkup[base] = fn_bs_lkup_mx
         fn_bs_sum[fn_bs_lkup_mx] = {}
         fn_bs_n[fn_bs_lkup_mx] = {}
      fn_bs_i = fn_bs_lkup[base]

      base_i = base_lkup[base]
      if base_i != bmi:
         continue
      if do_avg:
         if base_i != bmi:
            continue
         base_done[base_i] += 1
      if fo2 in base_fl_opt[base_i]:
         continue
      base_fl_opt[base_i][fo2] = 1
      print("doing bmi= %d, fo= %d, count= %d done= %d base= %s, x= %s" % (bmi, fo, base_count[base_i], base_done[base_i], base, x))

      if do_avg and base_count[base_i] == base_done[base_i]:
        do_avg_write = True
        print("do_avg_write = True", file=sys.stderr)
      else:
        do_avg_write = False


      data = []
      if not fo in fn_bs_data[bmi]:
         with open(x) as tsv:
            for line in csv.reader(tsv, dialect="excel-tab"):
              data.append(line)
         fn_bs_data[bmi][fo] = data
      else:
         data = fn_bs_data[bmi][fo]
      
      chrts = 0
      ch_arr = []
      ch_cols_used = {}
      sheet_nm = "sheet1"
      ch_type  = "line"
      for i in range(len(data)):
          for j in range(len(data[i])):
              if j == 0 and data[i][j] == "title":
                 #print("got title for x= %s\n" % (x))
                 chrts = chrts + 1
                 ch = []
                 ch.append(["title", i, j])
                 if len(data[i]) >= 4:
                    sheet_nm = data[i][3]
                 if len(data[i]) >= 6:
                    ch_type = data[i][5]
                    ch[0].append(ch_type)
              if j == 0 and data[i][j] == "hdrs":
                 #print("got hdrs for x= %s\n" % (x))
                 ch.append(["hdrs", i])
                 ch_arr.append(ch)
              #print(data[i][j])
          #print("")
      
      if fo in prefix_dict:
         prefix = prefix_dict[fo]
      else:
         prefix = ""
         
      if verbose:
         print("prefix2= ", prefix, ", fo= ", fo, ", file_list[",fo,"]= ", file_list[fo], ", x= ",x)
         print("sheet_nm= %s\n" % (sheet_nm))
      wrksh_nm = sheet_nm
      if len(prefix) > 0:
         wrksh_nm = sheet_nm + "_" + prefix
      if do_avg == False or do_avg_write == True:
         if wrksh_nm in wksheet_nms:
             for i in range(100):
               tnm = wrksh_nm + "_" + str(i)
               #print("ck if worksheet name %s exists" % (tnm), file=sys.stderr)
               if not tnm in wksheet_nms:
                  if verbose:
                     print("use worksheet name %s" % (tnm), file=sys.stderr)
                  wrksh_nm = tnm
                  break
         print("use worksheet name %s" % (wrksh_nm), file=sys.stderr)
         worksheet = workbook.add_worksheet(wrksh_nm)
         wksheet_nms[wrksh_nm] = 1
         bold = workbook.add_format({'bold': 1})
   
      for c in range(chrts):
          #print("got chrt[%d] for x= %s\n" % (c, x))
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
          for i in range(dcol_beg, dcol_end):
             ch_cols_used[i] = 1
          mcol_num_cols = len(data[drw])
          if mcol_num_cols > 6:
             for h in range(6, mcol_num_cols, 2):
                 #print("sheet_nm= %s got series[%d] colb= %d cole= %d" % (sheet_nm, len(mcol_list), int(data[drw][h]), int(data[drw][h+1])))
                 tcol0 = int(data[drw][h])
                 tcol1 = int(data[drw][h+1])
                 if tcol0 > -1 and tcol1 > -1:
                    for i in range(tcol0, tcol1+1):
                        ch_cols_used[i] = 1
          mx = drow_end+1
          if mx > len(data):
             print("dude, mx= ", mx, ", len(data)= ", len(data))
        
          for i in range(drow_end-drow_beg+1):
              for h in range(hcol_end):
                  ck_max = False
                  if max_val > 0.0 and h in ch_cols_used:
                     ck_max = True
                  ij = i+drow_beg
                  if not ij in fn_bs_sum[fn_bs_i]:
                     fn_bs_sum[fn_bs_i][ij] = {}
                     fn_bs_n[fn_bs_i][ij] = {}
                  if (len(data[ij]) > h):
                      if h >= len(data[ij]):
                         print("dude, idx= ", ij, ", h= ", h, ", len(data[idx])= ", len(data[ij]), " drow: ", data[ij])
                      is_num = is_number(data[ij][h])
                      if is_num:
                         data[ij][h] = float(data[ij][h])
                         if ck_max:
                            if data[ij][h] > max_val:
                               data[ij][h] = 0.0
                         if not h in fn_bs_sum[fn_bs_i][ij]:
                            #fn_bs_sum[fn_bs_i][ij] = {}
                            fn_bs_sum[fn_bs_i][ij][h] = 0.0;
                            fn_bs_n[fn_bs_i][ij][h] = 0;
                         fn_bs_sum[fn_bs_i][ij][h] += data[ij][h]
                         fn_bs_n[fn_bs_i][ij][h] += 1;
                      else:
                         fn_bs_sum[fn_bs_i][ij][h] = data[ij][h]
                         fn_bs_n[fn_bs_i][ij][h] = -1;
      
      ph_add = 0
      ph_done = 0
      if len(opt_phase) > 0:
         ph_add = 1

      if do_avg == False or do_avg_write == True:
         #print("---- do_avg= %s, do_avg_write= %s, fn_bs_sum[%d] rows= %d" % (do_avg, do_avg_write, fn_bs_i, len(fn_bs_sum[fn_bs_i])), file=sys.stderr)
         if do_avg_write == True:
            #print("fn_bs_sum[%d] rows= %d" % (fn_bs_i, len(fn_bs_sum[fn_bs_i])), file=sys.stderr)
            for i in fn_bs_sum[fn_bs_i]:
                #print("row[%d].len= %d" % (i, len(fn_bs_sum[fn_bs_i][i])), file=sys.stderr)
                for j in fn_bs_sum[fn_bs_i][i]:
                   #print("row[%d][%d]= %s" % (i, j, fn_bs_sum[fn_bs_i][i][j]), file=sys.stderr)
                   val = fn_bs_sum[fn_bs_i][i][j]
                   num = fn_bs_n[fn_bs_i][i][j]
                   if num > 0:
                      val /= num;
                   worksheet.write(i, j, val)
            for i in range(len(data)):
                if not i in fn_bs_sum[fn_bs_i]:
                   worksheet.write_row(i, ph_add, data[i])
         else:
            for i in range(len(data)):
                worksheet.write_row(i, ph_add, data[i])
      
      for c in range(chrts):
          dcol_cat = -1
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
          if c == 0:
             if drw >= 35:
                ch_orient_vert = False
             else:
                ch_orient_vert = True
          if drow_end == -1 or drow_beg >= drow_end:
             print("no data for chart! sheet_nm= %s, ch_typ= %s, file= %s, drow_beg= %d, drow_end= %d, hcol_beg= %d, hcol_end= %d" % (sheet_nm, ch_type, x, drow_beg, drow_end, hcol_beg, hcol_end), file=sys.stderr)
             # didn't find any data in table
             continue
          use_cats = False
          mcol_end = int(data[drw][4])+1
          mcol_num_cols = len(data[drw])
          mcol_list = []
          if mcol_num_cols > 5 and int(data[drw][5]) > -1:
             dcol_cat = int(data[drw][5])
             use_cats = True
          if mcol_num_cols > 6:
             for h in range(6, mcol_num_cols, 2):
                 #print("sheet_nm= %s got series[%d] colb= %d cole= %d" % (sheet_nm, len(mcol_list), int(data[drw][h]), int(data[drw][h+1])))
                 tcol0 = int(data[drw][h])
                 tcol1 = int(data[drw][h+1])
                 if tcol0 > -1 and tcol1 > -1:
                    mcol_list.append([tcol0, tcol1+1])
          else:
             if hcol_beg < 0 or hcol_end < 0:
                print("What going on, sheet_nm= %s, ch_typ= %s, file= %s, hcol_beg= %d, hcol_end= %d" % (sheet_nm, ch_type, x, hcol_beg, hcol_end), file=sys.stderr)
             mcol_list.append([hcol_beg, hcol_end])
          print("sheet= %s ch= %d hro= %d hc= %d hce= %d, dr= %d, dre= %d" % (sheet_nm, c, hrow_beg, hcol_beg, hcol_end, drow_beg, drow_end))
          ch_style = 10
          chart1 = None
          if ch_type == "scatter_straight":
             if ph_done == 0 and ph_add == 1 and dcol_cat > 0:
                ph_done = 1
                for ii in range(len(data)):
                    #  'categories': [wrksh_nm, drow_beg, dcol_cat+ph_add, drow_end, dcol_cat+ph_add],
                    jjj = dcol_cat-1
                    if len(data[ii]) <  1 or ii <= hrow_beg:
                       continue
                    if data[ii][jjj] is None or data[ii][jjj] == '':
                       continue
                    if ii > drow_end:
                       continue
                    tval = data[ii][jjj]
                    in_phase = False
                    for jj in range(len(opt_phase)):
                       if tval >= opt_phase[jj][1] and (tval <= opt_phase[jj][2] or opt_phase[jj][2] == -1):
                          if do_avg == False or do_avg_write == True:
                             worksheet.write(ii, 0, opt_phase[jj][0])
                             in_phase = True
                          break
                    if in_phase == False and clip != "":
                       #print("try to zero out row ", ii, " len= ", len(data[ii]))
                       for ij in range(len(data[ii])):
                           worksheet.write_blank(ii, ph_add+ij, None, bold0)

             if do_avg == False or do_avg_write == True:
                chart1 = workbook.add_chart({'type': 'scatter', 'subtype': 'straight'})
          else:
             if ch_type != "copy":
                if do_avg == False or do_avg_write == True:
                   chart1 = workbook.add_chart({'type': ch_type})
          if ch_type == "copy":
             #print("chart_type= copy", file=sys.stderr)
             continue
          # Configure the first series.
          got_how_many_series_for_chart = 0
          for hh in range(len(mcol_list)):
              for h in range(mcol_list[hh][0], mcol_list[hh][1]):
                  if h < 0:
                     print("What going on2, sheet_nm= %s, ch_typ= %s, file= %s, hcol_beg= %d, hcol_end= %d" % (sheet_nm, ch_type, x, hcol_beg, hcol_end), file=sys.stderr)
                  if drow_beg < 0 or drow_end < 0:
                     print("What going on3, sheet_nm= %s, ch_typ= %s, file= %s, drow_beg= %d drow_end= %d hcol_beg= %d, hcol_end= %d" % (sheet_nm, ch_type, x, drow_beg, drow_end, hcol_beg, hcol_end), file=sys.stderr)
                     continue
                  got_how_many_series_for_chart += 1
                  if do_avg == False or do_avg_write == True:
                   if use_cats:
                     chart1.add_series({
                         'name':       [wrksh_nm, hrow_beg, h+ph_add],
                         'categories': [wrksh_nm, drow_beg, dcol_cat+ph_add, drow_end, dcol_cat+ph_add],
                         'values':     [wrksh_nm, drow_beg, h+ph_add, drow_end, h+ph_add],
                     })
                   else:
                     chart1.add_series({
                         'name':       [wrksh_nm, hrow_beg, h+ph_add],
                         'values':     [wrksh_nm, drow_beg, h+ph_add, drow_end, h+ph_add],
                     })
          if got_how_many_series_for_chart == 0:
             print("What going on4, sheet_nm= %s, ch_typ= %s, file= %s, drow_beg= %d drow_end= %d hcol_beg= %d, hcol_end= %d" % (sheet_nm, ch_type, x, drow_beg, drow_end, hcol_beg, hcol_end), file=sys.stderr)
          if do_avg == False or do_avg_write == True:
             chart1.set_title ({'name': title})
             chart1.set_style(ch_style)
             ch_opt = {'x_offset': 25, 'y_offset': 10}
             if len(ch_size) >= 2:
                ch_opt = {'x_offset': 25, 'y_offset': 10, 'x_scale': ch_size[0], 'y_scale': ch_size[1]}
             if ch_orient_vert:
                ch_top_at_row = hrow_beg+1
                ch_left_at_col = 0
                if len(ch_array) > 0:
                   ch_ln_prev = len(ch_array)-1
                   if ch_array[ch_ln_prev][0] == sheet_nm:
                      ch_top_at_row = ch_array[ch_ln_prev][1] + int(ch_size[2]*ch_size[1])
                      ch_left_at_col = ch_array[ch_ln_prev][2] + 0
             else:
                ch_top_at_row = 1
                ch_left_at_col = 0
                if len(ch_array) > 0:
                   ch_ln_prev = len(ch_array)-1
                   if ch_array[ch_ln_prev][0] == sheet_nm:
                      ch_top_at_row = ch_array[ch_ln_prev][1] + 0
                      ch_left_at_col = ch_array[ch_ln_prev][2] + int(ch_size[2])
                #print("sh %s ch %s row= %d col= %d" % (sheet_nm, title, ch_top_at_row, ch_left_at_col))
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
    print("close workbook %s\n" % (output_filename), file=sys.stderr)
    workbook.close()
    closed_wkbk = True
    
sys.exit(0)

