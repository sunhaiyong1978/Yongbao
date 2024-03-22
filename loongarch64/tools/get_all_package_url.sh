#!/bin/bash

BASE_DIR="${PWD}"
NEW_TARGET_SYSDIR="${PWD}/workbase"
source env/function.sh

function set_proxy
{
        declare DOMAIN=$(echo ${1} | grep -o ".\{0,\}//[^/]\{0,\}" | awk -F'/' '{print $NF}')
        declare PROXY_SERVER=$(cat proxy.set | grep -v "^#" | grep "${DOMAIN} " | awk -F' ' '{ print $2 }')
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
	if [ "x${2}" == "x" ]; then
		return ""
	fi
	VERSION_STR="$(ls ${BASE_DIR}/files/step/${1}/ 2>/dev/null)"
	if [ "x$?" == "x0" ]; then
		echo "${VERSION_STR}" | sort -V | uniq | tail -n2 | head -n1
	else
		return ""
	fi
}

declare GIT_ONLY=FALSE
declare GIT_UPDATE=FALSE
declare FORCE_DOWN=FALSE
declare RESOURCES_ONLY=FALSE
declare PROXY_MODE=0
declare INDEX_FILE=""

while getopts 'gfuri:ph' OPT; do
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
            exit 0
            ;;
    esac
done
shift $(($OPTIND - 1))

mkdir -p ${BASE_DIR}/downloads/sources/{files,hash}
mkdir -p ${BASE_DIR}/downloads/sources/git
FAIL_COUNT=1
NO_FILE="警告："
if [ ! -d logs ]; then
	mkdir -p logs
fi
echo "" > logs/download_fail.log

if [ "x${1}" == "x" ]; then
        STEP_FILE="$(cat step | grep -v "^#")"
else
        STEP_FILE="$(cat step | grep -v "^#" | grep "/${1}")"
fi

declare SAVE_FILENAME=""

if [ "x${INDEX_FILE}" == "x" ]; then
	STEP_ARRAY="$(echo "${STEP_FILE}" | sed "s@%step/@@g" | awk -F'|' '{ print $1 }' | uniq)"
else
	STEP_ARRAY="$(cat ${INDEX_FILE} | grep -v "^#" | awk -F' ' '{ print $2 }' | sed "s@step/@@g" | awk -F'|' '{ print $1 }' | uniq)"
fi

echo -n "" > ${BASE_DIR}/downloads/sources/files.list.tmp
echo -n "" > ${BASE_DIR}/downloads/sources/resources.list.tmp

