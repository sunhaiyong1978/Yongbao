#!/bin/bash

BASE_DIR="${PWD}"
# NEW_TARGET_SYSDIR="${PWD}/workbase"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"

if [ -f ${BASE_DIR}/current_branch ]; then
	RELEASE_VERSION="$(cat ${BASE_DIR}/current_branch | grep -v "^#" | grep -v "^$" | head -n1 | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")"
	if [ -d ${BASE_DIR}/Branch_${RELEASE_VERSION} ]; then
		NEW_TARGET_SYSDIR="${BASE_DIR}/Branch_${RELEASE_VERSION}/workbase"
		SCRIPTS_DIR="${BASE_DIR}/Branch_${RELEASE_VERSION}/scripts"
		SOURCES_DIR="${BASE_DIR}/Branch_${RELEASE_VERSION}/sources"
		NEW_BASE_DIR="${BASE_DIR}/Branch_${RELEASE_VERSION}"
		RELEASE_BUILD_MODE=1
#		echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将在指定目录中进行构建。"
	else
#		echo "没有发现 Branch_${RELEASE_VERSION} 目录。"
		NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
		NEW_BASE_DIR="${BASE_DIR}"
		SCRIPTS_DIR="${BASE_DIR}/scripts"
		SOURCES_DIR="${BASE_DIR}/sources"
		RELEASE_BUILD_MODE=0
	fi
else
	NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	NEW_BASE_DIR="${BASE_DIR}"
	SCRIPTS_DIR="${BASE_DIR}/scripts"
	SOURCES_DIR="${BASE_DIR}/sources"
	RELEASE_BUILD_MODE=0
fi

declare GIT_ONLY=FALSE
declare GIT_UPDATE=FALSE
declare FORCE_DOWN=FALSE
declare RESOURCES_ONLY=FALSE
declare PROXY_MODE=0
declare INDEX_FILE=""
declare SINGLE_PACKAGE=FALSE
declare VERSION_INDEX=""
declare WORLD_PARM=""
declare AUTO_DOWNLOAD_OR_COPY=0

while getopts 'gfuri:pswav:h' OPT; do
    case $OPT in
	g)  
	    GIT_ONLY=TRUE
	    ;;
	f)  
	    FORCE_DOWN=TRUE
	    ;;
	u)
	    GIT_UPDATE=TRUE
	    ;;
	r)
	    RESOURCES_ONLY=TRUE
	    ;;
	p)
	    PROXY_MODE=1
	    ;;
	i)
	    INDEX_FILE=$OPTARG
	    ;;
	s)
	    SINGLE_PACKAGE=TRUE
	    ;;
	w)
            NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
            NEW_BASE_DIR="${BASE_DIR}"
            SCRIPTS_DIR="${BASE_DIR}/scripts"
            SOURCES_DIR="${BASE_DIR}/sources"
            RELEASE_BUILD_MODE=0
	    WORLD_PARM="-w"
	    ;;
	a)
	    AUTO_DOWNLOAD_OR_COPY=1
	    ;;
	v)
	    VERSION_INDEX=$OPTARG
	    ;;
        h|?)
            echo "下载目标系统所涉及的源码包和资源文件。"
            echo ""
            echo "用法: ./`basename $0` [选项] [步骤组/软件包]"
            echo "步骤组/软件包:"
            echo "    用来指定下载范围，通常一个步骤组会包含多个软件包，可以单独软件包名，当指定的软件包名在不同的步骤中都存在时，会一起进行下载。"
            echo "    例如:boot/linux，代表了下载名为“boot”的步骤组内的linux这个软件包所需要的源码包或资源文件。"
            echo "    例如:boot，代表了名为“boot”的步骤组内全部的源码包或资源文件。"
            echo "    例如:linux，如果没有“linux”这个名称的步骤组，则会自动查询所有步骤组中是否存在linux这个软件包所对应的源码包，如果存在多个则会一起进行下载，若找不到则会提示错误。"
            echo "    不指定步骤组/软件包时代表全部软件包和资源文件都需要进行下载。"
            echo "选项:"
            echo "    -h: 当前帮助信息。"
            echo "    -f: 无论之前是否下载过，都强制下载软件源码包及资源文件。"
            echo "    -g: 仅对使用GIT协议的软件包进行下载。"
            echo "    -r: 仅对软件包的资源文件进行下载。"
            echo "    -u: 与-g参数配合使用，仅对使用GIT协议的软件包中没有指定分支（branch）或提交（commit）的源码包或资源文件进行下载。"
            echo "    -p: 使用proxy.set文件，通过该文件中的设置在下载过程中使用代理。"
            echo "    -i <文件名>: 指定索引文件，并根据索引文件中的内容下载所需源码包和资源文件。"
            echo "    -s: 指定独立的软件包，该参数优先级低于-i参数指定索引文件的，当不使用-i指定时该参数才可生效。"
	    echo "    -v <版本名>: 指定下载“版本名”对应的软件包，部分软件包可提供多个“版本名”，该参数设置后将仅下载存在该指定“版本名”的软件包。
	    echo "    -w: 强制使用主线环境中的下载地址，不指定该参数将使用 current_branch 中指定的分支环境中的下载地址，若不存在 current_branch 文件则默认使用主线环境。
	    echo "    -a: 自动根据下载协议决定下载到的位置，存在 current_branch 文件指定版本名时该参数会根据下载文件的类型而自动选择存放的目录，GIT类型协议的文件下载到分支环境的目录中，而普通文件则下载到主线环境的目录中，若不存在 current_branch 文件则全部下载在主线环境的目录中。"
            exit 0
            ;;
    esac
