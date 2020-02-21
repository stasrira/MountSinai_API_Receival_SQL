USE [dw_motrpac]
GO
/****** Object:  Table [dbo].[dw_metadata_modification_log]    Script Date: 2/21/2020 12:46:35 PM ******/
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
ALTER TABLE [dbo].[dw_metadata_modification_log] ADD  DEFAULT (getdate()) FOR [datetime_stamp]
GO
