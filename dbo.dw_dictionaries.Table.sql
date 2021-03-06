USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_dictionaries](
	[dict_id] [int] NOT NULL,
	[dict_name] [varchar](50) NOT NULL,
	[dict_uri] [varchar](100) NULL,
	[dict_json] [varchar](max) NULL,
	[dict_json_hash]  AS (hashbytes('SHA2_256',[dict_json])),
	[datetime_stamp] [datetime] NULL,
 CONSTRAINT [PK_dw_dictionaries] PRIMARY KEY CLUSTERED 
(
	[dict_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
CREATE NONCLUSTERED INDEX [IX_dw_dictionaries] ON [dbo].[dw_dictionaries]
(
	[dict_json_hash] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [IX_dw_dictionaries_3] ON [dbo].[dw_dictionaries]
(
	[dict_name] ASC,
	[dict_uri] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dw_dictionaries] ADD  CONSTRAINT [DF_dw_dictionaries_datetime_stamp]  DEFAULT (getdate()) FOR [datetime_stamp]
GO
