USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_metadata_file_load_log](
	[log_id] [bigint] IDENTITY(1,1) NOT NULL,
	[study_id] [int] NULL,
	[sample_id] [varchar](30) NULL,
	[file_path] [varchar](400) NULL,
	[status] [varchar](100) NULL,
	[status_desc] [varchar](max) NULL,
	[datetime_stamp] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[log_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[dw_metadata_file_load_log] ADD  DEFAULT (getdate()) FOR [datetime_stamp]
GO
