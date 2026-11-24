#! /bin/bash
# Resolve the repo directory before any later cd. The clone does not
# have to live in ~/winlink-configuration.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Escape \, &, and | for a sed replacement that uses | as the delimiter.
# User text such as a Winlink password is otherwise able to abort sed
# or to be expanded as the matched text (&).
sed_repl() {
  printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

# Escape text that will be written into an XML text node.
# Use sed rather than ${var//pat/repl}: in bash, & in that replacement
# means the matched text, so "&lt;" would be written as "<lt;".
xml_text() {
  printf '%s' "$1" | sed \
    -e 's/&/\&amp;/g' \
    -e 's/</\&lt;/g' \
    -e 's/>/\&gt;/g'
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

if [[ "$(id -u)" -eq 0 ]]; then
  echo "Run this script as the gateway account, not as root or with sudo."
  exit 1
fi

# Update system if needed
echo "Make sure packages are up to date. Remove anything no longer needed"
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y

# Get packages required to build direwolf
echo "Installing packages required to compile and configure direwolf"
sudo apt install git git-lfs build-essential cmake libasound2-dev libudev-dev libavahi-client-dev alsa-utils libgps-dev libhamlib-dev -y

# Get packages required for AX.25
echo "Installing packages required for AX.25 functionality"
sudo apt install ax25-apps ax25-tools ax25-xtools libax25 libax25-dev -y

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
./autogen.sh
./configure
make -j2
sudo make install
clear

echo "Creating symbolic link /etc/rmsgw to point to /usr/local/etc/rmsgw"
sudo ln -s /usr/local/etc/rmsgw /etc/rmsgw
cd "$SCRIPT_DIR"

# Get User to answer some basic questions
echo "In order to properly configure this Winlink Gateway please provide answers to the following questions:"
read -rp "Enter your callsign (e.g., NOCALL): " CALLSIGN
read -rp "Enter desired SSID for gateway: " SSID
read -rp "Enter your city: " CITY
read -rp "Enter your state (2‑letter): " STATE
read -rp "Enter your zip code : " ZIPCODE
read -rp "Enter your Maindenhead Grid Square (ex. AA00aa): " GRIDSQUARE
read -rp "Enter your email address: " EMAIL_ADDRESS
read -rp "Enter your node's frequency (ex. 144930000): " FREQUENCY
read -rp "Enter the radio PTT serial device [/dev/ttyUSB0]: " RADIO_DEVICE

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

# AX.25 callsigns are uppercase. Accept either "10" or "-10" for the SSID.
CALLSIGN="$(trim "$CALLSIGN")"
SSID="$(trim "$SSID")"
SSID="${SSID#-}"
CITY="$(trim "$CITY")"
STATE="$(trim "$STATE")"
ZIPCODE="$(trim "$ZIPCODE")"
GRIDSQUARE="$(trim "$GRIDSQUARE")"
EMAIL_ADDRESS="$(trim "$EMAIL_ADDRESS")"
FREQUENCY="$(trim "$FREQUENCY")"
RADIO_DEVICE="$(trim "$RADIO_DEVICE")"
if [[ -z "$RADIO_DEVICE" ]]; then
    RADIO_DEVICE="/dev/ttyUSB0"
fi
echo "Radio PTT serial device: ${RADIO_DEVICE}"
CALLSIGN="${CALLSIGN^^}"
STATE="${STATE^^}"

if [[ ! "$CALLSIGN" =~ ^[A-Z0-9]+$ ]]; then
    echo "Callsign must be letters and numbers only. Nothing was written."
    exit 1
fi
if [[ ! "$SSID" =~ ^[0-9]+$ ]] || (( 10#$SSID > 15 )); then
    echo "SSID must be a number from 0 to 15. Nothing was written."
    exit 1
fi

# Plain-text files (banner, gateway.conf, direwolf, ax25) and XML files
# need different escaping. XML entity escaping happens first so that a
# later sed escape of & does not turn &amp; back into the matched text.
CALLSIGN_SED="$(sed_repl "$CALLSIGN")"
SSID_SED="$(sed_repl "$SSID")"
CITY_SED="$(sed_repl "$CITY")"
STATE_SED="$(sed_repl "$STATE")"
GRID_SED="$(sed_repl "$GRIDSQUARE")"
FREQ_SED="$(sed_repl "$FREQUENCY")"
RADIO_DEVICE_SED="$(sed_repl "$RADIO_DEVICE")"
USER_SED="$(sed_repl "$USER")"
CITY_XML_SED="$(sed_repl "$(xml_text "$CITY")")"
STATE_XML_SED="$(sed_repl "$(xml_text "$STATE")")"
ZIP_XML_SED="$(sed_repl "$(xml_text "$ZIPCODE")")"
GRID_XML_SED="$(sed_repl "$(xml_text "$GRIDSQUARE")")"
EMAIL_XML_SED="$(sed_repl "$(xml_text "$EMAIL_ADDRESS")")"
PASSWORD_XML_SED="$(sed_repl "$(xml_text "$SYSOP_PASSWORD")")"

# copy the template configuration files to the necessary directories
echo "Copying template configuration files to proper locations"
sudo cp "$SCRIPT_DIR/supporting-files/usr/local/etc/rmsgw/channels.xml" /usr/local/etc/rmsgw/
sudo cp "$SCRIPT_DIR/supporting-files/usr/local/etc/rmsgw/banner" /usr/local/etc/rmsgw/
sudo cp "$SCRIPT_DIR/supporting-files/usr/local/etc/rmsgw/gateway.conf" /usr/local/etc/rmsgw/
sudo cp "$SCRIPT_DIR/supporting-files/usr/local/etc/rmsgw/sysop.xml" /usr/local/etc/rmsgw/
cp "$SCRIPT_DIR/supporting-files/home/direwolf.winlink.conf" "$HOME/"

# copy start and stop scripts to /usr/local/bin, then edit the installed copy
sudo cp "$SCRIPT_DIR/supporting-files/usr/local/bin/start.direwolf.winlink.sh" /usr/local/bin
sudo sed -i -e "s|NOUSER|${USER_SED}|g" /usr/local/bin/start.direwolf.winlink.sh
sudo chmod +x /usr/local/bin/start.direwolf.winlink.sh
sudo cp "$SCRIPT_DIR/supporting-files/usr/local/bin/stop.direwolf.winlink.sh" /usr/local/bin
sudo chmod +x /usr/local/bin/stop.direwolf.winlink.sh
sudo cp "$SCRIPT_DIR/supporting-files/usr/local/bin/start.rmsgw.winlink.sh" /usr/local/bin
sudo chmod +x /usr/local/bin/start.rmsgw.winlink.sh
sudo cp "$SCRIPT_DIR/supporting-files/usr/local/bin/rmsgw-status-update.sh" /usr/local/bin
sudo chmod +x /usr/local/bin/rmsgw-status-update.sh

# copy systemd service file to /etc/systemd/system, then edit the installed copy
sudo cp "$SCRIPT_DIR/supporting-files/etc/systemd/system/winlinkdw.service" /etc/systemd/system
sudo sed -i -e "s|NOUSER|${USER_SED}|g" /etc/systemd/system/winlinkdw.service

#enable the winlinkdw.service
sudo systemctl enable winlinkdw.service

# copy supporting ax25 configuration files to /etc/ax25
sudo cp "$SCRIPT_DIR/supporting-files/etc/ax25/axports" /etc/ax25
sudo cp "$SCRIPT_DIR/supporting-files/etc/ax25/ax25d.conf" /etc/ax25

# Modify configuration files with the received information
echo "Updating banner"
BANNER_FILE="/usr/local/etc/rmsgw/banner"
sudo sed -i \
-e "s|N0CALL|${CALLSIGN_SED}|g" \
-e "s|A-town|${CITY_SED}|g" \
-e "s|A-state/province|${STATE_SED}|g" \
"$BANNER_FILE"

echo "Updating channels.xml"
CHANNEL_FILE="/usr/local/etc/rmsgw/channels.xml"
sudo sed -i \
-e "s|<channel name=\"1\" type=\"ax25\" active=\"yes\">|<channel name=\"radio\" type=\"ax25\" active=\"yes\">|" \
-e "s|<basecall>N0CALL</basecall>|<basecall>${CALLSIGN_SED}</basecall>|" \
-e "s|<callsign>N0CALL-00</callsign>|<callsign>${CALLSIGN_SED}-${SSID_SED}</callsign>|" \
-e "s|<password>password</password>|<password>${PASSWORD_XML_SED}</password>|" \
-e "s|<gridsquare>AA00AA</gridsquare>|<gridsquare>${GRID_XML_SED}</gridsquare>|" \
-e "s|<frequency>144000000</frequency>|<frequency>${FREQ_SED}</frequency>|" \
"$CHANNEL_FILE"

echo "Updating gateway.conf"
GATEWAY_FILE="/usr/local/etc/rmsgw/gateway.conf"
sudo sed -i \
-e "s|GWCALL=N0CALL-00|GWCALL=${CALLSIGN_SED}-${SSID_SED}|" \
-e "s|GRIDSQUARE=AA00aa|GRIDSQUARE=${GRID_SED}|" \
"$GATEWAY_FILE"

echo "Updating sysop.xml"
SYSOP_FILE="/usr/local/etc/rmsgw/sysop.xml"
sudo sed -i \
-e "s|<Callsign></Callsign>|<Callsign>${CALLSIGN_SED}</Callsign>|" \
-e "s|<Password></Password>|<Password>${PASSWORD_XML_SED}</Password>|" \
-e "s|<GridSquare></GridSquare>|<GridSquare>${GRID_XML_SED}</GridSquare>|" \
-e "s|<City></City>|<City>${CITY_XML_SED}</City>|" \
-e "s|<State></State>|<State>${STATE_XML_SED}</State>|" \
-e "s|<PostalCode></PostalCode>|<PostalCode>${ZIP_XML_SED}</PostalCode>|" \
-e "s|<Email></Email>|<Email>${EMAIL_XML_SED}</Email>|" \
"$SYSOP_FILE"

# Update ax25 configuration here.
# NOUSER is on the ax25d.conf default line (the account rmsgw runs as).
# axports has no account name, only the gateway callsign-SSID.
echo "Updating ax25d.conf and axports with user's callsign"
AX25PORTS_FILE=/etc/ax25/axports
AX25DCONF_FILE=/etc/ax25/ax25d.conf
sudo sed -i \
-e "s|N0CALL-00|${CALLSIGN_SED}-${SSID_SED}|" \
"$AX25PORTS_FILE"

sudo sed -i \
-e "s|N0CALL-00|${CALLSIGN_SED}-${SSID_SED}|" \
-e "s|NOUSER|${USER_SED}|g" \
"$AX25DCONF_FILE"

# Update direwolf configuration here. MYCALL must include the SSID so it
# matches axports, ax25d, channels.xml, and gateway.conf.
echo "Updating direwolf.winlink.conf"
DIREWOLF_CONF_FILE="${HOME}/direwolf.winlink.conf"
sed -i \
-e "s|MYCALL N0CALL-00|MYCALL ${CALLSIGN_SED}-${SSID_SED}|" \
-e "s|PTT /dev/ttyUSB0 RTS|PTT ${RADIO_DEVICE_SED} RTS|" \
"$DIREWOLF_CONF_FILE"

echo "Installing RMS Gateway status cron job..."
# Install cron job: run at boot AND every 20 minutes
sudo tee /etc/cron.d/rmsgw-status-update >/dev/null <<EOF
*/20 * * * * root /usr/local/bin/rmsgw-status-update.sh
EOF

sudo chmod 644 /etc/cron.d/rmsgw-status-update

PLACEHOLDER_WARNINGS=0
warn_if_present() {
    local file="$1"
    local pattern="$2"
    if [[ ! -f "$file" ]]; then
        echo "WARNING: ${file} was not installed."
        PLACEHOLDER_WARNINGS=$((PLACEHOLDER_WARNINGS + 1))
        return
    fi
    if sudo grep -qF -- "$pattern" "$file"; then
        echo "WARNING: '${pattern}' was not replaced in ${file}"
        PLACEHOLDER_WARNINGS=$((PLACEHOLDER_WARNINGS + 1))
    fi
}

warn_if_present /usr/local/bin/start.direwolf.winlink.sh "NOUSER"
warn_if_present /etc/systemd/system/winlinkdw.service "NOUSER"
warn_if_present "$BANNER_FILE" "N0CALL"
warn_if_present "$BANNER_FILE" "A-town"
warn_if_present "$BANNER_FILE" "A-state/province"
warn_if_present "$CHANNEL_FILE" "<basecall>N0CALL</basecall>"
warn_if_present "$CHANNEL_FILE" "<callsign>N0CALL-00</callsign>"
warn_if_present "$CHANNEL_FILE" "<password>password</password>"
warn_if_present "$CHANNEL_FILE" "<gridsquare>AA00AA</gridsquare>"
warn_if_present "$CHANNEL_FILE" "<frequency>144000000</frequency>"
warn_if_present "$CHANNEL_FILE" "name=\"1\""
warn_if_present "$GATEWAY_FILE" "GWCALL=N0CALL-00"
warn_if_present "$GATEWAY_FILE" "GRIDSQUARE=AA00aa"
warn_if_present "$SYSOP_FILE" "<Callsign></Callsign>"
warn_if_present "$AX25PORTS_FILE" "N0CALL-00"
warn_if_present "$AX25DCONF_FILE" "N0CALL-00"
warn_if_present "$AX25DCONF_FILE" "NOUSER"
warn_if_present "$DIREWOLF_CONF_FILE" "N0CALL"
if [[ "$RADIO_DEVICE" != "/dev/ttyUSB0" ]]; then
    warn_if_present "$DIREWOLF_CONF_FILE" "PTT /dev/ttyUSB0 RTS"
fi

if (( PLACEHOLDER_WARNINGS > 0 )); then
    echo "Setup finished with ${PLACEHOLDER_WARNINGS} placeholder warning(s). Review the files above before rebooting."
else
    echo "Setup is complete."
fi
echo "type \"sudo reboot\" to reboot the computer."
