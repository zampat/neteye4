-- ACTUAL Overdue TASKS grouped by batch group
declare @timeoverdueinminutes as int
set @timeoverdueinminutes=$(timeoverdueinminutes)

select 
GETUTCDATE() as currentDate,
DB_NAME() as DBName,
SERVERPROPERTY('MachineName') as DBServername,
@@SERVICENAME as  DBServicename,
CASE @@SERVICENAME
   WHEN 'MSSQLSERVER' THEN 'SQLServer'
   ELSE 'MSSQL$'+@@SERVICENAME
END as SQLInstance,
GROUPID,
isnull(sum(BOverdueMinutes),0) as TotalOverdueMinutes,
count(*) as cntBatchOverdue 
from
	(
		select 
			GETUTCDATE() as currentDate,
			b.BATCHJOBID as Batchjobid,
			b.GROUPID as GROUPID,
			bj.CAPTION as BJCaption,
			b.CAPTION as BCaption,
			bj.STATUS as BatchJobStatus,
			b.STATUS as BatchStatus,
			bj.CREATEDBY as BJCREATEDBY,
			bj.CREATEDDATETIME as BJCREATEDDATETIME,
			bj.STARTDATETIME as BJSTARTDATETIME,
			bj.ORIGSTARTDATETIME as BJORIGSTARTDATETIME,
			bj.COMPANY as BJCOMPANY,
--			bj.DATAPARTITION as BJDATAPARTITION,
			b.CLASSNUMBER,b.CREATEDBY as BCREATEDBY,
			b.CREATEDDATETIME as BCREATEDDATETIME,
			b.STARTDATETIME as BSTARTDATETIME,
			b.ENDDATETIME as BENDDATETIME,
			b.IGNOREONFAIL as BIGNOREONFAIL,
			b.RETRIESONFAILURE as BRETRIESONFAILURE,
			b.RETRYCOUNT as BRETRYCOUNT,
			DATEDIFF(minute,  bj.ORIGSTARTDATETIME, GETUTCDATE()) as BOverdueMinutes 
		from batch b left join batchconstraints bc on b.RECID=bc.BATCHID
		join BATCHJOB bj on b.BATCHJOBID=bj.RECID
		where (b.STATUS=1 or b.STATUS=1 or b.STATUS=5)  and  (bc.recid is null)--or (--b.STATUS
		and DATEDIFF(minute,  bj.ORIGSTARTDATETIME, GETUTCDATE()) >= @timeoverdueinminutes
		union
		select 
			GETUTCDATE() as currentDate,
			b.BATCHJOBID,
			b.GROUPID,
			bj.CAPTION as BatchJobCaption,
			b.CAPTION as BatchCaption,
			bj.STATUS as BatchJobStatus,
			b.STATUS as BatchStatus,
			bj.CREATEDBY,
			bj.CREATEDDATETIME,
			bj.STARTDATETIME,
			bj.ORIGSTARTDATETIME,
			bj.COMPANY,
--			bj.DATAPARTITION,
			b.CLASSNUMBER,
			b.CREATEDBY,
			b.CREATEDDATETIME,
			b.STARTDATETIME,
			b.ENDDATETIME,
			b.IGNOREONFAIL,
			b.RETRIESONFAILURE,
			b.RETRYCOUNT, 
			DATEDIFF(minute, max(bcon.ENDDATETIME),GETUTCDATE() ) as BOverdueMinutes 
		from batch b join batchconstraints bc
			on b.RECID=bc.BATCHID 
		join BATCHJOB bj on b.BATCHJOBID=bj.RECID
		join batch bcon on bc.DEPENDSONBATCHID=bcon.RECID
		where 
		b.RECID in
			(	select 
					inb.RECID from batch inb left join batchconstraints inbc on inb.RECID=inbc.BATCHID 
				join BATCHJOB inbj on inb.BATCHJOBID=inbj.RECID
				join batch inbcon on inbc.DEPENDSONBATCHID=inbcon.RECID
				where 
					(inb.STATUS=1 or inb.STATUS=1 or inb.STATUS=5) and  ((inbcon.STATUS=4 and (inbc.EXPECTEDSTATUS=4 or inbc.EXPECTEDSTATUS=250)) or(inbcon.STATUS=3 and (inbc.EXPECTEDSTATUS=3 or inbc.EXPECTEDSTATUS=250)))
				group by inb.RECID
				having count(*)=(select count(*) from BATCHCONSTRAINTS tinbc where tinbc.BATCHID=inb.RECID)
			)
		group by 
		b.BATCHJOBID,
		b.GROUPID,
		bj.CAPTION,
		b.CAPTION,
		bj.STATUS,
		b.STATUS,
		bj.CREATEDBY,
		bj.CREATEDDATETIME,
		bj.STARTDATETIME,
		bj.ORIGSTARTDATETIME,
		bj.COMPANY,
		--bj.DATAPARTITION,
		b.CLASSNUMBER,
		b.CREATEDBY,
		b.CREATEDDATETIME,
		b.STARTDATETIME,
		b.ENDDATETIME,
		b.IGNOREONFAIL,
		b.RETRIESONFAILURE,
		b.RETRYCOUNT
		having DATEDIFF(minute,max(bcon.ENDDATETIME),GETUTCDATE()) >= @timeoverdueinminutes
	) as Batchoverdue
group by GROUPID
