USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
exec usp_send_study_tap_report 1 --send report in any case
exec usp_send_study_tap_report 3, 1 --send report only if metadata activity was present on the time of running the stored procedure
*/
CREATE proc [dbo].[usp_send_study_tap_report] (
	@study_id as int
	,@send_only_when_metadata_activity_occurred int = 0 --this parameter will manage if TAP report have to be sent only when metadata receival activity was present on the day of sending TAP report
														--0: TAP report will be always sent.
														--1: TAP report will be sent only if some metadata activity was present.
	)
as
	Begin

	Begin Try

		declare @html_body varchar (max) = '', @html_out varchar (max) = '';
		declare @email_from varchar (50), @email_to varchar (300), @subject varchar (200), @smtp varchar (50),@email_body_type varchar (20);
		declare @study_name varchar (100) = 'Not Defined';
		declare @page_break varchar (200) = '<br/><P style="page-break-before: always">'
		declare @error int, @message nvarchar(4000), @ErrorSeverity INT, @ErrorState int;

		--based on the value of @send_only_when_metadata_activity_occurred property, check if metadata activity was present or not on the day of running TAP procedure
		if isnull(@send_only_when_metadata_activity_occurred, 0) = 1
			Begin 
			--create table #tmp_stats 
			declare @tmp_stats as table 
				(
				study_name varchar (50), 
				[program_name] varchar (50),
				--dict_name varchar (50), 
				api_retrieval_id varchar (50), 
				api_retrieval_status varchar (50), 
				api_status_details varchar (200), 
				api_retrieval_attempts int, 
				records_received_for_period int, 
				process_status varchar (50),
				period_start datetime, 
				period_end datetime
				)
			declare @d as datetime = getdate();

			insert into @tmp_stats exec usp_api_processing_history_studies_for_date @d

			if not exists (select top 1 * from @tmp_stats)
				Begin --abort running TAP report if no metadata activity was found at the time of running the TAP report.
				Print 'No activity was found on "' + cast (@d as varchar (20)) + '" for study id = ' + cast(@study_id as varchar (10)) + '. Based on the parameter @send_only_when_metadata_activity_occurred value supplied, TAP report will be aborted. To force sendng TAP report supply 0 for the given parameter.'
				Return
				End
			End

		--get main TAP report for the given study_id
		exec usp_get_tap_report_html @study_id, 1, @html_out out 
		set @html_body = @html_body + @html_out;

		--get out of TAP scope report for the given study_id (without html styles and main totals)
		exec usp_get_tap_report_html @study_id, 2, @html_out out, 0, 0
		set @html_body = @html_body + @page_break + @html_out;

		--assign main email properties to variables
		Select 
			@email_from = dbo.udf_get_config_value(1, 99, 'tap_report_email_from') --'stas.rirak@mssm.edu',
			,@email_to = dbo.udf_get_config_value(1, 99, 'tap_report_email_to') --'stasrirak.ms@gmail.com, stasrira@yahoo.com',
			,@subject = dbo.udf_get_config_value(1, 99, 'tap_report_email_subject') --'API Activity Stats for {{report_date}}' 
			,@smtp = dbo.udf_get_config_value(1, 99, 'smtpserver')
			,@email_body_type = dbo.udf_get_config_value(1, 99, 'tap_report_email_body_type')

		--Select 
		--	@email_from = 'stas.rirak@mssm.edu',
		--	@email_to = 'stasrirak.ms@gmail.com, stasrira@yahoo.com',
		--	@subject = 'API Activity Stats for {{report_date}}' + convert(varchar (20), @date, 101)

		--insert the current stat date to the subject
		select @subject = REPLACE (@subject, '{{report_date}}', convert(varchar (20), getdate(), 101))
		select @study_name = study_name from dw_studies where study_id = @study_id
		select @subject = REPLACE (@subject, '{{study_name}}', @study_name)

		--execute the send email procedure
		EXEC usp_send_cdosysmail 
			@email_from, --from
			@email_to, --to
			@subject,
			@html_body,
			@smtp,
			@email_body_type

	End Try

	Begin Catch
		select @error = ERROR_NUMBER(),
                 @message = ERROR_MESSAGE(), --, @xstate = XACT_STATE();
				 @ErrorSeverity = ERROR_SEVERITY(),
				 @ErrorState = ERROR_STATE();
		
		--raise error to report it to the parent process
		RAISERROR (@message, -- Message text.
               @ErrorSeverity, -- Severity.
               @ErrorState -- State.
               );

		--set @message = 'Some of internal procedure calls reported errors (see previous messages for details). Aborting execution of the procedure!'
		--RAISERROR (@message, -- Message text.
  --             16, -- Severity.
  --             1 -- State.
  --             );
	End Catch

	End
	
GO
