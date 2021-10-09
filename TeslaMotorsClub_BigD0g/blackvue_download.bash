#!/bin/bash

#################################################################################################
#   This script is used to download blackvue dashcam files to the specified root storage directory.
#   No warranty express or implied comes with this script, and improvements or bugs for this script
#   please let the OP know so all can recieve the fix.
#
#   The script will download yesterday and today's files and due to the use of wget will not duplicate
#   file downloads.
#
#   Files will be downloaded to the root directory then the date the file was captured and then a front
#   and rear folder will be created if dual dashcasm's are installed.
#
#   This script ONLY works with blackvue dashcams (tested on 900S, but should work on 600 and later models)
#
#    -- BigD0g
#################################################################################################

#The top level directory of where to store your dashcam files
DASHCAM_ROOT_STORAGE=/media/shared/tesla/dashcam

#The IP Address of the FRONT blackvue dashcam
DASHCAM_FRONT_IP=192.168.0.21

#The IP Address of the REAR blackvue dashcam if installed aka 4 channel install 2 seperate blackvues
DASHCAM_REAR_IP=192.168.0.22

export BVDATE=`date '+%Y%m%d'`
echo $BVDATE

export YESTERDAYDATE=`date -d "1 day ago" '+%Y%m%d'`
echo $YESTERDAYDATE

function downloadSpecifiedFileDates() {

    #Setup directories for files by date
    if [ ! -d "$DASHCAM_ROOT_STORAGE/$YESTERDAYDATE" ]; then
        mkdir -p $DASHCAM_ROOT_STORAGE/$YESTERDAYDATE/front
        mkdir $DASHCAM_ROOT_STORAGE/$YESTERDAYDATE/rear
    fi

    if [ ! -d "$DASHCAM_ROOT_STORAGE/$BVDATE" ]; then
        mkdir -p $DASHCAM_ROOT_STORAGE/$BVDATE/front
        mkdir $DASHCAM_ROOT_STORAGE/$BVDATE/rear
    fi

    count=$(ping -c4 $1 | grep 'received' | awk -F',' '{ print $2}' | awk '{ print $1}')

    if [ $count -eq 4 ]; then
        echo "Successful connection! for " $1
        for file in `curl http://$1/blackvue_vod.cgi | sed 's/^n://' | sed 's/F.mp4//' | sed 's/R.mp4//' | sed 's/,s:1000000//' | sed $'s/\r//' | grep $2`; do
            wget -P $DASHCAM_ROOT_STORAGE/$2/$3 -c http://$1$file\F.mp4;
            wget -P $DASHCAM_ROOT_STORAGE/$2/$3 -c http://$1$file\R.mp4;
            wget -P $DASHCAM_ROOT_STORAGE/$2/$3 -nc http://$1$file\F.thm;
            wget -P $DASHCAM_ROOT_STORAGE/$2/$3 -nc http://$1$file\R.thm;
wget -P $DASHCAM_ROOT_STORAGE/$2/$3 -nc http://$1$file.gps;
            wget -P $DASHCAM_ROOT_STORAGE/$2/$3 -nc http://$1$file.3gf;
        done
    fi

}

#Set this one off into the background so we can do both cameras at the sametime.
downloadSpecifiedFileDates $DASHCAM_FRONT_IP $YESTERDAYDATE front
downloadSpecifiedFileDates $DASHCAM_FRONT_IP $BVDATE front

#downloadSpecifiedFileDates $DASHCAM_REAR_IP $YESTERDAYDATE rear
#downloadSpecifiedFileDates $DASHCAN_REAR_IP $BVDATE rear

exit 0
