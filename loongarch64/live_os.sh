#!/bin/bash -e

export NEW_TARGET_SYSDIR="${PWD}/workbase"
export BASE_DIR="${PWD}"

declare UPDATE_MODE=FALSE
declare DISTRO_LABEL=""

while getopts 'ul:' OPT; do
    case $OPT in
        u)
            UPDATE_MODE=TRUE
            ;;
	l)
	    DISTRO_LABEL=$OPTARG
	    ;;
        ?)
            echo "用法: `basename $0` [选项]"
            exit 0
            ;;
    esac
done
shift $(($OPTIND - 1))


if [ "x${1}" == "x" ]; then
	echo "错误：必须指定一个目录。"
	exit 1
fi

LIVE_DIRECTORY="${1}"

if [ ! -d ${LIVE_DIRECTORY} ]; then
	mkdir -pv ${LIVE_DIRECTORY}
fi


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


if [ "x${UPDATE_MODE}" != "xTRUE" ]; then
	for i in boot EFI images
	do
		if [ -d ${LIVE_DIRECTORY}/${i} ]; then
			mv ${LIVE_DIRECTORY}/${i}{,.$(date +%Y%m%d%H%M%S)}
		fi
	done
fi

if [ -d ${NEW_TARGET_SYSDIR}/dist/os/bootimage-squashfs ]; then
	cp -a ${NEW_TARGET_SYSDIR}/dist/os/bootimage-squashfs/{boot,EFI} ${LIVE_DIRECTORY}/
else
	echo "错误：缺少制作LiveUSB的文件，请确认是否完成了系统的制作，可以使用./build.sh完成系统的构建。"
	exit 5
fi

if [ -d ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/ ]; then
	mkdir -p ${LIVE_DIRECTORY}/images
	cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/*.squashfs ${LIVE_DIRECTORY}/images/
else
	echo "错误：缺少LiveUSB所需的文件，可以使用 ./dist_os.sh 命令来准备这些文件。"
	exit 5
fi

echo "# 顺序编号 文件名称" > ${LIVE_DIRECTORY}/images/images.list

declare IMAGE_INDEX=1
for i in boot sysroot
do
	if [ -f ${LIVE_DIRECTORY}/images/${i}.${DISTRO_ARCH}.squashfs ]; then
		echo "${IMAGE_INDEX} ${i}.${DISTRO_ARCH}" >> ${LIVE_DIRECTORY}/images/images.list
	else
		echo "错误：缺少启动核心文件images/${i}.${DISTRO_ARCH}.squashfs，可能导致启动失败！"
		exit 6
	fi
	((IMAGE_INDEX++))
done

for i in $(ls ${LIVE_DIRECTORY}/images/*.squashfs | sed "s@${LIVE_DIRECTORY}/images/@@g" | grep "\.${DISTRO_ARCH}\.squashfs" | sed "s@\.${DISTRO_ARCH}\.squashfs@@g")
do
	if [ "x${i}" == "xboot" ] || [ "x${i}" == "xsysroot" ]; then
		continue
	fi
	echo "# ${IMAGE_INDEX} ${i}.${DISTRO_ARCH}" >> ${LIVE_DIRECTORY}/images/images.list
	((IMAGE_INDEX++))
done


if [ "x${DISTRO_LABEL}" == "x" ]; then
	MD5_1=$(md5sum ${LIVE_DIRECTORY}/images/boot.${DISTRO_ARCH}.squashfs)
	MD5_2=$(md5sum ${LIVE_DIRECTORY}/images/sysroot.${DISTRO_ARCH}.squashfs)
	NEW_LABEL="$(echo ${DISTRO_NAME}_${DISTRO_VERSION}_${MD5_1:0:5}${MD5_2:0:5} | sed "s@ @@g")"
else
	NEW_LABEL="$(echo ${DISTRO_LABEL} | sed "s@ @@g")"
fi

sed -i "/LABEL/s@vmlinux.efi@vmlinux_${NEW_LABEL}.efi @g" ${LIVE_DIRECTORY}/boot/grub/grub.cfg
sed -i "/initrd/s@initramfs.img.gz@initramfs_${NEW_LABEL}.img.gz @g" ${LIVE_DIRECTORY}/boot/grub/grub.cfg
mv ${LIVE_DIRECTORY}/boot/vmlinux{,_${NEW_LABEL}}.efi
mv ${LIVE_DIRECTORY}/boot/initramfs{,_${NEW_LABEL}}.img.gz

sed -i "s@ LABEL=Sunhaiyong @ LABEL=${NEW_LABEL} @g" ${LIVE_DIRECTORY}/boot/grub/grub.cfg
echo "${NEW_LABEL}" > ${LIVE_DIRECTORY}/LABEL
sed -i "/ quiet/s@ quiet@ quiet amdgpu.dpm=0 @g" ${LIVE_DIRECTORY}/boot/grub/grub.cfg
cp -a ${BASE_DIR}/docs ${LIVE_DIRECTORY}/ 

echo "Live USB系统导出完成，存放在 ${LIVE_DIRECTORY} , 准备一个第一分区为VFAT格式空分区的U盘，将 ${LIVE_DIRECTORY} 目录中所有内容复制到U盘的第一分区中，该U盘即可在支持UEFI的机器上作为LiveUSB启动。"
