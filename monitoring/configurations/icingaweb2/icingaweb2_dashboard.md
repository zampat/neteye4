# Extending default Icingaweb2 / NetEye Dashboard

Icingaweb2 provides a default dashboard in menu "Dashboard".
The default dashboard is defined within a .php code file an might be extended adding new elements

__Warning: This approach is absolutely NOT update save and settings have to be recreated after each update!__

```
# diff -ruN /usr/share/icingaweb2/modules/monitoring/configuration.php.orig /usr/share/icingaweb2/modules/monitoring/configuration.php
--- /usr/share/icingaweb2/modules/monitoring/configuration.php.orig     2019-10-10 15:47:58.037832728 +0200
+++ /usr/share/icingaweb2/modules/monitoring/configuration.php  2019-10-10 15:55:37.656922351 +0200
@@ -301,6 +301,13 @@
     'monitoring/list/hosts?host_problem=1&sort=host_severity'
 );

+$dashboard = $this->dashboard(N_('Wuerth Phoenix Dashboard'), array('priority' => 40));
+$dashboard->add(
+    N_('My Hosts'),
+    'monitoring/list/hosts?(host=*pbz*|host_display_name=*my_filter*)'
+);
+
+
 /*
  * Overview
  */

```
