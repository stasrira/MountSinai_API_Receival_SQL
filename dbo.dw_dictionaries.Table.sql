USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_dictionaries](
	[dict_id] [int] NOT NULL,
	[dict_name] [varchar](50) NULL,
	[dict_uri] [varchar](1000) NULL,
	[dict_json] [varchar](max) NULL,
	[dict_json_hash]  AS (hashbytes('SHA2_256',[dict_json])),
PRIMARY KEY CLUSTERED 
(
	[dict_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
