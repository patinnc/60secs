#######################################################################
#
# started from an example of creating Excel Line charts with Python and XlsxWriter from John McNamara, jmcnamara@cpan.org
# but massive changes
#
# need to install xlsxwriter in python
# pip install xlsxwriter
# python tsv_2_xlsx.py -o tst.xlsx -i "*.png" sys_*.txt.tsv
#   The optional '-i "*.png"' image file glob is in dbl quotes so it won't get expanded on the command line.
#   The glob gets expanded in the script. If you don't enclose the glob in quotes then only 1 image file name gets passed to the -i option and the rest get treated as tsv files.


from __future__ import print_function
from __future__ import unicode_literals
from datetime import date
#from importlib import reload
import importlib
import xlsxwriter
import csv
import getopt
import sys
import glob
import os
import io
import math

# the 2 statements below workaround a "UnicodeEncodeError: 'ascii' codec can't encode character u'\xb5' in position 21: ordinal not in range(128)"
# error when I read yab cmd json files
if sys.version_info.major == 2:
  import imp
  imp.reload(sys)  
else:
  importlib.reload(sys)  
#if sys.version_info.major == 2:
#sys.setdefaultencoding('utf8')

output_filename = 'chart_line.xlsx'
opened_wkbk = False
closed_wkbk = False

options_filename = ""
options_phase    = ""
clip = ""
options_str = ""
options_str_top = ""
worksheet_charts = None
ch_sh_arr = []
verbose = False
tsv_dialect = "excel-tab"
chart_show_blanks_as = "gap" # or "zero" or "span"
options_all_charts_one_row = False
options_get_max_val = False
all_charts_one_row = []
all_charts_one_row_hash = {}
all_charts_one_row_max = -1
desc = None
options_sku = None
set_col_arr = []
xlsx_add_line_from_file_to_charts_sheet = []
got_sum_all = 0
sum_all_file = ""
sum_all_base = ""

#print("%f" % (1.0/0.0))  # force an error for testing to check error handling

# check actual cmdline args
options, remainder = getopt.getopt(sys.argv[1:], 'Aa:b:c:d:e:f:i:m:o:O:P:p:s:S:v', [
                                                         'average',
                                                         'avg_dir',
                                                         'begin=',
                                                         'clip=',
                                                         'desc=',
                                                         'end=',
                                                         'file=',
                                                         'images=',
                                                         'max=',
                                                         'output=',
                                                         'options=',
                                                         'phase=',
                                                         'prefix=',
                                                         'size=',
                                                         'sum_all=',
                                                         'verbose'
                                                         'sku=',
                                                         'phase=',
                                                         ])
sv_remainder = remainder
do_avg = False
max_val = 0.0
ts_beg = -1.0
ts_end = -1.0
avg_dir = None;

gmarker_type_lst = ["square", "diamond", "triangle", "x", "star", "short_dash", "long_dash", "circle", "plus"]
#print("remainder files: ", remainder)
#gcolor_lst = ["#b0556a", "#7adf39", "#8d40d6", "#ead12d", "#0160eb", "#aaed78", "#f945b7", "#04e6a0", "#cf193b", "#4df8ca", "#b21f72", "#41981b", "#b773eb", "#276718", "#f39afb", "#0ea26a", "#015fc6", "#ec7118", "#108cf5", "#feab4f", "#1eacf8", "#a13502", "#49f6fd", "#9e5d33", "#30d8ec", "#ab952f", "#8156a5", "#f5db82", "#1e67a9", "#f6b17c", "#47caf9", "#695909", "#7daaef", "#a4ce84", "#ef89bb", "#1c6c43", "#ecb5f2", "#7ddab8", "#0f88b4", "#07a1b2"];
gcolor_lst= ["#1f77b4", "#aec7e8", "#ff7f0e", "#ffbb78", "#2ca02c", "#98df8a", "#d62728", "#ff9896", "#9467bd", "#c5b0d5",
  "#8c564b", "#c49c94", "#e377c2", "#f7b6d2", "#7f7f7f", "#c7c7c7", "#bcbd22", "#dbdb8d", "#17becf", "#9edae5" ];

for opt, arg in options:
    if opt == '-A' or opt == '--average':
        do_avg = True
    elif opt == '-a' or opt == '--avg_dir':
        avg_dir = arg
    elif opt == '-b' or opt == '--begin':
        ts_beg = float(arg)
    elif opt == '-c' or opt == '--clip':
        clip   = arg
    elif opt == '-d' or opt == '--desc':
        desc   = arg
    elif opt == '-e' or opt == '--end':
        ts_end = float(arg)
    elif opt == '-f' or opt == '--file':
        options_filename = arg
    elif opt == '-o' or opt == '--output':
        output_filename = arg
    elif opt == '--sku':
        options_sku = arg
        print("_______ --sku arg, opt=", opt, ", arg= ", arg)
    elif opt == '--phase':
        options_phase = arg
    elif opt == '-O' or opt == '--options':
        options_str = arg
        options_str_top = arg
        #print("options_str_top= ", options_str_top, file=sys.stderr)
    elif opt == '-m' or opt == '--max':
        max_val = float(arg)
    elif opt == '-S' or opt == '--sum_file':
        #got_sum_all += 1
        sum_all_file = arg
        sum_all_base = os.path.basename(sum_all_file)
        print("sum_all_base= %s" % (sum_all_base))
    elif opt == '-v' or opt == '--verbose':
        verbose = True

if options_str.find("drop_summary") >= 0:
   got_drop_summary = True
else:
   got_drop_summary = False
if options_str.find("all_charts_one_row") >= 0:
   options_all_charts_one_row = True
if options_str.find("tsv_dialect{excel-csv}") >= 0:
   tsv_dialect = "excel"
   print("tsv_dialect= excel")

chart_show_blanks_as = "gap" # or "zero" or "span"
chart_show_blanks_set = False
if options_str.find("chart_show_blanks_as{gap}") >= 0:
   chart_show_blanks_as = "gap" # or "zero" or "span"
   chart_show_blanks_set = True
elif options_str.find("chart_show_blanks_as{zero}") >= 0:
   chart_show_blanks_as = "zero" # or "zero" or "span"
   chart_show_blanks_set = True
elif options_str.find("chart_show_blanks_as{span}") >= 0:
   chart_show_blanks_as = "span" # or "zero" or "span"
   chart_show_blanks_set = True

# don't do get_max_val here. data suppliers have to create new 'peak' variables and old avg variables
#if options_str.find("get_max_val") >= 0:
#   options_get_max_val = True
#   options_get_max_val = True
#   print("opt= %s, get_max_val= %s" % (opt, options_get_max_val), file=sys.stderr)

sheets_limit = []
arr = options_str.split(",")
if verbose > 0:
   print("options_str= ", options_str, ", options arr= ", arr)
if len(options_str) > 0:
  arr = options_str.split(",")
  if verbose > 0:
     print("options arr= ", arr)
  for opt in arr:
    lkfor = "sheet_limit{"
    i = opt.find(lkfor)
    if verbose > 0:
       print("opt= ", opt, ", i=", i)
    if i == 0:
       str2 = opt[len(lkfor):-1]
       arr2 = str2.split(";")
       sheets_limit.append([arr2[0], arr2[1],arr[2]])
       if verbose > 0:
          print("opt= %s, lkfor= %s, str2= %s" % (opt, lkfor, str2), file=sys.stderr)
    lkfor="xlsx_set_col_width{"
    # xlsx_set_col_width{sum_all!C:C;30) optional sheetnm, col can be range or 1 col
    if opt.find(lkfor) >= 0:
       pos = opt.find(lkfor) + len(lkfor)
       mstr = opt[pos:]
       print("+++++++set_col= ", mstr);
       #worksheet.set_column
       pos = mstr.find("}")
       mstr = mstr[:pos]
       print("+++++++set_col= ", mstr);
       set_col_sheet = ""
       pos = mstr.find("!")
       if pos > 0:
         set_col_sheet = mstr[:pos]
         mstr = mstr[pos+1:]
       print("set_col sheet= ", set_col_sheet, ", mstr= ", mstr)
       pos = mstr.find(";")
       set_col_cols = ""
       if pos > 0:
         set_col_cols = mstr[:pos]
         mstr = mstr[pos+1:]
       set_col_width = 0
       if len(mstr) > 0:
         set_col_width = int(mstr)
       if set_col_width > 0 and set_col_cols != "":
         set_col_arr.append({"sheet":set_col_sheet, "cols":set_col_cols, "width":set_col_width, "level":None})
       print("set_col_arr len= ", len(set_col_arr), set_col_arr)

    lkfor="xlsx_add_line_from_file_to_charts_sheet{"
    # xlsx_add_line_from_file_to_charts_sheet{filename} tab delimited line of text from file for row 1 of charts file
    if opt.find(lkfor) >= 0:
       pos = opt.find(lkfor) + len(lkfor)
       mstr = opt[pos:]
       pos = mstr.find("}")
       mstr = mstr[:pos]
       print("+++++++xlsx_add_line_from_file_to_charts_sheet file= ", mstr);
       with open(mstr, 'rU') as tsv:
         for line in csv.reader(tsv, dialect="excel-tab"):
           #print("try options_file %s line %s" % (options_filename, line), file=sys.stderr)
           if len(line) > 0 and len(line[0]) > 0 and line[0][0] == "#":
             #print("skip options_file %s line %s" % (options_filename, line), file=sys.stderr)
             continue
           xlsx_add_line_from_file_to_charts_sheet.append(line)
       #abc
       print("xlsx_add_line_from_file_to_charts_sheet= ", xlsx_add_line_from_file_to_charts_sheet)


