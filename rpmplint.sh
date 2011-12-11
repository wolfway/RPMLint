#!/bin/bash

# Author Dimitar Yordanov
#
# Usage : sudo /tmp/script.sh  <5.3.iso>  <5.4.iso>

DATE=$(date +%m_%d_%H_%M)
LOG=/tmp/sat_rpm_${DATE}.log

############################################ FUNCTIONS ######################################
function print_msg() {
  echo "===> $1" | tee -a $LOG
}
function print_pkg() {
  echo "=> $1" | tee -a $LOG
}
function separate() {
   echo "########################## $1 ##########################" | tee -a $LOG
}
function separate_pkg() {
  echo "--------------------------------------------------------" | tee -a $LOG
}
function separate_section(){
   echo "=========================================================" | tee -a $LOG
}

function remove_pkg() {

OLD_IFS=$IFS
IFS=''

local arr_str="$1[*]"
local arr_local=(${!arr_str})

eval "$1=(`echo  ${arr_local[*]} | tr ' ' '\n' | egrep -v "/\$2$"`)"

IFS=$OLD_IFS
  
}

function usage() {
 echo "Usage: ./script.sh 5.3.iso 5.4.iso"
}

function clean() {
 separate_section;
 echo "Clean out ... "
 echo "Umount 5.3" 
 umount /tmp/RMPLINT_$DATE/5.3
 echo "Umont 5.4"
 umount /tmp/RMPLINT_$DATE/5.4
 echo "Remove /tmp/RMPLINT_$DATE/"
 rm -fr /tmp/RMPLINT_$DATE/
 echo '*************************************************************'
 echo "|   Log file : $LOG"
 echo '*************************************************************'
 exit;
}

##################################################      MAIN   ##################################################

