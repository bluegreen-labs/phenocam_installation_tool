#!/bin/sh

#--------------------------------------------------------------------
# This script installs all necessary configuration
# files as required to upload images to the PhenoCam server
# (phenocam.nau.edu) on your NetCam SC/XL camera
#
# NOTES: this program can be used stand alone or called remotely
# as is done in the PIT.sh script. The script
# will pull all installation files from a server and adjust the
# settings on the NetCam accordingly.
#
# Koen Hufkens (May 2016) koen.hufkens@gmail.com
#--------------------------------------------------------------------

# -------------- BASIC ERROR TRAPS-----------------------------------

if [ "$#" -eq "1" ]; then
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

# feedback on default settings
if [ "$#" -eq "2" ]; then
	echo "Only a name and time zone are provided."
	echo "All other settings will be set to default settings."
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
echo "cron start time set to: ${CRONSTART}"

if [ -n "$5" ]; then
    CRONEND=$5
else
    CRONEND="22"
fi
echo "cron end time set to: ${CRONEND}"

if [ -n "$6" ]; then
    CRONINT=$6
else
    CRONINT="30"
fi
echo "cron interval set to: ${CRONINT}"

# set ftp mode to passive if "passive" is not specified
echo "setting FTP mode"
if [ -n "$7" ]; then
	if [ "$7" = "active" ]; then
                echo "Using default FTP mode (none/active)."
		FTPMODE=""
	elif [ "$7" = "passive" ]; then
                echo "Setting FTP mode to passive."
		FTPMODE="passive"
	else
		echo "Invalid option provided for FTP mode"
                echo "Setting FTP mode to passive."
		FTPMODE="passive"
	fi
else
        echo "Setting FTP mode to passive."
	FTPMODE="passive"
fi

# upload / download server - location from which to grab and
# and where to put config files
HOST='phenocam.nau.edu'
USER='anonymous'
PASSWD='anonymous'

# create default server list
# modified line for new server.txt format EWK
#echo $HOST > server.txt
echo -e "$USER:$PASSWD@$HOST/data\\/$NEW_CAMERA_NAME" > server.txt

# make sure we are in the config directory
# before proceeding
cd /etc/config

# overwrite default nameserver (DNS) with universal google DNS server
# if these settings are not correct subsequent calls to the server
# might fail
echo "setting name server to 8.8.8.8"
echo "nameserver 8.8.8.8" > resolv.conf

# check IPv4 network connectivity
if ping -q -c 1 8.8.8.8 >/dev/null; then
    echo "IPv4 is up"
else
    echo "IPv4 is down"
    echo "The camera doesn't seem to have access to the network!"
    echo "This is required to run the phenocam-installation-tool"
    echo "**** Trying to proceed without verifying network. ****"
fi

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

# gzip stuff
gzip $NEW_CAMERA_NAME\_backup_settings\_$TODAY.tar

ftp -n << EOF
	open $HOST
	user $USER $PASSWD
	$FTPMODE
	cd data/$NEW_CAMERA_NAME
	binary
	put $NEW_CAMERA_NAME\_backup_settings\_$TODAY.tar.gz
	bye
EOF

# delete uploaded tar archive
rm $NEW_CAMERA_NAME\_backup_settings\_$TODAY.*

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
echo "removing old installation files first"
if [ -f phenocam_default_install.tar* ]; then
	rm phenocam_default_install.tar*
fi

# download the installation files from the PhenoCam servers
echo "downloading new installation files from phenocam server"
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
MODEL=`status | grep Product | cut -d'/' -f3 | cut -d'-' -f1`
echo "Camera model found: ${MODEL}"

IR=`status | grep IR | sed -e 's#.*IR:\(\)#\1#' | cut -d' ' -f1`
echo "IR mode: ${IR}"

# new 3 / 5 MP models with or without IR
if [ "$MODEL" = "NetCamSC" ]; then
	if [ "$IR" = "1" ]; then
	MODELNAME="NetCam SC IR"
	else
	MODELNAME="NetCam SC"
	fi
fi

# HD 10 MP models with or without IR
if [ "$MODEL" = "NetCamSCX" ]; then
	if [ "$IR" = "1" ]; then
	MODELNAME="NetCam SCX IR"
	else
	MODELNAME="NetCam SCX"
	fi
fi

# legacy X model (rare)
if [ "$MODEL" = "NetCamXL" ]; then
	MODELNAME="NetCam XL"
fi

