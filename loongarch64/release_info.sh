#!/bin/bash -e

export NEW_TARGET_SYSDIR="${PWD}/workbase"
export BASE_DIR="${PWD}"

declare UPDATE_MODE=FALSE
declare DISTRO_LABEL=""

while getopts 'h' OPT; do
    case $OPT in
        ?|h)
            echo "用法: `basename $0` [选项]"
            exit 0
            ;;
    esac
done
shift $(($OPTIND - 1))


if [ -f ${BASE_DIR}/workbase/logs/release_show.txt ]; then
	mv ${BASE_DIR}/workbase/logs/release_show.txt{,.$(date +%Y%m%d%H%M%S)}
fi
if [ -f ${BASE_DIR}/workbase/logs/release_info.txt ]; then
	mv ${BASE_DIR}/workbase/logs/release_info.txt{,.$(date +%Y%m%d%H%M%S)}
	if [ -f ${BASE_DIR}/workbase/logs/release_info.temp ]; then
		rm ${BASE_DIR}/workbase/logs/release_info.temp
		touch ${BASE_DIR}/workbase/logs/release_info.temp
	fi
fi
if [ -f ${BASE_DIR}/workbase/logs/release_summary.txt ]; then
	mv ${BASE_DIR}/workbase/logs/release_summary.txt{,.$(date +%Y%m%d%H%M%S)}
fi

# for i in $(cat ${BASE_DIR}/env/*/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }' | sort | uniq)
for i in $(cat ${BASE_DIR}/info_set/release_sort)
do
	echo "统计 $i 目录内的软件版本信息..."
	if [ -d ${BASE_DIR}/workbase/overlaydir_strip/$i ]; then
		echo "${i} 组中包含了以下软件包：" >> ${BASE_DIR}/workbase/logs/release_info.txt
		for pkg_info in $(ls ${BASE_DIR}/workbase/overlaydir_strip/${i}/var/Yongbao/status/* )
		do
			if [ -f ${pkg_info} ]; then
				if [ "x$(grep "^${i}/${pkg_info##*/}" ${BASE_DIR}/info_set/release_hide)" == "x" ] && [ "x$(grep "^${pkg_info##*/}$" ${BASE_DIR}/info_set/release_hide)" == "x" ]; then
					if [ "x$(cat ${BASE_DIR}/info_set/release_summary | grep "^${pkg_info##*/}=")" != "x" ] && [ "x$(cat ${BASE_DIR}/workbase/logs/release_info.temp | grep "^${pkg_info##*/}-$(cat ${pkg_info})$")" == "x" ]; then
						echo "找到一个提要${pkg_info##*/}。"
						echo "${pkg_info##*/}-$(cat ${pkg_info})" >> ${BASE_DIR}/workbase/logs/release_info.temp
						echo "${pkg_info##*/}=$(cat ${BASE_DIR}/info_set/release_summary | grep "^${pkg_info##*/}=" | awk -F'=' '{ print $2 }' | sed "s@<<<VERSION>>>@$(cat ${pkg_info})@g")" >> ${BASE_DIR}/workbase/logs/release_show.txt
					fi
					echo "	${pkg_info##*/} $(cat ${pkg_info})" >> ${BASE_DIR}/workbase/logs/release_info.txt
				fi
			fi
		done
		echo "" >> ${BASE_DIR}/workbase/logs/release_info.txt
	else
		echo "${BASE_DIR}/workbase/overlaydir 中没有发现 $i 目录，跳过。"
	fi
done

for i in $(cat ${BASE_DIR}/info_set/release_summary | grep -v "^#" | awk -F'=' '{ print $1 }')
do
	if [ "x$(cat ${BASE_DIR}/workbase/logs/release_show.txt | grep "^${i##*/}=")" != "x" ]; then
		echo "* $(cat ${BASE_DIR}/workbase/logs/release_show.txt | grep "^${i##*/}=" | awk -F'=' '{ print $2 }')" >> ${BASE_DIR}/workbase/logs/release_summary.txt
	fi
done
