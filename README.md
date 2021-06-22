# 60secs Tool

# Table of Contents
- [Introduction](#introduction)
- [Data collection](#data-collection)
- [Charting Data](#charting-data)

--------------------------------------------------------------------------------
## Introduction
60secs is based on Brendan Gregg's "Linux Performance Analysis in 60 seconds" article.
See his [PDF article](http://www.brendangregg.com/Articles/Netflix_Linux_Perf_Analysis_60s.pdf)

[Project page with more examples and sample spreadsheets](https://patinnc.github.io/60secs/)

--------------------------------------------------------------------------------
## Data Collection
- Copy 60secs.sh to system to be monitored.
    - Probably have to be root
    - Need a perf binary if one isn't installed on the box
    - Say we copy 60secs.sh to /root/60secs.sh
- mkdir 60secs_data
- cd 60secs_data
- ../60secs.sh -t all -d 60 -i 1 # to do all the tasks. each task for 60 seconds, with an interval of 1 sec
- after it is done:
    - cd ..
    - tar czvf 60secs_data.tar.gz 60secs_data
- transfer the data to another box


--------------------------------------------------------------------------------
## Charting Data

- need python
- need to install xlsxwriter from John McNamara
   - see https://xlsxwriter.readthedocs.io/
   - do: pip install xlsxwriter
- On my MacBook I do:
   - tar xzvf 60secs_data.tar.gz
   - cd 60secs_data
   - ~/repos/60secs/src/sys_2_tsv.sh -d . -o dont_sum_sockets > tmp.txt # if you don't want all sockets summed to socket 0
   - ~/repos/60secs/src/sys_2_tsv.sh -d . > tmp.txt # you want all sockets summed to socket 0
   - should create chart_line.xlsx
       - you can open this with Excel or
       - import the sheet into a blank google sheet. It will replace the whole sheet so be careful. You should get all the charts and data. But an excel feature I like (that you won't get) is where you can select the top data series of a chart and hit 'del' and that line will get deleted, chart auto ranges the y axis and you can keep deleting the top line so you can see each line with a reasonable scale. If you try this with google sheets then the whole chart is deleted. But there is a good 'undo'.
- not all the data is charted or even copied to the xlsx. For instance, I'm not sure what to do with the 'free' data. The dmesg data is not shown. The 'top' data has a lot that could be plotted (but I don't yet). It would be nice to do a text flip chart to simulate top updating the screen but I don't know how to do this in a portable way.

