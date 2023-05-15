#!/bin/bash
# This script is used to create a raw image file and mount it as a loop device.

if [[ $# -lt 2 ]] ; then
    echo "Please specify loop device path and group name." >> /dev/stderr
    exit 1
fi

disk=$1
group=$2
isulad_daemon_file="/etc/isulad/daemon.json"

group_exist=$(vgdisplay -C | grep $group)
if [ x"$group_exist" != x"" ];then
    echo "group $group already exist" >> /dev/stderr
    exit 1
fi

rm -rf /var/lib/isulad/*

lvremove -f $group/thinpool
lvremove -f $group/thinpoolmeta
vgremove -f $group
pvremove -f $disk
mount | grep $disk | grep /var/lib/isulad
if [ x"$?" == x"0" ];then
    umount /var/lib/isulad
fi
echo y | mkfs.ext4 $disk

touch /etc/lvm/profile/${group}-thinpool.profile
cat > /etc/lvm/profile/${group}-thinpool.profile <<EOF
activation {
thin_pool_autoextend_threshold=80
thin_pool_autoextend_percent=20
}
EOF

set -e

pvcreate -y $disk
vgcreate $group $disk
echo y | lvcreate --wipesignatures y -n thinpool $group -l 80%VG
echo y | lvcreate --wipesignatures y -n thinpoolmeta $group -l 1%VG
lvconvert -y --zero n -c 512K --thinpool $group/thinpool --poolmetadata $group/thinpoolmeta
lvchange --metadataprofile ${group}-thinpool $group/thinpool
lvs -o+seg_monitor

sed -i "s/\"storage\-driver\"\: \"overlay2\"/\"storage\-driver\"\: \"devicemapper\"/g" $isulad_daemon_file
sed -i "/    \"storage-opts\"\: \[/{n;d}" $isulad_daemon_file
sed -i "/    \"storage-opts\"\: \[/a\    \"dm\.thinpooldev\=\/dev\/mapper\/$group\-thinpool\",\n    \"dm\.fs\=ext4\"\,\n    \"dm\.min\_free\_space\=10\%\"" $isulad_daemon_file

exit 0
