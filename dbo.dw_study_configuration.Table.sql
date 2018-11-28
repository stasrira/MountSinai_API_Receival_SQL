USE [dw_motrpac]
GO
/****** Object:  Table [dbo].[dw_study_configuration]    Script Date: 11/28/2018 4:59:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_study_configuration](
	[study_id] [int] NOT NULL,
	[config_key] [varchar](50) NOT NULL,
	[config_value] [varchar](1000) NULL,
 CONSTRAINT [PK_dw_study_configuration] PRIMARY KEY CLUSTERED 
(
	[config_key] ASC,
	[study_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idx1_dw_study_configuration]    Script Date: 11/28/2018 4:59:11 PM ******/
CREATE NONCLUSTERED INDEX [idx1_dw_study_configuration] ON [dbo].[dw_study_configuration]
(
	[config_value] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
