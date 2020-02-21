USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create view [dbo].[vw_api_processing_history_dictionaries_today]
as
with dates as (
	select  
	--DATEADD(day, DATEDIFF(day, 0, GETDATE()), -1) [beginOfYesterday],
	DATEADD(day, DATEDIFF(day, 0, GETDATE()), 0) [beginOfToday] 
	,DATEADD(day, DATEDIFF(day, 0, GETDATE() + 1 ), 0) [beginOfTomorrow]
	)
select e.entity_type_name, d.dict_name, d.dict_uri, 
	h.api_retrieval_id, h.api_retrieval_status, 
	isnull(h.api_status_details, '') api_status_details, 
	isnull(h.api_response_sneak_peek, '') api_response_sneak_peek, h.datetime_stamp
from dw_api_retrieval_history h
	inner join dw_entity_types e on e.entity_type = h.entity_type
	inner join dw_dictionaries d on d.dict_id = h.entity_id
	left outer join dates t on 1 = 1
where h.entity_type = 2
and h.datetime_stamp between t.[beginOfToday] and t.[beginOfTomorrow]


GO
