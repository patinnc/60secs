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


import xlsxwriter
import csv
import getopt
import sys
import glob

options, remainder = getopt.getopt(sys.argv[1:], 'i:o:v', ['images=', 
                                                         'output=',
                                                         'verbose',
                                                         ])
output_filename = 'chart_line.xlsx'
verbose = False
image_files=[]

print 'OPTIONS   :', options

for opt, arg in options:
    if opt in ('-i', '--images'):
        for x in glob.glob(arg):
           image_files.append(x)
    elif opt in ('-o', '--output'):
        output_filename = arg
    elif opt in ('-v', '--verbose'):
        verbose = True

workbook = xlsxwriter.Workbook(output_filename)

def is_number(s):
    try:
        float(s)
        return True
    except ValueError:
        return False

#for x in sys.argv[1:]:
for x in remainder:
   
   data = []
   with open(x) as tsv:
       for line in csv.reader(tsv, dialect="excel-tab"):
           data.append(line)
   #print data
   
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
           if j == 0 and data[i][j] == "hdrs":
              print("got hdrs for x= %s\n" % (x))
              ch.append(["hdrs", i])
              ch_arr.append(ch)
           print data[i][j],
       print
   
   print("sheet_nm= %s\n" % (sheet_nm))
   wrksh_nm = sheet_nm
   worksheet = workbook.add_worksheet(wrksh_nm)
   bold = workbook.add_format({'bold': 1})

   for c in range(chrts):
       print("got chrt[%d] for x= %s\n" % (c, x))
       title_rw = ch_arr[c][0][1]
       title_cl = ch_arr[c][0][2]
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
              if len(data[i]) < dcol_beg:
                 break
          data[drw][3] = str(drow_end)
       dcol_end = int(data[drw][4])+1
       for i in range(drow_end-drow_beg+1):
           for h in range(hcol_end):
               if (h >= hcol_beg):
                   is_num = is_number(data[i+drow_beg][h])
                   if is_num:
                      data[i+drow_beg][h] = float(data[i+drow_beg][h])
   
   for i in range(len(data)):
       worksheet.write_row(i, 0, data[i])
   
   for c in range(chrts):
       title_rw = ch_arr[c][0][1]
       title_cl = ch_arr[c][0][2]
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
       headings = []
       for h in range(hcol_end):
           if (h >= hcol_beg):
              headings.append(data[hrow_beg][h])
       #worksheet.write_row(hrow_beg, hcol_beg, headings, bold)
       print ("sheet= %s ch= %d hro= %d hc= %d hce= %d, dr= %d, dre= %d" % (sheet_nm, c, hrow_beg, hcol_beg, hcol_end, drow_beg, drow_end))
       chart1 = workbook.add_chart({'type': ch_type})
       # Configure the first series.
       for h in range(hcol_end):
           if (h >= hcol_beg):
               #    'categories': '=Sheet1!$A$2:$A$7',
               chart1.add_series({
                   'name':       [wrksh_nm, hrow_beg, h],
                   'values':     [wrksh_nm, drow_beg, h, drow_end, h],
               })
       chart1.set_title ({'name': title})
       chart1.set_style(10)
       worksheet.insert_chart(hrow_beg, hcol_end, chart1, {'x_offset': 25, 'y_offset': 10})

if len(image_files) > 0:
   rw = len(image_files)
   cl = 0
   worksheet = workbook.add_worksheet('images')
   for x in image_files:
       worksheet.insert_image(rw, cl, x)
       rw = rw - 1
       cl = cl + 1

workbook.close()
    
sys.exit(0)

