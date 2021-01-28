SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @sqlVers numeric(4,2)
DECLARE @currentDatetime datetime;

set @currentDatetime=GETUTCDATE();

select
    @currentDatetime as [timestamp],
	a.transaction_id,
	a.session_id,
	--ses.context_info,
	cast(ses.context_info as varchar(128)) as axsession,
	SUBSTRING(REPLACE(LTRIM(cast(ses.context_info as varchar(128))), ' ',','),	CHARINDEX(',',REPLACE(LTRIM(cast(ses.context_info as varchar(128))),' ', ',')) + 1,CHARINDEX(',',	REPLACE(LTRIM(cast(ses.context_info as varchar(128))),' ', ','), CHARINDEX(',',REPLACE(LTRIM(cast(ses.context_info as varchar(128))),' ', ',')) + 1)- ( CHARINDEX(',',REPLACE(LTRIM(cast(ses.context_info as varchar(128))),	' ', ',')) )- CASE	WHEN cast(ses.context_info as varchar(128)) = ''	THEN 0	ELSE 1	END) AS AXSessionID,
	SUBSTRING(REPLACE(LTRIM(cast(ses.context_info as varchar(128))), ' ',','), 1,CHARINDEX(',',	REPLACE(LTRIM(cast(ses.context_info as varchar(128))),' ', ','))- CASE	WHEN cast(ses.context_info as varchar(128)) = '' THEN 0 ELSE 1 END) AS AXUser
	,ses.host_name
	,ses.login_name
	,ses.nt_user_name
	,ses.nt_domain
	,ses.host_process_id
	,ses.program_name
	,a.is_snapshot
	,d.login_time
	,b.transaction_begin_time
	,last_batch_time = d.last_batch
	,Transaction_sec=convert(numeric(18,2),datediff(ss,b.transaction_begin_time,getdate()))
	,Last_Batch_min =convert(numeric(18,2),datediff(MINUTE,d.last_batch,getdate()))
	,Login_Hours =
		convert(numeric(18,2),round(datediff(ss,d.login_time,getdate())/3600.0000,2))
	,Transaction_Hours =
		convert(numeric(18,2),round(datediff(ss,b.transaction_begin_time,getdate())/3600.0000,2))
	,Last_Batch_Hours =
		convert(numeric(18,2),round(datediff(mm,d.last_batch,getdate())/60.0000,2))
	,Transaction_min =
		convert(numeric(18,2),round(datediff(ss,b.transaction_begin_time,getdate())/60.0000,2))
	,b.name
	,b.transaction_type
	,transaction_type_desc =
	case b.transaction_type
	when 1 then 'Read/write transaction' 
	when 2 then 'Read-only transaction' 
	when 3 then 'System transaction' 
	when 4 then 'Distributed transaction'
	else ''end
	,b.transaction_state
	,transaction_state_desc =
	case b.transaction_state
	when 0 then 'Transaction has not been completely initialized yet.'
	when 1 then 'Transaction has been initialized but has not started.'
	when 2 then 'Transaction is active. '
	when 3 then 'Transaction has ended. Used for read-only transactions.'
	when 4 then 'Commit process has been initiated on the distributed transaction.'
	when 5 then 'Transaction is in a prepared state and waiting resolution.'
	when 6 then 'Transaction has been committed.'
	when 7 then 'Transaction is being rolled back. '
	when 8 then 'transaction has been rolled back.'
	else '' end
	,hostname = rtrim(d.hostname)
    ,d.program_name
	,Program_name = rtrim(d.Program_name)
	,loginame= rtrim(d.loginame)
	,SQL_text = e.text
from 
	sys.dm_tran_active_snapshot_database_transactions a
	join
	sys.dm_tran_active_transactions b
	on a.transaction_id = b.transaction_id 
	join
	master.dbo.sysprocesses d
	on a.session_id = d.spid
	join sys.dm_exec_sessions  ses
	on ses.session_id=a.session_id
	cross apply
	sys.dm_exec_sql_text( d.sql_handle ) e
where 
    convert(numeric(18,2),datediff(ss,b.transaction_begin_time,getdate()))>0
order by
	a.transaction_id

