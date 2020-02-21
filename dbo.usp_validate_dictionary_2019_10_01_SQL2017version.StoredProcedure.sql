USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
declare @valid_result as varchar (30), @valid_msg varchar (400) 
exec usp_validate_dictionary 2, 
		--'{"field": [{"description": "", "encoding": "null", "label": "Col1", "type": "varchar", "name": "Col1"},{"description": "", "encoding": "null", "label": "Col1", "type": "varchar", "name": "Col1"}, {"description": "", "encoding": "null", "label": "Col2", "type": "varchar", "name": "Col2"}, {"description": "", "encoding": "null", "label": "Col3", "type": "varchar", "name": "Col3"}, {"description": "", "encoding": "null", "label": "Col4", "type": "varchar", "name": "Col4"}]}', 
		'{"field": [{"description": "", "encoding": "null", "label": "Col8", "type": "varchar", "name": "Col8"}, {"description": "", "encoding": "null", "label": "Col2", "type": "varchar", "name": "Col2"}, {"description": "", "encoding": "null", "label": "Col3", "type": "varchar", "name": "Col3"}, {"description": "", "encoding": "null", "label": "Col4", "type": "varchar", "name": "Col4"}]}', 
		--'{"field": [{"description": "", "encoding": "null", "label": "Col1", "type": "varchar", "name": "Col1"}, {"description": "", "encoding": "null", "label": "Col2", "type": "varchar", "name": "Col2"}, {"description": "", "encoding": "null", "label": "Col3", "type": "varchar", "name": "Col3"}, {"description": "", "encoding": "null", "label": "Col4", "type": "varchar", "name": "Col4"}]}', 
		'',
		@valid_result output
		,@valid_msg output
select @valid_result, @valid_msg
*/

CREATE proc [dbo].[usp_validate_dictionary_2019_10_01_SQL2017version]
	@dict_id_cur as int,
	@dict_new_json as varchar (max),
	@dict_path as varchar (200) = '', --path inside of the @dict_new_json leading to the array of fields, i.e. '$.field'
	@valid_result as varchar (30) output,
	@valid_msg as varchar (max) output
as

set nocount on

declare @tb_dict_new as table (name varchar (200))
declare @tb_dict_cur as table (name varchar (200))
--declare @dict_path as varchar (100)
declare @missFields as varchar (4000) = '', @newFields varchar (4000) = ''

--if @dict_path value was not provided, read it from a config file.
if len(trim(@dict_path)) = 0 
	Begin
	select @dict_path = isnull(dbo.udf_get_config_value(@dict_id_cur, 2, 'dictionary_path'), dbo.udf_get_config_value(1, 99, 'default_dictionary_path')) --get config value, but if nothing is provided use default from global config entity --'$.field'
	End

--print @dict_path --for testing only

--get list of columns from new dictionary
insert into @tb_dict_new (name)
select name from OpenJson (@dict_new_json, @dict_path)
with (
		[name] varchar (200)
		)

--select * from @tb_dict_new --for testing only

select 
@valid_msg = 'Duplicated column name "' + name + '", repeated ' + cast(count (*) as varchar (20)) + ' times.'
, @valid_result = 'Failed'
from @tb_dict_new
group by name
having count (*) > 1

If len(trim(@valid_result)) > 0
	--if validation result is not empty, an error happen => break procedure execution
	return

--select @valid_msg --for testing onlyl

--get dictionary information for the current dictionary
create table #dict (
	dict_id int,
	name varchar (50),
	description varchar (200), 
	label varchar (50),
	type varchar (20),
	code int,
	value varchar (200)
	)
Insert into #dict exec usp_get_dictionary @dict_id_cur

--select * from #dict --for testing only

--get list of columns for existing dictionary
insert into @tb_dict_cur (name) select name from #dict
--select * from @tb_dict_cur --for testing only

drop table #dict --delete temp table 

declare @new_cnt as int, @missing_cnt as int

--for testing only == Start ==================
--select c.name name_cur, n.name name_new 
--From @tb_dict_cur c 
--full outer join @tb_dict_new n on c.name = n.name
--for testing only == End ======================

;with dict_comp as (
	--compare columns between saved and new dictionary 
	select 
		1 as temp_id1, --fake templ id
		c.name name_cur, n.name name_new 
	From @tb_dict_cur c 
	full outer join @tb_dict_new n on c.name = n.name
	)
, dict_counts as (
	--get counts of new and missiong fields
	select
		1 as temp_id2, --fake temp id
		count (case when name_cur is null then 1 else null end) as new_cnt, --cur_name_nulls,
		count (case when name_new is null then 1 else null end) as missing_cnt --new_name_nulls
	from dict_comp
)
, dict_all as (
	--combine 2 previous select statements
	Select * from dict_comp a
	full outer join dict_counts b on a.temp_id1 = b.temp_id2
)
--get list of missing and new fields and corresponded counts
select 
	@newFields = @newFields + case when name_cur is null then ', "' + name_new + '"' else '' end
	,@missFields = @missFields + case when name_new is null then ', "' + name_cur + '"' else '' end
	,@new_cnt = new_cnt
	,@missing_cnt = missing_cnt
from dict_all 

--trim leading commas from list of fields
select 
	@newFields = stuff(@newFields, 1, 2, ''), 
	@missFields = stuff(@missFields, 1, 2, '')

--select @newFields as newFields, @new_cnt as newCount, @missFields as missingFields, @missing_cnt as missingCount --for testing only

Select @valid_result = 
	Case
	When @missing_cnt > 0 and @new_cnt = 0 then 'OK'
	When @missing_cnt = 0 and @new_cnt > 0 then 'Update'
	When @missing_cnt = 0 and @new_cnt = 0 then 'OK'
	When @missing_cnt > 0 and @new_cnt > 0 then 'Failed'
	End
	,@valid_msg = 
	Case
	When @missing_cnt > 0 and @new_cnt = 0 then 'Structure is preserved, but ' + cast (@missing_cnt as varchar (10)) + ' field(s) - ' + @missFields + ' - were not supplied.'
	When @missing_cnt = 0 and @new_cnt > 0 then cast (@new_cnt as varchar (10)) + ' new field(s) - ' + @newFields + ' - were identified.'
	When @missing_cnt = 0 and @new_cnt = 0 then 'Structures are in sync.'
	When @missing_cnt > 0 and @new_cnt > 0 then 'New dictionary structure identified. There are ' + cast (@missing_cnt as varchar (10)) + ' missing field(s) - ' + @missFields + ' - and ' + cast (@new_cnt as varchar (10)) + ' new field(s) - ' + @newFields + '.'
	End

Print 'Validation result = ' + @valid_result
Print 'Validation message = ' + @valid_msg
GO
