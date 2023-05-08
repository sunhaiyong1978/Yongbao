#!/bin/bash -e

export NEW_TARGET_SYSDIR="${PWD}/workbase"
export BASE_DIR="${PWD}"

while getopts 'h' OPT; do
    case $OPT in
        h|?)
            echo "说明：将首次运行脚本安装到系统中。"
            echo "用法: ./`basename $0`"
            exit 0
            ;;
    esac
done
shift $(($OPTIND - 1))

declare OVERLAY_DIR=""

if [ -d ${BASE_DIR}/workbase/overlaydir_strip ]; then
	for dir in $(ls ${NEW_TARGET_SYSDIR}/scripts/os_first_run/*.run | sed "s@${NEW_TARGET_SYSDIR}/scripts/os_first_run/@@g" | awk -F'.' '{ print $1 }' | sort | uniq)
	do
		if [ ! -f ${BASE_DIR}/env/${dir}/overlay.set ]; then
			echo "${dir} 组没有定义overlay目录，无法安装其中软件包相关的首次启动执行脚本。"
			exit 1
		fi
		OVERLAY_DIR=$(cat ${BASE_DIR}/env/${dir}/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }')
		if [ "x${OVERLAY_DIR}" == "x" ]; then
			echo "${dir} 组没有定义overlay目录，无法安装其中软件包相关的首次启动执行脚本。"
			exit 1
		fi
		if [ ! -d ${BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}/etc/first-run.d/ ]; then
			mkdir -pv ${BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}/etc/first-run.d/
		fi
		for run_file in $(ls ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${dir}.*.run | sed "s@${NEW_TARGET_SYSDIR}/scripts/os_first_run/${dir}\.@@g" | awk -F'.' '{ print $1 }')
		do
			echo -n "正在安装${dir}.${run_file}.run文件到 ${OVERLAY_DIR}/etc/first-run.d/50-$(date +%Y%m%d%H%M%S)-${dir}_${run_file}.sh ..."
			cat ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${dir}.${run_file}.run > ${BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}/etc/first-run.d/50-${run_file}_${dir}_$(date +%Y%m%d%H%M%S).sh
			echo "完成！"
		done

	done

	for dir in $(ls ${NEW_TARGET_SYSDIR}/scripts/os_start_run/*.run | sed "s@${NEW_TARGET_SYSDIR}/scripts/os_start_run/@@g" | awk -F'.' '{ print $1 }' | sort | uniq)
	do
		if [ ! -f ${BASE_DIR}/env/${dir}/overlay.set ]; then
			echo "${dir} 组没有定义overlay目录，无法安装其中软件包相关的首次启动执行脚本。"
			exit 1
		fi
		OVERLAY_DIR=$(cat ${BASE_DIR}/env/${dir}/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }')
		if [ "x${OVERLAY_DIR}" == "x" ]; then
			echo "${dir} 组没有定义overlay目录，无法安装其中软件包相关的首次启动执行脚本。"
			exit 1
		fi

		if [ ! -d ${BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}/etc/start-run.d/ ]; then
			mkdir -pv ${BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}/etc/start-run.d/
		fi
		for run_file in $(ls ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${dir}.*.run | sed "s@${NEW_TARGET_SYSDIR}/scripts/os_start_run/${dir}\.@@g" | awk -F'.' '{ print $1 }')
		do
			echo -n "正在安装${dir}.${run_file}.run文件到 ${OVERLAY_DIR}/etc/start-run.d/50-$(date +%Y%m%d%H%M%S)-${dir}_${run_file}.sh ..."
			cat ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${dir}.${run_file}.run > ${BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}/etc/start-run.d/50-${run_file}_${dir}_$(date +%Y%m%d%H%M%S).sh
			echo "完成！"
		done
	done


else
	echo "没有发现可以用来打包的系统目录，请检查${BASE_DIR}/workbase/overlaydir_strip目录是否存在，你可以通过strip_os.sh脚本生成该目录。"
	exit 1
fi
