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
IMPORTANT:
    The setup  will register the location of the config file in the startup parameters of the service (see service.msc - SQLDMVMonitor). The file will not be copied. For this it is important that a secure location is used for this config file.
    The service read the config file each time it is started. The config file can be located also on a local path or on a shared path.
    Please take into consideration that the user that is installing the SQL DMV Tracing Service and the Account under which the SQL DMV Service is running must have read access to this file.
	

Phase 2)
========
PREREQUIREMENTS:
- Powershell script requires SMO assemblies (SharedManagementObjects.msi) installed on the computer where you run the script. The SMO must be at least for verions SQL 2012.
- User executing the powershell script must have SysAdmin rights on the SQL Server Instance (defined in the SQLTrace.Conf)
- a valid SQLTrace.conf which was created in Phase 1) 
  IMPORTANT:
  the msi bundle will register the config file SQLTrace.conf  for the service. The file will not be copied. For this it is important that a secure location is used for this config file.
- Windows Service Account under which the SQL DMV Tracing Service will run.In this document we will name this account <SQLDMV Service Account>
- Path where the SQL Service should write the SQL Extended Event files (path is checked starting form SQL Service)

PREPARATIONS

RUN the Powershell script Prepair4SQLDMVMonitor.ps1 located in the same direcotry as the readme.txt. 
The script will validate and set the needed configurations and permissions for the SQL Server Instance which you want to monitor.
As Result the Scripts returns a object which describes if the SQL Server Instance is Perpared successfull. 
You can query the status of success by running:
$result.SQLInstancePrepared

Detailed description regarding the script parameters you can find in the powershell script.

Example:
1) apply permissions and configurations
$result=.\Prepair4SQLDMVMonitor.ps1 -SQLTraceConfigFile C:\tmp\sqltrace.conf -SQLExtEventDir C:\tmp -SQLTraceServiceaccount 'wp\test_leitner'
$result.SQLInstancePrepared must be return TRUE

2) validate if permissions and configurations are set without applying them (userful for checks/validate configurations)
$result=.\Prepair4SQLDMVMonitor.ps1 -SQLTraceConfigFile C:\tmp\sqltrace.conf -SQLExtEventDir C:\tmp -SQLTraceServiceaccount 'wp\test_leitner' -OnlyValidate
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
	- Microsoft Visual C++ 2010 SP1 Redistributable Package (x64) (https://www.microsoft.com/en-US/download/details.aspx?id=13523)


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

LICENSEACCEPTED = Mandatory - Value must be set to "1" to confirm and accept License agreement. Default is "0" 

SQLDMVTRCCONFDIR = Path where the <SQLDMVCONFIG> file  must exist. This parameter is REQUIRED. 
    The setup  will register the location of the config file in the startup parameters of the service (see service.msc - SQLDMVMonitor). The file will not be copied. For this it is important that a secure location is used for this config file.
    The service read the config file each time it is started. The config file can be located also on a local path or on a shared path.
    Please take into consideration that the user that is installing the SQL DMV Tracing Service and the Account under which the SQL DMV Service is running must have read access to this file.
	
	Setup will check that in this directory or subdirectory a valid config file with then name sqltrace.conf exist.
	The Setup check that a config file exist in 3 directories using this sequence:
		1.<SQLDMVTRCCONFDIR>\<computername>.<FullComputerDomainname>\sqltrace.conf
		2.<SQLDMVTRCCONFDIR>\<computername>\sqltrace.conf
		3.<SQLDMVTRCCONFDIR>\sqltrace.conf
	If file is found, setup will skip further validations. This means if File is found on Point 1., Point 2 and 3 ar skiped.
	Important: The setup is following this rule to find the config file. The service is not following this rule to find the config file. The service works with the established location/Path of the config file,  passed as service startup parameter.
SQLDMVTRCSERVICEACCOUNT		=  Windows Account whith which the SQL DMV Tracing service will run. e.g. <domain\accountname> . Please take into consideration that the Powershell preparescript has set the needed permissions for this user.
SQLDMVTRCSERVICEACCOUNTPWD	=  Passsword of the Windows Account. set Password "" if you use a gMSA

SQLDMVTRCASSIGNADMIN		= If set to 1 a Windows Account/Group defined with param SQLDMVTRCADMINACCOUNT becomes the permissions to stop/start/query the SQL DMV Tracing Service.Default is 0 (false)
SQLDMVTRCADMINACCOUNT		= Windows Account/Group which will have the permissions to start/stop  the SQL DMV service. Setup will assign the appropriate permissions. Specify <Domain\accountname> or <Domain\group>. Mandatory if SQLDMVTRCADMINACCOUNT=1

MSINEWINSTANCE              = If set to 1 you can install until 5 additional sqldmvmonitor Agents 
TRANSFORMS                  = String Value define which sqldmvmonitor Agent Instance can be installed allowed values are: ":I01",":I02",":I03",":I04",":I05"


e.g.: msiexec /i sqldmvmonitor-<version>-x64.msi MSINEWINSTANCE=1 TRANSFORMS=":I02"


Examples of installation:
=========================

1) install SQL DMV Tracing in silent mode. Service should run with an existing service account wp\sqlsvctrc. No SQL DMV  Admin should be configured. Install dir should be default one. SQL DMV config file is located in C:\tmp
msiexec /i "SQLDMVMonitor-<version>-x64.msi" /qn /L*V c:\tmp\install.log SQLDMVTRCCONFDIR="c:\tmp"  LICENSEACCEPTED="1" SQLDMVTRCSERVICEACCOUNT="wp\sqlsvctrc" SQLDMVTRCSERVICEACCOUNTPWD="password" SQLDMVTRCASSIGNADMIN=0 

