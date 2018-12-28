USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
--usage example
EXEC usp_send_cdosysmail 
	'SQLServer2016@gmail.com',
	'stasrirak.ms@gmail.com',
	'Test email notification.',
	'<b>This is a Test Mail</b><br><h1><font color = "blue">Test email!</font></h1>'

*/

CREATE procedure [dbo].[usp_send_cdosysmail]
	@from varchar(500) ,
	@to varchar(500) ,
	@subject varchar(500),
	@body varchar(max) ,
	@smtpserver varchar(25) = 'smtp.mssm.edu',
	@bodytype varchar(10) = 'htmlbody' 
as
	Begin

--for testing only
print @to
print @subject
print @bodytype
print @body 

	declare @imsg int
	declare @hr int
	declare @source varchar(255)
	declare @description varchar(500)
	declare @output varchar(1000)
	exec @hr = sp_oacreate 'cdo.message', @imsg out
	exec @hr = sp_oasetproperty @imsg,
		'configuration.fields("http://schemas.microsoft.com/cdo/configuration/sendusing").value','2'

	exec @hr = sp_oasetproperty @imsg, 'configuration.fields("http://schemas.microsoft.com/cdo/configuration/smtpserver").value', @smtpserver 

	exec @hr = sp_oamethod @imsg, 'configuration.fields.update', null
	exec @hr = sp_oasetproperty @imsg, 'to', @to
	exec @hr = sp_oasetproperty @imsg, 'from', @from
	exec @hr = sp_oasetproperty @imsg, 'subject', @subject

	-- if you are using html e-mail, use 'htmlbody' instead of 'textbody'.

	exec @hr = sp_oasetproperty @imsg, @bodytype, @body
	exec @hr = sp_oamethod @imsg, 'send', null

	-- sample error handling.
	if @hr <>0 
		begin
			Print @hr
			exec @hr = sp_oageterrorinfo null, @source out, @description out
			if @hr = 0
			begin
				select @output = ' source: ' + @source
				print @output
				select @output = ' description: ' + @description
				print @output
			end
			else
			begin
				print ' sp_oageterrorinfo failed.'
				return
			end
		end
	exec @hr = sp_oadestroy @imsg

	End
GO
