USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*
1) First way to execute - 
exec usp_get_manifest_data 

--Get only specified sample ids or study ids
exec usp_get_manifest_data @aliquot_ids = 'AS06-11984'
exec usp_get_manifest_data @study_id = 7, @aliquot_ids = 'AS06-11984'

--Specify a particular dictionary to use
exec usp_get_manifest_data @aliquot_ids = 'AS06-11984', @dictionary_id = 12

2) Second way to execute -
create table #stas1 ([#stas1] int)
exec usp_get_manifest_data @aliquot_ids = 'AS06-11984', @tb_out_name = '#stas1'
select * from #stas1
drop table #stas1
*/
CREATE proc [dbo].[usp_get_manifest_data]
	@aliquot_ids varchar (max) = '' --contains list of Aliquot Ids that are required to be returned; if not blank, only these ids will be passed into the output
	,@tb_out_name varchar (30) = ''
	,@friendly_no_data int = 0 --0: will return an empty dataset, 1: will return one row with a message - "No data found"
	,@aliquot_delimiter varchar (4) = ',' -- delimiter of the sample ids in the @aliquot_ids variable 
	,@dictionary_id int = Null
	,@study_id int = Null
as
	Begin 

	SET NOCOUNT ON

	Declare @sql as varchar (max);
	declare @key_list varchar (max) = ''; --, @str_tb_out varchar (max) = ''
	declare @select_list1 varchar (max) = '', @select_list2 varchar (max) = '', @inner_join_list varchar (max) = '' 
	declare @aliquot_id_filter varchar (max) = '', @study_id_filter varchar (200) = ''
	declare @def_field_type varchar (50), @encoding_val varchar (50);
	declare @dict_id int;
	declare @tb_keys table (keyN varchar (200));
	declare @str varchar (max) = '';
	declare @temp_tb_name varchar (50) = newid();
	declare @topRecToAnalyze int

	if not exists (select * from dw_aliquot_manifests)
		--if no records available in the dw_aliquot_manifests table, exit the proc returning an empty dataset
		Begin
		Select 
		p.program_id, p.program_name, 
		jst.study_id, s.study_name, 
		jst.aliquot_id as aliquot_id_DB, 
		jst.sample_id as sample_id_DB
		--, jst.manifest_data
		from dw_aliquot_manifests jst
		inner join dw_studies s on jst.study_id = s.study_id
		inner join dw_programs p on s.program_id = p.program_id

		return
		End

	--=========== Retrieve Dictionary directly from JSON string
	if @dictionary_id is Null
		Begin
		select top 1 @dict_id = dict_id from dw_dictionaries where dict_name = 'Aliquot Manifest Metadata'
		End
	else
		Begin
		select @dict_id = @dictionary_id
		End

	create table #tmp_dict (
		fieldName varchar (150),
		fieldDesc varchar (200),
		fieldlabel varchar (150),
		fieldType varchar (30),
		fieldCode int,
		fieldValue varchar (200)
	)

	--This creates a dynamic statement to open JSON containing dictionary fields 
	--This created as a dynamic statement because SQL Server 2016 does not allow passing variables for Path parameter of the OpenJson functions. This is not an issue in 2017 version.
	set @str = 
	'
	;with dict_for_study as (
		--get dictionary json for a given study
		select dict_json 
		from dw_dictionaries d 
		where d.dict_id = ' + cast (@dict_id as varchar(20)) + '
	)
	,json_tb as (
		--split dict json string to a table with separate json string for each dict field
		select [key], [value] from OpenJson ((select dict_json from dict_for_study), ''' 
		+ isnull(dbo.udf_get_config_value(@dict_id, 2, 'dictionary_path'), dbo.udf_get_config_value(1, 99, 'default_dictionary_path')) + 
		''') --''$.field''
	)
	insert into #tmp_dict --insert dictionary map to a temp table
	--convert dictionary field map into a regular table structure
	Select 
	jsf.*, jsf1.*
	from json_tb jst
	CROSS APPLY 
		OPENJSON (jst.[value], ''$'') --refer to the root of the given JSON array of dictionary fields
		with (
		[name] varchar (200) ,
		[description] varchar (200), 
		label varchar (50), 
		[type] varchar (50)
		) as jsf
	outer APPLY 
		OPENJSON (jst.[value], ''' 
		--+ dbo.udf_get_config_value(@dict_id, 2, 'encoding_path') + 
		+ isnull(dbo.udf_get_config_value(@dict_id, 2, 'encoding_path'), dbo.udf_get_config_value(1, 99, 'default_encoding_path')) +
		''') --''$.encoding''
		with (
		[code] varchar (200), 
		[value] varchar (200)
		) as jsf1
	'
