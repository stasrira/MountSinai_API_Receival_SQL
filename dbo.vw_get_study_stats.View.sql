USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--this view returns all available programs/studies combinations with associated records counts in dw_metadata
CREATE view [dbo].[vw_get_study_stats]
as
with metadata_stats as
	(
	select study_id, count (*) record_count
	from dw_metadata
	group by study_id
	)
select p.program_Name, p.program_id, s.study_Name, s.study_id as [study_id(retrieval_id)], s.dict_id as [dictionary_id] ,isnull(m.record_count, 0) as Records#
from dw_studies s 
inner join dw_programs p on s.program_id = p.program_id
left join metadata_stats m on s.study_id = m.study_id
GO
