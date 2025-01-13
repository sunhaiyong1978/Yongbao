#!/bin/bash

BASE_DIR="${PWD}"

while getopts 'hf' OPT; do
	case $OPT in
		f)
			WRITE_FORCE=1
			;;
		h)
			echo "用法: `basename $0` [-f] 版本名 "
			exit 0
			;;
		?)
			echo "用法: `basename $0` [-f] 版本名 "
			exit -1
			;;
	esac
done
shift $(($OPTIND - 1))

VERSION_NAME=""
if [ "x${1}" == "x" ]; then
	echo "未指定版本名，使用当前 env/distro.info 中 DISTRO_VERSION 作为版本名。"
else
	VERSION_NAME="$(echo ${1} | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")"
fi
echo "VERSION_NAME=${VERSION_NAME}"
if [ "x${VERSION_NAME}" == "x" ]; then
	VERSION_NAME="$(cat env/distro.info | grep "^DISTRO_VERSION=" | awk -F'=' '{ print $2 }' | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")"
fi


if [ ! -d ${BASE_DIR}/Branch_${VERSION_NAME} ]; then
	echo -n "创建 Branch_${VERSION_NAME} 目录..."
	mkdir -p Branch_${VERSION_NAME}
	echo "完成。"
else
	echo "Branch_${VERSION_NAME} 目录已存在，不能继续创建。"
#	exit -2
fi

ENV_DIR=${BASE_DIR}/Branch_${VERSION_NAME}/env
SCRIPTS_DIR=${BASE_DIR}/Branch_${VERSION_NAME}/scripts
FILES_DIR=${BASE_DIR}/Branch_${VERSION_NAME}/files
SOURCES_DIR=${BASE_DIR}/Branch_${VERSION_NAME}/sources


if [ ! -d ${BASE_DIR}/Branch_${VERSION_NAME}/env ]; then
	cp -a ${BASE_DIR}/env ${BASE_DIR}/Branch_${VERSION_NAME}/
fi
if [ ! -d ${BASE_DIR}/Branch_${VERSION_NAME}/scripts ]; then
	cp -a ${BASE_DIR}/scripts ${BASE_DIR}/Branch_${VERSION_NAME}/
fi
if [ ! -d ${BASE_DIR}/Branch_${VERSION_NAME}/files ]; then
	cp -a ${BASE_DIR}/files ${BASE_DIR}/Branch_${VERSION_NAME}/
fi
if [ ! -d ${BASE_DIR}/Branch_${VERSION_NAME}/sources ]; then
	cp -a ${BASE_DIR}/sources ${BASE_DIR}/Branch_${VERSION_NAME}/
fi
if [ ! -d ${BASE_DIR}/Branch_${VERSION_NAME}/docs ]; then
	cp -a ${BASE_DIR}/docs ${BASE_DIR}/Branch_${VERSION_NAME}/
fi
if [ ! -f ${BASE_DIR}/Branch_${VERSION_NAME}/step ]; then
	cp -a ${BASE_DIR}/step ${BASE_DIR}/Branch_${VERSION_NAME}/
fi
if [ ! -f ${BASE_DIR}/Branch_${VERSION_NAME}/info_set ]; then
	cp -a ${BASE_DIR}/info_set ${BASE_DIR}/Branch_${VERSION_NAME}/
fi

mkdir -p ${BASE_DIR}/Branch_${VERSION_NAME}/downloads/sources/{files,hash}


if [ -f ${BASE_DIR}/current_branch ]; then
	if [ "x${WRITE_FORCE}" != "x1" ]; then
		echo "当前 current_branch 已经存在，指定版本名为“$(cat ${BASE_DIR}/current_branch | grep -v "^#" | grep -v "^$" | head -n1 | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")”，请使用-f参数进行强制更新，或手工进行修改。"
		exit 0
	fi
fi
echo "${VERSION_NAME}" > ${BASE_DIR}/current_branch
echo "current_branch 文件内容已更新。"
exit 0