# set proper camera names in all config files
# and upload scripts
cat default_overlay0.conf	| sed "s/mycamera/$NEW_CAMERA_NAME/g" | sed "s/netcammodel/$MODELNAME/g" | sed "s/LOCAL/$LOCALTZ/g" > current_overlay0.conf
#cat default_ftp.scr 		| sed "s/mycamera/$NEW_CAMERA_NAME/g" | sed "s/FTPMODE/$FTPMODE/g" | sed "s/PASSWORD/$PASSWD/g" | sed "s/USER/$USER/g" > ftp.scr
#cat default_IR_ftp.scr 	| sed "s/mycamera/$NEW_CAMERA_NAME/g" | sed "s/FTPMODE/$FTPMODE/g" | sed "s/PASSWORD/$PASSWD/g" | sed "s/USER/$USER/g" > IR_ftp.scr
#cat default_IP_ftp.scr 	| sed "s/mycamera/$NEW_CAMERA_NAME/g" | sed "s/FTPMODE/$FTPMODE/g" | sed "s/PASSWORD/$PASSWD/g" | sed "s/USER/$USER/g" > IP_ftp.scr
cat default_ftp.scr 		| sed 's@data/mycamera@DATAPTH@' | sed "s/mycamera/$NEW_CAMERA_NAME/g" | sed "s/FTPMODE/$FTPMODE/g" | sed "s/PASSWORD/PASWRD/g" | sed "s/USER/USERNAME/g" > ftp.scr
cat default_IR_ftp.scr 		| sed 's@data/mycamera@DATAPTH@' | sed "s/mycamera/$NEW_CAMERA_NAME/g" | sed "s/FTPMODE/$FTPMODE/g" | sed "s/PASSWORD/PASWRD/g" | sed "s/USER/USERNAME/g" > IR_ftp.scr
cat default_IP_ftp.scr 		| sed 's@data/mycamera@DATAPTH@' | sed "s/mycamera/$NEW_CAMERA_NAME/g" | sed "s/FTPMODE/$FTPMODE/g" | sed "s/PASSWORD/PASWRD/g" | sed "s/USER/USERNAME/g" > IP_ftp.scr


# rewrite everything into new files, just to be sure
cat default_video0.conf > video0.conf
cat default_ntp.server 	> ntp.server
cat default_sched0.conf > sched0.conf

# remove all default files
# rm default_*

# set the links to the cgi scripts for pull requests
chmod +x metadata.cgi
chmod +x rgb.cgi
ln -s /etc/config/metadata.cgi /var/httpd/metadata.cgi
ln -s /etc/config/rgb.cgi /var/httpd/rgb.cgi

# copy the default start parameters into the config
# directory, add the soft links. The latter ensures
# that the pull cgi scripts are callable after reboot
cat /etc/default/start > start
echo "ln -s /etc/config/metadata.cgi /var/httpd/metadata.cgi" >> start
echo "ln -s /etc/config/rgb.cgi /var/httpd/rgb.cgi" >> start

# upload an image upon restart!
echo "configuring camera to upload image on restart"
echo "sh /etc/config/phenocam_upload.sh" >> start

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
cat current_overlay0.conf  | sed "s/TZONE/$TZONE/g" > overlay0.conf

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

# -------------- UPLOAD TEST IMATES ---------------------------

echo ""
echo "#--------------------------------------------------------------------"
echo "#"
echo "# Uploading test images !"
echo "#"
echo "#--------------------------------------------------------------------"
echo ""

# grab the default settings and overwrite the current one
# this disables upload process from starting while doing
# the test uploads
cat /etc/default/crontab > crontab

# uploading first images, testing the upload procedure
echo "Uploading the first images as a test... (wait 2min)"
sh phenocam_upload.sh

echo "Uploading the ip table"
sh phenocam_ip_table.sh

# -------------- SET SCHEDULED UPLOADS / SAVE CONFIG ---------------

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

# generate random number between 0 and the interval value
rnumber=`awk -v min=0 -v max=$CRONINT 'BEGIN{srand(); print int(min+rand()*(max-min+1))}'`

# divide 60 min by the interval
div=`echo "59 $CRONINT /" | dc`

int=`echo $div | cut -d'.' -f1`
rem=`echo $div | cut -d'.' -f2`

for i in `seq 0 $int`;do

	product=`echo "$CRONINT $i *" | dc`
	sum=`echo "$product $rnumber +" | dc`

	if [ "$i" = "0" ];then 
		interval=`echo $sum`
	else
		if [ "$sum" -le "59" ];then
		interval=`echo ${interval},${sum}`
		fi
	fi
done

echo "crontab intervals set to: $interval"

# append the custom lines to the default crontab
# as loaded in the previous section
echo "$interval $CRONSTART-$CRONEND * * * admin sh /etc/config/phenocam_upload.sh" >> crontab
echo "30 12 * * * admin sh /etc/config/phenocam_ip_table.sh" >> crontab

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!! MOST IMPORTANT, SAVE CONFIG TO FLASH !!!!
config save

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

echo ""
echo "#--------------------------------------------------------------------"
echo "#"
echo "# Done !!! - close the terminal if it remains open !"
echo "#"
echo "#--------------------------------------------------------------------"
echo ""

exit 0
