#!/bin/bash

STR_IN=$1
STR_CK=$2

awk -v in_lst="$1" -v ck_lst="$2" '
BEGIN {
   a = "kitten";
   b = "sitting";
   a = in_str;
   nin = split(in_lst, in_arr, ",");
   n = split(ck_lst, arr, ",");
   for (j=1; j <= nin; j++) {
    dmin = -1;
    dmax = -1;
    a = in_arr[j];
    for (i=1; i <= n; i++) {
      b = arr[i];
      #d = levenshteinDistance(a, b);
      d = levdist(a, b);
      dist[i] = d;
      if (dmin == -1) {
        dmin = d;
        dmax = d;
      }
      if (dmin > d) {
        dmin = d;
      }
      if (dmax < d) {
        dmax = d;
      }
      #printf("%s -> %s after %d edit%s\n", a, b, d, p);
    }
    if (dmin > 0) {
    prtd = 0;
    printf("error suboption= %s top_10 closest options: ", a);
    for (k=dmin; k <= dmax; k++) {
     for (i=1; i <= n; i++) {
       if (dist[i] != k) {
         continue;
       }
       b = arr[i];
       d = dist[i];
       p = d == 1 ? "" : "s";
       if (prtd < 11) {
         printf("%s,", b);
       }
       prtd++;
     }
    }
    printf("\n");
    }
   }
   
   exit;
}
 
# from http://awk.freeshell.org/LevenshteinEditDistance
function levdist(str1, str2,	l1, l2, tog, arr, i, j, a, b, c) {
	if (str1 == str2) {
		return 0
	} else if (str1 == "" || str2 == "") {
		return length(str1 str2)
	} else if (substr(str1, 1, 1) == substr(str2, 1, 1)) {
		a = 2
		while (substr(str1, a, 1) == substr(str2, a, 1)) a++
		return levdist(substr(str1, a), substr(str2, a))
	} else if (substr(str1, l1=length(str1), 1) == substr(str2, l2=length(str2), 1)) {
		b = 1
		while (substr(str1, l1-b, 1) == substr(str2, l2-b, 1)) b++
		return levdist(substr(str1, 1, l1-b), substr(str2, 1, l2-b))
	}
	for (i = 0; i <= l2; i++) arr[0, i] = i
	for (i = 1; i <= l1; i++) {
		arr[tog = ! tog, 0] = i
		for (j = 1; j <= l2; j++) {
			a = arr[! tog, j  ] + 1
			b = arr[  tog, j-1] + 1
			c = arr[! tog, j-1] + (substr(str1, i, 1) != substr(str2, j, 1))
			arr[tog, j] = (((a<=b)&&(a<=c)) ? a : ((b<=a)&&(b<=c)) ? b : c)
		}
	}
	return arr[tog, j-1]
}
 
# from https://rosettacode.org/wiki/Levenshtein_distance#AWK
function levenshteinDistance(s1, s2,
    s1First, s2First, s1Rest, s2Rest,
    distA, distB, distC, minDist) {
 
    # If either string is empty,
    # then distance is insertion of the others characters.
    if (length(s1) == 0) return length(s2);
    if (length(s2) == 0) return length(s1);
 
    # Rest of process uses first characters 
    # and remainder of each string.
    s1First = substr(s1, 1, 1);
    s2First = substr(s2, 1, 1);
    s1Rest = substr(s1, 2, length(s1));
    s2Rest = substr(s2, 2, length(s2));
 
    # If leading characters are the same, 
    # then distance is that between the rest of the strings.
    if (s1First == s2First) {
        return levenshteinDistance(s1Rest, s2Rest);
    }
 
    # Find the distances between sub strings.
    distA = levenshteinDistance(s1Rest, s2);
    distB = levenshteinDistance(s1, s2Rest);
    distC = levenshteinDistance(s1Rest, s2Rest);
 
    # Return the minimum distance between substrings.    
    minDist = distA;
    if (distB < minDist) minDist = distB;
    if (distC < minDist) minDist = distC;
    return minDist + 1; # Include change for the first character.
}
' 