# Test  Paramas
if [[ (`id -u` -ne 0) || ($# -ne 2) ]];then
  usage;
  exit 1;
fi
#--------------------------------------------------------------------------------------------------------------------
mkdir /tmp/RMPLINT_$DATE && mkdir /tmp/RMPLINT_$DATE/5.3 && mkdir /tmp/RMPLINT_$DATE/5.4 && \
 mount -o loop $1 /tmp/RMPLINT_$DATE/5.3 && \
 mount -o loop $2 /tmp/RMPLINT_$DATE/5.4  

RPM_3_home=/tmp/RMPLINT_$DATE/5.3/Satellite

RPM_4_home=/tmp/RMPLINT_$DATE/5.4/Satellite
#--------------------------------------------------------------------------------------------------------------------

#Take all the Satellite 5.3 Packages
declare -a arr_Sat_3_rpm=(`find /tmp/RMPLINT_$DATE/5.3 -name "*.rpm" | sort`)


#Take all the Satellite 5.4 Packag
declare -a arr_Sat_4_rpm=(`find /tmp/RMPLINT_$DATE/5.4 -name "*.rpm" | sort`)

#Number of 5.3 Pkg
print_msg "Number of RPM in 5.3 = ${#arr_Sat_3_rpm[*]}"
#Number of 5.4 Pkg
print_msg "Number of RPM in 5.4 = ${#arr_Sat_4_rpm[*]}"
#   

# Find the packages that are common for 5.4 and 5.3 (were not changed)
separate 'Common packages for 5.3/5.4'
pkg_cnt=0;
for line in ${arr_Sat_3_rpm[*]}
 do
   # Get the name of the packet
   pkg=`echo ${line##*/}` 
   if [[ `echo  ${arr_Sat_4_rpm[*]} | tr ' ' '\n ' | egrep -c "/$pkg$"` -gt 0 ]]
     then
       pkg_cnt=$(($pkg_cnt+1))
       print_pkg $pkg
       # Take the package out of the 5.3 list
       #  arr_Sat_3_rpm=(`echo  ${arr_Sat_3_rpm[*]} | tr ' ' '\n ' | egrep -v "^$pkg$"`)
       remove_pkg  arr_Sat_3_rpm $pkg
       # Take the package out of the 5.4 list
       #  arr_Sat_4_rpm=(`echo  ${arr_Sat_4_rpm[*]} | tr ' ' '\n ' | egrep -v "^$pkg$"`) 
       remove_pkg  arr_Sat_4_rpm $pkg
   fi
 done
print_msg " Total number of common packages = $pkg_cnt";

separate 'Java Packages'
print_msg 'Satellite 5.3'
  for line in `echo  ${arr_Sat_3_rpm[*]} | tr ' ' '\n ' | egrep -i "/java.*\.rpm$"`	
    do #Get only the pkg name
      pkg=`echo ${line##*/}`
      print_pkg $pkg
      remove_pkg  arr_Sat_3_rpm $pkg
    done
print_msg 'Satellite 5.4'
  for line in `echo  ${arr_Sat_4_rpm[*]} | tr ' ' '\n ' | egrep -i "/java.*\.rpm$"`
   do #Get only the pkg name
      pkg=`echo ${line##*/}`
      print_pkg $pkg
      remove_pkg  arr_Sat_4_rpm $pkg
   done

#Packages that are in  5.3 and are not included in 5.4
separate 'Packages that are in 5.3 and are not included in 5.4'
pkg_cnt=0
for line in ${arr_Sat_3_rpm[*]}
 do    
     #Get only the pkg name
     pkg=`echo ${line##*/}`   
     #pkg_name=`expr match "$pkg" '\([^\.]\+\)-[0-9]\+\..*'` 
     pkg_name=`echo ${pkg%%-[0-9]*\.[0-9]*.*.rpm}`
     if [[ `echo ${arr_Sat_4_rpm[*]} | tr ' ' '\n ' | egrep -c "/\$pkg_name.*rpm$"` -eq 0  ]];then
          print_pkg $pkg
          # Take the package out of the 5.3 list
          remove_pkg  arr_Sat_3_rpm $pkg         
          pkg_cnt=$((pkg_cnt+1))   
     fi
 done
 print_msg "Total number: $pkg_cnt"

#Packages that are in  5.4 and are not included in 5.3
separate 'Packages that are in 5.4 and are not included in 5.3'
pkg_cnt=0
for line in ${arr_Sat_4_rpm[*]}
 do    
     #Get only the pkg name
     pkg=`echo ${line##*/}`    
     #pkg_name=`expr match "$pkg" '\([^\.]\+\)-[0-9]\+\..*'` 
     pkg_name=`echo ${pkg%%-[0-9]*\.[0-9]*.*.rpm}`
     if [[ `echo ${arr_Sat_3_rpm[*]} | tr ' ' '\n' | egrep -c "/\$pkg_name.*.rpm$"` -eq 0  ]];then 
          print_pkg "$pkg"
          rpmlint $RPM_4_home/$pkg | tee -a $LOG
          separate_section;
          # Take the package out of the 5.4 list
          remove_pkg  arr_Sat_4_rpm $pkg 
          pkg_cnt=$((pkg_cnt+1))       
     fi
 done
print_msg "Total number: $pkg_cnt"
 
# Compare the rest of the packages - DEBUG
if [[ ${#arr_Sat_4_rpm[*]} -ne ${#arr_Sat_3_rpm[*]} ]];then
   print "Something went wrong !!!"
fi

separate ' Compare 5.3 rpm version against 5.4 rpm version of a package.' 
separate " Number of packges to be compared = ${#arr_Sat_4_rpm[*]}"

for (( index=0; index < ${#arr_Sat_4_rpm[*]}; index++ ))
  do
    separate_section;
    print_pkg "`echo ${arr_Sat_3_rpm[$index]##*/}`"
    rpmlint  ${arr_Sat_3_rpm[$index]} | tee -a  $LOG
    separate_pkg;
    print_pkg "`echo ${arr_Sat_4_rpm[$index]##*/}`"
    rpmlint ${arr_Sat_4_rpm[$index]}  | tee -a $LOG
  done
 
# Clean
clean; 
#END
