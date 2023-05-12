#!/bin/bash -e
./build.sh -d
./strip_os.sh -f
./install_os_run.sh
./pack_os.sh -f
mkdir -p workbase/live_usb
./live_os.sh -u workbase/live_usb
