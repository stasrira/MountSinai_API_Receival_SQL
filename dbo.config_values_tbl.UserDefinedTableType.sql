USE [dw_motrpac]
GO
/****** Object:  UserDefinedTableType [dbo].[config_values_tbl]    Script Date: 2/21/2020 12:46:35 PM ******/
CREATE TYPE [dbo].[config_values_tbl] AS TABLE(
	[config_key] [varchar](50) NOT NULL,
	[config_value] [varchar](1000) NULL,
	PRIMARY KEY CLUSTERED 
(
	[config_key] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO
