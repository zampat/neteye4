Copyright 2020 Würth Phoenix S.r.l.

This README describes the prerequisits for installing the AX ETW Tracing Agent. 
It gives a overview of the possible installation options/parameters and describes the installation process providing some examples.

PREREQUIREMENTS
User running installation must have windows local administration rights. 
Following software must be installed to be able to setup the AX ETW Agent:
- Windows Operation System: Windows 2008 R2 or higher (64 Bit)
- .net Framework 4.5 or higher
- Installed ETW Provider Microsoft-DynamicsAX-Tracing (AX 2012)


PREPARATIONS

Befor installing the Agent, the Windows Administrator running the installation must provide following information:
1) Windows account under which the AX ETW Service can run. The account can be Localsystem, a windows account or a valid gMSA. In this document we will name this account <AXETW Service Account>
2) Windows Administrator installing the service must provide a coniguration file,in which the necessary connections informations are set. We will name it axetw.conf <AXETWCONFIG>
   For deatils regarding the explanation please open the file axetw.example.conf which is located in the same directory as this README. 
   ATTENTION: 
   The setup  will register the location of the config file axetw.conf in the startup parameters of the service (see service.msc - AXETWTracing). The file will not be copied. For this it is important that a secure location is used for this config file.
   The service read the config file each time it is started. The config file can be located also on a local path or on a shared path.
   Please take into consideration that the user that is installing the AX Tracing Service and the Account under which the AX Tracing Service is running must have read access to this file.

3) Optionally you can define a Windows Account/Group which have the permission to stop/start the service. This is important if other users then the Windows Administrator should have the permissions to restart the service.
this is usefull if you want to manage the service remotly using powershell. In this document we will name this account/group as <AXETW Admin Account>.


RUNNING Installation
====================
You can install the AX ETW Tracing Agents in 2 ways:
1) using UI Wizzard
2) running installation in silent mode 


1. Installation using UI Wizzard
Run AXETWTracing-x64.msi and follow the installation steps.

2. Installation silent mode
Run msiexec from command line (detailed description regarding msiexec parameters you can find follwoing this link: https://docs.microsoft.com/en-us/windows/win32/msi/command-line-options). 
To run the installation in silent mode use following syntax:
msiexec /i "AXETWTracing-x64.msi" /qn /L*V <logfile> <AX ETW Setup Parameters>. You can find the desciption of the AX ETW Setup Parameters below:

The AX ETW Setup Parameters:
============================

INSTALLFOLDER=Path where the binaries will be installed. Default <ProgramFiles>\AXETWTracing

LICENSEACCEPTED = Mandatory - Value must be set to "1" to confirm and accept License agreement. Default is "0" 

AXETWTRACINGCONFDIR=Path where the <AXETWCONFIG> file  must exist. This parameter is REQUIRED. 
    The setup  will register the location of the config file axetw.conf in the startup parameters of the service (see service.msc - AXETWTracing). The file will not be copied. For this it is important that a secure location is used for this config file.
    The service read the config file each time it is started. The config file can be located also on a local path or on a shared path.
    Please take into consideration that the user that is installing the AX Tracing Service and the Account under which the AX Tracing Service is running must have read access to this file.

	Setup will check that in this directory or subdirectory (having the name of the computer where service is installed) a valid config file with then name axetw.conf exist.
	The Setup check if file exist using sequence:
		1.<AXETWTRACINGCONFDIR>\<computername>.<FullComputerDomainname>\axetw.conf
		2.<AXETWTRACINGCONFDIR>\<computername>\axetw.conf
		3.<AXETWTRACINGCONFDIR>\axetw.conf

    If file is found, setup will skip further validations. This means if File is found on Point 1., Point 2 and 3 ar skiped.
	Important: The setup is following this rule to find the config file. The service is not following this rule to find the config file. The service works with the established location/Path of the config file,  passed as service startup parameter.

AXETWSERVICEACCOUNTBUILDIN= If set to 1 AX ETW Service will run as LocalSystem.If set to 0 ServiceAccount and Password must be defined using Parameter AXETWSERVICEACCOUNT and AXETWSERVICEACCOUNTPWD. Default is 1.
AXETWSERVICEACCOUNT=Mandatory if parameter AXETWSERVICEACCOUNTBUILDIN is set to 0. Specify <domain\accountname>
AXETWSERVICEACCOUNTPWD=Mandatory if parameter AXETWSERVICEACCOUNTBUILDIN is set to 0. Let value empty e.g. "" if you set up a gMSA

AXETWASSIGNADMIN=If set to 1 a Windows Account/Group defined with param AXETWADMINACCOUNT becomes the permissions to stop/start/query the AX ETW Service.Default is 0 (false)
AXETWADMINACCOUNT= Mandatory if parameter AXETWSERVICEACCOUNTBUILDIN is set to 1. Specify <Domain\accountname> or <Domain\group>

Examples of installation:
=========================

1) install AX ETW Tracing in silent mode. Service should run with an existing service account wp\axetw. No ETW Admin should be configured. Install dir should be default one.
msiexec /i "AXETWTracing-x64.msi" /qn /L*V c:\tmp\install.log AXETWTRACINGCONFDIR="c:\tmp" AXETWSERVICEACCOUNTBUILDIN=0 AXETWSERVICEACCOUNT="wp\axetw" AXETWSERVICEACCOUNTPWD="password" AXETWASSIGNADMIN=0 LICENSEACCEPTED="1"

