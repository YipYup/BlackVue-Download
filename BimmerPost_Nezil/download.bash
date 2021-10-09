#!/bin/bash

echo

###### Set location where you want to store dashcam data. Sub-directories will be created for each day ######
rootpath=[Your data storage location]

###### If IP Address can be set static in the dascham or DHCP server, set the IP address here, otherwise comment out this line ######
ipaddress=[Dashcam IP Address]

###### Use to locate IP address if you cannot set it to be static in the dashcam or DHCP, otherwise comment out whole section ######
# macaddress="00:25:42:XX:XX:XX"
# ipaddress=$(arp -n | grep -i $macaddress | awk '{print $1}')
# if [[ -z $ipaddress ]]; then
#     # Ping all addresses between 192.168.1.100 and 192.168.1.200 to make sure we have a complete arp table
#     for i in {100..200}; do (ping 192.168.1.$i -c 1 -w 5  &> /dev/null &); done
#     # Allow some time to get the ping responses
#     sleep 5s
#     # Try again to locate IP address in arp table
#     ipaddress=$(arp -n | grep -i $macaddress | awk '{print $1}')
# fi

if [[ ! -z $ipaddress ]]; then
    count=$(ping -c4 $ipaddress | grep 'received' | awk -F',' '{ print $2}' | awk '{ print $1}')
    if [ $count -eq 4 ]; then
        echo "BlackVue is up at $(date) ($ipaddress)"
        echo "Getting file list"
        if curl -# "http://$ipaddress/blackvue_vod.cgi" -o ${rootpath}list.txt --no-verbose;then
            # sort the file, get the oldest files first
            sort ${rootpath}list.txt -o ${rootpath}sortlist.txt
            while read line
            do
                # check if valid line
                if [[ $line = *Record* ]];then
                    # extract the different file formats from the line read
                    path=$(echo $line| cut -d':' -f 2)
                    path=$(echo $path| cut -d',' -f 1)
                    file=$(echo $path| cut -d'/' -f 3)
                    sdir=$(echo $file| cut -d'_' -f 1)
                    # echo "$sdir" - "$file" - "$path"
                    # check if directory exists. If not, create it.
                    if [ ! -d "$rootpath$sdir" ]; then
                        mkdir "$rootpath$sdir"
                    fi

                    # check if file exist. If not, copy from dashcam.
                    if [ ! -f "$rootpath$sdir/$file" ]; then
                        #If front camera file, try to download gps and 3gf file first
                        if [[ $path = *F.mp4* ]];then
                             echo "Downloading ${path/F.mp4/.gps}"
                             (cd $rootpath$sdir; curl -# "http://$ipaddress${path/F.mp4/.gps}" -O)
                             echo "Downloading ${path/F.mp4/.3gf}"
                             (cd $rootpath$sdir; curl -# "http://$ipaddress${path/F.mp4/.3gf}" -O)
                        fi
                        if ! (echo "Downloading $path"; cd $rootpath$sdir; curl -# "http://$ipaddress$path" -O);then
                            echo Transfer of "$file" failed...
                            if [ -f "$rootpath$sdir/$file" ]; then
                                # remove bogus file
                                rm -f "$rootpath$sdir/$file"
                            fi
                        fi
                    fi
                fi
            done < ${rootpath}sortlist.txt
            echo "Completed at $(date)"
        fi
else
    echo "BlackVue is down at $(date) ($ipaddress not responding)"
fi
