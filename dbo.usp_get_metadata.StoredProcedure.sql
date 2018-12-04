USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--usp_get_metadata 1,1 

CREATE proc [dbo].[usp_get_metadata]
	@program_id int, 
	@study_id int
as
	Begin 

	Declare @sql as varchar (max)
	declare @key_list varchar (max) = ''

	--declare @topRecToAnalyze int

	--set @topRecToAnalyze = cast(dbo.udf_get_config_value(@study_id, 'top_recs_for_json_structure') as int)

	If exists (select top 1 * from dw_metadata where program_id = @program_id and study_id = @study_id)
	Begin --proceed here if some data is present for the passed study id
		
		--get list of keys
		;with tb_data as (
		select top (cast(dbo.udf_get_config_value(@study_id, 'top_recs_for_json_structure') as int)) sample_data 
		from dw_metadata --json_values 
		where program_id = @program_id and study_id = @study_id
		)
		,key_list as 
		(
		select distinct t2.[key]
		from tb_data t1
		CROSS APPLY 
		OPENJSON (t1.sample_data) t2
		)
		--select * from key_list -- for testing only
		Select @key_list = @key_list + isnull([key],'') + ' ' + dbo.udf_get_config_value(@study_id, 'default_value_type') + ',' --' varchar (200), '  
		from key_list

		set @key_list = left(@key_list, len(@key_list) - 1)
	--Print @key_list --for testing only
	
		--generic Select statement template
		set @sql = 'Select jst.program_id, p.program_name, jst.study_id, s.study_name, jst.sample_retrieval_id as sample_id, jsf.* 
		from dw_metadata jst
		inner join dw_programs p on jst.program_id = p.program_id
		inner join dw_studies s on jst.study_id = s.study_id
		CROSS APPLY 
		OPENJSON (jst.sample_data) 
		with ({field_list}) as jsf'

		set @sql = REPLACE (@sql, '{field_list}', @key_list)
Print @sql --for testing only

		exec (@sql) --output select statement
	End
	
	Else

	Begin --proceed here if no data is present for the passed study id
		select program_id, study_id, sample_id from dw_metadata where program_id = @program_id and study_id = @study_id
	End

	End
GO
