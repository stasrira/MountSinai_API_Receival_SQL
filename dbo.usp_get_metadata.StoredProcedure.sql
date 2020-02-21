USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
1) First way to execute - 
exec usp_get_metadata 1 --existing study
exec usp_get_metadata 4 --not existing study
exec usp_get_metadata 4, '', 1 --not existing study
exec usp_get_metadata 7

--Get only specified sample ids
exec usp_get_metadata @study_id = 1, @sample_ids = '99920015501, 99920015801,  80000885506,80000885507'
exec usp_get_metadata @study_id = 2, @sample_ids = '99920015501, 99920015801,  80000885506,80000885507'

2) Second way to execute -
create table #stas1 ([#stas1] int)
exec usp_get_metadata 3, '#stas1'
select * from #stas1
drop table #stas1
*/
CREATE proc [dbo].[usp_get_metadata]
	@study_id int
	,@tb_out_name varchar (30) = ''
	,@friendly_no_data int = 0 --0: will return an empty dataset, 1: will return one row with a message - "No data found"
	,@sample_ids varchar (max) = '' --contains list of Sample Ids that are required to be returned; if not blank, only these ids will be passed into the output
	,@sample_delim varchar (4) = ',' -- delimiter of the sample ids in the @sample_ids variable 
as
	Begin 

	SET NOCOUNT ON

	Declare @sql as varchar (max);
	declare @key_list varchar (max) = ''; --, @str_tb_out varchar (max) = ''
	declare @select_list1 varchar (max) = '', @select_list2 varchar (max) = '', @inner_join_list varchar (max) = '', @sample_id_filter varchar (max);
	declare @def_field_type varchar (50), @encoding_val varchar (50);
	declare @dict_id int;
	declare @tb_keys table (keyN varchar (200));
	declare @str varchar (max) = '';
	declare @temp_tb_name varchar (50) = newid();
	declare @topRecToAnalyze int

	If exists (select top 1 * from dw_metadata where study_id = @study_id) --program_id = @program_id and 
	Begin --proceed here if some data is present for the passed study id
	
		--=========== Retrieve Dictionary directly from JSON string
		
		select @dict_id = dict_id from dw_studies where study_id = @study_id --identify dictionary to be used with this study

		create table #tmp_dict (
			fieldName varchar (150),
			fieldDesc varchar (200),
			fieldlabel varchar (150),
			fieldType varchar (30),
			fieldCode int,
			fieldValue varchar (200)
		)

		--This creates a dynamic statement to open JSON containing dictionary fields 
		--This created as a dynamic statement because SQL Server 2016 does not allow pass variables for Path parameter of the OpenJson functions. This is not an issue in 2017 version.
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

			set @topRecToAnalyze = isnull(
									cast(dbo.udf_get_config_value(@study_id, 1, 'top_recs_for_json_structure') as int), --config value is set for this study, read it from there
									(select count(*) from dw_metadata where study_id = @study_id) --if no config value supply count of all rows for the study as "top" value (all records will be analyzed)
									)

--set @topRecToAnalyze = 1000 --for testing only
--print '@topRecToAnalyze = ' + cast (isnull(@topRecToAnalyze, 'NULL') as varchar (10)) --for testing only

			--get list of keys
			;with tb_data as (
			--select top (cast(dbo.udf_get_config_value(@study_id, 1, 'top_recs_for_json_structure') as int)) sample_data 
			select top (@topRecToAnalyze) sample_data 
			from dw_metadata --json_values 
			where study_id = @study_id --program_id = @program_id and 
			)
			,key_list as 
			(
			select distinct t2.[key]
			from tb_data t1
			CROSS APPLY 
			OPENJSON (t1.sample_data) t2
			)
			--select * from key_list -- for testing only
			insert into @tb_keys (keyN)
			select [key] from key_list 

