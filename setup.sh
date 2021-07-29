echo "Installing Required Global packages"
export DEBIAN_FRONTEND=noninteractive
apt-get -y install sudo
apt-get -y install msr-tools
apt-get -y install hwloc
apt-get -y install hwinfo
apt-get -y install cpuid
apt-get -y install lsblk
apt-get -y install util-linux
apt-get -y install numactl
apt-get -y install sysstat
apt-get -y install nicstat
apt-get -y install jq
apt-get -y install dmidecode
##apt-get -y install cpupower
##apt-get -y install linux-cpupower
#apt-get -y install hwloc
#apt-get -y install hwinfo
#apt-get -y install lscpu
#apt-get -y install lsblk
#apt-get -y install cpuid
#apt-get -y install util-linux # for lscpu
#apt-get -y install numactl
#apt-get -y install dmidecode
#apt-get -y install sysstat nicstat
