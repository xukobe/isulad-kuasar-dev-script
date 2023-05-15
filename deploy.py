#!/usr/bin/env python3
import yaml
import os
import subprocess

# Below is the config.yaml template
"""
# Global
# eg. http://192.168.0.1:7890
proxy: ""

######## Config for docker image build ########
# Force build docker image every time
force_build: false
tag_name: "openeuler/kuasar:latest"

######## Config for running a container ########
# Workspace mounted into docker environment
workspace: "/workspace"
# Virtual block image for creating devicemapper
block_img: "~/kuasar_env.img"
# MB
block_size: 5000
# Loop device to mount block image
loop: "/dev/loop123"
# LVM group name for devicemapper
group: "isulad0"
# Container name for development environment
name: "kuasar_env"
"""

dir_path = os.path.dirname(os.path.realpath(__file__))
script_dir = os.path.join(dir_path, 'scripts')
config_path = os.path.join(dir_path, 'config.yaml')

def check_image(config):
    # check if tag_name is already exist
    repo_name = config.get('tag_name').split(':')[0]
    process = subprocess.run(['docker', 'images'], stdout=subprocess.PIPE, universal_newlines=True)
    for line in process.stdout.split('\n'):
        if repo_name in line:
            return True
    return False

def build_image(config):
    # check if tag_name is already exist
    to_build = False
    if not check_image(config):
        to_build = True

    if config.get('force_build'):
        to_build = True
    
    if to_build:
        build_script = os.path.join(script_dir, 'build.sh')
        process = subprocess.run(['bash', build_script, '-p', config.get('proxy'), '-t', config.get('tag_name')],
                                 universal_newlines=True)
        if process.returncode != 0:
            print('Build docker image failed!')
            return False
        print('Build docker image successfully!')
    else:
        print('Docker image already exist!')
    return True

def check_container(config):
    # check if container is already exist
    process = subprocess.run(['docker', 'ps', '-a'], stdout=subprocess.PIPE, universal_newlines=True)
    for line in process.stdout.split('\n'):
        if config.get('name') in line:
            return True
    return False

def run_container(config):
    if check_container(config):
        print('Container already exist!')
        return True
    run_script = os.path.join(script_dir, 'start.sh')
    print(run_script)
    cmd_list = ['bash', run_script, '-n', config.get('name'),
                '-p', config.get('proxy'), '-w', config.get('workspace'),
                '-b', config.get('block_img'), '-s', str(config.get('block_size')),
                '-l', config.get('loop'), '-g', config.get('group'),
                '-i', config.get('tag_name')]
    process = subprocess.run(cmd_list, universal_newlines=True)
    if process.returncode != 0:
        print('Run container failed!')
        return False
    print('Run container successfully!')
    return True

# Write a main function
def main():
    # config.yaml is in the same directory as this script, get the realpath path of config.yaml
    with open(config_path) as f:
        config = yaml.safe_load(f)
    if not build_image(config):
        return
    # check if container is already exist
    if not run_container(config):
        return
    print('Now you can enter the container by running:')
    print('docker exec -it {} /bin/bash'.format(config.get('name')))

if __name__ == '__main__':
    main()
