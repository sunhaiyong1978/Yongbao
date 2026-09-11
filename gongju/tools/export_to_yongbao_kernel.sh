#!/bin/bash -e

INITRAMFS_URL="https://mirrors.wsyu.edu.cn/fedora/linux/Yongbao/initramfs/initramfs-squashfs.img.gz"

declare OUT_DIR=""
declare ARCH_FAMILY="loongarch"
declare CUSTOM_KERNEL_FILE=""

while getopts 'k:o:a:h' OPT; do
    case $OPT in
	k)
	    CUSTOM_KERNALE_FILE=$OPTARG
	    ;;
        o)
            OUT_DIR=$OPTARG
            ;;
	a)
	    ARCH_FAMILY=$OPTARG
	    ;;
        h|?)
            echo "将指定目录中的内核及内核模块文件打包成Yongbao系统使用的目录和文件结构。"
	    echo "-o：该参数需要指定一个目录，该目录用来存放内核及模块的处理结果文件，不指定该参数将默认使用out目录。"
	    exit 0
	    ;;
    esac
done
shift $(($OPTIND - 1))


EXPORT_KERNEL_VERSION="$(uname -a | awk -F' ' '{ print $3 }')"
if [ "x${CUSTOM_KERNEL_FILE}" == "x" ]; then
	EXPORT_KERNEL_FILE="$(ls /boot/vmlinu*-${EXPORT_KERNEL_VERSION} | head -n1)"
else
	EXPORT_KERNEL_FILE="${CUSTOM_KERNEL_FILE}"
fi
EXPORT_KERNEL_MODULE_DIR="/lib/modules/${EXPORT_KERNEL_VERSION}"
echo "${EXPORT_KERNEL_VERSION}"

if [ "x${EXPORT_KERNEL_FILE}" != "x" ]; then
	if [ -f ${EXPORT_KERNEL_FILE} ]; then
		echo "${EXPORT_KERNEL_FILE}"
	else
		echo "内核文件 ${EXPORT_KERNEL_FILE} 没有找到，请使用 -k 指定内核文件路径和文件名。"
		exit 1
	fi
else
	echo "无法确认当前内核文件。"
	exit 1
fi

if [ "x${EXPORT_KERNEL_MODULE_DIR}" != "x" ]; then
	if [ -d ${EXPORT_KERNEL_MODULE_DIR} ]; then
		echo "${EXPORT_KERNEL_MODULE_DIR}"
	else
		echo "模块路径 ${EXPORT_KERNEL_MODULE_DIR} 不存在，无法继续"
		exit 1
	fi
else
	echo "无法确认当前内核模块路径。"
	exit 1
fi


MKSQUASHFS=""
if [ -f /usr/bin/mksquashfs ]; then
	MKSQUASHFS=/usr/bin/mksquashfs
else
	if [ -f /sbin/mksquashfs ]; then
		MKSQUASHFS=/sbin/mksquashfs
	fi
fi
if [ "x${MKSQUASHFS}" == "x" ]; then
	echo "没有发现 mksquashfs 命令，请安装。"
	exit 3
fi


if [ "x${OUT_DIR}" == "x" ]; then
	echo "未指定存放结果的目录，将使用默认的out目录，若需要指定目录，可使用-o参数"
	OUT_DIR="out"
fi

if [ ! -d initramfs_template ]; then
	mkdir -p initramfs_template
fi
if [ ! -f initramfs_template/initramfs-squashfs.img.gz ]; then
	echo "下载 initramfs 模板文件..."
	wget -c "${INITRAMFS_URL}" -O initramfs_template/initramfs-squashfs.img.gz
	if [ "x$?" == "x0" ]; then
		echo "下载完成，请不要删除，以后在当前目录下制作可以复用，不用再次下载。"
	else
		echo "下载失败，请检查网络环境。"
		exit 7
	fi
fi

DATA_SUFF="$(date +%Y%m%d%H%M%S)"
if [ -d "${OUT_DIR}" ]; then
	echo "${OUT_DIR} 目录已经存在，将备份原目录为 ${OUT_DIR}.${DATA_SUFF} ..."
	mv "${OUT_DIR}" "${OUT_DIR}.${DATA_SUFF}"
