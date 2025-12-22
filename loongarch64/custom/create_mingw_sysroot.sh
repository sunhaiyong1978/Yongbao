#!/bin/bash -e

# 本脚本可以创建指定架构runtime环境。

declare CREATE_ARCH_NAME="mingw64ucrt"
declare BUILD_ERROR_LIMITE=1
declare FORCE_REBUILD=0

while getopts 'a:fK:h' OPT; do
    case $OPT in
	a)
		CREATE_ARCH_NAME=$OPTARG
		;;
	f)	FORCE_REBUILD=1
		;;
	K)
		BUILD_ERROR_LIMITE=$OPTARG
		;;
	h|?)
		echo "本脚本可以创建指定架构mingw_sysroot环境"
		echo "custom/${0} [选项]"
		echo "-a <架构名> : 指定编译的架构名称。"
		echo "支持架构：mingw64 | mingw64ucrt | mingw32"
		echo "-f : 强制全部重新编译。"
		echo "-K <数字>: 表示允许出错步骤的数量，0表示没有限制。"
		echo "-h: 帮助信息。"
		exit 127
    esac
done
shift $(($OPTIND - 1))

case "${CREATE_ARCH_NAME}" in
	mingw64 | mingw64ucrt | mingw32)
		echo "即将开始构建 ${CREATE_ARCH_NAME} 架构的 sysroot，sysroot 存放目录 workbase/overlay/${CREATE_ARCH_NAME}_sysroot ..."
		# build.sh 是构建脚本
		# -d 参数表示构建前检查并需要下载的软件包，去掉该参数表示构建过程中检查需要的软件包并下载。
		# -o <标记> ，f_opt,g_opt,mingw,mingw_sysroot 为步骤标记，本脚本中不要修改。
		# -g ，根据指定的mingw_sysroot确定依赖的相关软件包和步骤组，本脚本中不要修改。
		# -S <目录名> ，该参数指定编译的结果存放的目录，目录会创建在 workbase/overlay/ 目录中。
		# -e target=<架构名>， 通过target指定创建的mingw_sysroot所用架构。
		# -K [0|1|数字] ，表示允许出错步骤的数量，0表示没有限制。
		if [ "x${FORCE_REBUILD}" == "x1" ]; then
			./build.sh -f -d -o f_opt,g_opt,mingw,mingw_sysroot -g -S ${CREATE_ARCH_NAME}_sysroot -e target=${CREATE_ARCH_NAME} -K ${BUILD_ERROR_LIMITE} mingw_sysroot
		else
			./build.sh -d -o f_opt,g_opt,mingw,mingw_sysroot -g -S ${CREATE_ARCH_NAME}_sysroot -e target=${CREATE_ARCH_NAME} -K ${BUILD_ERROR_LIMITE} mingw_sysroot
		fi
		echo "构建完成，下面开始进行二进制文件的strip，以减少文件体积..."
		./strip_os.sh -f ${CREATE_ARCH_NAME}_sysroot
		echo "处理完成，sysroot 存放在 workbase/overlay_strip/${CREATE_ARCH_NAME}_sysroot ，可通过 ./pack_os.sh 脚本进行打包。"
		;;
	*)
		echo "当前脚本不支持 ${CREATE_ARCH_NAME} 架构的创建！"
		exit 1
		;;
esac
