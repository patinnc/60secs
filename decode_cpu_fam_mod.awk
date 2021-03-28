   function decode_fam_mod(vndor, fam, mod, cpu_model_name,    i, k, res, csx_i, dcd) {
      if (vndor == "GenuineIntel") {
        # cascade lake 2nd gen stuff from https://www.intel.com/content/www/us/en/products/docs/processors/xeon/2nd-gen-xeon-scalable-spec-update.html
        # 2nd gen xeon scalable cpus: cascade lake sku is 82xx, 62xx, 52xx, 42xx 32xx W-32xx  from https://www.intel.com/content/www/us/en/products/docs/processors/xeon/2nd-gen-xeon-scalable-spec-update.html
        # skylake 1st gen stuff from https://www.intel.com/content/www/us/en/processors/xeon/scalable/xeon-scalable-spec-update.html
        # 1st gen xeon scalable cpus: 81xx, 61xx, 51xx, 81xxT, 61xxT 81xxF, 61xxF, 51xx, 41xx, 31xx, 51xxT 41xxT, 51xx7, k
        
        # cpuid tables from https://en.wikichip.org/wiki/intel/cpuid
        i=0;
        dcd[++i,1]="Ice Lake";     dcd[i,2]="Family 6 Model 108";
        dcd[++i,1]="Ice Lake";     dcd[i,2]="Family 6 Model 106";
        dcd[++i,1]="Coffee Lake";  dcd[i,2]="Family 6 Model 158";
        dcd[++i,1]="Cooper Lake/Cascade Lake/Skylake";  dcd[i,2]="Family 6 Model 85"; csx_i=i;
        dcd[++i,1]="Broadwell";    dcd[i,2]="Family 6 Model 79";
        dcd[++i,1]="Broadwell";    dcd[i,2]="Family 6 Model 86";
        dcd[++i,1]="Haswell";      dcd[i,2]="Family 6 Model 63";
        dcd[++i,1]="Ivy Bridge";   dcd[i,2]="Family 6 Model 62";
        dcd[++i,1]="Sandy Bridge"; dcd[i,2]="Family 6 Model 45";
        dcd[++i,1]="Westmere";     dcd[i,2]="Family 6 Model 44";
        dcd[++i,1]="EX";           dcd[i,2]="Family 6 Model 47";
        dcd[++i,1]="Nehalem";      dcd[i,2]="Family 6 Model 46";
        dcd[++i,1]="Lynnfield";    dcd[i,2]="Family 6 Model 30";
        dcd[++i,1]="Bloomfield, EP, WS";  dcd[i,2]="Family 6 Model 26";
        dcd[++i,1]="Penryn";       dcd[i,2]="Family 6 Model 29";
        dcd[++i,1]="Harpertown, QC, Wolfdale, Yorkfield";  dcd[i,2]="Family 6 Model 23";
        str = "Family " fam " Model " mod;
        res=" ";
        for(k=1; k <= i; k++) {
           if (dcd[k,2] == str) {
              res=dcd[k,1];break;
           }
        }
        if (k==csx_i) { # so cooper/cascade/sky
           if (match(cpu_model_name, / [86543]2[0-9][0-9]/) > 0) { res="Cascade Lake"}
           else if (match(cpu_model_name, / [86543]1[0-9][0-9]/) > 0) { res="Skylake"}
        }
        return res;
      }
      if (vndor == "AuthenticAMD") {
       # cpuid tables from https://en.wikichip.org/wiki/amd/cpuid
       #Zen 2  Rome    0x8     0xF     0x2     0x?     Family 23 Model [32-47]
       #Matisse        0x8     0xF     0x7     0x1     Family 23 Model 113
       #Castle Peak    0x8     0xF     0x3     0x1     Family 23 Model 49
       #Zen+   Picasso 0x8     0xF     0x1     0x8     Family 23 Model 24
       #Pinnacle Ridge 0x8     0xF     0x0     0x8     Family 23 Model 8
       #Zen    Raven Ridge     0x8     0xF     0x1     0x1     Family 23 Model 17
       #Naples, Whitehaven, Summit Ridge, Snowy Owl    0x8     0xF     0x0     0x1     Family 23 Model 1
#Vendor ID:           AuthenticAMD
#CPU family:          25
#Model:               1
#Model name:          AMD EPYC 7543 32-Core Processor
       
       i=0;
       dcd[++i,1]="Zen2 Rome";           dcd[i,2]="Family 23 Model 32-47"; dcd[i,3]=23; dcd[i,4]=32;  dcd[i,5]=47;
       dcd[++i,1]="Zen2 Matisse";        dcd[i,2]="Family 23 Model 113";   dcd[i,3]=23; dcd[i,4]=113; dcd[i,5]=113;
       dcd[++i,1]="Zen2 Castle Peak";    dcd[i,2]="Family 23 Model 49";    dcd[i,3]=23; dcd[i,4]=49;  dcd[i,5]=49;
       dcd[++i,1]="Zen+ Picasso";        dcd[i,2]="Family 23 Model 24";    dcd[i,3]=23; dcd[i,4]=24;  dcd[i,5]=24;
       dcd[++i,1]="Zen+ Pinnacle Ridge"; dcd[i,2]="Family 23 Model 8";     dcd[i,3]=23; dcd[i,4]=8;   dcd[i,5]=8;
       dcd[++i,1]="Zen Raven Ridge";     dcd[i,2]="Family 23 Model 17";    dcd[i,3]=23; dcd[i,4]=17;  dcd[i,5]=17;
       dcd[++i,1]="Zen Naples/Whitehaven/Summit Ridge/Snowy Owl";
       dcd[++i,2]="Family 23 Model 1";    dcd[i,3]=23; dcd[i,4]=1;  dcd[i,5]=1;
       dcd[++i,1]="Zen3 Milan";          dcd[i,2]="Family 25 Model 1";    dcd[i,3]=25; dcd[i,4]=1;  dcd[i,5]=1;
       str = "Family " fam " Model " mod;
       res=" ";
       for(k=1; k <= i; k++) {
         if (dcd[k,3] == fam && dcd[k,4] <= mod && mod <= dcd[k,5] ) {
           res=dcd[k,1];break;
         }
       }
       return res;
     }
   }
