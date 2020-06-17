Copyright 2020 Würth Phoenix S.r.l.

This README describes the prerequisits for installing the SQL DMV Monitor. 
It gives a overview of the possible installation options/parameters and describes the installation process providing some examples.


The Installation process is diveded in 3 Phases. Before you install the SQL DMV Monitor and Tracing Service you have to :
1) define the configuration file with the valid parameters(sqltrace.conf). 
2) setup the SQL Server Instance with the required permissions and configurations 
3) install the SQL DMV Monitoring and Tracing Service (DMVmonitor). 


Phase 1)
========
To define the SQL DMV Monitoring and Tracing Configuration File please refer to the file SQLTrace.example.conf. it is located in the same directory.
Copy it to SQLTrace.conf and make the necessary modifications.
IMPORTANT:Please take into consideration that the user that is installing the SQL DMV Tracing Service and the Account under which the SQL DMV Service is running must have read access to this file.

Phase 2)
========
PREREQUIREMENTS:
- Powershell script requires SMO assemblies (SharedManagementObjects.msi) installed on the computer where you execute the script. the SMO must be at least for verions SQL 2012.
- User exectuing the powershell script must have SysAdmin rights on the SQL Server Instance (defined in the SQLTrace.Conf)
- a valid SQLTrace.conf which was created in Phase 1) 
- Windows Service Account under which the SQL DMV Tracing Service will run.In this document we will name this account <SQLDMV Service Account>
- Path where the SQL Service should write the SQL Extended Event files (path is checked starting form SQL Service)

PREPARATIONS

RUN the Powershell script Prepair4SQLDMVMonitoring.ps1 located in the same direcotry as the readme.txt. 
The script will validate and set the needed configurations and permissions for the SQL Server Instance which you want to monitor.
As Result the Scripts returns as Object with telling if SQL Server Instance is Perpared and describing the Status.

$result.SQLInstancePrepared
Example:
$result=.\Prepair4SQLDMVMonitoring.ps1 -SQLTraceConfigFile C:\tmp\sqltrace.conf -SQLExtEventDir C:\tmp -SQLTraceServiceaccount 'wp\test_leitner'

$result.SQLInstancePrepared must be return TRUE

Phase 3)
=======
Installing  the  SQL DMV Monitor and Tracing Service

PREREQUIREMENTS
- Result of SQLInstancePrepared described in Phase 2 must be True 
- User running installation must have windows local administration rights. 
- Following software must be installed to be able to setup the SQL DMV Service:
	- Windows Operation System: Windows 2008 R2 or higher (64 Bit)
	- .net Framework 4.5.2 or higher


PREPARATIONS

Befor installing the Service, the Windows Administrator running the installation must provide following information:
1) Windows account under which the SQL DMV Monitoring and Tracing Service can run. The account must be a windows account or a valid gMSA. In this document we will name this account <SQLDMV Service Account>
2) Windows Administrator installing the service must provide the SQLTracing.conf file (Phase 1)
3) SQL Service Instance (defined in sqltrace.conf) which will be Monitored and Traced must have configurations and permissions set from Phase2
4) Optionally you can define a Windows Account/Group which have the permission to stop/start the service. The msi during installation will give this Account/Group required permissions for start/stopping the service
   This is important if other users then the Windows Administrator should have the permissions to restart the service.


RUNNING Installation
====================
You can install the SQLDMV Monitor Servic in 2 ways:
1) using UI Wizzard
2) running installation in silent mode 

1. Installation using UI Wizzard
Run SQLDMVMonitor-x64.msi and follow the installation steps.

