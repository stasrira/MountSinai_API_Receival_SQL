USE [dw_motrpac]
GO
/****** Object:  Table [dbo].[dw_studies]    Script Date: 11/28/2018 4:59:11 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_studies](
	[study_id] [int] NOT NULL,
	[program_id] [int] NOT NULL,
	[study_Name] [varchar](50) NULL,
	[dictionary_id] [int] NULL,
 CONSTRAINT [PK_dw_studies] PRIMARY KEY CLUSTERED 
(
	[study_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Index [idx1_dw_studies]    Script Date: 11/28/2018 4:59:11 PM ******/
CREATE NONCLUSTERED INDEX [idx1_dw_studies] ON [dbo].[dw_studies]
(
	[program_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [idx2_dw_studies]    Script Date: 11/28/2018 4:59:11 PM ******/
CREATE NONCLUSTERED INDEX [idx2_dw_studies] ON [dbo].[dw_studies]
(
	[dictionary_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
