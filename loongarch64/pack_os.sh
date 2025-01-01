#!/bin/bash -e

export BASE_DIR="${PWD}"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"

declare FORCE_CREATE=FALSE
declare ARCHIVE_MODE="squashfs"
declare OVERLAY_NAME=""
declare KERNEL_CREATE=TRUE
declare KERNEL_ONLY=FALSE
declare WORLD_PARM=""

while getopts 'fkm:wh' OPT; do
    case $OPT in
        f)
            FORCE_CREATE=TRUE
            ;;
        k)
            KERNEL_ONLY=TRUE
            ;;
	m)
            ARCHIVE_MODE=$OPTARG
            ;;
	w)
	    NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	    NEW_BASE_DIR="${BASE_DIR}"
	    RELEASE_BUILD_MODE=0
	    WORLD_PARM="-w"
	    echo "强制指定使用主线环境中进行打包。"
	    ;;
        h|?)
            echo "用法: `basename $0` [选项] [目录名]"
            echo "目录名: "
            echo -n "    目前可用的目录名有: "
            for i in $(cat ${NEW_BASE_DIR}/env/*/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }' | sort | uniq)
            do
                   echo -n "${i} "
            done
            echo "    不指定目录名将处理所有的目录。"
            echo ""
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
            echo "    -f: 将原有目录进行重命名，并重新进行目标系统的打包工作。"
            echo "    -k: 对内核进行打包工作,制定该参数后“[目录名]”将视作内核的标记名。"
            echo "    -m <模式名> 设置打包模式，目前可用的打包模式名有tar和squashfs。"
	    echo "    -w: 强制在主线环境中进行打包，不指定该参数将使用 current_branch 指定的分支环境中进行打包，若不存在 current_branch 文件则默认对主线环境进行打包。"

            exit 0
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
			echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将在指定目录中进行打包。"
		else
			echo "没有发现 Branch_${RELEASE_VERSION} 目录。"
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


#				DISTRO_NAME=$(grep -r "^DISTRO_NAME=" env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
#				if [ "x${DISTRO_NAME}" == "x" ]; then
#					echo "无法获取操作系统名称，无法继续，请编辑env/distro.info文件，并增加DISTRO_NAME的定义。"
#					exit 3
#				fi
#				DISTRO_ARCH=$(grep -r "^DISTRO_ARCH=" env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
#				if [ "x${DISTRO_ARCH}" == "x" ]; then
#					echo "缺少架构名称，无法继续，请编辑env/distro.info文件，并增加DISTRO_ARCH的定义。"
#					exit 3
#				fi
#				DISTRO_VERSION=$(grep -r "^DISTRO_VERSION=" env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
#				if [ "x${DISTRO_VERSION}" == "x" ]; then
#					echo "缺少系统的版本号，无法继续，请编辑env/distro.info文件，并增加DISTRO_VERSION的定义。"
#					exit 3
#				fi
#				if [ "x${ARCHIVE_MODE}" == "x" ]; then
#					ARCHIVE_MODE=$(grep -r "^DISTRO_ARCHIVE_MODE=" env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
#					if [ "x${ARCHIVE_MODE}" == "x" ]; then
#						ARCHIVE_MODE=$(grep -r "^DEFAULT=" env/archive | tail -n1 | awk -F'=' '{ print $2 }')
#						if [ "x${ARCHIVE_MODE}" == "x" ]; then
#							echo "缺少打包系统方式的设置，请编辑env/distro.info文件，并增加DISTRO_ARCHIVE_MODE的定义,当前将默认设置为squashfs。"
#							ARCHIVE_MODE=squashfs
#						fi
#					fi
#				fi


DISTRO_NAME=$(grep -r "^DISTRO_NAME=" ${NEW_BASE_DIR}/env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
if [ "x${DISTRO_NAME}" == "x" ]; then
	echo "无法获取操作系统名称，无法继续，请编辑 ${NEW_BASE_DIR}/env/distro.info 文件，并增加DISTRO_NAME的定义。"
	exit 3
fi
DISTRO_ARCH=$(grep -r "^DISTRO_ARCH=" ${NEW_BASE_DIR}/env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
if [ "x${DISTRO_ARCH}" == "x" ]; then
	echo "缺少架构名称，无法继续，请编辑 ${NEW_BASE_DIR}/env/distro.info 文件，并增加DISTRO_ARCH的定义。"
	exit 3
fi
DISTRO_VERSION=$(grep -r "^DISTRO_VERSION=" ${NEW_BASE_DIR}/env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
if [ "x${DISTRO_VERSION}" == "x" ]; then
	echo "缺少系统的版本号，无法继续，请编辑 ${NEW_BASE_DIR}/env/distro.info 文件，并增加DISTRO_VERSION的定义。"
	exit 3
fi
if [ "x${ARCHIVE_MODE}" == "x" ]; then
	ARCHIVE_MODE=$(grep -r "^DISTRO_ARCHIVE_MODE=" ${NEW_BASE_DIR}/env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
	if [ "x${ARCHIVE_MODE}" == "x" ]; then
		ARCHIVE_MODE=$(grep -r "^DEFAULT=" ${NEW_BASE_DIR}/env/archive | tail -n1 | awk -F'=' '{ print $2 }')
		if [ "x${ARCHIVE_MODE}" == "x" ]; then
			echo "缺少打包系统方式的设置，请编辑 ${NEW_BASE_DIR}/env/distro.info 文件，并增加DISTRO_ARCHIVE_MODE的定义,当前将默认设置为squashfs。"
			ARCHIVE_MODE=squashfs
		fi
	fi
fi


if [ "x${OVERLAY_NAME}" == "x" ]; then
	if [ "x${KERNEL_CREATE}" == "xTRUE" ]; then
		KERNEL_VERSION=$(cat ${NEW_TARGET_SYSDIR}/common_files/linux-kernel.version)
		if [ "x${KERNEL_VERSION}" != "x" ]; then
        		KERNEL_LIST="$(ls ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION})"
			if [ "x$?" == "x0" ] && [ "x${KERNEL_LIST}" != "x" ]; then
				for kernel_dir in $(ls ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION})
				do
					echo "打包 ${kernel_dir} 内核..."
					if [ "x${FORCE_CREATE}" == "xTRUE" ]; then
						tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${kernel_dir}/img "kernel_${kernel_dir}" ${ARCHIVE_MODE} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
					else
						tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${kernel_dir}/img "kernel_${kernel_dir}" ${ARCHIVE_MODE} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
					fi
				done
			else
                		echo "发现编译内核的版本信息，但未找到对应的内核文件，无法继续！请检查 ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION} 目录中是否存放有内核目录。"
		                exit 6
        		fi
		else
			echo "没有发现构建内核版本的信息，无法打包内核，请确认是否完成内核的编译。"
			exit 7
		fi
	fi
	if [ "x${KERNEL_ONLY}" == "xFALSE" ]; then
		if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip ]; then
			OVERLAY_DIR_LIST=$(find ${NEW_BASE_DIR}/workbase/overlaydir/ -maxdepth 1 -type f -name "*.dist" | awk -F'/' '{ print $NF }' | sed "s@\.dist\$@@g")
			if [ "x${OVERLAY_DIR_LIST}" == "x" ]; then
				echo "没有发现任何需要进行处理的目录。"
				exit 1
			fi

#			for i in $(cat ${NEW_BASE_DIR}/env/*/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }' | sort | uniq)
			for i in ${OVERLAY_DIR_LIST}
			do
				RELEASE_SUFF=""
				if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${i}.released ]; then
					RELEASE_SUFF=".update"
				fi
				echo "制作 ${i}${RELEASE_SUFF} 打包文件..."
				if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${i}${RELEASE_SUFF} ]; then
	
					STEP_NAME=""
					if [ -f ${NEW_BASE_DIR}/env/${i}.info ]; then
						STEP_NAME=$(grep -r "^$i_NAME=" ${NEW_BASE_DIR}/env/${i}.info | tail -n1 | awk -F'=' '{ print $2 }')
					fi
					if [ "x${STEP_NAME}" == "x" ]; then
						STEP_NAME=${i}
					fi

					if [ "x${FORCE_CREATE}" == "xTRUE" ]; then
						tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_BASE_DIR}/workbase/overlaydir_strip/${i}${RELEASE_SUFF} "${STEP_NAME}${RELEASE_SUFF}" ${ARCHIVE_MODE} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
						for j in $(cat ${NEW_BASE_DIR}/workbase/overlaydir/${i}.split | awk -F' ' '{ print $1 }' | sort | uniq)
						do
							if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/$i${RELEASE_SUFF}.$j ]; then
								tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_BASE_DIR}/workbase/overlaydir_strip/$i${RELEASE_SUFF}.$j "${STEP_NAME}${RELEASE_SUFF}.$j" ${ARCHIVE_MODE} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
							fi
						done
					else
						tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_BASE_DIR}/workbase/overlaydir_strip/$i${RELEASE_SUFF} "${STEP_NAME}${RELEASE_SUFF}" ${ARCHIVE_MODE} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
						for j in $(cat ${NEW_BASE_DIR}/workbase/overlaydir/${i}.split | awk -F' ' '{ print $1 }' | sort | uniq)
						do
							if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/$i${RELEASE_SUFF}.$j ]; then
								tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_BASE_DIR}/workbase/overlaydir_strip/$i${RELEASE_SUFF}.$j "${STEP_NAME}${RELEASE_SUFF}.$j" ${ARCHIVE_MODE} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
							fi
						done
					fi
				else
					echo "警告：${NEW_BASE_DIR}/workbase/overlaydir_strip/ 目录中没有 $i${RELEASE_SUFF} 目录，跳过！"
				fi
			done
		else
			echo "没有发现可以用来打包的系统目录，请检查${NEW_BASE_DIR}/workbase/overlaydir_strip目录是否存在，你可以通过strip_os.sh脚本生成该目录。"
			exit 1
		fi
	fi
