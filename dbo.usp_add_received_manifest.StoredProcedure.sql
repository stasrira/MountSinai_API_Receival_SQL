USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--this will add new manifest ids to the dw_received_manifests table
--usp_add_received_manifest 1, 'TST996-00200' 
CREATE procedure [dbo].[usp_add_received_manifest] (
@study_id int, 
@manifest_id varchar (20),
@user_reported varchar (50)=''
)
as

if not @study_id is null and not @manifest_id is null
Begin 
	--check if manifest was not reported yet
	if not exists (select * from dw_received_manifests where study_id = @study_id and manifestId = @manifest_id)
		Begin
			Insert into dw_received_manifests (manifestId, study_id, user_reported)
			Select @manifest_id, @study_id, @user_reported

			Print 'Manifest "' + @manifest_id +'" (study_id: ' + cast (@study_id as varchar (20)) + ') was added.'
		End
	else
		Begin
		Print 'Manifest "' + @manifest_id +'" (study_id: ' + cast (@study_id as varchar (20)) + ') already exists. No action was performed.'
		End
End
Else 
Begin
	Print 'Null value was passed to the procedure for study_id or manifest_id parameters.'
End
GO
