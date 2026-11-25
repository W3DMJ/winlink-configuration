# Winlink Configuration Script
Turn a Linux installation into a Winlink RMS Gateway
This has been developed and tested on Raspberry Pi4 and a Raspberry Pi Zero 2 W but has been tested on an Orange Pi 5 Plus running Debian 13.8 for aarch64.

Run the install script as the Linux account that should own the gateway for example is the normal user is pi then login as pi. The account used to install will be written into the systemd service and ax25d configuration. 
Do not execute the install script using sudo. The script will make calls sudo itself when needed for the steps that need root access.

To keep from having difficulties later it is suggested that your password be something then the default ie "Raspberry" because the service will need the following:
If running Raspberry Pi OS and not using default user such as pi run the following in a terminal:
  'sudo usermod -aG sudo,dialout $USER'
then add the following line edit in the sudoers file by running 'sudo visudo' look for:
  "# Allow members of group sudo to execute any command
   %sudo   ALL=(ALL:ALL) ALL"
change to"
  "# Allow members of group sudo to execute any command
   %sudo   ALL=(ALL:ALL) NOPASSWD:ALL"

Save and Exit file

REMINDER: YOUR PASSWORD SHOULD BE SOMETHING OTHER THAN 'raspberry'.
IT IS REQUIRED TO ALLOW INTERNET CONNECTIVITY BUT DO NOT EXPOSE TO 
CONNECTIONS ORIGINATING FROM BEYOND YOUR FIREWALL BY OPENING UP FIREWALL PORTS OR RUNNING
OTHER PUBLIC FACING SERVICES ON THIS DEVICE.

For Debian other than Raspberry Pi OS you may need the following:
Execute 'su' and enter root's password.
Execute 'apt update && apt upgrade -y && apt autoremove -y'
Execute 'apt install sudo git git-lfs vim cmake build-essential python3-all python3-pip python3-setuptools python3-venv'
Execute 'usermod +aG sudo,dialout [YOUR USERNAME]'
Execute 'visudo'

Edit the following line edit in the sudoers file :
  "# Allow members of group sudo to execute any command
   %sudo   ALL=(ALL:ALL) ALL"
change to"
  "# Allow members of group sudo to execute any command
   %sudo   ALL=(ALL:ALL) NOPASSWD:ALL"
Save and Exit

REMINDER: YOUR PASSWORD SHOULD BE SOMETHING OTHER THAN 'raspberry'.
IT IS REQUIRED TO ALLOW INTERNET CONNECTIVITY BUT DO NOT EXPOSE TO 
CONNECTIONS ORIGINATING FROM BEYOND YOUR FIREWALL BY OPENING UP FIREWALL PORTS OR RUNNING
OTHER PUBLIC FACING SERVICES ON THIS DEVICE.

For both cases a reboot may be required.

# Pre-Installation
Log in to the Raspberry Pi as that account.
type: 'sudo apt update && apt install git -y' press enter

The installation script will take care of the reset of the packages.

# Installation
At a terminal type 'git clone https://github.com/W3DMJ/winlink-configuration.git'
- Change the directory to winlink-configuration by typing 'cd winlink-configuration' then press enter
- Add execution privileges to the install script by typing 'chmod +x ./install-required-packages.sh' then press enter
- Execute the script by typing './install-required-packages.sh' and press enter

The script will take time to install all of the required packages, download the necessary
repositories, compile the code, install the executables and configurations files. 

# Configuration
Once the system is ready to customize the winlink server for your callsign you will be asked
for the necessary information to configure the rmsgw software. Answer the questions. The script
will then complete the configuration and once complete will prompt you to type 'sudo reboot'

Once the Raspberry Pi has rebooted the Winlink RMS Gateway should be ready to accepts connection
if there is a radio connected. This configuration assumes one has connected a radio via a DigiRig Mobile.

# CRONTAB
If the job in the script does not run, open a terminal and type `sudo crontab -e`, then add this line. Root's crontab has no user field:

*/20 * * * * /usr/local/bin/rmsgw-status-update.sh

The above line will cause the following to occur every 20 minutes:
/usr/local/bin/rmsgw_aci
/etc/rmsgw/updatesysop.py
/etc/rmsgw/updatechannel.py

if the node remains listed but when connection attempts are made and the node does not answer, open a terminal and type 'sudo crontab -e' the press enter. Copy and paste the following line into the editor:

0 */3 * * * /usr/bin/systemctl restart winlinkdw.service

Running these commands should keep your node in the RMS List and on the RMS Map and responding to connection attempts.