--select * from @tb_keys --for testing only

			select @def_field_type = isnull(dbo.udf_get_config_value(@study_id, 1, 'default_value_type'), dbo.udf_get_config_value(1, 99, 'default_value_type')) --get set config value, but if nothing is provided use varchar (200) as default
			select @encoding_val = isnull(dbo.udf_get_config_value(@dict_id, 2, 'encoding_val'), dbo.udf_get_config_value(1, 99, 'encoding_val'))

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

			set @key_list = left(@key_list, len(@key_list) - 1)

--Print 'Key list done'
			set @select_list1 = left(@select_list1, len(@select_list1) - 1)
--Print 'select list done'

--Print '@key_list = ' + isnull(@key_list, 'NULL') --for testing only
--print '@str_tb_out = ' + @str_tb_out --for testing only
--print '@inner_join_list = ' + isnull(@inner_join_list, 'NULL')
--print '@select_list1 = ' + isnull(@select_list1, 'NULL')
--print '@select_list2 = ' + isnull(@select_list2, 'NULL')
			
			set @sample_id_filter = '' --default state of the variable

			if len(ltrim(rtrim(@sample_ids))) > 0 
				Begin
				--prepare a condition to filter records based on the given list of sample_ids
				--declare @t_sids as table (sample_id varchar (100)); --this table will hold split list of submitted MIDs
				--Insert into @t_sids (sample_id)
				;with sids as (
					SELECT ltrim(rtrim(value)) as sample_id 
					FROM STRING_SPLIT(isnull(@sample_ids,''), @sample_delim)
					)
				Select @sample_id_filter = @sample_id_filter + ',''' + sample_id + ''''
				From sids

				--print @sample_id_filter
				--print STUFF(@sample_id_filter, 1,1,'')
								
				set @sample_id_filter = ' and jst.sample_id in (' + STUFF(@sample_id_filter, 1,1,'') + ') '

				End

			--generic Select statement template
			set @sql = '
			with tb_data 
			as (
				Select p.program_id, p.program_name, jst.study_id, s.study_name, 
				isnull(a.assay_code, '''') assay_code, isnull(a.assay_name, '''') assay_value,
				jst.sample_id, jst.sample_retrieval_id, jsf.* 
				from dw_metadata jst
				inner join dw_studies s on jst.study_id = s.study_id
				inner join dw_programs p on s.program_id = p.program_id
				left join dw_assays a on jst.assay_code = a.assay_code
				CROSS APPLY 
				OPENJSON (jst.sample_data) 
				with ({field_list}) as jsf
				where jst.study_id = ' + cast (@study_id as varchar (20)) + '
				{sample_id_filter}
			)
			select t.program_id, t.program_name, t.study_id, t.study_name, t.assay_code, t.assay_value, t.sample_id, {select_list}'
			+ iif (len(ltrim(rtrim(@tb_out_name)))>0, ' into [' + @temp_tb_name + '] ' , '') + 
			' from tb_data t 
			{inner_join}
			'

			set @sql = REPLACE (@sql, '{field_list}', @key_list)
			set @sql = REPLACE (@sql, '{select_list}', @select_list1 + @select_list2)
			set @sql = REPLACE (@sql, '{inner_join}', @inner_join_list)
			set @sql = REPLACE (@sql, '{sample_id_filter}', @sample_id_filter ) -- @sample_id_filter

--Print @sql --for testing only

--Print '------->> Executing @sql now!'

			exec (@sql) --execute the script to output the select statement into a temp table

	End
	
	Else

	Begin --proceed here if no data is present for the passed study id
		if @friendly_no_data = 1 
			Begin
			set @sql ='select ' + cast (@study_id as varchar (20)) + 'as study_id, ''No metadata found for this study id!'' as study_name'
			End
		else
			Begin
			set @sql = 
			'select m.study_id, s.study_name, m.sample_id '
			+ iif (len(ltrim(rtrim(@tb_out_name)))>0, ' into [' + @temp_tb_name + '] ' , '') +
			' from dw_metadata m
			inner join dw_studies s on m.study_id = s.study_id
			where m.study_id = ' + cast (@study_id as varchar (20))
			End

		

--print @sql; --for testing only

		exec (@sql) --execute the script to output the select statement into a temp table

	End

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
