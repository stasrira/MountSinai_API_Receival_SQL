USE [dw_motrpac]
GO
/****** Object:  StoredProcedure [dbo].[usp_load_single_sample_2019_10_01_SQL2017_version]    Script Date: 2/21/2020 12:46:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--select * from dw_metadata where study_id = 4
/*
exec usp_load_single_sample 
	@study_id = 4, 
	@sample_id ='124B', 
	@json ='{"Col3": "333-&&***", "Col2": "4", "Col4": "zzz", "Col1": "3344", "Col11": "5566"}', 
	@dict_json='{"field": [{"description": "", "encoding": "null", "label": "Col1", "type": "varchar", "name": "Col1"},{"description": "", "encoding": "null", "label": "Col11", "type": "varchar", "name": "Col11"}, {"description": "", "encoding": "null", "label": "Col2", "type": "varchar", "name": "Col2"}, {"description": "", "encoding": "null", "label": "Col3", "type": "varchar", "name": "Col3"}, {"description": "", "encoding": "null", "label": "Col4", "type": "varchar", "name": "Col4"}]}',
	@dict_path='$.field',
	@filepath='E:\MounSinai\MoTrPac_API\ProgrammaticConnectivity\MountSinai_metadata_file_loader\study01\test1.txt',
	@dict_update=1,
	@samlpe_update=1

	--'{"field": [{"description": "", "encoding": "null", "label": "Col1", "type": "varchar", "name": "Col1"}, {"description": "", "encoding": "null", "label": "Col2", "type": "varchar", "name": "Col2"}, {"description": "", "encoding": "null", "label": "Col3", "type": "varchar", "name": "Col3"}, {"description": "", "encoding": "null", "label": "Col4", "type": "varchar", "name": "Col4"}]}',
*/

CREATE proc [dbo].[usp_load_single_sample_2019_10_01_SQL2017_version]
	@study_id int,
	@sample_id varchar (100),
	@json varchar (max),
	@dict_json varchar (max),
	@dict_path as varchar (200) = '', --path inside of the @dict_json leading to the array of fields, i.e. '$.field'
	@filepath varchar (900) = 'N/A', --path of the file where from samlpe is loaded.
	@dict_update bit = 0 --0: not allow, 1: allow - updating dictionary if supplied version is not in sync with saved one
	,@samlpe_update bit = 1 --if equal 1, then updates are allowed, other options - not allowed.
as
	Begin

	SET NOCOUNT ON

	declare @dict_id as int
	declare @outStatus as varchar (30) = '', @outStatusDesc as varchar (max) = ''
	declare @status_failed as varchar (100) = 'Failed'

	--check if @study_id is valid
	if isnull(@study_id, 0) <= 0 or not exists (select * from dw_studies where study_id = @study_id)
		begin
			set @outStatus = @status_failed
			set @outStatusDesc = 'Invalid study_id (' + cast (isnull(@study_id, 'Null') as varchar (20)) + ' was supplied.'
		end 
	
	If len (trim(@outStatus)) = 0 
		--if status is still OK, proceed here
		Begin 

		declare @tmp_metadata add_metadata_tbl

		insert into @tmp_metadata (sample_id, sample_data)
		select @sample_id, @json

		--get dictionary id assigned to study
		select @dict_id = dict_id from dw_studies where study_id = @study_id

		--if @dict_path value was not provided, read it from a config file.
		if len(trim(@dict_path)) = 0 
			Begin
			select @dict_path = isnull(dbo.udf_get_config_value(@dict_id, 2, 'dictionary_path'), dbo.udf_get_config_value(1, 99, 'default_dictionary_path')) --get config value, but if nothing is provided use default from global config entity --'$.field'
			End

		--validate provided dictionary against dictionary saved for study
		declare @dict_valid_result as varchar (30), @dict_valid_msg varchar (max) 
		exec dbo.usp_validate_dictionary @dict_id, @dict_json, @dict_path, @dict_valid_result output, @dict_valid_msg output
				--'{"field": [{"description": "", "encoding": "null", "label": "Col", "type": "varchar", "name": "Col"}, {"description": "", "encoding": "null", "label": "Col2", "type": "varchar", "name": "Col2"}, {"description": "", "encoding": "null", "label": "Col3", "type": "varchar", "name": "Col3"}, {"description": "", "encoding": "null", "label": "Col4", "type": "varchar", "name": "Col4"}]}', 
	
