# winlink-configuration
Turn a Linux installation into a Winlink RMS Gateway
This has been developed and tested on Raspberry Pi4 and a Raspberry Pi Zero 2 W

Run the install script as the Linux account that should own the gateway. That account is written into the systemd service and ax25d configuration. The script calls sudo itself for the steps that need root.

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
