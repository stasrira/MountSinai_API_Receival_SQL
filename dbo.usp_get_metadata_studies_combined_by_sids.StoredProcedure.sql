USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
exec usp_get_metadata_studies_combined_by_sids '99920015501, 99920015801,  80000885507,90001015204, 90001015502'

*/
CREATE proc [dbo].[usp_get_metadata_studies_combined_by_sids] 
	(
	@sids varchar (4000), 
	@delim varchar (4) = ','
	)
	as

	Begin
	SET NOCOUNT ON

	--declare @sids varchar (4000), @delim varchar (4) = ',';  --for testing only
	--set @sids = '99920015501, 99920015801,  80000885507,90001015204, 90001015502' --80000885506,90001013001
	--============ testing: modified sample id!!! 90001013001; replaced with 90001015502, study_id 3

	declare @sql nvarchar (max) = '';
	declare @proc_name varchar (50) = 'dbo.usp_get_metadata_studies_combined';

	declare @t_sids as table (sid varchar (100)); --this table will hold split list of submitted Sample_Ids
	Insert into @t_sids (sid)
	SELECT ltrim(rtrim(value)) FROM STRING_SPLIT(isnull(@sids,''), @delim);

	----for testing only
	--select s.dict_id, s.study_id, m.sample_id
	--from dw_metadata m
	--inner join dw_studies s on m.study_id = s.study_id
	--where m.sample_id in (select sid from @t_sids)
	--group by s.dict_id, s.study_id, m.sample_id

	--table to store stats for the data being output
	declare @t_dict as table (
		dict_id int, 
		study_ids varchar(1000), 
		sample_ids varchar (max),
		rec_cnt int)

	--Dataset #1. 
	--Presents dictionaries with list of studies, list of sample ids reported and total records count (per each dictionary)
	;with dict_study as (
		select s.dict_id, s.study_id, m.sample_id
		from dw_metadata m
		inner join dw_studies s on m.study_id = s.study_id
		where m.sample_id in (select sid from @t_sids)
		group by s.dict_id, s.study_id, m.sample_id
	)
	insert into @t_dict (dict_id, rec_cnt, study_ids, sample_ids)
	select s.dict_id, count(*) rec_cnt
		--comma delimited list of studies for the given dict_id
		,STUFF((SELECT N',' + cast(s2.study_id as varchar (10))
			from dict_study s2 	
			where 
			s2.dict_id = s.dict_id
			group by s2.dict_id, s2.study_id
			ORDER BY s2.study_id
			FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'') as study_ids
		--comma delimited list of sample_ids for the given dict_id
		,STUFF((SELECT N',' + cast(s2.sample_id as varchar (100))
			from dict_study s2 	
			where 
			s2.dict_id = s.dict_id
			group by s2.dict_id, s2.sample_id
			ORDER BY s2.sample_id
			FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'') as sample_ids
	from dict_study s
	group by s.dict_id

	--output Dataset #1
	select * from @t_dict 

	--Dataset #2. 
	--Presentes a dataset showing sample ids belonging to more than one study (if any). If not such samples found, the recordset will be empty
	--Displays a Sample ID with total count and comma delimited list of studies it belongs to
	;with dict_study as (
		select s.dict_id, s.study_id, m.sample_id
		from dw_metadata m
		inner join dw_studies s on m.study_id = s.study_id
		where m.sample_id in (select sid from @t_sids)
		group by s.dict_id, s.study_id, m.sample_id
		)
	select sample_id, count (study_id) studies_cnt
		,STUFF((SELECT N',' + cast(s2.study_id as varchar (10))
			from dict_study s2 	
			where 
			s2.sample_id = s.sample_id
			group by s2.sample_id, s2.study_id
			ORDER BY s2.study_id
			FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'') as study_ids
	from dict_study s
	group by sample_id
	having count (study_id) > 1

	--Dataset #3 -#N
	--prepare SQL script to retrieve metadata 
	select @sql = @sql + 'exec ' + @proc_name + ' @study_ids = ''' + study_ids + ''', @sample_ids = ''' + sample_ids + ''' ; '
	from @t_dict

	--print @sql; for testing only

	--this will output one dataset for each dictionary id recorded in the @t_dict table
	--execute the created SQL strings
	exec sp_executesql @sql;

	End
GO
