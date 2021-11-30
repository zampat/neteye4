## Quick installation guide

### Prerequisites

1. Neteye 4.16+
2. setup and configured Nats service on Neteye

### Building the RPMs

<https://bitbucket.org/andava80/mssql-fileserver/src/develop/>
to build the rpm setup the correct rpmbuild environment and than run scripts ./build_dist.sh && ./build_rpm.sh
in /bin folder put updated binaries

as result there are two rpms:
1. mssql-fileserver-0.6.0-3.x86_64.rpm
2. mssql-fileserver-autosetup-0.6.0-3.x86_64.rpm

### autosetup
script 900_mssql_fileserver_generate_client_certs generates all certificates needed by the service to connect to nats-server

### nats-server
the nats-server user, permission and certification files are named sqltraceTEST

### SPEC FILE DESCRIPTION

#### - FOLDERS

Binaries in /usr/lib64/mssql-fileserver
Working directory in /neteye/shared/mssql-fileserver (with subfolders structured as usual conf & data)
Nats settings in /neteye/shared/nats-server/conf 

```
Name:    mssql-fileserver
Version: 0.1
Release: 3
Summary: mssql-fileserver dot.net 3.1 application

%define lib64_dir /usr/lib64/%{name}
%define working_dir /neteye/shared/%{name}/
%define conf_dir %{working_dir}/conf/
%define data_dir %{working_dir}/data/
%define nats_server_conf_dir  %{ne_shared_dir}/nats-server/conf/
```

here are reported some common variables important for our install process
```
#Common variables in spec files

#NetEye directories
%define ne_local_dir            /neteye/local/
%define ne_shared_dir           /neteye/shared/
%define ne_script_dir           %{ne_dir}/scripts/
%define ne_dir                  %{_datadir}/neteye/
%define ne_ug_dir               %{ne_dir}/userguide/
%define ne_secure_install_dir   %{ne_dir}/secure_install/
%define ne_secure_install_es_only_dir    %{ne_dir}/secure_install_elastic_only/
%define ne_secure_install_voting_only_dir %{ne_dir}/secure_install_voting_only/
%define ne_secure_install_satellites_dir %{ne_dir}/secure_install_satellite/
%define ne_local_checks_dir     %{ne_dir}/local_checks/
%define wwwconfigdir            %{_sysconfdir}/httpd/conf.d
%define phpconfigdir            %{ne_local_dir}/php/conf/php.d/
%define phpfpmconfigdir         %{ne_local_dir}/php/conf/php-fpm.d/
%define icingaweb_modules_dir   %{_datadir}/icingaweb2/modules/
%define icingaweb_modules_conf_dir   %{ne_shared_dir}/icingaweb2/conf/modules/
%define packages_d		%{ne_script_dir}/packages_structure/packages.d/

%define systemd_dir             %{_prefix}/lib/systemd/system/
%define systemd_plugin_dir      %{_sysconfdir}/systemd/system/
# Do not use this! this is deprecated, and identical to ne_dir
%define ne_usr_share_dir         /usr/share/neteye/
# directory where we install all the *.conf.tpl files for cluster services installation
%define ne_cluster_templates_dir %{ne_dir}/cluster/templates

#Internal URLs
%define wp_mirror            http://developers.wuerth-phoenix.com/static/downloads
```

#### - INSTALL 

service file is created and added to neteye services
```
# systemd
mkdir -pv %{buildroot}/%{systemd_dir}
cp -pv ./conf/systemd/%{name}.service %{buildroot}/%{systemd_dir}
mkdir -p %{buildroot}/%{systemd_plugin_dir}
cp -prv ./conf/systemd/*.service.d %{buildroot}/%{systemd_plugin_dir}
cp -prv ./conf/systemd/*.target.d %{buildroot}/%{systemd_plugin_dir}
```

binary files are copied
```
# lib64
mkdir -pv %{buildroot}/%{lib64_dir}
cp -pv bin/* %{buildroot}/%{lib64_dir}
```

data directory is created (all sql files are stored here)
```
# data
mkdir -pv %{buildroot}/%{data_dir}
```

conf directory is created
```
# conf
mkdir -p %{buildroot}/%{conf_dir}
cp -prv ./conf/%{name}/* %{buildroot}/%{conf_dir}
```

drdb replica for folder /neteye/shared/mssql-fileserver
```
# templates
mkdir -p %{buildroot}%{ne_cluster_templates_dir}
cp -pv ./conf/cluster/Services-mssql-fileserver.conf.tpl %{buildroot}%{ne_cluster_templates_dir}
```

autosetup script is added to neteye_secure_install forest
```
# autosetup
mkdir -p %{buildroot}%{ne_secure_install_dir}
cp -pv src/scripts/autosetup/*.sh %{buildroot}%{ne_secure_install_dir}
```

setup for nats-server connection
```
# install nats auth
%{__mkdir_p} %{buildroot}/%{nats_server_conf_dir}
cp -prv conf/nats-server/* %{buildroot}/%{nats_server_conf_dir}
```

#### - FILES PERMISSION

mssql-fileserver.service runs as root and all permissions are given accordingly
next step: create a dedicated user automatically

nats-server user (nats) has read rights on mssql-fileserver nats-server's configuration files 

## INSTALLATION PROCEDURE

```
rpm -ivh mssql-fileserver-0.6.0-3.x86_64.rpm
rpm -ivh mssql-fileserver-autosetup-0.6.0-3.x86_64.rpm
neteye_secure_install
neteye start
```
validation
```
service mssql-fileserver status
```

if you encounter the issue of connection to nats-server try restart both services with following steps

```
service nats-server restart
service mssql-fileserver restart
service mssql-fileserver status
```

## UNINSTALL PROCEDURE

```
rpm -ve mssql-fileserver-autosetup-0.6.0-3.x86_64.rpm
rpm -ve mssql-fileserver-0.6.0-3.x86_64.rpm
```

NOTE: \neteye\shared\mssql-fileserver\ is not removed

## UPGRADE

upgrade is unistall of old version and install of new version, than \neteye\shared\mssql-fileserver\conf\sqlservertrace.conf and other files are overwritten(take care in case of settings edited manually!)

## NEXT STEPS

1. httpd settings for files download
2. dedicated user
3. docus added to neteye'documentation
