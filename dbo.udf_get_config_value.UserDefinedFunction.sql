USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE function [dbo].[udf_get_config_value] (
@study_id int 
, @config_key varchar(50) 
) 
returns varchar (1000)
as
Begin 
	declare @out varchar (1000);

	select @out = config_value 
	from dw_study_configuration --with (index(PK_dw_study_configuration))
	where study_id = @study_id and config_key= @config_key 

	Return @out;

end
GO
