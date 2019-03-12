
# NetEye 4 community repo installation guide

## Installation

Clone git repository to NetEye filesystem.
Create a dedicated folder within your user's home like /root or /home/any-user/. Then clone git repository into this folder:
```
mkdir /root/git_neteye/ && cd /root/git_neteye/
git clone https://github.com/zampat/neteye4_monitoring_share.git
```

Install contents on NetEye and download external ressources running the installation script.
**Details related the automated activity is documentated below.**
```
./run_setup.sh
```

## Update monitoring plugins from third-party repositories

Clone external repositories into a temporary folder and compare if aupdates are available.
**Note:** Updates to files provided by external repositories should alwasy be promoted as pull requests to the external repository to maintain community culture and keep aligned with external improvements.

This step is automated by running script:
```
./update_monitoring-plugins_from_ext_git.sh
```


## Automated steps by scipts of this folder

- 010_init_neteyeshare.sh
  Create a folder structure for Agents, Monitoring Configuration and scripts under /neteye/shared/neteyeshare/

- 011_init_neteyeshare_weblink.sh
  Initialize an Apache Alias with authentication for neteyeshare access wia https

- 020_get_icinga2_agents.sh
  Fetch Icinga2 Agents from packages.icinga.org and store in /neteye/shared/neteyeshare/monitoring/agents/

- 030_ressources_init.sh
  Define sample Ressource for LDAP bind.

- 040_monitoring_templates_init.sh and 041_icingaweb2_icons_init.sh
  Provide monitoring templates for Icinga Director in neteyeshare
  Install additional Host Icons in Icinaweb2 folder

- 050_copy_nonproduct_monitoring_plugins.sh and 051_copy_nonproduct_monitoring_git_plugins.sh
  Provide monitoring plugins neteyeshare

- 052_install_nonproduct_monitoring_plugins.sh and 053_install_product_monitoring_plugins_before_release.sh
  Activate useful monitoring plugins in PluginsContribDir

- 060_monitoring_configurations.sh
  Place additional Icinga2 monitoring configuration into neteyeshare. 
  a) Provide general Dependency apply rule to implement a parent-child hierarchy

- 061_monitoring_analytics.sh
  Place sample Analytics dashboards into neteyeshare.
  a) generic_services_by_hosts.json
  b) generic_snmp_interfaces.json



