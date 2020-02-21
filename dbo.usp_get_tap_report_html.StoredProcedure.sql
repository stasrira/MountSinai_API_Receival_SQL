USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
--main TAP report
declare @html_out varchar (max);
exec usp_get_tap_report_html 1, 1, @html_out out,1
print @html_out;

declare @html_out varchar (max);
exec usp_get_tap_report_html 1, 1, @html_out out, 0 --no styles included
print @html_out;

--out of scope TAP report
declare @html_out varchar (max);
exec usp_get_tap_report_html 1, 2, @html_out out
print @html_out;
*/
CREATE proc [dbo].[usp_get_tap_report_html] (
	 @study_id as int
	,@report_type as int = 1 --expected types: 1 (regular report)-TAP vs Metadata report; 2(out of scope report)-Metadata vs TAP (where TAP was not set)
	,@html_out as varchar (max) output
	,@include_html_styles as int = 1 --expected values: 1: inlculde HTML styles; 0: do not include HTML styles
	,@include_main_totals as int = 1 --main totals can be present only for the regular TAP report (@report_type=1). Expected values: 1: inlculde main total counts on the begining of the report; 0: do not include main totals
	)
as

	Begin 

	declare @temp_tb_name varchar (100) = '#tap_data'
	declare @html varchar (max) = '', @html_style varchar (max) = '',@html_totals varchar (max) = '';
	--, @script varchar (max) = ''
	declare @str varchar (max) = '', @str1 varchar (max) = '';
	declare @rep_title varchar (200) = '', @study_name as varchar (100) = 'Not Defined';
	declare @total_tap_count int, @total_tap_received_count int, @total_metadata_count int
	declare @error int, @message nvarchar(4000), @ErrorSeverity INT, @ErrorState int;

	--populate temp table with tap report info
	create table #tap_data ([#tap_data] int)
	exec usp_get_tap_report_dataset @study_id, @report_type, @temp_tb_name, 1 --'#tap_data'
