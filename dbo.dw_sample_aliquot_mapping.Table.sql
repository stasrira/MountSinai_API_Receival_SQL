USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_sample_aliquot_mapping](
	[sample_id] [varchar](30) NOT NULL,
	[aliquot_id] [varchar](50) NOT NULL,
	[datetime_stamp] [datetime] NULL,
	[comments] [varchar](2000) NULL,
 CONSTRAINT [PK_dw_sample_aliquot_mapping_1] PRIMARY KEY CLUSTERED 
(
	[aliquot_id] ASC,
	[sample_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dw_sample_aliquot_mapping] ADD  DEFAULT (getdate()) FOR [datetime_stamp]
GO
