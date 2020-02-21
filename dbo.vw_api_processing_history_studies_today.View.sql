USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create view [dbo].[vw_api_processing_history_studies_today]
as
with meta_hist as (
	select study_id, sample_retrieval_id, count (*) as sample_count
	from dw_metadata_modification_log
	Group by study_id, sample_retrieval_id
	)
, dates as (
	select  
	--DATEADD(day, DATEDIFF(day, 0, GETDATE()), -1) [beginOfYesterday],
	DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0) [beginOfToday]
	, DATEADD(day, DATEDIFF(day, 0, GETDATE() + 1 ), 0) [beginOfTomorrow]
	)
--get study info
select --t.*, h.datetime_stamp, 
	e.entity_type_name, p.[program_Name], s.study_Name, d.dict_name, 
	h.api_retrieval_id, isnull(m.sample_count, 0) sample_count, h.api_retrieval_status, 
	isnull(h.api_status_details, '') api_status_details, 
	isnull(h.api_response_sneak_peek, '') api_response_sneak_peek, h.datetime_stamp
from dw_api_retrieval_history h
	inner join dw_studies s on h.entity_id = s.study_id 
	inner join dw_programs p on s.program_id = p.program_id
	inner join dw_entity_types e on e.entity_type = h.entity_type
	inner join dw_dictionaries d on d.dict_id = s.dict_id
	left join meta_hist m on h.api_retrieval_id = m.sample_retrieval_id
	left outer join dates t on 1 = 1
where h.entity_type = 1
and h.datetime_stamp between t.[beginOfToday] and t.[beginOfTomorrow] --select records from yesterday


GO
