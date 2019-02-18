USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
exec usp_send_study_tap_report 2
*/
CREATE proc [dbo].[usp_send_study_tap_report] (
	@study_id as int
	)
as
	Begin
	declare @html_body varchar (max) = '', @html_out varchar (max) = '';
	declare @email_from varchar (50), @email_to varchar (300), @subject varchar (200), @smtp varchar (50),@email_body_type varchar (20);
	declare @study_name varchar (100) = 'Not Defined';
	declare @page_break varchar (200) = '<br/><P style="page-break-before: always">'

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

	End
	
GO
