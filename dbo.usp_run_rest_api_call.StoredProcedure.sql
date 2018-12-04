USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* --usage example
declare @json varchar (max) = '' 
declare @ret_val int
declare @config_tbl config_values_tbl -- temp table to store config key/value pairs for the given study id
--get all configuration items for the given study_id into a temp table
insert into @config_tbl (config_key, config_value) 
select config_key, config_value from dbo.udf_get_all_config_value (1)

exec @ret_val = usp_run_rest_api_call 1, 'TST999-00200', @config_tbl, 	@json out	--'TST999-00403' --'TST999-00200'
print @ret_val
print @json
*/
/*
This procedure will perform actual API call based on provided parameters. It returns '1' for successful outcome and '-1' for error outcome.
It will log API communicatin errors using "usp_log_api_error" proc.
@json output variable will retrun the actual value returned by API 
*/
CREATE proc [dbo].[usp_run_rest_api_call] (
@study_id int,
@mid varchar (20),
@config_tbl config_values_tbl readonly,
@json varchar (max) out
)
as

Begin
	declare @str varchar (max);
	declare @first_chars int = 100; --number of characters of JSON string to be saved to log table
	declare @api_log_id bigint, @hr int, @Object Int;
	declare @URL varchar (200);
	declare @uid varchar (50), @pwd varchar (100);
	declare @accept_hdr varchar (50), @api_method varchar (50);
	declare @return_val int = -1

	create table #json (Json_Table varchar(max))


	exec usp_get_config_value_local @config_tbl, 'api_url', @URL out
	exec usp_get_config_value_local @config_tbl, 'api_user', @uid out
	exec usp_get_config_value_local @config_tbl, 'api_pwd', @pwd out
	exec usp_get_config_value_local @config_tbl, 'api_accept_header', @accept_hdr out
	exec usp_get_config_value_local @config_tbl, 'api_method', @api_method out

	set @URL = @URL + @mid --add mid value to the URL

	select --combine study info for log table entry
		@str = 'Study ID: ' + cast(min(study_id) as varchar(20)) + '; Study Name: ' + min(study_Name) +  '; Manifest ID: ' + isnull(@mid, 'Unknown')
	from dw_studies where study_id = @study_id
	exec @api_log_id = usp_update_api_communication_log 0, @mid, 'API call was initiated', @str, 'Command' --log start API connection session
	set @str = '' --reset @str

	Exec @hr=sp_OACreate 'MSXML2.ServerXMLHTTP.6.0', @Object OUT;
	IF @hr <> 0 
		Begin
		--report error to dw_api_communication_log table
		exec usp_log_api_error @api_log_id, @Object, @mid, 'sp_OACreate ''MSXML2.ServerXMLHTTP.6.0'''
		RETURN @return_val --break the execution
		End
	
	Exec @hr=sp_OAMethod @Object, 'open', NULL, @api_method, --'get',
					 @URL						--https://www.motrpac.org/rest/motrpacapi/biospecimen/ANI870-10000' --Your Web Service Url (invoked)
					 ,'false', @uid, @pwd --'stas.rirak@mssm.edu', 'BB846687-038A-D5BE-0509801DBBD95124' --@uid, @pwd--
	--IF @hr <> 0 EXEC sp_OAGetErrorInfo @Object
	IF @hr <> 0 
		Begin
		--report error to dw_api_communication_log table
		exec usp_log_api_error @api_log_id, @Object, @mid, 'sp_OAMethod ''Open'''
		RETURN @return_val --break the execution
		End

	Exec @hr=sp_OAMethod @Object, 'SetRequestHeader', NULL, 'Accept', @accept_hdr --'application/xml' --'application/json'
	--IF @hr <> 0 EXEC sp_OAGetErrorInfo @Object
	IF @hr <> 0 
		Begin
		--report error to dw_api_communication_log table
		exec usp_log_api_error @api_log_id, @Object, @mid, 'sp_OAMethod ''SetRequestHeader'''
		RETURN @return_val --break the execution
		End

	Exec @hr=sp_OAMethod @Object, 'send'
	--IF @hr <> 0 EXEC sp_OAGetErrorInfo @Object
	IF @hr <> 0 
		Begin
		--report error to dw_api_communication_log table
		exec usp_log_api_error @api_log_id, @Object, @mid, 'sp_OAMethod ''Send'''
		RETURN @return_val --break the execution
		End
	
	exec usp_update_api_communication_log @api_log_id, @mid, 'API Request Sent', @URL, 'Command' --log successful API send request 	

	--retrieve a response from API
	INSERT into #json (Json_Table) exec sp_OAGetProperty @Object, 'responseText'
	select @json = json_table from #json --save received JSON into the output variable
--print @json --for testing only

	select @str = 'Total length: ' + cast(len(Json_Table) as varchar(20)) + ', First ' + cast (@first_chars as varchar(20)) + ' characters: "' + left(Json_Table, @first_chars) + '..."' from #json
--Print @str
	exec usp_update_api_communication_log @api_log_id, @mid, 'API Response Received', @str, 'Command' --log successful receival of the response
	set @str = ''

	--close API connection 
	EXEC sp_OADestroy @Object

	exec usp_update_api_communication_log @api_log_id, @mid, 'API Coonection closed', 'Coonection closed', 'Command' --log successful receival of the response

	--update @return_val to OK outcome value 
	set @return_val = 1
	Return @return_val

End
GO
