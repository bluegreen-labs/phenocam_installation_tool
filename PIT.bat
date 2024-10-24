::--------------------------------------------------------------------
:: This script installs all necessary configuration
:: files as required to upload images to the PhenoCam server
:: (phenocam.sr.unh.edu) on your NetCam SC/XL camera REMOTELY with
:: minimum interaction with the camera
::
:: last updated and maintained by:
:: Koen Hufkens (January 2014) koen.hufkens@gmail.com
::--------------------------------------------------------------------
@echo off

:: if the timezone is positive +
:: replace + with the escaped {+} character
set timezone=%5%
set timezone=%timezone:+={+}%

:: asign variable names
set ip=%1%
set login=%2%
set passwd=%3%
set name=%4%
set TZ=%6%
set cronstart=%7%
set cronend=%8%
set timestep=%9%
shift
set ftpmode=%9%

:: Create VBS script
echo set OBJECT=WScript.CreateObject("WScript.Shell") > sendCommands.vbs
echo WScript.sleep 500 >> sendCommands.vbs
echo OBJECT.SendKeys "%login%{ENTER}" >> sendCommands.vbs
echo WScript.sleep 500 >> sendCommands.vbs
echo OBJECT.SendKeys "%passwd%{ENTER}" >> sendCommands.vbs
echo WScript.sleep 500 >> sendCommands.vbs
echo OBJECT.SendKeys "cd /etc/config{ENTER}" >> sendCommands.vbs
echo WScript.sleep 500 >> sendCommands.vbs
echo OBJECT.SendKeys "wget http://gaia.agraria.unitus.it:89/phenocam_icos_install.tar.gz{ENTER}" >> sendCommands.vbs
echo WScript.sleep 1000 >> sendCommands.vbs
echo OBJECT.SendKeys "gunzip phenocam_icos_install.tar.gz{ENTER}" >> sendCommands.vbs
echo WScript.sleep 500 >> sendCommands.vbs
echo OBJECT.SendKeys "tar -xvf phenocam_icos_install.tar{ENTER}" >> sendCommands.vbs
echo WScript.sleep 500 >> sendCommands.vbs
echo OBJECT.SendKeys "rm phenocam_icos_install.tar{ENTER}" >> sendCommands.vbs
echo WScript.sleep 500 >> sendCommands.vbs
echo OBJECT.SendKeys "sh phenocam_install.sh %name% %timezone% %TZ% %cronstart% %cronend% %timestep% %ftpmode%{ENTER}" >> sendCommands.vbs
echo WScript.sleep 180000 >> sendCommands.vbs
echo OBJECT.SendKeys "exit{ENTER}" >> sendCommands.vbs
echo WScript.sleep 50 >> sendCommands.vbs
echo OBJECT.SendKeys " " >> sendCommands.vbs

:: Open a Telnet window
start telnet.exe %ip%

:: Run the script
cscript sendCommands.vbs

:: remove VBS script
del sendCommands.vbs

