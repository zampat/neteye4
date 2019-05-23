#!/bin/bash

# NETEYESHARE_LOG="${NETEYESHARE_ROOT_PATH}/log"
DST_LOG_AGENTS_WIN_FOLDER="$1/agents/windows"
SAFED_WIN_VERSION="Safed_1_10_1-1.zip"
SRC_LOG_AGENT_URL="https://www.neteye-blog.com/wp-content/uploads/2019/03/${SAFED_WIN_VERSION}"


if [ ! -f "${DST_LOG_AGENTS_WIN_FOLDER}/${SAFED_WIN_VERSION}" ]
then
   mkdir -p ${DST_LOG_AGENTS_WIN_FOLDER}
   echo "[i] 102: Installing LOG Agent for Windows ${SAFED_WIN_VERSION} to ${DST_LOG_AGENTS_WIN_FOLDER}"
   wget ${SRC_LOG_AGENT_URL} -O ${DST_LOG_AGENTS_WIN_FOLDER}/${SAFED_WIN_VERSION}

else
   echo "[ ] 102: LOG agent already installed"
fi


