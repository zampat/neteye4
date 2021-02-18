# ORACLE Database monitoring

# Plugin: check_oracle_health

## Configuration and setup

- Install compiled plugin check_oracle_health in PluginContribDir
- Make use of service template "generic_oracle_health" from neteye4 icinga templates
- Install prerequisites for running the plugin:
**Legal note: The oracle client is a proprietary client of Oracle Inc. You need to comply and accept the license agreement and you can downloaded it from the download area as registered Oracle user.**

```
oracle-instantclient<version>-basic-<version>.x86_64
oracle-instantclient<version>-sqlplus-<version>.x86_64

@caragian suggest : 
- oracle-instantclient19.3-basic-19.3.0.0.0-1.x86_64.rpm
- oracle-instantclient19.3-sqlplus-19.3.0.0.0-1.x86_64.rpm

perl-DBD-Pg-2.19.3-4.el7.x86_64
perl-DBD-ODBC-1.50-3.el7.x86_64
perl-DBD-Oracle-1.80-19.3.0.0.0.rhel7.x86_64.rpm
```


Where to download Oracle client
https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html

Where to download the `perl-DBD-Oracle`:
https://rpm.pbone.net/info_idpl_68368613_distro_redhat_el_7_com_perl-DBD-Oracle-1.80-19.3.0.0.0.rhel7.x86_64.rpm.html


**Man page of check_oracle_health --help**

