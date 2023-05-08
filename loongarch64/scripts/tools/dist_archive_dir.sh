#!/bin/bash

#使用示例：scripts/tools/dist_archive_dir.sh ${BASE_DIR}/workbase/overlaydir_strip/sysroot "sysroot" squashfs Yongbao 1.0 loongarch64

export NEW_TARGET_SYSDIR="${PWD}/workbase"
export BASE_DIR="${PWD}"
export ARCHIVE_STEP_NAME=""
export ARCHIVE_DIR=""


declare FORCE_CREATE=FALSE

while getopts 'fh' OPT; do
    case $OPT in
        f)
            FORCE_CREATE=TRUE
            ;;
        h|?)
            echo "用法: `basename $0` [选项] 需打包目录 打包方式 发行版名称 发行版版本 架构名称"
            exit 0
            ;;
    esac
done
shift $(($OPTIND - 1))


if [ "x${1}" == "x" ]; then
	echo "没有制定需要打包的目录。"
	exit 1
fi
ARCHIVE_DIR="${1}"

if [ "x${2}" == "x" ]; then
	echo "没有指定步骤名称!"
	exit 2
fi
ARCHIVE_STEP_NAME="${2}"

if [ "x${3}" == "x" ]; then
	echo "没有指定打包模式!"
	exit 3
fi
ARCHIVE_MODE="${3}"

if [ "x${4}" == "x" ]; then
	echo "没有指定发行版名称!"
	exit 4
fi
ARCHIVE_OS_NAME="${4}"

if [ "x${5}" == "x" ]; then
	echo "没有指定发行版版本!"
	exit 5
fi
ARCHIVE_OS_VERSION="${5}"

if [ "x${6}" == "x" ]; then
	echo "没有指定指令集架构!"
	exit 6
fi
ARCHIVE_ARCH_NAME="${6}"

echo "正在使用 ${ARCHIVE_MODE} 方式打包 ${ARCHIVE_DIR} 目录中的文件..."

if [ -d ${ARCHIVE_DIR} ]; then
	case "${ARCHIVE_MODE}" in
		squashfs)
			mkdir -p ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/
			if [ ! -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/${ARCHIVE_STEP_NAME}.${ARCHIVE_ARCH_NAME}.squashfs ] || [ "x${FORCE_CREATE}" == "xTRUE" ]; then
				rm -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/${ARCHIVE_STEP_NAME}.${ARCHIVE_ARCH_NAME}.squashfs
				/sbin/mksquashfs ${ARCHIVE_DIR} ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/${ARCHIVE_STEP_NAME}.${ARCHIVE_ARCH_NAME}.squashfs -all-root -comp xz
			else
				echo "${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/${ARCHIVE_STEP_NAME}.${ARCHIVE_ARCH_NAME}.squashfs 文件已创建。"
			fi
			;;
		tar)
			pushd ${ARCHIVE_DIR} > /dev/null
			mkdir -p ${NEW_TARGET_SYSDIR}/dist/os/tar/
			if [ ! -f ${NEW_TARGET_SYSDIR}/dist/os/tar/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.tar.xz ] || [ "x${FORCE_CREATE}" == "xTRUE" ]; then
				rm -f ${NEW_TARGET_SYSDIR}/dist/os/tar/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.tar.xz
				tar --xattrs-include='*' --owner=root --group=root -cJf ${NEW_TARGET_SYSDIR}/dist/os/tar/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.tar.xz *
			else
				echo "${NEW_TARGET_SYSDIR}/dist/os/tar/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.tar.xz 文件已创建。"
			fi
			popd > /dev/null
			;;
		*)
			echo "不支持 ${ARCHIVE_MODE} 的打包模式。"
			exit 7
			;;
	esac

	pushd ${ARCHIVE_DIR} > /dev/null
		
	popd > /dev/null
else
	echo "没有找到 ${ARCHIVE_DIR} 目录，请检查是否制定了正确的路径。"
fi
