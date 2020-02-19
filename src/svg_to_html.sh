#!/bin/bash

SVG_LIST=
LOG_FILE=
SVG_DIR=
RPS=

while getopts "hd:f:l:r:" opt; do
  case ${opt} in
    l )
      LOG_FILE=$OPTARG
      ;;
    f )
      if [ ! -e $OPTARG ]; then
      echo "didn't find svg file file: $OPTARG"
      exit
      fi
      SVG_FILE="$SVG_FILE $OPTARG"
      ;;
    r )
      RPS="$OPTARG"
      ;;
    d )
      if [ ! -d $OPTARG ]; then
      echo "didn't find svg dir: $OPTARG"
      exit
      fi
      RESP=`find $OPTARG -name "*.svg"`
      if [ "$RESP" == "" ]; then
        echo "didn't find any SVG files in dir $OPTARG"
        exit
      fi
      SVG_DIR=$OPTARG
      SVG_FILE=$RESP
      ;;
    h )
      echo "$0 -f svg_file0 [-f svg_file1 [-f ...]] | -l svg_log_file | [ -d svg_file_dir ]
      echo "Usage: $0 [-h] -f svg_file | -l svg_log_file | -d svg_file_dir 
      echo "   -f svg_file path_of_svg file"
      echo "     This option can be repeated to build a list of svg files."
      echo "   -l svg_log_file  this is a file listing the svgs and other data (like the metric for each file"
      echo "   -d dir_with_svg_files  Currently all the SVGs in the dir will be processed"
      echo "   -r rps  a factor for each file (like the RPS for each svg)"
      echo "   -v verbose mode"
      exit
      ;;
    : )
      echo "Invalid option: $OPTARG requires an argument" 1>&2
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

#if [ "$SVG_DIR" != "" ]; then
#fi
#if [ ! -e $SVG_FILE ]; then
#  echo "didn't find svg file file: $SVG_FILE"
#  exit
#fi

#flmgrf_v2_jdk8_remote_1grps_24thrds/20-01-13_220942/perf-10800_5.1k.svg flmgrf_v2_jdk8_remote_1grps_24thrds/20-01-13_220942/perf-10800_10.3k.svg flmgrf_v2_jdk8_remote_1grps_24thrds/20-01-13_220942/perf-10800_15.2k.svg flmgrf_v2_jdk8_remote_1grps_24thrds/20-01-13_220942/perf-10800_20.0k.svg flmgrf_v2_jdk8_remote_1grps_24thrds/20-01-13_220942/perf-10800_25.2k.svg

#<html>
#<body>
#<?xml version="1.0" standalone="no"?>
#<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
#<div id="pfay_id_01">
## svg here
#</div>
#</body>
#</html>

#		details = document.getElementById("details").firstChild;
#		searchbtn = document.getElementById("search");
#		ignorecaseBtn = document.getElementById("ignorecase");
#		unzoombtn = document.getElementById("unzoom");
#		matchedtxt = document.getElementById("matched");

