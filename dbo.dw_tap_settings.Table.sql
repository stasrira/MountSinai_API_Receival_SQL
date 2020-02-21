USE [dw_motrpac]
GO
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
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [IX_dw_tap_settings] ON [dbo].[dw_tap_settings]
(
	[study_id] ASC,
	[tap_gr_1] ASC,
	[tap_gr_2] ASC,
	[tap_gr_3] ASC,
	[tap_gr_4] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
