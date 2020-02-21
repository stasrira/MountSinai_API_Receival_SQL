USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE proc [dbo].[usp_get_config_value_local] (
 @temp_tbl config_values_tbl readonly 
,@config_key varchar(50) 
,@outVal varchar (1000) out
) 
as
Begin 
	select @outVal=config_value from @temp_tbl where config_key = @config_key
	--select @outVal as OutVal_FromProc --for testing only
end
GO
