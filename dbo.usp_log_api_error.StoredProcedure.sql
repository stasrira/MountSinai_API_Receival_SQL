USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE proc [dbo].[usp_log_api_error] (
	@api_log_id int, --current session api log id; it is being created per each api retrieval run
	@Object int, --handler id
	@api_retrieval_id varchar (50), --keeps ID passed to API to get data; MID value will be passed for MoTrPAC studies
	@stepName varchar (200), --custom name identifying the performed step
	@actionType varchar (30) = 'Error', --type of the log entry; default in this procedure is set to 'Error'
	@errorNum int = 71000 --custom error number of the raised error
	)
as
	declare @source varchar(255);  
	declare @description varchar(255);
	declare @errLog varchar (4000);

	EXEC sp_OAGetErrorInfo @Object, @source OUT, @description OUT
	Select @errLog = 'Error # ' + cast(@errorNum as varchar (20)) + ', Source: ' + @source +', Description:' + @description 
	--log the error into DB api log table
	exec usp_update_api_communication_log @api_log_id, @api_retrieval_id, @stepName, @errLog, @actionType;

	--THROW @errorNum, @errLog, 1 --raise an error --this interrupts the exectution right here
	RAISERROR  (@errLog, 16, 1) --this call allow to continue and handle the error outcome in the caller procedure

GO
