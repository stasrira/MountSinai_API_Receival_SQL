USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dw_fw_field_set_profile_details](
	[Profile_Rec_ID] [decimal](10, 0) IDENTITY(1,1) NOT NULL,
	[profile_id] [int] NULL,
	[Field_Name] [varchar](100) NULL,
	[Dropdown_Error_Message] [varchar](50) NULL,
	[Default] [varchar](1000) NULL,
	[Required] [varchar](100) NULL,
	[Dropdown] [varchar](100) NULL,
	[DropDown_Values_First_Cell_Of_Lookup_Range] [varchar](6) NULL,
	[Calculation_Trigger] [varchar](100) NULL,
	[Calculation_overwrites_existing_value] [varchar](100) NULL,
	[Calculated] [varchar](100) NULL,
	[Date_Field] [varchar](100) NULL,
	[Export_Assignment] [varchar](500) NULL,
	[field_order] [decimal](8, 3) NULL,
	[Numeric_Only] [varchar](100) NULL,
	[Misc_Settings] [varchar](1000) NULL,
 CONSTRAINT [PK_dw_fw_field_set_profile_details] PRIMARY KEY CLUSTERED 
(
	[Profile_Rec_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
CREATE NONCLUSTERED INDEX [IX1_dw_fw_field_set_profiles] ON [dbo].[dw_fw_field_set_profile_details]
(
	[Field_Name] ASC,
	[profile_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