--select @dict_valid_result, @dict_valid_msg --for testing only

		If @dict_valid_result = 'OK' or (@dict_valid_result = 'Update' and @dict_update = 1)
			Begin

			if @dict_valid_result = 'Update'
				Begin 
				update dw_dictionaries set dict_json = @dict_json
				where dict_id = @dict_id
				End

			declare @tb_wrong_column_names as table (sample_id varchar (100), col_names varchar (2000))

			--Validate column names of the provided metadata JSON vs. associated dictionary and report not matching columns
			;with tb_dict as (
				--get list of columns from dictionary
				select df.name dict_col --,s.dict_id, d.dict_json, 
				from dw_dictionaries d 
				CROSS APPLY 
				OpenJson (d.dict_json, @dict_path)
				with (
						[name] varchar (200)
						) df
				where d.dict_id = @dict_id
			)
			--select distinct dict_col from tb_dict
			,tb_sample as (
				--get list of column names from samples
				select m.sample_id, c.[key] sample_col
				from @tmp_metadata m --json_values 
				CROSS APPLY 
				OPENJSON (m.sample_data) c 
				)
			--select * from tb_sample order by 1
			--identify unexpected sample column names
			, wr_col as (
				select *
				from tb_sample s 
				left join tb_dict d on s.sample_col = d.dict_col
				where d.dict_col is null
			)
			insert into @tb_wrong_column_names (sample_id, col_names)
			select
				w.sample_id,
				STUFF ((
					Select ', ' + sample_col
					From wr_col cc
					where cc.sample_id = w.sample_id
					FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS col_names
			from wr_col w
			Group by w.sample_id

	--select * from @tb_wrong_column_names

			If exists (select * from @tb_wrong_column_names)
				Begin 
				set @outStatus = @status_failed
				Select @outStatusDesc = @outStatusDesc + ', ' + cast(sample_id as varchar(10)) + ' -> ' + col_names 
				From @tb_wrong_column_names 
				select @outStatusDesc = 'Columns of the provided samples' + 
							' do not match dictionary''s columns for study id #' + isnull(cast (@study_id as varchar (20)), 'Not Defined') + 
							'. Here is the list of columns grouped by Sample ID: ' + stuff(@outStatusDesc, 1, 2, '')
	--Print @outStatusDesc --for testing only
				End
			
			if @outStatus <> @status_failed
				Begin
				--call common stored procedure to validate received JSON entries
				exec usp_add_metadata_records 
							@study_id, 
							'N/A', 
							@json, 
							@tmp_metadata, 
							'JSON', 
							@samlpe_update

				select @outStatus = 'OK', @outStatusDesc = 'Metadata for sample id "' + isnull(@sample_id, 'Not Defined') + '" was accepted and added. Dictionary Status: "' + isnull(@dict_valid_result, 'N/A') + '"; Status Details: "' + isnull(@dict_valid_msg, 'N/A') + '".'
				End

			End
		Else
			Begin 
				--report failed dictionary validation
				declare @str1 varchar (2000)
				set @outStatus = @status_failed
				if @dict_valid_result = 'Update' and @dict_update <> 1
					begin 
						set @str1 = 'Dictionary validation failed with status  "' + isnull(@dict_valid_result, 'Not Defined') + '", because dictionary updates are not allowed.'
					end
				else
					begin 
						set @str1 = 'Dictionary validation failed with status  "' + isnull(@dict_valid_result, 'Not Defined') + '"."'
					end
				set @outStatusDesc = @str1 + ' Description: "' + isnull(@dict_valid_msg, 'Not Defined') + '".'
			End

		End

		--log attempt of loading sample from file
		Insert into dw_metadata_file_load_log (study_id, sample_id, file_path, [status], status_desc)
		Select @study_id, @sample_id, @filepath, @outStatus, @outStatusDesc

		Select @outStatus as status, @outStatusDesc as description


	End


GO
