# 创建传统方式的wine
# # ./build.sh -O i686_runtime,x86_64-v2_runtime -S test -e target=x86_64-v2,target_32=i686 simulate/wine
# ./build.sh -e target=x86_64-v3,target_32=i686 -O ORIG,x86_64-v3_runtime,i686_runtime simulate/wine

# 创建wow方式的wine
# ./build.sh -e target=x86_64-v3,target_mingw64=mingw64ucrt,target_mingw32=mingw32 -O ORIG,x86_64-v3_runtime,mingw64ucrt_sysroot,mingw32_sysroot simulate/wine_wow

# 编译64位的dxvk
# ./build.sh -e target=x86_64-v3,target_mingw=mingw64ucrt -O x86_64-v3_runtime,mingw64ucrt_sysroot simulate/dxvk

# 编译32位的dxvk
./build.sh -e target=i686,target_mingw=mingw32 -O i686_runtime,mingw32_sysroot simulate/dxvk
