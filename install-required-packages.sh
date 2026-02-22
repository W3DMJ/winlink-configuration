#! /bin/bash
# Update system if needed
echo "Make sure packages are up to date. Remove anything no longer needed"
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y

# Get packages required to build direwolf
echo "Installing packages required to compile and configure direwolf"
sudo apt install git git-lfs build-essential cmake libasound2-dev libudev-dev libavahi-client-dev alsa-utils libgps-dev libhamlib-dev -y

# Get packages required for AX.25
echo "Installing packages required for AX.25 functionality"
sudo apt install ax25-apps ax25-tools ax25-xtools libax25 -y

# Setting up build environment
echo "Setting up build environment"
mkdir -p ~/Source/repos/amateur-radio-projects
cd ~/Source/repos/amateur-radio-projects

echo "Cloning Direwolf repo from github"
git clone --recursive https://github.com/wb2osz/direwolf.git

echo "Cloning RMSGW repo from github"
git clone --recursive https://github.com/W3DMJ/rmsgw.git

# Compile DIREWOLF first
echo "Building the direwolf executable and install the initial configuration files."
cd direwolf
mkdir build
cd build
cmake ..
make -j2
sudo make install
make install-conf

# Get packages required for rmsgw
echo "Installing packages required for RMSGW functionality"
sudo apt install xutils-dev libxml2 libxml2-dev libncurses5-dev python3-all python3-pip python3-venv python3-setuptools python3-requests autoconf -y
cd ~/Source/repos/amateur-radio-projects/rmsgw
git checkout fix-compile-errors
./autogen.sh
./configure
make -j2
sudo make install
clear

echo "Creating symbolic link /etc/rmsgw to point to /usr/local/etc/rmsgw"
sudo ln -s /usr/local/etc/rmsgw /etc/rmsgw

# Get User to answer some basic questions
echo "In order to properly configure this Winlink Gateway please provide answers to the following questions:"
read -rp "Enter your callsign (e.g., NOCALL): " CALLSIGN
read -rp "Enter your city: " CITY
read -rp "Enter your state (2‑letter): " STATE
read -rp "Enter your zip code : " ZIPCODE
read -rp "Enter your Maindenhead Grid Square (ex. AA00aa): " GRIDSQUARE
read -rp "Enter your email address: " EMAIL_ADDRESS
read -rp "Enter your node's frequency (ex. 144930000): " FREQUENCY

while true; do
    read -rsp "Enter your Winlink SYSOP Password: " SYSOP_PASSWORD
    echo
    read -rsp "Enter confirm your Winlink SYSOP Password: " SYSOP_PASSWORD_2
    echo

    if [[ "$SYSOP_PASSWORD" == "$SYSOP_PASSWORD_2" ]]; then 
        break 
    else 
        echo "Passwords do not match. Please try again." 
    fi
done

# copy the template configuration files to the necessary directories
echo "Copying template configuration files to proper locations"
sudo cp ~/winlink-configuration/supporting-files/usr/local/etc/rmsgw/channels.xml /usr/local/etc/rmsgw/
sudo cp ~/winlink-configuration/supporting-files/usr/local/etc/rmsgw/banner /usr/local/etc/rmsgw/
sudo cp ~/winlink-configuration/supporting-files/usr/local/etc/rmsgw/gateway.conf /usr/local/etc/rmsgw/
sudo cp ~/winlink-configuration/supporting-files/usr/local/etc/rmsgw/sysop.xml /usr/local/etc/rmsgw/
cp ~/winlink-configuration/supporting-files/home/pi/direwolf.winlink.conf ~/

# copy start and stop scripts to /usr/local/bin
sudo cp ~/winlink-configuration/supporting-file/usr/local/bin/start.direwolf.winlink.sh /usr/local/bin
sudo chmod +x /usr/local/bin/start.direwolf.winlink.sh
sudo cp ~/winlink-configuration/supporting-file/usr/local/bin/stop.direwolf.winlink.sh /usr/local/bin
sudo chmod +x /usr/local/bin/stop.direwolf.winlink.sh
sudo cp ~/winlink-configuration/supporting-file/usr/local/bin/start.rmsgw.winlink.sh /usr/local/bin
sudo chmod +x /usr/local/bin/start.rmsgw.winlink.sh

