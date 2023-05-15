#!/bin/bash

set -x

proxy=""
workspace=""
block_img=""
# MB
block_size=5000
image="openeuler/kuasar:latest"
loop="/dev/loop235"
name="kuasar_env"
group="isulad"
script_dir=$(dirname $0)

function err { echo "$@" >&2; }

function usage() {
    echo "Usage: $0 [options]"
    echo "Start docker container for isulad-kuasar development environment."
    echo "Options:"
    echo "    -n, --name        Name for docker container."
    echo "    -p, --proxy       Proxy for docker container."
    echo "    -w, --workspace   Workspace for development."
    echo "    -b, --block       Device mapper virutal block image."
    echo "    -s, --size        Size of device mapper virtual image."
    echo "    -l, --loop        Loop device for device mapper."
    echo "    -g, --group       LVM group."
    echo "    -i, --image       Docker image for development."
    echo "    -h, --help        Script help information"
}

args=`getopt -o n:p:w:b:s:l:g:i:h --long name:,proxy:,workspace:,block:,size:,loop:,group:,image:,help -- "$@"`
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$args"

while true ; do
    case "$1" in
        -n|--name)
            name=$2
            shift 2
            ;;
        -p|--proxy)
            proxy=$2
            shift 2
            ;;
        -w|--workspace)
            workspace=$2
            shift 2
            ;;
        -b|--block)
            block_img=$2
            shift 2
            ;;
        -s|--size)
            block_size=$2
            shift 2
            ;;
        -l|--loop)
            loop=$2
            shift 2
            ;;
        -g|--group)
            group=$2
            shift 2
            ;;
        -i|--image)
            image=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            err "Invalid argument $1!"
            usage
            exit 1
            ;;
    esac
done

proxy_option=""
if [[ ! -z $proxy ]] ; then
    proxy_option="--env HTTP_PROXY=$proxy --env HTTPS_PROXY=$proxy"
fi

if [[ -z $workspace || ! -d $workspace ]] ; then
    err "Please specify a valid workspace for docker container."
    exit 1
fi

workspace_option="-v $workspace:/workspace"

if [[ -z $block_img ]] ; then
    err "Please specify a valid device mapper virtual block image."
    exit 1
fi

if [[ -z $loop ]] ; then
    err "Please specify the loop device for docker container."
    exit 1
fi

if [[ ! -f $loop ]] ; then
    mknod $loop -m660 b 7 0
fi

function setup_loop_device() {
    echo "Setup loop device $1 for image $2."
    back_file=$(losetup -l $1 -O BACK-FILE | sed -n '2p')
    if [[ $? -ne 0 ]] ; then
        err "Failed to get loop device $1 information."
        exit 1
    fi
    if [[ -z $back_file ]] ; then
        dmsetup remove_all
        losetup -d $1
        losetup $1 $2
        if [[ $? -ne 0 ]] ; then
            err "Failed to setup loop device $1 for image $2."
            exit 1
        fi
    elif [[ $back_file != $2 ]] ; then
        err "Loop device $1 doesn't match image $2."
        exit 1
    fi
    echo "Loop device $1 has been setup for image $2."
}

if [[ ! -f $block_img ]] ; then
    echo "$block_img doesn't exist, trying to create new image with dd command."
    dd if=/dev/zero of=$block_img iflag=fullblock bs=1M count=$block_size && sync
    if [[ $? -ne 0 ]] ; then
        err "Failed to create device mapper virtual image, $block_img."
        exit 1
    fi
    echo "Create device mapper virtual image $block_img successfully."
    setup_loop_device $loop $block_img
else
    echo "$block_img exists"
    setup_loop_device $loop $block_img
fi

# This script is used to start docker container.
docker run $proxy_option -itd --rm --privileged --tmpfs /run --tmpfs /tmp --name $name -v /lib/modules:/lib/modules -v /dev:/dev $workspace_option $image
docker cp $script_dir/create_device_mapper.sh $name:/root
docker exec -it $name bash /root/create_device_mapper.sh $loop $group
