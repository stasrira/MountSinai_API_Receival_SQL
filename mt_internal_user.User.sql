USE [dw_motrpac]
GO
/****** Object:  User [mt_internal_user]    Script Date: 2/21/2020 12:46:35 PM ******/
CREATE USER [mt_internal_user] FOR LOGIN [mt_internal_user] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_datareader] ADD MEMBER [mt_internal_user]
GO
