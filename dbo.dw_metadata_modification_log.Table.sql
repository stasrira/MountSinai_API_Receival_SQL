USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_metadata_modification_log](
	[log_id] [bigint] IDENTITY(1,1) NOT NULL,
	[study_id] [int] NULL,
	[sample_id] [varchar](30) NULL,
	[sample_retrieval_id] [varchar](50) NULL,
	[process_status] [varchar](100) NULL,
	[datetime_stamp] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[log_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [idx1_dw_metadata_modification_log] ON [dbo].[dw_metadata_modification_log]
(
	[sample_id] ASC,
	[sample_retrieval_id] ASC,
	[study_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [idx2_dw_metadata_modification_log] ON [dbo].[dw_metadata_modification_log]
(
	[datetime_stamp] ASC,
	[sample_retrieval_id] ASC,
	[study_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dw_metadata_modification_log] ADD  DEFAULT (getdate()) FOR [datetime_stamp]
GO
