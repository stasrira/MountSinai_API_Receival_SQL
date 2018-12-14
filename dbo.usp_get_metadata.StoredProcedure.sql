USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--exec usp_get_metadata 1 
CREATE proc [dbo].[usp_get_metadata]
	@study_id int
as
	Begin 

	Declare @sql as varchar (max);
	declare @key_list varchar (max) = ''; --, @str_tb_out varchar (max) = ''
	declare @select_list1 varchar (max) = '', @select_list2 varchar (max) = '', @inner_join_list varchar (max) = '';
	declare @def_field_type varchar (50), @encoding_val varchar (50);
	declare @dict_id int;
	declare @tb_keys table (keyN varchar (200));
	declare @str varchar (max) = '';

	--declare @topRecToAnalyze int

	--set @topRecToAnalyze = cast(dbo.udf_get_config_value(@study_id, 'top_recs_for_json_structure') as int)
	If exists (select top 1 * from dw_metadata where study_id = @study_id) --program_id = @program_id and 
	Begin --proceed here if some data is present for the passed study id
		
		--=========== Retrieve Dictionary directly from JSON string
		
		select @dict_id = dict_id from dw_studies where study_id = @study_id --identify dictionary to be used with this study

		create table #tmp_dict (
			fieldName varchar (50),
			fieldDesc varchar (200),
			fieldlabel varchar (50),
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
			select [key], [value] from OpenJson ((select dict_json from dict_for_study), ''' + dbo.udf_get_config_value(@dict_id, 2, 'dictionary_path') + ''') --''$.field''
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
			OPENJSON (jst.[value], ''' + dbo.udf_get_config_value(@dict_id, 2, 'encoding_path') + ''') --''$.encoding''
			with (
			[code] varchar (200), 
			[value] varchar (200)
			) as jsf1
		'
--Print @str --for testing only
		exec (@str)

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

			--get list of keys
			;with tb_data as (
			select top (cast(dbo.udf_get_config_value(@study_id, 1, 'top_recs_for_json_structure') as int)) sample_data 
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

			select @def_field_type = dbo.udf_get_config_value(@study_id, 1, 'default_value_type')
			select @encoding_val = dbo.udf_get_config_value(@dict_id, 2, 'encoding_val')

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
					t.[' + isnull(keyN,'') + '] as ' + isnull(keyN,'') + ',' 
			from @tb_keys k 
			inner join dict_data d on k.keyN = d.fieldName

			--prepare SQL string for 'Select' (list of fields) and 'From' (inner joins) clauses
			;with dict_data as (
				select fieldName, fieldType
				from #tmp_dict 
				where fieldtype = @encoding_val --'enum'
				group by fieldName, fieldType
			)
			Select 
					@inner_join_list = @inner_join_list + 
					'
					inner join #tmp_dict t' + cast(row_number() OVER(ORDER BY keyN ASC) as varchar (20)) + 
					' on t.[' + isnull(keyN,'') + '] = t' + cast(row_number() OVER(ORDER BY keyN ASC) as varchar (20)) + '.fieldCode ' + 
					' and t' + cast(row_number() OVER(ORDER BY keyN ASC) as varchar (20)) + '.fieldName = ''' + isnull(keyN,'') + ''''
					,@select_list2 = @select_list2 + 
					'
					,t.[' + isnull(keyN,'') + '] as ' + isnull(keyN,'') + '_code,' + 
					't' + cast(row_number() OVER(ORDER BY keyN ASC) as varchar (20)) + '.fieldValue as ' + isnull(keyN,'') + '_value'
			from @tb_keys k 
			inner join dict_data d on k.keyN = d.fieldName

--print '@select_list1' + isnull (@select_list1, 'EMPTY')
--print @select_list2

			set @key_list = left(@key_list, len(@key_list) - 1)

--Print 'Key list done'
			set @select_list1 = left(@select_list1, len(@select_list1) - 1)
--Print 'select list done'

--Print @key_list --for testing only
		--print @str_tb_out --for testing only
--print @inner_join_list
--print @select_list1
--print @select_list2

			--generic Select statement template
			set @sql = '
			with tb_data 
			as (
				Select p.program_id, p.program_name, jst.study_id, s.study_name, jst.sample_retrieval_id, jsf.* 
				from dw_metadata jst
				inner join dw_studies s on jst.study_id = s.study_id
				inner join dw_programs p on s.program_id = p.program_id
				CROSS APPLY 
				OPENJSON (jst.sample_data) 
				with ({field_list}) as jsf
			)
			select t.program_id, t.program_name, t.study_id, t.study_name, {select_list}
			from tb_data t 
			{inner_join}
			'

			set @sql = REPLACE (@sql, '{field_list}', @key_list)
			set @sql = REPLACE (@sql, '{select_list}', @select_list1 + @select_list2)
			set @sql = REPLACE (@sql, '{inner_join}', @inner_join_list)

Print @sql --for testing only

			exec (@sql) --output select statement

			--select * from #tb_out

	End
	
	Else

	Begin --proceed here if no data is present for the passed study id
		select study_id, sample_id from dw_metadata where study_id = @study_id --program_id = @program_id and 
	End

	IF OBJECT_ID('tempdb..#tmp_dict') IS NOT NULL DROP TABLE #tmp_dict

	End
GO
