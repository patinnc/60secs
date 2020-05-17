#!/bin/bash

#from Young. see email: Fwd: NM command for set CPU power capping
# IPMI node manager reference: nm-4-0-external-interface-spec-550710-rev2-10.pdf 
# https://www.intel.com/content/dam/www/public/us/en/documents/technical-specifications/intel-power-node-manager-v3-spec.pdf

ACTION=$1
ARG2=$2

VEN=`dmidecode -t system | grep -i manufacturer | awk '/Quanta/{printf("qct\n");exit}/Wiwynn/{printf("ww\n");exit}'`
echo "VEN= $VEN"
#exit

if [ "$ACTION" == "" ]; then
  ACTION=get
fi

function decode_c2
{
  # 57 01 00 71 b0 00 96 00 e8 03 00 00 96 00 01 00
  echo "decode_c2: ${ARR[@]}"
  echo ${ARR[3]} | printf "%d\n" "0x${ARR[3]}" | awk '{
    v=$1+0;
    upr=rshift(and(0xf0, v), 4);
    lwr= and(0xf, v);
    #printf("hx= 0x%x upr= 0x%x lwr= 0x%x\n", $1, upr, lwr);
    domain="";
    if (lwr == 0) { domain = "Entire platform";}
    if (lwr == 1) { domain = domain "CPU";}
    if (lwr == 2) { domain = domain "Memory";}
    if (lwr == 3) { domain = domain "HW Protection";}
    if (lwr == 4) { domain = domain "High Power IO";}
    policy = "";
    set = "";
    if (and(upr, 1)>0) { policy = policy "Policy enabled"; sep=", ";}
    if (and(upr, 2)>0) { policy = policy "" sep "Per Domain NM Policy enabled"; sep=", ";}
    if (and(upr, 3)>0) { policy = policy "" sep "Global Domain NM Policy enabled";}
    printf("domain: %s\n", domain);
    printf("policy: %s\n", policy);
   }
   '
   
    #Byte 1 – Completion Code
    #=00h – Success (Remaining standard Completion Codes are shown in Section 2.16.)
    #=80h – Policy ID Invalid. In addition to bytes 2 to 4 extended error information is returned for this error code. =81h – Domain ID Invalid. In addition to bytes 2 to 4 extended error information is returned for this error code.
    #For Completion Code 00h (Success) response bytes 2 to 17 are defined as follows:
    #Byte 2:4 - Intel Manufacturer ID – 000157h, LS byte first.
    #Byte 5 – Domain ID
    #[3:0] - Domain ID (Identifies the domain that this Intel® Node Manager policy applies to.)
    #=00h – Entire platform
    #=01h – CPU subsystem
    #=02h – Memory subsystem
    #=03h – HW Protection*
    #=04h – High Power I/O subsystem
    #Others – Reserved
    #[4] – Policy enabled
    #[5] – Per Domain Intel® Node Manager policy control enabled
    #[6] – Global Intel® Node Manager policy control enabled [7] – Set to 1 if policy is created and managed by other management client e.g., DCMI management API, OSPM or responder LUN does not match. If policy is managed by external agent it could not be modified by Intel® NM IPMI commands.
}

if [ "$DO_Q" == "1" ]; then
$POWER_LO=0xAA # (170W total for 2 CPU)
$POWER_HI=0x00
POWER_LO=0xAA # (170W total for 2 CPU)
POWER_HI=0x00
ipmitool -b 0x06 -t 0x2C raw 0x2E 0xC0 0x57 0x01 0x00 0x01 0x00 0x00   #pg 57 enable nm global policy
ipmitool -b 0x06 -t 0x2C raw 0x2E 0xC0 0x57 0x01 0x00 0x03 0x01 0x00   #pg 57 enable per domain policy for cpu subsystem
ipmitool -b 0x06 -t 0x2c raw 0x2e 0xc1 0x57 0x01 0x00 0x01 0x02 0x10 0x01 $POWER_LO $POWER_HI 0x10 0x27 0x00 0x00 $POWER_LO $POWER_HI 0x0a 0x00
ipmitool -b 0x06 -t 0x2C raw 0x2E 0xC0 0x57 0x01 0x00 0x05 0x01 0x02   #pg 57 enable per policy of bytes 5 & 6: per cpu and memory

#exit
fi


