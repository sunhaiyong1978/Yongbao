declare CUSTOM_TARGET_NAME="loongarch64"
declare FORCE_BUILD=0

while getopts 't:h' OPT; do
    case $OPT in
        t)
            CUSTOM_TARGET_NAME=$OPTARG
            ;;
	f)
	    FORCE_BUILD=1
	    ;;
        h|?)
            echo "目标系统构建命令。"
	    exit 0
	    ;;
    esac
done
shift $(($OPTIND - 1))

case "${CUSTOM_TARGET_NAME}" in
	loongarch64 | x86_64 | i686 | mips64el | riscv64 )
		;;
	*)
		echo "不支持 ${CUSTOM_TARGET_NAME} 架构的构建。"
		exit 1
		;;
esac

if [ "x${FORCE_BUILD}" == "x0" ]; then
	./build.sh -S mini_runtime -e target=${CUSTOM_TARGET_NAME}  -i steps/mini_chroot_sysroot.index
else
	./build.sh -a -f -S mini_runtime -e target=${CUSTOM_TARGET_NAME}  -i steps/mini_chroot_sysroot.index
fi
