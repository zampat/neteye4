
# NetEye 4 community setup section

The present community repository for NetEye 4 provides default configurations, monitoring plugins and third-party scripts to simplify the setup of a NetEye 4 deployment. The deployment of the provided contents is performed by various script modules contained in this folder. The script installs the provided contents while verifying and maintaining existing contents.

## Installation and Update

[Neteye Configurations and Template Library Setup documentation](../doc/050_community_configs_init.md)


## Automated steps by scipts of this folder

- 005_git_submodules_init.sh
  Initialize included submodules

- 010_init_neteyeshare.sh
  Create a folder structure for Agents, Monitoring Configuration and scripts under /neteye/shared/neteyeshare/

- 011_init_neteyeshare_weblink.sh
  Initialize an Apache Alias with authentication for neteyeshare access wia https

- 020_get_icinga2_agents.sh
  Fetch Icinga2 Agents from packages.icinga.org and store in /neteye/shared/neteyeshare/monitoring/agents/

- 030_ressources_init.sh
  Define sample Ressource for LDAP bind.
- 031_root_navigation_sample.sh
  Add additional main menu entries, i.e. the link to the "NetEyeShare"
- 032_role_init.sh
  Add additional user permission roles, i.e. the "viewer"
- 033_authentication_init.sh and 034_auth_groups_init.sh
  Add LDAP users and groups authentication sample

- 040_monitoring_templates_init.sh and 041_icingaweb2_icons_init.sh
  Provide monitoring templates for Icinga Director in neteyeshare. [Read more about neteye template library and how to actate it.](../doc/050_community_configs_init.md)
  Install additional Host Icons in Icinaweb2 folder

- 051_copy_nonproduct_monitoring_git_plugins.sh
  Fetch plugins from thrid-party repositories and place into "neteyeshare"
- 052_install_nonproduct_monitoring_plugins.sh and 053_install_product_monitoring_plugins_before_release.sh
  Activate useful monitoring plugins in PluginsContribDir

- 060_synch_monitoring_plugins.sh
  Synchronize all monitoring plugins to the "neteyeshare"
- 061_sync_monitoring_configurations.sh
  Place additional Icinga2 monitoring configuration into neteyeshare. 
  a) Provide general Dependency apply rule to implement a parent-child hierarchy
- 062_sync_monitoring_analytics.sh
  Place sample Analytics dashboards into neteyeshare.
  a) generic_services_by_hosts.json
  b) generic_snmp_interfaces.json

- 070_synch_itoa.sh
  Synch ITOA agents and dashboards to local neteyeshare folder "itoa".

