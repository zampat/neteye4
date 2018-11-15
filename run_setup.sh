#!/bin/bash

# VARIABLES DEFINITION
ICINGA2_AGENT_VERSION="2.10.1"

NETEYESHARE_ROOT_PATH="/neteye/shared/neteyeshare"
NETEYESHARE_MONITORING="${NETEYESHARE_ROOT_PATH} + /monitoring"



# Init share folder structure
#
./scripts/010_init_neteyeshare.sh

# Icinga2 Agents
#
./scripts/020_get_icinga2_agents.sh $ICINGA2_AGENT_VERSION

# Icinga2 Configuration of defaults
#
# LDAP Ressource
./scripts/030_ressources_init.sh

# Monitoring Templates Import
#
./scripts/040_monitoring_templates_init.sh


# Monitoring Plugins Import
#
./scripts/050_monitoring_plugins_extra_init.sh $NETEYESHARE_MONITORING
./scripts/051_monitoring_plugins_activate.sh
