#!/bin/sh

#--------------------------------------------------------------------
# This script installs all necessary configuration
# files as required to upload images to the PhenoCam server
# (phenocam.sr.unh.edu) on your NetCam SC/XL camera
#
# NOTES: this program can be used stand alone or called remotely
# as is done in the PIT.sh script. The script
# will pull all installation files from a server and adjust the
# settings on the NetCam accordingly.
#
# Koen Hufkens (January 2014) koen.hufkens@gmail.com
#--------------------------------------------------------------------

# -------------- BASIC ERROR TRAPS-----------------------------------

if [ "$#" = "1" ]; then
	if [ "$1" = "reset" ]; then
		# reset video settings to factory default
		default_video=`ls /etc/default/video0.conf* | awk -v p=1 'NR==p'`
		echo "reset video default parameters"
	
		# dump video configuration to /dev/video/config0
		# device to adjust in memory settings
		nrfiles=`cat $default_video | awk 'END {print NR}'`

		for i in `seq 1 $nrfiles` ;
		do
				cat $default_video | awk -v p=$i 'NR==p' > /dev/video/config0
		done
		
		# copy to config folder / otherwise they won't show up on the
		# webpage, save to flash to keep after reboot
		cp $default_video /etc/config/video0.conf
		config save
		
		exit 0
	else
		echo "Wrong parameter, use reset to reset the video settings!"
		exit 0
	fi
fi

if [ "$#" != "6" ]; then
	echo "Not enough parameters, please check your inputs!"
	exit 0
fi

# -------------- SETTINGS -------------------------------------------

# get todays date
TODAY=`date +"%Y_%m_%d_%H%M%S"`

# set the new camera name / could be the same if the camera
# has not moved, or did not get a new function
NEW_CAMERA_NAME=$1

# The time offset of your camera position relative to UTC time
# as specified in + or - XYZ hours
TIMEOFFSET=$2

# set local time zone string if available, otherwise default to LOCAL
if [ -n "$3" ]; then
    LOCALTZ=$3
else
    LOCALTZ="LOCAL"
fi

# set crontab start and end times default
# to 4 and 22 if not provided, set interval
# to 30 min

if [ -n "$4" ]; then
    CRONSTART=$4
else
    CRONSTART="4"
fi

if [ -n "$5" ]; then
    CRONEND=$5
else
    CRONEND="22"
fi

if [ -n "$6" ]; then
    CRONINT=$6
else
    CRONINT="30"
fi

# upload / download server - location from which to grab and
# and where to put config files
HOST='klima.sr.unh.edu'
USER='anonymous'
PASSWD='anonymous'

# make sure we are in the config directory
# before proceeding
cd /etc/config

# -------------- BACKUP OLD CONFIG ----------------------------------

echo ""
echo "#--------------------------------------------------------------------"
echo "#"
echo "# Backing up settings for $NEW_CAMERA_NAME !"
echo "#"
echo "#--------------------------------------------------------------------"
echo ""


# In order to keep track of all the state changes of the camera
# we will upload the current camera configuration to the server.

# remove previous zip files
if [ -f $NEW_CAMERA_NAME\_backup_settings\_$TODAY.tar.gz ]; then
	rm $NEW_CAMERA_NAME\_backup_settings\_$TODAY.tar.gz
fi

# archive all settings
tar -cf $NEW_CAMERA_NAME\_backup_settings\_$TODAY.tar *.conf *.scr

# zip stuff
gzip $NEW_CAMERA_NAME\_backup_settings\_$TODAY.tar

ftp -n << EOF
	open $HOST
	user $USER $PASSWD
	cd data/$1
	binary
	put $NEW_CAMERA_NAME\_backup_settings\_$TODAY.tar.gz
	bye
EOF

# delete uploaded tar archive
rm $NEW_CAMERA_NAME\_backup_settings\_$TODAY.tar.gz

