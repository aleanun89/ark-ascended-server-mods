#!/bin/bash

# Quick function to generate a timestamp
timestamp () {
  date +"%Y-%m-%d %H:%M:%S,%3N"
}

# Shutdown function for trap
shutdown () {
    echo "$(timestamp) INFO: Recieved SIGTERM, shutting down gracefully"
    echo "$(timestamp) INFO: Saving world..."
    # Not clear if DoExit saves first so explicitly save then exit
    rcon -a 127.0.0.1:${RCON_PORT} -p "${SERVER_ADMIN_PASSWORD}" Saveworld
    rcon -a 127.0.0.1:${RCON_PORT} -p "${SERVER_ADMIN_PASSWORD}" DoExit

    # Server exit doesn't close pid for some reason, so lets check that the port is closed and then send SIGTERM to main pid
    while netstat -aln | grep -q $GAME_PORT; do
        sleep 1
    done

    echo "$(timestamp) INFO: Goodbye"
    kill -15 $asa_pid 
}

# Set our trap
trap 'shutdown' TERM

# Set vars established during image build
IMAGE_VERSION=$(cat /home/steam/image_version)
MAINTAINER=$(cat /home/steam/image_maintainer)
EXPECTED_FS_PERMS=$(cat /home/steam/expected_filesystem_permissions)

echo "$(timestamp) INFO: Launching Ark: Survival Ascended dedicated server image ${IMAGE_VERSION} by ${MAINTAINER}"

# Make sure required arguments are set
if [ -z "$SERVER_MAP" ]; then
    SERVER_MAP="TheIsland_WP"
    echo "$(timestamp) WARN: SERVER_MAP not set, using default: $SERVER_MAP"
fi

if [ -z "$SESSION_NAME" ]; then
    echo "$(timestamp) ERROR: SESSION_NAME environment variable must be set"
    exit 1
fi

if [ -z "$GAME_PORT" ]; then
    GAME_PORT="7777"
    echo "$(timestamp) WARN: GAME_PORT not set, using default: $GAME_PORT UDP"
fi

if [ -z "$RCON_PORT" ]; then
    RCON_PORT="27020"
    echo "$(timestamp) WARN: RCON_PORT not set, using default: $RCON_PORT TCP"
fi

if [ -z "$SERVER_PASSWORD" ]; then
    echo "$(timestamp) WARN: SERVER_PASSWORD not set, the server will be open to the public"
fi

if [ -z "$SERVER_ADMIN_PASSWORD" ]; then
    echo "$(timestamp) ERROR: SERVER_ADMIN_PASSWORD environment variable must be set"
    exit 1
fi

# Check for correct ownership
# ClusterDirOverride support
if [ -n "$CLUSTER_DIR_OVERRIDE" ]; then
    CLUSTER_DIR_OVERRIDE_ARG="-ClusterDirOverride=\"$CLUSTER_DIR_OVERRIDE\""
elif grep -q '^ClusterDirOverride=' /container/extra.ini; then
    CLUSTER_DIR_OVERRIDE=$(grep '^ClusterDirOverride=' /container/extra.ini | cut -d'=' -f2-)
    CLUSTER_DIR_OVERRIDE_ARG="-ClusterDirOverride=\"$CLUSTER_DIR_OVERRIDE\""
else
    CLUSTER_DIR_OVERRIDE_ARG=""
fi
if ! touch "${ARK_PATH}/ShooterGame/Saved/test"; then
    echo ""
    echo "$(timestamp) ERROR: The ownership of /home/steam/ark/ShooterGame/Saved is not correct and the server will not be able to save..."
    echo "the directory that you are mounting into the container needs to be owned by ${EXPECTED_FS_PERMS}"
    echo "from your container host attempt the following command 'chown -R ${EXPECTED_FS_PERMS} /your/ark/folder'"
    echo ""
    exit 1
fi

# Cleanup test write
rm "${ARK_PATH}/ShooterGame/Saved/test"

# Update Ark Ascended
echo "$(timestamp) INFO: Updating Ark Survival Ascended Dedicated Server"
steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$ARK_PATH" +login anonymous +app_update 2430930 validate +quit

# Check that steamcmd was successful
if [ $? != 0 ]; then
    echo "$(timestamp) ERROR: steamcmd was unable to successfully initialize and update Ark Survival Ascended Dedicated Server"
    exit 1
fi

# Check that log directory exists, if not create
if ! [ -d "${ARK_PATH}/ShooterGame/Saved/Logs/" ]; then
    mkdir -p "${ARK_PATH}/ShooterGame/Saved/Logs/"
fi

