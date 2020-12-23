#!/bin/bash

# Script action: 
# Copy Default Tornado rules into editor's folder
#

# TORNADO_RULES_DRAFT_DIR="/neteye/shared/tornado/conf/drafts"
TORNADO_RULES_DRAFT_DIR="$1"


# Valiation: Check existency of folder PluginsContrib
if [ ! -d "${TORNADO_RULES_DRAFT_DIR}" ]
then
   echo "[+] 150: tornado_default rules installation into ${TORNADO_RULES_DRAFT_DIR}"

   mkdir -p ${TORNADO_RULES_DRAFT_DIR}
   cp -r monitoring/tornado/tornado_sample_rules/draft_001 ${TORNADO_RULES_DRAFT_DIR}

   chown -R tornado:tornado ${TORNADO_RULES_DRAFT_DIR}

else
   echo "[ ] 150: tornado_default rules already installed in ${TORNADO_RULES_DRAFT_DIR}"

fi

echo "[i] 150: Installation of Tornado rules done."
