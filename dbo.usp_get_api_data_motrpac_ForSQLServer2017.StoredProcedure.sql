USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--select * from dw_metadata
--exec usp_get_api_data_motrpac 1, 'TST999-00403' --'TST999-00403' --'TST999-00200'
Create proc [dbo].[usp_get_api_data_motrpac_ForSQLServer2017]
	@study_id int,
	@mid varchar (20)
as
	Begin

	declare @Object as Int;
	declare @hr  int
	--declare @source varchar(255);  
	--declare @description varchar(255); 
	
	declare @err bit, @errCode as int
	--declare @errLog varchar (4000)
	declare @str varchar (max) --temp variable to store sql script 
	declare @json varchar (max) --temp variable to store returned json

	declare @URL varchar (200)
	declare @uid varchar (50), @pwd varchar (100)
	declare @accept_hdr varchar (50), @api_method varchar (50)
	declare @api_err_key varchar (50), @api_err_value varchar (50)
	declare @api_metadata_path varchar (100), @api_error_path varchar (100)
	declare @api_status_success varchar (20), @api_status_error varchar (20)
	declare @sample_id_key varchar (50)
	declare @allow_updates varchar (10)

	declare @api_log_id bigint --this will keep an id of the curent api call process
	declare @i int --temp variable

	--declare @json as table(Json_Table varchar(max))
	create table #json (Json_Table varchar(max))

	declare @config_tbl config_values_tbl -- temp table to store config key/value pairs for the given study id
	--temp table to store received API response before it gets posted to dw_metadata
	declare @tmp_metadata as table (
		sample_id varchar (30) not null primary key clustered,
		sample_data nvarchar (max),
		process_status varchar (50)
	)
	--temp table to keep temp list of sample ids during various validation operations
	declare @tmp_selected_samples as table (sample_id varchar (30))

	--get all configuration items for the given study_id into a temp table
	insert into @config_tbl (config_key, config_value) 
	select config_key, config_value from dbo.udf_get_all_config_value (@study_id)
--select * from @config_tbl --for testing only

	--get single config values from the temp table
	--set @mid = 'TST999-00200' --'TST999-00403'(not authorized) --'TST999-00200' --TST997-00200 --for testing only
	exec usp_get_config_value_local @config_tbl, 'api_url', @URL out
	exec usp_get_config_value_local @config_tbl, 'api_user', @uid out
	exec usp_get_config_value_local @config_tbl, 'api_pwd', @pwd out
	exec usp_get_config_value_local @config_tbl, 'api_accept_header', @accept_hdr out
	exec usp_get_config_value_local @config_tbl, 'api_method', @api_method out
	exec usp_get_config_value_local @config_tbl, 'error_code_key', @api_err_key out
	exec usp_get_config_value_local @config_tbl, 'error_value_key', @api_err_value out
	exec usp_get_config_value_local @config_tbl, 'metadata_path', @api_metadata_path out
	exec usp_get_config_value_local @config_tbl, 'error_path', @api_error_path out
	exec usp_get_config_value_local @config_tbl, 'allow_updates_of_changed_data', @allow_updates out
	exec usp_get_config_value_local @config_tbl, 'sample_id_key', @sample_id_key out --'vialLabel'
	exec usp_get_config_value_local @config_tbl, 'api_status_success', @api_status_success out
	exec usp_get_config_value_local @config_tbl, 'api_status_error', @api_status_error out

	set @URL = @URL + @mid --add mid value to the URL

	--get single config values from the main config table
	--set @URL = dbo.udf_get_config_value(@study_id, 'api_url') + @mid --'https://www.motrpac.org/rest/motrpacapi/biospecimen/' + @mid
	--Set @uid = dbo.udf_get_config_value(@study_id, 'api_user') --'stas.rirak@mssm.edu'
	--set @pwd = dbo.udf_get_config_value(@study_id, 'api_pwd') --'BB846687-038A-D5BE-0509801DBBD95124'
	--set @accept_hdr = dbo.udf_get_config_value(@study_id, 'api_accept_header') --application/json --'application/xml'
	--set @api_method = dbo.udf_get_config_value(@study_id, 'api_method') --'GET'
	--set @api_err_key = dbo.udf_get_config_value(@study_id, 'error_code_key') --'$.errorCode'
	--set @api_err_value = dbo.udf_get_config_value(@study_id, 'error_value_key') --'$.message'
	--set @api_metadata_path = dbo.udf_get_config_value(@study_id, 'metadata_path') --'$.data'
	--set @api_error_path = dbo.udf_get_config_value(@study_id, 'error_path') --'$'
	--set @sample_id_key = dbo.udf_get_config_value(@study_id, 'sample_id_key') --'vialLabel'

	select --combine study info for log table entry
		@str = 'Study ID: ' + cast(min(study_id) as varchar(20)) + '; Study Name: ' + min(study_Name) +  '; Manifest ID: ' + isnull(@mid, 'Unknown')
	from dw_studies where study_id = @study_id
	exec @api_log_id = usp_update_api_communication_log 0, @mid, 'API call was initiated', @str, 'Command' --log start API connection session
	set @str = '' --reset @str

	Exec @hr=sp_OACreate 'MSXML2.ServerXMLHTTP.6.0', @Object OUT;
	IF @hr <> 0 
		Begin
		--report error to dw_api_communication_log table
		exec usp_log_api_error @api_log_id, @Object, 'sp_OACreate ''MSXML2.ServerXMLHTTP.6.0'''
		RETURN --break the execution
		End
	
	Exec @hr=sp_OAMethod @Object, 'open', NULL, @api_method, --'get',
					 @URL						--https://www.motrpac.org/rest/motrpacapi/biospecimen/ANI870-10000' --Your Web Service Url (invoked)
					 ,'false', @uid, @pwd --'stas.rirak@mssm.edu', 'BB846687-038A-D5BE-0509801DBBD95124' --@uid, @pwd--
	--IF @hr <> 0 EXEC sp_OAGetErrorInfo @Object
	IF @hr <> 0 
		Begin
		--report error to dw_api_communication_log table
		exec usp_log_api_error @api_log_id, @Object, 'sp_OAMethod ''Open'''
		RETURN --break the execution
		End

	Exec @hr=sp_OAMethod @Object, 'SetRequestHeader', NULL, 'Accept', @accept_hdr --'application/xml' --'application/json'
	--IF @hr <> 0 EXEC sp_OAGetErrorInfo @Object
	IF @hr <> 0 
		Begin
		--report error to dw_api_communication_log table
		exec usp_log_api_error @api_log_id, @Object, 'sp_OAMethod ''SetRequestHeader'''
		RETURN --break the execution
		End

	Exec @hr=sp_OAMethod @Object, 'send'
	--IF @hr <> 0 EXEC sp_OAGetErrorInfo @Object
	IF @hr <> 0 
		Begin
		--report error to dw_api_communication_log table
		exec usp_log_api_error @api_log_id, @Object, 'sp_OAMethod ''Send'''
		RETURN --break the execution
		End
	
	exec usp_update_api_communication_log @api_log_id, @mid, 'API Request Sent', @URL, 'Command' --log successful API send request 	

	--retrieve a response from API
	INSERT into #json (Json_Table) exec sp_OAGetProperty @Object, 'responseText'

	set @i = 100
	select @str = 'Total length: ' + cast(len(Json_Table) as varchar(20)) + ', First ' + cast (@i as varchar(20)) + ' characters: "' + left(Json_Table, @i) + '..."' from #json
	--select @str
	exec usp_update_api_communication_log @api_log_id, @mid, 'API Response Received', @str, 'Command' --log successful receival of the response
	set @str = ''

	--close API connection 
	EXEC sp_OADestroy @Object

	exec usp_update_api_communication_log @api_log_id, @mid, 'API Coonection closed', 'Coonection closed', 'Command' --log successful receival of the response

