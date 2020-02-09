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


odata=[]
k = -1
targets=0
target_str=""
trgt_dict = {}
trgt_arr  = []
ts_dict = {}
rows=0
for i in range(len(data)):
    #print("i= ", i, ", obj= ", data[i])
    trgt = data[i]['target']
    for j in range(len(data[i]['datapoints'])):
        if data[i]['datapoints'][j][0] != None and data[i]['datapoints'][j][1] >= beg and data[i]['datapoints'][j][1] <= end:
           if not trgt in trgt_dict:
              k += 1
              trgt_dict[trgt] = k
              trgt_arr.append(trgt)
              rows = -1
           rows += 1
           if k == 0:
              ts_dict[data[i]['datapoints'][j][1]] = rows
              odata.append([data[i]['datapoints'][j][1], data[i]['datapoints'][j][1]-beg, data[i]['datapoints'][j][0]])
           else:
              if not data[i]['datapoints'][j][1] in ts_dict:
                 print("need to check your code dude. ts= %s of target %s not in target= %s array\n" % (data[i]['datapoints'][j][1], trgt, trgt_arr[0]))
                 sys.exit(1)
              rw = ts_dict[data[i]['datapoints'][j][1]]
              odata[rw].append(data[i]['datapoints'][j][0])

of = open(flnm+".tsv","w+")
rw = 0
of.write("title\t%s\tsheet\t%s\ttype\tscatter_straight\n" % (hdr, hdr))
rw += 1
of.write("hdrs\t%d\t%d\t%d\t%d\t1\n" % (rw+1, 2, len(odata)+rw, 1+len(trgt_arr)))
#hdrs	3	24	-1	35
rw += 1
of.write("ts\toffset")
for j in range(len(trgt_arr)):
    of.write("\t%s" % (trgt_arr[j]))
of.write("\n")

for i in range(len(odata)):
    for j in range(len(trgt_arr)):
        if j == 0:
           of.write("%f\t%f\t%f" % (odata[i][0], odata[i][1], odata[i][2]))
        else:
           of.write("\t%f" % (odata[i][2+j]))
    of.write("\n")

