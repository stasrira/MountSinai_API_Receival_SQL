USE [dw_motrpac]
GO
/****** Object:  Table [dbo].[dw_assays]    Script Date: 2/20/2020 6:54:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_assays](
	[assay_code] [int] NOT NULL,
	[assay_name] [varchar](50) NULL,
	[assay_desc] [varchar](1) NULL,
PRIMARY KEY CLUSTERED 
(
	[assay_code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
