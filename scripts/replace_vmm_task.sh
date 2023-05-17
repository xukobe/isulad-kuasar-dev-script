#!/bin/bash

set -x

kuasar_workspace=""
vmm_task_binary=""
initrd_image="/var/lib/kuasar/kuasar.initrd"

function usage() {
    echo "Usage: $0 [options]"
    echo "Replace vmm-task in the image."
    echo "Options:"
    echo "    -w, --workspace   Kuasar workspace for building vmm-task."
    echo "    -b, --binary      vmm-task binary to replace."
    echo "    -i, --image       Initrd image in which vmm-task will be replaced."
    echo "    -h, --help        Script help information"
}

args=`getopt -o w:b:i:h --long workspace:,binary:,image:,help -- "$@"`
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$args"

while true ; do
    case "$1" in
        -w|--workspace)
            kuasar_workspace=$2
            shift 2
            ;;
        -b|--binary)
            vmm_task_binary=$2
            shift 2
            ;;
        -i|--image)
            initrd_image=$2
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
            echo "Invalid argument!" >> /dev/stderr
            exit 1
            ;;
    esac
done

# if vmm-task binary is not specified, build it from source code
if [ x"$vmm_task_binary" == x"" ]; then
    echo "vmm-task not specified, build vmm-task from source code..."
    if [ x"$kuasar_workspace" == x"" ]; then
        echo "Kuasar workspace not specified!"
        echo "git clone kuasar source code..."
        kuasar_build=$(mktemp -d)
        git clone https://github.com/kuasar-io/kuasar.git $kuasar_build/kuasar
        if [ $? -ne 0 ]; then
            echo "Failed to clone kuasar source code!" >> /dev/stderr
            exit 1
        fi
        kuasar_workspace=$kuasar_build/kuasar
    fi
    if [ ! -d "$kuasar_workspace/vmm/task" ]; then
        echo "Kuasar workspace $kuasar_workspace does not exist or not a valid kuasar workspace!" >> /dev/stderr
        exit 1
    fi
    pushd $kuasar_workspace/vmm/task
    cargo build --release --target x86_64-unknown-linux-musl
    if [ $? -ne 0 ]; then
        echo "Failed to build vmm-task!" >> /dev/stderr
        exit 1
    fi
    popd
    vmm_task_binary="$kuasar_workspace/vmm/task/target/x86_64-unknown-linux-musl/release/vmm-task"
    if [ ! -f "$vmm_task_binary" ]; then
        echo "Failed to build vmm-task binary $vmm_task_binary!" >> /dev/stderr
        exit 1
    fi
fi

# replace vmm-task in initrd image
if [ ! -f "$initrd_image" ]; then
    echo "Initrd image $initrd_image does not exist!" >> /dev/stderr
    exit 1
fi

echo "Replace vmm-task in initrd image $initrd_image..."
tmp_dir=$(mktemp -d)
# extract initrd image
pushd $tmp_dir
zcat $initrd_image | cpio -idvm
if [ $? -ne 0 ]; then
    echo "Failed to extract initrd image $initrd_image!" >> /dev/stderr
    exit 1
fi

# replace vmm-task
pushd usr/sbin
rm -f vmm-task
cp $vmm_task_binary vmm-task
if [ $? -ne 0 ]; then
    echo "Failed to replace vmm-task in initrd image $initrd_image!" >> /dev/stderr
    exit 1
fi

echo "Replace init in initrd image $initrd_image..."

rm -f init
ln -s vmm-task init
popd

# pack initrd image
echo "Pack initrd image $initrd_image..."
find . | cpio -o -H newc | gzip > /tmp/kuasar.initrd
if [ $? -ne 0 ]; then
    echo "Failed to pack initrd image $initrd_image!" >> /dev/stderr
    exit 1
fi

# replace initrd image
mv /tmp/kuasar.initrd $initrd_image
if [ $? -ne 0 ]; then
    echo "Failed to replace initrd image $initrd_image!" >> /dev/stderr
    exit 1
fi

popd

echo "Delete temporary directory $tmp_dir..."
rm -rf $tmp_dir

# delete kuasar_build if it is specified
if [ x"$kuasar_build" != x"" ]; then
    echo "Delete kuasar build directory $kuasar_build..."
    rm -rf $kuasar_build
fi

echo "vmm-task replaced successfully!"

exit 0



