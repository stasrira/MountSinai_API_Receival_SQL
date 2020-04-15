USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_data_sources](
	[source_id] [int] IDENTITY(101,1) NOT NULL,
	[source_name] [varchar](1700) NULL,
	[source_desc] [varchar](1000) NULL,
	[datetimestamp] [datetime] NULL,
 CONSTRAINT [PK_dw_data_sources_1] PRIMARY KEY CLUSTERED 
(
	[source_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [dw_data_sources_indx1] ON [dbo].[dw_data_sources]
(
	[source_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dw_data_sources] ADD  DEFAULT (getdate()) FOR [datetimestamp]
GO
