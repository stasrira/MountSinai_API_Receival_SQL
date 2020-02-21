USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
1) First way to execute
usp_get_subject_metadata 7
usp_get_subject_metadata 7, '', 0, '', ',', 1
usp_get_subject_metadata 7, '', 0, '', ',', 2
usp_get_subject_metadata @study_id = 7, @show_inconsistent_subjects_detalis = 1, @friendly_no_data=1
usp_get_subject_metadata 7, '', 0, 'AS06-11984,AS07-07650,AS08-02684,AS08-07516', ',', 2
usp_get_subject_metadata @study_id = 7, @sample_ids = 'AS06-11984,AS07-07650,AS08-02684,AS08-07516', @show_inconsistent_subjects_detalis = 2
usp_get_subject_metadata @study_id = 7, @sample_ids = 'AS06-11984,AS07-07650,AS08-02684,AS08-07516'
usp_get_subject_metadata @study_id = 7, @sample_ids = ' AS08-02684,AS08-07516', @show_inconsistent_subjects_detalis = 1

2) Second way to execute -
create table #stas1 ([#stas1] int)
exec usp_get_subject_metadata 7, '#stas1'
select * from #stas1
drop table #stas1
*/

CREATE proc [dbo].[usp_get_subject_metadata]
	 @study_id int
	,@tb_out_name varchar (30) = ''
	,@friendly_no_data int = 0 --there are 0 or 1 expected values
	,@sample_ids varchar (max) = '' --contains list of Sample Ids that are required to be returned; if not blank, only these ids will be passed into the output
	,@sample_delim varchar (4) = ',' -- delimiter of the sample ids in the @sample_ids variabl
	/*
	expected values for @show_inconsistent_subjects_detalis parameter: 
		0: do not show inconsistent details, it will show only main subject dataset; 
		1: show subject dataset without grouping for the inconsistent records only;
		2: show both datasets for option 0 and 1
	*/
	,@show_inconsistent_subjects_detalis int = 0  
as
	Begin 

	SET NOCOUNT ON

	declare @dict_id int;
	declare @str varchar (max) = ''
	declare @temp_tb_name varchar (50) = newid();
	declare @proc_status varchar (20) = ''
	declare @no_mapping varchar (20) = 'no_mapping', @no_metadata varchar (20) = 'no_metadata'
	declare @subject_field_name varchar (50) = ''
	declare @sql varchar (max) = '', @sql1 varchar (max) = '', @sql2 varchar (max) = '', @sql1_i varchar (max) = ''
	declare @select1 as varchar (max) = '', @select2 as varchar (max) = '', @select1_i as varchar (max) = ''
	declare @having1 as varchar (max) = ''

	If not exists (select top 1 * from dw_study_dictionary_mapping where study_id = @study_id and mapping_code = 'subject')
	Begin 
		set @proc_status = @no_mapping
	End

	If not exists (select top 1 * from dw_metadata where study_id = @study_id)
		Begin
			set @proc_status = @no_metadata
		End

--print @proc_status

	if @proc_status = ''
		Begin
		--identify dictionary to be used with this study
		select @dict_id = dict_id from dw_study_dictionary_mapping 
		where study_id = @study_id and mapping_code = 'subject'

		--create temp table to hold dictionary and retreive it
		create table #dict (
			dictionary_id int,
			name varchar (50),
			description varchar (200), 
			label varchar (50),
			type varchar (20),
			code int,
			value varchar (200)
			)
		Insert into #dict exec usp_get_dictionary @dict_id

		--create temp table to hold study and retrieiv it
		create table #md ([#md] int)
		exec usp_get_metadata @study_id = @study_id, @tb_out_name = '#md', @sample_ids = @sample_ids, @sample_delim = @sample_delim

		--select * from  #dict
		--select * from #md where [sid] =1152

		--get name of the field holding Subject id value
		select @subject_field_name = ltrim(rtrim(mapping_code_pk_field_name))
		from dw_study_dictionary_mapping 
		where study_id = @study_id and mapping_code = 'subject'

		select 
			@select1 = @select1 + 
				iif (name = @subject_field_name, '[' + ltrim(rtrim(name)) +'] as subject_id', 
					'min([' + ltrim(rtrim(name)) + ']) as [' + ltrim(rtrim(name)) + ']') + ','
			,@select1_i = @select1_i + 
				iif (name = @subject_field_name, '[' + ltrim(rtrim(name)) +'] as subject_id', 
					'[' + ltrim(rtrim(name)) + '] as [' + ltrim(rtrim(name)) + ']') + ','
			,@select2 = @select2 + 
				iif (name = @subject_field_name, '[' + ltrim(rtrim(name)) +'] as subject_id', '')
			,@having1 = @having1 + iif (name = @subject_field_name, '', 
					'min([' + ltrim(rtrim(name)) + ']) <> max([' + ltrim(rtrim(name)) + ']) or ')
		from #dict

		set @select1 = left(@select1, len(@select1) - 1);
		set @select1_i = left(@select1_i, len(@select1_i) - 1);
		--set @select2 = left(@select2, len(@select2) - 1);
		set @having1 = left(@having1, len(@having1) - 3);

