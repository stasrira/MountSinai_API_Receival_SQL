USE [dw_motrpac]
GO
/****** Object:  Table [dbo].[dw_metadata]    Script Date: 2/21/2020 12:46:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_metadata](
	[study_id] [int] NOT NULL,
	[sample_id] [varchar](30) NOT NULL,
	[sample_retrieval_id] [varchar](50) NULL,
	[sample_data] [nvarchar](max) NOT NULL,
	[sample_data_format] [varchar](10) NULL,
	[sample_data_hash]  AS (hashbytes('SHA2_256',[sample_data])),
	[datetime_stamp] [datetime] NULL,
	[assay_code] [int] NULL,
 CONSTRAINT [PK_dw_metadata_1] PRIMARY KEY CLUSTERED 
(
	[study_id] ASC,
	[sample_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[dw_metadata] ADD  CONSTRAINT [DF__dw_metada__datet__4E1E9780]  DEFAULT (getdate()) FOR [datetime_stamp]
GO
