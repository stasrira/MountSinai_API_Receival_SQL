USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_api_retrieval_history](
	[log_id] [bigint] IDENTITY(1,1) NOT NULL,
	[entity_type] [int] NOT NULL,
	[entity_id] [int] NOT NULL,
	[api_retrieval_id] [varchar](50) NOT NULL,
	[api_retrieval_status] [varchar](20) NULL,
	[api_status_details] [varchar](200) NULL,
	[api_response_sneak_peek] [varchar](4000) NULL,
	[full_api_response_hash] [varbinary](max) NULL,
	[datetime_stamp] [datetime] NULL,
 CONSTRAINT [PK_dw_api_retrieval_history_1] PRIMARY KEY CLUSTERED 
(
	[log_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [IX_dw_api_retrieval_history] ON [dbo].[dw_api_retrieval_history]
(
	[api_retrieval_id] ASC,
	[entity_id] ASC,
	[entity_type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dw_api_retrieval_history] ADD  CONSTRAINT [DF__dw_api_re__datet__5D60DB10]  DEFAULT (getdate()) FOR [datetime_stamp]
GO
