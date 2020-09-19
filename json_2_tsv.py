from __future__ import print_function
import json
import getopt
import sys
import os


options, remainder = getopt.getopt(sys.argv[1:], 'vf:b:d:e:m:o:S:s:t:', ['verbose', 'file=', 'beg=',
                                                         'desc=',
                                                         'end=',
                                                         'match=',
                                                         'options=',
                                                         'Sheet=',
                                                         'summary=',
                                                         'type=',
                                                         ])
hdr = ""
sum_file = ""
sheet_nm = ""
options_str = ""
desc = ""
beg = 0.0
end = 0.0
match_intrvl = 0
verbose = 0
#print("%f\n" % (1.0/0.0)) # force error to test error handling

for opt, arg in options:
    if opt in ('-v', '--verbose'):
        verbose += 1
    if opt in ('-f', '--file'):
        flnm = arg
    if opt in ('-b', '--beg'):
        beg = float(arg)
    if opt in ('-d', '--desc'):
        desc = arg
        print("________json_2_tsv.py: got desc= %s" % (desc), file=sys.stderr)
    if opt in ('-e', '--end'):
        end = float(arg)
    if opt in ('-m', '--match'):
        match_intrvl = int(arg)
    if opt in ('-o', '--options'):
        options_str = arg
    if opt in ('-t', '--type'):
        hdr = arg
    if opt in ('-s', '--summary'):
        sum_file = arg
    if opt in ('-S', '--Sheet'):
        sheet_nm = arg

if verbose > 0:
   print("________json_2_tsv.py: got match_intrvl= %d" % (match_intrvl), file=sys.stderr)

#flnm=sys.argv[1]
#beg=float(sys.argv[2])
#end=float(sys.argv[3])
#if len(sys.argv) >= 5:
#   hdr=sys.argv[4]

sheets_for_files = []
sheets_limit = []
arr = options_str.split(",")
print("options_str= ", options_str, ", options arr= ", arr)
if len(options_str) > 0:
  lkfor = "sheet_for_file{"
  lkfor2 = "sheet_limit{"
  arr = options_str.split(",")
  if verbose > 0:
     print("options arr= ", arr)
  for opt in arr:
    i = opt.find(lkfor)
    if verbose > 0:
       print("opt= ", opt, ", i=", i)
    if i == 0:
       str2 = opt[len(lkfor):]
       i = str2.find("}")
       str2 = str2[0:i]
       arr2 = str2.split("=")
       sheets_for_files.append([arr2[0], arr2[1]])
       if verbose > 0:
          print("opt= %s, lkfor= %s, str2= %s" % (opt, lkfor, str2), file=sys.stderr)
       continue
    i = opt.find(lkfor2)
    if i == 0:
       str2 = opt[len(lkfor2):]
       i = str2.find("}")
       str2 = str2[0:i]
       arr2 = str2.split(";")
       if verbose > 0:
          print("opt= %s, lkfor= %s, str2= %s" % (opt, lkfor2, str2), ", arr2=", arr2, file=sys.stderr)
       sheets_limit.append([arr2[0], arr2[1], int(arr2[2]) ]) # sheetnm, type_limit, val
       if verbose > 0:
          print("opt= %s, lkfor= %s, str2= %s" % (opt, lkfor, str2), ", arr2= ", arr2, file=sys.stderr)

print("sheets_for_files= ", sheets_for_files)
print("sheets_limit= ", sheets_limit)

with open(flnm) as f:
  data = json.load(f)
# Output: {'name': 'Bob', 'languages': ['English', 'Fench']}
#print(data)
print("len= ", len(data))

if hdr == "" and flnm.find("RPS") > -1:
   hdr="RPS"
   cols=2
if hdr == "" and flnm.find("response") > -1:
   hdr="resp_tm"
   cols=4
if hdr == "" and flnm.find("latency") > -1:
   hdr="latency"
if hdr == "" and flnm.find("http-status") > -1:
   hdr="http_status"

