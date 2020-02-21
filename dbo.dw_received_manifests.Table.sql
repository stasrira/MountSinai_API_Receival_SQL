USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_received_manifests](
	[manifestId] [varchar](20) NOT NULL,
	[study_id] [int] NOT NULL,
	[user_reported] [varchar](50) NULL,
	[datetime_stamp] [datetime] NULL,
	[ignore] [bit] NULL,
	[ignore_comment] [varchar](1000) NULL,
	[ignore_datestamp] [datetime] NULL,
 CONSTRAINT [PK_dw_received_manifests] PRIMARY KEY CLUSTERED 
(
	[manifestId] ASC,
	[study_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [idx1_dw_received_manifests] ON [dbo].[dw_received_manifests]
(
	[user_reported] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_dw_received_manifests] ON [dbo].[dw_received_manifests]
(
	[ignore] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dw_received_manifests] ADD  CONSTRAINT [DF__dw_receiv__datet__59904A2C]  DEFAULT (getdate()) FOR [datetime_stamp]
GO
