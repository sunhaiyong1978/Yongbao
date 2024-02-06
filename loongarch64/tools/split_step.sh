#!/bin/bash

export NEW_TARGET_SYSDIR="${PWD}/workbase"
export BASE_DIR="${PWD}"
export SPLIT_STEP_NAME=""
export SPLIT_DIR=""

if [ "x${1}" == "x" ]; then
	echo "没有指定步骤名称!"
	exit 1
fi
SPLIT_STEP_NAME="${1}"

if [ "x${2}" == "x" ]; then
	echo "没有指定需要拆分的目录。"
	exit 2
fi
SPLIT_DIR="${2}"

echo "拆分 ${SPLIT_DIR} 目录..."
echo "拆分 ${SPLIT_DIR} 目录..." > ${BASE_DIR}/logs/split_${SPLIT_STEP_NAME}.log

if [ -d ${SPLIT_DIR} ]; then
	if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${SPLIT_STEP_NAME}.split ]; then
		cat ${NEW_TARGET_SYSDIR}/overlaydir/${SPLIT_STEP_NAME}.split | sort | uniq | while read line_split
		do
			SPLIT_PART_NAME=$(echo "${line_split}" | awk -F'	' '{ print $1 }')
			if [ "x${SPLIT_PART_NAME}" == "x" ]; then
				echo "没有设置拆分目标名。"
				exit 3
			fi
			SPLIT_DIRECTORY=$(echo "${line_split}" | awk -F'	' '{ print $2 }')
			if [ ! -d ${SPLIT_DIR}/./${SPLIT_DIRECTORY} ]; then
				"警告：${SPLIT_DIR}/./${SPLIT_DIRECTORY} 目录不存在, 跳过这条处理步骤，继续后面的步骤。"
				continue
			fi
			SPLIT_MATCH_RULE=$(echo "${line_split}" | awk -F'	' '{ print $3 }')
			if [ "x${SPLIT_MATCH_RULE}" == "x" ]; then
				SPLIT_MATCH_RULE="*"
			fi

			mkdir -p ${SPLIT_DIR}.${SPLIT_PART_NAME}/./${SPLIT_DIRECTORY}
			RUN_COMMAND="mv ${SPLIT_DIR}/./${SPLIT_DIRECTORY}/${SPLIT_MATCH_RULE} ${SPLIT_DIR}.${SPLIT_PART_NAME}/./${SPLIT_DIRECTORY}/"
			echo "${RUN_COMMAND}"
#			set -x
			eval ${RUN_COMMAND}
#			set +x
		done
	else
		echo "没有找到 ${NEW_TARGET_SYSDIR}/overlaydir/${SPLIT_STEP_NAME}.split 拆分文件，将使用默认的拆分方式。"
	fi
else
	echo "没有找到 ${SPLIT_DIR} 目录，请检查是否制定了正确的路径。"
fi
