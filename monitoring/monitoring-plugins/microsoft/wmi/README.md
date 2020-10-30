
# Install and Configuration instructions

## Introduction

The use of valuable Plugin `check_wmi_plus` is suggested.

Project site: 
http://www.edcint.co.nz/checkwmiplus/

Introduction and Configuration of WMI:
https://www.neteye-blog.com/2018/03/wmi-based-microsoft-server-monitoring/

Additional configurations needed for setup on NetEye 3/4 are provided here.

Credits to the authors of http://www.edcint.co.nz/checkwmiplus/


### Install required Perl modules.
- NetEye3: RPMs are provided on repo of neteye
- Neteye4: Use provided RPMs from folder `neteye4/`

### Apply configuration from `check_wmi_plus.conf` to `./etc/check_wmi_plus/`
Define:
- `$base_dir='/usr/lib64/nagios/plugins'; # NetEye 3`
- `$base_dir='/neteye/local/monitoring/plugins'; # NetEye 4`
- `$ignore_my_outdated_perl_module_versions=1; # CHANGE THIS IF NEEDED`

### Install check_wmi_plus in NetEye Plugins Dir:

Path NetEye 3: `/usr/lib64/nagios/plugins`
Path NetEye 4: `/neteye/local/monitoring/plugins`

- Copy the `check_wmi_plus.pl` 
- Copy the folder `etc/`