for i in ${STEP_ARRAY}
do
	PKG_NAME="$(cat scripts/step/${i}.info | awk -F'|' '{ print $1 }')"
	PKG_VERSION="$(cat scripts/step/${i}.info | awk -F'|' '{ print $2 }')"
	DOWNLOAD_TYPE=$(cat sources/url/${i} | awk -F'|' '{ print $1 }')
	URL="$(replace_arch_parm "$(cat sources/url/${i} | awk -F'|' '{ print $2 }')" )"
	SAVE_FILENAME="$(replace_arch_parm "$(cat sources/url/${i} | awk -F'|' '{ print $3 }')" )"
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
				if [ "x${FORCE_DOWN}" == "xFALSE" ] && [ -f ${BASE_DIR}/downloads/sources/files/${SAVE_FILENAME} ] && [ -f ${BASE_DIR}/downloads/sources/hash/${SAVE_FILENAME}.hash ] && [ "x$(md5sum ${BASE_DIR}/downloads/sources/files/${SAVE_FILENAME} | awk -F' ' '{print $1}')" == "x$(cat ${BASE_DIR}/downloads/sources/hash/${SAVE_FILENAME}.hash)" ]; then
					echo "$i 所需源码包已下载。"
				else
					if [ -f ${BASE_DIR}/downloads/sources/files/${SAVE_FILENAME}.commit ]; then
						rm -f ${BASE_DIR}/downloads/sources/files/${SAVE_FILENAME}.commit
					fi
					if [ "x${FORCE_DOWN}" == "xTRUE" ]; then
						rm -f ${BASE_DIR}/downloads/sources/files/${SAVE_FILENAME}
					fi
					echo "下载：$i 所需源码包到${BASE_DIR}/downloads/sources/files/${SAVE_FILENAME}..."
					# wget -c ${URL} -O ${BASE_DIR}/downloads/sources/files/${URL##*/}
					wget -c ${URL} -O ${BASE_DIR}/downloads/sources/files/${SAVE_FILENAME}
					if [ "x$?" != "x0" ]; then
						echo "${URL} 下载失败！"
						echo "下载 ${URL} 失败！" >> logs/download_fail.log
						((FAIL_COUNT++))
						continue;
					fi
					md5sum ${BASE_DIR}/downloads/sources/files/${SAVE_FILENAME} | awk -F' ' '{print $1}' > ${BASE_DIR}/downloads/sources/hash/${SAVE_FILENAME}.hash
				fi
				echo "${SAVE_FILENAME}" >> ${BASE_DIR}/downloads/sources/files.list.tmp
			fi
			;;
		GIT)
			if [ -f sources/url/${i}.gitinfo ]; then
				PKG_GIT_BRANCH="$(cat sources/url/${i}.gitinfo | awk -F'|' '{ print $1 }')"
				PKG_GIT_COMMIT="$(cat sources/url/${i}.gitinfo | awk -F'|' '{ print $2 }')"
				PKG_GIT_SUBMODULE="$(cat sources/url/${i}.gitinfo | awk -F'|' '{ print $3 }')"
			else
				PKG_GIT_BRANCH=""
				PKG_GIT_COMMIT=""
				PKG_GIT_SUBMODULE="0"
			fi
			if ( [ "x${FORCE_DOWN}" == "xFALSE" ] || [ "x$(eval echo \${FORCE_$(echo ${PKG_NAME}_${PKG_VERSION} | sed -e "s@-@_@g" -e "s@\.@_@g" )_git})" == "x1" ] ) && [ -f ${BASE_DIR}/downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz ] && [ -f ${BASE_DIR}/downloads/sources/hash/${PKG_NAME}-${PKG_VERSION}_git.tar.gz.hash ]; then
				echo "$i 所需源码包已下载。"
			else
				if [ -f ${BASE_DIR}/downloads/sources/hash/${PKG_NAME}-${PKG_VERSION}_git.tar.gz.hash ]; then
					rm -f ${BASE_DIR}/downloads/sources/hash/${PKG_NAME}-${PKG_VERSION}_git.tar.gz.hash
				fi
				if [ -f ${BASE_DIR}/downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz ]; then
					rm -f ${BASE_DIR}/downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz
				fi
				if [ -d ${BASE_DIR}/downloads/sources/git/${PKG_NAME}-${PKG_VERSION}_git ]; then
					rm -rf ${BASE_DIR}/downloads/sources/git/${PKG_NAME}-${PKG_VERSION}_git/
				fi
				if [ -d ${BASE_DIR}/downloads/sources/resource_git/${PKG_NAME}/${PKG_NAME}-${PKG_VERSION}_git ]; then
					rm -rf ${BASE_DIR}/downloads/sources/resource_git/${PKG_NAME}/${PKG_NAME}-${PKG_VERSION}_git
				fi
				echo "克隆：$i 所需源码包到${BASE_DIR}/downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz..."
				echo ${BASE_DIR}/tools/git_clone.sh "${PKG_NAME}" "${PKG_VERSION}" "${URL}" "${PKG_GIT_BRANCH}" "${PKG_GIT_COMMIT}"
				${BASE_DIR}/tools/git_clone.sh "${PKG_NAME}" "${PKG_VERSION}" "${URL}" "${PKG_GIT_BRANCH}" "${PKG_GIT_COMMIT}" "${PKG_GIT_SUBMODULE}"
				if [ "x$?" != "x0" ]; then
					echo "${URL} 克隆失败！"
					echo "克隆 ${URL} 失败！" >> logs/download_fail.log
					((FAIL_COUNT++))
					continue;
				fi
				if [ -f ${BASE_DIR}/downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz ]; then
					md5sum ${BASE_DIR}/downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz | awk -F' ' '{print $1}' > ${BASE_DIR}/downloads/sources/hash/${PKG_NAME}-${PKG_VERSION}_git.tar.gz.hash
					eval FORCE_$(echo ${PKG_NAME}_${PKG_VERSION} | sed -e "s@-@_@g" -e "s@\.@_@g" )_git=1
				else
					echo "downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz 文件未找到，请检查！"
					echo "${i} 步骤中克隆 ${URL} 的打包文件 downloads/sources/files/${PKG_NAME}-${PKG_VERSION}_git.tar.gz 未找到！" >> logs/download_fail.log
					((FAIL_COUNT++))
					continue;
				fi
			fi
			echo "${PKG_NAME}-${PKG_VERSION}_git.tar.gz" >> ${BASE_DIR}/downloads/sources/files.list.tmp
			;;
		FILE)
			if [ -f ${BASE_DIR}/sources/files/${SAVE_FILENAME} ]; then
				echo "复制：$i 所需源码包到${BASE_DIR}/downloads/sources/files/${SAVE_FILENAME}..."
				cp -a ${BASE_DIR}/sources/files/${URL##*/} ${BASE_DIR}/downloads/sources/files/${SAVE_FILENAME}
			else
				NO_FILE="${NO_FILE}
${i} 没有找到所需的文件${URL##*/}，请检查。"
			fi
			echo "${SAVE_FILENAME}" >> ${BASE_DIR}/downloads/sources/files.list.tmp
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


	if [ -d ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/ ] && [ "x$(find ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/ -name *.url)" != "x" ]; then
		echo "发现${i}存在需要下载的资源文件……"
		for url_i in $(ls ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/*.url)
		do
			RESOURCES_URL="$(cat ${url_i} | grep ^URL= | awk -F'=' '{ print $2 }' | sed "s@<<<PACKAGE_VERSION>>>@${PKG_VERSION}@g")"
			RESOURCES_FILENAME="$(cat ${url_i} | grep ^FILENAME= | awk -F'=' '{ print $2 }' | sed "s@<<<PACKAGE_VERSION>>>@${PKG_VERSION}@g")"
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
						if [ "x${FORCE_DOWN}" == "xFALSE" ] && ([ "x${GIT_UPDATE}" == "xFALSE" ] || [ "x${PKG_GIT_COMMIT}" != "x" ]) && [ -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz ] && [ -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz.hash ]; then
							echo "$i 所需源码包 ${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz 已下载。"
						else
							if [ -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz.hash ]; then
								rm -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz.hash
							fi
							if [ -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz ]; then
								rm -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz
							fi
							if [ -d ${BASE_DIR}/downloads/sources/resource_git/${PKG_NAME}/${PKG_NAME}-${RESOURCES_FILENAME}_git/ ]; then
								rm -rf ${BASE_DIR}/downloads/sources/resource_git/${PKG_NAME}/${PKG_NAME}-${RESOURCES_FILENAME}_git/
							fi
							echo "克隆：$i 所需资源文件到${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz..."
							mkdir -p ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/{files,hash}/
							echo ${BASE_DIR}/tools/git_clone.sh -d "${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/" "${PKG_NAME}" "${RESOURCES_FILENAME}" "${RESOURCES_URL}" "${PKG_GIT_BRANCH}" "${PKG_GIT_COMMIT}" "${PKG_GIT_SUBMODULE}"
							${BASE_DIR}/tools/git_clone.sh -d "${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/" "${PKG_NAME}" "${RESOURCES_FILENAME}" "${RESOURCES_URL}" "${PKG_GIT_BRANCH}" "${PKG_GIT_COMMIT}" "${PKG_GIT_SUBMODULE}"
							if [ "x$?" != "x0" ]; then
								echo "${URL} 克隆失败！"
								echo "克隆 ${URL} 失败！" >> logs/download_fail.log
								((FAIL_COUNT++))
								continue;
							fi
							if [ -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz ]; then
								md5sum ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz | awk -F' ' '{print $1}' > ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz.hash
							else
								echo "${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz 文件未找到，请检查！"
								echo "${i} 步骤中所需资源文件从 ${URL} 克隆的打包文件 ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz 未找到！" >> logs/download_fail.log
								((FAIL_COUNT++))
								continue;
							fi
						fi
						echo "${i}/${PKG_VERSION}/files/${PKG_NAME}-${RESOURCES_FILENAME}_git.tar.gz" >> ${BASE_DIR}/downloads/sources/resources.list.tmp
					else
						if [ "x${GIT_ONLY}" == "xFALSE" ]; then
							if [ "x${FORCE_DOWN}" == "xFALSE" ] && [ -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME} ] && [ -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${RESOURCES_FILENAME}.hash ]; then
        			                                echo "$i 所需资源文件${RESOURCES_FILENAME}已下载。"
	        		                        else
								echo "下载${RESOURCES_FILENAME}: ${RESOURCES_URL}..."
								mkdir -p ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/{files,hash}/
								if [ -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME} ]; then
									rm -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME}
								fi
								wget -c ${RESOURCES_URL} -O ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME}
								if [ "x$?" != "x0" ]; then
									echo "${RESOURCES_URL} 下载失败！"
									echo "下载${i}资源文件 ${RESOURCES_URL} 失败！" >> logs/download_fail.log
									((FAIL_COUNT++))
									continue;
								fi
								md5sum ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME} | awk -F' ' '{print $1}' > ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${RESOURCES_FILENAME}.hash
							fi
						fi
						echo "${i}/${PKG_VERSION}/files/${RESOURCES_FILENAME}" >> ${BASE_DIR}/downloads/sources/resources.list.tmp
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

	if [ -d ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/ ] && [ "x$(find ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/ -name *.listfile)" != "x" ]; then
		if [ "x${GIT_ONLY}" == "xFALSE" ]; then
			echo "发现${i}存在需要下载的资源组文件……"
			for listfile_i in $(ls ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/*.listfile)
			do
				LIST_URL="$(cat ${listfile_i} | grep ^URL= | awk -F'=' '{ print $2 }')"
				LIST_FILENAME="$(cat ${listfile_i} | grep ^FILE= | awk -F'=' '{ print $2 }')"
				LIST_NAME="$(basename ${listfile_i})"

				if [ -f ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${LIST_NAME}.hash ] && [ "x$(md5sum ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/${LIST_FILENAME} | awk -F' ' '{print $1}')" == "x$(cat ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${LIST_NAME}.hash)" ]; then
					echo "$i 所需资源组${LIST_NAME}内的文件都已下载。"
				else
					# 从旧版本目录中复制
					OLD_PKG_VERSION="$(get_pkg_old_version ${i} ${PKG_VERSION})"
					if [ "x${OLD_PKG_VERSION}" != "x" ] && [ "x${OLD_PKG_VERSION}" != "x${PKG_VERSION}" ]; then
						echo "从${BASE_DIR}/downloads/files/step/${i}/${OLD_PKG_VERSION}/files/${LIST_NAME}_dir/* 复制到 ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir/"
						cp -a ${BASE_DIR}/downloads/files/step/${i}/${OLD_PKG_VERSION}/files/${LIST_NAME}_dir/* ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir/
					fi

					case "${LIST_URL%%/*}" in
		                                https: | http: | ftps: | ftp:)
							echo "从${LIST_URL}下载${LIST_FILENAME}中的文件..."
							mkdir -p ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/{files,hash}/
							mkdir -p ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir
							wget -c -B ${LIST_URL} -i ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/${LIST_FILENAME} -P ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir/
							if [ "x$?" != "x0" ]; then
								echo "从 ${LIST_URL} 下载资源组文件 ${LIST_FILENAME} 失败！"
								echo "${i}从${LIST_URL}下载资源组文件 ${LIST_FILENAME} 失败！" >> logs/download_fail.log
								((FAIL_COUNT++))
								continue;
							fi
							pushd ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/
								tar -czf ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files/${LIST_NAME}_dir.tar.gz ${LIST_NAME}_dir
							popd
							md5sum ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/${LIST_FILENAME} | awk -F' ' '{print $1}' > ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/hash/${LIST_NAME}.hash
							;;
						*)
							echo "资源组${LIST_FILENAME}中的${LIS_URL} 地址无法识别，下载失败。"
							((FAIL_COUNT++))
							;;
					esac
				fi
#				echo "${i}/${PKG_VERSION}/${LIST_FILENAME}" >> ${BASE_DIR}/downloads/sources/resources.list.tmp
			done
			echo "已完成${i}需要下载的资源文件。"
		fi
	fi

	if [ -d ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/ ] && [ "x$(find ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/ -maxdepth 1 ! -name "*.package_list" ! -name "*.listfile" ! -name "*.url" -type f)" != "x" ]; then
		echo "$(find ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/ -maxdepth 1 ! -name "*.package_list" ! -name "*.listfile" ! -name "*.url" -type f | sed "s@${BASE_DIR}/files/step/@@g")" >> ${BASE_DIR}/downloads/sources/resources.list.tmp
	fi
	if [ -d ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files ] && [ "x$(find ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files -maxdepth 1 ! -name "*.package_list" ! -name "*.listfile" ! -name "*.url" -type f)" != "x" ]; then
		echo "$(find ${BASE_DIR}/downloads/files/step/${i}/${PKG_VERSION}/files -maxdepth 1 ! -name "*.package_list" ! -name "*.listfile" ! -name "*.url" -type f | sed "s@${BASE_DIR}/downloads/files/step/@@g")" >> ${BASE_DIR}/downloads/sources/resources.list.tmp
	fi
#	if [ -d ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/patches ] && [ "x$(find ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/patches -maxdepth 1 -type f)" != "x" ]; then
#		echo "$(find ${BASE_DIR}/files/step/${i}/${PKG_VERSION}/patches -maxdepth 1 -type f | sed "s@${BASE_DIR}/files/step/@@g")" >> ${BASE_DIR}/downloads/sources/patches.list.tmp
#	fi
done

if [ -f ${BASE_DIR}/downloads/sources/files.list.tmp ]; then
	mv ${BASE_DIR}/downloads/sources/files.list{.tmp,}
fi
if [ -f ${BASE_DIR}/downloads/sources/resources.list.tmp ]; then
	mv ${BASE_DIR}/downloads/sources/resources.list{.tmp,}
fi
if [ -f ${BASE_DIR}/downloads/sources/patches.list.tmp ]; then
	mv ${BASE_DIR}/downloads/sources/patches.list{.tmp,}
fi

if [ "x${NO_FILE}" != "x警告：" ]; then
	echo "${NO_FILE}"
fi

if [ "x${FAIL_COUNT}" != "x1" ]; then
	echo "有文件下载失败，请检查失败记录 logs/download_fail.log"
	exit -1
fi
