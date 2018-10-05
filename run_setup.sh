#!/bin/bash

ICINGA2_AGENT_VERSION="2.9.2"

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
