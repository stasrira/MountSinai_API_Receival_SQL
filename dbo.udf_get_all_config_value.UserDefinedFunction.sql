USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--select * from dbo.udf_get_all_config_value (1, 1)
CREATE FUNCTION [dbo].[udf_get_all_config_value] 
 (
 @entity_id int,
 @entity_type int
 )
RETURNS TABLE
AS
RETURN
	select config_key, config_value 
	from dw_configuration --with (index(PK_dw_study_configuration))
	where entity_id = @entity_id and entity_type = @entity_type



GO
