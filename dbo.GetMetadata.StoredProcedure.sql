USE [dw_motrpac]
GO
/****** Object:  StoredProcedure [dbo].[GetMetadata]    Script Date: 11/28/2018 4:59:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec GetMetadata
CREATE procedure [dbo].[GetMetadata] (
	@program varchar (50) = 'MoTrPAC', 
	@project varchar (50) = 'Pilot1')
as
	Begin 

	Declare @sql as varchar (max)
	declare @key_list varchar (max) = ''
	declare @topRecToAnalyze int = 1

	--get list of keys
	;with tb_data as (
	select top (@topRecToAnalyze) sample_data_json from json_values 
	)
	--Select @key_list = COALESCE(@key_list + ' varchar (200), ', '') + isnull(t2.[key],'')  from tb_data t1 --@Names = COALESCE(@Names + ', ', '') + Name
	--Select @key_list = @key_list + isnull(t2.[key],'') + ' varchar (200), '  from tb_data t1 --@Names = COALESCE(@Names + ', ', '') + Name
	, key_list as (
	select distinct t2.[key]
	from tb_data t1
	CROSS APPLY 
	OPENJSON (t1.sample_data_json) t2
	)
	--select * from key_list -- for testing only
	Select @key_list = @key_list + isnull([key],'') + ' varchar (200), '  
	from key_list

	set @key_list = left(@key_list, len(@key_list) - 1)
	--select @key_list --for testing only
	
	--generic Select statement template
	set @sql = 'Select jst.sample_id, jsf.* 
	from json_values jst
	CROSS APPLY 
	OPENJSON (jst.sample_data_json) 
	with ({field_list}) as jsf'

	set @sql = REPLACE (@sql, '{field_list}', @key_list)
	--select @sql --for testing only

	exec (@sql) --output select statement

	End
GO
