USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_source_aliquot_mapping](
	[source_id] [int] NOT NULL,
	[sample_id] [varchar](30) NOT NULL,
	[aliquot_id] [varchar](50) NOT NULL,
	[datetimestamp] [datetime] NULL,
 CONSTRAINT [PK_dw_source_aliquot_mapping_1] PRIMARY KEY CLUSTERED 
(
	[source_id] ASC,
	[aliquot_id] ASC,
	[sample_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dw_source_aliquot_mapping] ADD  DEFAULT (getdate()) FOR [datetimestamp]
GO
