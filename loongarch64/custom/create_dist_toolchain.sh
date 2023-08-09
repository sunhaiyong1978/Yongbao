#!/bin/bash -e
tools/get_all_package_url.sh target_base/mpfr
tools/get_all_package_url.sh target_base/mpc

./build.sh toolchain
