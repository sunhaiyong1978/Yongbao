#!/bin/bash -e
tools/get_all_package_url.sh mpfr
tools/get_all_package_url.sh mpc

./build.sh toolchain