# Check that log file exists, if not create
if ! [ -f "${ARK_PATH}/ShooterGame/Saved/Logs/ShooterGame.log" ]; then
    touch "${ARK_PATH}/ShooterGame/Saved/Logs/ShooterGame.log"
fi


# Incluir mejoras de extra.ini en Game.ini si existe
EXTRA_INI_PATH="${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer/extra.ini"
GAME_INI_PATH="${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer/Game.ini"
GAME_USERSETTINGS_PATH="${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini"
if [ -f "$EXTRA_INI_PATH" ]; then
    echo "$(timestamp) INFO: Procesando extra.ini para aplicar configuraciones profesionales"
    current_section=""
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        if [[ "$line" =~ ^\[(.*)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi
        key="${line%%=*}"
        value="${line#*=}"
        # Detectar si es parámetro avanzado para Game.ini
        if [[ "$key" =~ ^(PerLevelStatsMultiplier_|ExperiencePointsForLevel|DinoSpawnWeightMultipliers|OverrideEngramEntries|OverrideNamedEngramEntries|EngramEntryAutoUnlocks|ConfigOverrideNPCSpawnEntriesContainer|ConfigAddNPCSpawnEntriesContainer|ConfigSubtractNPCSpawnEntriesContainer|ConfigOverrideSupplyCrateItems|PlayerBaseStatMultipliers|MutagenLevelBoost|MutagenLevelBoost_Bred) ]]; then
            # Asegurar sección [/script/shootergame.shootergamemode] en Game.ini
            if ! grep -q "^\[/script/shootergame.shootergamemode\]" "$GAME_INI_PATH"; then
                echo -e "\n[/script/shootergame.shootergamemode]" >> "$GAME_INI_PATH"
            fi
            # Añadir o reemplazar en la sección
            if grep -A 1000 "^\[/script/shootergame.shootergamemode\]" "$GAME_INI_PATH" | grep -q "^$key="; then
                awk -v section="\[/script/shootergame.shootergamemode\]" -v key="$key" -v value="$value" '
                    $0 == section {print; in_section=1; next}
                    in_section && $0 ~ "^"key"=" {print key"="value; in_section=0; next}
                    {print}
                ' "$GAME_INI_PATH" > "$GAME_INI_PATH.tmp" && mv "$GAME_INI_PATH.tmp" "$GAME_INI_PATH"
            else
                sed -i "/^\[/script/shootergame.shootergamemode\]/a$key=$value" "$GAME_INI_PATH"
            fi
        else
            # El resto va a GameUserSettings.ini bajo [ServerSettings]
            if ! grep -q "^\[ServerSettings\]" "$GAME_USERSETTINGS_PATH"; then
                echo -e "\n[ServerSettings]" >> "$GAME_USERSETTINGS_PATH"
            fi
            if grep -A 1000 "^\[ServerSettings\]" "$GAME_USERSETTINGS_PATH" | grep -q "^$key="; then
                awk -v section="\[ServerSettings\]" -v key="$key" -v value="$value" '
                    $0 == section {print; in_section=1; next}
                    in_section && $0 ~ "^"key"=" {print key"="value; in_section=0; next}
                    {print}
                ' "$GAME_USERSETTINGS_PATH" > "$GAME_USERSETTINGS_PATH.tmp" && mv "$GAME_USERSETTINGS_PATH.tmp" "$GAME_USERSETTINGS_PATH"
            else
                sed -i "/^\[ServerSettings\]/a$key=$value" "$GAME_USERSETTINGS_PATH"
            fi
        fi
    done < "$EXTRA_INI_PATH"
fi

# Link logfile to stdout of pid 1 so we can see logs
ln -sf /proc/1/fd/1 "${ARK_PATH}/ShooterGame/Saved/Logs/ShooterGame.log"

# Build Ark Ascended launch command
LAUNCH_COMMAND="${SERVER_MAP}?SessionName=${SESSION_NAME}?RCONEnabled=True?RCONPort=${RCON_PORT}"
if [ -n "${MAX_PLAYERS}" ]; then
    LAUNCH_COMMAND="${LAUNCH_COMMAND}?MaxPlayers=${MAX_PLAYERS}"
fi
if [ -n "${SERVER_PASSWORD}" ]; then
    LAUNCH_COMMAND="${LAUNCH_COMMAND}?ServerPassword=${SERVER_PASSWORD}"
fi

if [ -n "${EXTRA_SETTINGS}" ]; then
    LAUNCH_COMMAND="${LAUNCH_COMMAND}${EXTRA_SETTINGS}"
fi

# Cluster support
if [ -n "${CLUSTER_ID}" ]; then
    LAUNCH_COMMAND="${LAUNCH_COMMAND}?ClusterId=${CLUSTER_ID}"
fi
if [ -n "${ENABLE_CROSS_TRAVEL}" ]; then
    LAUNCH_COMMAND="${LAUNCH_COMMAND}?CrossTravelEnabled=${ENABLE_CROSS_TRAVEL}"
fi

# Mods support
if [ -n "${MOD_IDS}" ]; then
    LAUNCH_COMMAND="${LAUNCH_COMMAND} -automanagedmods -mods=${MOD_IDS}"
fi

# According to Wiki, ServerAdminPassword must be the last "?" deliniated Argument
LAUNCH_COMMAND="${LAUNCH_COMMAND}?ServerAdminPassword=${SERVER_ADMIN_PASSWORD}"

# According to Wiki, game port is not a ? deliniated command
LAUNCH_COMMAND="${LAUNCH_COMMAND} -port=${GAME_PORT}"

if [ -n "${EXTRA_FLAGS}" ]; then
    LAUNCH_COMMAND="${LAUNCH_COMMAND} ${EXTRA_FLAGS}"
fi

# Añadir ClusterDirOverride si está definido
if [ -n "$CLUSTER_DIR_OVERRIDE_ARG" ]; then
    LAUNCH_COMMAND="${LAUNCH_COMMAND} $CLUSTER_DIR_OVERRIDE_ARG"
fi

# RCONEnabled in server start args doesn't seem to actually enabled RCON, so let's do it manually
if [ ! -f "${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini" ]; then
    mkdir -p "${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer"
    printf "[ServerSettings]\nRCONEnabled=True\nRCONPort=%s\n" "${RCON_PORT}" > "${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini"
elif ! grep -q "RCONEnabled" "${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini"; then
    # Añadir RCONEnabled=True después de RCONPort
    awk '/RCONPort=/ {print; print "RCONEnabled=True"; next} {print}' "${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini" > "${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini.tmp" && mv "${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini.tmp" "${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini"
    sed -i "s/RCONPort=[0-9]*/RCONPort=${RCON_PORT}/" "${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini"
elif grep -q "RCONEnabled=False" "${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini"; then
    sed -i "s/RCONEnabled=False/RCONEnabled=True/" "${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini"
    sed -i "s/RCONPort=[0-9]*/RCONPort=${RCON_PORT}/" "${ARK_PATH}/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini"
fi

echo ""
echo "   _____         __                                        "
echo "  /  _  \_______|  | __                                    "
echo " /  /_\  \_  __ \  |/ /                                    "
echo "/    |    \  | \/    <                                     "
echo "\____|__  /__|  |__|_ \                                    "
echo "        \/           \/                                    "
echo "  _________                  .__              .__          "
echo " /   _____/__ ____________  _|__|__  _______  |  |         "
echo " \_____  \|  |  \_  __ \  \/ /  \  \/ /\__  \ |  |         "
echo " /        \  |  /|  | \/\   /|  |\   /  / __ \|  |__       "
echo "/_______  /____/ |__|    \_/ |__| \_/  (____  /____/       "
echo "        \/                                  \/             "
echo "   _____                                  .___         .___"
echo "  /  _  \   ______ ____  ____   ____    __| _/____   __| _/"
echo " /  /_\  \ /  ___// ___\/ __ \ /    \  / __ |/ __ \ / __ | "
echo "/    |    \\\___ \\\  \__\  ___/|   |  \/ /_/ \  ___// /_/ | "
echo "\____|__  /____  >\___  >___  >___|  /\____ |\___  >____ | "
echo "        \/     \/     \/    \/     \/      \/    \/     \/ "
echo "                                                           "
echo "                                                           "
echo "$(timestamp) INFO: Launching ARK:SA"
echo "-----------------------------------------------------------"
echo "Server Name: ${SESSION_NAME}"
echo "Server Password: ${SERVER_PASSWORD}"
echo "Admin Password: ${SERVER_ADMIN_PASSWORD}"
echo "RCON Port: ${RCON_PORT}"
echo "Game Port: ${GAME_PORT}"
echo "Map: ${SERVER_MAP}"
echo "Extra Settings: ${EXTRA_SETTINGS}"
echo "Extra Flags: ${EXTRA_FLAGS}"
echo "Mods: ${MODS}"
echo "Server Container Image Version: ${IMAGE_VERSION}"
echo ""
echo ""

# Launch ASE Server in Proton
${STEAM_PATH}/compatibilitytools.d/GE-Proton${GE_PROTON_VERSION}/proton run ${ARK_PATH}/ShooterGame/Binaries/Win64/ArkAscendedServer.exe ${LAUNCH_COMMAND} &

asa_pid=$!

wait $asa_pid
