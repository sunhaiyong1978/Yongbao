#!/bin/bash -e

EXPORT_SHOW=1
EXPORT_ENV_VAR=0

while getopts 'neh' OPT; do
    case $OPT in
        n)
            EXPORT_SHOW=0
            ;;
        e)
            EXPORT_ENV_VAR=1
            ;;
        h|?)
            echo "用法: `basename $0` [-e] 步骤名/软件包名"
    esac
done
shift $(($OPTIND - 1))

if [ "x${1}" == "x" ]; then
        echo "必须指定一个包路径。"
        exit 1
fi

if [ "x${2}" == "x" ]; then
	SUFF=""
else
	if [ "x${2:0:1}" == "x." ]; then
		SUFF="${2}"
	else
		SUFF=".${2}"
	fi
fi

export NEW_TARGET_SYSDIR="${PWD}/workbase"
export BASE_DIR="${PWD}"

source env/function.sh

PACKAGE_FILE=scripts/step/${1}

if [ ! -f ${PACKAGE_FILE} ]; then
	echo "没有${PACKAGE_FILE}脚本文件。"
	exit 2
fi

for i in $(cat ${PACKAGE_FILE} | grep "^source " | sed "s@^source @@g")
do
	if [ -f $i ]; then
	        source $i
	else
		echo "找不到$i文件！"
		exit 3
	fi
done

SHOW_BODY="$(cat ${PACKAGE_FILE}${SUFF})"
if [ "x${EXPORT_SHOW}" == "x1" ]; then
	export

	for i in $(export | awk -F' ' '{ print $3 }' | awk -F'=' '{ print $1 }')
	do
		case ${i} in
			PWD)
				continue;
				;;
			*)
				SHOW_BODY="$(echo "${SHOW_BODY}" | sed "s@\${${i}}@#%%%#${i}#***#@g")"
				;;
		esac
	done
fi

if [ "x${EXPORT_ENV_VAR}" == "x0" ]; then
	SHOW_BODY="$(echo "${SHOW_BODY}" | sed "s@\${@#{@g")"

	SHOW_BODY="$(echo "${SHOW_BODY}" | sed -e "s@#%%%#@\${@g" -e "s@#\*\*\*#@}@g")"
fi

SHOW_BODY="$(replace_arch_parm "$(echo "${SHOW_BODY}")")"

envsubst <<< "${SHOW_BODY}" | sed "s@#{@\${@g"

