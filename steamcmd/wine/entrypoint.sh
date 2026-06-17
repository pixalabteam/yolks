#!/bin/bash

# Wait for the container to fully initialize
sleep 1

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set tty width so wine console output does not prematurely wrap.
stty columns 250 2>/dev/null || true

echo "Running on Debian $(cat /etc/debian_version)"
wine --version

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

# Set default values for steam if not provided
STEAM_USER=${STEAM_USER:-anonymous}
if [ "${STEAM_USER}" == "anonymous" ]; then
	STEAM_PASS=""
	STEAM_AUTH=""
fi

## If AUTO_UPDATE is not set or is set to 1, run steamcmd to update the server
if [ -z "${AUTO_UPDATE}" ] || [ "${AUTO_UPDATE}" == "1" ]; then
	if [ -n "${SRCDS_APPID}" ]; then
		# shellcheck disable=SC2046,SC2086
		./steamcmd/steamcmd.sh +force_install_dir /home/container +login "${STEAM_USER}" "${STEAM_PASS}" "${STEAM_AUTH}" $([[ "${WINDOWS_INSTALL}" == "1" ]] && printf %s '+@sSteamCmdForcePlatformType windows') $([[ -z ${HLDS_GAME} ]] || printf %s "+app_set_config 90 mod ${HLDS_GAME}") "+app_update ${SRCDS_APPID} $([[ -z ${SRCDS_BETAID} ]] || printf %s "-beta ${SRCDS_BETAID}") $([[ -z ${SRCDS_BETAPASS} ]] || printf %s "-betapassword ${SRCDS_BETAPASS}") ${INSTALL_FLAGS}  $([[ "${VALIDATE}" == "1" ]] && printf %s 'validate')" $([[ "${UPDATE_STEAMWORKS}" == "1" ]] && printf %s '+app_update 1007') +quit
	fi
fi

if [[ "${XVFB}" == "1" ]]; then
	Xvfb :0 -screen 0 "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}" &
fi

mkdir -p "${WINEPREFIX}"

# Check if wine-gecko required and install it if so
if [[ ${WINETRICKS_RUN} =~ gecko ]]; then
	echo "Installing Gecko"
	WINETRICKS_RUN=${WINETRICKS_RUN/gecko}

	if [ ! -f "${WINEPREFIX}/gecko_x86.msi" ]; then
		wget -q -O "${WINEPREFIX}/gecko_x86.msi" http://dl.winehq.org/wine/wine-gecko/2.47.4/wine_gecko-2.47.4-x86.msi
	fi

	if [ ! -f "${WINEPREFIX}/gecko_x86_64.msi" ]; then
		wget -q -O "${WINEPREFIX}/gecko_x86_64.msi" http://dl.winehq.org/wine/wine-gecko/2.47.4/wine_gecko-2.47.4-x86_64.msi
	fi

	wine msiexec /i "${WINEPREFIX}/gecko_x86.msi" /qn /quiet /norestart /log "${WINEPREFIX}/gecko_x86_install.log"
	wine msiexec /i "${WINEPREFIX}/gecko_x86_64.msi" /qn /quiet /norestart /log "${WINEPREFIX}/gecko_x86_64_install.log"
fi

# Check if wine-mono required and install it if so
if [[ ${WINETRICKS_RUN} =~ mono ]]; then
	echo "Installing mono"
	WINETRICKS_RUN=${WINETRICKS_RUN/mono}

	if [ ! -f "${WINEPREFIX}/mono.msi" ]; then
		wget -q -O "${WINEPREFIX}/mono.msi" https://dl.winehq.org/wine/wine-mono/9.1.0/wine-mono-9.1.0-x86.msi
	fi

	wine msiexec /i "${WINEPREFIX}/mono.msi" /qn /quiet /norestart /log "${WINEPREFIX}/mono_install.log"
fi

# List and install other packages
for trick in ${WINETRICKS_RUN}; do
	echo "Installing ${trick}"
	winetricks -q "${trick}"
done

# Replace Startup Variables
MODIFIED_STARTUP=$(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo -e ":/home/container$ ${MODIFIED_STARTUP}"

# Run the Server
eval ${MODIFIED_STARTUP}
