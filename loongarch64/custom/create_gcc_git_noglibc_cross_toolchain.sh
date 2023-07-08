#!/bin/bash -e
./build.sh toolchain/cross-binutils_git
./build.sh toolchain/cross-gcc_git
./build.sh toolchain/dist-cross-gcc_git-noglibc
find workbase/dist/ -name "*gcc_git-noglibc.tar.xz"
