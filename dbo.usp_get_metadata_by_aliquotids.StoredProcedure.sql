USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Procedure accepts list of aliquot_ids, maps those to sample_ids (using dw_sample_aliquot_mapping table) and returns metadata for the identified samples. 
Number of returned datasets will be defined by number of study ids the identified samples belong to.
For examlple, if given samples belong to 2 studies, the procedure will return 2 data sets.
Final return dataset will include the aliquot_id it was mapped to. 
In case the same aliquot mapped to 2 studies, it will be included into output of each dataset of a matching study.

exec usp_get_metadata_by_aliquotid 'AS06-11984_1, AS07-07650_1,AS07-10643_1, DU19-01S0003431_1,DU19-01S0003446_1'
exec usp_get_metadata_by_aliquotid 'AS06-11984_1| AS07-07650_1|AS07-10643_1| DU19-01S0003431_1|DU19-01S0003446_1', '|', 8
exec usp_get_metadata_by_aliquotid ''
*/
create proc [dbo].[usp_get_metadata_by_aliquotids] 
	(
	@alids varchar (max), 
	@delim varchar (1) = ',',
	@study_id int = -1
	)
	as

	Begin
	SET NOCOUNT ON

	--declare @alids varchar (4000), @delim varchar (1) = '|';  --for testing only
	--set @alids = 'AS06-11984, AS07-07650,AS07-10643, DU19-01S0003431,DU19-01S0003446'
	--set @alids = 'AS06-11984| AS07-07650|AS07-10643| DU19-01S0003431|DU19-01S0003446'
	--============ testing: modified sample id!!! 90001013001; replaced with 90001015502, study_id 3

	declare @sql nvarchar (max) = '';
	declare @proc_name varchar (50) = 'dbo.usp_get_metadata';
	declare @study_id_cur int, @cur_row int, @sample_ids_cur varchar (max) = ''

	declare @t_alids as table (alid varchar (100)); --this table will hold split list of submitted Sample_Ids
	Insert into @t_alids (alid)
	SELECT ltrim(rtrim(value)) FROM STRING_SPLIT(isnull(@alids,''), @delim);

	--select * from @t_alids

	if exists (
		select top 1 * 
		from dw_sample_aliquot_mapping m
		where m.aliquot_id in (select alid from @t_alids)
		) 
		Begin

		;with samples as (
			select s.sample_id
			from dw_sample_aliquot_mapping s 
			inner join @t_alids a on s.aliquot_id = a.alid 
		)
		,study_samples as (
			select s.study_id, s.sample_id
			from dw_metadata s 
			inner join samples a on s.sample_id = a.sample_id
			where (s.study_id = @study_id or @study_id < 0)
		)
		--select * from study_samples
		, final_study_samples as (
			select 
				ROW_NUMBER() OVER (ORDER BY m.study_id) row_num,
				m.study_id,
				--comma delimited list of sample_ids for the given dict_id
				STUFF((SELECT @delim + cast(s2.sample_id as varchar (100))
						from study_samples s2
						where s2.study_id = m.study_id
						group by s2.study_id, s2.sample_id
						ORDER BY s2.sample_id
						FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'') 
				as sample_ids
			from dw_metadata m
			inner join study_samples s on m.sample_id = s.sample_id
			--where m.sample_id in (select sample_id from study_samples)
			group by m.study_id
		)
		select * into #samples from final_study_samples

		--select * from #samples --for testing only

		Set @cur_row = 1
		while exists (select * from #samples)
		begin

			select 
				@study_id_cur = study_id,
				@sample_ids_cur = sample_ids
			from #samples
			where row_num = @cur_row

			
			create table #test1 ([#test1] int)
			
			exec dbo.usp_get_metadata @study_id = @study_id_cur, @sample_ids = @sample_ids_cur, @sample_delim =  @delim, @tb_out_name = '#test1'

			select a.alid as aliquot_id, t.* 
			from #test1 t 
			left join dw_sample_aliquot_mapping s on t.sample_id = s.sample_id
			inner join @t_alids a on s.aliquot_id = a.alid

			drop table #test1

			delete #samples
			where row_num = @cur_row

			select @cur_row = @cur_row + 1

		end

		drop table #samples

		End
	End

GO
