USE [dw_motrpac]
GO
/****** Object:  Table [dbo].[dw_tap_settings]    Script Date: 2/21/2020 12:46:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_tap_settings](
	[tap_id] [bigint] IDENTITY(1,1) NOT NULL,
	[study_id] [int] NULL,
	[tap_gr_1] [varchar](100) NULL,
	[tap_gr_2] [varchar](100) NULL,
	[tap_gr_3] [varchar](100) NULL,
	[tap_gr_4] [varchar](100) NULL,
	[tap_gr_5] [varchar](100) NULL,
	[tap_gr_6] [varchar](100) NULL,
	[tap_gr_7] [varchar](100) NULL,
	[tap_gr_8] [varchar](100) NULL,
	[tap_gr_9] [varchar](100) NULL,
	[sample_count] [int] NULL,
 CONSTRAINT [PK_dw_tap_settings] PRIMARY KEY CLUSTERED 
(
	[tap_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
