#!/bin/bash

#使用示例：tools/pack_archive_dir.sh ${BASE_DIR}/workbase/overlaydir_strip/sysroot "sysroot" squashfs Yongbao 1.0 loongarch64

export BASE_DIR="${PWD}"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"

export ARCHIVE_STEP_NAME=""
export ARCHIVE_DIR=""


declare FORCE_CREATE=FALSE
declare WORLD_PARM=""

while getopts 'fwh' OPT; do
    case $OPT in
        f)
            FORCE_CREATE=TRUE
            ;;
	w)
	    NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	    NEW_BASE_DIR="${BASE_DIR}"
	    RELEASE_BUILD_MODE=0
	    WORLD_PARM="-w"
#	    echo "强制指定使用主线环境中进行打包。"
	    ;;
        h|?)
            echo "用法: `basename $0` [选项] 需打包目录 打包方式 发行版名称 发行版版本 架构名称"
	    echo ""
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
	    echo "    -w: 强制在主线环境中进行打包，不指定该参数将使用 current_branch 指定的分支环境中进行打包，若不存在 current_branch 文件则默认对主线环境进行打包。"
            exit 0
            ;;
    esac
done
shift $(($OPTIND - 1))

if [ "x${WORLD_PARM}" == "x" ]; then
	if [ -f ${BASE_DIR}/current_branch ]; then
		RELEASE_VERSION="$(cat ${BASE_DIR}/current_branch | grep -v "^#" | grep -v "^$" | head -n1 | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")"
		if [ -d ${BASE_DIR}/Branch_${RELEASE_VERSION} ]; then
			NEW_TARGET_SYSDIR="${BASE_DIR}/Branch_${RELEASE_VERSION}/workbase"
			NEW_BASE_DIR="${BASE_DIR}/Branch_${RELEASE_VERSION}"
			RELEASE_BUILD_MODE=1
		else
			NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
			NEW_BASE_DIR="${BASE_DIR}"
			RELEASE_BUILD_MODE=0
		fi
	else
		NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
		NEW_BASE_DIR="${BASE_DIR}"
		RELEASE_BUILD_MODE=0
	fi
fi


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
			if [ -f /usr/bin/mksquashfs ]; then
				MKSQUASHFS=/usr/bin/mksquashfs
			fi
			if [ -f /sbin/mksquashfs ]; then
				MKSQUASHFS=/sbin/mksquashfs
			fi
			mkdir -p ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/
			if [ ! -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/${ARCHIVE_STEP_NAME}.${ARCHIVE_ARCH_NAME}.squashfs ] || [ "x${FORCE_CREATE}" == "xTRUE" ]; then
				rm -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/${ARCHIVE_STEP_NAME}.${ARCHIVE_ARCH_NAME}.squashfs
				${MKSQUASHFS} ${ARCHIVE_DIR} ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/${ARCHIVE_STEP_NAME}.${ARCHIVE_ARCH_NAME}.squashfs -all-root -comp xz
				echo ""
				echo "${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/${ARCHIVE_STEP_NAME}.${ARCHIVE_ARCH_NAME}.squashfs 文件创建完成。"
			else
				echo "${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/${ARCHIVE_STEP_NAME}.${ARCHIVE_ARCH_NAME}.squashfs 文件已创建。"
			fi
			;;
		tar)
			pushd ${ARCHIVE_DIR} > /dev/null
			mkdir -p ${NEW_TARGET_SYSDIR}/dist/os/tar/
			if [ ! -f ${NEW_TARGET_SYSDIR}/dist/os/tar/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.tar.xz ] || [ "x${FORCE_CREATE}" == "xTRUE" ]; then
				rm -f ${NEW_TARGET_SYSDIR}/dist/os/tar/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.tar.xz
				tar --checkpoint=200 --checkpoint-action=dot --xattrs-include='*' --owner=root --group=root -caf ${NEW_TARGET_SYSDIR}/dist/os/tar/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.tar.xz *
				echo ""
				echo "${NEW_TARGET_SYSDIR}/dist/os/tar/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.tar.xz 文件创建完成。"
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
