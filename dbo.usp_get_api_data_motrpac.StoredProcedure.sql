USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--select * from dw_metadata
--exec usp_get_api_data_motrpac 1, 'TST993-00200' --'TST999-00403' --'TST999-00200'
CREATE proc [dbo].[usp_get_api_data_motrpac]
	@study_id int,
	@mid varchar (20)
as
	Begin

	declare @err bit, @errCode as int
	declare @str varchar (max) --temp variable to store sql script 
	declare @json varchar (max) --temp variable to store returned json
	declare @ret_val int

	declare @api_endpoint varchar (200)
	declare @accept_hdr varchar (50)
	declare @api_err_key varchar (50), @api_err_value varchar (50)
	declare @api_metadata_path varchar (100), @api_error_path varchar (100)
	declare @api_status_success varchar (20) = dbo.udf_get_config_value (1, 99, 'api_status_success'); --retrieve common for all entities status value (stored in config for entity_type 99)
	declare @api_status_error varchar (20) = dbo.udf_get_config_value (1, 99, 'api_status_error');  --retrieve common for all entities status value (stored in config for entity_type 99)
	declare @api_status_success_details varchar (20) = dbo.udf_get_config_value (1, 99, 'api_status_success_details');  --retrieve common for all entities success status details value (stored in config for entity_type 99)
	declare @sample_id_key varchar (50)
	declare @allow_updates varchar (10)

	--declare @json as table(Json_Table varchar(max))
	create table #json (Json_Table varchar(max))

	declare @config_tbl config_values_tbl -- temp table to store config key/value pairs for the given study id
	--temp table to store received API response before it gets posted to dw_metadata
	create table #tmp_metadata  (
		sample_id varchar (30) not null primary key clustered,
		sample_data nvarchar (max),
		process_status varchar (50)
	)
	--temp table to keep temp list of sample ids during various validation operations
	declare @tmp_selected_samples as table (sample_id varchar (30))

	--get all configuration items for the given study_id into a temp table
	insert into @config_tbl (config_key, config_value) 
	select config_key, config_value from dbo.udf_get_all_config_value (@study_id, 1)
--select * from @config_tbl --for testing only

	--get single config values from the temp table
	--set @mid = 'TST999-00200' --'TST999-00403'(not authorized) --'TST999-00200' --TST997-00200 --for testing only
	exec usp_get_config_value_local @config_tbl, 'api_accept_header', @accept_hdr out
	exec usp_get_config_value_local @config_tbl, 'error_code_key', @api_err_key out
	exec usp_get_config_value_local @config_tbl, 'error_value_key', @api_err_value out
	exec usp_get_config_value_local @config_tbl, 'metadata_path', @api_metadata_path out
	exec usp_get_config_value_local @config_tbl, 'error_path', @api_error_path out
	exec usp_get_config_value_local @config_tbl, 'allow_updates_of_changed_data', @allow_updates out
	exec usp_get_config_value_local @config_tbl, 'sample_id_key', @sample_id_key out --'vialLabel'
	--exec usp_get_config_value_local @config_tbl, 'api_status_success', @api_status_success out
	--exec usp_get_config_value_local @config_tbl, 'api_status_error', @api_status_error out
	exec usp_get_config_value_local @config_tbl, 'api_endpoint', @api_endpoint out

	select --combine study info for log table entry; it will be passed to api call procedure
		@str = 'Study ID: ' + cast(min(study_id) as varchar(20)) + '; Study Name: ' + min(study_Name) +  '; Manifest ID: ' + isnull(@mid, 'Unknown')
	from dw_studies where study_id = @study_id

	--conduct and api call procedure
	exec @ret_val = usp_run_rest_api_call @str, @mid, @config_tbl,	@json out	--'TST999-00403' --'TST999-00200'
--print @ret_val --for testing only
--print @json --for testing only

	if @ret_val < 0 
		Begin --Error has occured during excution of usp_run_rest_api_call proc, exit stored procedure
		Return
		End

	insert into #json (Json_Table) values (@json)

--select Json_Table from #json --for test only 

	--check if the "errorCode" key exists in the returned response. If it exists, assume that the error response was returned.
	select @errCode = CHARINDEX (@api_err_key, Json_Table)  from #json --'errorCode'
	--get returned value into a variable
	select @json = Json_Table from #json
