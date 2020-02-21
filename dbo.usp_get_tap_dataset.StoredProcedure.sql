USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*
1) First way to execute - 
exec usp_get_tap_dataset 1 

2) Second way to execute -
create table #stas1 ([#stas1] int)
exec usp_get_tap_dataset 1, '#stas1'
select * from #stas1
drop table #stas1
*/
CREATE proc [dbo].[usp_get_tap_dataset]
	@study_id int
	--,@assay_id int
	,@tb_out_name varchar (30) = ''
as
	Begin 

	set nocount on

	--for testing only
	--Declare @study_id int = 1, @assay_id int = 1 --for testing only

	Declare @sql as varchar (max);
	declare @key_list varchar (max) = ''; --, @str_tb_out varchar (max) = ''
	declare @select_list1 varchar (max) = '', @select_list2 varchar (max) = '', @inner_join_list varchar (max) = '';
	declare @def_field_type varchar (50), @encoding_val varchar (50);
	declare @dict_id int;
	declare @tb_keys table (keyN varchar (200));
	declare @str varchar (max) = '';
	declare @temp_tb_name varchar (50) = newid();
	declare @assay_gr int;
	declare @tap_gr_1 as varchar (100), @tap_gr_2 as varchar (100), @tap_gr_3 as varchar (100), @tap_gr_4 as varchar (100), @tap_gr_5 as varchar (100), @tap_gr_6 as varchar (100), @tap_gr_7 as varchar (100), @tap_gr_8 as varchar (100), @tap_gr_9 as varchar (100)

--print @temp_tb_name --for testing only

	--declare @topRecToAnalyze int

	--set @topRecToAnalyze = cast(dbo.udf_get_config_value(@study_id, 'top_recs_for_json_structure') as int)

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

	--declare @str varchar (max), @dict_id int;

	--This creates a dynamic statement to open JSON containing dictionary fields 
	--This created as a dynamic statement because SQL Server 2016 does not allow pass variables for Path parameter of the OpenJson functions. This is not an issue in 2017 version.
	--Execution of this statement will populate #tmp_dict table with values
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

	--this adds index to the dictionary table
	set @str = 'create clustered index idx_' + replace(newid(),'-','') + '_1 on #tmp_dict (fieldName, fieldCode, fieldType)';
--print @str; --for testing only
	exec (@str);


	--tap analysis table (dw_tap_setting) is being merged with dictionary to bring descriptoins for the codes used in the dw_tap_setting table
	--the outcome of this statement will be outputed as a recordset or inserted into a temp table (if temp table name was provided)

