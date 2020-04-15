USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*
This proc adds aliquot manifest data to dw_aliquot_manifests together with updating the dw_data_sources.
Currently data source name holds description of the source (i.e path of the file used as a source). 

usp_add_aliquot_manifest_data 
	@aliquot_id = 'AS06-11984',
	@sample_id = 'AS06-11984', --'1152',
	@study_id = 7,
	@manifest_data = '{"aliquot_id":"AS06-11984","sample_id":"1152","creation_date":"2006-09-14","volume":"1","volume_measure":"ml","num_cells":"11""num_cells_multiplier":"x10^6",}',
	@aliquot_comments = 'Manual Load from Query analyzer',
	@source_name = 'Manual Update',
	@source_desc = 'Test Source',
	@output_status_dataset = 1
*/
CREATE proc [dbo].[usp_add_aliquot_manifest_data]
	@aliquot_id varchar (50),
	@sample_id varchar (30), 
	@study_id int,
	@manifest_data nvarchar(max) = '',
	@aliquot_comments varchar (2000) = '',
	@source_name varchar (1700) = 'Default - Not Provided',
	@source_desc varchar (1000) = '',
	@output_status_dataset bit = 0
as
Begin
	Begin try

		set nocount on

		declare @cur_source_id int
		declare @cur_data_hash varbinary
		declare @message nvarchar(4000) = ''
		declare @outStatus as varchar (30) = '', @outStatusDesc as varchar (max) = ''
		declare @status_failed as varchar (100) = 'Failed', @status_separator varchar (10) = '|' --CHAR(13)+CHAR(10)

		--=========== validate parameters =====================
		--check if @aliquot_id is not empty
		if @aliquot_id is null or len(ltrim(rtrim(@aliquot_id))) = 0 
			Begin 
			--report error
			set @outStatus = @status_failed
			If len (rtrim(ltrim(@outStatusDesc))) > 0
				set @outStatusDesc = @outStatusDesc + @status_separator
			set @outStatusDesc = @outStatusDesc + 'Required parameter @aliquot_id was not provided.'
			--set @message = '@aliquot_id was provided blank. Aborting execution.'
			----raise error to report it to the parent process
			--RAISERROR (@message, 16, 1); -- Message, Severity, State.
			--Return;
			End

		--check if @sample_id is not empty
		if @sample_id is null or len(ltrim(rtrim(@sample_id))) = 0 
			Begin 
			--report error
			set @outStatus = @status_failed
			If len (rtrim(ltrim(@outStatusDesc))) > 0
				set @outStatusDesc = @outStatusDesc + @status_separator
			set @outStatusDesc = @outStatusDesc + 'Required parameter @sample_id was not provided.'
			--set @message = '@sample_id was provided blank. Aborting execution.'
			----raise error to report it to the parent process
			--RAISERROR (@message, 16, 1); -- Message, Severity, State.
			--Return;
			End

		--check if @study_id > 0
		if @study_id not in (select study_id from dw_studies)
			Begin 
			--report error 
			set @outStatus = @status_failed
			If len (rtrim(ltrim(@outStatusDesc))) > 0
				set @outStatusDesc = @outStatusDesc + @status_separator
			set @outStatusDesc = @outStatusDesc + 'Invalid @study_id (' + cast(@study_id as varchar(10)) + ') was provided.'
			--set @message = 'Invalid @study_id (' + cast(@study_id as varchar(10)) + ') was provided. Aborting execution.'
			----raise error to report it to the parent process
			--RAISERROR (@message, 16, 1); -- Message, Severity, State.
			--Return;
			End
	
		If len(rtrim(ltrim(@outStatus))) = 0
			Begin
			--get data source id; if data source is not present yet, add it to the table
			if not exists (select * from dw_data_sources where source_name = ltrim(rtrim(isnull(@source_name, ''))))
				and not @source_name is null
				Begin 
				insert into dw_data_sources (source_name, source_desc) 
				Select isnull(@source_name, ''), @source_desc

				--get id of just created entry
				set @cur_source_id = scope_identity()

				If len (rtrim(ltrim(@outStatusDesc))) > 0
					set @outStatusDesc = @outStatusDesc + @status_separator
				set @outStatusDesc = @outStatusDesc + 'New data source was recorded to the database: ' + isnull(@source_name, '')

				End
			else
				Begin 
				select @cur_source_id = source_id from dw_data_sources where source_name = ltrim(rtrim(isnull(@source_name, '')))

				If len (rtrim(ltrim(@outStatusDesc))) > 0
					set @outStatusDesc = @outStatusDesc + @status_separator
				set @outStatusDesc = @outStatusDesc + 'Provided data source was recognized as existing: ' + isnull(@source_name, '')
				End

			if not exists (
				select * 
				from dw_aliquot_manifests 
				where sample_id = @sample_id 
					and aliquot_id = @aliquot_id
					and study_id = @study_id)
	
				Begin
				--add aliquot manifest information, if it is not currently present	
				insert into dw_aliquot_manifests (
					 aliquot_id, sample_id, study_id, manifest_data, comments)
				Select  @aliquot_id, @sample_id, @study_id, @manifest_data, @aliquot_comments

				If len (rtrim(ltrim(@outStatusDesc))) > 0
					set @outStatusDesc = @outStatusDesc + @status_separator
				set @outStatusDesc = @outStatusDesc + 'New aliquot_id/sample_id/study_id combination was added to the database: ' + 
											'@aliquot_id = ''' + cast(@aliquot_id as varchar (50)) + ''', ' +
											'@sample_id = ''' + cast(@sample_id as varchar(30)) + ''', ' +
											'@study_id = ''' + cast(@study_id as varchar(10)) + '''. '

				End
			else
				--aliquot manifest information exists

				-- check if the new manifest data is matching the previously saved one
				if exists (
					select *
					from dw_aliquot_manifests 
					where sample_id = @sample_id 
						and aliquot_id = @aliquot_id
						and study_id = @study_id 
						and (manifest_data_hash is null or 
							manifest_data_hash <> hashbytes('SHA2_256',@manifest_data))
					)
				Begin
					declare @cur_manifest_data nvarchar (max)
					-- get value of the current manifest data for the current aliquot id
					select 
						@cur_manifest_data = manifest_data
					from dw_aliquot_manifests 
					where sample_id = @sample_id 
						and aliquot_id = @aliquot_id
						and study_id = @study_id

					-- new manifest data is not matching previously saved one; update the existing record
					Update dw_aliquot_manifests 
					Set 
						manifest_data = @manifest_data,
						datetime_stamp = getdate(),
						comments = @aliquot_comments
					where 
						sample_id = @sample_id 
						and aliquot_id = @aliquot_id
						and study_id = @study_id

					If len (rtrim(ltrim(@outStatusDesc))) > 0
						set @outStatusDesc = @outStatusDesc + @status_separator
					set @outStatusDesc = @outStatusDesc + 'Manifest data for existing aliquot_id/sample_id/study_id combination was updated with newly provided one: ' + 
												'@aliquot_id = ''' + cast(@aliquot_id as varchar (50)) + ''', ' +
												'@sample_id = ''' + cast(@sample_id as varchar(30)) + ''', ' +
												'@study_id = ''' + cast(@study_id as varchar(10)) + ''', ' +
												'new manifest data = ''' + cast(@manifest_data as varchar(max)) + ''', ' +
												'previous manifest data = ''' + cast(@cur_manifest_data as varchar(max)) + '''.'
				End
				else
				Begin
					If len (rtrim(ltrim(@outStatusDesc))) > 0
						set @outStatusDesc = @outStatusDesc + @status_separator
					set @outStatusDesc = @outStatusDesc + 'No changes were found for the Manifest data of the existing aliquot_id/sample_id/study_id combination: ' + 
												'@aliquot_id = ''' + cast(@aliquot_id as varchar (50)) + ''', ' +
												'@sample_id = ''' + cast(@sample_id as varchar(30)) + ''', ' +
												'@study_id = ''' + cast(@study_id as varchar(10)) + '''.'
				End

			--verify that mapping for data source and aliquot is present; if not present create it
			if not exists (
				select * 
				from dw_source_aliquot_mapping 
				where source_id = @cur_source_id
					and sample_id = @sample_id
					and aliquot_id = @aliquot_id
				)
				Begin
				Insert into dw_source_aliquot_mapping (source_id, sample_id, aliquot_id)
				Select @cur_source_id, @sample_id, @aliquot_id
				End

			End
		
		If len(rtrim(ltrim(@outStatus))) = 0
			set @outStatus = 'OK'

		if @output_status_dataset = 1
			Select @outStatus as status, @outStatusDesc as description

	End Try

	Begin Catch
		declare @error int, @err_message nvarchar(4000) = '', @ErrorSeverity INT, @ErrorState int;

		select	 @error = ERROR_NUMBER(),
                 @err_message = ERROR_MESSAGE(),
				 @ErrorSeverity = ERROR_SEVERITY(),
				 @ErrorState = ERROR_STATE();
		
		if @output_status_dataset = 1
			Begin
			set @outStatus = @status_failed
			If len(rtrim(ltrim(@outStatusDesc))) > 0
				set @outStatusDesc = @outStatusDesc + @status_separator
			set @outStatusDesc = @outStatusDesc + 'System error (error #' + cast(@error as varchar(20)) + ') has occured: ' + @err_message
			End
		Else
			Begin
			--raise error to report it to the parent process
			RAISERROR (@message, @ErrorSeverity, @ErrorState);
			End

	End Catch

End
GO
