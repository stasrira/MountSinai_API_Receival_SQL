USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE function [dbo].[udf_get_config_value] (
@entity_id int,
@entity_type int,
@config_key varchar(50) 
) 
returns varchar (1000)
as
Begin 
	declare @out varchar (1000);

	select @out = config_value 
	from dw_configuration 
	where [entity_id] = @entity_id and entity_type = @entity_type and config_key= @config_key 

	Return @out;

end
GO