--select Json_Table from #json --for test only 

	--check if the "errorCode" key exists in the returned response. If it exists, assume that the error response was returned.
	select @errCode = CHARINDEX (@api_err_key, Json_Table)  from #json --'errorCode'
	--get returned value into a variable
	select @json = Json_Table from #json
--select @@json --for test only

	if @errCode > 0 --CHARINDEX ('errorCode', @rsp) > 0
		Begin

		--TODO: save error output to Log table

				--TODO: report api response to dw_api_retrieval_history
		--Report api response to dw_api_retrieval_history
		--select @json = Json_Table from #json
		--Insert into dw_api_retrieval_history (program_id, study_id, api_retrieval_id, api_retrieval_status, api_response_sneak_peek, full_api_response_hash)
		--Select 
		--	(select program_id from dw_studies where study_id = @study_id) as program_id,
		--	@study_id, 
		--	@mid, -- MID used to get response from API
		--	'OK',
		--	left(@json, 1000), -- sneak peak of received response 
		--	hashbytes('SHA2_256',@str)
		--set @str = ''

		set @str = 
		'Insert into dw_api_retrieval_history (program_id, study_id, api_retrieval_id, api_retrieval_status, api_status_details, api_response_sneak_peek) ' +
		'select
		(select program_id from dw_studies where study_id = ' + cast (@study_id as varchar(20)) + '),
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

