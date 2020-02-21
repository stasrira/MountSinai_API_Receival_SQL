USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_study_dictionary_mapping](
	[study_id] [int] NOT NULL,
	[mapping_code] [varchar](20) NOT NULL,
	[dict_id] [int] NOT NULL,
	[mapping_code_pk_field_name] [varchar](200) NOT NULL,
	[mapping_desc] [varchar](200) NULL,
 CONSTRAINT [PK_dw_study_dictionary_mapping] PRIMARY KEY CLUSTERED 
(
	[study_id] ASC,
	[mapping_code] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
