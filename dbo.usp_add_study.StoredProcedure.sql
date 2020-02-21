USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* --example of execution
exec usp_add_study 
	@study_name = 'Pass 1B',
	@program_id = 1,
	@dictionary_id = 1,
	@config_combined = 'allow_updates_of_changed_data^1^1:Allows updates of the modified metadata in dw_metadata; 0: do not allow updates.|api_accept_header^application/json^Defines format of response requested from the API server|api_endpoint^biospecimen/^API endpoint to get metadata information|api_method^GET^API method to be used|api_pwd^BB846687-038A-D5BE-0509801DBBD95124^API password|api_url^https://www.motrpac.org/rest/motrpacapi/^API URL|api_user^stas.rirak@mssm.edu^API user|default_value_type^varchar (200)^Default ''field'' type for fields dynamically extracted from JSON received for this entity|error_code_key^errorCode^Key name of the Error Code element reported in JSON for the error response of this entity|error_path^$^Path in JSON response for this entity to the Error related elements|error_value_key^message^Key name of the Error Details element reported in JSON for the error response of this entity|max_failed_retrieval_attempts^7^Max number of attepts to retrieve a response for the given MID. 0 stands for Unlimited.|metadata_path^$.biospecimen^Path in JSON response for this entity to the metadata related elements|sample_id_key^vialLabel^Predefined key name of the element in the JSON response keeping Sample ID value|tap_gr_1^assay^Name of the field containing Assay_id information in the metadata table for current study.|tap_gr_2^sampleTypeCode^Name of the field containing SampleType information in the metadata table for current study.|tap_gr_3^sacrificeTime^Name of the field containing Timepoint information in the metadata table for current study.|tap_gr_4^sex^Name of the field containing Sex information in the metadata table for current study.|top_recs_for_json_structure^1^Number of records to be used by the system to analyse the JSON structure'
	--Bad string containing a dubplicate PK - @config_combined = 'allow_updates_of_changed_data^1^1:Allows updates of the modified metadata in dw_metadata; 0: do not allow updates.|allow_updates_of_changed_data^application/json^Defines format of response requested from the API server|api_endpoint^biospecimen/^API endpoint to get metadata information|api_method^GET^API method to be used|api_pwd^BB846687-038A-D5BE-0509801DBBD95124^API password|api_url^https://www.motrpac.org/rest/motrpacapi/^API URL|api_user^stas.rirak@mssm.edu^API user|default_value_type^varchar (200)^Default ''field'' type for fields dynamically extracted from JSON received for this entity|error_code_key^errorCode^Key name of the Error Code element reported in JSON for the error response of this entity|error_path^$^Path in JSON response for this entity to the Error related elements|error_value_key^message^Key name of the Error Details element reported in JSON for the error response of this entity|max_failed_retrieval_attempts^7^Max number of attepts to retrieve a response for the given MID. 0 stands for Unlimited.|metadata_path^$.biospecimen^Path in JSON response for this entity to the metadata related elements|sample_id_key^vialLabel^Predefined key name of the element in the JSON response keeping Sample ID value|tap_gr_1^assay^Name of the field containing Assay_id information in the metadata table for current study.|tap_gr_2^sampleTypeCode^Name of the field containing SampleType information in the metadata table for current study.|tap_gr_3^sacrificeTime^Name of the field containing Timepoint information in the metadata table for current study.|tap_gr_4^sex^Name of the field containing Sex information in the metadata table for current study.|top_recs_for_json_structure^1^Number of records to be used by the system to analyse the JSON structure'
*/
CREATE procedure [dbo].[usp_add_study] (
	@study_name varchar (100) --name of the study to be added
	,@program_id int --id of the existing Program Id
	,@dictionary_id int --id of the existing dictionary
	,@config_combined varchar (max) /* This is a string presenting all config values to be set for the new study. These entries will be inserted into dw_configuration table.
									The value of this parameter presents a delimited string presenting multiple configuration entries devided by the row_delimiter. 
									Each such row presents a delimited string presenting entries for the fields of the dw_configuration table.
									*/
	,@row_delim varchar (10) = '|'
	,@field_delim varchar (10) = '^'
	,@allow_studies_with_same_names int = 0 --This controls allowing of creating a new study having exactly the same Study Name (@study_name) as some existing one. 0: do not allow; 1: allow.
	)
as 

