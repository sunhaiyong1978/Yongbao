function os_first_run
{
	set +e
	RUN_COMMOND="${1}"
	if [ -f ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${STEP_BUILDNAME}.${STEP_PACKAGENAME}.run ]; then
		grep "^${1}$" ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${STEP_BUILDNAME}.${STEP_PACKAGENAME}.run
		if [ "x$?" == "x0" ]; then
			return
		fi
	fi
	set -e
	echo "${1}" >> ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${STEP_BUILDNAME}.${STEP_PACKAGENAME}.run
	return
}

function os_start_run
{
	set +e
	RUN_COMMOND="${1}"
	if [ -f ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${STEP_BUILDNAME}.${STEP_PACKAGENAME}.run ]; then
		grep "^${1}$" ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${STEP_BUILDNAME}.${STEP_PACKAGENAME}.run
		if [ "x$?" == "x0" ]; then
			return
		fi
	fi
	set -e
	echo "${1}" >> ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${STEP_BUILDNAME}.${STEP_PACKAGENAME}.run
	return
}

function info_pool
{
	if [ "x${1}" != "x" ]; then
		echo "${1}" >> ${NEW_TARGET_SYSDIR}/logs/info_pool
	fi
}


function get_user_set_env
{
	if [ "x${1}" == "x" ]; then
		echo ""
	else
		ENV_NAME_TEMP_STR="YONGBAO_SET_ENV_${1}"
		if [ "x${!ENV_NAME_TEMP_STR}" == "x" ]; then
			echo "${2}"
		else
			echo "${!ENV_NAME_TEMP_STR}"
		fi
	fi
	return
}

function get_arch_datafile
{
	if [ "x${1}" == "x" ]; then
		echo "NULL.conf"
		return
	fi
	if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
		echo "NULL.conf"
		return
	fi
	RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "\(^\|/\)${1}\(/\|=\)" | awk -F'=' '{ print $2 }' | head -n1)"
	echo "${RET_VAL}"
	return
}

function get_arch_parm
{
	if [ "x${1}" == "x" ]; then
		echo "ERROR"
		return
	fi
	if [ "x${2}" == "x" ]; then
		echo "ERROR"
		return
	fi

	ARCH_DATAFILE=$(get_arch_datafile "${1}")
	if [ "x${ARCH_DATAFILE}" == "xNULL.conf" ]; then
		echo "ERROR"
		return
	fi
	RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/data/${ARCH_DATAFILE} | grep "^${2}=" | awk -F"^${2}=" '{ print $2 }' | head -n1)"
	echo "${RET_VAL}"
	return

}


function replace_arch_parm
{
	if [ "x${2}" == "x" ]; then
		SEARCH_ARCH=$(uname -m)
	else
		SEARCH_ARCH=${2}
	fi
	RET_VAL="${1}"
	for replace in $(echo "${1}" | grep -o "<<<[^>]*>>>")
	do
		RET_VAL="$(echo "${RET_VAL}" | sed "s@${replace}@$(get_arch_parm "${SEARCH_ARCH}" ${replace:3:-3})@g")"
	done
	echo "${RET_VAL}"
	return
}

function archname_to_name
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
		if [ "x${1}" == "x${2}" ]; then
			echo "${2}"
		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
#			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $2 }' | sed "s@[[:space:]]@@g")"
			RET_VAL="$(get_arch_parm "${1}" "NAME")"
			if [ "x${RET_VAL}" == "x" ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			else
				echo "${RET_VAL}"
			fi
		fi
	fi
	return
}



function archname_to_linuxname
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
		if [ "x${1}" == "x${2}" ]; then
			echo "${2}"
		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
#			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $2 }' | sed "s@[[:space:]]@@g")"
			RET_VAL="$(get_arch_parm "${1}" "LINUX_NAME")"
			if [ "x${RET_VAL}" == "x" ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			else
				echo "${RET_VAL}"
			fi
		fi
	fi
	return
}

function archname_to_triple
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
		if [ "x${1}" == "x${2}" ]; then
			echo "${2}"
		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
			# RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}[[:space:]]" | awk -F"^${1}" '{ print $2 }' | sed "s@[[:space:]]@@g")"
#			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $3 }' | sed "s@[[:space:]]@@g")"
			RET_VAL="$(get_arch_parm "${1}" "TRIPLE")"
			if [ "x${RET_VAL}" == "x" ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			else
				echo "${RET_VAL}"
			fi
		fi
	fi
	return
}

function archname_to_archbit
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
		if [ "x${1}" == "x${2}" ]; then
			echo "${2}"
		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
#			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $4 }' | sed "s@[[:space:]]@@g")"
			RET_VAL="$(get_arch_parm "${1}" "BIT")"
			if [ "x${RET_VAL}" == "x" ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			else
				echo "${RET_VAL}"
			fi
		fi
	fi
	return
}

function archname_to_lib_suff
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
		if [ "x${1}" == "x${2}" ]; then
			echo "${2}"
		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
#			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $4 }' | sed "s@[[:space:]]@@g")"
			RET_VAL="$(get_arch_parm "${1}" "LIB_SUFF")"
			echo "${RET_VAL}"
		fi
	fi
	return
}

function archbit_to_lib_suff
{
	case "${1}" in
		64)
			echo "64"
			;;
		*)
			echo ""
			;;
	esac
}

function archname_to_archabi
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
		if [ "x${1}" == "x${2}" ]; then
			echo "${2}"
		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $5 }' | sed "s@[[:space:]]@@g")"
			RET_VAL="$(get_arch_parm "${1}" "ABI")"
			if [ "x${RET_VAL}" == "x" ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			else
				echo "${RET_VAL}"
			fi
		fi
	fi
	return
}

function archname_to_cflags
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
		if [ "x${1}" == "x${2}" ]; then
			echo "${2}"
		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
			RET_VAL="$(get_arch_parm "${1}" "CFLAGS")"
			echo "${RET_VAL}"
		fi
	fi
	return
}

function archname_to_cxxflags
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
		if [ "x${1}" == "x${2}" ]; then
			echo "${2}"
		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
			RET_VAL="$(get_arch_parm "${1}" "CXXFLAGS")"
			echo "${RET_VAL}"
		fi
	fi
	return
}

function save_package_version
{
	declare SAVE_PACKAGE_NAME=""
	declare SAVE_PACKAGE_VERSION=""
	if [ "x${1}" == "x" ]; then
		SAVE_PACKAGE_NAME="${STEP_PACKAGENAME}"
	else
		SAVE_PACKAGE_NAME="${1}"
	fi
	if [ "x${2}" == "x" ]; then
		SAVE_PACKAGE_VERSION="${PACKAGE_VERSION}"
	else
		SAVE_PACKAGE_VERSION="${2}"
	fi
	if [ "x${SAVE_PACKAGE_NAME}" == "x" ]; then
		SAVE_PACKAGE_NAME="foo"
	fi
	echo "${SAVE_PACKAGE_VERSION}" > ${COMMON_DIR}/${SAVE_PACKAGE_NAME}.version
	return
}

function get_package_version
{
	declare GET_PACKAGE_NAME="${1}"
	if [ "x${GET_PACKAGE_NAME}" == "x" ]; then
		echo "unknown"
		return
	fi
	if [ ! -f ${COMMON_DIR}/${GET_PACKAGE_NAME}.version ]; then
		echo "noversion"
		return
	fi
	echo "$(cat ${COMMON_DIR}/${GET_PACKAGE_NAME}.version | head -n1)"
	return
}

source ${NEW_TARGET_SYSDIR}/set_env.conf
source ${NEW_TARGET_SYSDIR}/package_env.conf
