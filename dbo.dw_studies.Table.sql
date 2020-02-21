USE [dw_motrpac]
GO
/****** Object:  Table [dbo].[dw_studies]    Script Date: 2/21/2020 12:46:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_studies](
	[study_id] [int] NOT NULL,
	[program_id] [int] NOT NULL,
	[study_Name] [varchar](50) NULL,
	[dict_id] [int] NOT NULL,
 CONSTRAINT [PK_dw_studies] PRIMARY KEY CLUSTERED 
(
	[study_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
