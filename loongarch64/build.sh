#!/bin/bash

if [ ! -f step ]; then
	echo "没有发现脚本文件，请检查当前目录是否存在step文件。"
fi

NEW_TARGET_SYSDIR="${PWD}/workbase"
BASE_DIR="${PWD}"


declare FORCE_BUILD=0
declare FORCE_ALL_BUILD=0
declare OPT_SET_STR=""
declare ONLY_BUILD=0
declare SINGLE_BUILD=1
declare FORCE_ALL_DOWNLOAD=0

while getopts 'fao:rdh' OPT; do
    case $OPT in
        f)
            FORCE_BUILD=1
            ;;
        a)
            FORCE_ALL_BUILD=1
            ;;
	o)
	    OPT_SET_STR=$OPTARG
	    ;;
	r)
	    SINGLE_BUILD=0
	    ;;
        d)
            FORCE_ALL_DOWNLOAD=1
            ;;
        h|?)
            echo "目标系统构建命令。"
            echo ""
            echo "用法: ./`basename $0` [选项] [步骤组/软件包]"
            echo "步骤组/软件包:"
            echo "    用来指定编译范围，通常一个步骤会包含多个软件包，可以单独指定步骤名或者软件包名，当指定的软件包名在不同的步骤中都存在时，需要指定步骤名以确认需要编译的软件包步骤。"
            echo "    例如:boot/linux，代表了名为“boot”的步骤组内的linux这个软件包编译的步骤。"
            echo "    例如:boot，代表了名为“boot”的步骤组内全部的步骤。"
            echo "    例如:linux，如果没有“linux”这个名称的步骤组，则会自动查询所有步骤组中是否存在linux这个软件包所对应的步骤，如果存在多个则会提示用户进行选择，如果仅存在一个则会开始制作该软件包的步骤，若找不到则会提示错误。"
            echo "    不指定步骤组/软件包时代表全部步骤都进行制作。"
            echo "选项:"
            echo "    -h: 当前帮助信息。"
            echo "    -d: 强制编译前先检查并下载需要的软件源码包及资源文件。"
            echo "    -o <标记,标记,...>: 设置编译标记参数（符合标记参数的软件包才会进行编译）"
            echo "    -r: 根据指定的编译步骤或软件包，搜寻依赖的相关软件包和步骤组一起进行编译。"
            echo "    -f: 强制执行指定的编译步骤。该参数必须指定编译步骤或软件包才有效。"
            echo "    -a: 强制编译所有的软件包步骤。与-f参数配合，用来在不指定任何软件包时强制编译所有满足标记参数设置的软件包。"
            exit 127
    esac
done
shift $(($OPTIND - 1))


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

function get_string_stepname
{
        echo $(echo "${1}" | grep -o "[^:#%/]\{0,\}/" || echo "NULL") | head -n1 | sed "s@/@@g"
}

function get_string_pkgname
{
        echo $(echo "${1}" | grep -o "\(^[^/]\{1,\}$\|/\{1\}[^/]\{1,\}\)" || echo "NULL") | head -n1 | sed "s@/@@g"
}