if verbose > 0:
   print("sheets_limit= ", sheets_limit)
opt_fl = []
fl_options = []
file_list1 = []

if options_filename != "":
   opt_fl = []
   with open(options_filename, 'rU') as tsv:
       for line in csv.reader(tsv, dialect="excel-tab"):
           #print("try options_file %s line %s" % (options_filename, line), file=sys.stderr)
           if len(line) > 0 and len(line[0]) > 0 and line[0][0] == "#":
             #print("skip options_file %s line %s" % (options_filename, line), file=sys.stderr)
             continue
           opt_fl.append(line)

if len(opt_fl) > 0:
   fl_opt = 0
   fl_options.append([sys.argv[0]])
   if verbose > 0:
      print("len(fl_options)= %d at 20, len(opt_fl)= %d" % (len(fl_options), len(opt_fl)), file=sys.stderr)
   for i in range(len(opt_fl)):
       # use blank lines to mark groups, might have multiple consecutive blanks so only use change from non-blank to blank
       if len(opt_fl[i]) == 0 and i > 0 and len(opt_fl[i-1]) > 0:
          fl_opt = fl_opt + 1
          fl_options.append([sys.argv[0]])
          #print("len(fl_options)= %d at 22" % (len(fl_options)), file=sys.stderr)
          continue
       if len(opt_fl[i]) == 1 and opt_fl[i][0][0] != "-":
          if verbose > 0:
             print("path? try= ", opt_fl[i][0])
          base = os.path.basename(opt_fl[i][0])
          file_list1.append({"fl_opt":fl_opt, "flnm":opt_fl[i][0], "base":base, "done":0})
          if sum_all_base != "" and base == sum_all_base:
             got_sum_all += 1
       for j in range(len(opt_fl[i])):
           fl_options[fl_opt].append(opt_fl[i][j])
else:
   fl_opt = 0
   #print("len(fl_options)= %d at 30" % (len(fl_options)), file=sys.stderr)
   fl_options.append([])
   for i in range(len(sys.argv)):
       fl_options[fl_opt].append(sys.argv[i])

if verbose > 0:
   print("len(fl_options)= %d at 50" % (len(fl_options)), file=sys.stderr)

print("got number of sum_all.tsv files= ", got_sum_all)
#file_list = sorted(file_list1, key=lambda x: (x["base"], x["fl_opt"]))
file_list = file_list1
if verbose > 0:
   print("tsv_2_xls.py: file_list: ", file_list)

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
fn_bs_hdr_list  = {}
fn_bs_hdr_lkup  = {}
fn_bs_hdr_rows  = {}
fn_bs_hdr_chrt  = {}
fn_bs_hdr_map   = {}
fn_bs_hdr_max   = {}
fn_bs_lkup_mx = -1

#do_avg = False
#do_avg = True

base_lkup = {}
base_list = {}
base_count= {}
base_done= {}
base_fl_opt= {}
base_mx = -1

def is_number(s):
    try:
      float(s)
      return True
    except ValueError:
      return False

def ck_set_col_width(wrksht, nm):
    if len(set_col_arr) == 0:
      return
    for i in range(len(set_col_arr)):
      len_in  = len(nm)
      nm_arr  = set_col_arr[i]["sheet"]
      len_arr = len(nm_arr)
      print("+++ck set_column nm= %s width(%s!%s, %d), sub_nm= %s" % (nm, set_col_arr[i]["sheet"], set_col_arr[i]["cols"], set_col_arr[i]["width"], nm[:len_arr]))
      if nm_arr == nm or len_arr == 0 or (len_arr < len_in and nm[:len_arr] == nm_arr):
         rc = wrksht.set_column(set_col_arr[i]["cols"], set_col_arr[i]["width"])
         print("+++did set_column width(%s!%s, %d), rc= %d" % (nm, set_col_arr[i]["cols"], set_col_arr[i]["width"], rc))
    return

   
# now check the options in the options file
for fo2 in range(len(fl_options)):
   fo = fo2
   if verbose > 0:
      print("fo= ", fo)
   options, remainder = getopt.getopt(fl_options[fo][1:], 'Aa:b:c:d:e:i:m:o:O:P:p:s:S:v', [
                                                            'average',
                                                            'avg_dir',
                                                            'begin',
                                                            'clip=',
                                                            'desc=',
                                                            'end=',
                                                            'images=',
                                                            'max=',
                                                            'output=',
                                                            'options=',
                                                            'phase=',
                                                            'prefix=',
                                                            'size=',
                                                            'sum_all=',
                                                            'verbose',
                                                            'sku=',
                                                            'phase=',
                                                            ])
   for opt, arg in options:
       if opt == '-A' or opt ==  '--average':
           do_avg = True
       elif opt == '-p' or opt == '--prefix':
           prefix = arg
           prefix_dict[fo] = prefix

   for x in remainder:
      pfx = ""
      if fo in prefix_dict:
         pfx = prefix_dict[fo]
      pfx_xtra = ""
      if not do_avg:
        pfx_xtra = pfx
      base = os.path.basename(x) + pfx_xtra
      if got_sum_all > 0 and got_drop_summary and len(base) >= 7 and base[0:7] == "summary":
         print("skip sum_file x= %s" % (x), file=sys.stderr)
         continue
      if not base in base_lkup:
         base_mx += 1
         base_lkup[base] = base_mx
         base_list[base_mx] = base
         base_count[base_mx] = 0
         base_done[base_mx] = 0
         base_fl_opt[base_mx] = {}
         if verbose > 0:
            print("adding base_lkup[%s]= %d" % (base, base_mx))
      base_i = base_lkup[base]
      base_count[base_i] += 1
      #base_fl_opt[base_i][fo] = 1

worksheet_sum_all = None
worksheet_sum_all_nm = None

for i in range(base_mx+1):
    if verbose > 0:
       print("base_lkup[%s] = %d, count= %d" % (base_list[i], i, base_count[i]))

for fo2 in range(len(fl_options)):
   all_charts_one_row.append([-1, 1, 0, None])

