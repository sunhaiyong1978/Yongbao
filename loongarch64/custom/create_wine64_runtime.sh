#!/bin/bash -e

# 筛选编译Wine所需要的host-tools工具集。
mkdir -p steps
./build.sh -x -o -f_opt,-g_opt,wine -i steps/wine_runtime_host_requires.index -g host-tools
sed -i "/step\/target_base/d" steps/wine_runtime_host_requires.index
sed -i -e "/cross-tools\/gcc/d" \
       -e "/cross-tools\/binutils/d" \
       -e "/cross-tools\/grub/d" \
       -e "/cross-tools\/gdb/d" \
       -e "/cross-tools\/qemu/d" \
       steps/wine_runtime_host_requires.index
./build.sh -i steps/wine_runtime_host_requires.index


# 编译与wine相关的交叉工具链
./build.sh -o wine64 -g cross-toolchains

# 编译wine64_runtime环境的软件包
./build.sh wine64_runtime

# Strip二进制的调试信息
./strip_os.sh -f wine64_runtime

# 对Wine64 runtime进行打包。
./pack_os.sh -f wine64_runtime