odata=[]
k = -1
targets=0
target_str=""
trgt_dict = {}
trgt_tot  = {}
trgt_tot_tm  = {}
trgt_ts   = {}
trgt_arr  = []
trgt_arr2 = []
ts_dict = {}
lat_tot = 0.0
rows=0
json_stat = None
for i in range(len(data)):
    #print("i= ", i, ", obj= ", data[i])
    trgt = data[i]['target']
    if "tags" in data[i]:
       if "stat" in data[i]['tags']:
          json_stat = data[i]['tags']['stat']
          if json_stat == "muttley.node.calls":
             json_stat = "muttley node calls/sec"
    trgt_arr2.append(trgt)
    if hdr == "latency":
       trgt = data[i]['tags']['bucket']
       lwr_bnd = 1
       mspos = trgt.find("ms")
       if mspos != -1:
          dshpos = trgt.find("-")
          if dshpos < mspos:
             mspos=dshpos
          lwr_bnd_str = trgt[:mspos]
          lwr_bnd = int(lwr_bnd_str)
       else:
          mspos = trgt.find("s")
          if mspos != -1:
             dshpos = trgt.find("-")
             if dshpos < mspos:
                mspos=dshpos
             lwr_bnd_str = trgt[:mspos]
             lwr_bnd = 1000*float(lwr_bnd_str)
       trgt_ts[trgt] = lwr_bnd
       if verbose > 0:
          print("target= %s, lwr_bnd= %d" % (trgt, lwr_bnd))
    tm_diff = 0
    use_every = 1
    use_this  = 0
    json_ts = data[i]['step_size_ms']
    json_ts = json_ts / 1000;
    if match_intrvl > 0 and json_ts > match_intrvl:
       print("________json_2_tsv.py: got match_intrvl= %d, but json_ts = %d secs so disabling matching interval" % (match_intrvl, json_ts), file=sys.stderr)
       match_intrvl = 0

    for j in range(len(data[i]['datapoints'])):
        tm = data[i]['datapoints'][j][1]
        if match_intrvl > 0 and tm_diff == 0:
           tm_diff = data[i]['datapoints'][j+1][1] - tm
           if tm_diff > 0 and tm_diff < match_intrvl:
              use_every = match_intrvl/tm_diff
              if use_every < 1:
                 use_every = 1
           if verbose > 0:
              print("________json_2_tsv.py: got match_intrvl= %d, use_every= %d" % (match_intrvl, use_every), file=sys.stderr)
           
        if use_every > 1:
           use_this += 1
           if use_this < use_every:
              continue
           else:
              use_this = 0
        if (beg == 0.0 and end == 0.0) or (tm >= beg and tm <= end):
           if data[i]['datapoints'][j][0] == None:
              val = 0.0
           else:
              val = data[i]['datapoints'][j][0];
           if not trgt in trgt_dict:
              k += 1
              trgt_dict[trgt] = k
              trgt_tot[trgt] = 0.0
              trgt_tot_tm[trgt] = 0.0
              trgt_arr.append(trgt)
              rows = -1
           rows += 1
           if hdr == "latency":
              trgt_tot[trgt] += val;
              trgt_tot_tm[trgt] += trgt_ts[trgt]*val;
              lat_tot += trgt_ts[trgt]*val;
           if k == 0:
              ts_dict[tm] = rows
              odata.append([tm, tm-beg, val])
           else:
              if not tm in ts_dict:
                 print("need to check your code dude. k= %d ts= %s of target %s not in target= %s array\n" % (k, data[i]['datapoints'][j][1], trgt, trgt_arr[0]), file=sys.stderr)
                 sys.exit(1)
              rw = ts_dict[tm]
              if rw >= len(odata):
                 print("need to check your code dude. rw= %d, len(odata)= %d, k= %d ts= %s of target %s not in target= %s array\n" % (rw, len(odata), k, tm, trgt, trgt_arr[0]), file=sys.stderr)

              odata[rw].append(val)

if hdr == "" and len(trgt_arr2) == 1:
   hdr = trgt_arr2[0]

if sheet_nm == "" and hdr != "":
   sheet_nm = hdr

if sheet_nm == "":
   for i in range(len(sheets_for_files)):
      if flnm.find(sheets_for_files[i][0]) != -1:
         sheet_nm = sheets_for_files[i][1]
         print("set sheet_nm= %s" % (sheet_nm))
         break

