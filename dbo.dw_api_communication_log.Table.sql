USE [dw_motrpac]
GO
/****** Object:  Table [dbo].[dw_api_communication_log]    Script Date: 2/21/2020 12:46:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_api_communication_log](
	[row_id] [bigint] IDENTITY(1,1) NOT NULL,
	[api_call_session_id] [bigint] NOT NULL,
	[api_retrieval_id] [varchar](50) NULL,
	[logName] [varchar](200) NULL,
	[logValue] [varchar](4000) NULL,
	[logType] [varchar](30) NULL,
	[datetime_stamp] [datetime] NULL,
 CONSTRAINT [PK__dw_api_c__9E2397E0E7663D33] PRIMARY KEY CLUSTERED 
(
	[row_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dw_api_communication_log] ADD  CONSTRAINT [DF__dw_api_co__datet__0A338187]  DEFAULT (getdate()) FOR [datetime_stamp]
GO
