#!/bin/bash -e
tools/get_all_package_url.sh -g -f boot/grub
tools/get_all_package_url.sh boot/grub

./build.sh -f cross-tools/grub
./build.sh -f boot/grub
./build.sh -f boot/initramfs-for-squashfs
./build.sh -f boot/bootimage-squashfs

./strip_os.sh -f boot
./pack_os.sh -f boot

if [ -d workbase/live_usb ]; then
	./live_os.sh -u workbase/live_usb
fi
