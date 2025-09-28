from flask import Flask, render_template, request, redirect, url_for, flash
import os
from backup import create_backup, list_backups, restore_backup
from rcon_tools import send_rcon_command, save_world, restart_server

app = Flask(__name__)
app.secret_key = 'arkadminsecretkey'

CONFIG_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '../container'))
GAME_INI = os.path.join(CONFIG_DIR, 'Game.ini')
GAME_USER_SETTINGS = os.path.join(CONFIG_DIR, 'GameUserSettings.ini')

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/edit/<config>', methods=['GET', 'POST'])
def edit_config(config):
    file_path = GAME_INI if config == 'game' else GAME_USER_SETTINGS
    if request.method == 'POST':
        content = request.form['content']
        with open(file_path, 'w') as f:
            f.write(content)
        flash(f'{config} actualizado correctamente.')
        return redirect(url_for('edit_config', config=config))
    with open(file_path, 'r') as f:
        content = f.read()
    return render_template('edit.html', config=config, content=content)

# Backup routes
@app.route('/backup', methods=['GET'])
def backup_page():
    backups = list_backups()
    return render_template('backup.html', backups=backups)

@app.route('/backup/create', methods=['POST'])
def create_backup_route():
    path = create_backup()
    flash(f'Backup creado: {os.path.basename(path)}')
    return redirect(url_for('backup_page'))

@app.route('/backup/restore/<backup_name>', methods=['POST'])
def restore_backup_route(backup_name):
    try:
        restore_backup(backup_name)
        flash(f'Backup restaurado: {backup_name}')
    except Exception as e:
        flash(f'Error al restaurar: {str(e)}')
    return redirect(url_for('backup_page'))


# RCON admin routes
@app.route('/rcon', methods=['GET'])
def rcon_page():
    return render_template('rcon.html')

@app.route('/rcon/send', methods=['POST'])
def send_rcon():
    command = request.form.get('command')
    output = send_rcon_command(command)
    flash(f'Respuesta: {output}')
    return redirect(url_for('rcon_page'))

@app.route('/rcon/save', methods=['POST'])
def save_world_route():
    output = save_world()
    flash(f'Respuesta: {output}')
    return redirect(url_for('rcon_page'))

@app.route('/rcon/restart', methods=['POST'])
def restart_server_route():
    output = restart_server()
    flash(f'Respuesta: {output}')
    return redirect(url_for('rcon_page'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
