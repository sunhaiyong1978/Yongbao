# ./build.sh -o mingw -g mingw_sysroot
# ./build.sh -o mingw -e host=mingw64,target=loongarch64 toolchain
./build.sh -e host=mingw64ucrt,target=loongarch64 toolchain