Begin 

	--temp table to store parced config values
	create table #config (
		row_id int identity (1,1)
		,entry_comb varchar (max) --this is a temp field; stores config_key, config_value, config_desc in the delimited format as it was passed to the procedure.
		,config_key varchar (50) --holds information to be passed to the config_key field of the dw_configuration table
		,config_value varchar (1000) --holds information to be passed to the config_value field of the dw_configuration table
		,config_desc varchar (1000) ----holds information to be passed to the config_desc field of the dw_configuration table
	); 

	--for testing only
	--declare @config_combined varchar (max) = 'allow_updates_of_changed_data^1^1:Allows updates of the modified metadata in dw_metadata; 0: do not allow updates.|api_accept_header^application/json^Defines format of response requested from the API server|api_endpoint^biospecimen/^API endpoint to get metadata information|api_method^GET^API method to be used|api_pwd^BB846687-038A-D5BE-0509801DBBD95124^API password|api_url^https://www.motrpac.org/rest/motrpacapi/^API URL|api_user^stas.rirak@mssm.edu^API user|default_value_type^varchar (200)^Default ''field'' type for fields dynamically extracted from JSON received for this entity|error_code_key^errorCode^Key name of the Error Code element reported in JSON for the error response of this entity|error_path^$^Path in JSON response for this entity to the Error related elements|error_value_key^message^Key name of the Error Details element reported in JSON for the error response of this entity|max_failed_retrieval_attempts^7^Max number of attepts to retrieve a response for the given MID. 0 stands for Unlimited.|metadata_path^$.biospecimen^Path in JSON response for this entity to the metadata related elements|sample_id_key^vialLabel^Predefined key name of the element in the JSON response keeping Sample ID value|tap_gr_1^assay^Name of the field containing Assay_id information in the metadata table for current study.|tap_gr_2^sampleTypeCode^Name of the field containing SampleType information in the metadata table for current study.|tap_gr_3^sacrificeTime^Name of the field containing Timepoint information in the metadata table for current study.|tap_gr_4^sex^Name of the field containing Sex information in the metadata table for current study.|top_recs_for_json_structure^1^Number of records to be used by the system to analyse the JSON structure|allow_updates_of_changed_data^1^1:allows updates of the modified metadata in dw_metadata; 0: do not allow updates.|api_accept_header^application/json^Defines format of response requested from the API server|api_endpoint^biospecimen/^API endpoint to get metadata information|api_method^GET^API method to be used|api_pwd^BB846687-038A-D5BE-0509801DBBD95124^API password|api_url^https://www.motrpac.org/rest/motrpacapi/^API URL|api_user^stas.rirak@mssm.edu^API user|default_value_type^varchar (200)^Default field type for fields dynamically extracted from JSON received for this entity|error_code_key^errorCode^Key name of the Error Code element reported in JSON for the error response of this entity|error_path^$^Path in JSON response for this entity to the Error related elements|error_value_key^message^Key name of the Error Details element reported in JSON for the error response of this entity|max_failed_retrieval_attempts^7^Max number of attepts to retrieve a response for the given MID. 0 stands for Unlimited.|metadata_path^$.biospecimen^Path in JSON response for this entity to the metadata related elements|sample_id_key^vialLabel^Predefined key name of the element in the JSON response keeping Sample ID value|top_recs_for_json_structure^1^Number of records to be used by the system to analyse the JSON structure';

	declare @sql nvarchar(max) = '';
	--declare @row_delim nvarchar (1) = '|', @field_delim nvarchar (1) = '^'; --for testing only
	declare @new_study_id int, @duplicated_study_id int;
	declare @error int, @message nvarchar(4000), @ErrorSeverity INT, @ErrorState int;--, @xstate int;

	--check for a provided @study_name against of the existing studies
	if exists(select study_id from dw_studies where study_Name = @study_name) and isnull(@allow_studies_with_same_names, 0) <> 1
		Begin 
		--abort the process and raise custom error
		
		select top 1 @duplicated_study_id = study_id from dw_studies where study_Name = @study_name

		set @message = 'You are attempting to create a new study "' + @study_name + '", however there is already a study with exactly same name (study_id = ' + cast (@duplicated_study_id as varchar(10)) + ').
						If you still want to force creating the new study, supply @allow_studies_with_same_names parameter for this procedure with value 1. '
		
		print '==========ERROR=================='
		Print 'Error Message: ' + @message

		--raise error to report it to the parent process
		RAISERROR (@message, -- Message text.
               16, -- Severity.
               1 -- State.
               );
		Return;
		End

	--split provided string by config entries (info that present rows in the dw_configuration table
	Insert into #config (entry_comb)
	SELECT value FROM STRING_SPLIT(isnull(@config_combined,''), @row_delim);

	--select * from #config order by 1 --for testing only

	/* --this is for test only
	SELECT f.* --s.config_key, s.config_value, s.config_desc
	FROM (select row_id, entry_comb from #config) AS c
		CROSS APPLY 
		(
		select 
		c.row_id,
		ROW_NUMBER() Over(Partition by c.row_id Order by c.row_id) field_num, 
		s.value
		From STRING_SPLIT(c.entry_comb,'^') AS s
		) f
	*/

	--prepare dynamic update statements for config_key, config_value, config_desc fields based on the delimited info stored in the entry_comb field
	SELECT @sql = @sql + 
		'update #config set ' +
		Case f.field_num
			when 1 then 'config_key'
			when 2 then 'config_value'
			when 3 then 'config_desc'
		end +
		' = ''' + replace(cast (f.value as varchar (1000)), '''', '''''')  + '''' +
		' where row_id = ' + cast (f.row_id as varchar (10)) + 
		';'
	FROM (select row_id, entry_comb from #config) AS c
		CROSS APPLY 
		(
		select 
		c.row_id,
		ROW_NUMBER() Over(Partition by c.row_id Order by c.row_id) field_num, 
		s.value
		From STRING_SPLIT(c.entry_comb,'^') AS s
		) f
	--where f.row_id >4 and f.row_id <10 --for testing only

	/*--example of the preapred update statement in the above statement: 
	update #config set config_key = 'api_accept_header' where row_id = 2;
	update #config set config_value = 'application/json' where row_id = 2;
	update #config set config_desc = 'Defines format of response requested from the API server' where row_id = 2;
	*/
--print @sql; --for testing only

	exec sp_executesql @sql; --execute dynamically created statement

	--select * from #config --for testing only

--Print 'Before Openning a new transaction - @@TRANCOUNT = ' + cast (@@TRANCOUNT as varchar (10))

	Begin Try

		Begin Transaction [Tr1] --start transaction

--Print 'After Openning a new transaction - @@TRANCOUNT = ' + cast (@@TRANCOUNT as varchar (10))

		--INSERT of new information - start transaction to add new study to multiple tables
		select @new_study_id =  isnull(max(study_id),0) + 1 from dw_studies  

		--create a new entry in the dw_studies table
		insert into dw_studies (study_id, study_name, dict_id, program_id)
		select @new_study_id, @study_name, @dictionary_id, @program_id

		--make final insert of all prepared info to the dw_configuration table 
		Insert into dw_configuration (entity_type, entity_id, config_key, config_value, description)
		Select 
			1 as entity_type --entity type for study is 1
			,@new_study_id as study_id --id of the newlly added study id
			, config_key, config_value, config_desc
			--, entry_comb, row_id
		from #config 
		--order by 3 

		Commit Transaction [Tr1] --commit transation

--Print 'After Commiting a transaction - @@TRANCOUNT = ' + cast (@@TRANCOUNT as varchar (10))

		IF OBJECT_ID('tempdb..#config') IS NOT NULL DROP TABLE #config
	
	End Try

	Begin Catch
		--declare @error int, @message nvarchar(4000), @ErrorSeverity INT, @ErrorState int;--, @xstate int;

		--collect error info
        select @error = ERROR_NUMBER(),
                 @message = ERROR_MESSAGE(), --, @xstate = XACT_STATE();
				 @ErrorSeverity = ERROR_SEVERITY(),
				 @ErrorState = ERROR_STATE();
		
		--print to console
		print '==========ERROR=================='
		Print 'Error Number: ' + Cast (@error as varchar (20)) + '; Error Message: ' + @message

--Print 'Before Rollback - @@TRANCOUNT = ' + cast (@@TRANCOUNT as varchar (10))

		IF @@TRANCOUNT > 0
			Rollback Transaction [Tr1] --rollback transaction started in the Try section

--Print 'After Rollback - @@TRANCOUNT = ' + cast (@@TRANCOUNT as varchar (10))

		IF OBJECT_ID('tempdb..#config') IS NOT NULL DROP TABLE #config

		--raise error to report it to the parent process
		RAISERROR (@message, -- Message text.
               @ErrorSeverity, -- Severity.
               @ErrorState -- State.
               );
	End Catch

	

End

GO
