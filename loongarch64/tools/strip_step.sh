#!/bin/bash

export NEW_TARGET_SYSDIR="${PWD}/workbase"
export BASE_DIR="${PWD}"
export STRIP_STEP_NAME=""
export STRIP_DIR=""

if [ "x${1}" == "x" ]; then
	echo "没有指定步骤名称!"
	exit 1
fi
STRIP_STEP_NAME="${1}"

if [ "x${2}" == "x" ]; then
	echo "没有指定需要清理调试信息的目录。"
	exit 2
fi
STRIP_DIR="${2}"

echo "清理 ${STRIP_DIR} 目录内文件的调试信息..."
echo "清理 ${STRIP_DIR} 目录内文件的调试信息..." > ${BASE_DIR}/logs/strip_${STRIP_STEP_NAME}.log
source ${BASE_DIR}/env/${STRIP_STEP_NAME}/config

if [ -d ${STRIP_DIR} ]; then
	pushd ${STRIP_DIR} > /dev/null
		for dir_i in $(find -name "lib" -o -name "lib64" -o -name "lib32" -o -name "share")
		do
			if [ -d ${dir_i} ]; then
				echo "find ${dir_i} -type f -name \*.a -exec ${CROSS_TARGET}-strip --strip-debug {} ';'" >> ${BASE_DIR}/logs/strip_${STRIP_STEP_NAME}.log
				find ${dir_i} -type f -name \*.a -exec ${CROSS_TARGET}-strip --strip-debug {} 2>> ${BASE_DIR}/logs/strip_${STRIP_STEP_NAME}.log ';'
				echo "find ${dir_i} -type f -name \*.so* -exec ${CROSS_TARGET}-strip --strip-unneeded {} ';'" >> ${BASE_DIR}/logs/strip_${STRIP_STEP_NAME}.log
				find ${dir_i} -type f -name \*.so* -exec ${CROSS_TARGET}-strip --strip-unneeded {} 2>> ${BASE_DIR}/logs/strip_${STRIP_STEP_NAME}.log ';'
			fi
		done
		for dir_i in $(find -name "bin" -o -name "sbin" -o -name "libexec")
		do
			if [ -d ${dir_i} ]; then
				echo "find ${dir_i} -type f -exec ${CROSS_TARGET}-strip --strip-all {} ';'" >> ${BASE_DIR}/logs/strip_${STRIP_STEP_NAME}.log
				find ${dir_i} -type f -exec ${CROSS_TARGET}-strip --strip-all {} 2>> ${BASE_DIR}/logs/strip_${STRIP_STEP_NAME}.log ';'
			fi
		done
	popd > /dev/null
else
	echo "没有找到 ${STRIP_DIR} 目录，请检查是否制定了正确的路径。"
fi