2) install AX ETW Tracing in silent mode. Service should run with an existing service account wp\axetw. AX ETW Admin group wp\axetwadmingrp should be configured . Install dir should be default.
msiexec /i "AXETWTracing-x64.msi" /qn /L*V c:\tmp\install.log AXETWTRACINGCONFDIR="c:\tmp" AXETWSERVICEACCOUNTBUILDIN=0 AXETWSERVICEACCOUNT="wp\axetw" AXETWSERVICEACCOUNTPWD="password" AXETWASSIGNADMIN=1 AXETWADMINACCOUNT="wp\axetwadmingrp""LICENSEACCEPTED="1"

2) install AX ETW Tracing in silent mode. Service should be installed under c:\tools\axetwtraing . Service should run with localsystem. NO AX Admin is requried.
msiexec /i "AXETWTracing-x64.msi" /qn /L*V c:\tmp\install.log AXETWTRACINGCONFDIR="c:\tmp" INSTALLFOLDER="c:\tools\AXETWTracing" AXETWSERVICEACCOUNTBUILDIN=1  LICENSEACCEPTED="1"

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


Uninstall AXETWTracing Service
==============================
 The service can be uninstalled using:
 1) UI using the add/remove feature from Control Panel.
 2) Silent by using msiexec. e.g.
	msiexec /x "{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}" /qn /L*V c:\tmp\uninstall.log


=================================
Upgrade from previous Version
=================================
Each upgrade will be handled as Major Upgrade. During Upgrade Windows Installer will uninstall previous version before running the installation.
Windows Installer does check current installed version using the ProductCode of the msi bundle (is a guid).(this is important when you deploy the agent using e.g. Powershell DSC).
The ProductCode for the actual version can be found in this document under Section Appendix Point 1. 

Please take in consideration that you have to run the upgrade/installation with the necessary setup parameters (like first installation)
If during installation of the new version a error occure, the old version will not be installed!!


Known issues: upgrading from version 0.1.x during unintall service is stopped but process is still running for approx 30 sec. Please stop service and check that process (AXETWTracing) is removed, before running msi bundle.

============================
APPENDIX:
============================
1) List of ProductCode for released versions  (important for upgrading and uninstall):


Productcode for verion 0.5.0:
{028F0085-10F0-496E-8AF0-091CE1E362B5}

Productcode for verion 0.4.1:
{DD16E428-A3ED-415B-8F68-7A21D5000789}

Productcode for verion 0.4.0:
{9446603F-3B28-4B5B-86B2-FCFE896EC285}

Productcode for verion 0.3.1:
{EE218EEE-E01B-4AD9-A112-9A209CE8BFE2}

Productcode for verion 0.3.0:
{964B29C2-65D9-49FA-905F-FBC82F7C4F05}

Productcode for verion 0.2.0:
{4ACFA367-02CA-49B8-82D0-F501D2A9AE3E}

Productcode for version 0.1.1:
{B25BF6EF-109F-4044-8B33-05E29F322C6E}
