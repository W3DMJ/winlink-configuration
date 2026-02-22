#!/bin/bash -x
# zero out old direwolf log file in case /run/ is full
truncate --size 0 /run/direwolf.log

# prioritize USB audio device
grep -i usb /proc/asound/cards > /dev/null 2>&1
if [ $? -eq 0 ]; then
   export ALSA_CARD=`grep -i usb /proc/asound/cards | head -1 | cut -c 2-2`
else
   export ALSA_CARD=0
fi
echo "ALSA_CARD:  $ALSA_CARD"

# create a custom direwolf conf file, based on detected ptt method
sudo cp /home/pi/direwolf.winlink.conf /run/direwolf.winlink.conf
exec direwolf -d t -d o -p -q d -t 0 -c /run/direwolf.winlink.conf |& grep --line-buffered -v PTT_METHOD > /home/pi/direwolf.log 
