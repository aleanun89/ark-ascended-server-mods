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
    *)
        echo "Uso: $0 {restart|save|restartmap|status}"
        exit 1
        ;;
esac
