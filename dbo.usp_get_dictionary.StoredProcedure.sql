USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*
Usage examples:
--1) simple call of the procedure
--usp_get_dictionary 1 --usage example

--2) Save output to a temp table
create table #dict (
	dictionary_id int,
	name varchar (50),
	description varchar (200), 
	label varchar (50),
	type varchar (20),
	code int,
	value varchar (200)
	)
Insert into #dict exec usp_get_dictionary 1
select * from #dict
drop table #dict
*/

CREATE proc [dbo].[usp_get_dictionary] (@dict_id int)
as
	Set nocount on

	declare @str varchar (max) = '';
	--This creates a dynamic statement to open JSON containing dictionary fields 
	--This created as a dynamic statement because SQL Server 2016 does not allow pass variables for Path parameter of the OpenJson functions. This is not an issue in 2017 version.
	set @str = 
	'
	;with dict_for_study as (
		--get dictionary json for a given study
		select dict_json 
		from dw_dictionaries d 
		where d.dict_id = ' + cast (@dict_id as varchar(20)) + '
	)
	,json_tb as (
		--split dict json string to a table with separate json string for each dict field
		select [key], [value] from OpenJson ((select dict_json from dict_for_study), ''' 
		--+ dbo.udf_get_config_value(@dict_id, 2, 'dictionary_path') + ''') --''$.field''
		+ isnull(dbo.udf_get_config_value(@dict_id, 2, 'dictionary_path'), dbo.udf_get_config_value(1, 99, 'default_dictionary_path')) + ''')
	)
	--convert dictionary field map into a regular table structure
	Select 
	' + cast(@dict_id as varchar(10)) + ' as dictionary_id, 
	jsf.*, isnull(jsf1.code, '''') as code, isnull(jsf1.value,'''') as value
	from json_tb jst
	CROSS APPLY 
		OPENJSON (jst.[value], ''$'') --refer to the root of the given JSON array of dictionary fields
		with (
		[name] varchar (200) ,
		[description] varchar (200), 
		label varchar (50), 
		[type] varchar (50)
		) as jsf
	outer APPLY 
		OPENJSON (jst.[value], ''' 
		--+ dbo.udf_get_config_value(@dict_id, 2, 'encoding_path') 
		+ isnull(dbo.udf_get_config_value(@dict_id, 2, 'encoding_path'), dbo.udf_get_config_value(1, 99, 'default_encoding_path'))
		+ ''') --''$.encoding''
		with (
		[code] varchar (200), 
		[value] varchar (200)
		) as jsf1
	'
--Print @str --for testing only
	exec (@str)
GO
