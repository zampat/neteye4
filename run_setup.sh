#!/bin/bash

ICINGA2_AGENT_VERSION="2.9.2"

# Icinga2 Agents
#
./scripts/010_get_icinga2_agents.sh $ICINGA2_AGENT_VERSION

# Icinga2 Configuration of defaults
#
# LDAP Ressource
./scripts/020_ressources_init.sh
