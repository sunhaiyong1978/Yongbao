#!/bin/bash

export BASE_DIR="${PWD}"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"
declare WORLD_PARM=""

while getopts 'wh' OPT; do
    case $OPT in
	w)
	    NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	    NEW_BASE_DIR="${BASE_DIR}"
	    RELEASE_BUILD_MODE=0
	    WORLD_PARM="-w"
	    ;;
        h|?)
            echo "目标系统运行准备处理脚本。"
            echo ""
            echo "用法: ./`basename $0` [选项] [步骤名称] [需要处理的目录]"
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
	    echo "    -w: 强制在主线环境中进行处理，不指定该参数将使用 current_branch 指定的分支环境中进行处理，若不存在 current_branch 文件则默认对主线环境进行处理。"
            exit 127
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
#			echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将在指定目录中进行构建。"
		else
#			echo "没有发现 Branch_${RELEASE_VERSION} 目录。"
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


export FIX_STEP_NAME=""
export FINAL_FIX_DIR=""

if [ "x${1}" == "x" ]; then
	echo "没有指定步骤名称!"
	exit 1
fi
FIX_STEP_NAME="${1}"

if [ "x${2}" == "x" ]; then
	echo "没有指定需要处理的目录。"
	exit 2
fi
FINAL_FIX_DIR="${2}"

echo "处理 ${FINAL_FIX_DIR} 目录以符合在目标系统环境中运行..."
mkdir -p ${NEW_TARGET_SYSDIR}/logs/final_fix/
# echo "处理 ${FINAL_FIX_DIR} 目录以符合在目标系统环境中运行..." > ${NEW_TARGET_SYSDIR}/logs/final_fix/final_fix_${FIX_STEP_NAME}.log
# source ${NEW_BASE_DIR}/env/${FIX_STEP_NAME}/config

if [ -d ${FINAL_FIX_DIR} ]; then
# 	PACKAGE_STEP_NAME=""
	STEP_BUILDNAME=""
	if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist ]; then
# 		PACKAGE_STEP_NAME=$(cat ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist)
		source ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist
	fi
# 	if [ "x${PACKAGE_STEP_NAME}" == "x" ]; then
# 		PACKAGE_STEP_NAME="target_base"
#	fi
	if [ "x${STEP_BUILDNAME}" == "x" ]; then
		STEP_BUILDNAME="target_base"
	fi
	pushd ${FINAL_FIX_DIR} > /dev/null
		set -x
		source ${NEW_BASE_DIR}/env/${STEP_BUILDNAME}/config
		if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist ]; then
			source ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist
		fi
		echo "执行默认的处理操作..."
		touch ${TEMP_DIRECTORY}/strip-foo
		sed -i \
			-e "s@bin/${CROSS_TARGET}-@bin/@g" \
			-e "s@${CROSSTOOLS_DIR}/bin@/usr/bin@g" \
			-e "s@${HOST_TOOLS_DIR}/bin@/usr/bin@g" \
			-e "s@${SYSROOT_DIR}/lib@/usr/lib@g" \
			-e "s@${SYSROOT_DIR}/usr@/usr@g" \
			-e "s@${SYSROOT_DIR}@@g" \
			$(file usr/{bin,sbin,libexec}/* | grep "text executable" | awk -F':' '{ print $1 }') \
			$(find usr -type f -name "*.pc" \
			-o -type f -name "*.cmake" \
			-o -type f -name "Makefile*" \
			-o -type f -name "*.service" \
			-o -type f -name "*.pri" \
			-o -type f -name "*.pl" \
			-o -type f -name "*.desktop" \
			-o -type f -name "*.py" \
			) \
			${TEMP_DIRECTORY}/strip-foo
		set +x
	popd > /dev/null

	if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.final_fix ]; then
		echo "发现 ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.final_fix 文件，按照其中的设置对 ${FIX_STEP_NAME} 目录进行追加处理操作..."
		cat ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.final_fix | sort | uniq | while read line_fix
		do
			STRIP_SET_DIRECTORY=$(echo "${line_fix}" | awk -F'	' '{ print $1 }')
			if [ "x${STRIP_SET_DIRECTORY}" == "x" ]; then
				echo "没有设置处理目录。"
				exit 3
			fi
			if [ ! -d ${FINAL_FIX_DIR}/./${STRIP_SET_DIRECTORY} ]; then
				"警告：${FINAL_FIX_DIR}/./${STRIP_SET_DIRECTORY} 目录不存在, 跳过这条处理步骤，继续后面的步骤。"
				continue
			fi
# 			STRIP_SET_DIRECTORY_DEPTH=$(echo "${line_fix}" | awk -F'	' '{ print $2 }')
# 			STRIP_SET_FILES=$(echo "${line_fix}" | awk -F'	' '{ print $3 }')
# 			STRIP_SET_COMMAND=$(echo "${line_fix}" | awk -F'	' '{ print $4 }')
# 			STRIP_SET_COMMAND_PARM=$(echo "${line_fix}" | awk -F'	' '{ print $5 }')
# 			pushd ${FINAL_FIX_DIR} > /dev/null
# 				case "${STRIP_SET_DIRECTORY_DEPTH}" in
# 					1)
# 						echo "将对 ${PWD}/./${STRIP_SET_DIRECTORY} 中的 ${STRIP_SET_FILES} 文件使用 ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} 进行处理。" >> ${NEW_TARGET_SYSDIR}/logs/final_fix/final_fix_${FIX_STEP_NAME}.log
# 						echo "将对 ${PWD}/./${STRIP_SET_DIRECTORY} 中的 ${STRIP_SET_FILES} 文件使用 ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} 进行处理。"
# 						RUN_COMMAND="find ${PWD}/./${STRIP_SET_DIRECTORY} -maxdepth ${STRIP_SET_DIRECTORY_DEPTH} -type f -name '"${STRIP_SET_FILES}"' -exec ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} {} 2>> ${NEW_TARGET_SYSDIR}/logs/final_fix/final_fix_${FIX_STEP_NAME}.log ';'"
# 						set -x
# 						eval "${RUN_COMMAND}"
# 						set +x
# 						;;
# 					0)
# 						echo "将对 ${PWD}/./${STRIP_SET_DIRECTORY} 中及其之下所有目录中的 ${STRIP_SET_FILES} 文件使用 ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} 进行处理。" >> ${NEW_TARGET_SYSDIR}/logs/final_fix/final_fix_${FIX_STEP_NAME}.log
# 						echo "将对 ${PWD}/./${STRIP_SET_DIRECTORY} 中及其之下所有目录中的 ${STRIP_SET_FILES} 文件使用 ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} 进行处理。"
# 						RUN_COMMAND="find ${PWD}/./${STRIP_SET_DIRECTORY} -type f -name '"${STRIP_SET_FILES}"' -exec ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} {} 2>> ${NEW_TARGET_SYSDIR}/logs/final_fix/final_fix_${FIX_STEP_NAME}.log ';'"
# 						set -x
# 						eval "${RUN_COMMAND}"
# 						set +x
# 						;;
# 					*)
# 						echo "${PWD}/./${STRIP_SET_DIRECTORY} 设置的目录深度不适用，请使用 0(表示全部目录) 和 1(仅当前目录) 。"
# 						;;
# 				esac
# 			popd > /dev/null
		done
	fi
else
	echo "没有找到 ${FINAL_FIX_DIR} 目录，请检查是否制定了正确的路径。"
fi
