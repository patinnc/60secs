from __future__ import print_function
import json
import sys

flnm=sys.argv[1]
beg=float(sys.argv[2])
end=float(sys.argv[3])
hdr=""
if len(sys.argv) >= 5:
   hdr=sys.argv[4]
with open(flnm) as f:
  data = json.load(f)
# Output: {'name': 'Bob', 'languages': ['English', 'Fench']}
#print(data)
print("len= ", len(data))

if hdr == "" and sys.argv[1].find("RPS") > -1:
   hdr="RPS"
   cols=2
if hdr == "" and sys.argv[1].find("response") > -1:
   hdr="resp_tm"
   cols=4
if hdr == "" and sys.argv[1].find("latency") > -1:
   hdr="latency"
if hdr == "" and sys.argv[1].find("http-status") > -1:
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
ts_dict = {}
lat_tot = 0.0
rows=0
for i in range(len(data)):
    #print("i= ", i, ", obj= ", data[i])
    trgt = data[i]['target']
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
       trgt_ts[trgt] = lwr_bnd
       print("target= %s, lwr_bnd= %d" % (trgt, lwr_bnd))
    for j in range(len(data[i]['datapoints'])):
        tm = data[i]['datapoints'][j][1]
        if tm >= beg and tm <= end:
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

of = open(flnm+".tsv","w+")
rw = 0
of.write("title\t%s\tsheet\t%s\ttype\tscatter_straight\n" % (hdr, hdr))
rw += 1
of.write("hdrs\t%d\t%d\t%d\t%d\t1\n" % (rw+1, 2, len(odata)+rw+1, 1+len(trgt_arr)))
#hdrs	3	24	-1	35
rw += 1
of.write("ts\toffset")
for j in range(len(trgt_arr)):
    of.write("\t%s" % (trgt_arr[j]))
of.write("\n")
rw += 1

tm_last = -1.0
for i in range(len(odata)):
    for j in range(len(trgt_arr)):
        if j == 0:
           of.write("%f\t%f\t%f" % (odata[i][0], odata[i][1], odata[i][2]))
           tm_last = odata[i][1]
        else:
           of.write("\t%f" % (odata[i][2+j]))
    of.write("\n")
    rw += 1

if hdr != "latency":
   sys.exit(0)

of.write("\n")
rw += 1
of.write("title\t%%total time by response time bucket\tsheet\t%s\ttype\tcolumn\n" % (hdr))
rw += 1
of.write("hdrs\t%d\t%d\t%d\t%d\t%d\n" % (rw+1, 3, rw+len(trgt_arr)+1, 3, 4))
rw += 1
of.write("%s\t%s\t%s\t%s\t%s\n" % ("Latency", "calls", "tot_time(ms)", "%tot_time", "bucket"))
rw += 1
tm_tot_lo = 0
tm_tot_hi = 0
if lat_tot == 0:
   lat_tot = 1
for j in range(len(trgt_arr)):
    trgt = trgt_arr[j]
    tm_cur = trgt_ts[trgt]*trgt_tot[trgt]
    tm_nxt = 0
    if (j+1) < len(trgt_arr):
       trgtp1 = trgt_arr[j+1]
       tm_nxt = trgt_ts[trgtp1]*trgt_tot[trgt]
    tm_tot_lo = tm_tot_lo + tm_cur
    tm_tot_hi = tm_tot_hi + tm_nxt
    of.write("%d\t%d\t%d\t%.3f\t%s\t\t=%d\t=%d\n" % (trgt_ts[trgt], trgt_tot[trgt], trgt_tot_tm[trgt], 100.0*trgt_tot_tm[trgt]/lat_tot, trgt, tm_cur, tm_nxt))
    rw += 1
of.write("\n")
tm_tot_lo = tm_tot_lo * 0.001
tm_tot_hi = tm_tot_hi * 0.001
of.write("\t\t\t\t\ttm_tot_lo\t=%d\t=%d\ttm_tot_hi\n" % (tm_tot_lo, tm_tot_hi))
if tm_last > 0.0:
   tm_tot_lo = tm_tot_lo / tm_last
   tm_tot_hi = tm_tot_hi / tm_last
   of.write("\t\t\t\t\ttm_tot_lo/s\t=%f\t=%f\ttm_tot_hi/s\n" % (tm_tot_lo, tm_tot_hi))
   tm_tot_lo = tm_tot_lo / 32
   tm_tot_hi = tm_tot_hi / 32
   of.write("\t\t\t\t32 cpus\tfrac_of_32_cpus_lo\t=%f\t=%f\tfrac_of_32_cpus_hi\n" % (tm_tot_lo, tm_tot_hi))
of.write("\n")