fi
echo -n "创建 ${OUT_DIR} , 处理结果将存放在该目录下..."
mkdir -p "${OUT_DIR}"/dist/{boot,images}
mkdir -p "${OUT_DIR}"/build/module/usr/lib/modules
mkdir -p "${OUT_DIR}"/build/initramfs
echo "完成！"

echo "复制内核文件..."
cp -af ${EXPORT_KERNEL_FILE} ${OUT_DIR}/dist/boot/
echo "完成！"

echo "安装 initramfs-squashfs.img.gz ..."
cp -a initramfs_template/initramfs-squashfs.img.gz "${OUT_DIR}"/build/initramfs/
pushd "${OUT_DIR}"/build/initramfs/ 2>&1 >/dev/null
	gunzip initramfs-squashfs.img.gz
	cpio -id < initramfs-squashfs.img | true
	rm initramfs-squashfs.img
	rm lib/*.ko
	for i in fs/fat/fat fs/fat/msdos fs/fat/vfat drivers/usb/storage/usb-storage drivers/usb/storage/uas
	do
		if [ -f ${EXPORT_KERNEL_MODULE_DIR}/kernel/${i}.ko.xz ]; then
			cp -a ${EXPORT_KERNEL_MODULE_DIR}/kernel/${i}.ko.xz lib/
			unxz -d lib/$(echo ${i} | awk -F'/' '{ print $NF }').ko.xz
			continue;
		fi
		if [ -f ${EXPORT_KERNEL_MODULE_DIR}/kernel/${i}.ko.zst ]; then
			cp -a ${EXPORT_KERNEL_MODULE_DIR}/kernel/${i}.ko.zst lib/
			unzst -d lib/$(echo ${i} | awk -F'/' '{ print $NF }').ko.zst
			continue;
		fi
		if [ -f ${EXPORT_KERNEL_MODULE_DIR}/kernel/${i}.ko ]; then
			cp -a ${EXPORT_KERNEL_MODULE_DIR}/kernel/${i}.ko lib/
			continue;
		fi
		echo "警告：找不到需要的内核模块 ${i}，可能该模块已编入内核，跳过。"
	done
	echo "${EXPORT_KERNEL_VERSION}" > ./uname_str.save
	find . | cpio -H newc --create > ../initramfs.img
	cd ..
	gzip -9 initramfs.img
popd 2>&1 >/dev/null

cp -a ${OUT_DIR}/build/initramfs.img.gz ${OUT_DIR}/dist/boot/initramfs_${EXPORT_KERNEL_VERSION}.img.gz

echo "创建内核模块的镜像文件..."
cp -a ${EXPORT_KERNEL_MODULE_DIR} "${OUT_DIR}"/build/module/usr/lib/modules/
${MKSQUASHFS} "${OUT_DIR}"/build/module "${OUT_DIR}"/dist/images/kernel_${EXPORT_KERNEL_VERSION}.loongarch64.squashfs -all-root -comp xz
echo "镜像文件创建完成！"
echo ""

echo -n "创建启动项参考内容 ${OUT_DIR}/dist/boot/grub.cfg.${EXPORT_KERNEL_VERSION} ..."
cat > ${OUT_DIR}/dist/boot/grub.cfg.${EXPORT_KERNEL_VERSION} << EOF
menuentry '勇豹 测试内核 (Linux ${EXPORT_KERNEL_VERSION})' {
  set gfxpayload=keep
  echo '加载Linux内核……'
  linux ${EXPORT_KERNEL_FILE} LABEL=这里需要手工修改 quiet
  initrd /boot/initramfs_${EXPORT_KERNEL_VERSION}.img.gz
  echo '加载完成，开始启动勇豹系统……'
}
EOF
echo "完成！请将该文件内容复制并添加到启动系统的 boot/grub/grub.cfg 中，并参考已有启动项修改LABEL=之后的标签名。"
echo ""
echo "所有需要安装的文件均存放在 "${OUT_DIR}"/dist 目录中。"

exit 0
# MODULE_DIR=$(realpath ${1}/lib/modules/${KERNEL_VERSION}/)
# KERNEL_SOURCE_DIR=$(realpath ${1}/lib/modules/${KERNEL_VERSION}/build)