done
shift $(($OPTIND - 1))

source ${NEW_BASE_DIR}/env/function.sh

function set_proxy
{
        declare DOMAIN=$(echo ${1} | grep -o ".\{0,\}//[^/]\{0,\}" | awk -F'/' '{print $NF}')
        declare PROXY_SERVER=""
	if [ -f proxy.set ]; then 
		PROXY_SERVER=$(cat proxy.set | grep -v "^#" | grep "${DOMAIN} " | awk -F' ' '{ print $2 }')
	fi
        if [ "x${PROXY_SERVER}" == "x" ]; then
                        unset https_proxy
                        unset http_proxy
        else
                        export https_proxy=${PROXY_SERVER}
                        export http_proxy=${PROXY_SERVER}
        fi
}


function get_pkg_old_version
{
	if [ "x${1}" == "x" ]; then
		return ""
	fi
#	if [ "x${2}" == "x" ]; then
#		return ""
#	fi
	VERSION_STR="$(ls ${BASE_DIR}/files/step/${1}/ 2>/dev/null)"
	if [ "x$?" == "x0" ]; then
		echo "${VERSION_STR}" | sort -V | uniq | tail -n2 | head -n1
	else
		return ""
	fi
}



mkdir -p ${NEW_BASE_DIR}/downloads/sources/{files,hash}
mkdir -p ${NEW_BASE_DIR}/downloads/sources/git
FAIL_COUNT=1
NO_FILE="警告："
if [ ! -d logs ]; then
	mkdir -p logs
fi
echo "" > logs/download_fail.log

if [ "x${1}" == "x" ]; then
        STEP_FILE="$(cat ${NEW_BASE_DIR}/step | grep -v "^#")"
else
	if [ "x${SINGLE_PACKAGE}" == "xFALSE" ]; then
	        STEP_FILE="$(cat ${NEW_BASE_DIR}/step | grep -v "^#" | grep "/${1}")"
	else
		STEP_FILE="${1}"
	fi
fi

declare SAVE_FILENAME=""

if [ "x${INDEX_FILE}" == "x" ]; then
	STEP_ARRAY="$(echo "${STEP_FILE}" | sed "s@%step/@@g" | awk -F'|' '{ print $1 }' | uniq)"
else
	STEP_ARRAY="$(cat ${INDEX_FILE} | grep -v "^#" | awk -F' ' '{ print $2 }' | sed "s@step/@@g" | awk -F'|' '{ print $1 }' | uniq)"
fi

echo -n "" > ${NEW_BASE_DIR}/downloads/sources/files.list.tmp
echo -n "" > ${NEW_BASE_DIR}/downloads/sources/resources.list.tmp

