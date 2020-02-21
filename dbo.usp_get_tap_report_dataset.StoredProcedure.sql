USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
1) First way to execute - 
exec usp_get_tap_report_dataset 1, 3 --get TAP vs received Metadata report
exec usp_get_tap_report_dataset 3, 2 --get out of scope report (Metadata that does not have TAP assignments)

exec usp_get_tap_report_dataset 1, 1, '',1 --get TAP vs received Metadata report and show status flag for diff_count field
exec usp_get_tap_report_dataset 3, 2, '',1

2) Second way to execute -
--get TAP vs received Metadata report
create table #stas1 ([#stas1] int)
exec usp_get_tap_report_dataset 3, 1,'#stas1'
select * from #stas1
drop table #stas1

--get TAP vs received Metadata report and show status flag for diff_count field
create table #stas1 ([#stas1] int)
exec usp_get_tap_report_dataset 3, 1,'#stas1', 1
select * from #stas1
drop table #stas1


--get out of scope report
create table #stas1 ([#stas1] int)
exec usp_get_tap_report_dataset 1, 2,'#stas1'
select * from #stas1
drop table #stas1
*/

CREATE proc [dbo].[usp_get_tap_report_dataset] (
	@study_id as int
	,@report_type as int = 1 --expected types: 1 (regular report)-TAP vs Metadata report; 2(out of scope report)-Metadata vs TAP (where TAP was not set)
	,@tb_out_name varchar (30) = ''
	,@diff_count_status_flag int = 0 --if set to 0: shows "diff_count" value as integer; if set to 1: shows diff_count as a status flag using this logic: 
											--diff_count=0: OK
											--diff_count<0: EXTRA
											--diff_count>0: LESS
	)
as

	set nocount on

	Begin try

	declare @str as varchar (max)='', @str1 as varchar (max)='', @str2 varchar (max) = '', @str_fields as varchar (max)='', @str_fields_join varchar (max)='';
	declare @str_template as varchar (max)='';
	--declare @study_id int = 1; --for testing only
	declare @assay_gr int;
	declare @received_count_field varchar (100) = '';
	declare @tap_gr_1 as varchar (100), @tap_gr_2 as varchar (100), @tap_gr_3 as varchar (100), @tap_gr_4 as varchar (100), @tap_gr_5 as varchar (100), @tap_gr_6 as varchar (100), @tap_gr_7 as varchar (100), @tap_gr_8 as varchar (100), @tap_gr_9 as varchar (100)
	declare @error int, @message nvarchar(4000), @ErrorSeverity INT, @ErrorState int;
	declare @no_metadata_avail bit = 0 --flag to store 1, if no metadata is available
	declare @temp_tb_name varchar (50) = newid() ;
--print @temp_tb_name;

	--get metadata for the particular study id into temp table
	create table #metadata ([#metadata] int)
	exec usp_get_metadata @study_id, '#metadata'
--select 'Point 1'
--select * from #metadata --for testing only
	--drop table #metadata

	--check if metadata is available for the current program
	if not exists (select top 1 * from #metadata)
		Begin
		set @no_metadata_avail = 1
		--raise error reporting that no metadata is present for the study_id
		--set @message = 'No metadata was found for study_id = ' + cast (@study_id as varchar (10)) + '. Aborting execution of the procedure!'
		--RAISERROR (@message, -- Message text.
  --             16, -- Severity.
  --             1 -- State.
  --             );
		End

	--get tap setting data for a particular study and assay combination to a temp table
	create table #tap_set ([#tap_set] int)
	exec usp_get_tap_dataset @study_id, '#tap_set' --1,
--select * from #tap_set --for testing only
	--drop table #tap_set

	--create table #metadata_grp (metadata_grp int)
	--select * from #metadata_grp

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
	
	if @report_type = 1
		Begin
		
		if @no_metadata_avail = 0
			Begin
			set @received_count_field = 'isnull(m.received_count, 0)';

			--prepare template to get report showing TAP data vs received metadata
			select @str_template = 'with metadat_grp as ( 
				{metadata_gr_tbl} 
				)
				Select 
					{select_list_of_fields}
					, isnull(s.sample_count, 0) as sample_count
					, {{received_count_field}} as received_count
					{{diff_count}} '
				+ iif (len(ltrim(rtrim(@tb_out_name)))>0, ' into [' + @temp_tb_name + '] ' , '') +
				'from #tap_set s 
				left join metadat_grp m on
				{join_list_of_fields}
				Where s.study_id = {study_id}'
			End
		Else
			Begin 
			set @received_count_field = '0';

			--prepare template to get report showing TAP data only, since no metadata is available
			select @str_template = 'Select 
					{select_list_of_fields}
					, isnull(s.sample_count, 0) as sample_count
					, {{received_count_field}} as received_count
					{{diff_count}} '
				+ iif (len(ltrim(rtrim(@tb_out_name)))>0, ' into [' + @temp_tb_name + '] ' , '') +
				' from #tap_set s 
				Where s.study_id = {study_id}'
			End
		
		--prepare script for displaying "diff_count" field
		if isnull(@diff_count_status_flag, 0) = 0
			Begin
			set @str2 = ', isnull(s.sample_count, 0) - {{received_count_field}} as diff_count '
			End
		else
			Begin
			set @str2 = ', case 
							when (isnull(s.sample_count, 0) - {{received_count_field}}) = 0 then ''OK''
							when (isnull(s.sample_count, 0) - {{received_count_field}}) > 0 then ''LESS''
							when (isnull(s.sample_count, 0) - {{received_count_field}}) < 0 then ''EXTRA''
							end
						as diff_count '
		End

		--update @str_template with the script for "diff_count" field
		set @str_template = replace (@str_template, '{{diff_count}}', @str2);
		set @str_template = replace (@str_template, '{{received_count_field}}', @received_count_field);

