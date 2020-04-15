USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_aliquot_manifests](
	[aliquot_id] [varchar](50) NOT NULL,
	[sample_id] [varchar](30) NOT NULL,
	[study_id] [int] NOT NULL,
	[manifest_data] [nvarchar](max) NULL,
	[manifest_data_format] [varchar](10) NULL,
	[manifest_data_hash]  AS (hashbytes('SHA2_256',[manifest_data])),
	[datetime_stamp] [datetime] NULL,
	[comments] [varchar](2000) NULL,
 CONSTRAINT [PK_dw_aliquot_manifests_1] PRIMARY KEY CLUSTERED 
(
	[aliquot_id] ASC,
	[sample_id] ASC,
	[study_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[dw_aliquot_manifests] ADD  DEFAULT (getdate()) FOR [datetime_stamp]
GO