# sheet_limit{endpoints;cols_max;100}
sheet_limit_cols = -1
for i in range(len(sheets_limit)):
    if sheets_limit[i][0] == sheet_nm and sheets_limit[i][1] == "cols_max":
       sheet_limit_cols = sheets_limit[i][2]
       print("sheet_limit sheet_nm= %s, mx_col= %d, len(trgt_arr)= %d" % (sheet_nm, sheet_limit_cols, len(trgt_arr)))
       #print("%f" % (1.0/0.0))
       break

line_typ = "scatter_straight"
if options_str != "" and options_str.find("line_for_scatter") >= 0:
   line_typ = "line"
if hdr == "" and json_stat != None:
   hdr = json_stat
of = open(flnm+".tsv","w+")
rw = 0
if desc != "":
  of.write("\tchart querypad string\t%s\n" % (desc))
  rw += 1
of.write("title\t%s\tsheet\t%s\ttype\t%s\n" % (hdr, sheet_nm, line_typ))
rw += 1

endp_list = {}
endp_lkup = {}
endp_map  = {}
endp_mx   = -1
mx_col = len(trgt_arr)
#if sheet_limit_cols != -1 and mx_col > (sheet_limit_cols):
if sheet_limit_cols != -1:
   if sheet_nm == "endpoints":
      #trgt_arr[mx_col-1] = "__other__"
      for j in range(len(trgt_arr)):
          if trgt_arr[j] == "":
             trgt_arr[j] = "__blank__"
          endp = trgt_arr[j]
          jj = endp.find("/")
          if jj != -1:
             endp = endp[0:jj]
          jj = endp.find("--")
          if jj != -1:
             endp = endp[0:jj]
          if not endp in endp_list:
             endp_mx += 1
             endp_list[endp] = endp_mx
             endp_lkup[endp_mx] = endp
          k = endp_list[endp]
          #print("endp[%d]= %s, k= %d" % (j, endp, k))
          endp_map[j] = k
      mx_col = endp_mx
      if verbose > 0:
         print("endp_map: ", endp_map)
         print("endp_mx= %d" % (endp_mx), ", endp_lkup= ", endp_lkup)
      #print("%f" % (1.0/0.0))
      #if endp_mx > sheet_limit_cols:
      #   mx_col = sheet_limit_cols
         print("sheet_limit sheet_nm= %s, mx_col= %d, len(trgt_arr)= %d, endp_mx= %d" % (sheet_nm, mx_col, len(trgt_arr), endp_mx), ", endp_lkup= ", endp_lkup)

if endp_mx != -1:
   of.write("hdrs\t%d\t%d\t%d\t%d\t1\n" % (rw+1, 2, len(odata)+rw+1, endp_mx+2))
else:
   of.write("hdrs\t%d\t%d\t%d\t%d\t1\n" % (rw+1, 2, len(odata)+rw+1, len(trgt_arr)+2))
#hdrs	3	24	-1	35
rw += 1
of.write("ts\toffset")
if endp_mx != -1:
   for j in range(endp_mx+1):
       of.write("\t%s" % (endp_lkup[j]))
else:
   for j in range(len(trgt_arr)):
       of.write("\t%s" % (trgt_arr[j]))
of.write("\n")
rw += 1

avg_sum=[]
avg_n=[]
for j in range(len(trgt_arr)):
    avg_sum.append(0.0)
    avg_n.append(0.0)
    
tm_last = -1.0
dline = []
for j in range(len(trgt_arr)):
    dline.append(0.0)