function format_step_str
{
	declare STEPNAME=$(get_string_stepname "${1}")
	declare STEP_PKGNAME=$(get_string_pkgname "${1}")
	if [ "x${STEPNAME}" == "xNULL" ] && [ "x${STEP_PKGNAME}" == "xNULL" ]; then
		# 没有设置指定编译步骤
		echo ""
		return;
	fi
	if [ "x${STEPNAME}" != "xNULL" ] && [ "x${STEP_PKGNAME}" == "xNULL" ]; then
		# 设置了指定编译组
		FIND_STEP=$(find scripts/step -maxdepth 1 -type d -name "${STEPNAME}"  | sed "s@scripts/step/@@g" )
		if [ "x${FIND_STEP}" != "x" ]; then
                        # 已找到指定步骤组：${FIND_STEP}
			echo "${FIND_STEP}/"
		else
                        # 没有找到指定的步骤组。
			echo "NULL"
		fi
		return;
	fi
	if [ "x${STEPNAME}" == "xNULL" ] && [ "x${STEP_PKGNAME}" != "xNULL" ]; then
		# 设置了指定编译包，但没有明确指定是哪个组里的包
		FIND_FILE=$(find scripts/step -type f -name ${STEP_PKGNAME} | sed "s@scripts/step/@@g")
		if [ "x$(echo "${FIND_FILE}" | head -n1 )" != "x$(echo "${FIND_FILE}" | tail -n1 )" ]; then
			# 发现存在多个指定名字的软件包，请明确其指定具体所属步骤组，以下为找出的列表供参考
			echo "${FIND_FILE}"
		else
			if [ "x${FIND_FILE}" == "x" ]; then
				# 没有找到指定的软件包，尝试使用步骤组的名字来查找……
				echo $(format_step_str "${STEP_PKGNAME}/")
			else
				# 已找到指定名字软件包及其所属步骤组
				echo "$(find scripts/step -name "${STEP_PKGNAME}" | sed "s@scripts/step/@@g")"
			fi
		fi
		return;
	fi
	if [ "x${STEPNAME}" != "xNULL" ] && [ "x${STEP_PKGNAME}" != "xNULL" ]; then
		# 指定了具体编译组中具体的包
		if [ -f scripts/step/${STEPNAME}/${STEP_PKGNAME} ]; then
			# 已找到指定步骤组和软件包
			echo "${STEPNAME}/${STEP_PKGNAME}"
		else
			# 没有找到指定的步骤组及软件包，请检查指定的步骤组和软件包是否存在。
			echo "NULL"
		fi
		return;
	fi
	echo ""
	return;
}

