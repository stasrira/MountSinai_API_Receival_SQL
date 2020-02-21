USE [dw_motrpac]
GO
CREATE TYPE [dbo].[add_metadata_tbl] AS TABLE(
	[sample_id] [varchar](100) NOT NULL,
	[sample_data] [nvarchar](max) NULL,
	[process_status] [varchar](50) NULL,
	PRIMARY KEY CLUSTERED 
(
	[sample_id] ASC
)WITH (IGNORE_DUP_KEY = OFF)
)
GO
