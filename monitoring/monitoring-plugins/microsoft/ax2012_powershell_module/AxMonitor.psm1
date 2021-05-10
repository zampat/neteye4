    $PrivateData = (Import-LocalizedData).PrivateData

    #Ax Monitor Checks
    function WP-AxMonitor($arg1)
    {
        <#
            .SYNOPSIS
            function used to perform check in remote
            .DESCRIPTION

            .PARAMETER arg1
            string with the function or cmdlet to call

            .EXAMPLE
            .WP-AxMonitor -arg1 "tcpTest -server 10.240.128.170 -port 1433"

            .NOTE
            this function is configured in NSCLIENT++ service as entry point

        #>
        Invoke-Expression -Command $arg1 -OutVariable retObj|Out-Null

        #Write-Host $arg1

        Write-Host $retObj.Output
        exit $retObj.OutputCode
    }

    function WP-Test
    {
        $nscpKey = (Get-Item $PrivateData.NSClientSVCkey)
        $nscpPath = $nscpKey.GetValue("ImagePath").SubString(0,$nscpKey.GetValue("ImagePath").IndexOf($PrivateData.NSClientSVCexe)).Trim('"')

        $SettingsFolder = [System.IO.Path]::Combine($nscpPath, $PrivateData.SettingsFolder, "settings.txt");

        Write-Host $SettingsFolder

        Set-Content -Path $SettingsFolder -Value "checca!"
    }

    function WP-GetSettingsProperty([string]$propertyName)
    {
        <#
            .SYNOPSIS
            function used to retrieve local settings
            .DESCRIPTION

            .EXAMPLE
            .WP-AxMonitor -arg1 "tcpTest -server 10.240.128.170 -port 1433"

            .NOTE
            local settings are saved in an xml file in the module directory
            if the property PrivateData -> AxSettingsPath has no value

        #>
        [System.Io.Path]::GetDirectoryName((Get-Module -Name AxMonitor).Path)

        $nscpKey = (Get-Item $PrivateData.NSClientSVCkey)
        $nscpPath = $nscpKey.GetValue("ImagePath").SubString(0,$nscpKey.GetValue("ImagePath").IndexOf($PrivateData.NSClientSVCexe)).Trim('"')

        $SettingsFolder = [System.IO.Path]::Combine($nscpPath, $PrivateData.SettingsFolder, "settings.json");
        
        return (Get-Content .\settings.json -Raw|ConvertFrom-Json).psobject.properties[$propertyName]
    }
    function WP-LoadSettings
    {
        if((Get-Module -Name AxMonitor).Path.Count -gt 1)
        {
            $path = (Get-Module -Name AxMonitor).Path[0]
        }else{
            $path = (Get-Module -Name AxMonitor).Path
        }
        $directory=[System.Io.Path]::GetDirectoryName($path)

        $path=[System.Io.Path]::Combine($directory, "settings.xml")

        return ([xml](Get-Content $path)).axmonitor
    }

    function WP-GetServiceDirectory([string]$name)
    {
        <#
            .DESCRIPTION
            WP-GetServiceDirectory serve in fase installazione, 
            funziona powershell 3.0, sviluppato in 5.1 
        #>
        $results=Get-WmiObject -Query "select Name,Pathname from win32_service where Name ='$name'"|Select-Object Name,@{Name='ExecutableDirectory';Expression={[System.IO.Path]::GetDirectoryName($_.Pathname.replace('"',''))}}
        
        return $results[0].ExecutableDirectory
    }

    
    function WP-tcpTest([string]$server, [int]$port)#OBchecked
    {
        <#
            .DESCRIPTION
            WP-tcpTest controlla ingresso tcp 
            funziona powershell 3.0, sviluppato in 5.1 

            andrebbe generalizzato con elenco porte o cmq da settings, cosi da avere un check solo 
        #>
        $retObj = New-Object AxMonitor.CheckStatus
        #$pingMeasurement = New-Object AxMonitor.CheckMeasurement "pingTime={0}ms",20,100
        #$retObj.measurements.Add($pingMeasurement);

        $pingRes = Test-NetConnection -WarningAction SilentlyContinue $server -Port $port

        if($pingRes.TcpTestSucceeded) {
            $retObj.SetStatusMessage(0,"Tcp Test Succeeded")
            #$retObj.measurements[0].Value=$pingRes.PingReplyDetails.RoundtripTime
            #$retObj.outCode = $retObj.measurements[0].outCode
        }else{
            $retObj.SetStatusMessage(2,"Tcp Test Failed")
        }
    
        return $retObj
    }

