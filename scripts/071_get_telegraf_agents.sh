#!/bin/bash

DST_ITOA_AGENTS_WIN_FOLDER="$1/agents/windows"
TELEGRAF_AGENT_VERSION=$2
SRC_ITOA_AGENT_URL="https://dl.influxdata.com/telegraf/releases"


if [ ! -f "${DST_ITOA_AGENTS_WIN_FOLDER}/telegraf-${TELEGRAF_AGENT_VERSION}_windows_amd64.zip" ]
then
   mkdir -p ${DST_ITOA_AGENTS_WIN_FOLDER}
   echo "[+] 071: Installing ITOA Agent for Windows of Version ${TELEGRAF_AGENT_VERSION} to ${DST_ITOA_AGENTS_WIN_FOLDER}"
   wget ${SRC_ITOA_AGENT_URL}/telegraf-${TELEGRAF_AGENT_VERSION}_windows_amd64.zip -O ${DST_ITOA_AGENTS_WIN_FOLDER}/telegraf-${TELEGRAF_AGENT_VERSION}_windows_amd64.zip

else
   echo "[ ] 071: ITOA Telegraf agent already installed"
fi


