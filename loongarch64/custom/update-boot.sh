#!/bin/bash -e
./build.sh -f boot/initramfs-for-squashfs
./build.sh -f boot/bootimage-squashfs

./strip_os.sh -f boot
./pack_os.sh -f boot

if [ -d workbase/live_usb ]; then
	./live_os.sh -u workbase/live_usb
fi