function get_require
{
	declare STEPNAME=""
	STEPNAME=${1}
	declare STEP_LISTS="${2}"
	if [ ! -f env/${STEPNAME}/overlay.set ]; then
		echo ""
		return;
	fi
	declare STEP_OVERLAY_NAME="$(cat env/${STEPNAME}/overlay.set | grep "overlay_dir=" | tail -n1 | awk -F'=' '{ print $2 }')"
	declare STEP_PARENT_NAME="$(cat env/${STEPNAME}/overlay.set | grep "parent_dirs=" | tail -n1 | awk -F'=' '{ print $2 }')"
	declare STEP_REQUIRES_NAME="$(cat env/${STEPNAME}/overlay.set | grep "requires=" | tail -n1 | awk -F'=' '{ print $2 }')"

	for step_dir in $(grep -r "overlay_dir=${STEP_OVERLAY_NAME}" env/* | awk -F'/' '{ print $2 }')
	do
		if [[ "${STEP_LISTS}" != *" ${step_dir} "* ]]; then
			STEP_LISTS="${STEP_LISTS} ${step_dir} "
		fi
	done
	
	for parent_name in $(echo ${STEP_PARENT_NAME} | tr ',' '\n')
	do
		for step_dir in $(grep -r "overlay_dir=${parent_name}" env/* | awk -F'/' '{ print $2 }')
		do
			if [[ "${STEP_LISTS}" != *" ${step_dir} "* ]]; then
				STEP_LISTS="${STEP_LISTS} ${step_dir} "
			fi
		done
	done

	for require_name in $(echo ${STEP_REQUIRES_NAME} | tr ',' '\n')
	do
		if [ -f env/${require_name}/config ]; then
			STEP_LISTS="${STEP_LISTS} ${require_name} "
		fi
	done

	echo "${STEP_LISTS}"
	return;
}

function get_requires
{
	declare STEPNAME=""
	STEPNAME="${1}"
	declare STEP_LISTS="${2}"

	if [ "x${STEPNAME}" == "x" ]; then
		echo ""
		return
	fi

	if [ ! -f env/${STEPNAME}/overlay.set ]; then
		echo ""
		return;
	fi

	declare OLD_STEP_LISTS=""
	STEP_LISTS="${STEP_LISTS} ${1} "

	while [ "x$(echo "${STEP_LISTS}" | tr " " "\\n" | sort | uniq | grep -v "^$")" != "x$(echo "${OLD_STEP_LISTS}" | tr " " "\\n" | sort | uniq | grep -v "^$")" ]
	do
		OLD_STEP_LISTS="${STEP_LISTS}"
		for i in $(echo "${STEP_LISTS}" | tr " " "\\n" | sort | uniq | grep -v "^$")
		do
			STEP_LISTS="${STEP_LISTS} $(get_require "${i}" "")"
		done
	done
	echo "${STEP_LISTS}" | tr " " "\\n" | sort | uniq | grep -v "^$"
	return 
}


function get_default_opt
{
	declare -a USE_OPT
	declare -a NOUSE_OPT
	declare USE_COUNT=0
	declare NOUSE_COUNT=0
	for i in $(cat env/opt.info | grep "^opt=")
	do
		OPT=$(echo ${i} | awk -F'=' '{ print $2 }')
		if [ "x${OPT:0:1}" == "x+" ]; then
			USE_OPT[${USE_COUNT}]=${OPT:1}
			((USE_COUNT++))
		else
			if [ "x${OPT:0:1}" == "x-" ]; then
				NOUSE_OPT[${NOUSE_COUNT}]=${OPT:1}
				((NOUSE_COUNT++))
			else
				USE_OPT[${USE_COUNT}]=${OPT}
				((USE_COUNT++))
			fi
		fi
	done
	echo "${USE_OPT[@]}"
}


function set_to_default_opt
{
	declare -a SET_OPT
	declare SET_COUNT=0
	declare SET_STR="${2}"
	declare -a USE_OPT=(${1})
	declare USE_COUNT=${#USE_OPT[@]}

	for i in $(echo "${SET_STR}" | tr "," "\\n")
	do
		SET_OPT[${SET_COUNT}]=${i}
		((SET_COUNT++))
	done

	for i in ${SET_OPT[*]}
	do
		if [ "x${i}" == "xbad" ] || ( ( [ "x${i:0:1}" == "x+" ] || [ "x${i:0:1}" == "x-" ] ) && [ "x${i:1}" == "xbad" ] ); then
			continue;
		fi
		if [ "x${i:0:1}" == "x-" ]; then
			OPT=${i:1}
			for j in $(echo ${!USE_OPT[@]})
			do
				if [ "x${OPT}x" == "x${USE_OPT[${j}]}x" ]; then
					USE_OPT[${j}]=""
				fi
			done
		else
			if [ "x${i:0:1}" == "x+" ]; then
				USE_OPT[${USE_COUNT}]=${i:1}
			else
				USE_OPT[${USE_COUNT}]=${i}
			fi
			((USE_COUNT++))
		fi
	done
	echo "${USE_OPT[@]}"
}

function test_opt_can_run
{
	declare TEST_COUNT=0
	declare TEST_STR="${2}"
	declare -a TEST_OPT
	declare OPT=""
	declare -a USE_OPT=(${1})
	declare USE_COUNT=${#USE_OPT[@]}

	if [ "x${TEST_STR}" == "x" ]; then
		echo "0"
		return
	fi

	for i in $(echo "${TEST_STR}" | tr "," "\\n")
	do
		if [ "x{i}" != "x" ]; then
			TEST_OPT[${TEST_COUNT}]=${i}
			((TEST_COUNT++))
		fi
	done

	TEST_STATUS=0
	for i in ${TEST_OPT[*]}
	do
		TEST_STATUS=0
		if [ "x${i:0:1}" == "x+" ]; then
			OPT=${i:1}
		else
			OPT=${i}
		fi
		for j in $(echo ${USE_OPT[*]})
		do
			if [ "x${j}" == "x" ]; then
				continue
			fi
			if [ "x${OPT}x" == "x${j}x" ]; then
				# ${i} 在使用
				TEST_STATUS=1
				break;
			fi
		done
		if [ "x${TEST_STATUS}" == "x0" ]; then
			# ${i} 标记没有找到，${1} 测试不通过"
			echo "1"
			return
		fi
	done

	# 全部找到，测试通过

	echo "0"
	return
}


function os_run_clean
{
	if [ "x${1}" == "x" ]; then
		return
	fi
	if [ "x${2}" == "x" ]; then
		return
	fi
	declare STEP_STAGE="${1}"
	declare PACKAGE_NAME="${2}"
	if [ -f ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${STEP_STAGE}.${PACKAGE_NAME}.run ]; then
		rm ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${STEP_STAGE}.${PACKAGE_NAME}.run
	fi
	if [ -f ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${STEP_STAGE}.${PACKAGE_NAME}.run ]; then
		rm ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${STEP_STAGE}.${PACKAGE_NAME}.run
	fi
	return
}

function create_os_run
{
	if [ "x${1}" == "x" ]; then
		return
	fi
	if [ "x${2}" == "x" ]; then
		return
	fi
	if [ "x${3}" == "x" ]; then
		return
	fi
	declare SCRIPT_FILE="${1}"
	declare STEP_STAGE="${2}"
	declare PACKAGE_NAME="${3}"
	if [ -f scripts/step/${SCRIPT_FILE}.os_first_run ]; then
		scripts/tools/show_package_script.sh -n ${SCRIPT_FILE} "os_first_run" > ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${STEP_STAGE}.${PACKAGE_NAME}.run
	fi

	if [ -f scripts/step/${SCRIPT_FILE}.os_start_run ]; then
		scripts/tools/show_package_script.sh -n ${SCRIPT_FILE} "os_start_run" > ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${STEP_STAGE}.${PACKAGE_NAME}.run
	fi
}


function step_to_index
{
	declare STEP_COUNT=1
	declare SHOW_COUNT=1
	declare TMP_NAME=""
	declare COUNT_NAME="STEP_COUNT"
	declare ALL_COUNT=0

	declare -a USE_OPT
	declare USE_COUNT=0

	declare STEPNAME=""
	declare STEP_PKGNAME=""
	declare STEP_PKG_STR="${1}" 
	declare STEP_PKG_OPT=""
	declare REQUIRES_STEPS=""
	declare GREP_STR=""
	declare STOP_STEP_PKGNAME=""
	declare STOP_STEP_GROUP=""
	declare STOP_STEP_STR=""

	if [ ! -f env/opt.info ]; then
		echo "警告：没有发现env/opt.info文件，本次制作选取的软件包将采用默认的设置。默认设置为：-fopt、-gopt"
	fi
	USE_OPT=($(get_default_opt))
 	USE_OPT=($(set_to_default_opt "$(echo ${USE_OPT[@]})" "${OPT_SET_STR}"))
	USE_COUNT=${#USE_OPT[@]}



	if [ "x${STEP_PKG_STR}" != "x" ]; then
		FORMAT_STRING=$(format_step_str "${STEP_PKG_STR}")
		echo "指定了编译步骤：${FORMAT_STRING}"
		if [ "x${FORMAT_STRING}" == "xNULL" ]; then
			echo "错误：制定的软件包或步骤组 ${STEP_PKG_STR} 不存在，请检查是否输入正确。"
			exit 1
		fi
		if [ $(echo "${FORMAT_STRING}" | head -n1) != $(echo "${FORMAT_STRING}" | tail -n1) ]; then
			echo "错误：发现了多个指定的编译步骤，请参考以下列表，重新指定具体的步骤："
			echo "${FORMAT_STRING}"
			exit 1
		fi
	        STEPNAME=$(get_string_stepname "${FORMAT_STRING}")
        	STEP_PKGNAME=$(get_string_pkgname "${FORMAT_STRING}")
		if [ "x${STEPNAME}" != "xNULL" ] && [ "x${STEP_PKGNAME}" != "xNULL" ]; then
			STEP_PKG_OPT=$(cat step | grep "^%step/${STEPNAME}/${STEP_PKGNAME}|" | sort | uniq | tail -n1 | awk -F'|' '{ print $2 }')
			STOP_STEP_PKGNAME=$(cat step | grep "^%step/${STEPNAME}/${STEP_PKGNAME}|" | sort | uniq | tail -n1 | awk -F'|' '{ print $1 }')
			STOP_STEP_GROUP="${STOP_STEP_PKGNAME}"
			STOP_STEP_STR="${STOP_STEP_PKGNAME}"
		fi
		if [ "x${STEPNAME}" != "xNULL" ] && [ "x${STEP_PKGNAME}" == "xNULL" ]; then
			STEP_PKG_OPT=$(cat step | grep "^%step/${STEPNAME}/" | head -n1 | awk -F'|' '{ print $2 }')
			STOP_STEP_PKGNAME=$(cat step | grep "^%step/${STEPNAME}/" | tail -n1 | awk -F'|' '{ print $1 }')
			STOP_STEP_GROUP="%step/${STEPNAME}/"
			STOP_STEP_STR="${STOP_STEP_PKGNAME}"
		fi

		echo "因指定了编译步骤，需测试编译的相关组，相关组如下："
		echo "${STEPNAME}"
		echo "$(get_requires "${STEPNAME}" "")"
		REQUIRES_STEPS="${STEPNAME} $(get_requires "${STEPNAME}" "")"
		GREP_STR=$(echo ${REQUIRES_STEPS} | sed "s@\([^ ]*\)@ -e \"step/&/\"@g")

	fi
	USE_OPT=($(set_to_default_opt "$(echo ${USE_OPT[@]})" "${STEP_PKG_OPT}"))

	echo "当前指定的编译标记如下："
	echo "${USE_OPT[@]}"

	for i in $(cat step | grep "^%step" | awk -F'/' '{ print $2 }' | sort | uniq)
	do
		declare ${i/-/_}_COUNT=1
	done

	for i in $(cat step | grep "^%step")
	do
		STEP_NAME=$(echo ${i} | awk -F'|' '{ print $1 }')
		STEP_OPT=$(echo ${i} | awk -F'|' '{ print $2 }')

		TMP_NAME=$(echo ${STEP_NAME} | awk -F'/' '{ print $2 }')
		COUNT_NAME=${TMP_NAME/-/_}_COUNT
		printf -v SHOW_COUNT "%05d" ${!COUNT_NAME}

		if [ "x$(test_opt_can_run "$(echo ${USE_OPT[@]})" "${STEP_OPT}")" == "x0" ]; then
			if [ "x${GREP_STR}" == "x" ]; then
				echo -n "${SHOW_COUNT}  "
				echo -n $(echo ${STEP_NAME} | sed "s@^%@@g")
				echo "|${STEP_OPT}"
			else
				eval  "echo ${STEP_NAME} | sed "s@^%@@g" | grep ${GREP_STR} > /dev/null"
				if [ "$?" == "0" ]; then
					if [ "x${SINGLE_BUILD}" == "x1" ]; then
						if [ "x${STOP_STEP_STR}" == "x${STEP_NAME}" ] || [ "${STEP_NAME%/*}/" == "${STOP_STEP_GROUP}" ] || ( [[ "${STEP_NAME}" =~ "${STOP_STEP_GROUP%/*}/" ]] && ( [ "x${STEP_NAME##*/}" == "xbegin_run" ] || [ "x${STEP_NAME##*/}" == "xfinal_run" ] || [ "x${STEP_NAME##*/}" == "xoverlay_before_run" ] || [ "x${STEP_NAME##*/}" == "xoverlay_after_run" ] ) ); then
							echo -n "${SHOW_COUNT}  "
							echo -n $(echo ${STEP_NAME} | sed "s@^%@@g")
							echo "|${STEP_OPT}"
						fi
					else
						echo -n "${SHOW_COUNT}  "
						echo -n $(echo ${STEP_NAME} | sed "s@^%@@g")
						echo "|${STEP_OPT}"
					fi
					if [ "x${STOP_STEP_PKGNAME}" == "x${STEP_NAME}" ]; then
						break;
					fi
				fi
			fi
		fi

		if [ "x${STEP_NAME##*/}" != "xbegin_run" ] && [ "x${STEP_NAME##*/}" != "xfinal_run" ] && [ "x${STEP_NAME##*/}" != "xoverlay_before_run" ] && [ "x${STEP_NAME##*/}" != "xoverlay_after_run" ]; then
			((${COUNT_NAME}++))
		fi
	done > ${NEW_TARGET_SYSDIR}/step.index
}


mkdir -p ${NEW_TARGET_SYSDIR}
echo "创将索引文件......"
step_to_index "${1}"
echo "索引文件创建完成。"

if [ "x${1}" != "x" ] && [ "x${FORCE_BUILD}" == "x1" ]; then
	FORCE_ALL_BUILD=1
fi

mkdir -p ${NEW_TARGET_SYSDIR}/status
mkdir -p ${NEW_TARGET_SYSDIR}/logs
mkdir -p ${NEW_TARGET_SYSDIR}/build
mkdir -p ${NEW_TARGET_SYSDIR}/dist
mkdir -p ${NEW_TARGET_SYSDIR}/temp
mkdir -p ${NEW_TARGET_SYSDIR}/common_files
mkdir -p ${NEW_TARGET_SYSDIR}/scripts/os_{first,start}_run

if [ -f ${NEW_TARGET_SYSDIR}/status/step.md5sum ]; then
	md5sum -c ${NEW_TARGET_SYSDIR}/status/step.md5sum 2>/dev/null > /dev/null
	if [ "$?" != "0" ] || [ "x${FORCE_ALL_DOWNLOAD}" == "x1" ]; then
		if [ "x${FORCE_ALL_DOWNLOAD}" == "x1" ]; then
			echo "强制指定进行软件包下载检查，开始进行必要的下载..."
		else
			echo "本次创建的索引文件与上次的内容不同，可能会存在需要下载的软件包，开始进行必要的下载..."
		fi
		scripts/tools/get_all_package_url.sh -i ${NEW_TARGET_SYSDIR}/step.index
		echo "下载完成。"
	fi
else
	echo "开始下载必要的软件包..."
	scripts/tools/get_all_package_url.sh -i ${NEW_TARGET_SYSDIR}/step.index
	echo "下载完成。"
fi
md5sum ${NEW_TARGET_SYSDIR}/step.index > ${NEW_TARGET_SYSDIR}/status/step.md5sum


mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/{.lowerdir,.workerdir}
mkdir -p ${NEW_TARGET_SYSDIR}/sysroot


mkdir -p ${NEW_TARGET_SYSDIR}/files
mkdir -p ${NEW_TARGET_SYSDIR}/build
cp -a ${BASE_DIR}/files/step/* ${NEW_TARGET_SYSDIR}/files/
cp -a ${BASE_DIR}/sources/downloads ${NEW_TARGET_SYSDIR}/



while mount | grep "overlay on ${NEW_TARGET_SYSDIR}/sysroot type " > /dev/null
do
	echo "卸载已挂载的目录 ${NEW_TARGET_SYSDIR}/sysroot ..."
	overlay_umount
done

echo "开始编译制作过程......"
echo "------------$(date)-------------" >> ${NEW_TARGET_SYSDIR}/logs/build_log

STEP_FILE="${NEW_TARGET_SYSDIR}/step.index"

echo -n "" > ${NEW_TARGET_SYSDIR}/logs/step_begin_run_save
echo -n "" > ${NEW_TARGET_SYSDIR}/logs/step_final_run_save
echo -n "" > ${NEW_TARGET_SYSDIR}/logs/step_overlay_before_run_save
echo -n "" > ${NEW_TARGET_SYSDIR}/logs/step_overlay_after_run_save

cat ${STEP_FILE} | awk -F'|' '{ print $1 }' | while read line
do
	RET_VAL=0
	PACKAGE_INDEX=$(echo "${line}" | sed "s@ *step@@g" | awk -F'/' '{ print $1 }')
	STEP_STAGE=$(echo "${line}" | sed "s@ *step@@g" | awk -F'/' '{ print $2 }')
	PACKAGE_NAME=$(echo "${line}" | sed "s@ *step@@g" | awk -F'/' '{ print $3 }')
	STATUS_FILE="${PACKAGE_NAME}_${STEP_STAGE}_${PACKAGE_INDEX}"
	SCRIPT_FILE=$(echo "${line}" | awk -F' ' '{ print $2 }' | sed "s@ *step\/@@g")
	if [ "x${PACKAGE_NAME}" == "xbegin_run" ] || [ "x${PACKAGE_NAME}" == "xoverlay_before_run" ] || [ "x${PACKAGE_NAME}" == "xoverlay_after_run" ]; then
		echo "${STEP_STAGE}" >> ${NEW_TARGET_SYSDIR}/logs/step_${PACKAGE_NAME}_save
		continue;
	else
		if [ -f ${NEW_TARGET_SYSDIR}/status/${STATUS_FILE} ]; then
			scripts/tools/show_package_script.sh -n ${SCRIPT_FILE} | md5sum -c ${NEW_TARGET_SYSDIR}/status/${STATUS_FILE} 2>/dev/null > /dev/null
			if [ "$?" == "0" ] && ([ "x${FORCE_BUILD}" == "x0" ] || [ "x${FORCE_ALL_BUILD}" == "x0" ]); then
				create_os_run "${SCRIPT_FILE}" "${STEP_STAGE}" "${PACKAGE_NAME}"
				echo -n -e "\r${STEP_STAGE}组中的${PACKAGE_NAME}软件包已完成制作。\033[0K"
				continue;
			else
				echo -n -e "\r${STEP_STAGE}组中的${PACKAGE_NAME}软件包制作步骤文件内容发生变化，需要重新执行。\033[0K"
			fi
		fi
	fi

	echo -e "\r开始制作${STEP_STAGE}组中的${PACKAGE_NAME}软件包步骤..."
	scripts/tools/show_package_script.sh ${SCRIPT_FILE} >/dev/null
	RET_VAL=$?
	if [ "${RET_VAL}" != "0" ]; then
		echo "${SCRIPT_FILE}脚本运行错误！"
		exit ${RET_VAL}
	fi
	RET_VAL=0

	grep "^${STEP_STAGE}$" ${NEW_TARGET_SYSDIR}/logs/step_begin_run_save > /dev/null
	if [ "x$?" == "x0" ]; then
		echo -n "运行 ${STEP_STAGE} 初始化脚本..."
		scripts/tools/run_package_script.sh ${STEP_STAGE}/begin_run >${NEW_TARGET_SYSDIR}/logs/begin_run_${STEP_STAGE}.log 2>&1
		if [ "x$?" != "x0" ]; then
			echo "错误！"
			scripts/tools/show_package_script.sh ${STEP_STAGE}/begin_run
			echo "${STEP_STAGE} 初始化脚本运行错误!"
			echo "错误日志请查看 ${NEW_TARGET_SYSDIR}/logs/begin_run_${STEP_STAGE}.log 文件。"
			exit -1
		fi
		sed -i "/^${STEP_STAGE}$/d" ${NEW_TARGET_SYSDIR}/logs/step_begin_run_save
		echo "完成。"
	fi

	if [ -f env/${STEP_STAGE}/overlay.set ]; then
		overlay_mount ${STEP_STAGE} env/${STEP_STAGE}/overlay.set
	fi
	
	if [ "x${PACKAGE_NAME}" != "xfinal_run" ]; then
		echo -n "制作${STEP_STAGE}组中的${PACKAGE_NAME}软件包..."
	else
		echo -n "执行${STEP_STAGE}组中的完成脚本..."
	fi
	ln -sf ${STATUS_FILE}.log ${NEW_TARGET_SYSDIR}/logs/current.log
	os_run_clean "${STEP_STAGE}" "${PACKAGE_NAME}"
	scripts/tools/run_package_script.sh ${SCRIPT_FILE} >${NEW_TARGET_SYSDIR}/logs/${STATUS_FILE}.log 2>&1
	if [ "x$?" != "x0" ]; then
		echo "错误！"
		scripts/tools/show_package_script.sh  ${SCRIPT_FILE}
		echo "${SCRIPT_FILE}制作错误!"
		echo "错误日志请查看 ${NEW_TARGET_SYSDIR}/logs/${STATUS_FILE}.log 文件。"
		exit -1
	fi

	if [ -f env/${STEP_STAGE}/overlay.set ]; then
		overlay_umount
	fi

	if [ "x${PACKAGE_NAME}" != "xfinal_run" ]; then
		scripts/tools/show_package_script.sh -n ${SCRIPT_FILE} | md5sum > ${NEW_TARGET_SYSDIR}/status/${STATUS_FILE}
	fi

	create_os_run "${SCRIPT_FILE}" "${STEP_STAGE}" "${PACKAGE_NAME}"

	echo "完成！"
	echo -n "${STEP_STAGE}/${PACKAGE_NAME} : " >> ${NEW_TARGET_SYSDIR}/logs/build_log
	if [ -f sources/url/${STEP_STAGE}/${PACKAGE_NAME} ]; then
		PACKAGE_URL=$(cat sources/url/${STEP_STAGE}/${PACKAGE_NAME})
		if [ "x${PACKAGE_URL}" != "x" ]; then
			echo -n "${PACKAGE_URL}" >> ${NEW_TARGET_SYSDIR}/logs/build_log
                	case "${PACKAGE_URL%%/*}" in
			git:)
				if [ -f sources/url/${STEP_STAGE}/${PACKAGE_NAME}.gitinfo ]; then
					echo -n " $(cat sources/url/${STEP_STAGE}/${PACKAGE_NAME}.gitinfo) " >> ${NEW_TARGET_SYSDIR}/logs/build_log
				fi
				;;
	                *)
				;;
			esac
		fi
	fi
	echo "" >> ${NEW_TARGET_SYSDIR}/logs/build_log
done

echo "编译制作过程完成。" >> ${NEW_TARGET_SYSDIR}/logs/build_log
echo "------------$(date)-------------" >> ${NEW_TARGET_SYSDIR}/logs/build_log
echo -e "\r编译制作过程完成。\033[0K\n"
if [ "x${1}" == "x" ]; then
	echo "接下来可以使用./strip_os.sh脚本来清除调试信息以及使用./dist_os.sh脚本来打包系统。"
fi