2. Installation silent mode
Run msiexec from command line (detailed description regarding msiexec parameters you can find follwoing this link: https://docs.microsoft.com/en-us/windows/win32/msi/command-line-options). 
To run the installation in silent mode use following syntax:
msiexec /i "SQLDMVMonitor-x64.msi" /qn /L*V <logfile> <SQL DMV Setup Parameters>. You can find the desciption of the Parameters below:

SQL DMV Setup Parameters   :
============================
INSTALLFOLDER    = Path where the binaries will be installed. Default <ProgramFiles>\SQLDMVTracing

SQLDMVTRCCONFDIR = Path where the <SQLDMVCONFIG> file  must exist. This parameter is REQUIRED. 
	Setup will check that in this directory or subdirectory a valid config file with then name sqltrace.conf exist.
	The Setup check that a config file exist in 3 directories using this sequence:
		1.<SQLDMVTRCCONFDIR>\<computername>.<FullComputerDomainname>\sqltrace.conf
		2.<SQLDMVTRCCONFDIR>\<computername>\sqltrace.conf
		3.<SQLDMVTRCCONFDIR>\sqltrace.conf
	If file is found, setup will skip further validations. This means if File is found on Point 1. than point 2 and 3 ar skiped.

SQLDMVTRCSERVICEACCOUNT		=  Windows Account whith which the SQL DMV Tracing service will run. e.g. <domain\accountname> . Please take into consideration that the Powershell preparescript has set the needed permissions for this user.
SQLDMVTRCSERVICEACCOUNTPWD	=  Passsword of the Windows Account. set Password "" if you use a gMSA

SQLDMVTRCASSIGNADMIN		= If set to 1 a Windows Account/Group defined with param SQLDMVTRCADMINACCOUNT becomes the permissions to stop/start/query the SQL DMV Tracing Service.Default is 0 (false)
SQLDMVTRCADMINACCOUNT		= Windows Account/Group which will have the permissions to start/stop  the SQL DMV service. Setup will assign the appropriate permissions. Specify <Domain\accountname> or <Domain\group>. Mandatory if SQLDMVTRCADMINACCOUNT=1


Examples of installation:
=========================

1) install SQL DMV Tracing in silent mode. Service should run with an existing service account wp\sqlsvctrc. No SQL DMV  Admin should be configured. Install dir should be default one. SQL DMV config file is located in C:\tmp
msiexec /i "SQLDMVMonitor-x64.msi" /qn /L*V c:\tmp\install.log SQLDMVTRCCONFDIR="c:\tmp" SQLDMVTRCSERVICEACCOUNT="wp\sqlsvctrc" SQLDMVTRCSERVICEACCOUNTPWD="password" SQLDMVTRCASSIGNADMIN=0 

2) install  SQL DMV Tracing in silent mode. Service should run with an existing service account wp\sqlsvctrc. SQL DMV Admin group wp\SQLDMVadmingrp should be configured . Install dir should be default. SQL DMV config file is located in C:\tmp
msiexec /i "SQLDMVMonitor-x64.msi" /qn /L*V c:\tmp\install.log SQLDMVTRCCONFDIR="c:\tmp" SQLDMVTRCSERVICEACCOUNT="wp\sqlsvctrc" SQLDMVTRCSERVICEACCOUNTPWD="password" SQLDMVTRCASSIGNADMIN=1  SQLDMVTRCADMINACCOUNT="wp\SQLDMVadmingrp" 


Return codes msiexec:
In silent mode you can verify if installation was successfull  checking the exitcode of msiexec. 
If exit code is 0 installation was successfull. For details of error codes refer to https://docs.microsoft.com/en-us/windows/win32/msi/error-codes.


Uninstall SQL DMV Monitori Service
==============================
 The service can be uninstalled using:
 1) UI using the add/remove feature from Control Panel.
 2) Silent by using msiexec. e.g.
	msiexec /x "{9A9628AC-47CC-4E08-B9A8-257FFC6A7EAC}" /qn /L*V c:\tmp\uninstall.log


============================
APPENDIX:
============================
1) where you can find the SMO msi ?
e.g. for SQL 2012
- msi SQLSysClrTypes.msi Microsoft System CLR Types for Microsoft® SQL Server® 2012 link: http://go.microsoft.com/fwlink/?LinkID=239644&clcid=0x409
- msi SharedManagementObjects.msi Microsoft SQL Server® 2012 Shared Management Objectslink: http://go.microsoft.com/fwlink/?LinkID=239659&clcid=0x409
