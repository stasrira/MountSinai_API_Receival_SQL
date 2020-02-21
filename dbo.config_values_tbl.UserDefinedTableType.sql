USE [dw_motrpac]
GO
CREATE TYPE [dbo].[config_values_tbl] AS TABLE(
	[config_key] [varchar](50) NOT NULL,
	[config_value] [varchar](1000) NULL,
	PRIMARY KEY CLUSTERED 
(
	[config_key] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO
