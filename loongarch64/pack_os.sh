#!/bin/bash -e

export NEW_TARGET_SYSDIR="${PWD}/workbase"
export BASE_DIR="${PWD}"

declare FORCE_CREATE=FALSE
declare ARCHIVE_MODE="squashfs"
declare OVERLAY_NAME=""

while getopts 'fm:h' OPT; do
    case $OPT in
        f)
            FORCE_CREATE=TRUE
            ;;
	m)
            ARCHIVE_MODE=$OPTARG
            ;;
        h|?)
            echo "用法: `basename $0` [选项] [目录名]"
            echo "目录名: "
            echo -n "    目前可用的目录名有: "
            for i in $(cat ${BASE_DIR}/env/*/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }' | sort | uniq)
            do
                   echo -n "${i} "
            done
            echo "    不指定目录名将处理所有的目录。"
            echo ""
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
            echo "    -f: 将原有目录进行重命名，并重新进行目标系统的打包工作。"
            echo "    -m <模式名> 设置打包模式，目前可用的打包模式名有tar和squashfs。"

            exit 0
            ;;
    esac
done
shift $(($OPTIND - 1))

case "x${ARCHIVE_MODE}" in
	xtar | xsquashfs)
		;;
	*)
		echo "打包模式指定错误，目前只支持tar和squashfs模式。"
		exit 1
		;;
esac

if [ "x${1}" != "x" ]; then
	OVERLAY_NAME="${1}"
fi

if [ -d ${BASE_DIR}/workbase/overlaydir_strip ]; then

	for i in $(cat ${BASE_DIR}/env/*/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }' | sort | uniq)
	do
		if [ "x${OVERLAY_NAME}" != "x" ]; then
			if [ "x${i}" != "x${OVERLAY_NAME}" ]; then
				continue
			fi
		fi
		echo "制作 $i 打包文件..."
		if [ -d ${BASE_DIR}/workbase/overlaydir_strip/$i ]; then
			DISTRO_NAME=$(grep -r "^DISTRO_NAME=" env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
			if [ "x${DISTRO_NAME}" == "x" ]; then
				echo "无法获取操作系统名称，无法继续，请编辑env/distro.info文件，并增加DISTRO_NAME的定义。"
				exit 3
			fi
			DISTRO_ARCH=$(grep -r "^DISTRO_ARCH=" env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
			if [ "x${DISTRO_ARCH}" == "x" ]; then
				echo "缺少架构名称，无法继续，请编辑env/distro.info文件，并增加DISTRO_ARCH的定义。"
				exit 3
			fi
			DISTRO_VERSION=$(grep -r "^DISTRO_VERSION=" env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
			if [ "x${DISTRO_VERSION}" == "x" ]; then
				echo "缺少系统的版本号，无法继续，请编辑env/distro.info文件，并增加DISTRO_VERSION的定义。"
				exit 3
			fi
			if [ "x${ARCHIVE_MODE}" == "x" ]; then
				ARCHIVE_MODE=$(grep -r "^DISTRO_ARCHIVE_MODE=" env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
				if [ "x${ARCHIVE_MODE}" == "x" ]; then
					ARCHIVE_MODE=$(grep -r "^DEFAULT=" env/archive | tail -n1 | awk -F'=' '{ print $2 }')
					if [ "x${ARCHIVE_MODE}" == "x" ]; then
						echo "缺少打包系统方式的设置，请编辑env/distro.info文件，并增加DISTRO_ARCHIVE_MODE的定义,当前将默认设置为squashfs。"
						ARCHIVE_MODE=squashfs
					fi
				fi
			fi

			STEP_NAME=""
			if [ -f env/${i}.info ]; then
				STEP_NAME=$(grep -r "^$i_NAME=" env/${i}.info | tail -n1 | awk -F'=' '{ print $2 }')
			fi
			if [ "x${STEP_NAME}" == "x" ]; then
				STEP_NAME=${i}
			fi

			if [ "x${FORCE_CREATE}" == "xTRUE" ]; then
				tools/pack_archive_dir.sh -f ${BASE_DIR}/workbase/overlaydir_strip/$i "${STEP_NAME}" ${ARCHIVE_MODE} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
			else
				tools/pack_archive_dir.sh ${BASE_DIR}/workbase/overlaydir_strip/$i "${STEP_NAME}" ${ARCHIVE_MODE} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
			fi
		else
			echo "警告：${BASE_DIR}/workbase/overlaydir_strip/ 目录中没有 $i 目录，跳过！"
		fi
	done
else
	echo "没有发现可以用来打包的系统目录，请检查${BASE_DIR}/workbase/overlaydir_strip目录是否存在，你可以通过strip_os.sh脚本生成该目录。"
	exit 1
fi