--Print @str_template;

		--old version -----------------------------------
		--select @str_template = 'with metadat_grp as ( 
		--	{metadata_gr_tbl} 
		--	)
		--	Select 
		--		{select_list_of_fields}
		--		, isnull(s.sample_count, 0) as sample_count
		--		, isnull(m.received_count, 0) as received_count
		--		, isnull(s.sample_count, 0) - isnull(m.received_count, 0) as diff_count '
		--	+ iif (len(ltrim(rtrim(@tb_out_name)))>0, ' into [' + @temp_tb_name + '] ' , '') +
		--	'from #tap_set s 
		--	left join metadat_grp m on
		--	{join_list_of_fields}
		--	Where s.study_id = {study_id}'

		End

	if @report_type = 2
		Begin

		if @no_metadata_avail = 0
			Begin
			--prepare template to get out of scope items metadata vs tap where tap is null 
			select @str_template = 'with metadat_grp as ( 
				{metadata_gr_tbl} 
				)
				Select 
					{select_list_of_fields}
					, isnull(s.received_count, 0) as received_count '
				+ iif (len(ltrim(rtrim(@tb_out_name)))>0, ' into [' + @temp_tb_name + '] ' , '') +
				'from metadat_grp s 
				left join #tap_set m on
				{join_list_of_fields}
				Where s.study_id = {study_id} and m.tap_id is null'
			End
		else
			Begin
			select @str_template = 'Select ''{study_id}'' as study_id, ''No metadata available for this study_id! Aborting execution.'' as study_name'
			End
		End

	--check if @str_template was assigned with some value
	If len(rtrim(ltrim(@str_template))) = 0 
		Begin 
			set @str = 'Error: Not expected report type value (' + cast (@report_type as varchar (10)) + ') was provided to the procedure! Aborting execution.'
			--print @str;
			Select '' study_id, @str as study_name;
		End 

	set @str_fields = 's.study_id, s.study_name
		' + iif(@tap_gr_1 is not null, ',s.' + @tap_gr_1 + '_code, s.' + @tap_gr_1 + '_value ', '') + '
		' + iif(@tap_gr_2 is not null, ',s.' + @tap_gr_2 + '_code, s.' + @tap_gr_2 + '_value ', '') + '
		' + iif(@tap_gr_3 is not null, ',s.' + @tap_gr_3 + '_code, s.' + @tap_gr_3 + '_value ', '') + '
		' + iif(@tap_gr_4 is not null, ',s.' + @tap_gr_4 + '_code, s.' + @tap_gr_4 + '_value ', '') + '
		' + iif(@tap_gr_5 is not null, ',s.' + @tap_gr_5 + '_code, s.' + @tap_gr_5 + '_value ', '') + '
		' + iif(@tap_gr_6 is not null, ',s.' + @tap_gr_6 + '_code, s.' + @tap_gr_6 + '_value ', '') + '
		' + iif(@tap_gr_7 is not null, ',s.' + @tap_gr_7 + '_code, s.' + @tap_gr_7 + '_value ', '') + '
		' + iif(@tap_gr_8 is not null, ',s.' + @tap_gr_8 + '_code, s.' + @tap_gr_8 + '_value ', '') + '
		' + iif(@tap_gr_9 is not null, ',s.' + @tap_gr_9 + '_code, s.' + @tap_gr_9 + '_value ', '') 

	set @str_fields_join = 's.study_id = m.study_id
		' + iif(@tap_gr_1 is not null, ' and s.' + @tap_gr_1 + '_code = m.' + @tap_gr_1 + '_code ', '')+ '
		' + iif(@tap_gr_2 is not null, ' and s.' + @tap_gr_2 + '_code = m.' + @tap_gr_2 + '_code ', '') + '
		' + iif(@tap_gr_3 is not null, ' and s.' + @tap_gr_3 + '_code = m.' + @tap_gr_3 + '_code ', '') + '
		' + iif(@tap_gr_4 is not null, ' and s.' + @tap_gr_4 + '_code = m.' + @tap_gr_4 + '_code ', '') + '
		' + iif(@tap_gr_5 is not null, ' and s.' + @tap_gr_5 + '_code = m.' + @tap_gr_5 + '_code ', '') + '
		' + iif(@tap_gr_6 is not null, ' and s.' + @tap_gr_6 + '_code = m.' + @tap_gr_6 + '_code ', '') + '
		' + iif(@tap_gr_7 is not null, ' and s.' + @tap_gr_7 + '_code = m.' + @tap_gr_7 + '_code ', '') + '
		' + iif(@tap_gr_8 is not null, ' and s.' + @tap_gr_8 + '_code = m.' + @tap_gr_8 + '_code ', '') + '
		' + iif(@tap_gr_9 is not null, ' and s.' + @tap_gr_9 + '_code = m.' + @tap_gr_9 + '_code ', '') 
