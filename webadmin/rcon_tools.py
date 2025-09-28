import subprocess
import os

RCON_HOST = '127.0.0.1'
RCON_PORT = os.environ.get('RCON_PORT', '27020')
RCON_PASSWORD = os.environ.get('SERVER_ADMIN_PASSWORD', '')

RCON_BIN = '/usr/local/bin/rcon'  # Ajusta si el binario está en otro lugar

def send_rcon_command(command):
    try:
        result = subprocess.run([
            RCON_BIN,
            '-a', f'{RCON_HOST}:{RCON_PORT}',
            '-p', RCON_PASSWORD,
            command
        ], capture_output=True, text=True, timeout=10)
        return result.stdout.strip()
    except Exception as e:
        return f'Error: {str(e)}'

def save_world():
    return send_rcon_command('Saveworld')

def restart_server():
    return send_rcon_command('DoExit')
