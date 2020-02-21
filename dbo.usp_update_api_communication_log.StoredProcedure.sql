USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--this procedure will insert a log entry into the dw_api_communication_log
CREATE procedure [dbo].[usp_update_api_communication_log] (
@api_call_session_id bigint  = 0, --keeps reference to the existing log session; if ommited ot set to 0, a new session will be created
@api_retrieval_id varchar (50), --keeps ID passed to API to get data; MID value will be passed for MoTrPAC studies
@entityName varchar (200), --Name (description) of the reported log information
@entityValue varchar (4000), --Value of the reported log information
@entityType varchar (30) --Expected values: Command, Property, Response, Error
)
as

Insert into  dw_api_communication_log (api_call_session_id, api_retrieval_id, logName, logValue, logType)
Values 
	( 
	--if @api_call_session_id = 0, this is the first API log record being passed to the log table. Create a new api_call_session_id for it
	iif(@api_call_session_id = 0, (select isnull(max(api_call_session_id), 0) + 1 from dw_api_communication_log), @api_call_session_id),
	@api_retrieval_id,
	@entityName,
	@entityValue,
	@entityType
	)

declare @row_id bigint
set @row_id = SCOPE_IDENTITY()

select @api_call_session_id = api_call_session_id from dw_api_communication_log where row_id = @row_id

return @api_call_session_id
GO
