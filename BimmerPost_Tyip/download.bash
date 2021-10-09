#!/bin/bash
#

# Script path
scriptpath=/data/Video/Blackvue/Scripts/

# Root path
rootpath=/data/Video/Blackvue/X5/

# Car Name
car="X5"

# Exclude recording type..X=no exclusion,N=Exclude Normal Recording
ExcType="N"

# Number of attempts to download mp4 file (minimum is 1)
times="2"

# Locate IP address in arp table
ipaddress=192.168.100.17

# Removal of files older than certain days and empty folders left behind
certain=60

# Time to cleanup old files and empty folders eg. 03-18 or 11-00 or 23-30
cleanuptime=11-00

###### Use to locate IP address if you cannot set it to be static in the dashcam or DHCP, otherwise comment out whole section ######
# macaddress="00:25:42:XX:XX:XX"
# ipaddress=$(arp -n | grep -i $macaddress | awk '{print $1}')
##### in case ipaddress is still empty then
# if [[ -z $ipaddress ]]; then
#     # Ping all addresses between 192.168.1.100 and 192.168.1.200 to make sure we have a complete arp table
#     for i in {100..200}; do (ping 192.168.1.$i -c 1 -w 5  &> /dev/null &); done
#     # Allow some time to get the ping responses
#     sleep 5s
#     # Try again to locate IP address in arp table
#     ipaddress=$(arp -n | grep -i $macaddress | awk '{print $1}')
# fi

# lock dirs/files
LOCKDIR="/tmp/"$car"script-lock"
PIDFILE="${LOCKDIR}/PID"

# exit codes and text
ENO_SUCCESS=0; ETXT[0]="ENO_SUCCESS"
ENO_GENERAL=1; ETXT[1]="ENO_GENERAL"
ENO_LOCKFAIL=2; ETXT[2]="ENO_LOCKFAIL"
ENO_RECVSIG=3; ETXT[3]="ENO_RECVSIG"

###
### start locking attempt
###

trap 'ECODE=$?; echo "["$car"script] Exit: ${ETXT[ECODE]}($ECODE)" >&2' 0
echo -n "["$car"script] Locking: " >&2

if mkdir "${LOCKDIR}" &>/dev/null; then

    # lock succeeded, install signal handlers before storing the PID just in case
    # storing the PID fails
    trap 'ECODE=$?;
          echo "["$car"script] Removing lock. Exit: ${ETXT[ECODE]}($ECODE)" >&2
          rm -rf "${LOCKDIR}"' 0
    echo "$$" >"${PIDFILE}"
    # the following handler will exit the script upon receiving these signals
    # the trap on "0" (EXIT) from above will be triggered by this trap's "exit" command!
    trap 'echo "["$car"script] Killed by a signal." >&2
          exit ${ENO_RECVSIG}' 1 2 3 15
    echo "success, installed signal handlers"

else

    # lock failed, check if the other PID is alive
    OTHERPID="$(cat "${PIDFILE}")"

    # if cat isn't able to read the file, another instance is probably
    # about to remove the lock -- exit, we're *still* locked
    #  Thanks to Grzegorz Wierzowiecki for pointing out this race condition on
    #  http://wiki.grzegorz.wierzowiecki.pl/code:mutex-in-bash
    if [ $? != 0 ]; then
      echo "lock failed, PID ${OTHERPID} is active" >&2
      exit ${ENO_LOCKFAIL}
    fi

    if ! kill -0 $OTHERPID &>/dev/null; then
        # lock is stale, remove it and restart
        echo "removing stale lock of nonexistant PID ${OTHERPID}" >&2
        rm -rf "${LOCKDIR}"
        echo "["$car"script] restarting myself" >&2
        exec "${scriptpath}$0" "$@"
    else
        # lock is valid and OTHERPID is active - exit, we're locked!
        echo "lock failed, PID ${OTHERPID} is active" >&2
        exit ${ENO_LOCKFAIL}
    fi

fi

