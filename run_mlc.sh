#!/bin/bash

ODIR=/root/output/mlc_data
if [ "$1" != "" ]; then
 ODIR=$1
fi
mkdir -p $ODIR

LST="latency_matrix bandwidth_matrix peak_injection_bandwidth idle_latency loaded_latency c2c_latency"

for i in $LST; do
 echo ./mlc --${i}
 /root/svr_info/bin/mlc --${i} > $ODIR/mlc_${i}.txt
done
exit