--print @str_fields_join

	--prepare template to get metadata grouped by available TAP categories (tap_gr_1...)
	set @str = '
		Select 
			' + @str_fields + '
			, count(*) received_count
		from #metadata s
		Group by 
		' + @str_fields
	--into ' + @metadata_tb_name + '
--print @str;
--exec (@str);

	Select @str1 = replace (@str_template, '{metadata_gr_tbl}', @str);
--print @str1;
	Select @str1 = replace (@str1, '{select_list_of_fields}', @str_fields);
--print @str1;
	Select @str1 = replace (@str1, '{join_list_of_fields}', @str_fields_join);
--print @str1;
	Select @str1 = replace (@str1, '{study_id}', cast (@study_id as varchar (20)));
--print @str1;

	--get metadata grouped by available TAP categories (tap_gr_1...)
	exec (@str1);

	If len(ltrim(rtrim(@tb_out_name)))>0 
		Begin --if the temp table name was provided into the input parameter
			select @str1 = '', @str = '';
				
			--prepare alter statements to copy metadata table structure into the one passed as a parameter @tb_out_name
			select 
				--c.name, t.name, c.prec 
				@str1 = @str1 + 'alter table [' + ltrim(rtrim(@tb_out_name)) + '] add [' + c.name + '] ' + t.name + iif(t.name = 'varchar', ' (' + cast(c.prec as varchar (20)) + '); ', '; ') 
				, @str = @str + '[' + c.name + '],'
			from syscolumns c 
			inner join sysobjects o on o.id = c.id 
			inner join systypes t on c.xtype = t.xtype
			where o.name = @temp_tb_name
			order by colid

			set @str = left(@str, len(@str) - 1);

			--preapare script to drop a column of the table that matches the name of the table; this column was passed as temp measure to have some default structure of the table
			set @str1 = @str1 + 'alter table [' + ltrim(rtrim(@tb_out_name)) + '] drop column [' + ltrim(rtrim(@tb_out_name)) + ']; '
					
--print @str1 --for testing only

			exec (@str1) --execute prepared script script
					
			set @str1 = ''

			--preapare script to insert all data from a temp table to the output table
			set @str1 = @str1 + 'insert into [' + ltrim(rtrim(@tb_out_name)) + '] (' + @str + ') select ' + @str + ' from [' + @temp_tb_name + ']; '
			--preapare script to drop the temp table
			set @str1 = @str1 + 'drop table [' + @temp_tb_name + ']; '

--print @str1 --for testing only

			exec (@str1) --execute prepared script script
			
		End
		
		IF OBJECT_ID('tempdb..#metadata') IS NOT NULL DROP TABLE #metadata
		IF OBJECT_ID('tempdb..#tap_set') IS NOT NULL DROP TABLE #tap_set

	End try

	Begin Catch
		--handle error -------------------

		select @error = ERROR_NUMBER(),
                 @message = ERROR_MESSAGE(), --, @xstate = XACT_STATE();
				 @ErrorSeverity = ERROR_SEVERITY(),
				 @ErrorState = ERROR_STATE();

		print '==========ERROR=================='
		Print 'Error Number: ' + Cast (@error as varchar (20)) + '; Error Message: ' + @message
		
		--remove temp tables
		IF OBJECT_ID('dw_motrpac..[' + isnull(@temp_tb_name,'') + ']') IS NOT NULL 
			Begin 
				set @str = 'DROP TABLE [' + isnull(@temp_tb_name,'') + ']'
				exec (@str);
			End
		IF OBJECT_ID('tempdb..#metadata') IS NOT NULL DROP TABLE #metadata
		IF OBJECT_ID('tempdb..#tap_set') IS NOT NULL DROP TABLE #tap_set

		--Select -1 study_id, @message as study_name
		--raise error to report it to the parent process
		RAISERROR (@message, -- Message text.
               @ErrorSeverity, -- Severity.
               @ErrorState -- State.
               );

	End Catch
GO
