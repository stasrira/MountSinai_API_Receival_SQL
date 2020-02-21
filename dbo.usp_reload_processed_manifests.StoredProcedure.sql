USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--exec usp_reload_processed_manifests
CREATE proc [dbo].[usp_reload_processed_manifests]
as

Begin 
	declare @entity_type int = 1;
	declare @str nvarchar (max) = ''
	declare @sp_name varchar (50) = 'usp_get_api_data_motrpac';

	--create temp table to hold intermediate results of the process
	create table #tb_reload (
		reload_id bigint,
		study_id int not null,
		manifestId varchar (20), 
		completed_status decimal (10, 4),
		completed_datetime datetime
		)

	/*
	Analyze reprocess requests submitted through dw_reloaded_manifests
	Extract all requested manifests into the temp table #tb_reload
	*/
	;with full_study as (--identify whole studies to be reprocessed
		select reload_id, study_id 
		from dw_reloaded_manifests 
		where completed_datetime is null
		and isnull(manifestId, '') = ''
		)
	, match_full_study_mids as (--identify mid to be reprocessed for the selected whole studies
		select f.reload_id, f.study_id, m.sample_retrieval_id as manifestId
		from full_study f 
		inner join dw_metadata m  on f.study_id = m.study_id
		group by reload_id, f.study_id, m.sample_retrieval_id
		)
	, single_mids as (--identify single MIDs to be reprocessed
		select reload_id, study_id, manifestId
		from dw_reloaded_manifests 
		where completed_datetime is null
		and isnull(manifestId, '') <> ''
		)
	, all_mids as ( --all MIDs that were submited for re-processing
		select reload_id, study_id, manifestId from match_full_study_mids
		union all
		select reload_id, study_id, manifestId from single_mids
		)
	insert into #tb_reload (reload_id, study_id, manifestId)
	select reload_id, study_id, manifestId 
	from all_mids a

	--identify MIDs that were not processed earlier and thus cannot be re-processed in this procedure
	update #tb_reload set 
		completed_status = -100,
		completed_datetime = getdate()
	from #tb_reload a
	where not exists 
		(select * from dw_metadata m where a.manifestId = m.sample_retrieval_id and a.study_id = m.study_id) --this will identify MIDs that were never processed earlier
	
--select * from #tb_reload --for testing only

	/* 
	--Dinamically create SQL statements for each manifest that needs to be reloaded and save into @str. 
	--The code will run the API retrieval procedure and udpate the status field of the temp table with 1 for success and 0 for error outcomes
	--Below is an example of code being generated in the previous statement
	-------------------------------------------------
	Begin try
		exec usp_get_api_data_motrpac 1, 'TST996-00200'; 
		update #tb_reload 
			set completed_datetime = getdate(), 
			completed_status = 1
		where study_id = 1 and manifestId = 'TST996-00200';
	End try
	Begin catch 
		update #tb_reload 
			set completed_datetime = getdate(),
			completed_status = 0
		where study_id = 1 and manifestId = 'TST996-00200';
	End catch
	------------------------------------------------------
	*/
	select @str = @str + 
	'
	Begin try
		exec ' + isnull(dbo.udf_get_config_value (study_id, @entity_type, 'api_call_stored_procedure'), @sp_name) 
		+ ' ' + cast (study_id as varchar (10)) + ', ''' + manifestId + '''; 
		update #tb_reload 
			set completed_datetime = getdate(), 
			completed_status = 1
		where study_id = ' + cast (study_id as varchar (10)) + ' and manifestId = ''' + manifestId + ''';
	End try
	Begin catch 
		update #tb_reload 
			set completed_datetime = getdate(),
			completed_status = 0
		where study_id = ' + cast (study_id as varchar (10)) + ' and manifestId = ''' + manifestId + ''';
	End catch 
		'  
	from #tb_reload a
	where completed_status is null --select only records that does not have status assigned yet
	Group by study_id, manifestId

print @str --for testing only
	
	exec sp_executesql @str --execute prepared SQL string


	--for testing only --START--
	--select reload_id, avg(isnull(completed_status,0)) completed_status, max(completed_datetime) comlpleted_datetime, count(*) manifest_count
	--	from #tb_reload
	--	Group by reload_id
	--for testing only --END--

	--update dw_reloaded_manifests with results of the reloading process
	;with reload_summary as (
		--results of processing collected in the temp table #tb_reload
		select reload_id, avg(isnull(completed_status,0)) completed_status, max(completed_datetime) comlpleted_datetime, count(*) manifest_count
		from #tb_reload
		Group by reload_id
	)
	--update dw_reloaded_manifests with final results of the process
	update dw_reloaded_manifests set 
		/*
		field completed_status from #tb_reload table will be 
		= 1, if all MID were successfully processed, 
		< 0, if the requested MID was not found in the originally processed MIDs (in dw_metadata)
		> 0 and < 1, if some errors were reported
		*/
		completed_status = iif(r.completed_status = 1, 'OK', iif(r.completed_status < 0 , 'NOT FOUND','ERROR')), 
		completed_datetime = r.comlpleted_datetime,
		processed_manifest_qty = r.manifest_count
	from dw_reloaded_manifests m 
	inner join reload_summary r on m.reload_id = r.reload_id

	--drop table #tb_reload
	IF OBJECT_ID('tempdb..#tb_reload') IS NOT NULL DROP TABLE #tb_reload
End

GO
