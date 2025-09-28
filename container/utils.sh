#!/bin/bash

# Script utilitario para administración interna del contenedor ARK ASA
# Uso: ./utils.sh <comando>
# Comandos disponibles: restart, save, restartmap, status

RCON_BIN="/usr/local/bin/rcon"
RCON_HOST="127.0.0.1"
RCON_PORT="${RCON_PORT:-27020}"
RCON_PASSWORD="${SERVER_ADMIN_PASSWORD}"

function restart_server() {
    $RCON_BIN -a ${RCON_HOST}:${RCON_PORT} -p "${RCON_PASSWORD}" DoExit
}

function save_world() {
    $RCON_BIN -a ${RCON_HOST}:${RCON_PORT} -p "${RCON_PASSWORD}" Saveworld
}

function restart_map() {
    $RCON_BIN -a ${RCON_HOST}:${RCON_PORT} -p "${RCON_PASSWORD}" DoRestartMap
}

function status() {
    $RCON_BIN -a ${RCON_HOST}:${RCON_PORT} -p "${RCON_PASSWORD}" listplayers
}

apply_extra_ini() {
    EXTRA_INI_PATH="$1"
    GAME_INI_PATH="/home/steam/ark/ShooterGame/Saved/Config/WindowsServer/Game.ini"
    GAME_USERSETTINGS_PATH="/home/steam/ark/ShooterGame/Saved/Config/WindowsServer/GameUserSettings.ini"

    if [ ! -f "$EXTRA_INI_PATH" ]; then
        echo "No existe el extra.ini: $EXTRA_INI_PATH"
        exit 1
    fi

    echo "Aplicando $EXTRA_INI_PATH..."
    current_section=""
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        if [[ "$line" =~ ^\[(.*)\]$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi
        key="${line%%=*}"
        value="${line#*=}"
        if [[ "$key" =~ ^(PerLevelStatsMultiplier_|ExperiencePointsForLevel|DinoSpawnWeightMultipliers|OverrideEngramEntries|OverrideNamedEngramEntries|EngramEntryAutoUnlocks|ConfigOverrideNPCSpawnEntriesContainer|ConfigAddNPCSpawnEntriesContainer|ConfigSubtractNPCSpawnEntriesContainer|ConfigOverrideSupplyCrateItems|PlayerBaseStatMultipliers|MutagenLevelBoost|MutagenLevelBoost_Bred) ]]; then
            if ! grep -q "^\[/script/shootergame.shootergamemode\]" "$GAME_INI_PATH"; then
                echo -e "\n[/script/shootergame.shootergamemode]" >> "$GAME_INI_PATH"
            fi
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
}

case "$1" in
    restart)
        restart_server
        ;;
    save)
        save_world
        ;;
    restartmap)
        restart_map
        ;;
    status)
        status
        ;;
    apply)
        if [ -n "$2" ]; then
            apply_extra_ini "$2"
            restart_server
        else
            echo "Uso: $0 apply /ruta/a/extra.ini"
            exit 1
        fi
        ;;
    *)
        echo "Uso: $0 {restart|save|restartmap|status|apply <extra.ini>}"
        exit 1
        ;;
esac