# -------------- DOWNLOAD CONFIG FILES ------------------------------

# download the config files from a server
# using the netcam's ftp function (headless)
# no user input required

# check if default_* files are there
# if so do not download them again
if [ ! -f default_ftp.scr ]; then

echo ""
echo "#--------------------------------------------------------------------"
echo "#"
echo "# Downloading settings from $HOST !"
echo "#"
echo "#--------------------------------------------------------------------"
echo ""

# remove previous install files
if [ -f phenocam_default_install.tar* ]; then
	rm phenocam_default_install.tar*
fi

wget http://$HOST/data/configs/phenocam_default_install.tar.gz

gunzip phenocam_default_install.tar.gz
tar -xvf phenocam_default_install.tar
rm phenocam_default_install.tar

fi

# -------------- SET CAMERA NAME ------------------------------------

# NOTE!! : The system doesn't do well when overwriting the original files
# using sed / awk, always use a tmp file. This is the reason for
# moving the files from the default_ uploaded ones to the final
# correct file names. It makes tracing errors more easy as well.

# grab camera info and make sure it is an IR camera
MODEL=`info | grep "NetCamSC" | cut -d'=' -f2`
IR=`status | grep IR | tail -c 2`

if [ "$MODEL" = "NetCamSC" ]; then
	if [ "$IR" = "1" ]; then
	MODELNAME="NetCam SC IR"
	else
	MODELNAME="NetCam SC"
	fi
else
	MODELNAME="NetCam XL"
fi

# set proper camera names in all config files
# and upload scripts
cat default_overlay0.conf	| sed "s/mycamera/$NEW_CAMERA_NAME/g" | sed "s/netcammodel/$MODELNAME/g" | sed "s/LOCAL/$LOCALTZ/g" > bak_overlay0.conf
cat default_ftp.scr 		| sed "s/mycamera/$NEW_CAMERA_NAME/g" > ftp.scr
cat default_IR_ftp.scr 		| sed "s/mycamera/$NEW_CAMERA_NAME/g" > IR_ftp.scr
cat default_IP_ftp.scr 		| sed "s/mycamera/$NEW_CAMERA_NAME/g" > IP_ftp.scr

# rewrite everything into new files, just to be sure
cat default_video0.conf > video0.conf
cat default_ntp.server 	> ntp.server
cat default_sched0.conf > sched0.conf

# remove all default files
rm default_*

echo ""
echo "#--------------------------------------------------------------------"
echo "#"
echo "# Adjusting setting files !"
echo "#"
echo "#--------------------------------------------------------------------"
echo ""

# -------------- APPLY NEW CONFIGURATION ----------------------------

# set time zone
# dump setting to config file
SIGN=`echo $TIMEOFFSET | cut -c'1'`

if [ "$SIGN" = "+" ]; then
	echo "UTC$TIMEOFFSET" | sed 's/+/-/g' > /etc/config/TZ
else
	echo "UTC$TIMEOFFSET" | sed 's/-/+/g' > /etc/config/TZ
fi

# export to current clock settings
export TZ=`cat /etc/config/TZ`

echo "# The camera clock is set to UTC$TIMEOFFSET"
echo "# validate this setting - set date/time shown below !!!"
date

# convert the sign from the UTC time zone TZ variable (for plotting in overlay)
if [ "$SIGN" = "+" ]; then
	TZONE=`echo "$TZ" | sed 's/-/+/g'`
else
	TZONE=`echo "$TZ" | sed 's/+/-/g'`
fi

# adjust overlay settings to reflect current time baseline (UTC)
cat bak_overlay0.conf  | sed "s/TZONE/$TZONE/g" > overlay0.conf

# check if the parameter is altered from factory default
# if so retain this parameter but alter all other settings
# this avoids resetting parameters on certain funky cameras
# which have been adjusted previously but might still benefit 
# from an update (e.g. having the meta-data pushed etc), while
# keeping all else constant. This avoids jumps in colour in the
# greenness time series. Data consistency prevails over cross site
# consistency.

