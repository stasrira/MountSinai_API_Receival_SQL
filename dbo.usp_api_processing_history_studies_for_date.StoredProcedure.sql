USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--usp_api_processing_history_studies_for_date '12/14/2018' 
--usp_api_processing_history_studies_for_date '11/28/2018'
CREATE proc [dbo].[usp_api_processing_history_studies_for_date]
@date as datetime = Null
as

--assign default date as Today
if @date is null 
	Begin 
	set @date = getdate();
	End

;with dates as (
	select  
	--DATEADD(day, DATEDIFF(day, 0, @date), -1) [beginOfYesterday],
	DATEADD(day, DATEDIFF(day, 0, @date), 0) [beginOfToday]
	, DATEADD(day, DATEDIFF(day, 0, @date + 1 ), 0) [beginOfTomorrow]
	)
	,meta_hist as (
	--get stat info from DW_metadata 
	select m.study_id, m.sample_retrieval_id, m.process_status, count (*) as total_records_received_for_period
	from dw_metadata_modification_log m
	left outer join dates t on 1 = 1
	where m.datetime_stamp between t.[beginOfToday] and t.[beginOfTomorrow] --select records from the current date
	Group by m.study_id, m.sample_retrieval_id, m.process_status
	)
	--,meta_hist2 as (
	--select study_id, sample_retrieval_id, count (*) as total_records_received_for_period, 
	--	--this will concatenate different values of the [process_status] field into a string
	--	STUFF(
	--		(
	--		Select ',' + process_status
	--		from dw_metadata_modification_log m
	--			left outer join dates t on 1 = 1
	--		where m.datetime_stamp between t.[beginOfToday] and t.[beginOfTomorrow] --this where condition must be in sync with the where condition of the main query
	--		group by process_status
	--		FOR XML PATH ('')
	--		),1,1,'') as all_statuses
	--from dw_metadata_modification_log m
	--left outer join dates t on 1 = 1
	--where m.datetime_stamp between t.[beginOfToday] and t.[beginOfTomorrow] --select records from the current date
	--Group by m.study_id, m.sample_retrieval_id
	--)
	,hist_retrieval as (
	select h.api_retrieval_id, h.api_retrieval_status, 
		isnull(h.api_status_details, '') api_status_details,
		count (*) as retrieval_attempts 
		--isnull(h.api_response_sneak_peek, '') api_response_sneak_peek --, h.datetime_stamp
	from dw_api_retrieval_history h
	left outer join dates t on 1 = 1
	where h.entity_type = 1
	and h.datetime_stamp between t.[beginOfToday] and t.[beginOfTomorrow] --select records from the current date
	Group by h.api_retrieval_id, h.api_retrieval_status, h.api_status_details
	)
select isnull(s.study_name, 'No Name') study_name, 
	isnull(p.program_name, 'No Name') program_name, 
	h.api_retrieval_id, h.api_retrieval_status, h.api_status_details, 
	h.retrieval_attempts, 
	isnull(m.total_records_received_for_period, 0) records_received_for_period, 
	isnull(m.process_status, '') process_status,
	beginOfToday period_start, beginOfToday period_end 
from hist_retrieval h 
left join meta_hist m on h.api_retrieval_id = m.sample_retrieval_id
left join dw_studies s on m.study_id = s.study_id 
left join dw_programs p on s.program_id = p.program_id
left outer join dates t on 1 = 1
order by study_name, api_retrieval_id
	

GO
