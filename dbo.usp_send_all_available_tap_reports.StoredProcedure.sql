USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*--use example
usp_send_all_available_tap_reports 
usp_send_all_available_tap_reports 1
usp_send_all_available_tap_reports 1, '1,2,3'
*/
CREATE proc [dbo].[usp_send_all_available_tap_reports]
(
	@send_only_when_metadata_activity_occurred int = 0 --this parameter will manage if TAP report have to be sent only when metadata receival activity was present on the day of sending TAP report
														--0: TAP report will be always sent.
														--1: TAP report will be sent only if some metadata activity was present.
	,@exclude_study_ids varchar (500) = '' --expected list of study ids in a comma delimited format
)
as
	BEGIN

	Begin try

		declare @sql as nvarchar (max), @studies_num int;
		declare @error int, @message nvarchar(4000), @ErrorSeverity INT, @ErrorState int;

		create table #studies (study_id int);

		;with tap_studies as (
			select study_id--, count(*) tap_num
			from dw_tap_settings 
			group by study_id
			)
		, metadata_studies as (
			select study_id--, count (*) study_num
			from dw_metadata
			group by study_id
			)
		Insert into #studies (study_id)
		Select m.study_id 
		from metadata_studies m 
		inner join tap_studies t on m.study_id = t.study_id

--select * from #studies

--print len(ltrim(rtrim(@exclude_study_ids)))

		if len(ltrim(rtrim(@exclude_study_ids))) > 0 
		Begin 
			set @sql = 'Delete from #studies where study_id in (' + @exclude_study_ids + ')';
--print @sql;
			exec sp_executesql @sql; --execute prepared SQL string
		End

		set @sql = ''
		--prepare script for calling stored procedure usp_send_study_tap_report for every study id availalble for TAP reports
		select
			@sql = @sql + 
				'exec usp_send_study_tap_report ' 
				+ cast (study_id as varchar (10)) + ', ' 
				+ cast (@send_only_when_metadata_activity_occurred as varchar(10)) + '; '
		from #studies
print @sql --for testing only
		
		select @studies_num = count(*) from #studies

--print '@studies_num = ' + cast (@studies_num as varchar (10));

		Print '==>>> ' + cast (@studies_num as varchar (10)) + ' TAP reports are being processed.'

		exec sp_executesql @sql; --execute prepared SQL string

		--drop table #studies
		IF OBJECT_ID('tempdb..#studies') IS NOT NULL DROP TABLE #studies

	End Try

	Begin Catch

		select @error = ERROR_NUMBER(),
                 @message = ERROR_MESSAGE(), --, @xstate = XACT_STATE();
				 @ErrorSeverity = ERROR_SEVERITY(),
				 @ErrorState = ERROR_STATE();
		
		--drop table #studies
		IF OBJECT_ID('tempdb..#studies') IS NOT NULL DROP TABLE #studies

		--raise error to report it to the parent process
		RAISERROR (@message, -- Message text.
               @ErrorSeverity, -- Severity.
               @ErrorState -- State.
               );
	
	End Catch

	END

	
GO
