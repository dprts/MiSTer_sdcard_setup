#!/bin/bash

RELEASE_URL="https://github.com/MiSTer-devel/SD-Installer-Win64_MiSTer/raw/master/"
RELEASE_FILE="release_20200122.rar"
IMAGE_REPO="https://github.com/MiSTer-devel/Linux_Image_creator_MiSTer.git"
IMAGES_URL="https://github.com/MiSTer-devel/Linux_Image_creator_MiSTer/raw/master/"
UBOOT_IMAGE="uboot.img"
KERNEL_IMAGE="zImage_dtb"

usage() {
    echo "Usage: $0 -d DEVICE"
    exit 2
}

errorout() {
    MSG=$1
    echo -e "\e[1;31m[-]\e[0m $MSG"
    exit 2
}

warning() {
    MSG=$1
    echo -e "\e[1;33m[!]\e[0m $MSG"
}

info() {
    MSG=$1
    echo -e "\e[1;32m[+]\e[0m $MSG"
}

while getopts ":hd:" opts; do
  case $opts in
    d) DEVICE=$OPTARG ;;
    h | \? | *) usage ;;
  esac
done

[ $EUID -ne 0 ] && errorout "Must be run as root"
[ ! -e $DEVICE ] && errorout "Incorrect device: $DEVICE"
grep -qs $DEVICE /proc/mounts && errorout "$DEVICE (or its partitions) are mounted, please umount and retry."

warning "All data on $DEVICE will be destroyed"
warning "Are you sure [y/n]"
read answer
[ "$answer" != "y" ] && errorout "Aborted by user"
    
info "Zeroing first 100MB of $DEVICE"
dd if=/dev/zero of=$DEVICE bs=1k count=1024 status=progress
sync

DEVICE_SIZE_BYTES=$(sfdisk -s $DEVICE)
DEVICE_SIZE_MBYTES=$(($DEVICE_SIZE_BYTES/1024))
P1_PARTITION_SIZE=$((DEVICE_SIZE_MBYTES-3))
A2_START=$((DEVICE_SIZE_MBYTES-2))

info "Device Size: ${DEVICE_SIZE_MBYTES}MBytes"
info "${DEVICE}p1 size: $P1_PARTITION_SIZE"
info "A2 partitions start: $A2_START"

sfdisk $DEVICE <<-__END__
1M,${P1_PARTITION_SIZE}M,0x07
${A2_START}M,1M,0xA2
__END__
partprobe

mkfs.exfat ${DEVICE}p1

[ ! -d ./MiSTer_filesystem ] && (info "Creating ./MiSTer_filesystem"; mkdir ./MiSTer_filesystem)

info "Mounting MiSTer_filesystem"
mount ${DEVICE}p1 $(realpath ./MiSTer_filesystem) || errorout "Error while mounting ${DEVICE}p1"

wget -N --continue ${RELEASE_URL}${RELEASE_FILE}
wget -N --continue ${IMAGES_URL}${UBOOT_IMAGE}
wget -N --continue ${IMAGES_URL}${KERNEL_IMAGE}

unrar x $RELEASE_FILE files/* ./MiSTer_filesystem
mv ./MiSTer_filesystem/files/* ./MiSTer_filesystem/
rm -r ./MiSTer_filesystem/files/

cp -v $KERNEL_IMAGE ./MiSTer_filesystem/linux
dd if=$UBOOT_IMAGE of=${DEVICE}p2 status=progress || errorout "Error while installing uboot"

info "Unmounting MiSTer_filesystem"
umount $(realpath ./MiSTer_filesystem) || errorout "Error while unmounting ${DEVICE}p1"
sync
info "All done, you can remove device $DEVICE"
