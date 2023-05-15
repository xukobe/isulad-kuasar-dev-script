#!/bin/bash

tag_name="openeuler/kuasar:latest"

function usage() {
    echo "Usage: $0 [options]"
    echo "Build docker image for isulad-kuasar development environment."
    echo "Options:"
    echo "    -p, --proxy       Proxy for docker build."
    echo "    -t, --tag         Tag name for docker image."
    echo "    -h, --help        Script help information"
}

args=`getopt -o p:t:h --long proxy:,tag:,help -- "$@"`
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$args"

while true ; do
    case "$1" in
        -p|--proxy)
            proxy=$2
            shift 2
            ;;
        -t|--tag)
            tag_name=$2
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
            err "Invalid argument!"
            exit 1
            ;;
    esac
done

build_dir=$(dirname $0)/..
echo "Build docker image from $build_dir"
echo "Proxy: $proxy"
echo "Tag name: $tag_name"
docker build --build-arg HTTP_PROXY=$proxy --build-arg HTTPS_PROXY=$proxy -t $tag_name -f $build_dir/Dockerfile $build_dir
if [ $? -ne 0 ]; then
    echo "Failed to build docker image $tag_name!"
    exit 1
fi
echo "Docker image $tag_name built successfully!"
