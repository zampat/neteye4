
# Thruk Configuration extension 

This folder provides configuration and scripts to extend the Neteye 3 monitoring view of Thruk.

[The lookup mechanism for Hosts in NagVis maps is introduced in neteye blog.](https://www.neteye-blog.com/2019/03/monitoring-maps-to-support-your-it-incident-management/)

Enhancements:
1. Action menu items for Services and Host details view
   provide dropdown for each host with direct link to:
  * Highlight NagVis Maps where host is registered (directly or through related hostgroup) 
  * Search host as device in NeDi
  * Search host as asset in AssetManagement (GLPI)
2. Report Scheduling
  * Define Senders email address for report scheduling
3. Thruk NetEye Theme CSS error fix
   Show the red background for hosts with status down in hosts and service details view

# Configuration and Setup

1. Install thruk_local.conf:
Note: Backup your original thruk_local.conf first.
```
cp thruk_local.conf /var/lib/neteye/thruk/thruk_local.conf
```

2. Install discovery script for monitoring maps:
Note: Default pahts for NagVis, Livestatus are defined within .cgi scrip. Adapt if ported to non-NetEye environments.
```
cp monitoring2maps_link.cgi /usr/lib/nagios/cgi/monitoring2maps_link.cgi
```

3. Thruk NetEye Theme CSS error fix
```
patch /var/lib/neteye/thruk/themes/themes-available/Neteye/stylesheets/status.css < themes_NetEye_stylesheets/status.css.diff
```

