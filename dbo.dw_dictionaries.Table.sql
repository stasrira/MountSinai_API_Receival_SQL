USE [dw_motrpac]
GO
/****** Object:  Table [dbo].[dw_dictionaries]    Script Date: 11/28/2018 4:59:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_dictionaries](
	[dictionary_id] [int] NOT NULL,
	[fieldName] [varchar](50) NOT NULL,
	[isCoded] [int] NULL,
	[key] [varchar](50) NULL,
	[value] [varchar](1000) NULL,
 CONSTRAINT [PK_dw_dictionaries] PRIMARY KEY CLUSTERED 
(
	[dictionary_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idx1_dw_dictionaries]    Script Date: 11/28/2018 4:59:11 PM ******/
CREATE NONCLUSTERED INDEX [idx1_dw_dictionaries] ON [dbo].[dw_dictionaries]
(
	[fieldName] ASC,
	[isCoded] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [idx2_dw_dictionaries]    Script Date: 11/28/2018 4:59:11 PM ******/
CREATE NONCLUSTERED INDEX [idx2_dw_dictionaries] ON [dbo].[dw_dictionaries]
(
	[fieldName] ASC,
	[key] ASC,
	[value] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
