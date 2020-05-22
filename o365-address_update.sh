#!/bin/bash -f
#If this machine version R80.40, uncomment the line below
source /opt/CPshrd-R80.40/tmp/.CPprofile.sh
#If this machine version R80.30, uncomment the line below
#source /opt/CPshrd-R80.30/tmp/.CPprofile.sh
#If this machine version R80.20, uncomment the next line
#source /opt/CPshrd-R80.20/tmp/.CPprofile.sh
#If this machine version R80.10, uncomment the line below
#source /opt/CPshrd-R80/tmp/.CPprofile.sh
#------------------------------------------------------------------------------------
#Define Environment
#Define Scripts Path
v_spath=/var/scripts
#Policy Name
v_polpack=Standard
#Policy Target Name
v_poltarget=ledinfrfw01
#Name  of group object
v_grp=ge_o365-networks
#Naming prefix for elements
v_objprefix=net-o365-
#comment for objects
v_objcomment="Do NOT use this object. Automatically created and deleted!"
#color of objects
v_objcolor=yellow
#Login User
v_cpuser=apiuser
#Login Password
v_cpuserpw=changeme
#Time
time=$(date "+%Y.%m.%d-%H.%M.%S")

#(if needed) define mail subject for notification
echo "Subject: "Activity Report - Office365 Import Script""


#define helper_files and vars
v_helper_o365_ipv4cidr=o365_helper_cidr.tmp
v_helper_o365_ipv4netmask=o365_helper_netmask.tmp
v_helper_rmfromgrp=o365_helper_removefromgrp.tmp
v_helper_rmobj=o365_helper_removeobjects.tmp
v_helper_currobj=o365_helper_currentobjects.tmp
v_helper_addhostcsv=o365_helper_add.tmp
v_helper_objlist_mso365sorted=o365_helper_ms-objsorted.tmp
v_helper_objlist_instsorted=o365_helper_inst-objsorted.tmp
v_helper_difflist=o365_helper_difflist.tmp
v_diff_add=o365_helper_diff_add.tmp
v_diff_rm=o365_helper_diff_rm.tmp
v_diff_add_netmask=o365_helper_diff_add_nm.tmp
v_diff_rm_sh=o365_helper_diff_rm_sh.tmp
v_diff_add_sh=o365_helper_diff_add_sh.tmp
#------------------------------------------------------------------------------------

echo "################## Script starts : $time ##################"
#cleaning up directory from helper files
if ls o365_helper* 1> /dev/null 2>&1; 
then
    rm o365_helper*
fi

#Download of Feed
curl_cli --insecure 'https://endpoints.office.com/endpoints/worldwide?noipv6&ClientRequestId=b10c5ed1-bad1-445f-b386-b919946339a7' | jq '.[] | select(.category=="Optimize")' | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\/[0-9]\{1,\}' > $v_helper_o365_ipv4cidr

mgmt_cli login --user $v_cpuser --password $v_cpuserpw --format json > id.txt

if mgmt_cli show group name "$v_grp" --format json -s id.txt | grep -q 'generic_err_object_not_found'; then
  echo "Group $v_grp does not exist. Creating ..."
  mgmt_cli add group name "$v_grp" color "$v_objcolor" comments "$v_objcomment" -s id.txt
else
echo "group $v_grp already exists"
fi

