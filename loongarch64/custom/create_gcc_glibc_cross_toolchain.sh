#!/bin/bash -e
./build.sh -r target_base/glibc
./build.sh toolchain
./build.sh toolchain/dist-cross-gcc
find workbase/dist/ -name "*gcc-glibc.tar.xz"
