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
# source ${BASE_DIR}/env/${STRIP_STEP_NAME}/config

if [ -d ${STRIP_DIR} ]; then
	if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${STRIP_STEP_NAME}.strip ]; then
		cat ${NEW_TARGET_SYSDIR}/overlaydir/${STRIP_STEP_NAME}.strip | sort | uniq | while read line_strip
		do
			STRIP_SET_DIRECTORY=$(echo "${line_strip}" | awk -F'	' '{ print $1 }')
			if [ "x${STRIP_SET_DIRECTORY}" == "x" ]; then
				echo "没有设置处理目录。"
				exit 3
			fi
			if [ ! -d ${STRIP_DIR}/./${STRIP_SET_DIRECTORY} ]; then
				"警告：${STRIP_DIR}/./${STRIP_SET_DIRECTORY} 目录不存在, 跳过这条处理步骤，继续后面的步骤。"
				continue
			fi
			STRIP_SET_DIRECTORY_DEPTH=$(echo "${line_strip}" | awk -F'	' '{ print $2 }')
			STRIP_SET_FILES=$(echo "${line_strip}" | awk -F'	' '{ print $3 }')
			STRIP_SET_COMMAND=$(echo "${line_strip}" | awk -F'	' '{ print $4 }')
			if [ "x$(echo ${STRIP_SET_COMMAND} | grep "^${NEW_TARGET_SYSDIR}/\(.*\)-strip")" == "x" ]; then
				echo "尝试进行处理的命令 ${STRIP_SET_COMMAND} 不以 ${NEW_TARGET_SYSDIR} 绝对路径开头，或者命令不以strip结尾，不继续进行处理，请检查。"
				exit 5
			fi
			STRIP_SET_COMMAND_PARM=$(echo "${line_strip}" | awk -F'	' '{ print $5 }')
			pushd ${STRIP_DIR} > /dev/null
				case "${STRIP_SET_DIRECTORY_DEPTH}" in
					1)
						echo "将对 ${PWD}/./${STRIP_SET_DIRECTORY} 中的 ${STRIP_SET_FILES} 文件使用 ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} 进行处理。" >> ${BASE_DIR}/logs/strip_${STRIP_STEP_NAME}.log
						RUN_COMMAND="find ${PWD}/./${STRIP_SET_DIRECTORY} -maxdepth ${STRIP_SET_DIRECTORY_DEPTH} -type f -name '"${STRIP_SET_FILES}"' -exec ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} {} 2>> ${BASE_DIR}/logs/strip_${STRIP_STEP_NAME}.log ';'"
						set -x
						eval "${RUN_COMMAND}"
						set +x
						;;
					0)
						echo "将对 ${PWD}/./${STRIP_SET_DIRECTORY} 中及其之下所有目录中的 ${STRIP_SET_FILES} 文件使用 ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} 进行处理。" >> ${BASE_DIR}/logs/strip_${STRIP_STEP_NAME}.log
						RUN_COMMAND="find ${PWD}/./${STRIP_SET_DIRECTORY} -type f -name '"${STRIP_SET_FILES}"' -exec ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} {} 2>> ${BASE_DIR}/logs/strip_${STRIP_STEP_NAME}.log ';'"
						set -x
						eval "${RUN_COMMAND}"
						set +x
						;;
					*)
						echo "${PWD}/./${STRIP_SET_DIRECTORY} 设置的目录深度不适用，请使用 0(表示全部目录) 和 1(仅当前目录) 。"
						;;
				esac


			popd > /dev/null
		done
	else
		echo "没有找到 ${NEW_TARGET_SYSDIR}/overlaydir/${STRIP_STEP_NAME}.strip 处理流程文件，将使用默认的清理流程。"
		pushd ${STRIP_DIR} > /dev/null
			source ${BASE_DIR}/env/target_base/config
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
	fi
else
	echo "没有找到 ${STRIP_DIR} 目录，请检查是否制定了正确的路径。"
fi