#$mod=Import-Module \\1869fp0011\NSClient\AxChecks.psm1
#Write-Host $arg1


    #Query db, user deve avere accesso in lettura al db
    function OleDb_OpenConnection($dbServer, $dbName, $retObj)
    {
        $databaseConnection = New-Object System.Data.OleDb.OleDbConnection
        if($databaseConnection.state -eq 0)
        {
            $databaseConnectionString = "Provider=SQLOLEDB.1;Server=" + $dbServer + ";Database=" + $dbName + ";Trusted_Connection=yes"
            $databaseConnection.ConnectionString = $databaseConnectionString
            try
            {
                $databaseConnection.Open()
            }
            catch
            {
                $retObj.AppendErrorMessage($_.Exception.Message)
            }    
        }
        return $databaseConnection
    }
    function OleDb_CloseConnection($databaseConnection)
    {
        if($databaseConnection.state -ne 0) 
        {
            try
            {
                $databaseConnection.Close()
            }
            catch
            {
        
            } 
        }
    }
    function OleDb_ExecuteQuery($databaseConnection, $query, $retObj)
    {
        $data = New-Object  System.Data.DataSet
    
        if($databaseConnection.state -ne 0)
        {
            try
            {
                $adapter= New-Object  System.Data.OleDb.OleDbDataAdapter
                $adapter.SelectCommand = $databaseConnection.CreateCommand()
                $adapter.SelectCommand.CommandText = $query
                $adapter.Fill($data)|Out-Null
            }
            catch
            {
                $retObj.AppendErrorMessage($_.Exception.Message)
                #Write-Host "2:" $_.Exception.Message
            }
        }
        return $data.Tables
    }
    function OleDb_ExecuteScalar($databaseConnection, $query, $retObj)
    {
        if($databaseConnection.state -ne 0)
        {
            try
            {
                $SelectCommand = $databaseConnection.CreateCommand()
                $SelectCommand.CommandText = $query
                return $SelectCommand.ExecuteScalar()
            }
            catch
            {
                $retObj.AppendErrorMessage($_.Exception.Message)
                #Write-Host "2:" $_.Exception.Message
            }
        }
    }
    function WP-OleDbCheck($dbServer, $dbName, $query)#OBchecked
    {
        <#
            .DESCRIPTION
            WP-OleDbCheck si connette a sqlserver ed esegue query, success case se la query torna un valore diverso da $null 
            funziona powershell x.0, sviluppato in 5.1 
        #>
        #questa é pensata per avere un reutrn value true o false
        $retObj = New-Object AxMonitor.CheckStatus
    
        $databaseConnection = OleDb_OpenConnection -dbServer $dbServer -dbName $dbName -retObj $retObj

        $result = OleDb_ExecuteScalar -databaseConnection $databaseConnection -query $query -retObj $retObj

        OleDb_CloseConnection -databaseConnection $databaseConnection
    
        if($result) {
            $retObj.SetStatusMessage(0,"Check succeeded with expected value")
        }else{
            $retObj.SetStatusMessage(2,"Check failed")
        }

        return $retObj
    }
    function WP-OleDbQuery($dbServer, $dbName, $query)#OBchecked
    {
        <#
            .DESCRIPTION
            WP-OleDbCheck si connette a sqlserver ed esegue query, success case se la query torna senza errori
            funziona powershell x.0, sviluppato in 5.1 
        #>
        #questa é piú verbose, anche se va sviluppata perché ad ora non so come gestire il risultato della query
        #un idea é di salvare un setting in locale e poi confrontarlo di volta in volta
        $retObj = New-Object AxMonitor.CheckStatus
    
        $databaseConnection = OleDb_OpenConnection -dbServer $dbServer -dbName $dbName -retObj $retObj

        $result = OleDb_ExecuteQuery -databaseConnection $databaseConnection -query $query -retObj $retObj

        OleDb_CloseConnection -databaseConnection $databaseConnection
    
        if($result -is [System.Data.DataTable]) {
            $retObj.SetStatusMessage(0, [string]::Format("Retrieved {0} rows",$result.Rows.Count))
            foreach($Row in $result.Rows)
            {
                $tableRowString = ""
                foreach($item in $Row.ItemArray)
                {
                    $tableRowString += $item.ToString() + "`t"
                }
                $retObj.AppendErrorMessage($tableRowString);
            }
        }
        else
        {
            $retObj.SetStatusMessage(2, "Query ended with errors")
        }
        return $retObj
    }

    function WP-LoadDatabaseSettings($dbId,[ref]$dbServer,[ref]$query)#OBchecked
    {
        $settings = WP-LoadSettings
        $dbsettings=$settings.sql.SelectSingleNode('database[@id="'+$dbId+'"]')
        if($dbServer.Value -is [string] -and [string]::IsNullOrEmpty($dbServer.Value)) { $dbServer.Value = $dbsettings.instance }
        if($query.Value -is [string] -and [string]::IsNullOrEmpty($query.Value))  { $query.Value = $dbsettings.readquery }

        return $dbsettings
    }

    function WP-GetLongTransactions($wrnTh = 300, $errTh = 600)#OBchecked
    {
        $settings = WP-LoadSettings
        $dbServer=(WP-LoadDatabaseSettings -dbId "AXBUSINESS").instance
        <#
            .DESCRIPTION
            WP-OleDbCheck si connette a sqlserver ed esegue query, success case se la query torna senza errori
            funziona powershell x.0, sviluppato in 5.1 
        #>
        #questa é piú verbose, anche se va sviluppata perché ad ora non so come gestire il risultato della query
        #un idea é di salvare un setting in locale e poi confrontarlo di volta in volta
        $retObj = New-Object AxMonitor.CheckStatus
        $retObj.measurements += New-Object AxMonitor.CheckMeasurement (New-Object AxMonitor.PerfParameter "transactionDuration","",$wrnTh,$errTh)
    
        $databaseConnection = OleDb_OpenConnection -dbServer $dbServer -dbName "master" -retObj $retObj

        $query=Get-Content C:\AxCollector\scripts\sql\longTransactionAlertScript2.txt
        $query=[string]::Format($query,$wrnTh)

        $result = OleDb_ExecuteQuery -databaseConnection $databaseConnection -query $query -retObj $retObj

        OleDb_CloseConnection -databaseConnection $databaseConnection
        
        $bodyHtml=""
        if($result -is [System.Data.DataTable]) {
            if($result.Rows.Count -gt 0) {
                #$retObj.AppendErrorMessage("sessionId |  duration  | AxSession |   AxUser  | ServerName | Company");
                $bodyHtml="<table><tr><th>sessionId</th><th>duration</th><th>AxSession</th><th>AxUser</th><th>ServerName</th><th>Company</th></tr>"
            }
            [Decimal]$maxDuration = [Decimal]::Zero;
            foreach($Row in $result.Rows)
            {
                if($Row.ItemArray[9] -gt $maxDuration) {
                    $maxDuration = $Row.ItemArray[9]
                }
                
                $sessionId = $Row.ItemArray[1].ToString()
                $duration = [TimeSpan]::FromSeconds([double]::Parse($Row.ItemArray[9].ToString())).ToString()
                $AxSession = $Row.ItemArray[2].ToString()
                $AxUser = $Row.ItemArray[3].ToString()
                $ServerName = $Row.ItemArray[4];
                $Company = $Row.ItemArray[15].ToString()

                
                $bodyHtml+=[string]::Format("<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td><td>{5}</td></tr>", $sessionId, $duration, $AxSession, $AxUser, $ServerName, $Company);
                
                $sessionId = $sessionId.PadLeft(8)
                $duration = $duration.PadLeft(10)
                $AxSession = $AxSession.PadLeft(9)
                $AxUser = $AxUser.PadLeft(9)
                #$retObj.AppendErrorMessage([string]::Format(" {0} | {1} | {2} | {3} | {4}", $sessionId, $duration, $AxSession, $AxUser, $ServerName, $Company));
            }
            if($result.Rows.Count -gt 0) {
                $bodyHtml+="</table>"
            }

            $retObj.measurements[0].Update($maxDuration)
            if($maxDuration -gt $errTh)
                { 
                    $retObj.SetStatusMessage(2, "Transactions over $errTh seconds $bodyHtml")
                    Send-MailMessage -To $settings.longtransactions.critical.Split(',') -From $settings.longtransactions.account -SmtpServer $settings.longtransactions.smtpserver -Subject "Long transaction CRITICAL detail" -BodyAsHtml $bodyHtml
                }
            elseif($maxDuration -gt $wrnTh)
                { 
                    $retObj.SetStatusMessage(1, "Transactions over $wrnTh seconds $bodyHtml")
                    Send-MailMessage -To $settings.longtransactions.warning.Split(',') -From $settings.longtransactions.account -SmtpServer $settings.longtransactions.smtpserver -Subject "Long transaction WARNING detail" -BodyAsHtml $bodyHtml
                }
            else
                { $retObj.SetStatusMessage(0, "No long transactions") }
            
        }
        else
        {
            $retObj.SetStatusMessage(2, "Query ended with errors")
        }

        $retObj.Output

        return $retObj
    }
    function WP-GetHeadBlockers($wrnTh = 300, $errTh = 600)#OBchecked
    {
        $settings = WP-LoadSettings
        $dbServer=(WP-LoadDatabaseSettings -dbId "AXBUSINESS").instance
        <#
            .DESCRIPTION
            WP-OleDbCheck si connette a sqlserver ed esegue query, success case se la query torna senza errori
            funziona powershell x.0, sviluppato in 5.1 
        #>
        #questa é piú verbose, anche se va sviluppata perché ad ora non so come gestire il risultato della query
        #un idea é di salvare un setting in locale e poi confrontarlo di volta in volta
        $retObj = New-Object AxMonitor.CheckStatus
        $retObj.measurements += New-Object AxMonitor.CheckMeasurement (New-Object AxMonitor.PerfParameter "waitTime","",$wrnTh,$errTh)
    
        $databaseConnection = OleDb_OpenConnection -dbServer $dbServer -dbName "master" -retObj $retObj

        $query=Get-Content C:\AxCollector\scripts\sql\headblocker2.txt
        $query=[string]::Format($query,$wrnTh)

        $result = OleDb_ExecuteQuery -databaseConnection $databaseConnection -query $query -retObj $retObj

        OleDb_CloseConnection -databaseConnection $databaseConnection
        
        $bodyHtml=""
        if($result -is [System.Data.DataTable]) {
            if($result.Rows.Count -gt 0) {
                #$retObj.AppendErrorMessage("sessionId |  waitTime  | AxSession |   AxUser  | ServerName | SqlText ");
            }
            [Decimal]$maxDuration = [Decimal]::Zero;
            foreach($Row in $result.Rows)
            {
                if($Row.ItemArray[4] -gt $maxDuration) {
                    $maxDuration = $Row.ItemArray[4]
                }
                
                $sessionId = $Row.ItemArray[6].ToString()
                $waitTime = [TimeSpan]::FromSeconds([double]::Parse($Row.ItemArray[4].ToString())).ToString()
                $AxSession = $Row.ItemArray[1].ToString()
                $AxUser = $Row.ItemArray[2].ToString()
                $ServerName = $Row.ItemArray[3];
                $Level = $Row.ItemArray[5]
                $BlockingTree = $Row.ItemArray[7].ToString()
                $Company = $Row.ItemArray[8].ToString()

                if($Level -eq 1)
                {
                    if($bodyHtml.Length -gt 0) {
                        $bodyHtml+="</table>"
                    }
                    $bodyHtml="<table><tr><th>sessionId</th><th>waitTime</th><th>AxSession</th><th>AxUser</th><th>ServerName</th><th>Company</th><th>Level</th></tr>"
                }

                $bodyHtml+=[string]::Format("<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td><td>{7}</td><td>{5}</td></tr>", $sessionId, $waitTime, $AxSession, $AxUser, $ServerName, $Level, $BlockingTree, $Company);
                
                $sessionId = $sessionId.PadLeft(8)
                $waitTime = $waitTime.PadLeft(10)
                $AxSession = $AxSession.PadLeft(9)
                $AxUser = $AxUser.PadLeft(9)
                $ServerName = $ServerName.PadLeft(10)
                #$retObj.AppendErrorMessage([string]::Format(" {0} | {1} | {2} | {3} | {4} | {5}", $sessionId, $waitTime, $AxSession, $AxUser, $ServerName, $BlockingTree, $Company));
            }
            if($result.Rows.Count -gt 0) {
                $bodyHtml+="</table>"
            }

            $retObj.measurements[0].Update($maxDuration)
            if($maxDuration -gt $errTh)
                { 
                    $bodyHtml=[string]::Format("<p>Head blocker detection with critical threshold at {0}</p>",[TimeSpan]::FromSeconds($errTh)) + $bodyHtml;
                    $retObj.SetStatusMessage(2, "Transaction blocked over $errTh seconds $bodyHtml")
                    Send-MailMessage -To $settings.longtransactions.critical.Split(',') -From $settings.longtransactions.account -SmtpServer $settings.longtransactions.smtpserver -Subject "Headblocker CRITICAL detail" -BodyAsHtml $bodyHtml
                }
            elseif($maxDuration -gt $wrnTh)
                { 
                    $bodyHtml=[string]::Format("<p>Head blocker detection with warning threshold at {0}</p>",[TimeSpan]::FromSeconds($wrnTh)) + $bodyHtml;
                    $retObj.SetStatusMessage(1, "Transaction blocked over $wrnTh seconds $bodyHtml")
                    Send-MailMessage -To $settings.longtransactions.warning.Split(',') -From $settings.longtransactions.account -SmtpServer $settings.longtransactions.smtpserver -Subject "Headblocker WARNING detail" -BodyAsHtml $bodyHtml
                }
            else
                { $retObj.SetStatusMessage(0, "No head blockers") }
            
        }
        else
        {
            $retObj.SetStatusMessage(2, "Query ended with errors")
        }

        $retObj.Output

        return $retObj
    }

    function WP-AxDBCheck_public([string]$dbServer, [string]$dbId = "AXBUSINESS")#OBchecked
    {
        #AXBUSINESS,AXMODEL,RS
        $dbsettings=WP-LoadDatabaseSettings -dbId $dbId -dbServer ([ref]$dbServer)

        return WP-OleDbCheck -dbServer $dbServer -dbName $dbsettings.name -query "select getdate()"
    }
    #remeber name in functions
    function WP-AxDBCheck_dbdatareader([string]$dbServer, [string]$dbId = "AXBUSINESS", [string]$query)#OBchecked
    {
        #AXBUSINESS,AXMODEL,RS
        $dbsettings=WP-LoadDatabaseSettings -dbId $dbId -dbServer ([ref]$dbServer) -query ([ref]$query)
        
        return WP-OleDbCheck -dbServer $dbServer -dbName $dbsettings.name -query $query
    }
    function WP-AxBusinessDBCheck_public($dbServer)#OBchecked
    {
        return WP-AxDBCheck_public -dbServer $dbServer -dbId "AXBUSINESS"
    }
    function WP-AxBusinessDBCheck_dbdatareader($dbServer, $query)#OBchecked
    {
        return WP-AxDBCheck_dbdatareader -dbServer $dbServer -dbId "AXBUSINESS" -query $query
    }
    function WP-AxModelDBCheck_public($dbServer)#OBchecked
    {
        return WP-AxDBCheck_public -dbServer $dbServer -dbId "AXMODEL"
    }
    function WP-AxModelDBCheck_dbdatareader($dbServer, $query)#OBchecked
    {
        return WP-AxDBCheck_dbdatareader -dbServer $dbServer -dbId "AXMODEL" -query $query
    }
    function WP-AxRSDBCheck_public($dbServer, $dbName)#OBchecked
    {
        return WP-AxDBCheck_public -dbServer $dbServer -dbId "RS"
    }
    function WP-AxRSDBCheck_dbdatareader($dbServer, $dbName, $query)#OBchecked
    {
        return WP-AxDBCheck_dbdatareader -dbServer $dbServer -dbId "RS" -query $query
    }

    function WP-AxBatchServersConfiguration([string]$dbServer,[string]$dbName,[string]$batchServers)#OBchecked
    {
        <#
            .DESCRIPTION
            WP-AxBatchServersConfiguration controlla che i batchservers specificati (lista separata da virgola) sono dei batchservers
            funziona powershell 3.0, sviluppato in 5.1 
        #>

        #questa é piú verbose, anche se va sviluppata perché ad ora non so come gestire il risultato della query
        #un idea é di salvare un setting in locale e poi confrontarlo di volta in volta

        
        $dbsettings=WP-LoadDatabaseSettings -dbId "AXBUSINESS" -dbServer ([ref]$dbServer)
        if([string]::IsNullOrEmpty($dbName))  { $dbName = $dbsettings.name }

        if([string]::IsNullOrEmpty($batchServers))  { 
            $settings=WP-LoadSettings
            $batchServers = ""
            foreach($batchServerId in $settings.SelectNodes("aos[@batch='1']").instance)
            {
                $batchServers += $batchServerId + ","
            }
            $batchServers = $batchServers.TrimEnd(',');
        }

        $retObj = New-Object AxMonitor.CheckStatus
    
        $databaseConnection = OleDb_OpenConnection -dbServer $dbServer -dbName $dbName -retObj $retObj

        $query = "select cast(case when SRS='"+$batchServers+"' then 1 else 0 end as bit) as result from (select (case when LEN(SRS)>0 then SRS else '' end) as SRS from (select stuff((select ','+ SERVERID from SYSSERVERCONFIG a where ENABLEBATCH=1 for xml path('')),1 ,1, '') as SRS) q1) q2"
        $result = OleDb_ExecuteScalar -databaseConnection $databaseConnection -query $query -retObj $retObj

        OleDb_CloseConnection -databaseConnection $databaseConnection
    
        if($result) {
            $retObj.SetStatusMessage(0,"Batch Servers Configuration is Working")
        }else{
            $retObj.SetStatusMessage(2,"Batch Servers Configuration has Changed")

            $databaseConnection = OleDb_OpenConnection -dbServer $dbServer -dbName $dbName -retObj $retObj

            $query = "select SERVERID,case when ENABLEBATCH=1 then 'is a batch AOS' else 'is not a batch AOS' end from SYSSERVERCONFIG"
            
            $result = OleDb_ExecuteQuery -databaseConnection $databaseConnection -query $query -retObj $retObj

            OleDb_CloseConnection -databaseConnection $databaseConnection

            if($result -is [System.Data.DataTable]) {
                foreach($Row in $result.Rows)
                {
                    $retObj.AppendErrorMessage($Row.ItemArray[0].ToString() + " " + $Row.ItemArray[1].ToString());
                }
            }
            else
            {
                $retObj.AppendErrorMessage("Query on SYSSERVERCONFIG ended with errors")
            }
        }

        return $retObj
    }
    function WP-isBatchServer([string]$instance, [boolean]$isBatch=$true)
    {
        <#
            .DESCRIPTION
            WP-CurrentAOSisBatchServer controlla che le istanze sulla corrente macchina sono configurati come batchserver
            funziona powershell 3.0, sviluppato in 5.1 
        #>
        
        if([string]::IsNullOrEmpty($instance)){
            $settings = WP-LoadSettings
            $instance = ""
            
            if($isBatch){
                $tmp = "1"
            }else{
            
                $tmp = "0"
            }
            $hostname = (hostname)
            foreach($s in $settings.SelectNodes("aos[@batch=$tmp][contains(@instance,'$hostname')]").instance)
            {
                $instance+=$s+","
            }
            $instance=$instance.TrimEnd(',')
        }
        $nInstances=$instance.Split(',').Count
        
        $tmp=""
        foreach($s in $instance.Split(','))
        {
            $tmp+="'"+$s+"',"
        }
        $instance=$tmp.TrimEnd(',')

        
        $dbServer = ""
        $dbsettings=WP-LoadDatabaseSettings -dbId "AXBUSINESS" -dbServer ([ref]$dbServer)

        $retObj = New-Object AxMonitor.CheckStatus
        
        $databaseConnection = OleDb_OpenConnection -dbServer $dbServer -dbName $dbsettings.name -retObj $retObj
        
        if($isBatch){
            $tmp = "1"
        }else{
            
            $tmp = "0"
        }
        $query = "select SERVERID,case when ENABLEBATCH=$tmp then 1 else 0 end as BATCHCONFIG,ENABLEBATCH from SYSSERVERCONFIG where SERVERID in (" + $instance + ")"
        
        $result = OleDb_ExecuteQuery -databaseConnection $databaseConnection -query $query -retObj $retObj
        
        OleDb_CloseConnection -databaseConnection $databaseConnection
        

        if($result -is [System.Data.DataTable]) {
            $resXinst = $result.Rows.Count -gt 0
            foreach($row in $result.Rows)
            {
                $resXinst = $resXinst -and ($row.ItemArray[1] -eq 1)
                
                if($row.ItemArray[2] -eq 1){
                    $tmp = [string]::Format("{0} is a batch server",$row.ItemArray[0])
                }else{
            
                    $tmp = [string]::Format("{0} is a batch server",$row.ItemArray[0])
                }

                $retObj.AppendErrorMessage($tmp)
            }
            if($resXinst){
                $retObj.SetStatusMessage(0, "Batch servers configuration is correct")
            }else{
                $retObj.SetStatusMessage(2, "Batch servers configuration is not valid")
            }
        }
        else
        {
            $retObj.SetStatusMessage(2, "Query ended with errors")
        }

        return $retObj



        $query = "select count(SERVERID) from SYSSERVERCONFIG where SERVERID in (" + $instance + ") and ENABLEBATCH=" 
        
        
        if($isBatch){
            $query += "1"
        }else{
            
            $query += "0"
        }

        $result = OleDb_ExecuteScalar -databaseConnection $databaseConnection -query $query -retObj $retObj

        OleDb_CloseConnection -databaseConnection $databaseConnection

        $result=$result -eq $nInstances

        if($result){
            $retObj.SetStatusMessage(0,"$instance batch configuration is correct")
        }else{
            $retObj.SetStatusMessage(2,"$instance batch configuration is not correct")
        }

        return $retObj
    }
    function WP-batchJobsWaitingStatistics([int]$minutes)#OBchecked
    {
        $dbServer = ""
        $dbsettings=WP-LoadDatabaseSettings -dbId "AXBUSINESS" -dbServer ([ref]$dbServer)

        $retObj = New-Object AxMonitor.CheckStatus
        
        $databaseConnection = OleDb_OpenConnection -dbServer $dbServer -dbName $dbsettings.name -retObj $retObj

        
        $query = "select COUNT(RECID) from BATCHJOB where DATEDIFF(minute, ORIGSTARTDATETIME, GETUTCDATE()) > " + $minutes + " and STATUS = 1"
                        
        $jobsCount = OleDb_ExecuteScalar -databaseConnection $databaseConnection -query $query -retObj $retObj
        

        OleDb_CloseConnection -databaseConnection $databaseConnection

        
        if($jobsCount -eq 0){
            $retObj.SetStatusMessage(0,"No waiting batch job")
        }else{
            $retObj.SetStatusMessage(2,[string]::Format("{0} jobs not executed",$jobsCount))
        }
        return $retObj
    }
    function WP-activeUserSession([string]$instance,[Nullable[int]]$sessionsWRN,[Nullable[int]]$sessionsERR,[Nullable[int]]$usersWRN,[Nullable[int]]$usersERR)
    {
        <#
            .DESCRIPTION
            WP-CurrentAOSisBatchServer controlla che le istanze sulla corrente macchina sono configurati come batchserver
            funziona powershell 3.0, sviluppato in 5.1 
        #>

        $settings = WP-LoadSettings
        $dbsettings=$settings.sql.SelectSingleNode('database[@id="AXBUSINESS"]')

        if([string]::IsNullOrEmpty($instance)) { $instance = hostname }
         
        $retObj = New-Object AxMonitor.CheckStatus
        $retObj.measurements += New-Object AxMonitor.CheckMeasurement (New-Object AxMonitor.PerfParameter "sessions","",$sessionsWRN,$sessionsERR)
        $retObj.measurements += New-Object AxMonitor.CheckMeasurement (New-Object AxMonitor.PerfParameter "users","",$usersWRN,$usersERR)

        $databaseConnection = OleDb_OpenConnection -dbServer $settings.sql.instance -dbName $dbsettings.name -retObj $retObj
        
        #next version make check for multiple instances on same machine
        $query = "select count(SESSIONID) as N_SESSIONS,count(distinct USERID) as N_USERS from SYSCLIENTSESSIONS as t1 inner join (select SERVERID,INSTANCE_NAME+'@'+AOSID as INSTANCE from SYSSERVERSESSIONS) t2 on t1.SERVERID=t2.SERVERID where t1.STATUS=1 and t2.INSTANCE like '%"+$instance+"%'"
       
        $result = OleDb_ExecuteQuery -databaseConnection $databaseConnection -query $query -retObj $retObj
        
        OleDb_CloseConnection -databaseConnection $databaseConnection
 
        if($result -is [System.Data.DataTable]) {
            $retObj.SetStatusMessage(0, [string]::Format("{0} active sessions - {1} logged users",$result.Rows[0].ItemArray[0],$result.Rows[0].ItemArray[1]))
            $retObj.measurements[0].Update($result.Rows[0].ItemArray[0])
            $retObj.measurements[1].Update($result.Rows[0].ItemArray[1])
        }
        else
        {
            $retObj.SetStatusMessage(2, "Query ended with errors")
        }

        return $retObj
    }

    #connect to AOS with .net BC and perform operations...
    function WP-GetAOSConfiguration([string]$InstanceId)
    {
        $HostName = (HostName)
        $InstanceId=$InstanceId.Replace("@$HostName","")

        foreach($InstanceNum in (Get-Item $PrivateData.AxSrvCfg.ServerRootKey).GetSubKeyNames())
        {
            if($InstanceId -ne $InstanceNum) { continue; }

            $Instance = Get-Item ($PrivateData.AxSrvCfg.ServerRootKey +"\$InstanceId")
            $InstanceName = $Instance.GetValue("InstanceName")
            $Current = Get-Item ($PrivateData.AxSrvCfg.ServerRootKey+"\$InstanceId\"+$Instance.GetValue("Current"))

            #$dbcli = $Current.GetValue("dbcli")

            

            $obj = [PSCustomObject]@{
                InstanceId = $InstanceId
                InstanceName = $Instance.GetValue("InstanceName")
                Instance = $InstanceId + "@" + $HostName

                dbserver = $Current.GetValue("dbserver")
                database = $Current.GetValue("database")
                port = $Current.GetValue("port")
                WSDLport = $Current.GetValue("WSDLport")
                NetTCPPort = $Current.GetValue("NetTCPPort")
            }
            return $obj
        }
    }
    function WP-connectionToAOSCheck([string]$aosServer)
    {
        #possibilit'a sono:
        #1)ho un check verso macchina e allora devo avere AOSServer
        #2)ho un check verso tutte le macchine, qui devo avere un settings, possibilmente autogenerato, con tutti gli aos servers
        #3)le porte da testare o le leggo da impostazioni
        #4)oppure li leggo da clientCFG
        #5)NB: potrei avere N connection settings da verificare (1 per company)
    }
    function WP-netBCConnect([Microsoft.Dynamics.BusinessConnectorNet.Axapta]$ax, $retObj) {
        try
        {
            $company = ""
            $language = ""
            $aos = ""
            $config = ""
            $ax.logon($company,$language,$aos,$config)

            return $true
        }
        catch
        {
            $retObj.AppendErrorMessage($_.Exception.Message)
            return $false
        }
    }
    function WP-netBCDisconnect([Microsoft.Dynamics.BusinessConnectorNet.Axapta]$ax, $retObj) {
        try
        {
            $ax.Logoff()|Out-Null
        }
        catch
        {
            $retObj.AppendErrorMessage($_.Exception.Message) 
        }
    }
    function WP-netBCDIXFCheck([string]$DIXFnetworkpath)
    {
        
        $retObj = New-Object AxMonitor.CheckStatus

        if([string]::IsNullOrEmpty($DIXFnetworkpath)){
            $settings = WP-LoadSettings
            $DIXFnetworkpath = $settings.dixf.path
        }

        #il seguente é un check sul metadata svc e poi la connessione da AOS a DB(va eseguito da AX user)
        $axconn = new-object Microsoft.Dynamics.BusinessConnectorNet.Axapta

        $result = $false

        if(WP-netBCConnect -ax $axconn -retObj $retObj)
        {
            #$r=$ax.CallStaticRecordMethod("DMFParameters","getServiceConnectionUrl")

            if(![string]::IsNullOrEmpty($DIXFnetworkpath)){ 
               $result = $axconn.CallStaticRecordMethod("DMFParameters","validateSharedFileFolderPath", $DIXFnetworkpath)
               $result = $result.get_Item(1)
            }
            WP-netBCDisconnect -ax $axconn -retObj $retObj
        }
            
        if($result) {
            $retObj.SetStatusMessage(0, "DIXF shared path $DIXFnetworkpath correctly validated")
        }
        else
        {
            $retObj.SetStatusMessage(2, "DIXF shared path $DIXFnetworkpath validation failed")
        }
        
        return $retObj
    }
    #net.tcp
    function WP-AxMetadataService_NetTcpCheck([string]$aosServer,[int]$netTCPport)
    {
        #ax userparam
    
        $retObj = New-Object AxMonitor.CheckStatus

        #aos pu'o essere ricavato,per ora facciamo che alla peggio si mette localhost
        if([string]::IsNullOrEmpty($aosServer)){ $aosServer = "localhost" }
        if($netTCPport -eq 0) { $netTCPport = 8201 } #devo pescarla da config

        #$aosCfg = WP-getClientConfigurationModel 
        #$aosCfg.wcfServices.SelectNodes('endpoint[@name="MetadataServiceEndpoint"]');

        $cueNames = $null
        try
        {
            $NetTcpBinding = new-object System.ServiceModel.NetTcpBinding
            $netTcpUri = "net.tcp://" + $aosServer + ":" + "$netTCPport" + "/DynamicsAx/Services/MetadataService"

            $endPointIdentity = [System.ServiceModel.EndpointIdentity]::CreateSpnIdentity($null);

            $endpoint = new-object System.ServiceModel.EndpointAddress($netTcpUri, $endPointIdentity, $null)

            $serviceClassObject = new-object Microsoft.Dynamics.AX.Framework.Services.Metadata.Client.AxMetadataServiceClient($NetTcpBinding, $endpoint)

            $cueNames = $serviceClassObject.GetCueNames()

            $serviceClassObject.Close()
        }
        catch
        {
            $retObj.AppendErrorMessage($_.Exception.Message) 
        }

        if($cueNames -and $cueNames.Count -gt 0) {
            $retObj.SetStatusMessage(0, [string]::Format("Metadata Service $aosServer"+":$netTCPport\GetCueNames returned {0} items", $cueNames.Count))
        }
        else
        {
            $retObj.SetStatusMessage(2, "Metadata Service $aosServer"+":$netTCPport\GetCueNames returned no item")
        }
        
        return $retObj
    }
    function WP-AxManageabilityServiceGroup_NetTcpCheck([string]$aosServer,[int]$netTCPport)
    {
        #ax admin
    
        $retObj = New-Object AxMonitor.CheckStatus

        #aos pu'o essere ricavato,per ora facciamo che alla peggio si mette localhost
        if([string]::IsNullOrEmpty($aosServer)){ $aosServer = "localhost" }
        if($netTCPport -eq 0) { $netTCPport = 8201 } #devo pescarla da config
        
        #$aosCfg = WP-getClientConfigurationModel 
        #$aosCfg.wcfServices.SelectNodes('endpoint[@name="NetTcpBinding_AxManagementPackService"]');

        try
        {
            $NetTcpBinding = new-object System.ServiceModel.NetTcpBinding
            $netTcpUri = "net.tcp://" + $aosServer + ":" + "$netTCPport" + "/DynamicsAx/Services/AxManageabilityServiceGroup"
            $endPointIdentity = [System.ServiceModel.EndpointIdentity]::CreateSpnIdentity($null);
            $endpoint = new-object System.ServiceModel.EndpointAddress($netTcpUri, $endPointIdentity, $null)
            
            $serviceClassObject = new-object AxManagementPackServiceClient($NetTcpBinding, $endpoint)
            $callContext = new-object schemas.microsoft.com.dynamics._2010._01.datacontracts.CallContext
            $callContext.LogonAsUser = [Environment]::UserDomainName + "\" + [Environment]::UserName
            
            $result = ($serviceClassObject.testBasicServiceCall($callContext) -ne 0)

            $serviceClassObject.Close()
        }
        catch
        {
            $retObj.AppendErrorMessage($_.Exception.Message) 
        }


        if($result -eq $null) {
            $retObj.SetStatusMessage(2, "Manageability Service Group Check on $aosServer"+":$netTCPport failed")
        }
        elseif($result) {
            $retObj.SetStatusMessage(0, "Manageability Service Group $aosServer"+":$netTCPport\testBasicServiceCall returned true")
        }
        else {
            $retObj.SetStatusMessage(2, "Manageability Service Group $aosServer"+":$netTCPport\testBasicServiceCall returned false")
        }

        return $retObj
    }
    function WP-AxQueryService_NetTcpCheck([string]$aosServer,[int]$netTCPport)
    {
        #ax userparam
    
        $retObj = New-Object AxMonitor.CheckStatus
        
        #aos pu'o essere ricavato,per ora facciamo che alla peggio si mette localhost
        if([string]::IsNullOrEmpty($aosServer)){ $aosServer = "localhost" }
        if($netTCPport -eq 0) { $netTCPport = 8201 } #devo pescarla da config
        
        #$aosCfg = WP-getClientConfigurationModel 
        #$aosCfg.wcfServices.SelectNodes('endpoint[@name="MetadataServiceEndpoint"]');

        $result=$null
        try
        {
            $NetTcpBinding = new-object System.ServiceModel.NetTcpBinding
            $NetTcpBinding.TransferMode = [System.ServiceModel.TransferMode]::Streamed
            $netTcpUri = "net.tcp://" + $aosServer + ":" + "$netTCPport" + "/DynamicsAx/Services/QueryService"

            $endPointIdentity = [System.ServiceModel.EndpointIdentity]::CreateSpnIdentity($null);

            $endpoint = new-object System.ServiceModel.EndpointAddress($netTcpUri, $endPointIdentity, $null)
            
            $serviceClassObject = new-object Microsoft.Dynamics.AX.Framework.Services.QueryService.QueryServiceClient($NetTcpBinding, $endpoint)
    
            $paging=(new-object Microsoft.Dynamics.AX.Framework.Services.QueryService.ValueBasedPaging) -as [Microsoft.Dynamics.AX.Framework.Services.QueryService.Paging]
            $paging.RecordLimit = 1

            $dataset=$serviceClassObject.ExecuteStaticQuery("SRSServers",[ref]$paging)
            $result=$dataset.Tables[0].Rows

            $serviceClassObject.Close()

        }
        catch
        {
            $retObj.AppendErrorMessage($_.Exception.Message) 
        }

        
        if($result -and $result.Count -gt 0) {
            $retObj.SetStatusMessage(0, [string]::Format("Query Service $aosServer"+":$netTCPport\SRSServers returned {0} items", $result.Count))
        }
        else
        {
            $retObj.SetStatusMessage(2, "Query Service $aosServer"+":$SRSServers\GetCueNames returned no item")
        }
        
        return $retObj
    }
    #printers, posso fare lista, potrei mettere un conteggio
    function WP-sharedPrintersCheck([string]$printServer, [string]$printerList = "")#OBchecked , aggiungere jobcount
    {
        $printerArray=$printerList.Split("|", [System.StringSplitOptions]::RemoveEmptyEntries)
        
        if([string]::IsNullOrEmpty($printServer)){ 
            $settings = WP-LoadSettings
            $printServer = $settings.SelectNodes('printserver')[0].server
        }
        if([string]::IsNullOrEmpty($printServer)){ 
            $printServer = (hostname)
        }

        $retObj = New-Object AxMonitor.CheckStatus

        $res = Get-Printer -ComputerName $printServer -WarningVariable wn -WarningAction SilentlyContinue -ErrorVariable er -ErrorAction SilentlyContinue|Where-Object { $_.Shared }|foreach {$_.Name}
        foreach($erEl in $er){
            $retObj.AppendErrorMessage($erEl.Exception.Message);
        }

        if(($printerArray.Count -eq 0) -and ($er.Count -eq 0))
        {
            $retObj.SetStatusMessage(0,[string]::Format("found {0} printers shared on $printServer",$res.Count));
        }
        else
        {
            $result=$true   
            foreach($printer in $printerArray)
            {
                if($res -and $res.Contains($printer))
                {
                    $result = $result -and $true
                    $retObj.AppendErrorMessage("$printServer\$printer is shared");
                }
                else
                {
                    $result = $false
                    $retObj.AppendErrorMessage("$printServer\$printer is not shared");
                }
                
                
            }
            #dovrei mettere un flag che mi chiede se voglio questo dettaglio
            foreach($printer in $res)
            {
                if(!$printerArray.Contains($printer))
                {
                    $retObj.AppendErrorMessage("$printServer\$printer is shared");
                } 
            }
                
            if($result)
            {
                $retObj.SetStatusMessage(0,[string]::Format("found {0} printers shared on $printServer",$res.Count));
            }
            else
            {
                $retObj.SetStatusMessage(2,[string]::Format("found {0} printers shared on $printServer",$res.Count));
            }
        }
        return $retObj
    }
    #questo 'e un check da implementare se prevedo un settingsfile
    function WP-sharedPrintersList() #OBchecked
    {
        $retObj = New-Object AxMonitor.CheckStatus
        
        #leggo settings file e poi chiamo  WP-sharedPrintersCheck
        $settings = WP-LoadSettings
        foreach($printserver in $settings.SelectNodes('printserver'))
        {
            $printerList = ""
            foreach($printer in $printserver.SelectNodes('printer').name)
            {
                $printerList += $printer + "|"
            }
            $printerList = $printerList.TrimEnd('|')

            #mettere lúnione di due risultati
            $retObj = WP-sharedPrintersCheck -printServer $printserver.server -printerList $printerList
        }

        #qui 'e l' occasione per rivedere un po' il meccanismo di checks multipli e poi unione dei risultati
        return $retObj
    } 
    #filesharing
    function WP-testPath([Parameter(Mandatory=$true)][string]$path)
    {

        $retObj = New-Object AxMonitor.CheckStatus

        $res=Test-Path $path -ErrorAction SilentlyContinue -ErrorVariable er
        if(!$res)
        {
            $res=($er|where Exception -is [System.UnauthorizedAccessException]).Count -eq 1
        }

        if($res)
        {
            $retObj.SetStatusMessage(0,"$path is valid");
        }
        else
        {
            $retObj.SetStatusMessage(2,"$path is not valid");
            foreach($erEl in $er){
                $retObj.AppendErrorMessage($erEl.Exception.Message);
            }
        }
        
        return $retObj
    }
    function WP-testPathAccess([string]$shareName, [string]$path)
    {
        #serve accesso dir list alla cartella...

        if(![string]::IsNullOrEmpty($shareName))
        {
            $retObj = New-Object AxMonitor.CheckStatus

            $settings = WP-LoadSettings
            $share=$settings.fileshare.SelectSingleNode('share[@name="' + $shareName + '"]')
            if(![string]::IsNullOrEmpty($share.value))
            {
                $ntfsaccesses=Get-NTFSAccess -Path $share.value -ErrorAction SilentlyContinue -ErrorVariable ers
                foreach($er in $ers)
                {
                    $retObj.AppendErrorMessage($er.Exception.Message);   
                }
                if($ntfsaccesses -eq $null)
                {
                    $retObj.SetStatusMessage(2, "$shareName with path "+$share.value+" is not shared");
                }
                else
                {
                    $result=$true

                    foreach($account in $share.SelectNodes('account'))
                    {

                        $ntfsaccess = $ntfsaccesses|where { $_.Account -eq $account.name }

                        if($ntfsaccess.AccessControlType -ne $account.accessControlType){
                            $retObj.AppendErrorMessage([string]::Format("AccessControlType is {0} not {1}",$ntfsaccess.AccessControlType,$account.accessControlType));
                            $result=$false
                        }
                        if($ntfsaccess.AccessRights -ne $account.accessRights){
                            $retObj.AppendErrorMessage([string]::Format("AccessRights is {0} not {1}",$ntfsaccess.AccessRights,$account.accessRights));
                            $result=$false
                        }
                        if($ntfsaccess.InheritanceFlags -ne $account.inheritanceFlags){
                            $retObj.AppendErrorMessage([string]::Format("InheritanceFlags is {0} not {1}",$ntfsaccess.InheritanceFlags,$account.inheritanceFlags));
                            $result=$false
                        }
                        if($ntfsaccess.PropagationFlags -ne $account.propagationFlags){
                            $retObj.AppendErrorMessage([string]::Format("PropagationFlags is {0} not {1}",$ntfsaccess.PropagationFlags,$account.propagationFlags));
                            $result=$false
                        }
                    }

                    if($result){
                        $retObj.SetStatusMessage(0,"$shareName on " + $tmp.Path + " is valid");
                    }else{
                        $retObj.SetStatusMessage(2,"$shareName on " + $tmp.Path + " is not valid");
                    }
                }
            }
            else
            {
                $retObj.SetStatusMessage(2, "$shareName path not found in settings");
            }
            return $retObj
        }
        else
        {
            #controlla che non é null
            return WP-testPath -path $path
        }
    }
    function WP-testUserPathsAccess([string]$accountName)
    {
        #serve accesso dir list alla cartella...
        
        $retObj = New-Object AxMonitor.CheckStatus

        $settings = WP-LoadSettings
        $shares = $settings.fileshare.SelectNodes('share[account/@account="'+$accountName+'"]')
        
        $result=$true

        foreach($share in $shares)
        {
            $ntfsaccess=Get-NTFSAccess -Path $share.value -Account $accountName -ErrorAction SilentlyContinue -ErrorVariable ers
            foreach($er in $ers)
            {
                $retObj.AppendErrorMessage($er.Exception.Message);   
            }

            if($ntfsaccess -eq $null)
            {
                $retObj.SetStatusMessage(2, $share.name + " with path "+$share.value+" is not shared");
            }
            else
            {
                
                #Write-Host "3:" $share.name $share.value
                if($ntfsaccess.AccessControlType -ne $share.account.accessControlType){
                    $retObj.AppendErrorMessage([string]::Format($share.name + " AccessControlType is {0} not {1}",$ntfsaccess.AccessControlType,$share.account.accessControlType));
                    $result=$false
                }
                if($ntfsaccess.AccessRights -ne $share.account.accessRights){
                    $retObj.AppendErrorMessage([string]::Format($share.name + " AccessRights is {0} not {1}",$ntfsaccess.AccessRights,$share.account.accessRights));
                    $result=$false
                }
                if($ntfsaccess.InheritanceFlags -ne $share.account.inheritanceFlags){
                    $retObj.AppendErrorMessage([string]::Format($share.name + " InheritanceFlags is {0} not {1}",$ntfsaccess.InheritanceFlags,$share.account.inheritanceFlags));
                    $result=$false
                }
                if($ntfsaccess.PropagationFlags -ne $share.account.propagationFlags){
                    $retObj.AppendErrorMessage([string]::Format($share.name + " PropagationFlags is {0} not {1}",$ntfsaccess.PropagationFlags,$share.account.propagationFlags));
                    $result=$false
                }

            }
        }
        
        if($result){
            $retObj.SetStatusMessage(0,"sharing for $accountName are valid");
        }else{
            $retObj.SetStatusMessage(2,"sharing for $accountName are not valid");
        }

        return $retObj
    }
    function WP-testAllUserPathsAccess
    {
        #serve accesso dir list alla cartella...
        
        $retObj = New-Object AxMonitor.CheckStatus

        $settings = WP-LoadSettings
        $shares = $settings.fileshare.SelectNodes('share')
        
        $result=$true

        foreach($share in $shares)
        {
            #Write-Host "1: " $share
            foreach($account in $share.account)
            {
                #Write-Host "2: " $account
                #Write-Host "3: " $share.value  $account.account
                $ntfsaccess=Get-NTFSAccess -Path $share.value -Account $account.account -ErrorAction SilentlyContinue -ErrorVariable ers
                foreach($er in $ers)
                {
                    $retObj.AppendErrorMessage($er.Exception.Message);   
                }

                if($ntfsaccess -eq $null)
                {
                    $retObj.SetStatusMessage(2, $share.name + " with path "+$share.value+" is not shared");
                }
                else
                {
                    if($ntfsaccess.AccessControlType -ne $account.accessControlType){
                        $retObj.AppendErrorMessage([string]::Format($share.name + " AccessControlType is {0} not {1}",$ntfsaccess.AccessControlType,$account.accessControlType));
                        $result=$false
                    }
                    if($ntfsaccess.AccessRights -ne $account.accessRights){
                        $retObj.AppendErrorMessage([string]::Format($share.name + " AccessRights is {0} not {1}",$ntfsaccess.AccessRights,$account.accessRights));
                        $result=$false
                    }
                    if($ntfsaccess.InheritanceFlags -ne $account.inheritanceFlags){
                        $retObj.AppendErrorMessage([string]::Format($share.name + " InheritanceFlags is {0} not {1}",$ntfsaccess.InheritanceFlags,$account.inheritanceFlags));
                        $result=$false
                    }
                    if($ntfsaccess.PropagationFlags -ne $account.propagationFlags){
                        $retObj.AppendErrorMessage([string]::Format($share.name + " PropagationFlags is {0} not {1}",$ntfsaccess.PropagationFlags,$account.propagationFlags));
                        $result=$false
                    }
                }
            }
        }
        
        if($result){
            $retObj.SetStatusMessage(0,"sharing are valid");
        }else{
            $retObj.SetStatusMessage(2,"sharing are not valid");
        }

        return $retObj
    }

    function WP-testSharedPath([Parameter(Mandatory=$true)][string]$shareName,[Parameter(Mandatory=$true)][string]$accountName,[Parameter(Mandatory=$true)]$accessControlType,[Parameter(Mandatory=$true)]$accessRights,[Parameter(Mandatory=$true)]$inheritanceFlags,[Parameter(Mandatory=$true)]$propagationFlags) {
        
        $retObj = New-Object AxMonitor.CheckStatus

        $tmp = $(Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue) 
        #poi definiamo meglio nei settings
        $smbAccessAccount=(Get-SmbShareAccess -Name $shareName -ErrorAction SilentlyContinue).AccountName -eq "EveryOne"
        #poi definiamo meglio nei settings
        $smbAccessType=(Get-SmbShareAccess -Name $shareName -ErrorAction SilentlyContinue).AccessRight -eq "Change"
        $smbAccess = $smbAccessAccount -and $smbAccessType

        if($tmp -eq $null)
        {
            $retObj.SetStatusMessage(2,"$shareName does not exist");
        }
        elseif(!$smbAccess)
        {
            $retObj.SetStatusMessage(2,"$shareName has no write access");
        }
        else
        {
            $result=$true
            try
            {
                $ntfsaccess = Get-NTFSAccess $tmp.Path -Account $accountName

                if($ntfsaccess.AccessControlType -ne $accessControlType){
                    $retObj.AppendErrorMessage([string]::Format("AccessControlType is {0} not {1}",$ntfsaccess.AccessControlType,$accessControlType));
                    $result=$false
                }
                if($ntfsaccess.AccessRights -ne $accessRights){
                    $retObj.AppendErrorMessage([string]::Format("AccessRights is {0} not {1}",$ntfsaccess.AccessRights,$accessRights));
                    $result=$false
                }
                if($ntfsaccess.InheritanceFlags -ne $inheritanceFlags){
                    $retObj.AppendErrorMessage([string]::Format("InheritanceFlags is {0} not {1}",$ntfsaccess.InheritanceFlags,$inheritanceFlags));
                    $result=$false
                }
                if($ntfsaccess.PropagationFlags -ne $propagationFlags){
                    $retObj.AppendErrorMessage([string]::Format("PropagationFlags is {0} not {1}",$ntfsaccess.PropagationFlags,$propagationFlags));
                    $result=$false
                }
            }
            catch
            {
                $retObj.AppendErrorMessage($_.Exception.Message);
            }

            if($result){
                $retObj.SetStatusMessage(0,"$shareName on " + $tmp.Path + " is valid");
            }else{
                $retObj.SetStatusMessage(2,"$shareName on " + $tmp.Path + " is not valid");
            }
        }
        return $retObj
    }

    function WP-testSharingConfig
    {
        #this need config file on the system
        Write-Host "WP-testSharingConfig"
    }
    #SSRS
    function WP-SSRSwebCheck([string]$webpage)#OBchecked
    {
        $settings = WP-LoadSettings
        if([string]::IsNullOrEmpty($webpage)) { $webpage = $settings.ssrssvc.webpage }

        return WP-WebPageCheck -webpage $webpage
    }
    function WP-SSRSsvcCheck([string]$reportServiceURI) #OBchecked
    {
        $retObj = New-Object AxMonitor.CheckStatus

        
        if([string]::IsNullOrEmpty($reportServiceURI)){ 
            $settings = WP-LoadSettings
            #si puó anche ricavare dal db
            $reportServiceURI = $settings.ssrssvc.uri
        }

        try
        {
            $SSRSProxy = new-webserviceproxy -Uri $ReportServiceURI -Namespace SSRS.ReportingService2005 -UseDefaultCredential -ErrorAction SilentlyContinue -ErrorVariable er
            
            if($er.Count -gt 0)
            {
                for($i=0;$i -lt $er.Count;$i++)
                {
                    $retObj.AppendErrorMessage($er[$i].ErrorDetails.Message);
                } 
                $retObj.SetStatusMessage(2, "Error in retrieving data from SSRS service")
                return $retObj
            }

            $list = $SSRSProxy.ListChildren("/DynamicsAX",$false)

            if($list.Count -gt 0) {
                $retObj.SetStatusMessage(0, [string]::Format("Found {0} report types",$list.Count))
            } else {
                $retObj.SetStatusMessage(2, "Found 0 report types")
            }
        }
        catch{
             $retObj.SetStatusMessage(2, "Error in retrieving data from SSRS service")
             $retObj.AppendErrorMessage($_.Exception.Message);
        }
        return $retObj
    }
    function WP-SSRSreportRender([string]$reportServiceURI) #OBchecked
    {
        $retObj = New-Object AxMonitor.CheckStatus
        
        if([string]::IsNullOrEmpty($reportServiceURI)){ 
            $settings = WP-LoadSettings
            #si puó anche ricavare dal db
            $reportServiceURI = $settings.ssrssvc.renderuri
        }      
        $ReportPath = "/DynamicsAx/SRSReportServerWarmup.AutoDesign"            
        $format = "xml"            
        $deviceinfo = ""            
        $extention = ""            
        $mimeType = ""            
        $encoding = "UTF-8"            
        $warnings = $null            
        $streamIDs = $null      
              
        $Reports = New-WebServiceProxy -Uri $reportServiceURI -UseDefaultCredential -namespace "ReportExecution2005" -ErrorAction SilentlyContinue -ErrorVariable er -WarningAction SilentlyContinue -WarningVariable wn      

        if($er.Count -gt 0)
        {
            for($i=0;$i -lt $er.Count;$i++)
            {
                $retObj.AppendErrorMessage($er[$i].ErrorDetails.Message);
            } 
            $retObj.SetStatusMessage(2, "Error in retrieving data from SSRS service")
            return $retObj
        }

        $Result = $null
        try
        {            
            $rsExec = new-object ReportExecution2005.ReportExecutionService            
            $rsExec.Credentials = [System.Net.CredentialCache]::DefaultCredentials             
            
            #Set ExecutionParameters            
            $execInfo = @($ReportPath, $null)             
            
            #Load the selected report.

            #errore qui non é gestito...
            $rsExec.GetType().GetMethod("LoadReport").Invoke($rsExec, $execInfo) | out-null 
    
            $parameters = [ReportExecution2005.ParameterValue[]] @()            
      
            #errore qui non é gestito...
            #Set ExecutionParameters            
            $ExecParams = $rsExec.SetExecutionParameters($parameters, "en-us");             
         
            #errore qui non é gestito...   
            $render = $rsExec.Render($format, $deviceInfo,[ref] $extention, [ref] $mimeType,[ref] $encoding, [ref] $warnings, [ref] $streamIDs)             
  
            #la finezza dei 3 pt di domanda si puó anche togliere          
            $Result = [text.encoding]::ascii.getString($render,3,$render.Count -3)  

            $Result = [xml]([text.encoding]::ascii.getString($render,3,$render.Count -3))
        }
        catch
        {
            $retObj.AppendErrorMessage($_.Exception.Message);
        } 

        $count = 0
        if($Result.Report.Table1.Detail_Collection.Detail -ne $null)
        {
            $count = 1
            if($Result.Report.Table1.Detail_Collection.Detail.Count -gt 0)
            {
                $count = $Result.Report.Table1.Detail_Collection.Detail.Count
            }
        }

        if($count -gt 0)
        {
            $retObj.SetStatusMessage(0, "SSRS rendering worked successfully")
        }
        else
        {
            $retObj.SetStatusMessage(2, "SSRS rendering failed")
        }

        return $retObj
    }
    function WP-SSRSreportRenderAndSave([string]$reportServiceURI,[Parameter(Mandatory=$true)][string]$Path,[string]$format="xml") #OBchecked, aggiungere anche altri formati
    {
        $retObj = New-Object AxMonitor.CheckStatus
        
        if([string]::IsNullOrEmpty($reportServiceURI)){ 
            $settings = WP-LoadSettings
            #si puó anche ricavare dal db
            $reportServiceURI = $settings.ssrssvc.renderuri
        }     
        $ReportPath = "/DynamicsAx/SRSReportServerWarmup.AutoDesign"            
        #$format = "xml"            
        $deviceinfo = ""            
        $extention = ""            
        $mimeType = ""            
        $encoding = "UTF-8"            
        $warnings = $null            
        $streamIDs = $null      
              
        $Reports = New-WebServiceProxy -Uri $reportServiceURI -UseDefaultCredential -namespace "ReportExecution2005" -ErrorAction SilentlyContinue -ErrorVariable er -WarningAction SilentlyContinue -WarningVariable wn      

        if($er.Count -gt 0)
        {
            for($i=0;$i -lt $er.Count;$i++)
            {
                $retObj.AppendErrorMessage($er[$i].ErrorDetails.Message);
            } 
            $retObj.SetStatusMessage(2, "Error in retrieving data from SSRS service")
            return $retObj
        }

        $Result = $null
                    
        $rsExec = new-object ReportExecution2005.ReportExecutionService            
        $rsExec.Credentials = [System.Net.CredentialCache]::DefaultCredentials             
            
        #Set ExecutionParameters            
        $execInfo = @($ReportPath, $null)             
            
        #Load the selected report.

        #errore qui non é gestito...
        $rsExec.GetType().GetMethod("LoadReport").Invoke($rsExec, $execInfo) | out-null 
    
        $parameters = [ReportExecution2005.ParameterValue[]] @()            
      
        #errore qui non é gestito...
        #Set ExecutionParameters            
        $ExecParams = $rsExec.SetExecutionParameters($parameters, "en-us");             
         
        #errore qui non é gestito...   
        $render = $rsExec.Render($format, $deviceInfo,[ref] $extention, [ref] $mimeType,[ref] $encoding, [ref] $warnings, [ref] $streamIDs)             
  
        #la finezza dei 3 pt di domanda si puó anche togliere          
        switch($format)
        {
            "pdf" {
                [io.file]::WriteAllBytes($Path,$render)
            }
            "csv" {
                [io.file]::WriteAllText($Path,[text.encoding]::ascii.getString($render,3,$render.Count -3));
                break;
            }
            "xml" {
                [io.file]::WriteAllText($Path,[text.encoding]::ascii.getString($render,3,$render.Count -3));
                break;
            }
            "default" {
                [io.file]::WriteAllBytes($Path,$render);
                 break;
            }
        }
    }
    #DIXF (non riesco a farlo funzionare su queste macchine)
    function WP-DIXFsvcCheck([string]$dixfServiceURI,[string]$dixfServiceUser,[string]$DIXFnetworkpath) #OBnotworking, da vedere
    {
        
        $settings = WP-LoadSettings
        if([string]::IsNullOrEmpty($dixfServiceURI)){
            $dixfServiceURI = $settings.dixf.svc
        }
        if([string]::IsNullOrEmpty($dixfServiceUser)){
            $dixfServiceUser = $settings.dixf.user
        }
        if([string]::IsNullOrEmpty($dixfServiceUser)){
            $dixfServiceUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        }
        if([string]::IsNullOrEmpty($DIXFnetworkpath)){
            $DIXFnetworkpath = $settings.dixf.path
        }

        $binding = New-Object System.ServiceModel.WSHttpBinding

        #$id=[System.ServiceModel.EndpointIdentity]::CreateUpnIdentity([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
        $id=[System.ServiceModel.EndpointIdentity]::CreateUpnIdentity($dixfServiceUser)
        $address = new-object System.ServiceModel.EndpointAddress (new-object Uri "http://1869DB0011:7000/DMFService/DMFServiceHelper.svc"),$id

        $obj=new-object Microsoft.Dynamics.AX.Framework.Tools.DMF.ServiceProxy.DMFServiceReference.ServiceContractClient $binding,$address
        
        $res = $obj.HasWritePermission($DIXFnetworkpath)

        $obj.Dispose()

        Write-Host "HasWritePermission" $res
    }
    #HelpServer (mettere nei settings)
    function WP-HelpSrvWebCheck([string]$helpServerPath, [string]$language, [string]$title) #OBchecked
    {
    
        $settings = WP-LoadSettings
        if([string]::IsNullOrEmpty($helpServerPath)){ $helpServerPath = $settings.helpserver.uri }
        if([string]::IsNullOrEmpty($language)){ $language = $settings.helpserver.defaultLanguage }
        if([string]::IsNullOrEmpty($title)){ $title = $settings.helpserver.SelectNodes('check[@language="'+$language+'"]').title }

        #impostare da settings
        #$helpServerPath = "http://1871as0031:9100/DynamicsAX6HelpServer"
        $helpServerPath = $helpServerPath.TrimEnd('/');

        $webpage = "$helpServerPath/Topic.aspx?ContentLanguage=$language&ResourceLanguage=$language&IncludeDefault=True"
        
        #title potrei impostare nei settings per la lingua

        return WP-WebPageCheck -webpage $webpage -title $title
    }
    function WP-HelpSrvSearchCheck([string]$helpServerPath,[string]$textToFind) #OBchecked --> attenzione a check lingua
    {
        $settings = WP-LoadSettings
        if([string]::IsNullOrEmpty($helpServerPath)){ $helpServerPath = $settings.helpserver.uri }
        if([string]::IsNullOrEmpty($language)){ $language = $settings.helpserver.defaultLanguage }
        if([string]::IsNullOrEmpty($textToFind)){ $textToFind = $settings.helpserver.SelectNodes('check[@language="'+$language+'"]').textToFind }

        $retObj = New-Object AxMonitor.CheckStatus

        #impostare da settings
        #$helpServerPath = "http://1871as0031:9100/DynamicsAX6HelpServer"
        $helpServerPath = $helpServerPath.TrimEnd('/');

        $tmp=""
        foreach($word in $textToFind.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries))
        {
            $tmp += $word 
        }

        $webpage = "$helpServerPath/Search.aspx?ContentLanguage=$language&ResourceLanguage=$language&IncludeDefault=True&QueryString=$tmp"

        $output=$null
        try
        {
            $output=Invoke-WebRequest $webpage -UseBasicParsing -UseDefaultCredentials -ErrorAction SilentlyContinue -ErrorVariable er
        }
        catch
        {
            $retObj.AppendErrorMessage($_.Exception.Message);
            $output=$null
        }
        $nResults = 0

        $res = $output.StatusCode -eq 200;
        if($res -and ![string]::IsNullOrEmpty($tmp)) { 
            $nResults = (Select-XML -Content $output.Content -XPath "//li[@class='SearchResult']").Count;
            $res = (Select-XML -Content $output.Content -XPath "//li[@class='SearchResult']").Count -gt 0
        }

        if($res)
        {
            $retObj.SetStatusMessage(0,"Help server search found $nResults results for '$textToFind'");
        }
        else
        {
            $retObj.SetStatusMessage(2,"Help server search found no result");
            foreach($error in $er){
                #Write-Host $error
                $retObj.AppendErrorMessage($error.Message);
            }
        }
    
        return $retObj
    }
    function WP-HelpServiceCheck #OBchecked
    {
        
        $retObj = New-Object AxMonitor.CheckStatus
        
        $settings = WP-LoadSettings
        $helpServicePath = $settings.helpserver.uri.TrimEnd('/') + "/HelpService.svc"

        try
        {
            $svc= New-Object HelpServiceClient (New-Object System.ServiceModel.BasicHttpBinding),$helpServicePath
            $config=$svc.GetConfiguration()
            if($config)
            {
                $retObj.SetStatusMessage(0,"Help service properly working");
            }
        }
        catch
        {
            $retObj.SetStatusMessage(2,"Help service not properly working");
            $retObj.AppendErrorMessage($_.Exception.Message);
        }

        return $retObj
    }
    #questo per lo lascio qui, poi vedr'o come usarlo
    function WP-HelpServiceGetContents 
    {
        
        $settings = WP-LoadSettings
        $helpServicePath = $settings.helpserver.uri.TrimEnd('/') + "/HelpService.svc"

        $svc= New-Object HelpServiceClient (New-Object System.ServiceModel.BasicHttpBinding),$helpServicePath

        $context = New-Object Microsoft.Dynamics.Framework.Help.ContentContext 
        $context.DocumentSet="UserDocumentation"
        $context.Language="EN-US"

        $contentList=$svc.GetTableOfContents($context,$true,$true)
    }
    #mobile portal
    #WP-WebPageCheck -webpage http://axprmob-weg:8002/ --> sviluppa
    #di base posso usare il check sul title
    function WP-WebPageCheck([string]$webpageId, [string]$webpage, [string]$title)  #OBchecked
    {
        
        if([string]::IsNullOrEmpty($webpage))
        {
            $settings = WP-LoadSettings
            $webpageSetts=$settings.webpages.SelectSingleNode('webpage[@id="'+$webpageId+'"]')
            $webpage = $webpageSetts.uri
            $title = $webpageSetts.title
        }

        $retObj = New-Object AxMonitor.CheckStatus
        
        $output=$null
        $res=$false
        try
        {
            $output=Invoke-WebRequest $webpage -UseBasicParsing -UseDefaultCredentials -ErrorAction SilentlyContinue -ErrorVariable er
            $res = $output.StatusCode -eq 200
        }
        catch
        {
            $retObj.AppendErrorMessage($_.Exception.Message);
            $output=$null
        }
        

        if($res)
        {
            if([string]::IsNullOrEmpty($title)) { 
                $retObj.SetStatusMessage(0,"Http page loaded");
            }else{ 
                if(([xml]$output.Content).html.head.title.Trim() -eq $title.Trim())
                {
                    $retObj.SetStatusMessage(0,"Http page loaded with correct title");
                }
                else
                {
                    $retObj.SetStatusMessage(2,"Http page loaded but not with correct title");
                    $retObj.AppendErrorMessage([string]::Format("Found {0} as title", ([xml]$output.Content).html.head.title.Trim()));
                }
            }
        }
        else
        {
            $retObj.SetStatusMessage(2,"Http page not loaded");
            foreach($error in $er){
                #Write-Host $error
                $retObj.AppendErrorMessage($error.Message);
            }
        }
    
        return $retObj
    }
    #ok, superuser required???
    function WP-WebSiteCheck([string]$website)
    {
        #local admin
        $retObj = New-Object AxMonitor.CheckStatus
        
        $res=$false
        try
        {
            $res = (Get-Website -Name AXPRODHELP -ErrorAction SilentlyContinue).State -eq "Started"
        }
        catch
        {
            $retObj.AppendErrorMessage($_.Exception.Message);
        }
        

        if($res)
        {
            $retObj.SetStatusMessage(0,"$website is running");
        }
        else
        {
            $retObj.SetStatusMessage(2,"$website is not running");
        }
    
        return $retObj
    }
    function WP-WebSitesCheck() #OBchecked
    {
        #local admin
        $retObj = New-Object AxMonitor.CheckStatus
        
        $settings = WP-LoadSettings
        $sites = $settings.iis.SelectNodes('site')

        $restot=$true

        foreach($site in $sites)
        {
            $res=$false
            try
            {
                
                $res = (Get-Website -Name AXPRODHELP -ErrorAction SilentlyContinue).State -eq "Started"
            }
            catch
            {
                $retObj.AppendErrorMessage($_.Exception.Message);
            }
            if(!$res){
                $retObj.AppendErrorMessage("$website is not running");
            }
            $restot = $restot -and $res
        }

        if($restot)
        {
            $retObj.SetStatusMessage(0,"websites are all running");
        }
        else
        {
            $retObj.SetStatusMessage(2,"websites are not all running");
        }
    
        return $retObj
    }

    #client
    function WP-getClientConfigurationModel([string]$configName,[string]$configFile)
    {
        #poi si puó anche salvare in un settings file
        
        if(![string]::IsNullOrEmpty($configName) -and [Microsoft.Dynamics.AX.Framework.Client.ConfigurationModel.ClientConfigurationModel]::GetConfigurationNames().Contains($configName)){
            $cfg= new-ObJECT Microsoft.Dynamics.AX.Framework.Client.ConfigurationModel.RegistryConfigurationModel $configName
        }elseif(![string]::IsNullOrEmpty($configFile)){
            $cfg= new-ObJECT Microsoft.Dynamics.AX.Framework.Client.ConfigurationModel.FileConfigurationModel $configFile
        }else{
            $cfg= [Microsoft.Dynamics.AX.Framework.Client.ConfigurationModel.ClientConfigurationModel]::DefaultConfiguration
        }

        $ret= @{
            aosInstances=$cfg.ReadAosInstances();
            wcfServices=([xml]$cfg.ReadWcfConfiguration()).configuration.'system.serviceModel'.client;
            }

        return $ret
    }#$cfg.wcfServices.SelectNodes('//endpoint[@name="NetTcpBinding_WHSMobileDevicesService"]')
    function WP-testClienttoAOSconnection([string]$configName,[string]$configFile)
    {
        <#
            .DESCRIPTION
            WP-tcpTest controlla ingresso tcp 
            funziona powershell 3.0, sviluppato in 5.1 
        #>
        $retObj = New-Object AxMonitor.CheckStatus
        #$pingMeasurement = New-Object AxMonitor.CheckMeasurement "pingTime={0}ms",20,100
        #$retObj.measurements.Add($pingMeasurement);

        #mettere nei settings eventuali connessioni

        $cfg=WP-getClientConfigurationModel

        if( $cfg.aosInstances.Count -eq 0){
            $retObj.SetStatusMessage(2,"Found no aos instance")
            return $retObj
        }

        $ret=$true
        foreach($aosInstance in $cfg.aosInstances)
        {
            $pingRes = Test-NetConnection -WarningAction SilentlyContinue $aosInstance.ServerName -Port $aosInstance.TcpIPPort
            
            if(!$pingRes.TcpTestSucceeded) {
                $ret=$false
                $retObj.AppendErrorMessage([string]::Format("Tcp connection to {0}:{1} failed",$aosInstance.ServerName, $aosInstance.TcpIPPort));
            }
        }

        if($ret) {
            $retObj.SetStatusMessage(0,"Client to AOS Test Connection Succeeded")
            #$retObj.measurements[0].Value=$pingRes.PingReplyDetails.RoundtripTime
            #$retObj.outCode = $retObj.measurements[0].outCode
        }else{
            $retObj.SetStatusMessage(2,"Client to AOS Test Connection  Failed")
        }
    
        return $retObj
    }