--Print @str --for testing only

	exec (@str)

--select * from #tmp_dict -- for testing only

	/*--original code that works in SQL Server 2017
	;with dict_for_study as (
		--get dictionary json for a given study
		select dict_json 
		from dw_dictionaries d 
		where d.dict_id = @dict_id
	)
	,json_tb as (
		--split dict json string to a table with separate json string for each dict field
		select [key], [value] from OpenJson ((select dict_json from dict_for_study), dbo.udf_get_config_value(@dict_id, 2, 'dictionary_path')) --'$.field'
	)
	insert into #tmp_dict --insert dictionary map to a temp table
	--convert dictionary field map into a regular table structure
	Select 
	jsf.*, jsf1.*
	from json_tb jst
	CROSS APPLY 
		OPENJSON (jst.[value], '$') --refer to the root of the given JSON array of dictionary fields
		with (
		[name] varchar (200) ,
		[description] varchar (200), 
		label varchar (50), 
		[type] varchar (50)
		) as jsf
	outer APPLY 
		OPENJSON (jst.[value], dbo.udf_get_config_value(@dict_id, 2, 'encoding_path')) --'$.encoding'
		with (
		[code] varchar (200), 
		[value] varchar (200)
		) as jsf1
	*/

	set @str = 'create clustered index idx_' + replace(newid(),'-','') + '_1 on #tmp_dict (fieldName, fieldCode, fieldType)';
--print @str; --for testing only
	exec (@str);

	--set @topRecToAnalyze = (select count(*) from dw_aliquot_manifests where study_id = @study_id) --if no config value supply count of all rows for the study as "top" value (all records will be analyzed)

--set @topRecToAnalyze = 1000 --for testing only
--print '@topRecToAnalyze = ' + cast (isnull(@topRecToAnalyze, 'NULL') as varchar (10)) --for testing only

	--get list of keys
	;with tb_data as (
	--select top (@topRecToAnalyze) sample_data 
	select manifest_data 
	from dw_aliquot_manifests --json_values 
	where not manifest_data is null
	)
	,key_list as 
	(
	select distinct t2.[key]
	from tb_data t1
	CROSS APPLY 
	OPENJSON (t1.manifest_data) t2
	)
	--select * from key_list -- for testing only
	insert into @tb_keys (keyN)
	select [key] from key_list 

--select * from @tb_keys --for testing only

	select @def_field_type = dbo.udf_get_config_value(1, 99, 'default_value_type') 
	select @encoding_val = dbo.udf_get_config_value(1, 99, 'encoding_val')

