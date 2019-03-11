# Monitoring Microsoft SQL Server

Monitoring of SQL Server availability, ressource usage and provided databases is best done by [community-based check_mssql_health.](https://labs.consol.de/nagios/check_mssql_health/)

## Preparation of freetds on NetEye

Enable the default SQL Server verion in freetds. [See related freetds documentation](http://www.freetds.org/userguide/freetdsconf.htm)
Define in /etc/freetds.conf: *Note: This is valid for both NetEye 3 and 4.*
```
[global]
        # TDS protocol version
        tds version = 8.0
```

## Install the compiled version on NetEye

**NetEye 4:**
*Note: This step is done automatically when executing script "run_setup.sh"*
Copy the file "check_mssql_health" to /neteye/shared/monitoring/plugins/

**NetEye 3:**
Copy the file "check_mssql_health.neteye3" to /usr/lib64/nagios/plugins/


## Configuring the Monitoring

[General Plugin documentation is found here](https://labs.consol.de/nagios/check_mssql_health/)

**NetEye 3:** A dedicated Monarch Profile is installed automatically and imporable in section "profiles"

**NetEye 4:** Default service templates are installed when [installing the monitoring template library for NetEye 4](../../../../doc/monitoring_templates.md)

### Advanced plugin usage examples

SQL query requiring encryption:

Note the "$" in the table name of "[Complex table$nB Scheduler Job Log]"

```
# echo "SELECT right(DATEDIFF(minute, GETutcDATE(), max([Start Date_Time])),1 )as 'DIFF' from [NB8RT_PROD].[dbo].[Complex table\$nB Scheduler Job Log] (nolock) where [Start Date_Time] > DATEADD(day, -1, GETutcDATE()) and [Scheduler ID] = '| ./check_mssql_health.pl --mode encode

# ./check_mssql_health.pl --hostname=10.1.1.1 --port=1433 --username=myusername --password=mypassword --mode=sql --name="SELECT%20right%28DATEDIFF%28minute%2C%20GETutcDATE%28%29%2C%20max%28%5BStart%20Date%5FTime%5D%29%29%2C1%20%29as%20%27DIFF%27%20from%20%5BNB8RT%5FPROD%5D%2E%5Bdbo%5D%2E%5BComplex%20table%24nB%20Scheduler%20Job%20Log%5D%20%28nolock%29%20where%20%5BStart%20Date%5FTime%5D%20%3E%20DATEADD%28day%2C%20%2D1%2C%20GETutcDATE%28%29%29%20and%20%5BScheduler%20ID%5D%20%3D%20%27SCHED01%27group%20by%20%20%5BScheduler%20ID%5D%20having%20%20GETutcDATE%28%29%20%3E%20max%28%5BStart%20Date%5FTime%5D%29" --warning 100 --critical 150 --name2 "Anzahl running schedulers:"
OK - running schedulers:: 0 | 'running'=0;100;150;;
```

# Advanced topics

### Building a new version of the Plugin-script

1. Get lastest version from [project portal](https://labs.consol.de/nagios/check_mssql_health/#download)
2. Untar into a local folder
3. Compile according your NetEye environment
   - Define cluster compatible cache file paths
     NetEye 3: /var/cache/nagios
     NetEye 4: WIP: No cluster compatible path had been defined, yet
     Workaround: Make use of /neteye/shared/monitoring/cache/check_mssql_health
     ADVICE: make sure the cache folder exists!
4. Copy the Plugin build in plugins-scripts/ into NetEye Plugin dir

```
#wget https://labs.consol.de/assets/downloads/nagios/check_mssql_health-2.6.4.14.tar.gz
# tar xvfz check_mssql_health-2.6.4.14.tar.gz
# cd check_mssql_health-2.6.4.14/

Compile for NetEye 3:
# ./configure --prefix=/usr/lib64/nagios/plugins --with-nagios-user=nagios --with-nagios-group=nagios --with-perl=/usr/bin/perl --with-statefiles-dir=/var/cache/nagios
# make

Compile for NetEye 4:
# mkdir /neteye/shared/monitoring/cache/check_mssql_health
# ./configure --prefix=/neteye/shared/monitoring/plugins --with-nagios-user=icinga --with-nagios-group=icinga --with-perl=/usr/bin/perl --with-statefiles-dir=/neteye/shared/monitoring/cache/check_mssql_health
# make

NetEye 3:
# cp plugins-scripts/check_mssql_health.pl /usr/lib64/nagios/plugins
NetEye 4:
# cp plugins-scripts/check_mssql_health.pl /neteye/shared/monitoring/plugins/
```