# copy systemd service file to /etc/systemd/service
sudo cp ~/winlink-configuration/supporting-files/etc/systemd/system/winlinkdw.service /etc/systemd/system
#enable the winlinkdw.service
sudo systemctl enable winlinkdw.service

# copy supporting ax25 configuration files to /etc/ax25
sudo cp ~/winlink-configuration/supporting-files/etc/ax25/axports /etc/ax25
sudo cp ~/winlink-configuration/supporting-files/etc/ax25/ax25d.conf /etc/ax25

# Modify configuration files with the recieve information
echo "Updating banner"
BANNER_FILE="/usr/local/etc/rmsgw/banner"
sudo sed -i \
-e "s/N0CALL/$CALLSIGN/g" \
-e "s/A-town/$CITY/g" \
-e "s/A-state\/province/$STATE/g" \
"$BANNER_FILE"

echo "Updating channels.xml"
CHANNEL_FILE="/usr/local/etc/rmsgw/channels.xml"
sudo sed -i \
-e "s|<channel name="radio" type="ax25" active="yes">|<channel name="1" type="ax25" active="yes">|" \
-e "s|<basecall>N0CALL</basecall>|<basecall>${CALLSIGN}</basecall>|" \
-e "s|<callsign>N0CALL-10</callsign>|<callsign>${CALLSIGN}-10</callsign>|" \
-e "s|<password>password</password>|<password>${SYSOP_PASSWORD}</password>|" \
-e "s|<gridsquare>AA00AA</gridsquare>|<gridsquare>${GRIDSQUARE}</gridsquare>|" \
-e "s|<frequency>144000000</frequency>|<frequency>${FREQUENCY}</frequency>|" \
"$CHANNEL_FILE"

echo "Updating gateway.conf"
GATEWAY_FILE="/usr/local/etc/rmsgw/gateway.conf"
sudo sed -i \
-e "s/N0CALL/"${CALLSIGN}-10"/g" \
-e "s/AA00aa/$GRIDSQUARE/g" \
"$GATEWAY_FILE"

echo "Updating sysop.xml"
SYSOP_FILE="/usr/local/etc/rmsgw/sysop.xml"
sudo sed -i \
-e "s|<Callsign></Callsign>|<Callsign>${CALLSIGN}</Callsign>|" \
-e "s|<Password></Password>|<Password>${SYSOP_PASSWORD}</Password>|" \
-e "s|<GridSquare></GridSquare>| <GridSquare>${GRIDSQUARE}</GridSquare>|" \
-e "s|<City></City>|<City>${CITY}</City>|" \
-e "s|<State></State>|<State>${STATE}</State>|" \
-e "s|<PostalCode></PostalCode>|<PostalCode>${ZIPCODE}</PostalCode>|" \
-e "s|<Email></Email>|<Email>${EMAIL_ADDRESS}</Email>|" \
"$SYSOP_FILE"

# Update ax25 configuration here
echo "Updating ax25d.conf and axports with user's callsign"
AX25PORTS_FILE=/etc/ax25/axports
AX25DCONF_FILE=/etc/ax25/ax25d.conf
sudo sed -i \
-e "s|N0CALL-10|${CALLSIGN}-10|" \
"$AX25PORTS_FILE"

sudo sed -i \
-e "s|N0CALL-10|${CALLSIGN}-10|" \
"$AX25DCONF_FILE"

# Update direwolf configuration here
echo "Updating direwolf.winlink.conf"
DIREWOLF_CONF_FILE="/home/pi/direwolf.winlink.conf"
sudo sed -i \
-e "s|N0CALL|${CALLSIGN}|" \
"$DIREWOLF_CONF_FILE"

echo "Installing RMS Gateway status cron job..."
# Create the status update script
sudo tee /usr/local/bin/rmsgw-status-update.sh >/dev/null <<EOF
#!/bin/bash
/usr/local/bin/rmsgw_aci
/etc/rmsgw/updatesysop.py
EOF

sudo chmod +x /usr/local/bin/rmsgw-status-update.sh

# Install cron job: run at boot AND every 20 minutes
sudo tee /etc/cron.d/rmsgw-status-update >/dev/null <<EOF
*/20 * * * * root /usr/local/bin/rmsgw-status-update.sh
EOF

sudo chmod 644 /etc/cron.d/rmsgw-status-update
# clear
echo "Setup is complete."
echo "type \"sudo reboot\" to reboot the computer."