for bmi in range(base_mx+1):

 if verbose > 0:
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
   if verbose > 0:
      print("fo= ", fo)
   #options, remainder = getopt.getopt(sys.argv[1:], 'i:o:p:v', ['images=',
   options, remainder = getopt.getopt(fl_options[fo][1:], 'Aa:b:c:d:e:i:m:o:O:P:p:s:S:v', [
                                                            'average',
                                                            'avg_dir',
                                                            'begin=',
                                                            'clip=',
                                                            'desc=',
                                                            'end=',
                                                            'images=',
                                                            'max=',
                                                            'output=',
                                                            'options=',
                                                            'phase=',
                                                            'prefix=',
                                                            'size=',
                                                            'sum_all=',
                                                            'verbose',
                                                            'sku=',
                                                            'phase=',
                                                            ])

   image_files=[]
   prefix = ""
   ch_size = [1.0, 1.0, 15.0, 8.0]

   # if orient_vert == true then put charts down same column.
   # if False, put charts across same row (so scroll right to see charts). This is useful if you start data at row 40 then charts won't obscure data.
   # Also, if you put in a filter on the data, some charts might disappear if they are in the rows hidden by the filter.
   # If the 1st hdr row number is > 35 then ch_orient_vert will be set to false.
   ch_orient_vert = True
   
   if verbose > 0:
      print('OPTIONS   :', options)
   ch_array = []
   opt_phase_in = []
   opt_phase = []
   #do_avg = False
   do_avg_write = False
   
   for opt, arg in options:
       if opt == '-i' or opt == '--images':
           for x in glob.glob(arg):
              image_files.append(x)
       elif opt == '-b' or opt == '--begin':
           ts_beg = float(arg)
           print("ts_beg= %f" % (ts_beg), file=sys.stderr)
       elif opt == '-e' or opt == '--end':
           ts_end = float(arg)
           print("ts_end= %f" % (ts_end), file=sys.stderr)
       elif opt == '-c' or opt == '--clip':
           clip = arg
           print("python clip= ", clip)
       elif opt == '-d' or opt == '--desc':
           desc = arg
           all_charts_one_row[fo2][3] = desc
       elif opt == '-o' or opt == '--output':
           output_filename = arg
       elif opt == '-O' or opt == '--options':
           options_str = arg
       elif opt == '-m' or opt == '--max':
           max_val = float(arg)
       elif opt == '-A' or opt == '--average':
           do_avg = True
       elif opt == '--sku':
           options_sku = arg
           print("_______ --sku arg, opt=", opt, ", arg= ", arg)
       elif opt == '--phase':
           options_phase = arg
       elif opt == '-P' or opt == '--phase':
           phase = arg
           print("tsv_2_xls.ph: phase file= %s" % (phase), file=sys.stderr)
           #with open(phase, 'rU') as tsv:
           with io.open(phase, "rU", encoding="utf-8") as tsv:
              ln2 = [None, None, None]
              for line in csv.reader(tsv, delimiter=str(' '), dialect="excel-tab"):
                  if len(line) >= 3 and (line[0] == "beg" or line[0] == "end") and not is_number(line[1]):
                     if line[0] == "beg" and is_number(line[2]):
                        ln2[1] = float(line[2])
                     if line[0] == "end" and is_number(line[2]):
                        ln2[0] = line[1] 
                        ln2[2] = float(line[2])
                        opt_phase_in.append(ln2)
                  else:
                     if is_number(line[1]):
                        line[1] = float(line[1])
                     if len(line) < 3:
                        line.append("-1.0")
                     if len(line[2]) == 0 or line[2] is None:
                        line[2] = "-1.0"
                     #print("line2= '%s', len(line)= %d" % (line[2], len(line)), file=sys.stderr)
                     line[2] = float(line[2])
                     opt_phase_in.append(line)
           tsv.close
           opt_phase = sorted(opt_phase_in, key=lambda x: x[1])
           #print("phase= ", opt_phase, file=sys.stderr)
       elif opt == '-p' or opt == '--prefix':
           prefix = arg
           prefix_dict[fo] = prefix
       elif opt == '-s' or opt == '--size':
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
           if len(ch_tsize) >= 3:
              ch_size[2] = float(ch_tsize[2])
              ch_size[3] = float(ch_tsize[2])
           if len(ch_tsize) == 4:
              ch_size[3] = float(ch_tsize[3])
       elif opt == '-v' or opt == '--verbose':
           verbose = True

   
   if opened_wkbk == False:
       print("+++open workbook output_filename", output_filename)
       workbook = xlsxwriter.Workbook(output_filename)
       workbook.formats[0].set_font_size(14)
       bold0 = workbook.add_format({'bold': 0})
       opened_wkbk = True
       if got_sum_all > 0:
          if fo in prefix_dict:
             prefix = prefix_dict[fo]
          else:
             prefix = ""
         
          sheet_nm = "sum_all"
          wrksh_nm = sheet_nm
          if len(prefix) > 0:
             wrksh_nm = sheet_nm + "_" + prefix
          worksheet = workbook.add_worksheet(wrksh_nm)
          ck_set_col_width(worksheet, wrksh_nm)
          worksheet_sum_all = worksheet
          worksheet_sum_all_nm = wrksh_nm
          wksheet_nms[wrksh_nm] = 1
          bold = workbook.add_format({'bold': 1})
       if options_str.find("chart_sheet") >= 0:
          wrksh_nm = "charts"
          worksheet_charts = workbook.add_worksheet(wrksh_nm)
          ck_set_col_width(worksheet_charts, wrksh_nm)
          worksheet_charts_nm = wrksh_nm
          if len(xlsx_add_line_from_file_to_charts_sheet) > 0:
             worksheet_charts.write_row(0, 0, xlsx_add_line_from_file_to_charts_sheet[0])
          ch_sh_row = -1
   
