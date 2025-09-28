import os
import shutil
from datetime import datetime

ARK_SAVED_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '../container/ark/ShooterGame/Saved'))
BACKUP_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), 'backups'))

os.makedirs(BACKUP_DIR, exist_ok=True)

def create_backup():
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_path = os.path.join(BACKUP_DIR, f'ark_backup_{timestamp}')
    shutil.copytree(ARK_SAVED_DIR, backup_path)
    return backup_path

def list_backups():
    return [f for f in os.listdir(BACKUP_DIR) if os.path.isdir(os.path.join(BACKUP_DIR, f))]

def restore_backup(backup_name):
    backup_path = os.path.join(BACKUP_DIR, backup_name)
    if not os.path.isdir(backup_path):
        raise FileNotFoundError('Backup not found')
    # Remove current saved dir and restore
    if os.path.exists(ARK_SAVED_DIR):
        shutil.rmtree(ARK_SAVED_DIR)
    shutil.copytree(backup_path, ARK_SAVED_DIR)
    return True
