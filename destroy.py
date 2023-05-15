#!/usr/bin/env python3
import yaml
import os
import subprocess

dir_path = os.path.dirname(os.path.realpath(__file__))
script_dir = os.path.join(dir_path, 'scripts')
config_path = os.path.join(dir_path, 'config.yaml')

def shutdown_container(config):
    shutdown_script = os.path.join(script_dir, 'shutdown.sh')
    cmd_list = ['bash', shutdown_script, '-n', config.get('name'),
                '-b', config.get('block_img'), '-l', config.get('loop'),
                '-g', config.get('group')]
    process = subprocess.run(cmd_list, universal_newlines=True)
    if process.returncode != 0:
        print('Shutdown container failed!')
        return False
    print('Shutdown container successfully!')
    return True

def main():
    with open(config_path) as f:
        config = yaml.safe_load(f)
    # check if container is already exist
    if not shutdown_container(config):
        return

if __name__ == '__main__':
    main()