```
Copyright (c) 2008 Gerhard Lausser


  Check various parameters of Oracle databases 

  Usage:
    check_oracle_health [-v] [-t <timeout>] --connect=<connect string>
        --username=<username> --password=<password> --mode=<mode>
        --tablespace=<tablespace>
    check_oracle_health [-h | --help]
    check_oracle_health [-V | --version]

  Options:
    --connect
       the connect string
    --username
       the oracle user
    --password
       the oracle user's password
    --warning
       the warning range
    --critical
       the critical range
    --mode
       the mode of the plugin. select one of the following keywords:
       tnsping                       	(Check the reachability of the server)
       connection-time               	(Time to connect to the server)
       password-expiration           	(Check the password expiry date for users)
       connected-users               	(Number of currently connected users)
       session-usage                 	(Percentage of sessions used)
       process-usage                 	(Percentage of processes used)
       rman-backup-problems          	(Number of rman backup errors during the last 3 days)
       sga-data-buffer-hit-ratio     	(Data Buffer Cache Hit Ratio)
       sga-library-cache-gethit-ratio	(Library Cache (Get) Hit Ratio)
       sga-library-cache-pinhit-ratio	(Library Cache (Pin) Hit Ratio)
       sga-library-cache-reloads     	(Library Cache Reload (and Invalidation) Rate)
       sga-dictionary-cache-hit-ratio	(Dictionary Cache Hit Ratio)
       sga-latches-hit-ratio         	(Latches Hit Ratio)
       sga-shared-pool-reload-ratio  	(Shared Pool Reloads vs. Pins)
       sga-shared-pool-free          	(Shared Pool Free Memory)
       pga-in-memory-sort-ratio      	(PGA in-memory sort ratio)
       invalid-objects               	(Number of invalid objects in database)
       stale-statistics              	(Find objects with stale optimizer statistics)
       corrupted-blocks              	(Number of corrupted blocks in database)
       tablespace-usage              	(Used space in tablespaces)
       tablespace-free               	(Free space in tablespaces)
       container-tablespace-free     	(Free space in tablespaces of container databases)
       tablespace-remaining-time     	(Remaining time until a tablespace is full)
       tablespace-fragmentation      	(Free space fragmentation index)
       tablespace-io-balance         	(balanced io of all datafiles)
       tablespace-can-allocate-next  	(Segments (of a tablespace) can allocate next extent)
       datafile-io-traffic           	(io operations/per sec of a datafile)
       datafiles-existing            	(Percentage of the maximum possible number of datafiles)
       datafiles-recovery            	(Check if datafiles need media recovery)
       datafiles-offline             	(Check if datafiles are offline)
       asm-diskgroup-usage           	(Used space in diskgroups)
       asm-diskgroup-free            	(Free space in diskgroups)
       soft-parse-ratio              	(Percentage of soft parses)
       switch-interval               	(Time between redo log file switches)
       retry-ratio                   	(Redo buffer allocation retries)
       redo-io-traffic               	(Redo log io bytes per second)
       roll-header-contention        	(Rollback segment header contention)
       roll-block-contention         	(Rollback segment block contention)
       roll-hit-ratio                	(Rollback segment hit ratio (gets/waits))
       roll-wraps                    	(Rollback segment wraps (per sec))
       roll-extends                  	(Rollback segment extends (per sec))
       roll-avgactivesize            	(Rollback segment average active size)
       seg-top10-logical-reads       	(user objects among top 10 logical reads)
       seg-top10-physical-reads      	(user objects among top 10 physical reads)
       seg-top10-buffer-busy-waits   	(user objects among top 10 buffer busy waits)
       seg-top10-row-lock-waits      	(user objects among top 10 row lock waits)
       event-waits                   	(processes wait events)
       event-waiting                 	(time spent by processes waiting for an event)
       enqueue-contention            	(percentage of enqueue requests which must wait)
       enqueue-waiting               	(percentage of time spent waiting for the enqueue)
       latch-contention              	(percentage of latch get requests which must wait)
       latch-waiting                 	(percentage of time a latch spends sleeping)
       sysstat                       	(change of sysstat values over time)
       dataguard-lag                 	(Dataguard standby lag)
       dataguard-mrp-status          	(Dataguard standby MRP status)
       flash-recovery-area-usage     	(Used space in flash recovery area)
       flash-recovery-area-free      	(Free space in flash recovery area)
       failed-jobs                   	(The jobs which did not exit successful in the last <n> minutes (use --lookback))
       sql                           	(any sql command returning a single number)
       sql-runtime                   	(the time an sql command needs to run)
       list-tablespaces              	(convenience function which lists all tablespaces)
       container-list-tablespaces    	(convenience function which lists all tablespaces of all container databases)
       list-datafiles                	(convenience function which lists all datafiles)
       list-asm-diskgroups           	(convenience function which lists all asm diskgroups)
       list-enqueues                 	(convenience function which lists all enqueues)
       list-latches                  	(convenience function which lists all latches)
       list-events                   	(convenience function which lists all events)
       list-background-events        	(convenience function which lists all background events)
       list-sysstats                 	(convenience function which lists all statistics from v$sysstat)

    --name
       the name of the tablespace, datafile, wait event, 
       latch, enqueue, or sql statement depending on the mode.
    --name2
       if name is a sql statement, this statement would appear in
       the output and the performance data. This can be ugly, so 
       name2 can be used to appear instead.
    --regexp
       if this parameter is used, name will be interpreted as a 
       regular expression.
    --units
       one of %, KB, MB, GB. This is used for a better output of mode=sql
       and for specifying thresholds for mode=tablespace-free
    --ident
       outputs instance and database names
    --commit
       turns on autocommit for the dbd::oracle module
    --noperfdata
       do not output performance data

  Tablespace-related modes check all tablespaces in one run by default.
  If only a single tablespace should be checked, use the --name parameter.
  The same applies to datafile-related modes.
  If an additional --regexp is added, --name's argument will be interpreted
  as a regular expression.
  The parameter --mitigation lets you classify the severity of an offline
  tablespace. 

  tablespace-remaining-time will take historical data into account. The number
  of days in the past can be given with the --lookback parameter. (Default: 30)
  
  In mode sql you can url-encode the statement so you will not have to mess
  around with special characters in your Nagios service definitions.
  Instead of 
  --name="select count(*) from v$session where status = 'ACTIVE'"
  you can say 
  --name=select%20count%28%2A%29%20from%20v%24session%20where%20status%20%3D%20%27ACTIVE%27
  For your convenience you can call check_oracle_health with --mode encode
  and it will encode the standard input.

Send email to gerhard.lausser@consol.de if you have questions
regarding use of this software. 
Please include version information with all correspondence (when possible,
use output from the --version option of the plugin itself).
```
