USE [dw_motrpac]
GO
/****** Object:  StoredProcedure [dbo].[usp_get_dictionary_ForSQLServer2017]    Script Date: 2/21/2020 12:46:35 PM ******/
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

create proc [dbo].[usp_get_dictionary_ForSQLServer2017] (@dict_id int)
as

;with dict_for_study as (
			--get dictionary json for a given study
			select dict_json 
			from dw_dictionaries d 
			where d.dict_id = 1
		)
		,json_tb as (
			--split dict json string to a table with separate json string for each dict field
			select [key], [value] from OpenJson ((select dict_json from dict_for_study), dbo.udf_get_config_value(@dict_id, 2, 'dictionary_path')) --'$.field'
		)
		--insert into #tmp_dict --insert dictionary map to a temp table
		--convert dictionary field map into a regular table structure
		Select 
		jsf.*, jsf1.*
		from json_tb jst
		CROSS APPLY 
			OPENJSON (jst.[value], '$') --refer to the root of the given JSON array of dictionary fields
			with (
			[name] varchar (200) ,
			[description] varchar (200), 
			label varchar (50), 
			[type] varchar (50)
			) as jsf
		outer APPLY 
			OPENJSON (jst.[value], dbo.udf_get_config_value(@dict_id, 2, 'encoding_path')) --'$.encoding'
			with (
			[code] varchar (200), 
			[value] varchar (200)
			) as jsf1
GO