if [ "$ACTION" == "set" ]; then
  
  # below 0xC0 Enable power capping
  # below 0xC1 Set NM policy CPU power capping to 170W (0xaa)
  if [ "$ARG2" != "" ]; then
    PWR_STR=$ARG2
  else
    echo "you must enter 'set power_in_watts'. like $0 set 170"
    echo "bye"
    exit
  fi
  PWR_HEX=`awk -v pwr="$PWR_STR" 'BEGIN{printf("0x%x\n", pwr);exit}'`
  echo "do set PWR_STR= $PWR_STR, PWR_HEX= $PWR_HEX"
  if [ "$VEN" == "qct" ]; then
    POWER_LO=0xAA # (170W total for 2 CPU)
    POWER_LO=$PWR_HEX
    POWER_HI=0x00
    ipmitool -b 0x06 -t 0x2C raw 0x2E 0xC0 0x57 0x01 0x00 0x01 0x00 0x00   #pg 57 enable nm global policy
    ipmitool -b 0x06 -t 0x2C raw 0x2E 0xC0 0x57 0x01 0x00 0x03 0x01 0x00   #pg 57 enable per domain policy for cpu subsystem
    RESP=`ipmitool -b 0x06 -t 0x2c raw 0x2e 0xc1 0x57 0x01 0x00 0x01 0x02 0x10 0x01 $POWER_LO $POWER_HI 0x10 0x27 0x00 0x00 $POWER_LO $POWER_HI 0x0a 0x00`
    ipmitool -b 0x06 -t 0x2C raw 0x2E 0xC0 0x57 0x01 0x00 0x05 0x01 0x02   #pg 57 enable per policy of bytes 5 & 6: per cpu and memory
  else
  # page 105
  # byte6 0x01 && 0x0f is domain
  # byte6      && 0xf0 policy enabled
  #                                                            4    5    6    7        8    9   10   11   12   13   14   15   16   17
  RESP=`ipmitool  -t 0x2c -b 6 raw 0x2e 0xc1 0x57 0x01 0x00 0x01 0x01 0xb0 0x00 $PWR_HEX 0x00 0xe8 0x03 0x00 0x00 0x00 0x00 0x01 0x00`
  fi
  RC=$?
  echo "set cmd RC= $RC"
  if [ "$RC" != "0" -o "$RESP" != " 57 01 00" ]; then
     echo "set cmd seems to have failed"
     exit
  fi
    
  #ipmitool                                 raw 0x2c 0x04 0xdc 0x00 0x00 0x00 0x00 $PWR_HEX 0x00 0xe8 0x03 0x00 0x00 0x00 0x00 $PWR_HEX 0x03
  ACTION="enable"
  #exit
fi

if [ "$ACTION" == "enable" ]; then
  echo "do $ACTION"
  # below 0xC0 Enable power capping
  RESP=`ipmitool -t 0x2c -b 6 raw 0x2e 0xc0 0x57 0x01 0x00 0x05 0x01 0x01`
  if [ "$RC" != "0" -o "$RESP" != " 57 01 00" ]; then
     echo "enable cmd seems to have failed"
     exit
  fi
  RC=$?
  echo "enable cmd response= 0x$RC"
  #IOCTL to get IP failed: -1
  ACTION="get"
  #exit
fi

if [ "$ACTION" == "get" ]; then
  # below 0xC2 Get NM policy
  echo "do $ACTION"
  if [ "$VEN" == "qct" ]; then
  #RESP=`ipmitool  -t 0x2c -b 6 raw 0x2e 0xc2 0x57 0x01 0x00 0x01 0x00`
  RESP=`ipmitool -b 0x06 -t 0x2C raw 0x2E 0xC2 0x57 0x01 0x00 0x00 0x01`   #pg 57 enable per policy of bytes 5 & 6: per cpu and memory
  else
  RESP=`ipmitool  -t 0x2c -b 6 raw 0x2e 0xc2 0x57 0x01 0x00 0x01 0x01`
  fi
  RC=$?
  # 57 01 00 71 b0 00 96 00 e8 03 00 00 96 00 01 00
  echo "get cmd RC= $RC, RESP= $RESP"
  HX=`echo "$RESP" | awk '{printf("%s\n", $7);exit;}'`
  if [ "$RC" == "0" ]; then
  ARR=( $RESP )
  #echo "ARR= ${ARR[@]}"
  #echo "ARR[3]= ${ARR[3]}"
  decode_c2 
  printf "power_limit: 0x%s, %d watts\n" $HX "0x$HX"
  fi
  
  #IOCTL to get IP failed: -1
  #Unable to send RAW command (channel=0x6 netfn=0x6 lun=0x0 cmd=0x34 rsp=0x80): Unknown (0x80)
  exit
fi

exit

# dcmi version of power capping cmds:
#   use https://systemx.lenovofiles.com/help/index.jsp?topic=%2Fcom.lenovo.sysx.imm2.doc%2Fnn1jo_c_dcmi_power_mgmt.html
#   enable capping
#   ipmitool raw 0x2c 0x05 0xdc 0x01 0x00 0x00

# below 0xC2 Get NM policy, the policy is disabled and power capping is 100W
ipmitool  -t 0x2c -b 6 raw 0x2e 0xc2 0x57 0x01 0x00 0x01 0x01
exit