awk -v rps="$RPS" '
  BEGIN {
   printf("<html>\n");
   printf("<script>\nvar clicked=0; function myFunction() { if (clicked==0){clicked=1;}else{clicked=0;} rescale_all(clicked); console.log(\"clicked it\");}\n");
   printf("function rescale_all(wide0_sqz1) { \n");
   for (i=1; i < ARGC; i++) {
      printf("  rescale_%.2d(wide0_sqz1);\n", i);
   }
   printf("}\n");
   printf("</script>\n");
   printf("<body>\n");
   printf("<button onclick=\"myFunction()\">Click me</button>\n");
   printf("<?xml version=\"1.0\" standalone=\"no\"?>\n");
   fl=0;
   fl_str=sprintf("%.2d", fl);
   #printf("fl_str= %s\n", fl_str);
   printf("<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n");
   smx=0;
   printf("ARGIND= %s\n", ARGIND);
   printf("last file= %s\n", ARGV[ARGC-1]) > "/dev/stderr";
   fctr_mx=0;
   fctr_last=0.0;
   srt_lst="";
   if (rps == "") {
   for (i=1; i < ARGC; i++) {
      str = ARGV[i];
      pos = index(str, ".svg");
      if (pos > 0) {
        str = substr(str, 1, pos-1);
      }
      fctr="1.0";
      last_char = substr(str, length(str), 1);
      if (last_char == "k") {
        str = substr(str, 1, length(str)-1);
        printf("str= %s\n", str) > "/dev/stderr";
        for (j=length(str)-1; j > 0; j--) {
          last_char = substr(str, j, 1);
          if (last_char == "_") {
             str = substr(str, j+1);
             printf("%s\n", str) > "/dev/stderr";
             fctr_arr[++fctr_mx] = str+0.0;
             fctr_last = str+0.0;
             srt_lst = srt_lst "" str " " fctr_mx "\n";
             break;
          }
        }
      }
      printf("file[%d]= %s fctr[%d]= %f\n", i, str, fctr_mx, fctr_arr[fctr_mx]) > "/dev/stderr";
   } 
   } else {
     n=split(rps, arr, ",");
     for (i=1; i <= n; i++) {
         str = arr[i];
         printf("%s\n", str) > "/dev/stderr";
         fctr_arr[++fctr_mx] = str+0.0;
         fctr_last = str+0.0;
         srt_lst = srt_lst "" str " " fctr_mx "\n";
     }
   }
   #printf("\nsrt_lst= %s\n", srt_lst);
   cmd = "printf \"" srt_lst "\" |sort -n -k 1";
   #printf("cmd= %s\n", cmd);
   nf_mx=0;
   while ( ( cmd | getline result ) > 0 ) {
     nf_mx++;
     n = split(result, arr, " ");
     nf_arr[nf_mx,1]=arr[1];
     nf_arr[nf_mx,2]=arr[2];
     nf_arr[nf_mx,3]=ARGV[arr[2]];
     #print  result;
   } 
   close(cmd)
   for (i=1; i <= nf_mx; i++) {
     ARGV[i] = nf_arr[i,3];
     fctr_last = nf_arr[i,1]+0.0;
     fctr_arr[i] = nf_arr[i,1]+0.0;
   }
   if (fctr_mx != nf_mx) {
     printf("screwed up logic here, fctr_mx= %d, nf_mx= %d\n", fctr_mx, nf_mx) > "/dev/stderr";
     exit;
   }
   for (i=1; i <= nf_mx; i++) {
      printf("file[%d]= %s fctr[%d]= %f\n", i, ARGV[i], i, fctr_arr[i]) > "/dev/stderr";
   }
   #exit;
   #printf("%s", srt_lst) | cmd | getline var[1];
   #printf("did one\n");
   #for (j=2; j <= fctr_mx; j++) {
   #   rc = (cmd | getline var[j]);
   #   if (rc <= 0) {
   #     break;
   #   }
   #}
   #close(cmd)
   
   sarr[++smx]="details";
   sarr[++smx]="search";
   sarr[++smx]="ignorecase";
   sarr[++smx]="unzoom";
   sarr[++smx]="details";
   sarr[++smx]="matched";
   sarr[++smx]="frames";
   sarr[++smx]="background";
   sarr[++smx]="title";
   fmx=0;
   farr[++fmx]="init(";
   farr[++fmx]="g_to_text(";
   farr[++fmx]="g_to_func(";
   vmx=0;
   varr[++vmx]="details";
   varr[++vmx]="searchbtn";
   varr[++vmx]="unzoombtn";
   varr[++vmx]="matchedtxt";
   varr[++vmx]="svg";
   varr[++vmx]="searching";
   varr[++vmx]="currentSearchTerm";
   varr[++vmx]="ignorecase";
   varr[++vmx]="ignorecaseBtn";

#  	var details, searchbtn, unzoombtn, matchedtxt, svg, searching, currentSearchTerm, ignorecase, ignorecaseBtn;
#  	function init(evt) {
#  		details = document.getElementById("details").firstChild;
#  		searchbtn = document.getElementById("search");
#  		ignorecaseBtn = document.getElementById("ignorecase");
#  		unzoombtn = document.getElementById("unzoom");
#  		matchedtxt = document.getElementById("matched");
#  		svg = document.getElementsByTagName("svg")[0];
#  		searching = 0;
#  		currentSearchTerm = null;
#  	}
#  	details.nodeValue 


#	function init(evt) {
#	window.addEventListener("keydown",function (e) {
#	window.addEventListener("keydown",function (e) {
#	function find_child(node, selector) {
#	function find_group(node) {
#	function orig_save(e, attr, val) {
#	function orig_load(e, attr) {
#	function g_to_text(e) {
#	function g_to_func(e) {
#	function update_text(e) {
#	function zoom_reset(e) {
#	function zoom_child(e, x, ratio) {
#	function zoom_parent(e) {
#	function zoom(node) {
#	function unzoom() {
#	function toggle_ignorecase() {
#	function reset_search() {
#	function search_prompt() {
#	function search(term) {
   chg=1;
   dis_chg=0;
  }
  /^<..CDATA./ {
    printf("%s {\n", $0);
    next;
  }
  /^]]>/ {
    printf("}\n%s\n", $0);
    next;
  }

  {
    if (ARGIND != fl) {
      argcm1 = ARGC-1;
      fctrm1 = fctr_arr[ARGC-1];
      if (fctrm1 == 0) {
        fctrm1 = 1.0;
      }
      printf("fl= %d, current jOPS= %.3f, %%of max= %.3f%%\n", fl, fctr_arr[ARGIND], 100.0*fctr_arr[ARGIND]/fctrm1);
      printf("</div>\n");
      fl = ARGIND;
      fl_str=sprintf("%.2d", fl);
      printf("<div id=\"pfay_id_%s\">\n", fl_str);
      chg=1;
      dis_chg = 0;
    }
    if ($0 == "<g id=\"frames\">") {
       dis_chg = 1;
    }
    if (chg == 1) {
      if (index($0, "function init(") > 1) {
           printf("  var pfay_id_%s = document.getElementById(\"pfay_id_%s\");\n", fl_str, fl_str); 
           printf("  var fctr_%s = %.3f;\n", fl_str, fctr_arr[ARGIND]);
           printf("  var scale_%s = %.3f;\n", fl_str, fctr_arr[fl]/fctr_arr[fctr_mx]);
      }
      if (index($0, "svg = document.getElementsByTagName") > 1) {
         sub("document", "pfay_id_"fl_str);
      }
      for (i=1; i <=smx; i++) {
         str = "\""sarr[i]"\"";
         if (index($0, str) > 1) {
            if (sarr[i] != "title" || index($0, "find_child") == 0) {
            gsub(str, "\""sarr[i]""fl_str"\"");
            }
         }
         str = "#"sarr[i];
         if (index($0, str) > 1) {
            gsub(str, "#"sarr[i]""fl_str);
         }
      }
      for (i=1; i <=fmx; i++) {
         str = farr[i];
         pos = index($0, str);
         if (pos > 1) {
            str2 = substr(farr[i], 1, length(str)-1);
            str1 = str2 "\\(";
            str2 = str2 "" fl_str "(";
            #str2 = str2 "" fl_str;
            #printf("str= %s, str2= %s\n", str, str2);
            gsub(str1, str2);
         }
      }
      for (i=1; i <=vmx; i++) {
         str = varr[i]",";
         if (index($0, str) > 1) {
            gsub(str, varr[i]""fl_str",");
         }
         str = varr[i]")";
         if (index($0, str) > 1) {
            gsub(str, varr[i]""fl_str")");
         }
         str = varr[i]";";
         if (index($0, str) > 1) {
            gsub(str, varr[i]""fl_str";");
         }
         str = varr[i]" =";
         if (index($0, str) > 1) {
            gsub(str, varr[i]""fl_str" =");
         }
         str = varr[i]" ? ";
         if (index($0, str) > 1) {
            str = varr[i]" ";
            gsub(str, varr[i]""fl_str" ");
         }
         str = varr[i]".";
         if (index($0, str) > 1) {
            gsub(str, varr[i]""fl_str".");
         }
      }
    }
    #if (index($0, "<\svg>") == 1) {
    #  printf("</g>\n");
    #}
    got_svg_beg = 0;
    if (index($0, "<svg ver") == 1) {
       pos = index($0, " width=");
       str = substr($0, pos+7);
       pos2 = index(str, " ");
       width = substr(str, 2);
       pos2 = index(width, "\"");
       width = substr(width, 1, pos2-1);
       printf("width= %s\n", width) > "/dev/stderr";
       printf("<script>function rescale_%s(wide0_sqz1) { var width; if (wide0_sqz1 == 0) { width=\"%s\"; } else { width=\"%.0f\";} document.getElementById(\"svg_%s\").setAttribute(\"width\", width);}</script>\n",
          fl_str, width, width*fctr_arr[fl]/fctr_arr[fctr_mx], fl_str);
       got_svg_beg = 1;
       sub("<svg ", "<svg id=\"svg_"fl_str"\" preserveAspectRatio=\"none\" ");
    }
    printf("%s\n", $0);
    if (dis_chg == 1) {
       chg = 0;
    }
    #if (got_svg_beg==1) {
    #  printf("<g transform=\"scale(%f, 1.0)\">\n", fctr_arr[fl]/fctr_arr[fctr_mx]);
    #}
    if (index($0, "var text = find_child(e, ") > 0) { # g_to_text()
      printf("if (fctr_%s > 0.0) { var pos  = text.lastIndexOf(\"(\"); var sam  = text.substr(pos+1); pos= sam.indexOf(\" \"); sam = sam.substr(0, pos); var nw = parseFloat(sam) / fctr_%s; text += \", samples/metric= \" + nw.toString();}\n", fl_str, fl_str);
    }
  }
  /^lajflakdjflakdj / {
    printf("got %s\n", $0);
    n = split($0, arr, /\//);
    for (i=1; i < n; i++) {
      #printf("arr[%d]= %s\n", i, arr[i]);
      if (arr[i] == "CPU") {
       sub_test = arr[i+1];
       #printf("sub_test= %s\n", sub_test);
       st_beg=1; 
       break;
      }
    }
    getline;
    if (index($0, "Start command: ") == 1) {
      n = split($0, arr, /[()]/);
      beg = arr[2];
      #printf("beg= %s\n",beg);
      getline;
      if (index($0, "Stop command: ") == 1) {
        n = split($0, arr, /[()]/);
        end = arr[2];
        ++st_mx;
        st_sv[st_mx,1]=sub_test;
        st_sv[st_mx,2]=beg;
        st_sv[st_mx,3]=end;
      }
    }
  }
  END{ 
   printf("</div>\n");
   printf("</body>\n");
   printf("</html>\n");
  }
  ' $SVG_FILE
#  ' flmgrf_v2_jdk8_remote_1grps_24thrds/20-01-13_220942/perf-10800_5.1k.svg flmgrf_v2_jdk8_remote_1grps_24thrds/20-01-13_220942/perf-10800_10.3k.svg flmgrf_v2_jdk8_remote_1grps_24thrds/20-01-13_220942/perf-10800_15.2k.svg flmgrf_v2_jdk8_remote_1grps_24thrds/20-01-13_220942/perf-10800_20.0k.svg flmgrf_v2_jdk8_remote_1grps_24thrds/20-01-13_220942/perf-10800_25.2k.svg
# $@
