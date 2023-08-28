#!/bin/bash -e

./build.sh -r host-tools/automake

# 筛选编译Wine所需要的host-tools工具集。
mkdir -p steps
./build.sh -x -o -f_opt,-g_opt,wine -i steps/wine_runtime_host_requires.index -g host-tools
sed -i "/step\/target_base/d" steps/wine_runtime_host_requires.index
sed -i -e "/cross-tools\/gcc/d" \
       -e "/cross-tools\/binutils/d" \
       -e "/cross-tools\/grub/d" \
       -e "/cross-tools\/gdb/d" \
       -e "/cross-tools\/qemu/d" \
       -e "/cross-tools\/rustc/d" \
       -e "/bootstrap\//d" \
       -e "/host-tools\/node/d" \
       -e "/host-tools\/cbindgen/d" \
       steps/wine_runtime_host_requires.index
./build.sh -i steps/wine_runtime_host_requires.index


# 编译与wine相关的交叉工具链
./build.sh -o wine -g cross-toolchains

# 编译wine_runtime环境的软件包
./build.sh wine_runtime

# Strip二进制的调试信息
./strip_os.sh -f wine_runtime

# 对Wine runtime进行打包。
./pack_os.sh -f wine_runtime
