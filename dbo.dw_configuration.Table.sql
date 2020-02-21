USE [dw_motrpac]
GO
/****** Object:  Table [dbo].[dw_configuration]    Script Date: 2/21/2020 12:46:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_configuration](
	[entity_type] [int] NOT NULL,
	[entity_id] [int] NOT NULL,
	[config_key] [varchar](50) NOT NULL,
	[config_value] [varchar](1000) NULL,
	[description] [varchar](1000) NULL,
 CONSTRAINT [PK_dw_configuration] PRIMARY KEY CLUSTERED 
(
	[config_key] ASC,
	[entity_id] ASC,
	[entity_type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
