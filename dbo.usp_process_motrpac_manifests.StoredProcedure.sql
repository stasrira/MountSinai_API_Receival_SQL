USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
This procedure loops through list of Manifest IDs stored in dw_received_manifests and load API data for each one 
Already loaded manifests will be ignored
*/

--exec usp_process_motrpac_manifests
CREATE proc [dbo].[usp_process_motrpac_manifests] 
as

declare @entity_type int = 1;
declare @sp_name varchar (50) = 'usp_get_api_data_motrpac'
declare @str nvarchar (max) = ''
declare @tb_mid as table(mid varchar(20), study_id int, num_of_attempts int )
declare @err_status as varchar (20) = dbo.udf_get_config_value (1, 99, 'api_status_error')

--Identify manifests to be processed
;with 
not_processed 
--find all manifests that do not have any values in the dw_metadata
as 
	(
	select m.study_id, m.manifestId 
	from dw_received_manifests m 
		left join dw_metadata d on m.manifestId = d.sample_retrieval_id and m.study_id = d.study_id
	where
		isnull(m.ignore,0) = 0 
		and d.sample_retrieval_id is null
	)
,history_errors_attempts
--find history attempts counts for the processed manifests
as 
	(
	select
		[entity_id],  
		api_retrieval_id , count(*) num_errors
	from dw_api_retrieval_history
	where api_retrieval_status =  @err_status--'ERROR' --dbo.udf_get_config_value (@study_id, @entity_type, 'api_status_error') --
		and entity_type = 1 --study type
	Group by [entity_id], api_retrieval_id
	)
insert into @tb_mid (mid, study_id, num_of_attempts)
select m.manifestId, m.study_id, h.num_errors --, *
from dw_received_manifests m 
inner join not_processed p on m.manifestId = p.manifestId and m.study_id = p.study_id
left join  history_errors_attempts h on m.manifestId = h.api_retrieval_id and m.study_id = h.[entity_id]

;With tb_manifests_raw as 
	(
	select *, 
	isnull(dbo.udf_get_config_value (study_id, @entity_type, 'api_call_stored_procedure'), @sp_name) stored_proc_name,
	dbo.udf_get_config_value (study_id, @entity_type, 'max_failed_retrieval_attempts') failed_attempts
	from @tb_mid
	)
, tb_manifests as 
	(
	Select mid, study_id, num_of_attempts, stored_proc_name, 
		iif(
			isnumeric(
				isnull(failed_attempts,'')
					) > 0, 
		cast(failed_attempts as int), 0
		) failed_attempts_int
	from tb_manifests_raw
	)
Select
@str = @str + 'exec ' + stored_proc_name + ' ' + cast (study_id as varchar (10)) + ', ''' + mid + '''; '
from tb_manifests
		where 
		(
		isnull(num_of_attempts, 0) = 0 --use manifests that have no entries in the dw_api_retrieval_history
		or 
		num_of_attempts < failed_attempts_int or failed_attempts_int = 0 --use manifests that did not failed more than the configuration limit ('max_failed_retrieval_attempts') or if the limit is not set (or set to 0)
		) 

--select * from @tb_mid --for testing only

Print @str --for testing only

--example of a string:
--exec usp_get_api_data_motrpac 1, 'TST997-00200'; exec usp_get_api_data_motrpac 1, 'TST999-00403'; 

--execute the SQL string
exec sp_executesql @str

GO
