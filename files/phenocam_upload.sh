#!/bin/sh

#--------------------------------------------------------------------
# This script is cued up in the crontab file and called every
# x min to upload two images, a standard RGB image and an infra-
# red (IR) image (if available) to the PhenoCam server.
#
# last updated and maintained by:
# Koen Hufkens (Januari 2014) koen.hufkens@gmail.com
#--------------------------------------------------------------------

# -------------- SUBROUTINES -----------------------------------------

# seems like the bourne shell on the Stardots does NOT support 
# subroutines!

# -------------- SETTINGS -------------------------------------------

# make sure we are in the right directory
cd /etc/config

# export to current clock settings
export TZ=`cat /etc/config/TZ`

# switch time zone sign
if [ -n `echo $TZ | grep -` ]; then
	TZONE=`echo "$TZ" | sed 's/+/-/g'`
else
	TZONE=`echo "$TZ" | sed 's/-/+/g'`
fi

# config device (contains all settings and changing state variables)
CONFIG="/dev/video/config0"

# sets the delay between the
# RGB and IR image acquisitions
DELAY=30

# sets debug state, for script development only
# operational value is 0
DEBUG=1
if [ "$DEBUG" = "1" ] ; then
LOG="/var/tmp/IR_upload.log"
rm -f $LOG > /dev/null
else
LOG="/dev/null"
fi

# how many servers do we upload to
nrservers=`awk 'END {print NR}' server.txt`
	
# -------------- UPLOAD IMAGES --------------------------------------

# grab camera info and make sure it is an IR camera
IR=`status | grep IR |  awk -F'IR:' '{print $2}' | cut -d' ' -f1`

# grab camera temperature from memory put it into
# variable TEMP
TEMP=`/bin/mbus -td2 /dev/ds1629 w 0xee w 0xaa,0 r 2 | awk '{ C = and(rshift($1, 7), 0x1ff); if (and(C, 0x100)) C = C - 0x200; C /= 2; printf("%.1f\n", C); }'`

# grab date - keep fixed for RGB and IR uploads
DATE=`date +"%a %b %d %Y %H:%M:%S"`

# grap date and time string to be inserted into the
# ftp scripts - this coordinates the time stamps
# between the RGB and IR images (otherwise there is a
# slight offset due to the time needed to adjust exposure
DATETIMESTRING=`date +"%Y_%m_%d_%H%M%S"`

# grab date and time for `.meta` files
METADATETIME=`date -Iseconds`

# substitute the values in the ftp.scr and IR_ftp.scr
# upload scripts
cat IR_ftp.scr | sed "s/DATETIMESTRING/$DATETIMESTRING/g" > IR_ftp_tmp.scr

# The following few lines updates the time in the overlay
# should time changes have occured it will show up in the
# overlay!! -- this prevents this error

# The following line dumps the current time in the correct format
# to an overlay0_tmp.conf file
cat current_overlay0.conf  | sed "s/TZONE/$TZONE/g" | sed "s/%a %b %d %Y  %H:%M:%S/$DATE/g" | sed "s/\${IC}/$TEMP/g" > overlay0_tmp.conf

# grab metadata using the metadata function
# grab the MAC address
mac_addr=`ifconfig | grep HWaddr | awk '{print $5}' | sed 's/://g'`

# grab internal ip address
ip_addr=`ifconfig eth0 | awk '/inet addr/{print substr($2,6)}'`

# grab external ip address if there is an external connection
# first test the connection to the google name server
connection=`ping -q -c 1 8.8.8.8 > /dev/null && echo ok || echo error`