--select * from #tap_data --for testing only
	--drop table #tap_data

	--check if metadata is available for the current program
	--if not exists (select top 1 * from #tap_data)
	--	Begin
	--	--raise error reporting that no tap_data is present for the study_id
	--	set @message = 'The system could not produce TAP data for study_id = ' + cast (@study_id as varchar (10)) + '. Aborting execution of the procedure!'
		
	--	IF OBJECT_ID('tempdb..#tap_data') IS NOT NULL DROP TABLE #tap_data
		
	--	RAISERROR (@message, -- Message text.
 --              16, -- Severity.
 --              1 -- State.
 --              );

	--	Return;
	--	End

	--get study name
	select @study_name = study_name from dw_studies where study_id = @study_id

	--calculate main totals only for the main TAP report
	If @report_type = 1 
		Begin
		--get main totals------------------------
		select 
			@total_tap_count = isnull(sum(sample_count), 0), 
			@total_tap_received_count = isnull(sum(received_count), 0) 
		from #tap_data

		select @total_metadata_count = isnull(count(*), 0)
		from dw_metadata
		where study_id = @study_id
		end 

	set @rep_title =
		Case @report_type 
			When 1 then '"{{study_name}}" - Metadata TAP Report'
			When 2 then '"{{study_name}}" - Metadata Out of TAP Scope'
			else 'Title was not defined for this report type.'
		end

	create table #html_body (html varchar (max));

	set @html_style = '
	<head>
	<style>
		table {
		  font-family: arial, sans-serif;
		  border-collapse: collapse;
		  width: 80%;
		}

		td {
		  border: 1px solid #dddddd;
		  text-align: left;
		  padding: 8px;
		}

		th {
		  border: 1px solid #dddddd;
		  padding: 8px;
		  text-align: center;
		}

		tr:nth-child(even) {
		  background-color: #dddddd;
		}

		.OK {
		  color: green;
		  font-weight: normal;
		 }

		 .yellow_flag {
		  color: DarkOrange;
		  font-weight: bold;
		 }

		 .red_flag {
		  color: red;
		  font-weight: bold;
		 }

		 .totals {
		  text-align:center;
		  font-weight: bold;
		  }
	</style>
	</head>
	'
	--set @script = '
	--<script>
	--function selectElementContents(el) {
	--	var range = document.createRange();
	--	range.selectNodeContents(el);
	--	var sel = window.getSelection();
	--	sel.removeAllRanges();
	--	sel.addRange(range);
	--}
	--function highlight_element(elem_id) {
	--	var el = document.getElementById(elem_id);
	--	selectElementContents(el);
	--	document.execCommand(''copy'');
	--}
	--</script>
	--'

	if @report_type = 1 and @include_main_totals = 1 
		Begin
		--set @html_totals only, if @include_main_totals is set to 1
		Set @html_totals = '
			<h2>
			"{{study_name}}" - Sample Totals as of {{report_date}}
			</h2>

			<table>
			<tr>
				<th>Total Received</th>
				<th>TAP Expected</th>
				<th>TAP Received</th>
				<th>Out Of TAP Plan</th>
			</tr>
			<tr>
				<td class="totals">{{Total Received}}</td>
				<td class="totals">{{TAP Expected}}</td>
				<td class="totals">{{TAP Received}}</td>
				<td class="totals">{{Out Of TAP Plan}}</td>
			</tr>
			</table>
			'
		End

	--main HTML body of the email
	set @html = '
		{{html_style}}
		{{main_totals}}
		<h2>
		{{report_title}} as of {{report_date}}
		</h2>
		<table id="tbl' + cast(@report_type as varchar (10)) + '">
		<tr>
			{{table_headers}}
		</tr>
		{{table_content}}
		</table>
		'
	select 
		--c.name --, t.name, c.precision 
		@str = @str + '<th>' + 
			case c.name
				when 'sample_count' then 'Expected'
				when 'received_count' then 'Received'
				when 'diff_count' then 'Status'
				else
					c.name
			end 
			 + '</th>',
		@str1 = @str1 +  
			case c.name
				when 'diff_count' then 
					'''<td'' + ' +
					'Case ' + c.name + '
						when ''OK'' then '' class="OK" ''
						when ''LESS'' then '' class="red_flag" ''
						when ''EXTRA'' then '' class="yellow_flag" '' 
					end'
					+ ' + ''>'' + ' +
					'cast([' + c.name + '] as varchar (200))'
				else
					'''<td>'' + ' + 'cast([' + c.name + '] as varchar (200))'
			end 
			 + ' + ''</td>''+'

	from Tempdb.Sys.Columns c 
	inner join Tempdb.Sys.objects o on o.object_id = c.object_id 
	inner join Tempdb.Sys.types t on c.system_type_id = t.system_type_id
	where c.Object_ID = Object_ID('tempdb..' + @temp_tb_name)
	order by column_id

	--replace all postfix "_code" with " code" to allow column headers to be wrapped when viewed in web browser
	set @str = REPLACE (@str, '_code', ' code');
	--replace all postfix "_value" with " value" to allow column headers to be wrapped when viewed in web browser
	set @str = REPLACE (@str, '_value', ' value');
	--print @str;

	set @str1 = left(rtrim(@str1), len(rtrim(@str1)) - 1) 
	set @str1 = 'insert into #html_body (html) Select ' + @str1 + ' as html from #tap_data ' --original code
	--set @str1 = 'insert into #html_body (html) Select top 10 ' + @str1 + ' as html from #tap_data ' --for testing only
	--print @str1;

	exec (@str1);

	set @str1 = ''
	--select top 20 @str1 = @str1 + '<tr>' + html + '</tr>' from #html_body --for testing only !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	select @str1 = @str1 + '<tr>' + html + '</tr>' from #html_body --commented for testing only
	
	--select * from #html_body -- for testing only
	IF OBJECT_ID('tempdb..#html_body') IS NOT NULL DROP TABLE #html_body
	IF OBJECT_ID('tempdb..#tap_data') IS NOT NULL DROP TABLE #tap_data

	--insert HTML content to the HTML template
	set @html = REPLACE (@html, '{{table_headers}}', @str);
	set @html = REPLACE (@html, '{{table_content}}', @str1);

	--update @html_totals with calculated values
	set @html_totals = REPLACE(@html_totals, '{{Total Received}}', cast (isnull(@total_metadata_count, '') as varchar (10)));
	set @html_totals = REPLACE(@html_totals, '{{TAP Expected}}', cast(isnull(@total_tap_count, '') as varchar (10)));
	set @html_totals = REPLACE(@html_totals, '{{TAP Received}}', cast (isnull(@total_tap_received_count, '') as varchar (10)));
	set @html_totals = REPLACE(@html_totals, '{{Out Of TAP Plan}}', cast(isnull((@total_metadata_count - @total_tap_received_count), '') as varchar (10)));

	--replace report title place holder with the actual title
	set @html = REPLACE (@html, '{{main_totals}}', @html_totals);
	
	--insert the reporting date to the main template
	set @html = REPLACE (@html, '{{report_date}}', convert(varchar (20), getdate(), 101));
	--replace report title place holder with the actual title
	set @html = REPLACE (@html, '{{report_title}}', @rep_title);
	--replace study name place holder with the actual study name
	select @html = REPLACE (@html, '{{study_name}}', @study_name)
	--replace "script" place holder with the actual script
	--select @html = REPLACE (@html, '{{script}}', @script)
	
	--replace html_style place holder with the styles or blank space, based on the value of the @include_html_styles
	if isnull(@include_html_styles, 0) = 1
		Begin
		set @html = REPLACE (@html, '{{html_style}}', @html_style);
		End
	else 
		Begin
		set @html = REPLACE (@html, '{{html_style}}', '');
		End

	--print @html; --for testing only

	set @html_out = @html;

	End

GO
