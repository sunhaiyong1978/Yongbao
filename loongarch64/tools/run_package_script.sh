#!/bin/bash -e

if [ "x${1}" == "x" ]; then
        echo "必须指定一个包路径。"
        exit 1
fi

export NEW_TARGET_SYSDIR="${PWD}/workbase"
export BASE_DIR="${PWD}"
export OVERLAY_DIR=${NEW_TARGET_SYSDIR}/overlay/$(cat env/${1%%/*}/overlay.set | grep "overlay_dir=" | head -n1 | gawk -F'=' '{ print $2 }')

source env/function.sh

PACKAGE_FILE=scripts/step/${1}

if [ ! -f ${PACKAGE_FILE} ]; then
        echo "没有${PACKAGE_FILE}脚本文件。"
        exit 2
fi

echo -n "正在执行${3}..."
TMP_RUN="$(replace_arch_parm "$(cat ${PACKAGE_FILE})")"
echo "${TMP_RUN}" > ${NEW_TARGET_SYSDIR}/temp/TEMP-run.sh
bash -e -x ${NEW_TARGET_SYSDIR}/temp/TEMP-run.sh
#bash -e -x ${PACKAGE_FILE}
if [ "x$?" == "x0" ]; then
	echo "完成。"
	exit 0
else
	echo "发生了错误，请查看日志文件内容。"
	exit 3
fi