# if it's a NetCamSC model make an additional IR picture
# if not just take an RGB picture
if [ "$IR" = "1" ]; then

	# some feedback
	echo "Uploading RGB Image"

	# just in case, set IR to 0
	echo "ir_enable=0" > $CONFIG
	sleep $DELAY # adjust exposure

	# grab metadata
	cat /dev/video/config0 > /etc/config/metadata.txt

	# colate everything
	echo "ip_addr=$ip_addr" >> /etc/config/metadata.txt
	#echo "ip_ext_addr=$ip_ext_addr" >> /etc/config/metadata.txt
	echo "mac_addr=$mac_addr" >> /etc/config/metadata.txt
	echo "datetime_original=\"$METADATETIME\"" >> /etc/config/metadata.txt

	# dump overlay configuration to /dev/video/config0
	# device to adjust in memory settings
	# first grab the number of lines in the overlay0_tmp.conf
	# file, then write line by line to the video device
	nrlines=`awk 'END {print NR}' overlay0_tmp.conf`

	for i in `seq 1 $nrlines` ;
	do
	 awk -v p=$i 'NR==p' overlay0_tmp.conf > /dev/video/config0
	done

	# run the upload script With RGB enabled (default)
	# dump overlay configuration to /dev/video/config0
	# device to adjust in memory settings

	for i in `seq 1 $nrservers` ;
	do
		#changed following lines for different RGB ftp paths EWK
		#SERVER=`awk -v p=$i 'NR==p' server.txt` 
		#cat ftp.scr | sed "s/DATETIMESTRING/$DATETIMESTRING/g" | sed "s/SERVER/$SERVER/g" > ftp_tmp.scr
		USERNAME=`awk -v p=$i 'NR==p' server.txt | awk 'BEGIN {FS= "[:@/]";} {print$1}'`
		PASWRD=`awk -v p=$i 'NR==p' server.txt | awk 'BEGIN {FS= "[:@/]";} {print$2}'`
		SERVER=`awk -v p=$i 'NR==p' server.txt | awk 'BEGIN {FS= "[:@/]";} {print$3}'`
		DATAPTH=`awk -v p=$i 'NR==p' server.txt | awk -F: 'BEGIN {FS= "[:@/]";} { st = index($0,"/");print substr($0,st+1)}'`

		echo $USERNAME
		echo $PASWRD
		echo $SERVER
		echo $DATAPTH

		cat ftp.scr | sed "s/DATETIMESTRING/$DATETIMESTRING/g" | sed "s/SERVER/$SERVER/g" | sed "s/USERNAME/$USERNAME/g" | sed "s/PASWRD/$PASWRD/g" | sed "s/DATAPTH/$DATAPTH/g" > ftp_tmp.scr
 		#end edits EWK
		
		ftpscript ftp_tmp.scr >> $LOG
	done
	
	rm /etc/config/metadata.txt

	# some feedback
	echo "Uploading IR Image"

	# change the settings to enable IR image acquisition
	echo "ir_enable=1" > $CONFIG
	sleep $DELAY	# adjust exposure

	# grab metadata
	cat /dev/video/config0 > /etc/config/metadata.txt

	# colate everything
	echo "ip_addr=$ip_addr" >> /etc/config/metadata.txt
	#echo "ip_ext_addr=$ip_ext_addr" >> /etc/config/metadata.txt
	echo "mac_addr=$mac_addr" >> /etc/config/metadata.txt
	echo "datetime_original=\"$METADATETIME\"" >> /etc/config/metadata.txt

	# dump overlay configuration to /dev/video/config0
	# device to adjust in memory settings
	# first grab the number of lines in the overlay0_tmp.conf
	# file, then write line by line to the video device
	nrlines=`awk 'END {print NR}' overlay0_tmp.conf`

	for i in `seq 1 $nrlines` ;
	do
	 awk -v p=$i 'NR==p' overlay0_tmp.conf > /dev/video/config0
	done

	# run the upload script With IR enabled for all servers
	for i in `seq 1 $nrservers` ;
	do
		#changed following lines for different IR ftp paths EWK
		#SERVER=`awk -v p=$i 'NR==p' server.txt` 
		#cat IR_ftp.scr | sed "s/DATETIMESTRING/$DATETIMESTRING/g" | sed "s/SERVER/$SERVER/g" > IR_ftp_tmp.scr
		USERNAME=`awk -v p=$i 'NR==p' server.txt | awk 'BEGIN {FS= "[:@/]";} {print$1}'`
		PASWRD=`awk -v p=$i 'NR==p' server.txt | awk 'BEGIN {FS= "[:@/]";} {print$2}'`
		SERVER=`awk -v p=$i 'NR==p' server.txt | awk 'BEGIN {FS= "[:@/]";} {print$3}'`
		DATAPTH=`awk -v p=$i 'NR==p' server.txt | awk -F: 'BEGIN {FS= "[:@/]";} { st = index($0,"/");print substr($0,st+1)}'`

		echo $USERNAME
		echo $PASWRD
		echo $SERVER
		echo $DATAPTH

		cat IR_ftp.scr | sed "s/DATETIMESTRING/$DATETIMESTRING/g" | sed "s/SERVER/$SERVER/g" | sed "s/USERNAME/$USERNAME/g" | sed "s/PASWRD/$PASWRD/g" | sed "s/DATAPTH/$DATAPTH/g" > IR_ftp_tmp.scr
 		#end edits EWK
 		ftpscript IR_ftp_tmp.scr >> $LOG
	done
	
	# Reset the configuration to 
	# the default RGB settings
	echo "ir_enable=0" > $CONFIG

	# clean up temporary files
	rm /etc/config/metadata.txt
	rm ftp_tmp.scr
	rm IR_ftp_tmp.scr