for i in range(len(odata)):
    if endp_mx != -1:
       for j in range(len(trgt_arr)):
           dline[j] = 0.0
       for j in range(len(trgt_arr)):
           k = endp_map[j]
           if i < len(odata) and (2+j) < len(odata[i]):
              dline[k] += odata[i][2+j]
       for j in range(endp_mx+1):
           if j == 0:
              of.write("%f\t%f\t%f" % (odata[i][0], odata[i][1], dline[j]))
              tm_last = odata[i][1]
           else:
              #of.write("\t%f" % (odata[i][2+j]))
              of.write("\t%f" % (dline[j]))
           avg_sum[j] += dline[j]
           avg_n[j] += 1.0
       of.write("\n")
       rw += 1
       continue

    for j in range(len(trgt_arr)):
        if j == 0:
           of.write("%f\t%f\t%f" % (odata[i][0], odata[i][1], odata[i][2]))
           tm_last = odata[i][1]
        else:
           if i < len(odata) and (2+j) < len(odata[i]):
              of.write("\t%f" % (odata[i][2+j]))
        if i < len(odata) and (2+j) < len(odata[i]):
           avg_sum[j] = avg_sum[j] + odata[i][j+2]
           avg_n[j] = avg_n[j] + 1.0
    of.write("\n")
    rw += 1

sf = None
if sum_file != "":
   sf = open(sum_file,"a+")

http_stat_errs = 0
if hdr == "http_status" and sum_file != "":
   did_writes = 0
   not_200= 0
   not_200_str = ""
   not_200_sep = ""
   for j in range(0, len(trgt_arr)):
       if trgt_arr[j] != "200":
          not_200 = not_200  + avg_sum[j]/avg_n[j]
          not_200_str = not_200_str + not_200_sep + trgt_arr[j]
          not_200_sep = ", "
   for j in range(0, len(trgt_arr)):
       if sf != None and trgt_arr[j] == "200":
          sf.write("%s\t%s\t=%f\t%s\n" % ("software successs", hdr, avg_sum[j]/avg_n[j], trgt_arr[j]))
   if sf != None:
       sf.write("%s\t%s\t=%f\t%s\n" % ("software errs", hdr, not_200, not_200))

if sum_file != "" and hdr != "latency" and hdr != "http_status":
   if endp_mx != -1:
     for j in range(0, endp_mx):
       str = hdr
       str2 = endp_lkup[j]
       if len(str) == 0 and len(str2) > 0:
           str = "RPS "+str2
       #sf.write("\t%s\t%s\t=%f\n" % ("software utilization", hdr, avg_sum[j]/avg_n[j], trgt_arr[j]))
       if sf != None:
          if len(str) > 0 and len(str2) > 0:
             sf.write("\t%s\t\"%s\"\t=%f\n" % (str, str2, avg_sum[j]/avg_n[j]))
          else:
             sf.write("\t%s\t%s\t=%f\n" % ("software utilization", str, avg_sum[j]/avg_n[j]))
   else:
     for j in range(0, mx_col):
       str = hdr
       if len(str) == 0 and len(trgt_arr[j]) > 0:
           str = "RPS "+trgt_arr[j]
       #sf.write("\t%s\t%s\t=%f\n" % ("software utilization", hdr, avg_sum[j]/avg_n[j], trgt_arr[j]))
       if sf != None:
          if len(str) > 0 and len(trgt_arr[j]) > 0:
             sf.write("\t%s\t\"%s\"\t=%f\n" % (str, trgt_arr[j], avg_sum[j]/avg_n[j]))
          else:
             sf.write("\t%s\t%s\t=%f\n" % ("software utilization", str, avg_sum[j]/avg_n[j]))


if hdr != "latency":
   sys.exit(0)

of.write("\n")
rw += 1
tm_tot_lo = 0
tot_calls = 0
tm_tot_hi = 0
lat_tot_mid = 0.0
calls_tot = 0.0
if lat_tot == 0:
   lat_tot = 1

for j in range(len(trgt_arr)):
    trgt = trgt_arr[j]
    tm_nxt = 0
    tm_cur = trgt_ts[trgt]
    calls_tot += trgt_tot[trgt]
    if (j+1) < len(trgt_arr):
       trgtp1 = trgt_arr[j+1]
       tm_nxt = trgt_ts[trgtp1]
    if tm_nxt != 0:
       mid_pt = tm_cur + 0.5*(tm_nxt - tm_cur)
    else:
       mid_pt = tm_cur
    lat_tot_mid += trgt_tot[trgt] * mid_pt
if lat_tot_mid == 0:
    lat_tot_mid = 1.0