# at cleanuptime every day when the script is not busy downloading, delete dashcam files over certain days and empty directories to prevent overfilling the disk
if [[ "$(date +"%H-%M")" = "${cleanuptime}" ]]; then
	echo $(date) Started removing files older than $certain days and empty folders under $car.....>>${scriptpath}oldfilecleanup.log
	logfile=$(find "$rootpath" -mtime +${certain} -delete -print)
	echo $(date) Removed old files:>>${scriptpath}oldfilecleanup.log
	echo ${logfile} | tr ' ' '\n'.....>>${scriptpath}oldfilecleanup.log
	logdir=$(find "$rootpath" -type d -empty -delete -print)
	echo $(date) Removed empty directories:>>${scriptpath}oldfilecleanup.log
	echo $logdir | tr ' ' '\n'.....>>${scriptpath}oldfilecleanup.log
	echo $(date) Finished removing old files and empty folders under $car.....>>${scriptpath}oldfilecleanup.log
fi

if [[ ! -z $ipaddress ]]; then

    count=$(ping -c4 $ipaddress | grep 'received' | awk -F',' '{ print $2}' | awk '{ print $1}')
    if [ $count -eq 4 ]; then

        echo "BlackVue-"$car" is up at $(date) ($ipaddress)"
        if wget "http://$ipaddress/blackvue_vod.cgi" --output-document=${rootpath}list.txt --no-use-server-timestamps --no-verbose --timeout 60 --tries 1;then

            # sort the file, get the oldest files first
            sort ${rootpath}list.txt -o ${rootpath}sortlist.txt

			# speedup : remove outdated filenames from Downloaded mp4 file list.txt
			touch ${rootpath}"Downloaded mp4 file list.txt"
			sort ${rootpath}"Downloaded mp4 file list.txt" -o ${rootpath}"Downloaded mp4 file list.txt"
			line=$(head -n 1 ${rootpath}sortlist.txt)
			path=$(echo $line| cut -d':' -f 2)
			path=$(echo $path| cut -d',' -f 1)
			file=$(echo $path| cut -d'/' -f 3)
			if grep -Fq $file ${rootpath}"Downloaded mp4 file list.txt"
			then
				sed -i -n -E -e "/${file}/,$ p" ${rootpath}"Downloaded mp4 file list.txt"
			fi

			# speedup : cleanse the sortlist.txt by removing filenames of already downloaded or excluded mp4 files
			while read line
			do
				if [[ $line = *Record* ]];then
						# extract the different file formats from the line read
						path=$(echo $line| cut -d':' -f 2)
						path=$(echo $path| cut -d',' -f 1)
						file=$(echo $path| cut -d'/' -f 3)
						if grep -Fq $file ${rootpath}"Downloaded mp4 file list.txt"
						then
							grep -v "${file}" ${rootpath}sortlist.txt > ${rootpath}"1.txt"; mv ${rootpath}"1.txt" ${rootpath}sortlist.txt
						fi
				fi
			done < ${rootpath}sortlist.txt

			while read line
            do
			    #check that dashcam is still online
			    countA=$(ping -c2 $ipaddress | grep 'received' | awk -F',' '{ print $2}' | awk '{ print $1}')
                if [ $countA -ne 2 ]; then
				    echo "BlackVue-"$car" is no longer online"
				    exit
			    fi
                # check if valid line
                if [[ $line = *Record* ]];then

                    # extract the different file formats from the line read
                    path=$(echo $line| cut -d':' -f 2)
                    path=$(echo $path| cut -d',' -f 1)
                    file=$(echo $path| cut -d'/' -f 3)
                    sdir=$(echo $file| cut -d'_' -f 1)
                    # echo "$sdir" - "$file" - "$path"

                    # check if directory exist. If not, create it.
                    if [ ! -d "$rootpath$sdir" ]; then
                        mkdir "$rootpath$sdir"
                    fi

                    # check if file exist. If not, copy from dashcam.
					if [ ! -f "$rootpath$sdir/$file" ]; then

                        # If front camera file, try to download gps and 3gf file first
                        if [[ $path = *F.mp4* ]];then
							if [ ! -f "$rootpath$sdir/${file/F.mp4/.gps}" ]; then
								if ! wget "http://$ipaddress${path/F.mp4/.gps}" --directory-prefix=$rootpath$sdir --no-use-server-timestamps --no-verbose --timeout 60 --tries 1;then
									echo Transfer of "${file/F.mp4/.gps}" failed...
									if [ -f "$rootpath$sdir/${file/F.mp4/.gps}" ]; then
										# remove bogus file
										rm -f "$rootpath$sdir/${file/F.mp4/.gps}"
									fi
								else
									# add to the route file
									cat "$rootpath$sdir/${file/F.mp4/.gps}" | awk -F ']' '{ print $2 }' | egrep -v '^$' >> "$rootpath$sdir/route.log"
								fi
							fi

							if [ ! -f "$rootpath$sdir/${file/F.mp4/.3gf}" ]; then
								if ! wget "http://$ipaddress${path/F.mp4/.3gf}" --directory-prefix=$rootpath$sdir --no-use-server-timestamps --no-verbose --timeout 60 --tries 1;then
									echo Transfer of "${file/F.mp4/.3gf}" failed...
									if [ -f "$rootpath$sdir/${file/F.mp4/.3gf}" ]; then
										# remove bogus file
										rm -f "$rootpath$sdir/${file/F.mp4/.3gf}"
									fi
								fi
							fi
                        fi

						if [[ ! $path = *${ExcType}*.mp4* ]];then

							k=1
							while [ $k -le $times ]
							do
							((k++))
							if ! wget "http://$ipaddress$path" --directory-prefix=$rootpath$sdir --no-use-server-timestamps --no-verbose --timeout 60 --tries 1;then
								echo $(date) Transfer of "$file" failed.....>>"$rootpath$sdir/error.log"
								i=$(($times-$k+1))
								echo Transfer of "$file" failed. Trying download again $i more time"("s")".
								if [ -f "$rootpath$sdir/$file" ]; then
									# remove bogus file
									rm -f "$rootpath$sdir/$file"
								fi
							else
								#check integrity of downloaded mp4
								errors=$(ffmpeg -v error -i "/$rootpath$sdir/$file" null $1 2>&1)
								if [[ ! $errors = *null* ]] || [[ $errors = *channel* ]]; then
									echo $(date) $errors .....>>"$rootpath$sdir/error.log"
									i=$(($times-$k+1))
									echo "$rootpath$sdir/$file" corrupted. Trying download again $i more time"("s")".
									rm -f "$rootpath$sdir/$file"
								else
									echo Download of "$rootpath$sdir/$file" successful!
									echo $file >>${rootpath}"Downloaded mp4 file list.txt"
									break
								fi
							fi
							done

						else
							# speedup : these files are diberately excluded, so they go to the Downloaded mp4 file list
							echo $file >>${rootpath}"Downloaded mp4 file list.txt"
                        fi
                    else
					# speedup : useful at initiation then useful because most likely the file is corrupt
					errors=$(ffmpeg -v error -i "/$rootpath$sdir/$file" null $1 2>&1)
						if [[ ! $errors = *null* ]] || [[ $errors = *channel* ]]; then
							echo $(date) DELETED because $errors .....>>"$rootpath$sdir/error.log"
							echo "$rootpath$sdir/$file" corrupted and hence deleted
							rm -f "$rootpath$sdir/$file"
						else
							echo $file >>${rootpath}"Downloaded mp4 file list.txt"
						fi
					fi

                fi

            done < ${rootpath}sortlist.txt

            echo "Completed at $(date)"

        fi

    else

        echo "BlackVue-"$car" is down at $(date) ($ipaddress not responding)"

    fi

else

    echo "BlackVue-"$car" is down at $(date) (not found in arp table)"

fi
