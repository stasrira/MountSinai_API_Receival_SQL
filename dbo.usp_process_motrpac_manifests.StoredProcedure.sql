USE [dw_motrpac]
GO
/****** Object:  StoredProcedure [dbo].[usp_process_motrpac_manifests]    Script Date: 11/28/2018 4:59:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec usp_process_motrpac_manifests
CREATE proc [dbo].[usp_process_motrpac_manifests] 
as

declare @study_id int = 1
declare @tb_mid as table(mid varchar(20))
declare @int_failed_attempts int, @str_failed_attempts varchar (100)

set @str_failed_attempts = dbo.udf_get_config_value (1, 'max_failed_retrieval_attempts')
set @int_failed_attempts = iif(
								isnumeric(
									isnull(@str_failed_attempts,'')
										) > 0, 
							cast(@str_failed_attempts as int), 0
							) 

--Identify manifests to be processed
;with 
not_processed 
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
as 
	(
	select 
		study_id, api_retrieval_id , count(*) num_errors
	from dw_api_retrieval_history
	where api_retrieval_status = dbo.udf_get_config_value (1, 'api_status_error') --'ERROR'
	Group by program_id, study_id, api_retrieval_id
	)
insert into @tb_mid (mid)
select m.manifestId --, *
from dw_received_manifests m 
inner join not_processed p on m.manifestId = p.manifestId and m.study_id = p.study_id
left join  history_errors_attempts h on m.manifestId = h.api_retrieval_id and m.study_id = h.study_id
where 
	(
	h.api_retrieval_id is null --use manifests that have no entries in the dw_api_retrieval_history
	or 
	(h.num_errors < @int_failed_attempts or @int_failed_attempts = 0) --use manifests that did not failed more than the configuration limit ('max_failed_retrieval_attempts') or if the limit is not set (or set to 0)
	) 


select * from @tb_mid
GO
