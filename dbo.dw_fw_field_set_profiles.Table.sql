USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_fw_field_set_profiles](
	[profile_id] [int] NOT NULL,
	[profile_name] [varchar](50) NOT NULL,
	[profile_desc] [varchar](200) NULL,
	[profile_owner] [varchar](50) NULL,
	[profile_created] [datetime] NULL,
	[display_order] [decimal](8, 3) NULL,
	[active] [int] NULL,
 CONSTRAINT [PK1_dw_fw_field_set_profiles] PRIMARY KEY CLUSTERED 
(
	[profile_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dw_fw_field_set_profiles] ADD  DEFAULT (getdate()) FOR [profile_created]
GO
ALTER TABLE [dbo].[dw_fw_field_set_profiles] ADD  DEFAULT ((1)) FOR [active]
GO
