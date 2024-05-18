#!/bin/bash
# crontab script to update the ip table
# for each site, for validation of uptime

# some feedback on the action
echo "uploading IP table"

# how many servers do we upload to
nrservers=`awk 'END {print NR}' server.txt`

# grab the name, date and IP of the camera
DATETIME=`date`
ZONE=` cat /etc/config/overlay0.conf | grep overlay_text | cut -d' ' -f18`
DATETIME=`echo $DATETIME | sed "s/UTC/$ZONE/g"`
IP=`ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
SITENAME=`cat /etc/config/overlay0.conf | grep overlay_text | cut -d' ' -f2`

# update the IP and time variables
cat site_ip.html | sed "s/DATETIME/$DATETIME/g" | sed "s/SITEIP/$IP/g" > $SITENAME\_ip.html

# run the upload script for the ip data
# and for all servers
for i in `seq 1 $nrservers` ;
do
	#Changes here for ftp paths EWK
	#SERVER=`awk -v p=$i 'NR==p' server.txt` 
	#cat IP_ftp.scr | sed "s/DATETIMESTRING/$DATETIMESTRING/g" | sed "s/SERVER/$SERVER/g" > IP_ftp_tmp.scr
		USERNAME=`awk -v p=$i 'NR==p' server.txt | awk 'BEGIN {FS= "[:@/]";} {print$1}'`
		PASWRD=`awk -v p=$i 'NR==p' server.txt | awk 'BEGIN {FS= "[:@/]";} {print$2}'`
		SERVER=`awk -v p=$i 'NR==p' server.txt | awk 'BEGIN {FS= "[:@/]";} {print$3}'`
		DATAPTH=`awk -v p=$i 'NR==p' server.txt | awk -F: 'BEGIN {FS= "[:@/]";} { st = index($0,"/");print substr($0,st+1)}'`

		echo $USERNAME
		echo $PASWRD
		echo $SERVER
		echo $DATAPTH

		cat IP_ftp.scr | sed "s/DATETIMESTRING/$DATETIMESTRING/g" | sed "s/SERVER/$SERVER/g" | sed "s/USERNAME/$USERNAME/g" | sed "s/PASWRD/$PASWRD/g" | sed "s/DATAPTH/$DATAPTH/g" > IP_ftp_tmp.scr
 		#end edits EWK
	
	ftpscript IP_ftp_tmp.scr >> /dev/null
done

# clean up
rm IP_ftp_tmp.scr