#   if fake_file_list > 0:
#      remainder = [file_list[fo]["flnm"]]

   if verbose:
      print("file list remainder= ", remainder, file=sys.stderr)

   drow_end = -1
   filenum = -1
   for x in remainder:
      filenum = filenum + 1
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

      pfx = ""
      if fo in prefix_dict:
         pfx = prefix_dict[fo]
      pfx_xtra = ""
      if not do_avg:
        pfx_xtra = pfx
      base = os.path.basename(x) + pfx_xtra
      if not base in fn_bs_lkup:
         fn_bs_lkup_mx += 1
         fn_bs_lkup[base] = fn_bs_lkup_mx
         fn_bs_sum[fn_bs_lkup_mx] = {}
         fn_bs_n[fn_bs_lkup_mx] = {}
         fn_bs_hdr_list[fn_bs_lkup_mx] = {}
         fn_bs_hdr_lkup[fn_bs_lkup_mx] = {}
         fn_bs_hdr_rows[fn_bs_lkup_mx] = {}
         fn_bs_hdr_chrt[fn_bs_lkup_mx] = {}
         fn_bs_hdr_map[fn_bs_lkup_mx] = {}
         fn_bs_hdr_max[fn_bs_lkup_mx] = {}
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
      if verbose > 0:
         print("doing bmi= %d, fo= %d, count= %d done= %d base= %s, x= %s" % (bmi, fo, base_count[base_i], base_done[base_i], base, x))

      if do_avg and base_count[base_i] == base_done[base_i]:
        do_avg_write = True
        #print("do_avg_write = True", file=sys.stderr)
      else:
        do_avg_write = False


      data = []
      if not fo in fn_bs_data[bmi]:
         #with open(x, 'rU', encoding="utf-8") as tsv:
         #with open(x, "rU") as tsv:
         linenum = -1
         with io.open(x, "rU", encoding="utf-8") as tsv:
            try:
               #for line in csv.reader(tsv, dialect="excel-tab"):
               for line in csv.reader(tsv, dialect=tsv_dialect):
                   linenum = linenum +1
                   data.append(line)
            except:
               print("---- error read tsv filename[%d]= %s, linenum= %d" % (filenum, x, linenum), file=sys.stderr)
               sys.exit(1)
         tsv.close
         fn_bs_data[bmi][fo] = data
      else:
         data = fn_bs_data[bmi][fo]
      
      print("do_avg= %d bmi= %d, " % (do_avg, bmi), ", fo= ", fo, file=sys.stderr)
      chrts = 0
      ch_arr = []
      ch_opts  = []
      ch_cols_used = {}
      sheet_nm = "sheet1"
      ch_type  = "line"
      for i in range(len(data)):
          for j in range(len(data[i])):
              if j == 0 and data[i][j] == "sheet" and len(data[i]) >= 2:
                 sheet_nm = data[i][1]
              if j == 0 and data[i][j] == "title":
                 #print("got title for x= %s\n" % (x))
                 chrts = chrts + 1
                 ch = []
                 co = {}
                 ch.append(["title", i, j])
                 # if sheet name field == "null" then use the default sheet name instead or the one set by the the 'sheet' cmd above
                 if len(data[i]) >= 4 and data[i][3] != "null":
                    sheet_nm = data[i][3]
                 if len(data[i]) >= 6:
                    ch_type = data[i][5]
                    ch[0].append(ch_type)
                 if len(data[i]) >= 8 and data[i][6] == "options":
                    for k in range(7, len(data[i]), 2):
                      opk = data[i][k]
                      opv = data[i][k+1]
                      if opk == "style":
                         opv = int(opv)
                      co[opk] = opv
                      print("ch ch_typ= %s, title= %s, ch_opt[%s:" % (ch_type, data[i][1], opk), opv, file=sys.stderr)
                      if opk == "chart_show_blanks_as":
                        if opv != "gap" and opv != "zero" and opv != "span":
                          print("error: invalid chart_show_blanks_as setting %s", opv, ", valid values=", ["gap" "zero", "span"], file=sys.stderr)
                          sys.exit(1)
                      if verbose > 0 and opk == "set_x_axis_name":
                          print("ch ch_typ= %s, title= %s, ch_opt[%s:" % (ch_type, data[i][1], opk), opv, file=sys.stderr)
                      if verbose > 0 and opk == "set_y_axis_name":
                          print("ch ch_typ= %s, title= %s, ch_opt[%s:" % (ch_type, data[i][1], opk), opv, file=sys.stderr)
                      if verbose > 0 and opk == "set_x_axis_date_axis":
                          print("ch ch_typ= %s, title= %s, ch_opt[%s:" % (ch_type, data[i][1], opk), opv, file=sys.stderr)
              if j == 0 and data[i][j] == "hdrs":
                 #print("got hdrs for x= %s\n" % (x))
                 ch.append(["hdrs", i])
                 ch_arr.append(ch)
                 ch_opts.append(co)
              #print(data[i][j])
          #print("")
      
      if got_sum_all > 0 and got_drop_summary and len(sheet_nm) >= 7 and sheet_nm[0:7] == "summary":
         #print("skip2 sum_file x= %s" % (x), file=sys.stderr)
         continue
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
      suffix = ""
      #if sheet_nm == "sum_all":
      #   print("use sum_file x= %s" % (x), file=sys.stderr)
      #   worksheet = worksheet_sum_all
      #   wrksh_nm  = worksheet_sum_all_nm
      #   wksheet_nms[wrksh_nm] = 1
      #   bold = workbook.add_format({'bold': 1})
      if do_avg == False or do_avg_write == True:
         if sheet_nm == "sum_all":
            if verbose > 0:
               print("use sum_file x= %s" % (x), file=sys.stderr)
            worksheet = worksheet_sum_all
            wrksh_nm  = worksheet_sum_all_nm
         #else:
         if sheet_nm != "sum_all":
            # make sure worksheet name is unique (allow 100 versions of base name)
            if wrksh_nm in wksheet_nms:
             for i in range(5000):
               suffix = "_" + str(i)
               tnm = wrksh_nm + suffix
               #print("ck if worksheet name %s exists" % (tnm), file=sys.stderr)
               if not tnm in wksheet_nms:
                  if verbose:
                     print("use worksheet name %s" % (tnm), file=sys.stderr)
                  wrksh_nm = tnm
                  break
             if verbose:
                print("use worksheet name %s" % (wrksh_nm), file=sys.stdout)
            worksheet = workbook.add_worksheet(wrksh_nm)
            ck_set_col_width(worksheet, wrksh_nm)
         wksheet_nms[wrksh_nm] = 1
         bold = workbook.add_format({'bold': 1})
   
      def find_drow_end(data, ch_arr, c, drow_beg, drow_end):
          drw  = ch_arr[c][1][1]
          mcol_num_cols = len(data[drw])
          dcol_cat = -1
          skipped = 0
          if mcol_num_cols > 5 and int(data[drw][5]) > -1:
             dcol_cat = int(data[drw][5])
          if drow_end == -1:
             jjj = dcol_cat-1
             for i in range(drow_beg, len(data)):
                 if i > drow_beg and len(data[i]) == 0:
                    break
                 if i > drow_beg:
                    drow_end = i
                 else:
                    drow_end = i+1
                 if 1==1 and dcol_cat != -1 and len(data[i]) > jjj and i >= drow_beg:
                    if not (data[i][jjj] is None or data[i][jjj] == ''):
                       skip_it = False
                       if (is_number(data[i][jjj])):
                          tval = float(data[i][jjj])
                       else:
                          continue
                       if ts_beg != -1.0 and tval < ts_beg:
                          skip_it = True
                       if ts_end != -1.0 and tval > ts_end:
                          skip_it = True
                       if skip_it:
                          skipped += 1
                          #for ij in range(len(data[i])):
                          #    worksheet.write_blank(i, ph_add+ij, None, bold0)
                          continue
          data[drw][3] = str(drow_end)
          return drow_end, dcol_cat

      print("got do_avg= ", do_avg)
      dcol_cat = -1
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
          mcol_num_cols = len(data[drw])
          dcol_cat = -1
          skipped = 0
          if mcol_num_cols > 5 and int(data[drw][5]) > -1:
             dcol_cat = int(data[drw][5])
          if drow_end == -1:
             drow_end, dcol_cat = find_drow_end(data, ch_arr, c, drow_beg, drow_end)
             if verbose:
                print("found end data row= %d" % (drow_end))
          title = data[title_rw][title_cl+1]
          #if title == "pid_stat %CPU by proc" and hrow_beg > 0 and hrow_end < len(data):
          #   print("hdr row: ", data[hrow_beg])
          #   print(1.0/0.0)
          dcol_end = int(data[drw][4])+1
          for i in range(dcol_beg, dcol_end):
             ch_cols_used[i] = 1
          if mcol_num_cols > 6:
             for h in range(6, mcol_num_cols, 2):
                 #print("tsv_2_xlsx.py: mcol_num_cols= %d sheet_nm= %s got h= %d colb= %d cole= %d title= %s" % (mcol_num_cols, sheet_nm, h, int(data[drw][h]), int(data[drw][h+1]), title))
                 tcol0 = int(data[drw][h])
                 tcol1 = int(data[drw][h+1])
                 if tcol0 > -1 and tcol1 > -1:
                    for i in range(tcol0, tcol1+1):
                        ch_cols_used[i] = 1
          mx = drow_end+1
          if mx > len(data):
             print("dude, mx= ", mx, ", len(data)= ", len(data))
        
          if not hrow_beg in fn_bs_hdr_rows[fn_bs_i]:
             fn_bs_hdr_max[fn_bs_i][hrow_beg] = -1
             fn_bs_hdr_map[fn_bs_i][hrow_beg] = {}
             fn_bs_hdr_list[fn_bs_i][hrow_beg] = {}
             fn_bs_hdr_list[fn_bs_i][hrow_beg] = {}
             fn_bs_hdr_lkup[fn_bs_i][hrow_beg] = {}
             fn_bs_hdr_rows[fn_bs_i][hrow_beg] = 0
          for i in range(len(data[hrow_beg])):
              hstr = data[hrow_beg][i]
              if not hstr in fn_bs_hdr_list[fn_bs_i][hrow_beg]:
                 fn_bs_hdr_max[fn_bs_i][hrow_beg] += 1
                 if verbose > 0:
                    print("sheet %s added header[%d][%d][%d]= %s, file= %s" % (sheet_nm, fn_bs_i, hrow_beg, fn_bs_hdr_max[fn_bs_i][hrow_beg], hstr, x))
                 fn_bs_hdr_list[fn_bs_i][hrow_beg][hstr] = fn_bs_hdr_max[fn_bs_i][hrow_beg]
                 fn_bs_hdr_lkup[fn_bs_i][hrow_beg][fn_bs_hdr_max[fn_bs_i][hrow_beg]] = hstr
              hdr_idx = fn_bs_hdr_list[fn_bs_i][hrow_beg][hstr]
              fn_bs_hdr_map[fn_bs_i][hrow_beg][i] = hdr_idx
          if not fn_bs_i in fn_bs_hdr_map:
              print("dude, fn_bs_i: ", fn_bs_i, " not in fn_bs_hdr_map, error. bye", file=sys.stderr)
              sys.exit(1)
          if not hrow_beg in fn_bs_hdr_map[fn_bs_i]:
              print("dude, hrow_beg: ", hrow_beg, " not in fn_bs_hdr_map[",fn_bs_i,"] error. bye", file=sys.stderr)
              sys.exit(1)
          for i in range(drow_end-drow_beg+1):
              ij = i+drow_beg
              if wrksh_nm is not None and len(wrksh_nm) >= 7 and wrksh_nm[0:7] == "summary" and ij < len(data) and len(data[ij]) >= 4:
                  #print("---- got1 summary wrk_sh= %s suffix= %s len= %d col3= %s" % (wrksh_nm, suffix, len(data[ij]), data[ij][3]), file=sys.stderr)
                  if data[ij][3] == "data_sheet" and suffix != "" and len(data[ij][2]) > len(suffix) and data[ij][2][-len(suffix)] != suffix:
                     # so we haven't already added the suffix to the sheet name
                     data[ij][2] += suffix
              for h in range(hcol_end):
                  ck_max = False
                  if max_val > 0.0 and h in ch_cols_used:
                     ck_max = True
                  if not ij in fn_bs_sum[fn_bs_i]:
                     fn_bs_sum[fn_bs_i][ij] = {}
                     fn_bs_n[fn_bs_i][ij] = {}
                  if (ij < len(data) and len(data[ij]) > h):
                      if h >= len(data[ij]):
                         print("dude, idx= ", ij, ", h= ", h, ", len(data[idx])= ", len(data[ij]), " drow: ", data[ij])
                      is_num = is_number(data[ij][h])
                      if not h in fn_bs_hdr_map[fn_bs_i][hrow_beg]:
                         if ch_type != "copy":
                            print("dude, h: ", h, " not in fn_bs_hdr_map[",fn_bs_i,"][",hrow_beg,"], data[",ij,"][",h,"]=",data[ij][h]," fn_bs_hdr_map= ",fn_bs_hdr_map[fn_bs_i][hrow_beg]," error. skip, file= ", x, file=sys.stderr)
                         continue
                         #sys.exit(1)
                      use_idx = fn_bs_hdr_map[fn_bs_i][hrow_beg][h]
                      if is_num:
                         data[ij][h] = float(data[ij][h])
                         if ck_max:
                            if data[ij][h] > max_val:
                               data[ij][h] = 0.0
                         if not use_idx in fn_bs_sum[fn_bs_i][ij]:
                            #fn_bs_sum[fn_bs_i][ij] = {}
                            fn_bs_sum[fn_bs_i][ij][use_idx] = 0.0
                            fn_bs_n[fn_bs_i][ij][use_idx] = 0
                         if options_get_max_val:
                            if fn_bs_n[fn_bs_i][ij][use_idx] == 0 or fn_bs_sum[fn_bs_i][ij][use_idx] < data[ij][h]:
                               fn_bs_sum[fn_bs_i][ij][use_idx] = data[ij][h]
                               fn_bs_n[fn_bs_i][ij][use_idx] = 1
                         else:
                            if not do_avg:
                               data[ij][h] = float(data[ij][h])
                               fn_bs_sum[fn_bs_i][ij][use_idx] = data[ij][h]
                               fn_bs_n[fn_bs_i][ij][use_idx] = 1
                            else:
                             try:
                               if fn_bs_sum[fn_bs_i][ij][use_idx] == '':
                                  fn_bs_sum[fn_bs_i][ij][use_idx] = 0.0
                                  fn_bs_n[fn_bs_i][ij][use_idx] = 0
                               if data[ij][h] != '':
                                  data[ij][h] = float(data[ij][h])
                                  fn_bs_sum[fn_bs_i][ij][use_idx] += data[ij][h]
                                  fn_bs_n[fn_bs_i][ij][use_idx] += 1
                               elif not use_idx in fn_bs_sum[fn_bs_i][ij]:
                                  fn_bs_sum[fn_bs_i][ij][use_idx] = 0.0
                                  fn_bs_n[fn_bs_i][ij][use_idx] = 0
                               #else if fn_bs_sum[fn_bs_i][ij][use_idx] != "" and data[ij][h] == "":
                               #   don't do anything for this case
                               #   fn_bs_sum[fn_bs_i][ij][use_idx] += data[ij][h]
                               #   fn_bs_n[fn_bs_i][ij][use_idx] += 1
                             except Exception as e:
                               print(e, file=sys.stderr)
                               print("---- error on += of fn_bs_sum  data[%d][%d] filenm= %s, field= " % (ij, h, x), data[ij][h], "type of new val= ", type(data[ij][h]), "is spc= ",data[ij][j]=='', ", base_val= ", fn_bs_sum[fn_bs_i][ij][use_idx], ", line= ", data[ij], file=sys.stderr)
                               print("---- type of old val: ", type(fn_bs_sum[fn_bs_i][ij][use_idx]), " val of old val: '", fn_bs_sum[fn_bs_i][ij][use_idx], "', is spc= ",fn_bs_sum[fn_bs_i][ij][use_idx]=='',file=sys.stderr)
                               sys.exit(1)
                      else:
                         fn_bs_sum[fn_bs_i][ij][use_idx] = data[ij][h]
                         fn_bs_n[fn_bs_i][ij][use_idx] = -1
      
      ph_add = 0
      ph_done = 0
      do_ph_add = 0
      if len(opt_phase) > 0:
         do_ph_add = 1

      if do_avg == False or do_avg_write == True:
         #print("---- do_avg= %s, do_avg_write= %s, fn_bs_sum[%d] rows= %d" % (do_avg, do_avg_write, fn_bs_i, len(fn_bs_sum[fn_bs_i])), file=sys.stderr)
         write_rows = 0
         write_rows3 = 0
         if do_avg_write == True:
            #print("fn_bs_sum[%d] rows= %d" % (fn_bs_i, len(fn_bs_sum[fn_bs_i])), file=sys.stderr)
            ndata = [row[:] for row in data]
            skipped = 0
            for i in fn_bs_sum[fn_bs_i]:
                #if i == hrow_beg:
                #   print("tsv_2_xlsx.ph: at 1 sheet_nm= ", sheet_nm, ", hdr_len= ", len(fn_bs_hdr_lkup[fn_bs_i]), ", write header row= ", fn_bs_hdr_lkup[fn_bs_i])
                #print("row[%d].len= %d" % (i, len(fn_bs_sum[fn_bs_i][i])), file=sys.stderr)
                write_rows3 += 1
                for j in fn_bs_sum[fn_bs_i][i]:
                   #print("row[%d][%d]= %s" % (i, j, fn_bs_sum[fn_bs_i][i][j]), file=sys.stderr)
                   val = fn_bs_sum[fn_bs_i][i][j]
                   num = fn_bs_n[fn_bs_i][i][j]
                   if num > 0:
                      val /= num;
                   if worksheet is not None:
                      worksheet.write(i, j, val)
                   if i >= len(ndata):
                      is_num = is_number(val)
                      if is_num:
                         print("bad idx: i= %d, len(ndata)= %d, j= %d, flt_val= %f, num= %d" % (i, len(ndata), j, val, num), file=sys.stderr)
                      else:
                         print("bad idx: i= %d, len(ndata)= %d, j= %d, str_val= %s, num= %d" % (i, len(ndata), j, val, num), file=sys.stderr)
                      ii = i
                      if i >= len(ndata):
                         for ii in (len(ndata), i+1):
                            ndata.append([])
                   if j >= len(ndata[i]):
                      #for ii in (len(ndata[i]), j+1):
                      ii = j - len(ndata[i]) + 1
                      #print("tsv_2_xlsx.py: going to add %d cols to ndata[%d], len(ndata[%d])= %d, j= %d" % (ii, i, i, len(ndata[i]), j))
                      while ii >= 0:
                         ii -= 1
                         ndata[i].append(0.0)
                         if len(ndata[i]) > 1000:
                            sys.exit(1)
                   if verbose > 0 and i >= len(ndata):
                      print("tsv_2_xlsx.py: bad row idx i: i= %d, len(ndata)= %d, j= %d, str_val= %s, num= %d" % (i, len(ndata), j, val, num), file=sys.stderr)
                   if verbose > 0 and j >= len(ndata[i]):
                      print("tsv_2_xlsx.py: bad col idx j: i= %d, len(ndata)= %d, j= %d, len(ndata[%d])= %d, str_val= %s, num= %d" % (i, len(ndata), j, i, len(ndata[i]), val, num), file=sys.stderr)
                   ndata[i][j] = val
            for i in range(len(data)):
                if not i in fn_bs_sum[fn_bs_i]:
                   if i in fn_bs_hdr_rows[fn_bs_i]:
                      if len(fn_bs_hdr_lkup[fn_bs_i][i]) == 0:
                          continue
                      for k in range(i, i+2):  # allow for a little shifting of rows
                          if k < len(data) and  fn_bs_hdr_lkup[fn_bs_i][i][0] == data[k][0]: # look for match on 1st col of header row
                             if verbose > 0:
                                print("tsv_2_xlsx.py: at 2 sheet_nm= ", sheet_nm, ",i=",i,",k=",k,", outfile= ", output_filename, ", hdr_len= ", len(fn_bs_hdr_lkup[fn_bs_i][i]), ", write header row= ", fn_bs_hdr_lkup[fn_bs_i][i])
                             for j in range(fn_bs_hdr_max[fn_bs_i][i]+1):
                                 if verbose > 0 and sheet_nm == "pidstat":
                                    print("tsv_2_xlsx.py: at 2.1 sheet_nm= %s, hdr[%d, %d]= %s" % (sheet_nm, i, j, fn_bs_hdr_lkup[fn_bs_i][i][j]))
                                 if worksheet is not None:
                                    worksheet.write(i, j, fn_bs_hdr_lkup[fn_bs_i][i][j])
                             break
                   else:
                      if worksheet is not None:
                         worksheet.write_row(i, ph_add, data[i])
                   write_rows += 1
            if verbose > 0:
               print("----  write_rows2= %d, write_rows3= %d" % (write_rows, write_rows3), file=sys.stderr)
            #with open('new_tsv.tsv', 'w', newline='') as csvfile:
            pfx = ""
            if fo in prefix_dict:
               pfx = prefix_dict[fo]
            pfx_xtra = ""
            if not do_avg:
               pfx_xtra = pfx
            base = os.path.basename(x) + pfx_xtra
            nw_nm = base
            if avg_dir != None:
               nw_nm = avg_dir + "/" + nw_nm
               if verbose > 0:
                  print("---- got do_avg_write nw_nm= %s, rows= %d" % (nw_nm, len(data)), file=sys.stderr)
               with open(nw_nm, 'w') as csvfile:
                  spamwriter = csv.writer(csvfile, dialect="excel-tab")
                  for i in range(len(ndata)):
                      spamwriter.writerow(ndata[i])
         else:
            doing_sum_all = False
            if wrksh_nm != None and len(wrksh_nm) >= 7 and wrksh_nm[0:7] == "sum_all":
               doing_sum_all = True
            skipped = 0
            ts_first = -1.0
            ts_last  = -1.0
            jjj = dcol_cat-1
            for i in range(len(data)):
              if doing_sum_all and len(data[i]) >= 3 and data[i][2] == "goto_sheet":
                #print("---- got1 summary wrk_sh= %s suffix= %s len= %d col3= %s" % (wrksh_nm, suffix, len(data[ij]), data[ij][3]), file=sys.stderr)
                if worksheet is not None:
                   for j in range(len(data[i])):
                      if j <= 2:
                        worksheet.write(i, j, data[i][j])
                      else:
                        worksheet.write_url(i, j,  "internal:"+data[i][j]+"!A1")
                write_rows3 += 1
              else:
                   if 1==1 and dcol_cat != -1 and len(data[i]) > jjj and jjj != -1 and i >= drow_beg and i <= (drow_end):
                       try:
                         if data[i][jjj] is None or data[i][jjj] == '':
                           continue
                       except Exception as e:
                           print(e, ", i= ", i, ", jjj= ",jjj,  file=sys.stderr)
                           sys.exit(1)
                       if data[i][jjj] is None or data[i][jjj] == '':
                          continue
                       tval = data[i][jjj]
                       if ts_first == -1.0:
                          ts_first = tval
                       ts_last  = tval
                       skip_it = False
                       if ts_beg != -1.0 and tval < ts_beg:
                          skip_it = True
                       if ts_end != -1.0 and tval > ts_end:
                          skip_it = True
                       if skip_it:
                          skipped += 1
                          if worksheet is not None:
                            for ij in range(len(data[i])):
                              worksheet.write_blank(i, ph_add+ij, None, bold0)
                          continue
                   #if worksheet is not None and not math.isnan(data[i]):
                   if worksheet is not None:
                      try:
                         worksheet.write_row(i, ph_add, data[i])
                      except:
                         print("---- error write row[%d], filenm= %s, row= " % (i, x), data[i], file=sys.stderr)
                   write_rows += 1
         #print("---- skipped2a= %d, write_rows= %d, write_rows3= %d, ts_beg= %f, ts_end= %f ts_first= %f ts_last= %f" % (skipped, write_rows, write_rows3, ts_beg, ts_end, ts_first, ts_last), file=sys.stderr)
      
      printed_no_data_for_chart_msg = False
      sku_or_desc_text = None
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
          if options_all_charts_one_row == True:
             ch_orient_vert = False
          if drow_end == -1:
             drow_end, dcol_cat = find_drow_end(data, ch_arr, c, drow_beg, drow_end)
             print("ck data for chart! sheet_nm= %s, title= %s ch_typ= %s, file= %s, drow_beg= %d, drow_end= %d, hcol_beg= %d, hcol_end= %d ts_beg= %f ts_end= %f len(data)= %d" % (sheet_nm, title, ch_type, x, drow_beg, drow_end, hcol_beg, hcol_end, ts_beg, ts_end, len(data)), file=sys.stderr)
          if drow_end == -1 or ((ch_type == "column" or ch_type == "column_stacked") and drow_beg > drow_end) or ((ch_type != "column" and ch_type != "column_stacked") and drow_beg >= drow_end):
             if printed_no_data_for_chart_msg == False:
                print("no data for chart! sheet_nm= %s, title= %s ch_typ= %s, file= %s, drow_beg= %d, drow_end= %d, hcol_beg= %d, hcol_end= %d ts_beg= %f ts_end= %f" % (sheet_nm, title, ch_type, x, drow_beg, drow_end, hcol_beg, hcol_end, ts_beg, ts_end), file=sys.stderr)
                printed_no_data_for_chart_msg = True
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
             #print("tsv_2_xlsx.py: sheet_nm= %s title= %s ck columns[%d]" % (sheet_nm, title, len(mcol_list)))
             for h in range(6, mcol_num_cols, 2):
                 #print("tsv_2_xlsx.py: sheet_nm= %s title= %s add columns[%d] colb= %d cole= %d" % (sheet_nm, title, len(mcol_list), int(data[drw][h]), int(data[drw][h+1])))
                 tcol0 = int(data[drw][h])
                 tcol1 = int(data[drw][h+1])
                 if tcol0 > -1 and tcol1 > -1:
                    mcol_list.append([tcol0, tcol1+1])
                    #print("tsv_2_xlsx.py: added sheet_nm= %s title= %s got series[%d] colb= %d cole= %d" % (sheet_nm, title, len(mcol_list)-1, tcol0, tcol1+1))
          else:
             if hcol_beg < 0 or hcol_end < 0:
                print("What going on, sheet_nm= %s, ch_typ= %s, file= %s, hcol_beg= %d, hcol_end= %d" % (sheet_nm, ch_type, x, hcol_beg, hcol_end), file=sys.stderr)
             mcol_list.append([hcol_beg, hcol_end])
             #print("add_mcol_list[%d] sheet_nm= %s, ch_typ= %s, title= %s, hcol_beg= %d, hcol_end= %d" % (len(mcol_list)-1, sheet_nm, ch_type, title, hcol_beg, hcol_end), file=sys.stderr)
          if verbose:
             print("sheet= %s ch= %d hro= %d hc= %d hce= %d, dr= %d, dre= %d" % (sheet_nm, c, hrow_beg, hcol_beg, hcol_end, drow_beg, drow_end))
          ch_style = 10
          chart1 = None
          #got_how_many_series_for_chart = 0
          #if ch_type == "scatter_straight" and options_str_top.find("line_for_scatter") > -1:
          #   ch_type = "line"
          ch_markers = 0
          if ch_type == "scatter_straight_markers":
             ch_type =  "scatter_straight"
             ch_markers = 1
          if ch_type == "line_markers":
             ch_type =  "line"
             ch_markers = 1
          #print("ch_type= ", ch_type)
          if ch_type == "scatter_straight" or ch_type == "line":
             if ph_done == 0 and do_ph_add == 1 and dcol_cat > 0:
                #ph_done = 1
                skipped = 0
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
                    worksheet.write_blank(ii, 0, None, bold0)
                    if (ts_beg != -1.0 and tval < ts_beg) or (ts_end != -1.0 and tval > ts_end):
                       skipped += 1
                       continue
                    in_phase = False
                    phase_arr = []
                    #print("opt_phase ii= %d tval= %d lenopt_phase= %d" % (ii, tval, len(opt_phase)), file=sys.stderr)
                    cur_phase = ""
                    for jj in range(len(opt_phase)):
                       if tval < opt_phase[jj][1]:
                          #print("ex1 opt_phase ii= %d ph[%d]= %f tval= %f end= %f tv-beg= %f end-tv= %f" % (
                          #  ii, jj, opt_phase[jj][1], tval, opt_phase[jj][2], tval-opt_phase[jj][1], opt_phase[jj][2]-tval), file=sys.stderr)
                          continue
                       #print("ck  opt_phase ii= %d ph[%d]= %f tval= %f end= %f tv-beg= %f end-tv= %f" % (
                       #     ii, jj, opt_phase[jj][1], tval, opt_phase[jj][2], tval-opt_phase[jj][1], opt_phase[jj][2]-tval), file=sys.stderr)
                       #if opt_phase[jj][2] != -1 and tval < opt_phase[jj][2]:
                       #   print("ex2 opt_phase ii= %d ph[%d]= %f tval= %f end= %f tv-beg= %f end-tv= %f" % (
                       #     ii, jj, opt_phase[jj][1], tval, opt_phase[jj][2], tval-opt_phase[jj][1], opt_phase[jj][2]-tval), file=sys.stderr)
                       #   break
                       if tval >= opt_phase[jj][1] and (tval <= opt_phase[jj][2] or opt_phase[jj][2] == -1):
                          cur_phase = opt_phase[jj][0]
                          #print("got opt_phase ii= %d tval= %d clip= \"%s\" cur_phase[%d]= %s" % (ii, tval, clip, jj, cur_phase), file=sys.stderr)
                          if do_avg == False or do_avg_write == True:
                             in_phase = True
                             already_in_phase_arr = False
                             for ck_ph in range(len(phase_arr)):
                                 if phase_arr[ck_ph] == opt_phase[jj][0]:
                                     already_in_phase_arr = True
                                     break
                             if already_in_phase_arr == False:
                                phase_arr.append(opt_phase[jj][0])
                    if in_phase and len(phase_arr) > 0:
                       worksheet.write(ii, 0, " ".join(phase_arr))
                    #if (in_phase == False and clip != ""):
                    if (in_phase == False and clip != "") or (in_phase == True and clip != "" and clip != cur_phase):
                       #print("try to zero out row ", ii, " len= ", len(data[ii]))
                       for ij in range(len(data[ii])):
                           worksheet.write_blank(ii, ph_add+ij, None, bold0)
                print("opt_phase skipped= %d" % (skipped), file=sys.stderr)

             if do_avg == False or do_avg_write == True:
                #drow_beg, drow_end,if got_how_many_series_for_chart > 0:
                if drow_end  > (drow_beg+1):
                   if ch_type == "line" or (ch_type == "scatter_straight" and options_str_top.find("line_for_scatter") > -1):
                      chart1 = workbook.add_chart({'type': "line"})
                   else:
                      chart1 = workbook.add_chart({'type': 'scatter', 'subtype': 'straight'})
          else:
             if ch_type != "copy":
                if do_avg == False or do_avg_write == True:
                   #if got_how_many_series_for_chart > 0:
                   if drow_end  >= (drow_beg):
                      if ch_type == "line_stacked":
                        #print("chart_type2= %s, use_cats= %s" % (ch_type, use_cats), file=sys.stderr)
                        chart1 = workbook.add_chart({'type': "area", 'subtype': 'stacked'})
                        #chart1 = workbook.add_chart({'type': "line", 'subtype': 'stacked'})
                      else:
                        if ch_type == "column_stacked":
                          chart1 = workbook.add_chart({'type': 'column', 'subtype': 'stacked'})
                          #chart1.set_style(12)
                        else:
                          chart1 = workbook.add_chart({'type': ch_type})
          if ch_type == "copy":
             #print("chart_type= copy", file=sys.stderr)
             continue
          # Configure the first series.
          got_how_many_series_for_chart = 0
          num_series = 0
          for hh in range(len(mcol_list)):
              #print("tsv_2_xlsx.py: ckckck at2, sheet_nm= %s, ch_typ= %s, title= %s, hh= %d" % (sheet_nm, ch_type, title, hh))
              for h in range(mcol_list[hh][0], mcol_list[hh][1]):
                  #print("tsv_2_xlsx.py: ckckck at3, sheet_nm= %s, ch_typ= %s, title= %s, h= %d, mcol0= %d mcol1= %d" % (sheet_nm, ch_type, title, h, mcol_list[hh][0], mcol_list[hh][1]))
                  if h < 0:
                     print("What going on2, sheet_nm= %s, ch_typ= %s, file= %s, hcol_beg= %d, hcol_end= %d" % (sheet_nm, ch_type, x, hcol_beg, hcol_end), file=sys.stderr)
                  if drow_beg < 0 or drow_end < 0:
                     print("What going on3, sheet_nm= %s, ch_typ= %s, file= %s, drow_beg= %d drow_end= %d hcol_beg= %d, hcol_end= %d" % (sheet_nm, ch_type, x, drow_beg, drow_end, hcol_beg, hcol_end), file=sys.stderr)
                     continue
                  got_how_many_series_for_chart += 1
                  #print("tsv_2_xlsx.py: ckckck at4, sheet_nm= %s, ch_typ= %s, title= %s, h= %d, mcol0= %d mcol1= %d" % (sheet_nm, ch_type, title, h, mcol_list[hh][0], mcol_list[hh][1]))
                  if do_avg == False or do_avg_write == True:
                   use_drow_end = drow_end
                   if ch_type == "column" or ch_type == "column_stacked":
                     #if verbose > 0:
                     #   print("ck col chart, sheet_nm= %s, ch_typ= %s, file= %s, drow_beg= %d drow_end= %d hcol_beg= %d, hcol_end= %d, ph_add= %d, h= %d" % (sheet_nm, ch_type, x, drow_beg, drow_end, hcol_beg, hcol_end, ph_add, h), chart1, file=sys.stderr)
                     use_drow_end = drow_end
                   if chart1 != None and ((ch_type == "column" or ch_type == "column_stacked") or drow_end  > (drow_beg+1)):
                    rc = 0;
                    #print("got bef add_series ch_type= ", ch_type, ", title= ", title, ", drow_beg= ", drow_beg, ", drow_end= ", drow_end," h= ",h,",ph_add=",ph_add, file=sys.stderr);
                    use_color = num_series % len(gcolor_lst)
                    num_series = num_series + 1
                    a_s = {
                         'name':       [wrksh_nm, hrow_beg, h+ph_add],
                         'values':     [wrksh_nm, drow_beg, h+ph_add, use_drow_end, h+ph_add],
                    }
                    if use_cats:
                       if 'set_x_axis_date_axis' in ch_opts[c]:
                           a_s['categories'] = [wrksh_nm, drow_beg, dcol_cat+ph_add, use_drow_end, dcol_cat+ph_add]
                           print("did set_x_axis categories, sheet_nm= %s, ch_typ= %s, file= %s, drow_beg= %d drow_end= %d dcol_cat= %d, dcol_cat= %d" % (sheet_nm, ch_type, x, drow_beg, drow_end, dcol_cat, dcol_cat), file=sys.stderr)
                           print("did set_x_axis categories, min= ", data[drow_beg][dcol_cat], ", max= ", data[drow_end][dcol_cat], file=sys.stderr)
                       else:
                           a_s['categories'] = [wrksh_nm, drow_beg, dcol_cat+ph_add, use_drow_end, dcol_cat+ph_add]
                    if (mcol_list[hh][1]-mcol_list[hh][0]) > 1 or num_series > 1:
                       a_s['points'] = [{'fill': {'color': gcolor_lst[use_color]}}]
                       if ch_type == "column_stacked":
                         if drow_end-drow_beg > 1:
                            for clr_i in range(drow_end-drow_beg):
                              #print("use column_stacked[%d] chart gcolor_list[%d], sheet_nm= %s, ch_typ= %s, file= %s, drow_beg= %d drow_end= %d hcol_beg= %d, hcol_end= %d, ph_add= %d, h= %d" % (clr_i, use_color, sheet_nm, ch_type, x, drow_beg, drow_end, hcol_beg, hcol_end, ph_add, h), chart1, file=sys.stderr)
                              a_s['points'].append({'fill': {'color': gcolor_lst[use_color]}})
                         #print("use chart gcolor_list[%d], sheet_nm= %s, ch_typ= %s, file= %s, drow_beg= %d drow_end= %d hcol_beg= %d, hcol_end= %d, ph_add= %d, h= %d" % (use_color, sheet_nm, ch_type, x, drow_beg, drow_end, hcol_beg, hcol_end, ph_add, h), chart1, file=sys.stderr)
                    a_s['line'] = {'color': gcolor_lst[use_color]}
                    if ch_markers == 1:
                       use_marker = num_series % len(gmarker_type_lst)
                       #a_s['marker'] = {'type': 'automatic', 'fill':   {'color': gcolor_lst[use_color]},}
                       a_s['marker'] = {'type': gmarker_type_lst[use_marker], 'size': 7, 'border': {'color': gcolor_lst[use_color]},  'fill':   {'color': gcolor_lst[use_color]},}
                       #print("ch_type= ", ch_type, ", add markers")
                    #print("got add_series1, a_s= ", a_s);
                    rc = chart1.add_series(a_s)
          if got_how_many_series_for_chart == 0:
             print("What going on4, sheet_nm= %s, ch_typ= %s, file= %s, drow_beg= %d drow_end= %d hcol_beg= %d, hcol_end= %d" % (sheet_nm, ch_type, x, drow_beg, drow_end, hcol_beg, hcol_end), file=sys.stderr)
          if chart1 != None and (do_avg == False or do_avg_write == True):
             chart1.set_title ({'name': title})
             if 'style' in ch_opts[c]:
                chart1.set_style(ch_opts[c]['style'])
                print("got per chart ch_opts style= ", ch_opts[c]['style'], file=sys.stderr)
             else:
                chart1.set_style(ch_style)
             if chart_show_blanks_set == True:
                print("chart1.show_blanks_as(%s)" % (chart_show_blanks_as), file=sys.stderr)
                chart1.show_blanks_as(chart_show_blanks_as)
             if 'chart_show_blanks_as' in ch_opts[c]:
                chart1.show_blanks_as(ch_opts[c]['chart_show_blanks_as'])
             if 'set_x_axis_date_axis' in ch_opts[c]:
                chart1.set_x_axis({'date_axis': True, 'min' : 0, 'max': date(math.ceil(6195.0/365.0))})
                print("did set_x_axis date_axis, sheet_nm= %s, ch_typ= %s, file= %s, drow_beg= %d drow_end= %d hcol_beg= %d, hcol_end= %d" % (sheet_nm, ch_type, x, drow_beg, drow_end, hcol_beg, hcol_end), file=sys.stderr)
             if 'set_x_axis_name' in ch_opts[c]:
                chart1.set_x_axis({'name': ch_opts[c]['set_x_axis_name']})
             if 'set_y_axis_name' in ch_opts[c]:
                chart1.set_y_axis({'name': ch_opts[c]['set_y_axis_name']})
             
             use_xbase = 25
             if ch_size[0] == 1:
               use_xbase = 10
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
                      ch_left_at_col = ch_array[ch_ln_prev][3] + 0
                      if verbose > 0:
                            print("ch_left_at_col1= ", ch_left_at_col, ", title= ", title, file=sys.stderr)
                #print("+_++__insert chart for sheet= %s, chart= %s, at_row= %d at_col= %d" % (sheet_nm, title, ch_top_at_row, ch_left_at_col), file=sys.stderr)
             else:
                ch_top_at_row = 1
                ch_left_at_col = 0
                if len(ch_array) > 0:
                   ch_ln_prev = len(ch_array)-1
                   if ch_array[ch_ln_prev][0] == sheet_nm:
                      ch_top_at_row = ch_array[ch_ln_prev][1] + 0
                      ch_left_at_col = ch_array[ch_ln_prev][2] + int(ch_size[2])
                      if verbose > 0:
                            print("ch_left_at_col2= ", ch_left_at_col, ", title= ", title, file=sys.stderr)
                #print("sh %s ch %s row= %d col= %d" % (sheet_nm, title, ch_top_at_row, ch_left_at_col))
                #print("++++__insert chart for sheet= %s, chart= %s, at_row= %d at_col= %d" % (sheet_nm, title, ch_top_at_row, ch_left_at_col), file=sys.stderr)
                if worksheet_charts != None:
                   desc_str = None
                   if options_all_charts_one_row == True:
                      #print("___got desc= ",desc, ", desc_str", desc_str, ", fo2.3= ",  all_charts_one_row[fo2][3], ", fo2=", fo2)
                      if desc == None:
                        if options_sku != None:
                           desc_str = options_sku
                        else:
                           desc_str = str(fo)
                        all_charts_one_row[fo2][3] = desc_str
                      else:
                        desc_str = desc

                   if options_all_charts_one_row == True and desc_str != None:
                      if verbose > 0:
                         print("++++__calc0  chart for sheet= %s, fo2= %d desc= %s" % (sheet_nm, fo2, all_charts_one_row[fo2][3]), file=sys.stderr)
                      dsc = all_charts_one_row[fo2][3]
                      txt1 = ""
                      if options_sku != None:
                         txt1 = options_sku
                      if sku_or_desc_text != None:
                         txt1 += " " + sku_or_desc_text
                      if options_phase != "": 
                         txt1 += " " + options_phase
                      #if dsc == None:
                      #   if txt1 != "":
                      #     dsc = txt1
                      #else:
                      #   if txt1 != "":
                      #     dsc += txt1
                      #print("___got dsc1= ",dsc, ", desc= ",desc, ", desc_str", desc_str, ", txt1= ", txt1)
                      dsc_fo2 = None
                      if dsc != None:
                         dsc_fo2 = dsc + str(fo2)
                         #print("dsc= ",dsc, ", fo2= ", fo2,", dsc_fo2= ", dsc_fo2)
                      #if (dsc != None and not dsc in all_charts_one_row_hash) or (txt1 != "" and not txt1 in all_charts_one_row_hash):
                      #if (dsc != None and not dsc in all_charts_one_row_hash):
                      if (dsc_fo2 != None and not dsc_fo2 in all_charts_one_row_hash):
                         all_charts_one_row_max += 1
                         if desc != None:
                            file1 = open(desc,"r")
                            txt = file1.readline().rstrip('\n')
                            file1.close() 
                         else:
                            txt = desc_str
                         all_charts_one_row_hash[dsc_fo2] = {"index": all_charts_one_row_max, "charts":0, "txt":txt, "txt1":txt1}
                         #print("___got dsc2= ",dsc_fo2, ", desc= ",desc, ", desc_str", desc_str, ", txt1= ", txt1, ", dsc_i=", all_charts_one_row_max)
                      dsc_i = -1
                      if dsc != None:
                         dsc_i    = all_charts_one_row_hash[dsc_fo2]["index"]
                         ch_in_rw = all_charts_one_row_hash[dsc_fo2]["charts"]
                         #print("___got dsc3= ",dsc, ", desc= ",desc, ", desc_str", desc_str, ", txt1= ", txt1, ", ch_in_rw= ", ch_in_rw, ", dsc_i=", dsc_i)
                         all_charts_one_row[dsc_i][0] = 3+ dsc_i * (3+int(ch_size[1]*ch_size[2]))
                         all_charts_one_row[dsc_i][1] = ch_in_rw * int(ch_size[3])
                         if verbose > 0:
                            print("ch_left_at_cola= ", all_charts_one_row[dsc_i][1], ", title= ", title,  file=sys.stderr)
                         if ch_in_rw == 0:
                            worksheet_charts.write(all_charts_one_row[dsc_i][0]-2, 0, txt);
                            sku_or_desc_text = txt
                         ch_top_at_row  = all_charts_one_row[dsc_i][0]
                         ch_left_at_col = all_charts_one_row[dsc_i][1]
                         all_charts_one_row_hash[dsc_fo2]["charts"] += 1
                         if verbose > 0:
                            print("ch_left_at_col3= ", ch_left_at_col, ", title= ", title,  file=sys.stderr)
                         
                      if verbose > 0:
                         print("chart sheet= %s, row_beg= %d col= %d, title= %s" % (sheet_nm, ch_top_at_row, ch_left_at_col, title), file=sys.stderr)
                   else:
                     if c == 0:  # first chart of row
                        ch_sh_row += 1
                        if ch_sh_row > 0:
                           ch_top_at_row = ch_sh_arr[ch_sh_row-1][0] + int(ch_size[2]*ch_size[1])
                        ch_sh_arr.append([ch_top_at_row, ch_left_at_col])
                        if verbose > 0:
                          print("ch_left_at_col4= ", ch_left_at_col, ", title= ", title, file=sys.stderr)
                     if ch_sh_row >= len(ch_sh_arr) or not ch_sh_row in ch_sh_arr:
                       if verbose > 0:
                         print("info ch_sh_row= %d len(ch_sh_arr)= %d, x= %s\n" % (ch_sh_row, len(ch_sh_arr), x), file=sys.stderr)
                         #print("err: len(ch_sh_arr[ch_sh_row])= %d, x= %s\n" % (len(ch_sh_arr[ch_sh_row]), x), file=sys.stderr)
                     else:
                        ch_top_at_row = ch_sh_arr[ch_sh_row][0]
             rc = -1
             if worksheet_charts != None:
                worksheet_charts.write(ch_top_at_row -1, ch_left_at_col+1, title);
                if sku_or_desc_text != None or options_phase != "":
                   txt = ""
                   if options_sku != None:
                     txt = options_sku
                   if sku_or_desc_text != None:
                     txt += " " + sku_or_desc_text
                   if options_phase != "": 
                     txt += " " + options_phase
                   worksheet_charts.write(ch_top_at_row-2, ch_left_at_col+1, txt)
                #if sku_or_desc_text == None and options_sku != None:
                #   worksheet_charts.write(ch_top_at_row-2, ch_left_at_col+1, options_sku);
                #   print("ch_row= ", ch_top_at_row-2, ", ch_col= ", ch_left_at_col+1, ", sku= ", options_sku)
                if num_series == 0:
                   print("error: got num_series = 0 for chart1 title= %s file= %s" % (title, x), file=sys.stderr)
                else:
                   rc = worksheet_charts.insert_chart(ch_top_at_row, ch_left_at_col, chart1, ch_opt)
                if options_all_charts_one_row == True:
                   all_charts_one_row[fo2][2] += 1
             else:
                if num_series == 0:
                   print("error: got num_series = 0 for chart2 title= %s file= %s" % (title, x), file=sys.stderr)
                else:
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
   
print("python: got to bottom. ck close file %s\n" % (output_filename), file=sys.stderr)
if closed_wkbk == False:
    print("python: close workbook %s\n" % (output_filename), file=sys.stderr)
    workbook.close()
    closed_wkbk = True
    
print("python: exit with rc 0 for file %s\n" % (output_filename), file=sys.stderr)
sys.exit(0)