--print @select1
--print @select2
--print @having1

		set @sql1 = '
		;with inconsistent as (
		{sql2}
		)
		select {select1}, iif (min(isnull(i.subject_id,''''))='''', ''OK'', ''Inconsistent'') as record_QC '
		+ iif (len(ltrim(rtrim(@tb_out_name)))>0 and @show_inconsistent_subjects_detalis in (0,2), ' into [' + @temp_tb_name + '] ' , '') +
		' from #md m 
		left join inconsistent i on m.[' + @subject_field_name + '] = i.subject_id
		group by [' + @subject_field_name + ']
		order by [' + @subject_field_name + ']
		'

		set @sql1_i = '
		;with inconsistent as (
		{sql2}
		)
		select {select1}, ''Inconsistent'' as record_QC '
		+ iif (len(ltrim(rtrim(@tb_out_name)))>0 and @show_inconsistent_subjects_detalis in (1), ' into [' + @temp_tb_name + '] ' , '') +
		' 
		from #md m 
		inner join inconsistent i on m.[' + @subject_field_name + '] = i.subject_id
		order by [' + @subject_field_name + ']
		'

		set @sql2 = '
		select {select2} 
		from #md 
		group by ' + @subject_field_name + '
		having {having1}
		'
		
		set @sql2 = REPLACE (@sql2, '{select2}', @select2)
		set @sql2 = REPLACE (@sql2, '{having1}', @having1)
		set @sql1 = REPLACE (@sql1, '{select1}', @select1)
		set @sql1 = REPLACE (@sql1, '{sql2}', @sql2)
		set @sql1_i = REPLACE (@sql1_i, '{select1}', @select1_i)
		set @sql1_i = REPLACE (@sql1_i, '{sql2}', @sql2)

--print @sql1
--print @sql2
--print @sql1_i
		
		--exec this statement if @show_inconsistent_subjects_detalis in (0,2) with any value of @tb_out_name
		if @show_inconsistent_subjects_detalis in (0,2)
			exec (@sql1)

		--exec this statement 
		--if @show_inconsistent_subjects_detalis = 1 and @tb_out_name is provided
		--or @show_inconsistent_subjects_detalis = 2 and @tb_out_name is not provided
		if (@show_inconsistent_subjects_detalis = 1) 
			or (@show_inconsistent_subjects_detalis =2  and len(ltrim(rtrim(@tb_out_name))) = 0)
			exec (@sql1_i)

		End
	
	if @proc_status = @no_metadata
		Begin --proceed here if no data is present for the passed study id
			if @friendly_no_data = 1 
				Begin
				set @sql ='select '''' as subject_id, ''No metadata found for study id # ' + cast (@study_id as varchar (20)) + ''' as note'
				End
			else
				Begin
				set @sql = 
				'select '''' as subject_id '
				+ iif (len(ltrim(rtrim(@tb_out_name)))>0, ' into [' + @temp_tb_name + '] ' , '')
				End
	--print @sql; --for testing only
			exec (@sql) --execute the script to output the select statement into a temp table
		End
	
	if @proc_status = @no_mapping
		Begin --proceed here if no data is present for the passed study id
			if @friendly_no_data = 1 
				Begin
				set @sql = 'select '''' as subject_id, ''No "Subject" mapping found for study id # ' + cast (@study_id as varchar (20)) + ''' as note'
				End
			else
				--TODO: figure out the output in this codition
				Begin
				set @sql = 
				'select '''' as subject_id '
				+ iif (len(ltrim(rtrim(@tb_out_name)))>0, ' into [' + @temp_tb_name + '] ' , '')
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
--print @str
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


	End
GO
