USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_reloaded_manifests](
	[reload_id] [bigint] IDENTITY(1,1) NOT NULL,
	[study_id] [int] NOT NULL,
	[manifestId] [varchar](20) NULL,
	[requested_datetime] [datetime] NULL,
	[completed_status] [varchar](50) NULL,
	[completed_datetime] [datetime] NULL,
	[processed_manifest_qty] [int] NULL,
 CONSTRAINT [PK__dw_reloa__567C6CA75F2864FC] PRIMARY KEY CLUSTERED 
(
	[reload_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dw_reloaded_manifests] ADD  CONSTRAINT [DF__dw_reload__reque__473C8FC7]  DEFAULT (getdate()) FOR [requested_datetime]
GO
