USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--select * from dbo.udf_get_all_config_value (1)
CREATE FUNCTION [dbo].[udf_get_all_config_value] 
 (
 @study_id int 
 )
RETURNS TABLE
AS
RETURN
	select config_key, config_value 
	from dw_study_configuration --with (index(PK_dw_study_configuration))
	where study_id = @study_id
GO
