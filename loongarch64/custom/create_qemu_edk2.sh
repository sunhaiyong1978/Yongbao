#!/bin/bash -e
./build.sh -r cross-tools/gcc_nolibc
./build.sh -f toolchain/qemu-edk2