2) install  SQL DMV Tracing in silent mode. Service should run with an existing service account wp\sqlsvctrc. SQL DMV Admin group wp\SQLDMVadmingrp should be configured . Install dir should be default. SQL DMV config file is located in C:\tmp
msiexec /i "SQLDMVMonitor-<version>-x64.msi" /qn /L*V c:\tmp\install.log SQLDMVTRCCONFDIR="c:\tmp"  LICENSEACCEPTED="1" SQLDMVTRCSERVICEACCOUNT="wp\sqlsvctrc" SQLDMVTRCSERVICEACCOUNTPWD="password" SQLDMVTRCASSIGNADMIN=1  SQLDMVTRCADMINACCOUNT="wp\SQLDMVadmingrp" 

3) install sql DMV Monitor with specific Instance 01 installing not in quite mode
msiexec /i sqldmvmonitor-<version>-x64.msi /L*V c:\tmp\install-I01.log MSINEWINSTANCE=1 TRANSFORMS=":I01"

Return codes msiexec:
In silent mode you can verify if installation was successfull  checking the exitcode of msiexec. 
If exit code is 0 installation was successfull. For details of error codes refer to https://docs.microsoft.com/en-us/windows/win32/msi/error-codes.

SETUP Error/Failures
=======================
Setup will fail if :
  - config file is not found/readable or 
  - content of config file is not valid: 
    - missing or wrong nats server 
    - missing or wrong nats port 

Details of error can be found in the msi log file or in the application eventlog. If setup fails please verify on this locations


Uninstall default Instance SQL DMV Monitoring Service - I00
===========================================================
The service can be uninstalled using:
 1) UI using the add/remove feature from Control Panel.
 2) Silent by using msiexec. e.g.
	msiexec /x "{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}" /qn /L*V c:\tmp\uninstall.log

Uninstall SQL DMV Monitoring Service installed with Instance I01 to I05
=======================================================================
The SQLDMVMonitor service for Instance I01 to I05 can be uninstalled using:
  The service can be uninstalled using:
 1) UI using the add/remove feature from Control Panel.
 2) Silent by using msiexec with the specific GUID. List of Guid for instance can be found on APPENDIX point 2) (see end of readme).
	the list of guids are:
      I01={7C41FC5C-7694-45C2-B937-8AD4AEF5F952}
  e.g. uninstalling SQLDMMonitor Instance I01:
	msiexec /x "{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}" /qn /L*V c:\tmp\uninstall.log


=================================
Upgrade from previous Version
=================================
Each upgrade will be handled as Major Upgrade. During Upgrade Windows Installer will uninstall previous version before running the installation.
Windows Installer does check current installed version using the ProductCode of the msi bundle (is a guid).(this is important when you deploy the agent using e.g. Powershell DSC).
The ProductCode for the actual version can be found in this document under Section Appendix Point 2. 

Please take in consideration that you have to run the upgrade/installation with the necessary setup parameters (like first installation)
If during installation of the new version a error occure, the old version will not be installed!!

Known issues: upgrading from version 0.1.x during unintall service is stopped but process is still running for approx 30 sec. Please stop service and check that process (DMVMonitor) is removed, before running msi bundle.

===========================
Migrating to Version 0.4.x
===========================
When upgrading to Version 0.4.x you have to run also the powershell script Prepair4SQLDMVMonitor.ps1 (described in Phase 2). You have to run it with the needed parameters. The script will configure setup new xevent attributes.
This is needed to get all the required information about query fetches. The correct steps to migrate to the new version is:
1) stop SQL DMV Monitoring and Tracing Service (DMVmonitor). 
2) run Prepair4SQLDMVMonitor.ps1 with the needed parameters (same parameters as during first setup)
3) upgrade to new version running msi bundle of version 0.4.x (SQLDMVMonitor-v0.4.1-x64.msi)

Special Anotation regarding migrating to version 0.4.x:
With the Introduction of 0.4 the Field Types of Maxduration and MaxLastBatch in the Measurment SQLLongTransaction has been changed from float to integer. 
Data Collected by the Agent regarding SQLLongTransaction  will not be written to the Measurement until you:
- migrate the 2 Fields from float to integer 
- or you drop the measurement SQLLongTransaction

