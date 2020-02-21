USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--this will add new manifest ids to the dw_received_manifests table
--usp_add_received_manifests 1, 'StasA996-00200,StasA995-00200,Stas994-00200', 'mssmcampus\riraks01', ','
--usp_add_received_manifests 1, 'Stas996-00200', 'mssmcampus\riraks01', ','
--usp_add_received_manifests 1, NULL

CREATE procedure [dbo].[usp_add_received_manifests] (
	@study_id int, 
	@manifest_ids varchar (1000),
	@user_reported varchar (50)='',
	@delimiter varchar (10) = ','
)
as
Begin 

	SET NOCOUNT ON --this is needed for front end to make sure the returned recordset contains only expected values

	declare @mids as table (mid varchar (100)); --this table will hold split list of submitted MIDs
	create table #result --this table will hold each processed MID with the status of processing (1: OK, -1: Error) and status description
		(mid varchar (20), status_out int, status_desc_out varchar (1000));

	declare @sql nvarchar(max) = '';

	Insert into @mids (mid)
	SELECT value FROM STRING_SPLIT(isnull(@manifest_ids,''), @delimiter);
	
	select @sql = 
	'	
			declare @status_out int, @status_desc_out varchar (1000);

	'
 
	select @sql = @sql + '
			exec usp_add_received_manifest ' 
			+ cast (isnull(@study_id, 0) as varchar (20)) + ', ''' 
			+ mid + ''', ''' 
			+ isnull (@user_reported, '') + ''', @status_out output, @status_desc_out output; 
			insert into #result (mid, status_out, status_desc_out) Values (''' + mid + ''', @status_out, @status_desc_out);
			
			' from @mids;
print @sql; -- for testing only
	
	--execute the created SQL string
	exec sp_executesql @sql;

	select * from #result
End
GO
