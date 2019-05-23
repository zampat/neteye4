# Introcuction

NetEye 4 monitoring comes with the aim to provide a simple and ready-for-use approach to get started.
According this objective, templates for quickly setting up the monitoring are needed. This community portal comes with the aim, to provide a collection of templates brought togheter as a restult from many monitoring projects and experience during real-world projects.

The NetEye Template Library is a collection of service templates, host templates and notification templates to implement quickly your monitoring requirements. This library compatible with the [Icinga Template Library (ITL)](https://icinga.com/docs/icinga2/latest/doc/10-icinga-template-library/) and could be adopted and extended by the whole Icinga2 community. Out of this reason, the NetEye Templates Library is [published on a dedicated repository.](https://github.com/zampat/icinga2-monitoring-templates)

## Installing the NetEye Template Library

When installing the present "neteye4" repository (running run_setup.sh) the template library is copied to the local folder "neteyeshare". (Located in /neteye/shared/httpd/)
Here you find a script to perform the import of all template definitions into the Director. Simply execute "run_import.sh" to load all configurations into your monitoring configuration.

```
# cd /neteye/shared/httpd/neteyeshare/monitoring/monitoring-templates/
# ./run_import.sh
```

**Note: A validation for each template is done and if already available NO REPLACE is performed.** To replace a template definition, remove it manually from your configuration and run import agian.

### History Logs

The history logs related to the import exectuion are archived withing this file: import_history.log


Happy Monitoring !