--print '@def_field_type = ' + isnull(@def_field_type, 'NULL')
--print '@encoding_val = ' + isnull(@encoding_val, 'NULL')

	Select 
		--prepare SQL string for "With" clause of the OpenJson statement 
		@key_list = @key_list + '[' + isnull(keyN,'') + '] ' + @def_field_type + ',' --' varchar (200), '  
		--, @str_tb_out = @str_tb_out + '; alter table #tb_out add ' + '[' + isnull(keyN,'') + '] ' + @def_field_type
	from @tb_keys

	--prepare SQL string for 'Select' (list of fields) and 'From' (inner joins) clauses
	;with dict_data as (
		select fieldName, fieldType
		from #tmp_dict 
		where fieldtype <> @encoding_val --'enum'
		group by fieldName, fieldType
	)
	Select 
			@select_list1 = @select_list1 + 
			'
			isnull(t.[' + isnull(keyN,'') + '], '''') as [' + isnull(keyN,'') + '],' 
	from @tb_keys k 
	inner join dict_data d on k.keyN = d.fieldName

	--prepare SQL string for 'Select' (list of fields) and 'From' (inner joins) clauses
	;with dict_data as (
		select fieldName, fieldType
		from #tmp_dict 
		where fieldtype = @encoding_val --'enum'
		group by fieldName, fieldType
	)
	Select --instead of "inner" join "left" one will be used to make sure that records shown even for records that have incorrect codes assigned.
			@inner_join_list = @inner_join_list + 
			'
			left join #tmp_dict t' + cast(row_number() OVER(ORDER BY keyN ASC) as varchar (20)) + 
			' on t.[' + isnull(keyN,'') + '] = t' + cast(row_number() OVER(ORDER BY keyN ASC) as varchar (20)) + '.fieldCode ' + 
			' and t' + cast(row_number() OVER(ORDER BY keyN ASC) as varchar (20)) + '.fieldName = ''' + isnull(keyN,'') + ''''
			,@select_list2 = @select_list2 + 
			'
			,t.[' + isnull(keyN,'') + '] as [' + isnull(keyN,'') + '_code],' + 
			'isnull(t' + cast(row_number() OVER(ORDER BY keyN ASC) as varchar (20)) + '.fieldValue, '''') as [' + isnull(keyN,'') + '_value]'
			--'t' + cast(row_number() OVER(ORDER BY keyN ASC) as varchar (20)) + '.fieldValue as ' + isnull(keyN,'') + '_value' --original line of code
	from @tb_keys k 
	inner join dict_data d on k.keyN = d.fieldName

--print '@select_list1 = ' + isnull (@select_list1, 'EMPTY')
--print '@select_list2 = ' + @select_list2
	
	if len(isnull(@key_list, '')) > 0
		set @key_list = left(@key_list, len(@key_list) - 1)
	else 
		set @key_list = ''

	if len(isnull(@select_list1, '')) > 0
		set @select_list1 = left(@select_list1, len(@select_list1) - 1)
	else 
		set @select_list1 = ''

--Print '@key_list = ' + isnull(@key_list, 'NULL') --for testing only
----print '@str_tb_out = ' + @str_tb_out --for testing only
--print '@inner_join_list = ' + isnull(@inner_join_list, 'NULL')
--print '@select_list1 = ' + isnull(@select_list1, 'NULL')
--print '@select_list2 = ' + isnull(@select_list2, 'NULL')

	if len(ltrim(rtrim(@aliquot_ids))) > 0 
		Begin
		--prepare a condition to filter records based on the given list of sample_ids
		--declare @t_sids as table (sample_id varchar (100)); --this table will hold split list of submitted MIDs
		--Insert into @t_sids (sample_id)
		;with sids as (
			SELECT ltrim(rtrim(value)) as sample_id 
			FROM STRING_SPLIT(isnull(@aliquot_ids,''), @aliquot_delimiter)
			)
		Select @aliquot_id_filter = @aliquot_id_filter + ',''' + sample_id + ''''
		From sids
--print '#1 - @aliquot_id_filter = ' + isnull(@aliquot_id_filter, 'NULL') --for testing only
		set @aliquot_id_filter = ' and jst.aliquot_id in (' + STUFF(@aliquot_id_filter, 1,1,'') + ') '
--print '#2 - @aliquot_id_filter = ' + isnull(@aliquot_id_filter, 'NULL') --for testing only
		End
	else
		select @aliquot_id_filter = ''

--print '#Final - @aliquot_id_filter = ' + isnull(@aliquot_id_filter, 'NULL') --for testing only

	if not @study_id is null
		Begin
		select @study_id_filter = @study_id_filter + ' and jst.study_id = ' + cast (@study_id as varchar(10))
		--print 'study_id => if part'
		end
	else
		begin
		select @study_id_filter = ''
		--print 'study_id => else part'
		end
			
	--generic Select statement template
	set @sql = '
	with data_source_groupped as(
		select sample_id, aliquot_id, max(datetimestamp) as datetimestamp_latest 
		from dw_source_aliquot_mapping
		group by sample_id, aliquot_id
		)
	,data_source_latest as (
		select ds.*, dd.source_name, source_desc
		from dw_source_aliquot_mapping ds 
		inner join data_source_groupped dg on ds.sample_id = dg.sample_id and ds.aliquot_id = dg.aliquot_id and ds.datetimestamp = dg.datetimestamp_latest
		inner join dw_data_sources dd on dd.source_id = ds.source_id
	)
	,tb_data as (
		Select 
		p.program_id, p.program_name, 
		jst.study_id, s.study_name, 
		jst.aliquot_id as aliquot_id_DB, 
		jst.sample_id as sample_id_DB, 
		jsf.* 
		,jst.datetime_stamp
		from dw_aliquot_manifests jst
		inner join dw_studies s on jst.study_id = s.study_id
		inner join dw_programs p on s.program_id = p.program_id
		CROSS APPLY 
		OPENJSON (jst.manifest_data) 
		with ({field_list}) as jsf
		where 1 = 1
		{sample_id_filter}
		{study_id_filter}
	)
	select 
	t.aliquot_id_DB, t.sample_id_DB,
	t.program_id, t.program_name, 
	t.study_id, t.study_name 
	{select_list}
	, t.datetime_stamp as loaded_to_DB
	, ds.source_name as loaded_from_source '
	+ iif (len(ltrim(rtrim(@tb_out_name)))>0, ' into [' + @temp_tb_name + '] ' , '') + 
	' from tb_data t 
	left join data_source_latest ds on t.sample_id_DB = ds.sample_id and t.aliquot_id_DB = ds.aliquot_id
	{inner_join}
	'

	--jst.study_id = ' + cast (@study_id as varchar (20)) + '
--print '#1 - @sql = ' + isnull(@sql, 'NULL') --for testing only
	set @sql = REPLACE (@sql, '{field_list}', @key_list)
--print '#2 - @sql = ' + isnull(@sql, 'NULL') --for testing only
	set @sql = iif(len(@select_list1 + @select_list2) > 0, 
				REPLACE (@sql, '{select_list}', ', ' + @select_list1 + @select_list2),
				REPLACE (@sql, '{select_list}', '')
				)
--print '#3 - @sql = ' + isnull(@sql, 'NULL') --for testing only
	set @sql = REPLACE (@sql, '{inner_join}', @inner_join_list)
print '#4 - @sql = ' + isnull(@sql, 'NULL') --for testing only
	set @sql = REPLACE (@sql, '{sample_id_filter}', @aliquot_id_filter ) -- @aliquot_id_filter
print '#5 - @sql = ' + isnull(@sql, 'NULL') --for testing only
--print '@study_id_filter = ' + isnull(@study_id_filter, 'NULL') --for testing only
	set @sql = REPLACE (@sql, '{study_id_filter}', @study_id_filter ) -- @study_id_filter

print '#Final - @sql = ' + isnull(@sql, 'NULL') --for testing only

--Print '------->> Executing @sql now!'

	exec (@sql) --execute the script to output the select statement into a temp table

--End
	
	If len(ltrim(rtrim(@tb_out_name)))>0 
		Begin --if the temp table name was provided into the input parameter
			select @sql = '', @str = '';
					
			--prepare alter statements to copy metadata table structure into the one passed as a parameter @tb_out_name
			select 
				--c.name, t.name, c.prec 
				@sql = @sql + 'alter table [' + ltrim(rtrim(@tb_out_name)) + '] add [' + c.name + '] ' + t.name + iif(t.name = 'varchar', ' (' + cast(c.prec as varchar (20)) + '); ', '; ') 
				, @str = @str + '[' + c.name + '],'
			from syscolumns c 
			inner join sysobjects o on o.id = c.id 
			inner join systypes t on c.xtype = t.xtype
			where o.name = @temp_tb_name
			order by colid

			set @str = left(@str, len(@str) - 1);

			--preapare script to drop a column of the table that matches the name of the table; this column was passed as temp measure to have some default structure of the table
			set @sql = @sql + 'alter table [' + ltrim(rtrim(@tb_out_name)) + '] drop column [' + ltrim(rtrim(@tb_out_name)) + ']; '
					
--print @sql --for testing only

			exec (@sql) --execute prepared script script
					
			set @sql = ''

			--preapare script to insert all data from a temp table to the output table
			set @sql = @sql + 'insert into [' + ltrim(rtrim(@tb_out_name)) + '] (' + @str + ') select ' + @str + ' from [' + @temp_tb_name + ']; '
			--preapare script to drop the temp table
			set @sql = @sql + 'drop table [' + @temp_tb_name + ']; '

--print @sql --for testing only

			exec (@sql) --execute prepared script script
			
		End




	IF OBJECT_ID('tempdb..#tmp_dict') IS NOT NULL DROP TABLE #tmp_dict

	End
GO
