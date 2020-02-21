USE [dw_motrpac]
GO
CREATE USER [mt_internal_user] FOR LOGIN [mt_internal_user] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_datareader] ADD MEMBER [mt_internal_user]
GO