for i in ${STEP_ARRAY}
do
	if [ "x${VERSION_INDEX}" == "x" ]; then
		if [ ! -f ${SCRIPTS_DIR}/step/${i}.info ] || [ ! -f ${SOURCES_DIR}/url/${i} ]; then
			echo " $i 所需文件不存在，无法进行源码包及资源包的下载。"
			continue;
		fi
		PKG_NAME="$(cat ${SCRIPTS_DIR}/step/${i}.info | awk -F'|' '{ print $1 }')"
		PKG_VERSION="$(cat ${SCRIPTS_DIR}/step/${i}.info | awk -F'|' '{ print $2 }')"
		DOWNLOAD_TYPE=$(cat ${SOURCES_DIR}/url/${i} | awk -F'|' '{ print $1 }')
		URL="$(replace_arch_parm "$(cat ${SOURCES_DIR}/url/${i} | awk -F'|' '{ print $2 }')" )"
		SAVE_FILENAME="$(replace_arch_parm "$(cat ${SOURCES_DIR}/url/${i} | awk -F'|' '{ print $3 }')" )"
	else
		if [ ! -f ${SCRIPTS_DIR}/step/${i}.${VERSION_INDEX}.info ] || [ ! -f ${SOURCES_DIR}/url/${i}.${VERSION_INDEX} ]; then
			echo " $i 所需文件不存在，无法进行源码包及资源包的下载。"
			continue;
		fi
		PKG_NAME="$(cat ${SCRIPTS_DIR}/step/${i}.${VERSION_INDEX}.info | awk -F'|' '{ print $1 }')"
		PKG_VERSION="$(cat ${SCRIPTS_DIR}/step/${i}.${VERSION_INDEX}.info | awk -F'|' '{ print $2 }')"
		DOWNLOAD_TYPE=$(cat ${SOURCES_DIR}/url/${i}.${VERSION_INDEX} | awk -F'|' '{ print $1 }')
		URL="$(replace_arch_parm "$(cat ${SOURCES_DIR}/url/${i}.${VERSION_INDEX} | awk -F'|' '{ print $2 }')" )"
		SAVE_FILENAME="$(replace_arch_parm "$(cat ${SOURCES_DIR}/url/${i}.${VERSION_INDEX} | awk -F'|' '{ print $3 }')" )"
	fi

	if [ "x${SAVE_FILENAME}" == "x" ]; then
		SAVE_FILENAME="${URL##*/}"
	fi
	if [ "x${URL}" != "x" ] && [ "x${RESOURCES_ONLY}" != "xTRUE" ]; then
	        if [ "x${PROXY_MODE}" == "x1" ]; then
        	        set_proxy "${URL}"
	        fi
		case "${DOWNLOAD_TYPE}" in
		URL)
			if [ "x${GIT_ONLY}" == "xFALSE" ]; then
				if [ "x${FORCE_DOWN}" == "xFALSE" ] && [ -f ${NEW_BASE_DIR}/downloads/sources/files/${SAVE_FILENAME} ] && [ -f ${NEW_BASE_DIR}/downloads/sources/hash/${SAVE_FILENAME}.hash ] && [ "x$(md5sum ${NEW_BASE_DIR}/downloads/sources/files/${SAVE_FILENAME} | awk -F' ' '{print $1}')" == "x$(cat ${NEW_BASE_DIR}/downloads/sources/hash/${SAVE_FILENAME}.hash)" ]; then
					echo "$i 所需源码包已下载。"
				else
					IS_DOWNLOADED=0
					if [ "x${AUTO_DOWNLOAD_OR_COPY}" == "x1" ] && [ "x${NEW_BASE_DIR}" != "x${BASE_DIR}" ] && [ "x${FORCE_DOWN}" == "xFALSE" ]; then
						if [ -f ${BASE_DIR}/downloads/sources/files/${SAVE_FILENAME} ] && [ -f ${BASE_DIR}/downloads/sources/hash/${SAVE_FILENAME}.hash ] && [ "x$(md5sum ${BASE_DIR}/downloads/sources/files/${SAVE_FILENAME} | awk -F' ' '{print $1}')" == "x$(cat ${BASE_DIR}/downloads/sources/hash/${SAVE_FILENAME}.hash)" ]; then
							echo "在主线环境中发现 $i 所需的源码包，进行复制。"
							cp -a ${BASE_DIR}/downloads/sources/files/${SAVE_FILENAME} ${NEW_BASE_DIR}/downloads/sources/files/
							cp -a ${BASE_DIR}/downloads/sources/hash/${SAVE_FILENAME}.hash ${NEW_BASE_DIR}/downloads/sources/hash/
							echo "${SAVE_FILENAME}" >> ${NEW_BASE_DIR}/downloads/sources/files.list.tmp
							IS_DOWNLOADED=1
						fi
					fi
					if [ "x${IS_DOWNLOADED}" == "x0" ]; then
						if [ -f ${NEW_BASE_DIR}/downloads/sources/files/${SAVE_FILENAME}.commit ]; then
							rm -f ${NEW_BASE_DIR}/downloads/sources/files/${SAVE_FILENAME}.commit
						fi
						if [ "x${FORCE_DOWN}" == "xTRUE" ]; then
							rm -f ${NEW_BASE_DIR}/downloads/sources/files/${SAVE_FILENAME}
						fi
						echo "下载：$i 所需源码包到${NEW_BASE_DIR}/downloads/sources/files/${SAVE_FILENAME}..."
						# wget -c ${URL} -O ${BASE_DIR}/downloads/sources/files/${URL##*/}
						wget -c ${URL} -O ${NEW_BASE_DIR}/downloads/sources/files/${SAVE_FILENAME}
						if [ "x$?" != "x0" ]; then
							echo "${URL} 下载失败！"
							echo "下载 ${URL} 失败！" >> logs/download_fail.log
							((FAIL_COUNT++))
							continue;
						fi
						md5sum ${NEW_BASE_DIR}/downloads/sources/files/${SAVE_FILENAME} | awk -F' ' '{print $1}' > ${NEW_BASE_DIR}/downloads/sources/hash/${SAVE_FILENAME}.hash
					fi
					IS_DOWNLOADED=0
				fi
				echo "${SAVE_FILENAME}" >> ${NEW_BASE_DIR}/downloads/sources/files.list.tmp
			fi
			;;
		GIT)
			if [ "x${VERSION_INDEX}" == "x" ]; then
				if [ -f ${SOURCES_DIR}/url/${i}.gitinfo ]; then
					PKG_GIT_BRANCH="$(cat ${SOURCES_DIR}/url/${i}.gitinfo | awk -F'|' '{ print $1 }')"
					PKG_GIT_COMMIT="$(cat ${SOURCES_DIR}/url/${i}.gitinfo | awk -F'|' '{ print $2 }')"
					PKG_GIT_SUBMODULE="$(cat ${SOURCES_DIR}/url/${i}.gitinfo | awk -F'|' '{ print $3 }')"
				else
					PKG_GIT_BRANCH=""
					PKG_GIT_COMMIT=""
					PKG_GIT_SUBMODULE="0"
				fi
			else
				if [ -f ${SOURCES_DIR}/url/${i}.${VERSION_INDEX}.gitinfo ]; then
					PKG_GIT_BRANCH="$(cat ${SOURCES_DIR}/url/${i}.${VERSION_INDEX}.gitinfo | awk -F'|' '{ print $1 }')"
					PKG_GIT_COMMIT="$(cat ${SOURCES_DIR}/url/${i}.${VERSION_INDEX}.gitinfo | awk -F'|' '{ print $2 }')"
					PKG_GIT_SUBMODULE="$(cat ${SOURCES_DIR}/url/${i}.${VERSION_INDEX}.gitinfo | awk -F'|' '{ print $3 }')"
				else
					PKG_GIT_BRANCH=""
					PKG_GIT_COMMIT=""
					PKG_GIT_SUBMODULE="0"
				fi
			fi
			if ( [ "x${FORCE_DOWN}" == "xFALSE" ] || [ "x$(eval echo \${FORCE_$(echo ${PKG_NAME}_${PKG_VERSION} | sed -e "s@-@_@g" -e "s@\.@_@g" )_git})" == "x1" ] ) && [ -f ${NEW_BASE_DIR}/downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz ] && [ -f ${NEW_BASE_DIR}/downloads/sources/hash/${PKG_NAME}-${PKG_VERSION}_git.tar.gz.hash ]; then
				echo "$i 所需源码包已下载。"
			else
				if [ -f ${NEW_BASE_DIR}/downloads/sources/hash/${PKG_NAME}-${PKG_VERSION}_git.tar.gz.hash ]; then
					rm -f ${NEW_BASE_DIR}/downloads/sources/hash/${PKG_NAME}-${PKG_VERSION}_git.tar.gz.hash
				fi
				if [ -f ${NEW_BASE_DIR}/downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz ]; then
					rm -f ${NEW_BASE_DIR}/downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz
				fi
				if [ -d ${NEW_BASE_DIR}/downloads/sources/git/${PKG_NAME}-${PKG_VERSION}_git ]; then
					rm -rf ${NEW_BASE_DIR}/downloads/sources/git/${PKG_NAME}-${PKG_VERSION}_git/
				fi
				if [ -d ${NEW_BASE_DIR}/downloads/sources/resource_git/${PKG_NAME}/${PKG_NAME}-${PKG_VERSION}_git ]; then
					rm -rf ${NEW_BASE_DIR}/downloads/sources/resource_git/${PKG_NAME}/${PKG_NAME}-${PKG_VERSION}_git
				fi
				echo "克隆：$i 所需源码包到 ${NEW_BASE_DIR}/downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz ..."
				echo ${BASE_DIR}/tools/git_clone.sh ${WORLD_PARM} -d "${NEW_BASE_DIR}/downloads/sources/files/" "${PKG_NAME}" "${PKG_VERSION}" "${URL}" "${PKG_GIT_BRANCH}" "${PKG_GIT_COMMIT}"
				${BASE_DIR}/tools/git_clone.sh ${WORLD_PARM} -d "${NEW_BASE_DIR}/downloads/sources/files/" "${PKG_NAME}" "${PKG_VERSION}" "${URL}" "${PKG_GIT_BRANCH}" "${PKG_GIT_COMMIT}" "${PKG_GIT_SUBMODULE}"
				if [ "x$?" != "x0" ]; then
					echo "${URL} 克隆失败！"
					echo "克隆 ${URL} 失败！" >> ${NEW_BASE_DIR}/logs/download_fail.log
					((FAIL_COUNT++))
					continue;
				fi
				if [ -f ${NEW_BASE_DIR}/downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz ]; then
					md5sum ${NEW_BASE_DIR}/downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz | awk -F' ' '{print $1}' > ${NEW_BASE_DIR}/downloads/sources/hash/${PKG_NAME}-${PKG_VERSION}_git.tar.gz.hash
					eval FORCE_$(echo ${PKG_NAME}_${PKG_VERSION} | sed -e "s@-@_@g" -e "s@\.@_@g" )_git=1
				else
					echo "${NEW_BASE_DIR}/downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz 文件未找到，请检查！"
					echo "${i} 步骤中克隆 ${URL} 的打包文件 ${NEW_BASE_DIR}/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz 未找到！" >> ${NEW_BASE_DIR}/logs/download_fail.log
					((FAIL_COUNT++))
					continue;
				fi
			fi
			echo "${PKG_NAME}-${PKG_VERSION}_git.tar.gz" >> ${NEW_BASE_DIR}/downloads/sources/files.list.tmp
			;;
		FILE)
			if [ -f ${NEW_BASE_DIR}/sources/files/${SAVE_FILENAME} ]; then
				echo "复制：$i 所需源码包到${NEW_BASE_DIR}/downloads/sources/files/${SAVE_FILENAME}..."
				cp -a ${NEW_BASE_DIR}/sources/files/${URL##*/} ${NEW_BASE_DIR}/downloads/sources/files/${SAVE_FILENAME}
			else
				NO_FILE="${NO_FILE}
${i} 没有找到所需的文件${URL##*/}，请检查。"
			fi
			echo "${SAVE_FILENAME}" >> ${NEW_BASE_DIR}/downloads/sources/files.list.tmp
			;;
		*)
			echo "$i:		${URL%%/*}"
			;;
		esac
	else
		if [ "x${RESOURCES_ONLY}" != "xTRUE" ]; then
			case "${DOWNLOAD_TYPE}" in
        	        	NULL)
					echo "$i 无需下载源码。"
					;;
				*)
					NO_FILE="${NO_FILE}