# grab the first default video config file name. This should all be the
# same but the numbering might vary from system to system
default_video_settings=`ls /etc/default/video0.conf* | awk -v p=1 'NR==p'`

# which parameters should be evaluated and kept static if not 
# the factory defaults
parameters="exposure_grid blue red green" # haze saturation"

# get the colour balance setting from the camera
cbalance=`cat /dev/video/config0 | grep balance= | cut -d'=' -f2`

# If the colour balance is set to auto, use phenocam defaults,
# otherwise check and retain certain parameters.
# only check for previous settings if the colour balance is set
# to 0, if set to 1 we assume the camera is in factory mode or
# needs adjusting to the PhenoCam default settings
if [ "$cbalance" != "1" ]; then 
for i in $parameters; do
	
	# get factory, current and phenocam settings for the parameter
	factory=`cat $default_video_settings | grep $i=`
	current=`cat /dev/video/config0 | grep $i=`
	phenocam=`cat video0.conf | grep $i=`

	if [ "$factory" != "$current" ];then
		cat video0.conf | sed -e s/"$phenocam"/"$current"/g > tmp.conf
		echo "# We retain the old $i settings!"
		# overwrite the PhenoCam default settings with those
		# preserving the old exposure grid
		mv tmp.conf video0.conf
	fi
done
else
echo "colour balance settings are the factory default, overwriting"
fi
echo "# [do a factory reset if this an old camera but you prefer default settings]"

# dump video configuration to /dev/video/config0
# device to adjust in memory settings
nrfiles=`awk 'END {print NR}' video0.conf`

for i in `seq 1 $nrfiles` ;
do
 # assign a shell variable to a awk parameter with
 # the -v statement
 awk -v p=$i 'NR==p' video0.conf > /dev/video/config0
done

# dump overlay configuration to /dev/video/config0
# device to adjust in memory settings
nrfiles=`awk 'END {print NR}' overlay0.conf`

for i in `seq 1 $nrfiles` ;
do
 # assign a shell variable to a awk parameter with
 # the -v statement
 awk -v p=$i 'NR==p' overlay0.conf > /dev/video/config0
done

# cycle the clocks settings by calling the rc script
# which governs NTP settings
rc.ntpdate

# -------------- SET SCHEDULED UPLOADS -------------------------------

# set the cron job
# this job calls the phenocam_upload.sh script and
# upload a RGB and IR picture (if available) to the
# phenocam servers

echo ""
echo "#--------------------------------------------------------------------"
echo "#"
echo "# Setting a crontab for timed uploads to the PhenoCam network !"
echo "#"
echo "#--------------------------------------------------------------------"
echo ""

# grap the default settings
cat /etc/default/crontab > crontab

# append the custom line
echo "*/$CRONINT $CRONSTART-$CRONEND * * * admin sh /etc/config/phenocam_upload.sh" >> crontab
echo "59 11 * * * admin sh /etc/config/phenocam_ip_table.sh" >> crontab

# -------------- SAVE CONFIG / UPLOAD TEST IMATES -----------------------

echo ""
echo "#--------------------------------------------------------------------"
echo "#"
echo "# Saving config files to flash memory / uploading test images !"
echo "#"
echo "#--------------------------------------------------------------------"
echo ""

# !!!! MOST IMPORTANT, SAVE CONFIG TO FLASH !!!!
config save

# uploading first images, testing the upload procedure
echo "Uploading the first images as a test... (wait 2min)"
sh phenocam_upload.sh

echo "Uploading the ip table"
sh phenocam_ip_table.sh

echo ""
echo "#--------------------------------------------------------------------"
echo "#"
echo "# Done !!! - close the terminal if it remains open !"
echo "#"
echo "#--------------------------------------------------------------------"
echo ""

exit 0