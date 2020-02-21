USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE proc [dbo].[usp_validate_received_records] 
	@study_id int,
	@mid varchar (20),
	@full_json varchar (max),
	@config_tbl config_values_tbl readonly,
	@sample_data_type as varchar (50) = 'JSON', --format of the string, i.e. JSON, XML, etc.
	@allow_updates varchar (10) = '1' --if equal 1, then updates are allowed, other options - not allowed.
as

	--temp table to keep temp list of sample ids during various validation operations
	declare @tmp_selected_samples as table (sample_id varchar (30))
	declare @str as varchar (1000)
	declare @api_status_success varchar (20) = dbo.udf_get_config_value (1, 99, 'api_status_success'); --retrieve common for all entities status value (stored in config for entity_type 99)
	declare @api_status_success_details varchar (20) = dbo.udf_get_config_value (1, 99, 'api_status_success_details');  --retrieve common for all entities success status details value (stored in config for entity_type 99)
	declare @api_metadata_path varchar (100), @sample_id_key varchar (50)

	exec usp_get_config_value_local @config_tbl, 'metadata_path', @api_metadata_path out
	exec usp_get_config_value_local @config_tbl, 'sample_id_key', @sample_id_key out --'vialLabel'

	create table #tmp_metadata  (
		sample_id varchar (30) not null primary key clustered,
		sample_data nvarchar (max),
		process_status varchar (50)
	)

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
		@sample_data_type --right (@accept_hdr, len(@accept_hdr) - CHARINDEX('/', @accept_hdr)) as sample_data_type
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

	--3. Identify existing sample IDs having same values
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


	--Report results of processing records into a log table
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
		left(@full_json, 1000), -- sneak peak of received response 
		hashbytes('SHA2_256',@full_json)

	IF OBJECT_ID('tempdb..#tmp_metadata') IS NOT NULL DROP TABLE #tmp_metadata
GO
