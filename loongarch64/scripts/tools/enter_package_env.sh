#!/bin/bash -e

if [ "x${1}" == "x" ]; then
        echo "必须指定一个包路径。"
        exit 1
fi

export NEW_TARGET_SYSDIR="${PWD}/workbase"
export BASE_DIR="${PWD}"

function get_overlay_dirname
{
	declare OVERLAY_DIR=""

	OVERLAY_DIR=$(cat ${1} | grep "overlay_dir=" | head -n1 | gawk -F'=' '{ print $2 }')
	echo "${OVERLAY_DIR}"
}

function overlay_mount
{
	declare LOWERDIR_LIST
	declare OVERLAY_PARENT_LIST
	declare OVERLAY_DIR=""

	echo "准备 ${1} 步骤的目录..."

	LOWERDIR_LIST="${NEW_TARGET_SYSDIR}/overlaydir/.lowerdir"
	OVERLAY_DIR=$(get_overlay_dirname ${2})
	OVERLAY_PARENT_LIST=$(cat ${2} | grep "parent_dirs=" | head -n1 | gawk -F'=' '{ print $2 }')
	if [ "x${OVERLAY_PARENT_LIST}" != "x" ]; then
		for i in ${OVERLAY_PARENT_LIST}
		do
			if [ ! -d ${NEW_TARGET_SYSDIR}/overlaydir/${i} ]; then
				mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${i}
			fi
			LOWERDIR_LIST=${LOWERDIR_LIST}:${NEW_TARGET_SYSDIR}/overlaydir/${i}
		done
	fi

	if [ "x${OVERLAY_DIR}" == "x" ]; then
		mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${1}
		OVERLAY_DIR=${1}
	fi
	mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}
	sync
	sudo mount -t overlay overlay -o lowerdir=${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
	if [ "x$?" != "x0" ]; then
		echo "挂载sysroot错误！"
		echo "sudo mount -t overlay overlay -o lowerdir=${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
		exit -2
	fi
}

function overlay_umount
{
	sudo umount -R ${NEW_TARGET_SYSDIR}/sysroot
	if [ "x$?" != "x0" ]; then
		echo "卸载sysroot错误！"
		echo "sudo umount -R ${NEW_TARGET_SYSDIR}/sysroot"
		exit -2
	fi
	sync
}

STEP_STAGE=$(echo ${1} | awk -F'/' '{ print $1 }')
STEP_PACKAGE=$(echo ${1} | awk -F'/' '{ print $2 }')

if [ "x${STEP_PACKAGE}" == "x" ]; then
	if [ ! -d scripts/step/${STEP_STAGE} ]; then
		echo "没有${STEP_STAGE}组对应的环境。"
		exit 2
	fi
else
	PACKAGE_FILE=scripts/step/${1}

	if [ ! -f ${PACKAGE_FILE} ]; then
		echo "没有${PACKAGE_FILE}脚本文件。"
		exit 2
	fi
fi


while mount | grep "overlay on ${NEW_TARGET_SYSDIR}/sysroot type " > /dev/null
do
	echo "卸载已挂载的目录 ${NEW_TARGET_SYSDIR}/sysroot ..."
	overlay_umount
done


if [ -f env/${STEP_STAGE}/overlay.set ]; then
	overlay_mount ${STEP_STAGE} env/${STEP_STAGE}/overlay.set
fi

if [ "x${STEP_PACKAGE}" != "x" ]; then
	for i in $(cat ${PACKAGE_FILE} | grep "^source " | sed "s@^source @@g")
	do
		if [ -f $i ]; then
	        	source $i
		else
			echo "找不到$i文件！"
			exit 3
		fi
	done
else
	source env/${STEP_STAGE}/config
	source env/distro.info
fi
export

cd ${BUILD_DIRECTORY}
export PS1='\u:\w\$ '

bash 

while mount | grep "overlay on ${NEW_TARGET_SYSDIR}/sysroot type " > /dev/null
do
	echo "卸载已挂载的目录 ${NEW_TARGET_SYSDIR}/sysroot ..."
	overlay_umount
done