--declare @str as varchar (max); --for testing only
--declare @study_id int = 1; --for testing only
	--declare @assay_gr int;
	--declare @tap_gr_1 as varchar (100), @tap_gr_2 as varchar (100), @tap_gr_3 as varchar (100), @tap_gr_4 as varchar (100), @tap_gr_5 as varchar (100), @tap_gr_6 as varchar (100), @tap_gr_7 as varchar (100), @tap_gr_8 as varchar (100), @tap_gr_9 as varchar (100)

	select @tap_gr_1 = dbo.udf_get_config_value(@study_id, 1, 'tap_gr_1');
	select @tap_gr_2 = dbo.udf_get_config_value(@study_id, 1, 'tap_gr_2');
	select @tap_gr_3 = dbo.udf_get_config_value(@study_id, 1, 'tap_gr_3');
	select @tap_gr_4 = dbo.udf_get_config_value(@study_id, 1, 'tap_gr_4');
	select @tap_gr_5 = dbo.udf_get_config_value(@study_id, 1, 'tap_gr_5');
	select @tap_gr_6 = dbo.udf_get_config_value(@study_id, 1, 'tap_gr_6');
	select @tap_gr_7 = dbo.udf_get_config_value(@study_id, 1, 'tap_gr_7');
	select @tap_gr_8 = dbo.udf_get_config_value(@study_id, 1, 'tap_gr_8');
	select @tap_gr_9 = dbo.udf_get_config_value(@study_id, 1, 'tap_gr_9');

	select @assay_gr = 
		Case 
			when @tap_gr_1 like '%assay%' then 1
			when @tap_gr_2 like '%assay%' then 2
			when @tap_gr_3 like '%assay%' then 3
			when @tap_gr_4 like '%assay%' then 4
			when @tap_gr_5 like '%assay%' then 5
			when @tap_gr_6 like '%assay%' then 6
			when @tap_gr_7 like '%assay%' then 7
			when @tap_gr_8 like '%assay%' then 8
			when @tap_gr_9 like '%assay%' then 9
		else
			0
		end

	set @str = '
		Select 
			t.tap_id
			,t.study_id 
			' + iif(@tap_gr_1 is not null, ',t.tap_gr_1 as ' + @tap_gr_1 + '_code ', '') + '
			' + iif(@tap_gr_2 is not null, ',t.tap_gr_2 as ' + @tap_gr_2 + '_code ', '') + '
			' + iif(@tap_gr_3 is not null, ',t.tap_gr_3 as ' + @tap_gr_3 + '_code ', '') + '
			' + iif(@tap_gr_4 is not null, ',t.tap_gr_4 as ' + @tap_gr_4 + '_code ', '') + '
			' + iif(@tap_gr_5 is not null, ',t.tap_gr_5 as ' + @tap_gr_5 + '_code ', '') + '
			' + iif(@tap_gr_6 is not null, ',t.tap_gr_6 as ' + @tap_gr_6 + '_code ', '') + '
			' + iif(@tap_gr_7 is not null, ',t.tap_gr_7 as ' + @tap_gr_7 + '_code ', '') + '
			' + iif(@tap_gr_8 is not null, ',t.tap_gr_8 as ' + @tap_gr_8 + '_code ', '') + '
			' + iif(@tap_gr_9 is not null, ',t.tap_gr_9 as ' + @tap_gr_9 + '_code ', '') + '
			,t.sample_count
			,s.study_name 
			' + iif(@tap_gr_1 is not null, ',t_gr1.'+ iif(@assay_gr = 1, 'assay_name', 'fieldValue') + ' as ' + @tap_gr_1 + '_value', '') + '
			' + iif(@tap_gr_2 is not null, ',t_gr2.'+ iif(@assay_gr = 2, 'assay_name', 'fieldValue') + ' as ' + @tap_gr_2 + '_value', '') + '
			' + iif(@tap_gr_3 is not null, ',t_gr3.'+ iif(@assay_gr = 3, 'assay_name', 'fieldValue') + ' as ' + @tap_gr_3 + '_value', '') + '
			' + iif(@tap_gr_4 is not null, ',t_gr4.'+ iif(@assay_gr = 4, 'assay_name', 'fieldValue') + ' as ' + @tap_gr_4 + '_value', '') + '
			' + iif(@tap_gr_5 is not null, ',t_gr5.'+ iif(@assay_gr = 5, 'assay_name', 'fieldValue') + ' as ' + @tap_gr_5 + '_value', '') + '
			' + iif(@tap_gr_6 is not null, ',t_gr6.'+ iif(@assay_gr = 6, 'assay_name', 'fieldValue') + ' as ' + @tap_gr_6 + '_value', '') + '
			' + iif(@tap_gr_7 is not null, ',t_gr7.'+ iif(@assay_gr = 7, 'assay_name', 'fieldValue') + ' as ' + @tap_gr_7 + '_value', '') + '
			' + iif(@tap_gr_8 is not null, ',t_gr8.'+ iif(@assay_gr = 8, 'assay_name', 'fieldValue') + ' as ' + @tap_gr_8 + '_value', '') + '
			' + iif(@tap_gr_9 is not null, ',t_gr9.'+ iif(@assay_gr = 9, 'assay_name', 'fieldValue') + ' as ' + @tap_gr_9 + '_value', '') + 
			iif (len(ltrim(rtrim(@tb_out_name)))>0, ' into [' + @temp_tb_name + '] ' , '') +
		'from dw_tap_settings t
			inner join dw_studies s on t.study_id = s.study_id
			' + iif(@tap_gr_1 is not null, 'left join '+ iif(@assay_gr = 1, 'dw_assays', '#tmp_dict') + ' t_gr1 on t.tap_gr_1 = t_gr1.'+ iif(@assay_gr = 1, 'assay_code', 'fieldCode and t_gr1.fieldName = ''' + @tap_gr_1 + '''') , '') + '
			' + iif(@tap_gr_2 is not null, 'left join '+ iif(@assay_gr = 2, 'dw_assays', '#tmp_dict') + ' t_gr2 on t.tap_gr_2 = t_gr2.'+ iif(@assay_gr = 2, 'assay_code', 'fieldCode and t_gr2.fieldName = ''' + @tap_gr_2 + '''') , '') + '
			' + iif(@tap_gr_3 is not null, 'left join '+ iif(@assay_gr = 3, 'dw_assays', '#tmp_dict') + ' t_gr3 on t.tap_gr_3 = t_gr3.'+ iif(@assay_gr = 3, 'assay_code', 'fieldCode and t_gr3.fieldName = ''' + @tap_gr_3 + '''') , '') + '
			' + iif(@tap_gr_4 is not null, 'left join '+ iif(@assay_gr = 4, 'dw_assays', '#tmp_dict') + ' t_gr4 on t.tap_gr_4 = t_gr4.'+ iif(@assay_gr = 4, 'assay_code', 'fieldCode and t_gr4.fieldName = ''' + @tap_gr_4 + '''') , '') + '
			' + iif(@tap_gr_5 is not null, 'left join '+ iif(@assay_gr = 5, 'dw_assays', '#tmp_dict') + ' t_gr5 on t.tap_gr_5 = t_gr5.'+ iif(@assay_gr = 5, 'assay_code', 'fieldCode and t_gr5.fieldName = ''' + @tap_gr_5 + '''') , '') + '
			' + iif(@tap_gr_6 is not null, 'left join '+ iif(@assay_gr = 6, 'dw_assays', '#tmp_dict') + ' t_gr6 on t.tap_gr_6 = t_gr6.'+ iif(@assay_gr = 6, 'assay_code', 'fieldCode and t_gr6.fieldName = ''' + @tap_gr_6 + '''') , '') + '
			' + iif(@tap_gr_7 is not null, 'left join '+ iif(@assay_gr = 7, 'dw_assays', '#tmp_dict') + ' t_gr7 on t.tap_gr_7 = t_gr7.'+ iif(@assay_gr = 7, 'assay_code', 'fieldCode and t_gr7.fieldName = ''' + @tap_gr_7 + '''') , '') + '
			' + iif(@tap_gr_8 is not null, 'left join '+ iif(@assay_gr = 8, 'dw_assays', '#tmp_dict') + ' t_gr8 on t.tap_gr_8 = t_gr8.'+ iif(@assay_gr = 8, 'assay_code', 'fieldCode and t_gr8.fieldName = ''' + @tap_gr_8 + '''') , '') + '
			' + iif(@tap_gr_9 is not null, 'left join '+ iif(@assay_gr = 9, 'dw_assays', '#tmp_dict') + ' t_gr9 on t.tap_gr_9 = t_gr9.'+ iif(@assay_gr = 9, 'assay_code', 'fieldCode and t_gr9.fieldName = ''' + @tap_gr_9 + '''') , '') + '
		where t.study_id = ' + cast (@study_id as varchar (20)) + '
		'
--print @str;
	exec (@str);

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
