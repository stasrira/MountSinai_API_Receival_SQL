USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_fw_dropdown_fields](
	[Dict_id] [int] IDENTITY(1001,1) NOT NULL,
	[FieldName] [varchar](30) NOT NULL,
	[RawValue] [varchar](50) NULL,
	[ValidatedValue] [varchar](50) NULL,
	[DefaultFlag] [bit] NULL,
 CONSTRAINT [PK_dw_fw_dropdown_fields] PRIMARY KEY CLUSTERED 
(
	[Dict_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [IX_dw_fw_dropdown_fields] ON [dbo].[dw_fw_dropdown_fields]
(
	[FieldName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
