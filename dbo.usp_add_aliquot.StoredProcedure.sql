USE [dw_motrpac]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
This proc adds aliquot_id to dw_sample_aliquot_mapping together with updating the dw_data_sources.
Currently data source name holds description of the source (i.e path of the file used as a source). 
*/
Create proc [dbo].[usp_add_aliquot]
	@sample_id varchar (30), 
	@aliquot_id varchar (50),
	@source_name varchar (1700) = 'Manual Update',
	@aliquot_comments varchar (2000) = '',
	@source_desc varchar (1000) = ''
as

declare @cur_source_id int

--get data source id; if data source is not present yet, add it to the table
if not exists (select * from dw_data_sources where source_name = @source_name)
	Begin 
	insert into dw_data_sources (source_name, source_desc) 
	Select @source_name, @source_desc

	--get id of just created entry
	set @cur_source_id = scope_identity()

	End
else
	Begin 
	select @cur_source_id = source_id from dw_data_sources where source_name = @source_name
	End

--add sample/aliquot mapping, if it is not currently present
if not exists (select * from dw_sample_aliquot_mapping where sample_id = @sample_id and aliquot_id = @aliquot_id)
	Begin
	
	insert into dw_sample_aliquot_mapping (
		sample_id, aliquot_id, comments)
	Select @sample_id, @aliquot_id, @aliquot_comments

	End

--verify that mapping for data source and aliquot is present; if not present create it
if not exists (
	select * 
	from dw_source_aliquot_mapping 
	where source_id = @cur_source_id
		and sample_id = @sample_id
		and aliquot_id = @aliquot_id
	)
	Begin
	Insert into dw_source_aliquot_mapping (source_id, sample_id, aliquot_id)
	Select @cur_source_id, @sample_id, @aliquot_id
	End
GO
