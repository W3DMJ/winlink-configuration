# Winlink Configuration Script

Turn a Linux installation into a Winlink RMS Gateway.

Tested on:

- Raspberry Pi 4 running Raspberry Pi OS
- Raspberry Pi Zero 2 W running Raspberry Pi OS
- Orange Pi 5 Plus running Debian 13.8 for aarch64

Run the install script as the Linux account that should own the gateway. If that account is `pi`, log in as `pi`. The account you use is written into the systemd service and the ax25d configuration.

Run the script as that user. The script calls `sudo` itself for the steps that need root.

## Account setup

The gateway account needs to be in the `sudo` and `dialout` groups, and members of `sudo` need to run commands without a password prompt.

Choose a password other than the default `raspberry`. The gateway needs Internet access. Keep inbound firewall ports closed, and do not run other public-facing services on this device.

A reboot may be required after the group and sudoers changes below.

### Raspberry Pi OS

If you are not using the default user (such as `pi`), add your account to the required groups:

```bash
sudo usermod -aG sudo,dialout $USER
```

Allow passwordless sudo:

```bash
sudo visudo
```

Find this block:

```
# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) ALL
```

Change the `%sudo` line so it reads:

```
# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) NOPASSWD:ALL
```

Save and exit.

### Debian (other than Raspberry Pi OS)

Become root, update the system, and install the packages the installer expects. Replace `YOUR_USERNAME` with the account that will own the gateway:

```bash
su
apt update && apt upgrade -y && apt autoremove -y
apt install sudo git git-lfs vim cmake build-essential python3-all python3-pip python3-setuptools python3-venv
usermod -aG sudo,dialout YOUR_USERNAME
visudo
```

In the sudoers file, change:

```
# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) ALL
```

to:

```
# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) NOPASSWD:ALL
```

Save and exit, then leave the root shell:

```bash
exit
```

## Pre-installation

Log in as the gateway account. If Git is not already installed:

```bash
sudo apt update && sudo apt install git -y
```

The install script installs the remaining packages.

## Installation

```bash
git clone https://github.com/W3DMJ/winlink-configuration.git
cd winlink-configuration
chmod +x ./install-required-packages.sh
./install-required-packages.sh
```

The script installs the required packages, downloads the repositories, compiles the code, and installs the executables and configuration files. This takes a while.

## Configuration

When the script is ready to customize the gateway for your callsign, it asks for the information needed to configure the rmsgw software. Answer the questions.

When configuration finishes, the script asks you to reboot:

```bash
sudo reboot
```

After the reboot, the Winlink RMS Gateway is ready to accept connections when a radio is attached. This configuration assumes the radio is connected with a DigiRig Mobile.

## Scheduled jobs

The installer schedules a status update every 20 minutes. If that job does not run, add it to root's crontab. Root's crontab has no user field.

```bash
sudo crontab -e
```

Add:

```
*/20 * * * * /usr/local/bin/rmsgw-status-update.sh
```

Every 20 minutes that script runs:

- `/usr/local/bin/rmsgw_aci`
- `/etc/rmsgw/updatesysop.py`
- `/etc/rmsgw/updatechannel.py`

If the node stays listed but does not answer connection attempts, add this line to the same root crontab. It restarts the gateway service every 3 hours:

```
0 */3 * * * /usr/bin/systemctl restart winlinkdw.service
```

These jobs keep the node on the RMS List and the RMS Map, and keep it responding to connection attempts.
