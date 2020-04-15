USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Procedure accepts list of sample_ids and returns metadata for the given samples. 
Number of returned datasets will be defined by number of study ids the samples belong to.
For examlple, if given samples belong to 2 studies, the procedure will return 2 data sets. 

Example of execution:
exec usp_get_metadata_by_sampleids 'AS06-11984, AS07-07650,AS07-10643, DU19-01S0003431,DU19-01S0003446'
exec usp_get_metadata_by_sampleids 'AS06-11984, AS07-07650,AS07-10643, DU19-01S0003431,DU19-01S0003446', @show_dataset_separators = 1, @output_headers_as_dataset = 1
exec usp_get_metadata_by_sampleids 'AS06-11984| AS07-07650|AS07-10643| DU19-01S0003431|DU19-01S0003446', '|'
exec usp_get_metadata_by_sampleids ''
*/
CREATE proc [dbo].[usp_get_metadata_by_sampleids] 
	(
	@sids varchar (max), 
	@delim varchar (1) = ',',
	@study_id int = -1,
	@show_dataset_separators int = 0, 
	@output_headers_as_dataset int = 0
	)
	as

	Begin
	SET NOCOUNT ON

	--declare @sids varchar (4000), @delim varchar (1) = '|';  --for testing only
	--set @sids = 'AS06-11984, AS07-07650,AS07-10643, DU19-01S0003431,DU19-01S0003446'
	--set @sids = 'AS06-11984| AS07-07650|AS07-10643| DU19-01S0003431|DU19-01S0003446'
	--============ testing: modified sample id!!! 90001013001; replaced with 90001015502, study_id 3

	declare @sql nvarchar (max) = '', @sql_templ nvarchar(max) = '';
	declare @proc_name varchar (50) = 'dbo.usp_get_metadata';
	declare @study_id_cur int, @cur_row int, @sample_ids_cur varchar (max) = ''

	declare @t_sids as table (sid varchar (100)); --this table will hold split list of submitted Sample_Ids
	Insert into @t_sids (sid)
	SELECT ltrim(rtrim(value)) FROM STRING_SPLIT(isnull(@sids,''), @delim);

	--select * from @t_sids

	if exists (
		select top 1 * 
		from dw_metadata m
		where m.sample_id in (select sid from @t_sids)
		) 
		Begin

		;with study_samples as (
			select s.study_id, s.sample_id
			from dw_metadata s 
			inner join @t_sids a on s.sample_id = a.sid
			where (s.study_id = @study_id or @study_id < 0)
			)
		--select * from study_samples
		, samples as (
			select
				ROW_NUMBER() OVER (ORDER BY m.study_id) row_num,
				m.study_id
				--comma delimited list of sample_ids for the given dict_id
				--,STUFF((SELECT N',' + cast(s2.sample_id as varchar (100))
				,STUFF((SELECT @delim + cast(s2.sample_id as varchar (100))
					from study_samples s2
					where s2.study_id = m.study_id
					group by s2.study_id, s2.sample_id
					ORDER BY s2.sample_id
					FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'') as sample_ids
			from dw_metadata m
			inner join study_samples s on m.sample_id = s.sample_id
			group by m.study_id
			)
		--select * from samples
		select * into #samples from samples

		/*
		--prepare SQL script to retrieve metadata 
		select @sql = @sql + 'exec ' + @proc_name + ' @study_id = ' + cast(study_id as varchar (10)) + ', @sample_ids = ''' + sample_ids + ''', @sample_delim =  ''' + @delim + '''; '
		from samples
		
		--print @sql

		exec sp_executesql @sql;
		*/

		Set @cur_row = 1
		while exists (select * from #samples)
		begin
			
			if @show_dataset_separators = 1 and @cur_row > 1
				Begin
				Select '============> Dataset # ' + cast (@cur_row as varchar (10)) + ' <==============='
				End

			select 
				@study_id_cur = study_id,
				@sample_ids_cur = sample_ids
			from #samples
			where row_num = @cur_row

			create table #test1 ([#test1] int)
			
			exec dbo.usp_get_metadata @study_id = @study_id_cur, @sample_ids = @sample_ids_cur, @sample_delim =  @delim, @tb_out_name = '#test1'
			--exec dbo.usp_get_metadata @study_id = @study_id_cur, @sample_ids = @sample_ids_cur, @sample_delim =  @delim

			if @output_headers_as_dataset = 1
				Begin
				select @sql = ''

				--get list of column in the output table
				;with col_list as (
					--select 'aliquot_id' as name --add aliquot_id column to the list of columns
					--Union
					Select TOP 10000 name 
					From  Tempdb.Sys.Columns Where Object_ID = Object_ID('tempdb..#test1')
					order by column_id
					)
				select @sql = @sql + '''' + name + ''' as [' + name + '],'
				from col_list

				--output list of columns before outputing the actual dataset
				--this approach is needed if the query is executed from linux and headers of datasets are not shown
				set @sql = 'Select ' + left(@sql, len(@sql) - 1)

				--print @sql
				exec sp_executesql @sql;
				End

			select * from #test1

			drop table #test1

			delete #samples
			where row_num = @cur_row

			select @cur_row = @cur_row + 1

		end

		drop table #samples

		End
	End
GO
