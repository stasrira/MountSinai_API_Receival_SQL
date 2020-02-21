USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_configuration](
	[entity_type] [int] NOT NULL,
	[entity_id] [int] NOT NULL,
	[config_key] [varchar](50) NOT NULL,
	[config_value] [varchar](1000) NULL,
	[description] [varchar](1000) NULL,
 CONSTRAINT [PK_dw_configuration] PRIMARY KEY CLUSTERED 
(
	[config_key] ASC,
	[entity_id] ASC,
	[entity_type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [idx1_dw_configuration] ON [dbo].[dw_configuration]
(
	[config_value] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
