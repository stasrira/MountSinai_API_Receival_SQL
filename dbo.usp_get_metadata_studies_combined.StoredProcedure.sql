USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
--call to get all available records for a given studies
exec usp_get_metadata_studies_combined '1,2,3', ',', 1

--call to get only identified sample_ids
exec usp_get_metadata_studies_combined @study_ids = '1,2', @sample_ids = '90001013001, 90001015204, 90001015502, 90001015503, 90001015802, 90001015804, 90001015902, 80000885506, 80000885507, 80000885508'

*/
CREATE proc [dbo].[usp_get_metadata_studies_combined]
	@study_ids varchar (200) = ''
	,@study_delim varchar (10) = ','
	,@friendly_no_data int = 0 --0: will return an empty dataset, 1: will return one row with a message - "No data found"
	,@sample_ids varchar (max) = '' --contains list of Sample Ids that are required to be returned; if not blank, only these ids will be passed into the output
	,@sample_delim varchar (4) = ',' -- delimiter of the sample ids in the @sample_ids variable 
as
	Begin Try
	set nocount on
	 
	declare @tb_studies as table (study_id varchar (100), dict_id int, rec_count int); --this table will hold split list of submitted MIDs

	declare @cnt int, @sql_tmp varchar (1000) = '';
	declare @proc_name varchar (50) = 'usp_get_metadata';
	declare @sql nvarchar(max) = '', @sql2 nvarchar(max) = '', @sql3 nvarchar(max) = '';
	declare @error int, @message nvarchar(4000) = '', @ErrorSeverity INT, @ErrorState int;

	--check if @study_ids is not empty
	if len(ltrim(rtrim(@study_ids))) = 0 
		Begin 
		--report error 
		set @message = 'No study ids were passed to procedure. Aborting execution.'
		
		--raise error to report it to the parent process
		RAISERROR (@message, -- Message text.
               16, -- Severity.
               1 -- State.
               );
		Return;

		End

	Insert into @tb_studies (study_id)
	SELECT ltrim(rtrim(value)) FROM STRING_SPLIT(isnull(@study_ids,''), @study_delim);

	--check if all study ids are numberic values
	if exists (select * from @tb_studies where ISNUMERIC(study_id) <> 1)
		Begin 
		Set @sql_tmp = '';
		Select @sql_tmp = @sql_tmp + N', "' + study_id + '" ' from @tb_studies where ISNUMERIC(study_id) <> 1
		--set @sql_tmp = replace (@sql_tmp, ' "', ', "') --insert comma separators between the study ids
		select @sql_tmp = stuff(@sql_tmp, 1, 2, N'') --replace leading characters with blank string

		--report error 
		set @message = 'Study id are must be numeric values. The following study ids do not compy with this rule: ' + @sql_tmp
		
		--raise error to report it to the parent process
		RAISERROR (@message, -- Message text.
               16, -- Severity.
               1 -- State.
               );
		Return;

		End

	--assuming all study ids are numeric, update dictionary field
	;with metadata_stats as
		(
		select study_id, count (*) record_count
		from dw_metadata
		group by study_id
		)
	Update @tb_studies 
		set 
			dict_id = s.dict_id,
			rec_count = m.record_count
	From dw_studies s 
		inner join @tb_studies i on s.study_id = i.study_id
		left join metadata_stats m on m.study_id = s.study_id

	--check if all provided study ids are existing in dw_studies
	If exists (select * from @tb_studies where study_id not in (select study_id from dw_studies)) 
		Begin 
		Set @sql_tmp = '';
		Select @sql_tmp = @sql_tmp + ', "' + study_id + '"' from @tb_studies where study_id not in (select study_id from dw_studies)
		--set @sql_tmp = replace (@sql_tmp, ' "', ', "') --insert comma separators between the study ids
		select @sql_tmp = stuff(@sql_tmp, 1, 2, N'') --replace leading characters with blank string

		--report error 
		set @message = 'The following study ids do not exist in the dw_studies table: ' + @sql_tmp
		
		--raise error to report it to the parent process
		RAISERROR (@message, -- Message text.
               16, -- Severity.
               1 -- State.
               );
		Return;
		End

	--check if all studies belong to the same dictionary
	select @cnt = count(*) from (Select dict_id from @tb_studies group by dict_id) t
	if @cnt > 1
		Begin
		set @sql_tmp = '';

		SELECT @sql_tmp = @sql_tmp + N'; Dict id #' + cast (dict_id as varchar (10)) + ' used by studies: ' 
				+ STUFF((SELECT N', ' + cast(study_id as varchar (10))
				  FROM @tb_studies AS p2
				   WHERE p2.dict_id = p.dict_id 
				   ORDER BY study_id
				   FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 2, N'')
		FROM @tb_studies AS p
		GROUP BY dict_id
		ORDER BY dict_id;

		select @sql_tmp = stuff(@sql_tmp, 1, 2, N'') --replace leading characters with blank string

		--report error 
		set @message = 'All submitted studies must be using the same dictionary. Currenlty there are studies assigned to different dictionaries. See below dictionary ids with studies associated with them: '
			+ CHAR(13)+CHAR(10) + @sql_tmp
		
		--raise error to report it to the parent process
		RAISERROR (@message, -- Message text.
               16, -- Severity.
               1 -- State.
               );
		Return;
		End

		--If no errors were identified, proceed with retrieving information for all studies
		
		--count expected number of output records
		Select @cnt = sum (isnull(rec_count,0)) from @tb_studies

		if @cnt = 0 and @friendly_no_data = 1 
			--no records found to output and friendly output is set On
			Begin
			set @sql ='select ' + @study_ids + ' as study_ids, ''No metadata found for these studies!'' as study_name'
			End
		Else
			Begin 
			--There some records to output or friendly output is set Off
			--Proceed to prepare the main SQL statement
			select 
				@sql = @sql + 
						'create table #meta' + cast (ROW_NUMBER () over (order by study_id) as varchar (10)) + '([#meta' + cast (ROW_NUMBER () over (order by study_id) as varchar (10)) + '] int); ' +
						'exec ' + @proc_name + ' @study_id = ' + study_id + ', @tb_out_name = ''#meta' + cast (ROW_NUMBER () over (order by study_id) as varchar (10)) + ''', @sample_ids = ''' + @sample_ids + ''' ; '
						--@sql + 'create table #meta1 ([#meta1] int); exec ' + @proc_name + ' ' + '1' + ', ''#meta1'';  '
						--	+ 'create table #meta2 ([#meta2] int); exec ' + @proc_name + ' ' + '2' + ', ''#meta2'';  '	
						--	+ 'select * from #meta1 UNION ALL select * from #meta2; drop table #meta1; drop table #meta2'
				, @sql2 = @sql2 + ' UNION ALL select * from #meta' + cast (ROW_NUMBER () over (order by study_id) as varchar (10))
				--, @sql3 = @sql3 + 'drop table #meta' + cast (ROW_NUMBER () over (order by study_id) as varchar (10)) + '; '
				, @sql3 = @sql3 + '; IF OBJECT_ID(''tempdb..#meta' + cast (ROW_NUMBER () over (order by study_id) as varchar (10)) + ''') IS NOT NULL DROP TABLE #meta' + cast (ROW_NUMBER () over (order by study_id) as varchar (10)) + '; '

				--IF OBJECT_ID('tempdb..#config') IS NOT NULL DROP TABLE #config

			from @tb_studies 
			where rec_count > 0
			group by study_id --use group by to eliminate duplicated study id submission 

			select @sql2 = stuff(@sql2, 1, 11, N'') --replace leading 'UNION ALL' with blank string

--print @sql --for testing only
--print @sql2 --for testing only
--print @sql3 --for testing only

			set @sql = @sql + @sql2+ @sql3 
		End

--print @sql --for testing only

		--execute the created SQL strings
		exec sp_executesql @sql;
	End Try

	Begin Catch
		--handle error -------------------

		select @error = ERROR_NUMBER(),
                 @message = CHAR(13)+CHAR(10) + 'ERROR: ' + ERROR_MESSAGE(), --, @xstate = XACT_STATE();
				 @ErrorSeverity = ERROR_SEVERITY(),
				 @ErrorState = ERROR_STATE();

		--print '==========ERROR=================='
		--Print '========ERROR====== Number: ' + Cast (@error as varchar (20)) + '; Error Message: ' + @message
		
		--Select -1 study_id, @message as study_name
		--raise error to report it to the parent process
		RAISERROR (@message, -- Message text.
               @ErrorSeverity, -- Severity.
               @ErrorState -- State.
               );

	End Catch




GO
