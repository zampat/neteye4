#!/bin/bash

# VARIABLES DEFINITION
GIT_MONITORING_TEMPLATES="https://github.com/zampat/icinga2-monitoring-templates.git"


ICINGA2_AGENT_VERSION="2.10.1"

NETEYESHARE_ROOT_PATH="/neteye/shared/neteyeshare"
NETEYESHARE_MONITORING="${NETEYESHARE_ROOT_PATH}/monitoring"

ICINGA2_MASTERCONF_DIR="/neteye/shared/icingaweb2/conf"

MONITORING_PLUGINS_CONTRIB_DIR="/neteye/shared/monitoring/plugins"


# Init share folder structure
#
./scripts/010_init_neteyeshare.sh ${NETEYESHARE_MONITORING}

# Icinga2 Agents
#
./scripts/020_get_icinga2_agents.sh ${NETEYESHARE_MONITORING} ${ICINGA2_AGENT_VERSION}

# Icinga2 Configuration of defaults
#
# LDAP Ressource
./scripts/030_ressources_init.sh ${ICINGA2_MASTERCONF_DIR}

# Monitoring Templates Import
#
./scripts/040_monitoring_templates_init.sh ${NETEYESHARE_ROOT_PATH} ${GIT_MONITORING_TEMPLATES}


# Monitoring Plugins Import
#
./scripts/050_monitoring_plugins.sh $NETEYESHARE_MONITORING
./scripts/051_monitoring_plugins_activate.sh ${MONITORING_PLUGINS_CONTRIB_DIR}
./scripts/052_monitoring_configurations.sh ${NETEYESHARE_MONITORING}
