#!/bin/bash -e
./build.sh toolchain/cross-binutils
./build.sh toolchain/cross-gcc
./build.sh toolchain/dist-cross-gcc-noglibc
find workbase/dist/ -name "*gcc-noglibc.tar.xz"