--Print @json --for test only

	if @errCode > 0 --CHARINDEX ('errorCode', @rsp) > 0
		Begin

		set @str = 
		'Insert into dw_api_retrieval_history (entity_type, entity_id, api_retrieval_id, api_retrieval_status, api_status_details, api_response_sneak_peek) ' +
		'select
		1 as entity_type,
		' + cast (@study_id as varchar(20)) + ', 
		''' + cast (isnull(@mid,'') as varchar(30)) + ''',
		''' + cast (isnull(@api_status_error,'') as varchar(30)) + ''',
		''errorCode: '' + cast(errorCode as varchar(30)) + '', Description: '' + message,
		left(''' + isnull(@json, '') + ''', 1000)
		from #json t1
		CROSS APPLY 
		OpenJson ((select Json_Table from #json), ''' + @api_error_path + ''') 
		with (
			errorCode nvarchar(50) ''$.' + isnull(@api_err_key,'') + ''',
			[message] varchar (1000) ''$.' + isnull(@api_err_value,'') + '''
			) t2'
		--hashbytes(''SHA2_256'',''' + @str + ''')

--print @str --for testing only

		exec (@str)

		End
	Else
		Begin
		--Normal response received, proceed here

		--split api response by Sample ID
		set @str = ' 
		with tb_data as (
		select [key], [value] from OpenJson ((select * from #json), ''' + @api_metadata_path + ''') 
		)
		, json_by_sid as (
		Select t1.[value] sample_data_json, JSON_VALUE(t1.[value], ''$.' + @sample_id_key + ''') [sample_id]
		from tb_data t1
		)
		insert into #tmp_metadata (sample_id, sample_data)
		Select sample_id, sample_data_json 
		from json_by_sid
		'
--print @str
		exec (@str)
		set @str = ''

--TODO Add transaction and try/catch to all inserts/updates below

		--Validate received data
		--1. insert new records that does not exists in the target table yet
		--collect sample ids of all new records to @tmp_selected_samples
		insert into @tmp_selected_samples (sample_id)
		Select sample_id from #tmp_metadata where sample_id not in (Select sample_id from dw_metadata where study_id = @study_id) 

		--insert all sample records for samples selected in the step above to the dw_metadata
		Insert into dw_metadata (study_id, sample_id, sample_retrieval_id, sample_data, sample_data_format)
		Select 
			@study_id, 
			a.sample_id, 
			@mid, 
			a.sample_data, 
			right (@accept_hdr, len(@accept_hdr) - CHARINDEX('/', @accept_hdr)) as sample_data_type
		from #tmp_metadata a inner join @tmp_selected_samples b on a.sample_id = b.sample_id

		--update process_status field for processed records
		update #tmp_metadata set process_status = 'New Record' 
		from  #tmp_metadata a inner join @tmp_selected_samples b on a.sample_id = b.sample_id 

		delete from @tmp_selected_samples --clean temp table

		--2. Identify existing sample IDs that have changed values

		--identify existing sample_ids with changed data and save sample ids to a templ table
		insert into @tmp_selected_samples (sample_id)
		Select a.sample_id 
		from #tmp_metadata a
		inner join dw_metadata b on a.sample_id = b.sample_id 
		and (hashbytes('SHA2_256',a.sample_data)) <> (hashbytes('SHA2_256',b.sample_data))
		where isnull(a.process_status,'') = ''
			
		if ltrim(rtrim(@allow_updates)) = '1' 
			Begin 
			--update dw_metadata table with new sample_data values for all sample_ids that got new values
			update  dw_metadata set dw_metadata.sample_data = a.sample_data
			from #tmp_metadata a
			inner join dw_metadata b on a.sample_id = b.sample_id
			inner join @tmp_selected_samples c on a.sample_id = c.sample_id

			--update process_status field for processed records
			update #tmp_metadata set process_status = 'Changed Value - Updated' 
			from  #tmp_metadata a inner join @tmp_selected_samples b on a.sample_id = b.sample_id
			end
		else
			Begin 
			--update process_status field for processed records
			update #tmp_metadata set process_status = 'Changed Value - Updates Not Permitted' 
			from  #tmp_metadata a inner join @tmp_selected_samples b on a.sample_id = b.sample_id
			End

		--3. Identify existing sample IDs having same values values
		--identify existing sample_ids having same data and update status of the #tmp_metadata table accordingly
		Update #tmp_metadata set process_status = 'Same Value Reported'
		from #tmp_metadata a
		inner join dw_metadata b on a.sample_id = b.sample_id 
		and (hashbytes('SHA2_256',a.sample_data)) = (hashbytes('SHA2_256',b.sample_data))
		where isnull(a.process_status,'') = ''

		--4. If any of the reported records did not get a status assigned, update those to clearly mark that
		--identify existing sample_ids having same data and update status of the #tmp_metadata table accordingly
		Update #tmp_metadata set process_status = 'Not Processed'
		from #tmp_metadata a
		where isnull(a.process_status,'') = ''


		--Report results of processing API response into a log table
		declare @last_log_id as bigint
		select @last_log_id = isnull(max(log_id), 0) from dw_metadata_modification_log

		Insert into dw_metadata_modification_log 
			(study_id, sample_id, sample_retrieval_id, process_status)
		select @study_id, sample_id, @mid, process_status from #tmp_metadata

--		Select * from dw_metadata_modification_log where log_id > @last_log_id
		
		--Report api response to dw_api_retrieval_history
		Insert into dw_api_retrieval_history (entity_type, entity_id, api_retrieval_id, api_retrieval_status, api_status_details, api_response_sneak_peek, full_api_response_hash)
		Select 
			1 as entity_type,
			@study_id, 
			@mid, -- MID used to get response from API
			@api_status_success, --'OK'
			@api_status_success_details, --'N/A'
			left(@json, 1000), -- sneak peak of received response 
			hashbytes('SHA2_256',@json)
		End

	--drop the created temp table
	IF OBJECT_ID('tempdb..#json') IS NOT NULL DROP TABLE #json
	IF OBJECT_ID('tempdb..#tmp_metadata') IS NOT NULL DROP TABLE #tmp_metadata

	End


GO
