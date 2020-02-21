USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--exec usp_get_api_dictionary_motrpac 1
CREATE proc [dbo].[usp_get_api_dictionary_motrpac]
	@dict_id int
as
	Begin

	--declare @dict_id int = 1 --for testing only

	declare @err bit, @errCode as int;
	declare @str varchar (max); --temp variable to store sql script 
	declare @json varchar (max); --temp variable to store returned json
	declare @ret_val int;

	declare @api_url varchar (200);
	declare @accept_hdr varchar (50);
	declare @api_err_key varchar (50), @api_err_value varchar (50);
	declare @api_metadata_path varchar (100), @api_error_path varchar (100);
	declare @api_status_success varchar (20) = dbo.udf_get_config_value (1, 99, 'api_status_success'); --retrieve common for all entities status value (stored in config for entity_type 99)
	declare @api_status_error varchar (20) = dbo.udf_get_config_value (1, 99, 'api_status_error');  --retrieve common for all entities status value (stored in config for entity_type 99)
	declare @api_dictionary_endpoint varchar (100), @api_dictionary_name varchar (50);
	declare @entity_type int = 2; --default entity type for dictionaries

	--declare @json as table(Json_Table varchar(max))
	create table #json (Json_Table varchar(max));

	declare @config_tbl config_values_tbl; -- temp table to store config key/value pairs for the given study id

	--get all configuration items for the given study_id into a temp table
	insert into @config_tbl (config_key, config_value) 
	select config_key, config_value from dbo.udf_get_all_config_value (@dict_id, 2)
--select * from @config_tbl --for testing only

	--get single config values from the temp table
	--set @mid = 'TST999-00200' --'TST999-00403'(not authorized) --'TST999-00200' --TST997-00200 --for testing only
	exec usp_get_config_value_local @config_tbl, 'api_accept_header', @accept_hdr out
	exec usp_get_config_value_local @config_tbl, 'error_code_key', @api_err_key out
	exec usp_get_config_value_local @config_tbl, 'error_value_key', @api_err_value out
	exec usp_get_config_value_local @config_tbl, 'error_path', @api_error_path out
	exec usp_get_config_value_local @config_tbl, 'api_endpoint', @api_dictionary_endpoint out
	exec usp_get_config_value_local @config_tbl, 'api_dictionary_name', @api_dictionary_name out --'vialLabel'
	--exec usp_get_config_value_local @config_tbl, 'api_status_success', @api_status_success out
	--exec usp_get_config_value_local @config_tbl, 'api_status_error', @api_status_error out

	--combine dictionary info for log table entry; it will be passed to api call procedure
	select @str = 'Dictionary "' + @api_dictionary_name + '" retrieval'
--print @str --for testing only
--print @api_dictionary_name -- for testing only
	--conduct and api call procedure
	exec @ret_val = usp_run_rest_api_call @str, @api_dictionary_name, @config_tbl, 	@json out	--'TST999-00403' --'TST999-00200'
print @ret_val --for testing only
print @json --for testing only

	if @ret_val < 0 
		Begin --Error has occured during excution of usp_run_rest_api_call proc, exit stored procedure
		Return
		End

	insert into #json (Json_Table) values (@json)
--select Json_Table from #json --for test only 

	--get returned value into a variable
	select @json = Json_Table from #json
--Print @json --for test only

	--check if the "errorCode" key exists in the returned response. If it exists, assume that the error response was returned.
	select @errCode = CHARINDEX (@api_err_key, Json_Table) from #json --'errorCode'

	if @errCode > 0 --CHARINDEX ('errorCode', @rsp) > 0
		Begin --error was identified, proceed here

		set @str = 
		'Insert into dw_api_retrieval_history (entity_type, entity_id, api_retrieval_id, api_retrieval_status, api_status_details, api_response_sneak_peek) ' +
		'select
		' + cast (@entity_type as varchar(20)) + ',
		' + cast (@dict_id as varchar(20)) + ', 
		''' + cast (isnull(@api_dictionary_name,'') as varchar(100)) + ''',
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

		--check if Dictionary value exists in the dictionary table and if it is, compare the stored dictionary hash to the received one  
		if exists (select * from dw_dictionaries where dict_id = @dict_id)
		Begin --dictionary exists
			--check if dictionary got changed
			if exists (select * from dw_dictionaries where dict_id = @dict_id and isnull(dict_json_hash, cast('' as varbinary)) <> (hashbytes('SHA2_256',isnull(@json,''))))
			Begin 

			--TODO - add transaction to handle the below updates

				--copy existing dictionary record to dw_dictionaries_history table
				insert into dw_dictionaries_history (dict_id, dict_name, dict_uri, dict_json, originally_created)
				select dict_id, dict_name, dict_uri, dict_json, datetime_stamp
				from dw_dictionaries
				where dict_id = @dict_id

				--update exsting dictionary records
				update dw_dictionaries set dict_json = @json
				where dict_id = @dict_id
			End
		End

		Else

		Begin
			--this is a new dictionary, save it to the table
			exec usp_get_config_value_local @config_tbl, 'api_url', @api_url out

			Insert into dw_dictionaries (dict_id, dict_name, dict_uri, dict_json)
			select 
				@dict_id, 
				@api_dictionary_name,
				@api_url + @api_dictionary_endpoint + @api_dictionary_name,
				@json

		End

		
--TODO Add transaction and try/catch to all inserts/updates below

		--Report api response to dw_api_retrieval_history
		Insert into dw_api_retrieval_history (entity_type, [entity_id], api_retrieval_id, api_retrieval_status, api_response_sneak_peek, full_api_response_hash)
		Select 
			@entity_type,
			@dict_id, 
			@api_dictionary_name, -- MID used to get response from API
			@api_status_success, --'OK'
			left(@json, 1000), -- sneak peak of received response 
			hashbytes('SHA2_256',@json)
		End

	--drop the created temp table
	IF OBJECT_ID('tempdb..#json') IS NOT NULL DROP TABLE #json

	End
GO
