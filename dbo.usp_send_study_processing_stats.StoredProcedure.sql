USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--usp_send_study_processing_stats '12/14/2018' --usage example
CREATE proc [dbo].[usp_send_study_processing_stats] (
@date as datetime = null
) 
as

--declare @date datetime = '12/14/2018' --for testing only
declare @email_from varchar (50), @email_to varchar (300), @subject varchar (200), @smtp varchar (50),@email_body_type varchar (20);

--assign default date as Today
if @date is null 
	Begin 
	set @date = getdate();
	End


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

insert into @tmp_stats exec usp_api_processing_history_studies_for_date @date --TODO: put @date variable instead of the hardcoded date
--select * from @tmp_stats --for tesing only

declare @str varchar (max) = '', @html varchar (max);

--main HTML body of the email
set @html = '
<head>
<style>
table {
  font-family: arial, sans-serif;
  border-collapse: collapse;
  width: 100%;
}

td, th {
  border: 1px solid #dddddd;
  text-align: left;
  padding: 8px;
}

tr:nth-child(even) {
  background-color: #dddddd;
}
</style>
</head>

<h2>
API Retrieval stats on {{report_date}}
</h2>

<table>
<tr>
	<th>Study</th>
	<th>Program</th>
	<th>Api_retrieval_id</th>
	<th>Api_retrieval_status</th>
	<th>Api_status_details</th>
	<th>Api_retrieval_attempts</th>
	<th>Records Num</th>
	<th>Records Status</th>
</tr>
{{table_content}}
</table>
'

--collect content of the report into the @str variable
select @str = @str + '
<tr>
	<td>' + study_name + '</td>
	<td>' + [program_name] + '</td>
	<td>' + api_retrieval_id + '</td>
	<td>' + api_retrieval_status + '</td>
	<td>' + api_status_details + '</td>
	<td>' + cast (api_retrieval_attempts as varchar (10)) + '</td>
	<td>' + cast (records_received_for_period as varchar (10)) + '</td>
	<td>' + process_status + '</td>
</tr>
'
from @tmp_stats

--print @str

--insert the reporting date to the main template
set @html = REPLACE (@html, '{{report_date}}', convert(varchar (20), @date, 101));


--insert content of the report to the main template
set @html = REPLACE (@html, '{{table_content}}', @str);

--check if no content was reported, add "No activity" note
if len(@str) = 0 
	Begin
		set @html = @html + 
			'
			<h3>No activity reported...</h3>
			'
	end

--print @html

--assign main email properties to variables
Select 
	@email_from = dbo.udf_get_config_value(1, 99, 'api_stats_from_email') --'stas.rirak@mssm.edu',
	,@email_to = dbo.udf_get_config_value(1, 99, 'api_stats_to_email') --'stasrirak.ms@gmail.com, stasrira@yahoo.com',
	,@subject = dbo.udf_get_config_value(1, 99, 'api_stats_email_subject') --'API Activity Stats for {{report_date}}' 
	,@smtp = dbo.udf_get_config_value(1, 99, 'smtpserver')
	,@email_body_type = dbo.udf_get_config_value(1, 99, 'api_stats_email_body_type')

--Select 
--	@email_from = 'stas.rirak@mssm.edu',
--	@email_to = 'stasrirak.ms@gmail.com, stasrira@yahoo.com',
--	@subject = 'API Activity Stats for {{report_date}}' + convert(varchar (20), @date, 101)

--insert the current stat date to the subject
select @subject = REPLACE (@subject, '{{report_date}}', convert(varchar (20), @date, 101))

--execute the send email procedure
EXEC usp_send_cdosysmail 
	@email_from, --from
	@email_to, --to
	@subject,
	@html,
	@smtp,
	@email_body_type
GO
