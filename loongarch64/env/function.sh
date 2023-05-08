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