${i} 没有下载路径，请检查。"
					;;
			esac
		fi
	fi


	if [ -d ${NEW_BASE_DIR}/files/step/${i}/${PKG_VERSION}/ ] && [ "x$(find ${NEW_BASE_DIR}/files/step/${i}/${PKG_VERSION}/ -name *.url)" != "x" ]; then
		echo "发现${i}存在需要下载的资源文件……"
		for url_i in $(ls ${NEW_BASE_DIR}/files/step/${i}/${PKG_VERSION}/*.url)
		do
			RESOURCES_URL="$(cat ${url_i} | grep ^URL= | awk -F'=' '{ print $2 }' | sed "s@<<<PACKAGE_VERSION>>>@$(echo ${PKG_VERSION} | sed "s@-default\$@@g")@g")"
			RESOURCES_FILENAME="$(cat ${url_i} | grep ^FILENAME= | awk -F'=' '{ print $2 }' | sed "s@<<<PACKAGE_VERSION>>>@$(echo ${PKG_VERSION} | sed "s@-default\$@@g")@g")"
			RESOURCES_MODE="$(cat ${url_i} | grep ^MODE= | awk -F'=' '{ print $2 }')"
			PKG_GIT_BRANCH=""
			PKG_GIT_COMMIT=""
			PKG_GIT_SUBMODULE="0"
	        	if [ "x${PROXY_MODE}" == "x1" ]; then
	        	        set_proxy "${RESOURCES_URL}"
		        fi
			case "${RESOURCES_URL%%/*}" in
		                https: | http: | ftps: | ftp: | git:)
					if [ "x${RESOURCES_MODE}" == "xGIT" ]; then
						PKG_GIT_BRANCH="$(cat ${url_i} | grep ^GIT_BRANCH= | awk -F'=' '{ print $2 }')"
						PKG_GIT_COMMIT="$(cat ${url_i} | grep ^GIT_COMMIT= | awk -F'=' '{ print $2 }')"
						PKG_GIT_SUBMODULE="$(cat ${url_i} | grep ^GIT_SUBMODULE= | awk -F'=' '{ print $2 }')"
						if [ "x${PKG_GIT_SUBMODULE}" == "x" ]; then
							PKG_GIT_SUBMODULE="0"
						fi
						if [ "x${FORCE_DOWN}" == "xFALSE" ] && ([ "x${GIT_UPDATE}" == "xFALSE" ] || [ "x${PKG_GIT_COMMIT}" != "x" ]) && [ -f ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz ] && [ -f ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz.hash ]; then
							echo "$i 所需源码包 ${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz 已下载。"
						else
							if [ -f ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz.hash ]; then
								rm -f ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz.hash
							fi
							if [ -f ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz ]; then
								rm -f ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz
							fi
							if [ -d ${NEW_BASE_DIR}/downloads/sources/resource_git/${PKG_NAME}/${PKG_NAME}-${RESOURCES_FILENAME}_git/ ]; then
								rm -rf ${NEW_BASE_DIR}/downloads/sources/resource_git/${PKG_NAME}/${PKG_NAME}-${RESOURCES_FILENAME}_git/
							fi
							echo "克隆：$i 所需资源文件到${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz..."
							mkdir -p ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/{files,hash}/
							echo ${BASE_DIR}/tools/git_clone.sh ${WORLD_PARM} -d "${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/" "${PKG_NAME}" "${RESOURCES_FILENAME}" "${RESOURCES_URL}" "${PKG_GIT_BRANCH}" "${PKG_GIT_COMMIT}" "${PKG_GIT_SUBMODULE}"
							${BASE_DIR}/tools/git_clone.sh ${WORLD_PARM} -d "${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/" "${PKG_NAME}" "${RESOURCES_FILENAME}" "${RESOURCES_URL}" "${PKG_GIT_BRANCH}" "${PKG_GIT_COMMIT}" "${PKG_GIT_SUBMODULE}"
							if [ "x$?" != "x0" ]; then
								echo "${URL} 克隆失败！"
								echo "克隆 ${URL} 失败！" >> logs/download_fail.log
								((FAIL_COUNT++))
								continue;
							fi
							if [ -f ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz ]; then
								md5sum ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz | awk -F' ' '{print $1}' > ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz.hash
							else
								echo "${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz 文件未找到，请检查！"
								echo "${i} 步骤中所需资源文件从 ${URL} 克隆的打包文件 ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz 未找到！" >> logs/download_fail.log
								((FAIL_COUNT++))
								continue;
							fi
						fi
						echo "${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz" >> ${NEW_BASE_DIR}/downloads/sources/resources.list.tmp
					else
						if [ "x${GIT_ONLY}" == "xFALSE" ]; then
							if [ "x${FORCE_DOWN}" == "xFALSE" ] && [ -f ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME} ] && [ -f ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${RESOURCES_FILENAME}.hash ]; then
        			                                echo "$i 所需资源文件 ${RESOURCES_FILENAME} 已下载。"
	        		                        else
								IS_DOWNLOADED=0
								if [ "x${AUTO_DOWNLOAD_OR_COPY}" == "x1" ] && [ "x${NEW_BASE_DIR}" != "x${BASE_DIR}" ] && [ "x${FORCE_DOWN}" == "xFALSE" ]; then
									if [ -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME} ] && [ -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${RESOURCES_FILENAME}.hash ]; then
										echo "在主线环境中发现 $i 所需的资源文件 ${RESOURCES_FILENAME} ，进行复制。"
										mkdir -p ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/{files,hash}/
										cp -a ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME} ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/
										cp -a ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${RESOURCES_FILENAME}.hash ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/
										echo "${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME}" >> ${NEW_BASE_DIR}/downloads/sources/resources.list.tmp
#										continue;
										IS_DOWNLOADED=1
									fi
								fi
								if [ "x${IS_DOWNLOADED}" == "x0" ]; then
									echo "下载${RESOURCES_FILENAME}: ${RESOURCES_URL}..."
									mkdir -p ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/{files,hash}/
									if [ -f ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME} ]; then
										rm -f ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME}
									fi
									wget -c ${RESOURCES_URL} -O ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME}
									if [ "x$?" != "x0" ]; then
										echo "${RESOURCES_URL} 下载失败！"
										echo "下载${i}资源文件 ${RESOURCES_URL} 失败！" >> logs/download_fail.log
										((FAIL_COUNT++))
										continue;
									fi
									md5sum ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME} | awk -F' ' '{print $1}' > ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${RESOURCES_FILENAME}.hash
								fi
								IS_DOWNLOADED=0
							fi
						fi
						echo "${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME}" >> ${NEW_BASE_DIR}/downloads/sources/resources.list.tmp
					fi
					;;
				*)
					echo "${RESOURCES_URL} 地址无法识别，下载失败。"
					((FAIL_COUNT++))
					;;
			esac
		done
		echo "已完成${i}需要下载的资源文件。"
	fi

	if [ -d ${NEW_BASE_DIR}/files/step/${i}/${PKG_VERSION}/ ] && [ "x$(find ${NEW_BASE_DIR}/files/step/${i}/${PKG_VERSION}/ -name *.listfile)" != "x" ]; then
		if [ "x${GIT_ONLY}" == "xFALSE" ]; then
			echo "发现${i}存在需要下载的资源组文件……"
			for listfile_i in $(ls ${NEW_BASE_DIR}/files/step/${i}/${PKG_VERSION}/*.listfile)
			do
				LIST_URL="$(cat ${listfile_i} | grep ^URL= | awk -F'=' '{ print $2 }')"
				LIST_FILENAME="$(cat ${listfile_i} | grep ^FILE= | awk -F'=' '{ print $2 }')"
				LIST_NAME="$(basename ${listfile_i})"

#				if [ -f ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${LIST_NAME}.hash ] && [ "x$(md5sum ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/${LIST_FILENAME} | awk -F' ' '{print $1}')" == "x$(cat ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${LIST_NAME}.hash)" ]; then
				if [ "x${FORCE_DOWN}" == "xFALSE" ] && [ -f ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${LIST_NAME}.hash ] && [ "x$(md5sum ${NEW_BASE_DIR}/files/step/${i}/${PKG_VERSION}/${LIST_FILENAME} | awk -F' ' '{print $1}')" == "x$(cat ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${LIST_NAME}.hash)" ]; then
					echo "$i 所需资源组${LIST_NAME}内的文件都已下载。"
				else
					# 从旧版本目录中复制
					OLD_PKG_VERSION=""
#					OLD_PKG_VERSION="$(get_pkg_old_version ${i} ${PKG_VERSION})"
					OLD_PKG_VERSION="$(get_pkg_old_version ${i})"
					if [ "x${OLD_PKG_VERSION}" != "x" ] && [ "x${OLD_PKG_VERSION}" != "x${PKG_VERSION}" ]; then
						echo "从${BASE_DIR}/downloads/files/step/${i}/${OLD_PKG_VERSION}/files/${LIST_NAME}_dir/* 复制到 ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir/"
						mkdir -p ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/{files,hash}/
						mkdir -p ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir
						cp -a ${BASE_DIR}/downloads/files/step/${i}/${OLD_PKG_VERSION}/files/${LIST_NAME}_dir/* ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir/
					fi

					case "${LIST_URL%%/*}" in
		                                https: | http: | ftps: | ftp:)
							IS_DOWNLOADED=0
							if [ "x${AUTO_DOWNLOAD_OR_COPY}" == "x1" ] && [ "x${NEW_BASE_DIR}" != "x${BASE_DIR}" ] && [ "x${FORCE_DOWN}" == "xFALSE" ]; then
								if [ -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${LIST_NAME}.hash ] && [ "x$(md5sum ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/${LIST_FILENAME} | awk -F' ' '{print $1}')" == "x$(cat ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${LIST_NAME}.hash)" ]; then
									echo "在主线环境中发现 $i 所需资源组 ${LIST_NAME} 内的文件，进行复制。"
									mkdir -p ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/{files,hash}/
									mkdir -p ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir
									cp -a ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir.tar.gz ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/
									cp -a ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${LIST_NAME}.hash ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/
									echo "${i}/${PKG_VERSION}/files/${LIST_NAME}_dir.tar.gz" >> ${NEW_BASE_DIR}/downloads/sources/resources.list.tmp
									IS_DOWNLOADED=1
#									continue;
								fi
							fi
							if [ "x${IS_DOWNLOADED}" == "x0" ]; then
								echo "从${LIST_URL}下载${LIST_FILENAME}中的文件..."
								mkdir -p ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/{files,hash}/
								mkdir -p ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir
								wget -c -B ${LIST_URL} -i ${NEW_BASE_DIR}/files/step/${i}/${PKG_VERSION}/${LIST_FILENAME} -P ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir/
								if [ "x$?" != "x0" ]; then
									echo "从 ${LIST_URL} 下载资源组文件 ${LIST_FILENAME} 失败！"
									echo "${i}从${LIST_URL}下载资源组文件 ${LIST_FILENAME} 失败！" >> logs/download_fail.log
									((FAIL_COUNT++))
									continue;
								fi
								pushd ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/
									tar -czf ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir.tar.gz ${LIST_NAME}_dir
								popd
								md5sum ${NEW_BASE_DIR}/files/step/${i}/${PKG_VERSION}/${LIST_FILENAME} | awk -F' ' '{print $1}' > ${NEW_BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${LIST_NAME}.hash
							fi
							IS_DOWNLOADED=0
							;;
						*)
							echo "资源组${LIST_FILENAME}中的${LIS_URL} 地址无法识别，下载失败。"
							((FAIL_COUNT++))
							;;
					esac
				fi
#				echo "${i}/${PKG_VERSION}/${LIST_FILENAME}" >> ${NEW_BASE_DIR}/downloads/sources/resources.list.tmp
				echo "${i}/${PKG_VERSION}/files/${LIST_NAME}_dir.tar.gz" >> ${NEW_BASE_DIR}/downloads/sources/resources.list.tmp
			done
			echo "已完成${i}需要下载的资源文件。"
		fi
	fi

#	if [ -d ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/ ] && [ "x$(find ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/ -maxdepth 1 ! -name "*.package_list" ! -name "*.listfile" ! -name "*.url" -type f)" != "x" ]; then
#		echo "$(find ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/ -maxdepth 1 ! -name "*.package_list" ! -name "*.listfile" ! -name "*.url" -type f | sed "s@${BASE_DIR}/files/step/@@g")" >> ${BASE_DIR}/downloads/sources/resources.list.tmp
#	fi
#	if [ -d ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files ] && [ "x$(find ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files -maxdepth 1 ! -name "*.package_list" ! -name "*.listfile" ! -name "*.url" -type f)" != "x" ]; then
#		echo "$(find ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files -maxdepth 1 ! -name "*.package_list" ! -name "*.listfile" ! -name "*.url" -type f | sed "s@${BASE_DIR}/downloads/files/step/@@g")" >> ${BASE_DIR}/downloads/sources/resources.list.tmp
#	fi
#	if [ -d ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/patches ] && [ "x$(find ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/patches -maxdepth 1 -type f)" != "x" ]; then
#		echo "$(find ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/patches -maxdepth 1 -type f | sed "s@${BASE_DIR}/files/step/@@g")" >> ${BASE_DIR}/downloads/sources/patches.list.tmp
#	fi
done

if [ -f ${NEW_BASE_DIR}/downloads/sources/files.list.tmp ]; then
	mv ${NEW_BASE_DIR}/downloads/sources/files.list{.tmp,}
fi
if [ -f ${NEW_BASE_DIR}/downloads/sources/resources.list.tmp ]; then
	mv ${NEW_BASE_DIR}/downloads/sources/resources.list{.tmp,}
fi
if [ -f ${NEW_BASE_DIR}/downloads/sources/patches.list.tmp ]; then
	mv ${NEW_BASE_DIR}/downloads/sources/patches.list{.tmp,}
fi

if [ "x${NO_FILE}" != "x警告：" ]; then
	echo "${NO_FILE}"
fi

if [ "x${FAIL_COUNT}" != "x1" ]; then
	echo "有文件下载失败，请检查失败记录 logs/download_fail.log"
	exit -1
fi