else
	if [ "x${KERNEL_ONLY}" == "xTRUE" ]; then
		KERNEL_VERSION=$(cat ${NEW_TARGET_SYSDIR}/common_files/linux-kernel.version)
		if [ "x${KERNEL_VERSION}" != "x" ]; then
			if [ -d ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${OVERLAY_NAME} ]; then
				echo "打包 ${OVERLAY_NAME} 内核..."
				if [ "x${FORCE_CREATE}" == "xTRUE" ]; then
					tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${OVERLAY_NAME}/img "kernel_${OVERLAY_NAME}" ${ARCHIVE_MODE} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
				else
					tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${OVERLAY_NAME}/img "kernel_${OVERLAY_NAME}" ${ARCHIVE_MODE} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
				fi
			else
				echo "没有发现 ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${OVERLAY_NAME} 目录，无法继续打包内核。"
		                exit 6
        		fi
		else
			echo "没有发现构建内核版本的信息，无法打包内核，请确认是否完成内核的编译。"
			exit 7
		fi
		exit 0
	fi

	if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME} ]; then
		RELEASE_SUFF=""
		if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${i}.released ]; then
			RELEASE_SUFF=".update"
		fi
		echo "制作 ${OVERLAY_NAME}${RELEASE_SUFF} 打包文件..."
		if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} ]; then

			STEP_NAME=""
			if [ -f ${NEW_BASE_DIR}/env/${OVERLAY_NAME}.info ]; then
				STEP_NAME=$(grep -r "^${OVERLAY_NAME}_NAME=" ${NEW_BASE_DIR}/env/${OVERLAY_NAME}.info | tail -n1 | awk -F'=' '{ print $2 }')
			fi
			if [ "x${STEP_NAME}" == "x" ]; then
				STEP_NAME=${OVERLAY_NAME}
			fi

			if [ "x${FORCE_CREATE}" == "xTRUE" ]; then
				tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} "${STEP_NAME}${RELEASE_SUFF}" ${ARCHIVE_MODE} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
				if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME}.split ]; then
					for j in $(cat ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME}.split | awk -F' ' '{ print $1 }' | sort | uniq)
					do
						if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}.$j ]; then
							tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}.$j "${STEP_NAME}${RELEASE_SUFF}.$j" ${ARCHIVE_MODE} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
						fi
					done
				fi
			else
				tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} "${STEP_NAME}${RELEASE_SUFF}" ${ARCHIVE_MODE} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
				if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME}.split ]; then
					for j in $(cat ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME}.split | awk -F' ' '{ print $1 }' | sort | uniq)
					do
						if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}.$j ]; then
							tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}.$j "${STEP_NAME}${RELEASE_SUFF}.$j" ${ARCHIVE_MODE} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
						fi
					done
				fi
			fi
		fi
	else
		echo "${NEW_BASE_DIR}/workbase/overlaydir_strip 中没有发现 ${OVERLAY_NAME}${RELEASE_SUFF} 目录，跳过。"
	fi

#	if [ "x${OVERLAY_NAME}" != "x" ]; then
#		if [ "x${i}" != "x${OVERLAY_NAME}" ]; then
#			continue
#		fi
#	fi
fi

