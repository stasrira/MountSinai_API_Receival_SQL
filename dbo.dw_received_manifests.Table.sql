USE [dw_motrpac]
GO
/****** Object:  Table [dbo].[dw_received_manifests]    Script Date: 2/21/2020 12:46:35 PM ******/
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
ALTER TABLE [dbo].[dw_received_manifests] ADD  CONSTRAINT [DF__dw_receiv__datet__59904A2C]  DEFAULT (getdate()) FOR [datetime_stamp]
GO
