#!/bin/bash

# Immediately exit if a command run from a loop, a pipeline or a compound
# command statement fails or a variable is used unset.
set -e


################################################################################
# Configuration - please adapt it to your environment
################################################################################

# Mattermost path
mattermostdir="/home/$USER/mattermost"

# Backup path
backupdir="/home/$USER/mattermost-backup"

# Temporary path for download
downloaddir="/home/$USER/tmp"

# Specify the edition you use
edition="Team"
#edition="Enterprise"

# Start with plugins? Set 1 for starting with plugins active
plugins=1

################################################################################

# Check dependencies
if ! type "systemctl" >/dev/null 2>&1 && ! type "service" >/dev/null 2>&1 && ! type "supervisorctl" >/dev/null 2>&1; then
     echo "[-] The daemon manager (systemd, sysvinit or supervisorctl) is not accessible. Aborted."
     exit 1
fi

if ! type "wget" >/dev/null 2>&1 && ! type "curl" >/dev/null 2>&1; then
     echo "[-] A download tool like wget or curl is not accessible. Aborted."
     exit 1
fi

# Check requirements
if [[ "${edition}" != "Team" ]] && [[ "${edition}" != "Enterprise" ]]; then
     echo "[-] The edition must either be \"Team\" or \"Enterprise\". Aborted."
     exit 1
fi

# Check config variables
if [ ! -d "$mattermostdir" ];  then
     echo "Mattermost directory not found. Please check config"
     exit 1
fi

if [ ! -d "$downloaddir" ];  then
     echo "Download directory not found. Please check config"
     exit 1
fi

if [ ! -d "$backupdir" ];  then
     echo "Backup directory not found. Please check config"
     exit 1
fi

# Check if Mattermost exists in the path provided above
if [ ! -f "${mattermostdir}/bin/mattermost" ];  then
     echo "Mattermost not found please check the path for the Mattermost directory"
     exit 1
fi

# Get version from argument
if [ -z "${1}" ]; then
     echo "Please specify the version of Mattermost to download"
     exit 1
fi
version="${1}"

# Ask to clean backup dir
read -r -p "[?] Do you want to clean backup directory [Y/n] " input
case "$input" in
        [yY])
                echo "[+] Cleaning Backup directory..."
                rm -f "${backupdir}"/mattermost-backup-*.tar.gz
                ;;
        *)
                echo "[-] Skipping cleaning"
                ;;
esac


# Ask for backup
read -r -p "[?] Do you want to backup mattermost first? [Y/n] " input
case "$input" in
        [yY])
                echo "[+] Creating backup of Mattermost..."
                tar -czvf "${backupdir}/mattermost-backup-$(date +'%F-%H-%M').tar.gz" "${mattermostdir}" >/dev/null 2>&1
                echo "[+] Starting the update process of Mattermost..."
                ;;
        *)
                echo "[-] Skipping backup"
                ;;
esac

if [[ "${edition}" == "Team" ]]; then
     url="https://releases.mattermost.com/${version}/mattermost-team-${version}-linux-amd64.tar.gz"
else
     url="https://releases.mattermost.com/${version}/mattermost-${version}-linux-amd64.tar.gz"
fi

# Main

# Get the file
function get_the_file() {
     echo "[+] Downloading Mattermost ${edition} \"${version}\"..."
     if type "curl" >/dev/null 2>&1; then
             if ! curl -LC - "${url}" -o "${downloaddir}/mattermost-upgrade.tar.gz"; then
                     echo "[-] An issue occurred when downloading the Mattermost update package."
                     exit 1
             fi
     else
             if ! wget "${url}" -o "${downloaddir}/mattermost-upgrade.tar.gz"; then
                     echo "[-] An issue occurred when downloading the Mattermost update package."
                     exit 1
             fi
     fi

     echo "[+] The Mattermost update package has been downloaded with successful"
}

# Check previous download
if [ -e "${downloaddir}/mattermost-upgrade.tar.gz" ]; then
     read -r -p "[?] A previous download exists. Do you want to replace it by a new one? [Y/n " input

     case "$input" in
             [yY])
                     echo "[+] Remove previous download."
                     rm -rf "${downloaddir}/mattermost-upgrade.tar.gz"
                     get_the_file
                     ;;
     esac
else
     get_the_file
fi

echo "[+] Extracting Mattermost update package..."
mkdir -p "${downloaddir}/mattermost-upgrade"
tar -xf "${downloaddir}/mattermost-upgrade.tar.gz" -C "${downloaddir}/mattermost-upgrade/"

echo "[+] Stopping Mattermost service..."
if type supervisorctl >/dev/null 2>&1;  then
    supervisorctl stop mattermost >/dev/null 2>&1
elif type systemctl >/dev/null 2>&1;  then
     systemctl stop mattermost
else
     service mattermost stop
fi

if pgrep mattermost > /dev/null; then
     echo "[-] Mattermost is still running. Update not possible. Aborting..."
     rm -rf "${downloaddir}/mattermost-upgrade"
     rm -f "${downloaddir}/mattermost-upgrade.tar.gz"
     exit 1
fi

echo "[+] Preparing update..."
USER="$(stat -c '%U' ${mattermostdir}/bin/mattermost)"
GROUP="$(stat -c '%G' ${mattermostdir}/bin/mattermost)"
chown -hR "$USER":"$GROUP" "${downloaddir}/mattermost-upgrade/"


# Clean up Mattermost directory
find "${mattermostdir}" -mindepth 1 -maxdepth 1 -not \( -path "${mattermostdir}/config" -o -path "${mattermostdir}/logs" -o -path "${mattermostdir}/plugins" -o -path "${mattermostdir}/data" -o -path "${mattermostdir}/client" \) -exec rm -rf {} \;
find "${mattermostdir}/client" -mindepth 1 -maxdepth 1 -not \( -path "${mattermostdir}/client/plugins" \) -exec rm -rf {} \;


# Rename plugin directory
if [ "${plugins}" -eq 0 ];  then
     echo "[+] Renaming plugin folders..."
     if [ -d "${mattermostdir}/plugins/" ]; then
             mv "${mattermostdir}/plugins/" "${mattermostdir}/plugins~"
     fi
     if [ -d "${mattermostdir}/client/plugins/" ]; then
             mv "${mattermostdir}/client/plugins/" "${mattermostdir}/client/plugins~"
     fi
fi

echo "[+] Updating Mattermost..."
cp -an "${downloaddir}/mattermost-upgrade/mattermost/"* "${mattermostdir}"


echo "[+] Cleaning Mattermost temporary files..."
rm -rf "${downloaddir}/mattermost-upgrade/"
rm -f "${downloaddir}/mattermost-upgrade.gz"

#echo "[+] Allowing Mattermost to run on port 0-1023..."
#setcap cap_net_bind_service=+ep "${mattermostdir}/bin/mattermost"

echo "[+] Starting Mattermost service..."
if type supervisorctl >/dev/null 2>&1;  then
    supervisorctl start mattermost >/dev/null 2>&1
elif type systemctl >/dev/null 2>&1;  then
     systemctl start mattermost
else
     service mattermost start
fi

echo "[+] Mattermost updated with successful"

if [ "${plugins}" -eq 0 ];  then
     echo "*************************************************"
     echo "Dont forget to reactivate your plugins"
     echo "mv \"${mattermostdir}/plugins~\" \"${mattermostdir}/plugins\""
     echo "mv \"${mattermostdir}/client/plugins\" \"${mattermostdir}/client/plugins~\""
     echo "*************************************************"
fi
