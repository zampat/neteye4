Install the powershell module by coping it in C:\Program Files\WindowsPowerShell\Modules folder or adding the module's path to the PSModulePath

The module C:\Program Files\WindowsPowerShell\Modules\NTFSSecurity is required for some functions

set the proper values in settings.xml file

Once the module is installed each function can be called from powershell command line

Functions list:
    'WP-AxMonitor':
main functions, it can call all other functions
    'WP-Test':
    'WP-GetSettingsProperty':
    'WP-GetServiceDirectory':
    'WP-LoadSettings':
    'WP-LoadDatabaseSettings':

    'WP-tcpTest':
    #Query db, user must have access to db
    'WP-OleDbCheck':
    'WP-OleDbQuery':
    'WP-GetLongTransactions':
    'WP-GetHeadBlockers':
    'WP-AxDBCheck_public':
    'WP-AxDBCheck_dbdatareader':
    'WP-AxBusinessDBCheck_public':
    'WP-AxBusinessDBCheck_dbdatareader':
    'WP-AxModelDBCheck_public':
    'WP-AxModelDBCheck_dbdatareader':
    'WP-AxRSDBCheck_public':
    'WP-AxRSDBCheck_dbdatareader':

    'WP-AxBatchServersConfiguration':
    'WP-isBatchServer':
    'WP-activeUserSession':
    'WP-batchJobsWaitingStatistics':
    #connect to AOS with .net BC and perform operations...
    'WP-GetAOSConfiguration':
    'WP-netBCConnect':
    'WP-netBCDisconnect':
    'WP-netBCDIXFCheck':
    #net.tcp
    'WP-AxMetadataService_NetTcpCheck':#ax user
    'WP-AxManageabilityServiceGroup_NetTcpCheck':#ax admin
    'WP-AxQueryService_NetTcpCheck':
    #printers, posso fare lista
    'WP-sharedPrintersCheck':
    'WP-sharedPrintersList': 
    #filesharing
    'WP-testPath':
    'WP-testSharedPath':
    'WP-testPathAccess':
    'WP-testUserPathsAccess':
    'WP-testAllUserPathsAccess':
    'WP-testSharingConfig':
    #SSRS
    'WP-SSRSwebCheck':
    'WP-SSRSsvcCheck':
    'WP-SSRSreportRender':
    'WP-SSRSreportRenderAndSave':
    #DIXF
    'WP-DIXFsvcCheck':
    #HelpServer
    'WP-HelpSrvWebCheck':
    'WP-HelpSrvSearchCheck':
    'WP-HelpServiceCheck':
    #di base posso usare il check sul title
    'WP-WebPageCheck':
    'WP-WebSiteCheck':
    'WP-WebSitesCheck':
    #client
    'WP-getClientConfigurationModel':
    'WP-testClienttoAOSconnection':