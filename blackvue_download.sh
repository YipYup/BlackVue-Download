#!/bin/sh

# Get the list of files
FILES=`curl -s http://10.99.77.1/blackvue_vod.cgi |grep "n:" |cut -c 11-32`

# Loop through them all
for f in ${FILES}; do

  # Make sure we haven't grabbed this one already
  if [ ! -f $f ]; then

    # Figure out the file type
    TYPE=`echo ${f} | cut -d"_" -f 3`

    # Types are E=Event, N=Normal, P=Parking, M=Manual
    # I only care about E (impacts, me tapping the camera to remember, etc...)
    if [ ${TYPE:0:1} == "E" ]; then

      # Download it!
      curl -sO http://10.99.77.1/Record/${f}
    fi
  fi
done