of.write("title\t%%total time by response time bucket\tsheet\t%s\ttype\tcolumn\n" % (hdr))
rw += 1
of.write("hdrs\t%d\t%d\t%d\t%d\t%d\n" % (rw+1, 3, rw+len(trgt_arr)+1, 4, 3))
rw += 1
of.write("%s\t%s\t%s\t%s\t%s\n" % ("Latency", "calls", "tot_time(ms)", "%tot_time", "bucket"))
rw += 1
tm_rq_arr = []
for j in range(len(trgt_arr)):
    trgt = trgt_arr[j]
    tot_calls += trgt_tot[trgt]
    tm_cur = trgt_ts[trgt]*trgt_tot[trgt]
    tm_nxt = 0
    mid_pt = trgt_ts[trgt]
    if (j+1) < len(trgt_arr):
       trgtp1 = trgt_arr[j+1]
       tm_nxt = trgt_ts[trgtp1]*trgt_tot[trgt]
       mid_pt = trgt_ts[trgt] + 0.5*(trgt_ts[trgtp1] - trgt_ts[trgt])
    cur_tot = trgt_tot[trgt] * mid_pt
    tm_tot_lo = tm_tot_lo + tm_cur
    tm_tot_hi = tm_tot_hi + tm_nxt
    tm_rq_arr.append([trgt, 100.0*cur_tot/lat_tot_mid, 100.0*trgt_tot[trgt]/calls_tot])
    of.write("%d\t%d\t%d\t%s\t%.3f\t=%d\t=%d\n" % (trgt_ts[trgt], trgt_tot[trgt], trgt_tot_tm[trgt], trgt, 100.0*cur_tot/lat_tot_mid, tm_cur, tm_nxt))
    rw += 1
of.write("\n")
rw += 1
of.write("title\t%%cumulative calls and response time by response time bucket\tsheet\t%s\ttype\tline\n" % (hdr))
rw += 1
of.write("hdrs\t%d\t%d\t%d\t%d\t%d\n" % (rw+1, 0, rw+len(trgt_arr)+1, 2, 0))
rw += 1
of.write("%s\t%s\t%s\n" % ("bucket", "%p_calls", "%p_time"))
rw += 1
time_cumu = 0.0
calls_cumu = 0.0
for j in range(len(tm_rq_arr)):
    time_cumu += tm_rq_arr[j][1]
    calls_cumu += tm_rq_arr[j][2]
    of.write("%s\t%f\t%f\n" % (tm_rq_arr[j][0], time_cumu, calls_cumu))
    rw += 1
of.write("\n")
rw += 1
tm_tot_lo = tm_tot_lo * 0.001
tm_tot_hi = tm_tot_hi * 0.001
of.write("\t\t\t\t\ttot_calls\t=%d\n" % (tot_calls))
of.write("\t\t\t\t\ttm_tot_lo\t=%d\t=%d\ttm_tot_hi\n" % (tm_tot_lo, tm_tot_hi))
of.write("\t\t\t\t\ttm_tot_lo_ms/tot_calls\t=%.6f\t=%.6f\ttm_tot_hi_ms/tot_calls\n" % (1000.0*tm_tot_lo/tot_calls, 1000.0*tm_tot_hi/tot_calls))
if tm_last > 0.0:
   tm_tot_lo = tm_tot_lo / tm_last
   tm_tot_hi = tm_tot_hi / tm_last
   of.write("\t\t\t\t\ttm_tot_lo/s\t=%f\t=%f\ttm_tot_hi/s\n" % (tm_tot_lo, tm_tot_hi))
   if sf != None:
      sf.write("software utilization\tresponse_time_est_total\tlo_est/s\t=%f\n" % (tm_tot_lo))
      sf.write("software utilization\tresponse_time_est_total\thi_est/s\t=%f\n" % (tm_tot_hi))
   tm_tot_lo = tm_tot_lo / 32
   tm_tot_hi = tm_tot_hi / 32
   of.write("\t\t\t\t32 cpus\tfrac_of_32_cpus_lo\t=%f\t=%f\tfrac_of_32_cpus_hi\n" % (tm_tot_lo, tm_tot_hi))
of.write("\n")
sys.exit(0)
