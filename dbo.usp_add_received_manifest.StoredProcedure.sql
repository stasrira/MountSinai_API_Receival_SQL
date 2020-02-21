USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--this will add new manifest ids to the dw_received_manifests table
/*
declare @status_out int, @status_desc_out varchar (1000);
exec usp_add_received_manifest 1, '', '', @status_out output, @status_desc_out output; 
Print @status_out
Print @status_desc_out
*/
CREATE procedure [dbo].[usp_add_received_manifest] (
@study_id int, 
@manifest_id varchar (20),
@user_reported varchar (50)='',
@status_out int output,
@status_desc_out varchar (1000) output
)
as

Begin
	SET NOCOUNT ON --this is needed for front end to make sure the returned recordset contains only expected values

	if not isnull(@study_id, 0) = 0 and not rtrim(ltrim(isnull(@manifest_id, ''))) = ''
	Begin 
		--check if manifest was not reported yet
		if not exists (select * from dw_received_manifests where study_id = @study_id and manifestId = @manifest_id)
			Begin
				Insert into dw_received_manifests (manifestId, study_id, user_reported)
				Select @manifest_id, @study_id, @user_reported

				select @status_out = 1, @status_desc_out = 'Manifest "' + @manifest_id +'" (study_id: ' + cast (@study_id as varchar (20)) + ') was added.'
			End
		else
			Begin
				select @status_out = -1, @status_desc_out = 'Manifest "' + @manifest_id +'" (study_id: ' + cast (@study_id as varchar (20)) + ') already exists. No action was performed.'
			End
	End
	Else 
	Begin

		select @status_out = -1, @status_desc_out = 'Either Null or a blank value was passed for study_id or manifest_id parameters.'
	End

	return;
End


GO
