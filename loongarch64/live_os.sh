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
DISTRO_NAME_CN=$(grep -r "^DISTRO_NAME_CN=" env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
if [ "x${DISTRO_NAME_CN}" == "x" ]; then
        echo "无法获取操作系统中文名称，无法继续，请编辑env/distro.info文件，并增加DISTRO_NAME_CN的定义。"
        exit 3
fi
DISTRO_ARCH_NAME_CN=$(grep -r "^DISTRO_ARCH_NAME_CN=" env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
if [ "x${DISTRO_ARCH_NAME_CN}" == "x" ]; then
        echo "无法获取架构中文名称，无法继续，请编辑env/distro.info文件，并增加DISTRO_ARCH_NAME_CN的定义。"
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

# 复制启动相关文件
if [ -d ${NEW_TARGET_SYSDIR}/dist/os/bootimage-squashfs ]; then
	cp -a ${NEW_TARGET_SYSDIR}/dist/os/bootimage-squashfs/{boot,EFI} ${LIVE_DIRECTORY}/
else
	echo "错误：缺少制作LiveUSB的文件，请确认是否完成了系统的制作，可以使用./build.sh完成系统的构建。"
	exit 5
fi


# 复制所有squashfs文件
if [ -d ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/ ]; then
	mkdir -p ${LIVE_DIRECTORY}/images/update
	if [ -f ${BASE_DIR}/info_set/release_sort ]; then
		for i in $(cat ${BASE_DIR}/info_set/release_sort | grep -v "^#")
		do
			if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.${DISTRO_ARCH}.squashfs ]; then
				cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/
			fi
		done
	else
		if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/*.${DISTRO_ARCH}.squashfs ]; then
			cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/*.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/
		fi
	fi
else
	echo "错误：缺少LiveUSB所需的文件，可以使用 ./pack_os.sh 命令来准备这些文件。"
	exit 5
fi





# 处理基础squashfs文件

echo "# 顺序编号 文件名称" > ${LIVE_DIRECTORY}/images/images.list

declare IMAGE_INDEX=5
for i in boot sysroot
do
	if [ -f ${LIVE_DIRECTORY}/images/${i}.${DISTRO_ARCH}.squashfs ]; then
		echo "${IMAGE_INDEX} ${i}.${DISTRO_ARCH}" >> ${LIVE_DIRECTORY}/images/images.list
		if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${DISTRO_ARCH}.squashfs ]; then
			cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/update/
		fi
		# devel docs etc.
		if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${i}.split ]; then
			for j in $(cat ${NEW_TARGET_SYSDIR}/overlaydir/${i}.split | awk -F'[[:blank:]]' '{ print $1 }' | sort | uniq) 
			do
				if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.${j}.${DISTRO_ARCH}.squashfs ]; then
					cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.${j}.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/
					echo "$((IMAGE_INDEX+1)) ${i}.${j}.${DISTRO_ARCH}" >> ${LIVE_DIRECTORY}/images/images.list
				fi
				if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${j}.${DISTRO_ARCH}.squashfs ]; then
					cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${j}.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/update/
				fi
			done
		fi
	else
		echo "错误：缺少启动核心文件images/${i}.${DISTRO_ARCH}.squashfs，可能导致启动失败！"
		exit 6
	fi
	((IMAGE_INDEX+=10))
done


#根据基础squashfs文件生成LABEL字串。
if [ "x${DISTRO_LABEL}" == "x" ]; then
	MD5_1=$(md5sum ${LIVE_DIRECTORY}/images/boot.${DISTRO_ARCH}.squashfs)
	MD5_2=$(md5sum ${LIVE_DIRECTORY}/images/sysroot.${DISTRO_ARCH}.squashfs)
	NEW_LABEL="$(echo ${DISTRO_NAME}_${DISTRO_VERSION}_${MD5_1:0:5}${MD5_2:0:5} | sed "s@ @@g")"
else
	NEW_LABEL="$(echo ${DISTRO_LABEL} | sed "s@ @@g")"
fi

# 处理各个squashfs文件
if [ -f ${BASE_DIR}/info_set/release_sort ]; then
	for i in $(cat ${BASE_DIR}/info_set/release_sort | grep -v "^#" | sed -e "/^boot$/d" -e "/^sysroot$/d" )
	do
		if [ -f ${LIVE_DIRECTORY}/images/${i}.${DISTRO_ARCH}.squashfs ]; then
			echo "${IMAGE_INDEX} ${i}.${DISTRO_ARCH}" >> ${LIVE_DIRECTORY}/images/images.list
			if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${DISTRO_ARCH}.squashfs ]; then
				cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/update/
			fi
#			for j in devel docs
			if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${i}.split ]; then
				for j in $(cat ${NEW_TARGET_SYSDIR}/overlaydir/${i}.split | awk -F'[[:blank:]]' '{ print $1 }' | sort | uniq)
				do
					if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.${j}.${DISTRO_ARCH}.squashfs ]; then
						cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.${j}.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/
						echo "$((IMAGE_INDEX+1)) ${i}.${j}.${DISTRO_ARCH}" >> ${LIVE_DIRECTORY}/images/images.list
					fi
					if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${j}.${DISTRO_ARCH}.squashfs ]; then
						cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${j}.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/update/
					fi
				done
			fi
			((IMAGE_INDEX+=10))
		fi
	done
else
	for i in $(ls ${LIVE_DIRECTORY}/images/*.squashfs | sed "s@${LIVE_DIRECTORY}/images/@@g" | grep "\.${DISTRO_ARCH}\.squashfs" | sed "s@\.${DISTRO_ARCH}\.squashfs@@g" | awk -F'.' '{ print $1 }')
	do
		if [ "x${i}" == "xboot" ] || [ "x${i}" == "xsysroot" ] || [ "x${i:0:7}" == "xkernel_" ]; then
			continue
		fi
		echo "# ${IMAGE_INDEX} ${i}.${DISTRO_ARCH}" >> ${LIVE_DIRECTORY}/images/images.list
		((IMAGE_INDEX+=10))
	done
fi




# 安装Kernel

KERNEL_VERSION=$(cat ${NEW_TARGET_SYSDIR}/common_files/linux-kernel.version)

if [ "x${KERNEL_VERSION}" != "x" ]; then
	KERNEL_LIST="$(ls ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION})"
	if [ "x$?" == "x0" ] && [ "x${KERNEL_LIST}" != "x" ]; then
		cat > ${LIVE_DIRECTORY}/boot/grub/grub.cfg << EOF
set timeout=5
set theme=\$prefix/themes/starfield/theme.txt

font=\$prefix/fonts/unicode.pf2
if loadfont \$font ; then
  set gfxmode=auto
  set locale_dir=\$prefix/locale
  set lang=zh_CN
fi

terminal_output gfxterm

EOF
		for kernel_dir in $(ls ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION})
		do
			cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/kernel_${kernel_dir}.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/kernel_${KERNEL_VERSION}_${kernel_dir}.${DISTRO_ARCH}.squashfs
			cp ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${kernel_dir}/boot/vmlinux.efi ${LIVE_DIRECTORY}/boot/vmlinux_${KERNEL_VERSION}_${kernel_dir}_${NEW_LABEL}.efi
			cp ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${kernel_dir}/initramfs-squashfs.img.gz ${LIVE_DIRECTORY}/boot/initramfs_${KERNEL_VERSION}_${kernel_dir}_${NEW_LABEL}.img.gz
			cp ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${kernel_dir}/boot/vmlinux.config ${LIVE_DIRECTORY}/boot/vmlinux_${KERNEL_VERSION}_${kernel_dir}_${NEW_LABEL}.config
			cat >> ${LIVE_DIRECTORY}/boot/grub/grub.cfg << EOF
menuentry '${DISTRO_NAME_CN} ${DISTRO_VERSION} ${DISTRO_ARCH_NAME_CN} (Linux ${KERNEL_VERSION}_${kernel_dir})' {
  set gfxpayload=keep
  echo '加载Linux内核……'
  linux /boot/vmlinux_${KERNEL_VERSION}_${kernel_dir}_${NEW_LABEL}.efi LABEL=${NEW_LABEL} quiet amdgpu.dpm=0
  initrd /boot/initramfs_${KERNEL_VERSION}_${kernel_dir}_${NEW_LABEL}.img.gz
  echo '加载完成，开始启动${DISTRO_NAME_CN}系统……'
}
EOF
#		echo "1 kernel_${KERNEL_VERSION}_${kernel_dir}.${DISTRO_ARCH}" >> ${LIVE_DIRECTORY}/images/images.list
		done
	else
		echo "发现编译内核的版本信息，但未找到对应的内核文件，无法继续！请检查 ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION} 目录中是否存放有内核目录。"
		exit 6
	fi
else
	echo "没有发现构建内核版本的信息，无法选择安装的内核，请确认是否完成内核的编译。"
	exit 7
fi
# sed -i "/LABEL/s@vmlinux.efi@vmlinux_${NEW_LABEL}.efi @g" ${LIVE_DIRECTORY}/boot/grub/grub.cfg
# sed -i "/initrd/s@initramfs.img.gz@initramfs_${NEW_LABEL}.img.gz @g" ${LIVE_DIRECTORY}/boot/grub/grub.cfg
# mv ${LIVE_DIRECTORY}/boot/vmlinux{,_${NEW_LABEL}}.efi
# mv ${LIVE_DIRECTORY}/boot/initramfs{,_${NEW_LABEL}}.img.gz

# sed -i "s@ LABEL=Sunhaiyong @ LABEL=${NEW_LABEL} @g" ${LIVE_DIRECTORY}/boot/grub/grub.cfg
echo "${NEW_LABEL}" > ${LIVE_DIRECTORY}/LABEL
# sed -i "/ quiet/s@ quiet@ quiet amdgpu.dpm=0 @g" ${LIVE_DIRECTORY}/boot/grub/grub.cfg


# 提示可能漏掉的安装包
# ls ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/*.squashfs | awk -F'/' '{ print $NF }' | sed -e "s@\.docs\.${DISTRO_ARCH}\.squashfs@@g" -e "s@\.devel\.${DISTRO_ARCH}\.squashfs@@g" -e "s@\.${DISTRO_ARCH}\.squashfs@@g" | sed -e "/^kernel_/d" | sort | uniq > ${NEW_TARGET_SYSDIR}/temp/all_can_install_file.temp
# cat ${BASE_DIR}/info_set/release_sort | grep -v "^#" | sort | uniq > ${NEW_TARGET_SYSDIR}/temp/is_install_file.temp1
# cat ${BASE_DIR}/info_set/release_sort | grep -v "^#" | sed "s@\$@&.update@g" |sort | uniq >> ${NEW_TARGET_SYSDIR}/temp/is_install_file.temp1

find ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/ -maxdepth 1 -type f -name "*.squashfs" | awk -F'/' '{ print $NF }' | sed -e "s@\.${DISTRO_ARCH}\.squashfs@@g" | sed -e "/^kernel_/d" | sort | uniq > ${NEW_TARGET_SYSDIR}/temp/all_can_install_file.temp
find ${LIVE_DIRECTORY}/images/ -maxdepth 1 -type f -name "*.squashfs" | awk -F'/' '{ print $NF }' | sed -e "s@\.${DISTRO_ARCH}\.squashfs@@g" | sed -e "/^kernel_/d" > ${NEW_TARGET_SYSDIR}/temp/is_install_file.temp1
find ${LIVE_DIRECTORY}/images/update/ -maxdepth 1 -type f -name "*.squashfs" | awk -F'/' '{ print $NF }' | sed -e "s@\.${DISTRO_ARCH}\.squashfs@@g" | sed -e "/^kernel_/d" >> ${NEW_TARGET_SYSDIR}/temp/is_install_file.temp1
cat ${NEW_TARGET_SYSDIR}/temp/is_install_file.temp1 | sort | uniq > ${NEW_TARGET_SYSDIR}/temp/is_install_file.temp
NOT_INSTALL_FILE="$(diff -Nurp ${NEW_TARGET_SYSDIR}/temp/{is_install_file,all_can_install_file}.temp | grep "^+[^+]" | sed "s@^+@@g" | tr '\n' ' ' | sed 's/ $//')"
if [ "x${NOT_INSTALL_FILE}" != "x" ]; then
	echo -e "\e[33m发现了可能被遗漏安装的组件包： ${NOT_INSTALL_FILE}\e[0m"
fi



# 安装文档文件

cp -a ${BASE_DIR}/docs ${LIVE_DIRECTORY}/ 

# 安装发布信息文件
echo "本次发布的${DISTRO_NAME_CN} ${DISTRO_VERSION} 版本概要如下：" > ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt
cat ${NEW_TARGET_SYSDIR}/logs/release_summary.txt >> ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt
echo "" >> ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt
echo "" >> ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt
echo "" >> ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt
echo "更加详细的软件列表及版本信息如下：" >> ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt
cat ${NEW_TARGET_SYSDIR}/logs/release_info.txt >> ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt

iconv -t GBK -o ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.GBK.txt ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt

echo "Live USB系统导出完成，存放在 ${LIVE_DIRECTORY} , 准备一个第一分区为VFAT格式空分区的U盘，将 ${LIVE_DIRECTORY} 目录中所有内容复制到U盘的第一分区中，该U盘即可在支持UEFI的机器上作为LiveUSB启动。"
