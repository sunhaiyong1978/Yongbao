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
			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $2 }' | sed "s@[[:space:]]@@g")"
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
			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $3 }' | sed "s@[[:space:]]@@g")"
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
			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $4 }' | sed "s@[[:space:]]@@g")"
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

source ${NEW_TARGET_SYSDIR}/set_env.conf
