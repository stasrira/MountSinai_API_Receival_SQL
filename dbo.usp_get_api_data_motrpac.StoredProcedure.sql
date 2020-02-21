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

	--declare @api_endpoint varchar (200)
	declare @accept_hdr varchar (50)
	declare @api_err_key varchar (50), @api_err_value varchar (50)
	declare @api_metadata_path varchar (100) 
	declare @api_error_path varchar (100)
	--declare @api_status_success varchar (20) = dbo.udf_get_config_value (1, 99, 'api_status_success'); --retrieve common for all entities status value (stored in config for entity_type 99)
	declare @api_status_error varchar (20) = dbo.udf_get_config_value (1, 99, 'api_status_error');  --retrieve common for all entities status value (stored in config for entity_type 99)
	--declare @api_status_success_details varchar (20) = dbo.udf_get_config_value (1, 99, 'api_status_success_details');  --retrieve common for all entities success status details value (stored in config for entity_type 99)
	declare @sample_id_key varchar (50)
	declare @allow_updates varchar (10)

	--declare @json as table(Json_Table varchar(max))
	create table #json (Json_Table varchar(max))

	declare @config_tbl config_values_tbl -- temp table to store config key/value pairs for the given study id
	--temp table to store received API response before it gets posted to dw_metadata
	
	declare @tmp_metadata add_metadata_tbl

	create table #tmp_metadata  (
		sample_id varchar (100) not null primary key clustered,
		sample_data nvarchar (max),
		process_status varchar (50)
	)
	--temp table to keep temp list of sample ids during various validation operations
	--declare @tmp_selected_samples as table (sample_id varchar (30))

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
	--exec usp_get_config_value_local @config_tbl, 'api_endpoint', @api_endpoint out

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

		set @str = right (@accept_hdr, len(@accept_hdr) - CHARINDEX('/', @accept_hdr))
		
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

		--bring all data from a templ table to "add_metadata_tbl" variable type to pass it to "usp_add_metadata_records"
		insert into @tmp_metadata select * from #tmp_metadata

--select * from @tmp_metadata


		--call common stored procedure to validate received JSON entries
		/* parameters of usp_validate_received_records:
		@study_id int,
		@mid varchar (20),
		@full_json varchar (max),
		@metadata add_metadata_tbl readonly,
		@sample_data_type as varchar (50) = 'JSON', --format of the string, i.e. JSON, XML, etc.
		@allow_updates varchar (10) = '1' --if equal 1, then updates are allowed, other options - not allowed.
		*/

		exec usp_add_metadata_records 
					@study_id, 
					@mid, 
					@json, 
					@tmp_metadata,
					--@config_tbl, 
					--@api_metadata_path,
					--@sample_id_key,
					@str, 
					@allow_updates
		End

	--drop the created temp table
	IF OBJECT_ID('tempdb..#json') IS NOT NULL DROP TABLE #json
	--IF OBJECT_ID('tempdb..#tmp_metadata') IS NOT NULL DROP TABLE #tmp_metadata

	End


GO