--select @str --for testing only

		exec (@str)

		--Output JSON string and field's values separately 
		--set @str = 
		--'select * from #json t1
		--CROSS APPLY 
		--OpenJson ((select Json_Table from #json), ''' + @api_error_path + ''') 
		--with (
		--	errorCode nvarchar(50) ''$.' + @api_err_key + ''',
		--	[message] varchar (1000) ''$.' + @api_err_value + '''
		--	) t2'
		
--		select @str --for testing only
--		exec (@str)
		
		--original code -- for tesing only
		--select * from #json t1
		--CROSS APPLY 
		--OpenJson ((select Json_Table from #json), '$') 
		--with (
		--	errorCode nvarchar(50) '$.errorCode',
		--	[message] varchar (1000) '$.message'
		--	) t2
		
		End
	Else
		Begin
		--Normal response received, proceed here

		--split api response by Sample ID
		;with tb_data as (
		select [key], [value] from OpenJson ((select * from #json), @api_metadata_path) --'$.data' 
		)
		, json_by_sid as (
		--Select t1.[key] row_id, t1.value sample_data_json, js.* from tb_data t1
		Select t1.[value] sample_data_json, JSON_VALUE(t1.[value], '$.' + @sample_id_key) [sample_id]
		from tb_data t1
		)
		--insert received data into a temp table
		insert into @tmp_metadata (sample_id, sample_data)
		Select sample_id, sample_data_json 
		from json_by_sid

		--Insert into json_values (sample_id, sample_data_json)
		--Select sample_id, sample_data_json 
		--from json_by_sid
		--where sample_id not in (Select sample_id from json_values)

--TODO Add transaction and try/catch to all inserts/updates below

		--Validate received data
		--1. insert new records that does not exists in the target table yet
		--collect sample ids of all new records to @tmp_selected_samples
		insert into @tmp_selected_samples (sample_id)
		Select sample_id from @tmp_metadata where sample_id not in (Select sample_id from dw_metadata where study_id = @study_id) 

		--insert all sample records for samples selected in the step above to the dw_metadata
		Insert into dw_metadata (program_id, study_id, sample_id, sample_retrieval_id, sample_data, sample_data_format)
		Select 
			(select program_id from dw_studies where study_id = @study_id) as program_id,
			@study_id, 
			a.sample_id, 
			@mid, 
			a.sample_data, 
			right (@accept_hdr, len(@accept_hdr) - CHARINDEX('/', @accept_hdr)) as sample_data_type
		from @tmp_metadata a inner join @tmp_selected_samples b on a.sample_id = b.sample_id

		--update process_status field for processed records
		update @tmp_metadata set process_status = 'New Record' 
		from  @tmp_metadata a inner join @tmp_selected_samples b on a.sample_id = b.sample_id 

		delete from @tmp_selected_samples --clean temp table

		--2. Identify existing sample IDs that have changed values

		--identify existing sample_ids with changed data and save sample ids to a templ table
		insert into @tmp_selected_samples (sample_id)
		Select a.sample_id 
		from @tmp_metadata a
		inner join dw_metadata b on a.sample_id = b.sample_id 
		and (hashbytes('SHA2_256',a.sample_data)) <> (hashbytes('SHA2_256',b.sample_data))
		where isnull(a.process_status,'') = ''
			
		if ltrim(rtrim(@allow_updates)) = '1' 
			Begin 
			--update dw_metadata table with new sample_data values for all sample_ids that got new values
			update  dw_metadata set dw_metadata.sample_data = a.sample_data
			from @tmp_metadata a
			inner join dw_metadata b on a.sample_id = b.sample_id
			inner join @tmp_selected_samples c on a.sample_id = c.sample_id

			--update process_status field for processed records
			update @tmp_metadata set process_status = 'Changed Value - Updated' 
			from  @tmp_metadata a inner join @tmp_selected_samples b on a.sample_id = b.sample_id
			end
		else
			Begin 
			--update process_status field for processed records
			update @tmp_metadata set process_status = 'Changed Value - Updates Not Permitted' 
			from  @tmp_metadata a inner join @tmp_selected_samples b on a.sample_id = b.sample_id
			End

		--3. Identify existing sample IDs having same values values
		--identify existing sample_ids having same data and update status of the @tmp_metadata table accordingly
		Update @tmp_metadata set process_status = 'Same Value Reported'
		from @tmp_metadata a
		inner join dw_metadata b on a.sample_id = b.sample_id 
		and (hashbytes('SHA2_256',a.sample_data)) = (hashbytes('SHA2_256',b.sample_data))
		where isnull(a.process_status,'') = ''

		--4. If any of the reported records did not get a status assigned, update those to clearly mark that
		--identify existing sample_ids having same data and update status of the @tmp_metadata table accordingly
		Update @tmp_metadata set process_status = 'Not Processed'
		from @tmp_metadata a
		where isnull(a.process_status,'') = ''


		--Report results of processing API response into a log table
		declare @last_log_id as bigint
		select @last_log_id = isnull(max(log_id), 0) from dw_metadata_modification_log

		Insert into dw_metadata_modification_log 
			(study_id, sample_id, sample_retrieval_id, process_status)
		select @study_id, sample_id, @mid, process_status from @tmp_metadata

--		Select * from dw_metadata_modification_log where log_id > @last_log_id
		
		--Report api response to dw_api_retrieval_history
		Insert into dw_api_retrieval_history (program_id, study_id, api_retrieval_id, api_retrieval_status, api_response_sneak_peek, full_api_response_hash)
		Select 
			(select program_id from dw_studies where study_id = @study_id) as program_id,
			@study_id, 
			@mid, -- MID used to get response from API
			@api_status_success, --'OK'
			left(@json, 1000), -- sneak peak of received response 
			hashbytes('SHA2_256',@json)
		End

	--drop the created temp table
	IF OBJECT_ID('tempdb..#json') IS NOT NULL DROP TABLE #json

	End


GO
