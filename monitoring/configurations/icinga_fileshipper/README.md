# Configuration of Icinga2 module `fileshipper`

- `fileshipper` is distributed in NetEye 4 core
- verify that module is enabled
- define a path where to store import files 
- define a global configuration file

### Define folder holding import files
```
# mkdir /neteye/shared/httpd/file-import
```


### Define global configuration file

The path defined in that file will then be available in the Import panel
To define the path, run the following commands:
```
# mkdir /neteye/shared/icingaweb2/conf/modules/fileshipper/
# touch /neteye/shared/icingaweb2/conf/modules/fileshipper/imports.ini
# cat >>/neteye/shared/icingaweb2/conf/modules/fileshipper/imports.ini <<EOM
[NetEye File import]
basedir = "/neteye/shared/httpd/file-import" 
EOM
```