If you decide that you want to keep the measurements for SQLLongTransaction, you must :
1) write the measurement SQLLongTransaction including tags,fields to a temporary measurement (converting the 2 field Maxduration and MaxLastBatch to integer)
2) drop measurement SQLLongTransaction
3) write the temporary measurement back to SQLLongTransaction


==================================
TROUBLESHOOTING
=================================
1) Error: Invalid command line argument. Consult the Windows Installer SDK for detailed command line help.
This happens if you run the msi using the parameter for Multiinstance e.g. MSINEWINSTANCE=1 TRANSFORMS=":I01"
The error occures if the Instance is already installed. In the msi log File you will find follwoing error.
Extract from log:
"Specified instance {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX} via transform  is already installed. MSINEWINSTANCE requires a new instance that is not installed.
MainEngineThread is returning 1639"

============================
APPENDIX:
============================
1) where you can find the SMO msi ?
e.g. for SQL 2012
- msi SQLSysClrTypes.msi Microsoft System CLR Types for Microsoft® SQL Server® 2012 link: http://go.microsoft.com/fwlink/?LinkID=239644&clcid=0x409
- msi SharedManagementObjects.msi Microsoft SQL Server® 2012 Shared Management Objectslink: http://go.microsoft.com/fwlink/?LinkID=239659&clcid=0x409

2) List of ProductCode for released versions based on InstanceID (important for upgrading and uninstall):

Productcode for version 0.5.0
Default={09564825-3DCD-4DC2-96B7-B654710FE633}
I01={91237714-F050-4FF5-8822-898E84FD4EDF}
I02={1CD5C97B-B4F9-46CA-BAD6-19B51FF12639}
I03={AD0578DF-0E16-41A8-B46E-387474F913F1}
I04={564D433B-A35D-496C-8DA2-60DBBC1361AD}
I05={0BEB3595-41C3-4C25-8FF4-D1EB85336D1B}

Productcode for version 0.4.1
Default={D02F7B07-52D9-4A38-BCAF-05A87E1F2EC7}
I01={DFE7859D-6BE4-4BC1-84C9-526D456690D1}
I02={4E9F6545-ADA6-40B6-9C70-8AAD9E4EFCBA}
I03={D3D5A5A1-9D98-4184-B14B-53F4E935BD5A}
I04={0AF49B0C-D026-4AEA-835C-1F60AD41EE31}
I05={F1C45643-0F46-4AB9-B1F4-A7B8ECFBCC34}

Productcode for version 0.4.0
Default={AE113811-DAAD-47CB-ACB6-FAD8AC009663}
I01={5951BFAA-5AC0-4286-80E5-A4AF36C9C0F4}
I02={F9482AE2-59D5-4268-BFE5-FB520C43BD7B}
I03={C616CCCD-2C42-466F-A4FF-447AC21A283D}
I04={E8245FCC-57C0-4A99-9D7C-83C6FAF2C7B0}
I05={0EEC6F6A-7033-4B61-9865-267320542EBB}

Productcode for version 0.3.1
Default={D0E7F4AF-82C4-4B58-87C9-89BDDBEE4779}
I01={45B4717D-9B42-4998-B98D-14729EB3290D}
I02={0E5CCFB0-9690-40A2-B216-548977CD54BC}
I03={E69C1A2F-5B5F-435D-8E6B-1E585A740BA8}
I04={E783C535-A7F1-4541-888B-FC0F8BCD5411}
I05={2FD332AC-4ED9-4A24-90EC-5CEB95006E4E}

Productcode for version 0.3.0
Default={E05B5F69-C9DF-4C2C-8F0D-6A09030B83DB}
I01={C6C6D7B4-7C12-4558-82E8-432F3202CCF6}
I02={FDF69F06-8BBA-4B04-A775-4202DBC3DBA4}
I03={4C55C3F6-CA64-44B9-BC42-26E40CAE5544}
I04={A8384887-7F93-488D-81B1-BA76CA59FB61}
I05={74C3EBFF-DB81-46DE-B941-BD686CFEF718}

Productcode for version 0.2.1
Default={001CA7CF-D87D-4108-A3B8-D271402FF92F}
I01={C6B860DE-634A-4146-9B64-A3AE6EC0A409}
I02={92FEB3FD-5CCB-4CDF-B531-8E5015E64008}
I03={5508CC78-DABF-49CC-B217-A3AD2E294B86}
I04={20D1C901-8DCB-4280-899D-AF05D33B0636}
I05={3D7D125F-51E3-414F-BE1B-19B9BEFA29F7}

Productcode for version 0.2.0
Default={49689FD2-D834-4C3F-97FF-BC3BD7FEDAF0}
I01={7C41FC5C-7694-45C2-B937-8AD4AEF5F952}
I02={C1FF4CB6-26D4-4361-958F-4F8FC9BFCC0E}
I03={A6F06ACB-009E-47B8-A1AD-612946392825}
I04={9DB323F7-E431-465F-BD4D-42F570AE9837}
I05={3259D96B-3A1A-46F0-9D7F-A4A43EC44FE1}

Productcode for versoin 0.1.1
Default={9A9628AC-47CC-4E08-B9A8-257FFC6A7EAC}
