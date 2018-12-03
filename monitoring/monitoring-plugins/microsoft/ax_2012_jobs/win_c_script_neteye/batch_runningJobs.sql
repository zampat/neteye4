-- actual free batch tasks server per instance
;WITH currentrunningBatch AS
(
SELECT GETUTCDATE() as currentDate,SERVERID,COUNT(*) AS runningBatch FROM BATCH WHERE (STATUS=2 OR STATUS=7)
GROUP BY SERVERID
)
select 
	GETUTCDATE() as currentDate, 
	DB_NAME() as DBName,
	SERVERPROPERTY('MachineName') as DBServername,
	@@SERVICENAME as  DBServicename,
	CASE @@SERVICENAME
	WHEN 'MSSQLSERVER' THEN 'SQLServer'
	ELSE 'MSSQL$'+@@SERVICENAME
	END as SQLInstance,
	bgrp.SERVERID,
	SUBSTRING(bgrp.SERVERID,charindex('@',bgrp.SERVERID)+1,LEN(bgrp.SERVERID)) as host,
	SUBSTRING(bgrp.SERVERID,charindex('@',bgrp.SERVERID)+1,LEN(bgrp.SERVERID)) as AOSServer,
	SUBSTRING(bgrp.SERVERID,0,charindex('@',bgrp.SERVERID)) as AOSInstance,
	max(bcfg.MAXBATCHSESSIONS) as maxBatchSessions,
	(max(bcfg.MAXBATCHSESSIONS) - ISNULL(max(crbatch.runningBatch),0)) as freeBatchSessions,
	ISNULL(max(crbatch.runningBatch),0) as runningBatchSessions
FROM 
BATCHSERVERGROUP bgrp inner join BATCHSERVERCONFIG bcfg 
ON bcfg.SERVERID = bgrp.SERVERId 
inner join SYSSERVERCONFIG servercfg
on servercfg.SERVERID = bcfg.SERVERID
left join currentrunningBatch crbatch
on crbatch.SERVERID=bgrp.SERVERID 
WHERE
DATEDIFF(Second, CONVERT (date, GETUTCDATE()), GETUTCDATE())>=bcfg.STARTTIME 
and
DATEDIFF(Second, CONVERT (date, GETUTCDATE()), GETUTCDATE())<=bcfg.ENDTIME 
and servercfg.ENABLEBATCH=1
group by bgrp.SERVERID
