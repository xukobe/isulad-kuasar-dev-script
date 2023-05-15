#!/bin/bash

set -x

block_img=""
loop=""
name=""
group=""
script_dir=$(dirname $0)

function err { echo "$@" >&2; }

function usage() {
    echo "Usage: $0 [options]"
    echo "Start docker container for isulad-kuasar development environment."
    echo "Options:"
    echo "    -n, --name        Name for docker container."
    echo "    -b, --block       Device mapper virutal block image."
    echo "    -l, --loop        Loop device for device mapper."
    echo "    -g, --group       LVM group."
    echo "    -h, --help        Script help information"
}

args=`getopt -o n:b:l:g:h --long name:,block:,loop:,group:,help -- "$@"`
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$args"

while true ; do
    case "$1" in
        -n|--name)
            name=$2
            shift 2
            ;;
        -b|--block)
            block_img=$2
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

found=$(docker ps -f name=$name | sed -n '2p')
if [[ $found != "" ]] ; then
    docker stop $name
    if [[ $? -ne 0 ]] ; then
        err "Failed to stop container $name."
        exit 1
    fi
    echo "Container $name stopped"
fi

if [[ $block_img == "" ]] ; then
    err "Block image is not specified."
    exit 1
fi

if [[ $loop == "" ]] ; then
    err "Loop device is not specified."
    exit 1
fi

if [[ $group == "" ]] ; then
    err "LVM group is not specified."
    exit 1
fi

vg=$(pvs $loop | awk 'END {print $2}')
if [[ $vg != $group ]] ; then
    err "Loop device $loop doesn't belong to group $group."
    exit 1
fi

lvremove -f $group/thinpool
lvremove -f $group/thinpoolmeta
vgremove -f $group
pvremove -f $loop

back_file=$(losetup -l $loop -O BACK-FILE | sed -n '2p')
if [[ $? -ne 0 ]] ; then
    err "Failed to get loop device $loop information."
    exit 1
fi

if [[ $back_file != $block_img ]] ; then
    err "Loop device $loop doesn't match image $block_img."
    exit 1
fi

echo "Detach loop device $loop"
dmsetup remove_all
losetup -d $loop

echo "Remove block image $block_img"
rm $block_img -f
