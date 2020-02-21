USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create proc [dbo].[usp_view_file_loading_logs]
as
select * from dw_metadata_file_load_log order by datetime_stamp desc
select * from dw_metadata_modification_log order by datetime_stamp desc
GO