else

	# some feedback
	echo "Uploading RGB Image"

	# just in case, set IR to 0
	echo "ir_enable=0" > $CONFIG
	sleep $DELAY # adjust exposure

	# grab metadata
	cat /dev/video/config0 > /etc/config/metadata.txt

	# colate everything
	echo "ip_addr=$ip_addr" >> /etc/config/metadata.txt
	#echo "ip_ext_addr=$ip_ext_addr" >> /etc/config/metadata.txt
	echo "mac_addr=$mac_addr" >> /etc/config/metadata.txt
	echo "datetime_original=\"$METADATETIME\"" >> /etc/config/metadata.txt

	# dump overlay configuration to /dev/video/config0
	# device to adjust in memory settings
	nrlines=`awk 'END {print NR}' overlay0_tmp.conf`

	for i in `seq 1 $nrservers` ;
	do
	 awk -v p=$i 'NR==p' overlay0_tmp.conf > /dev/video/config0
	done

	# cycle over all servers and upload the data
	for i in `seq 1 $nrservers` ;
	do
		#changed following lines for different RGB ftp paths EWK
		#SERVER=`awk -v p=$i 'NR==p' server.txt` 
		#cat ftp.scr | sed "s/DATETIMESTRING/$DATETIMESTRING/g" | sed "s/SERVER/$SERVER/g" > ftp_tmp.scr
		USERNAME=`awk -v p=$i 'NR==p' server.txt | awk 'BEGIN {FS= "[:@/]";} {print$1}'`
		PASWRD=`awk -v p=$i 'NR==p' server.txt | awk 'BEGIN {FS= "[:@/]";} {print$2}'`
		SERVER=`awk -v p=$i 'NR==p' server.txt | awk 'BEGIN {FS= "[:@/]";} {print$3}'`
		DATAPTH=`awk -v p=$i 'NR==p' server.txt | awk -F: 'BEGIN {FS= "[:@/]";} { st = index($0,"/");print substr($0,st+1)}'`

		echo $USERNAME
		echo $PASWRD
		echo $SERVER
		echo $DATAPTH

		cat ftp.scr | sed "s/DATETIMESTRING/$DATETIMESTRING/g" | sed "s/SERVER/$SERVER/g" | sed "s/USERNAME/$USERNAME/g" | sed "s/PASWRD/$PASWRD/g" | sed "s/DATAPTH/$DATAPTH/g" > ftp_tmp.scr
 		#end edits EWK
 		ftpscript ftp_tmp.scr >> $LOG
	done

	# clean up temporary files
	rm /etc/config/metadata.txt
	rm ftp_tmp.scr
fi

# restore overlay with auto update for online viewing
nrfiles=`awk 'END {print NR}' overlay0.conf`

for i in `seq 1 $nrfiles` ;
do
 awk -v p=$i 'NR==p' overlay0.conf > /dev/video/config0
done

# clean up shared (between setup) temporary files
rm overlay0_tmp.conf

# Reset the configuration to 
# the default RGB settings (just in case it's stuck at IR)
echo "ir_enable=0" > $CONFIG

exit
