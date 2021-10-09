#!/bin/bash

#################################################################################################
#   This script is used to download blackvue dashcam files to the specified root storage directory.
#   No warranty express or implied comes with this script, and improvements or bugs for this script
#   please let the OP know so all can recieve the fix.
#
#    Files will be downloaded to the root directory then the date the file was captured and then a front
#    and rear folder will be created if dual dashcasm's are installed.
#
#    This script ONLY works with blackvue dashcams (tested on 900S, but should work on 600 and later models)
#
#    -- BigD0g
#################################################################################################

#The top level directory of where to store your dashcam files
DASHCAM_ROOT_STORAGE=~/jarvis-dashcam

#The IP Address of the FRONT blackvue dashcam
DASHCAM_FRONT_IP=192.168.0.21

#The IP Address of the REAR blackvue dashcam if installed aka 4 channel install 2 seperate blackvues
DASHCAM_REAR_IP=192.168.0.22

export BVDATE=`date +%Y%m%d`
echo $BVDATE

function downloadTodaysFiles() {

    count=$(ping -c4 $1 | grep 'received' | awk -F',' '{ print $2}' | awk '{ print $1}')

    if [ $count -eq 4 ]; then
        echo "Successful connection! for " $1
        cd $DASHCAM_ROOT_STORAGE/$BVDATE/$2
        for file in `curl http://$1/blackvue_vod.cgi | sed 's/^n://' | sed 's/F.mp4//' | sed 's/R.mp4//' | sed 's/,s:1000000//' | sed $'s/\r//' | grep $BVDATE`; do
            wget -c http://$1$file\F.mp4;
            wget -c http://$1$file\R.mp4;
            wget -nc http://$1$file\F.thm;
            wget -nc http://$1$file\R.thm;
            wget -nc http://$1$file.gps;
            wget -nc http://$1$file.3gf;
        done
    fi

}

#Setup directories for todays files
if [ ! -d "$DASHCAM_ROOT_STORAGE/$BVDATE" ]; then
  mkdir -p $DASHCAM_ROOT_STORAGE/$BVDATE/front
  mkdir $DASHCAM_ROOT_STORAGE/$BVDATE/rear
fi

#Set this one off into the background so we can do both cameras at the sametime.
downloadTodaysFiles $DASHCAM_FRONT_IP front &

#If you do not have a second blackvue installed delete this next line
downloadTodaysFiles $DASHCAM_REAR_IP rear &

exit 0
