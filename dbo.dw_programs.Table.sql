USE [dw_motrpac]
GO
/****** Object:  Table [dbo].[dw_programs]    Script Date: 11/28/2018 4:59:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_programs](
	[program_id] [int] NOT NULL,
	[program_Name] [varchar](50) NULL,
 CONSTRAINT [PK_dw_programs] PRIMARY KEY CLUSTERED 
(
	[program_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