if [ -e $v_helper_o365_ipv4cidr ]
then
    if [ -s $v_helper_o365_ipv4cidr ]
    then
        mgmt_cli show group name "$v_grp" -s id.txt |grep $v_objprefix |grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\-[0-9]\{1,\}'|sed -e 's|-|\/|g' > $v_helper_currobj
        #check for duplicates on Office365 and sort
        awk '!seen[$0]++' $v_helper_o365_ipv4cidr > $v_helper_objlist_mso365sorted
        sort -n $v_helper_objlist_mso365sorted  -o $v_helper_objlist_mso365sorted
        #sort existing member objects 
        awk '!seen[$0]++' $v_helper_currobj > $v_helper_objlist_instsorted
        sort -n $v_helper_objlist_instsorted  -o $v_helper_objlist_instsorted

        #finding changes
        diff -q $v_helper_objlist_mso365sorted $v_helper_objlist_instsorted
            if [ $? -ne 0 ];
            then
                diff $v_helper_objlist_mso365sorted $v_helper_objlist_instsorted > $v_helper_difflist
                grep -o '< [0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\/[0-9]\{1,\}' $v_helper_difflist |sed -e 's|< ||g' > $v_diff_add
                grep -o '> [0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\/[0-9]\{1,\}' $v_helper_difflist |sed -e 's|> ||g' > $v_diff_rm
                #replace / with -
                sed -i 's|\/|-|g' $v_diff_add
                sed -i 's|\/|-|g' $v_diff_rm

                #calc to Subnet and Netmask
                while IFS="-" read IP S
                    do
                        M=$(( 0xffffffff ^ ((1 << (32-S)) -1) ))
                        echo "subnet \"$IP\" subnet-mask \"$(( (M>>24) & 0xff )).$(( (M>>16) & 0xff )).$(( (M>>8) & 0xff )).$(( M & 0xff ))\""
                done < $v_diff_add >> $v_diff_add_netmask

                #object removal
                if [ -s $v_diff_rm ]
                then
                    echo "Found objects to remove"
                    awk -v awk_grp="$v_grp" -v awk_opfx="$v_objprefix" '{ print "mgmt_cli -s id.txt set group name \""awk_grp"\" members.remove \""awk_opfx$0"\" ignore-warnings \"true\""}' $v_diff_rm >$v_diff_rm_sh
                    awk -v awk_grp="$v_grp" -v awk_opfx="$v_objprefix" '{ print "mgmt_cli -s id.txt delete network name \""awk_opfx$0"\" ignore-warnings \"true\""}' $v_diff_rm >>$v_diff_rm_sh
                    sh $v_diff_rm_sh
                else
                    echo "no objects to remove found"
                fi

                #object creation
                if [ -s $v_diff_add ]
                then
                    echo "found new objects!"
                    awk -v awk_grp="$v_grp" -v awk_opfx="$v_objprefix" -v awk_color="$v_objcolor" -v awk_comment="$v_objcomment" 'FNR==NR { a[FNR""] = $0; next } { print "mgmt_cli -s id.txt add network name \""awk_opfx""a[FNR""]"\" ",$0" color \""awk_color"\" groups.1 \""awk_grp"\" comments \""awk_comment"\""}' $v_diff_add $v_diff_add_netmask >$v_diff_add_sh
                    sh $v_diff_add_sh
                else
                    echo "Nothing to add"
                fi

                #publish changes
                mgmt_cli publish -s id.txt

                echo "Done! Installing Policy!"

                #install policy
                mgmt_cli install-policy policy-package "$v_polpack" access true threat-prevention true targets.1 "$v_poltarget" -s id.txt

            else
                echo "No Changes!"
                mgmt_cli discard -s id.txt --format json
            fi
    else
        echo "PROBLEM! Could not get feed!"
	cat $v_helper_o365_ipv4cidr
        mgmt_cli discard -s id.txt --format json
    fi
else
    echo "PROBLEM! Feed could not process! File $v_helper_o365_ipv4cidr not found"
    mgmt_cli discard -s id.txt --format json
fi
#cleaning up
mgmt_cli logout -s id.txt
rm id.txt
rm $v_helper_o365_ipv4cidr
rm $v_helper_o365_ipv4netmask
rm $v_helper_rmfromgrp
rm $v_helper_rmobj
rm $v_helper_currobj
rm $v_helper_addhostcsv
rm $v_helper_objlist_mso365sorted
rm $v_helper_objlist_instsorted
rm $v_helper_difflist
rm $v_diff_add
rm $v_diff_rm
rm $v_diff_add_netmask
rm $v_diff_rm_sh
rm $v_diff_add_sh


echo "DONE"
echo "################## Script ends : $time ##################"
