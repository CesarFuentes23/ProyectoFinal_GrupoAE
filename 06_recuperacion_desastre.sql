use master;
go

select count(*) as total_donaciones, max(fecha_donacion) as ultima_donacion
from DonacionesONG.finanzas.Donacion;
go

select bs.backup_set_id,
       case bs.type when 'D' then 'full' when 'I' then 'diferencial' when 'L' then 'log' end as tipo,
       bs.is_copy_only,
       bs.backup_start_date,
       bs.backup_finish_date,
       bmf.physical_device_name
from msdb.dbo.backupset bs
    inner join msdb.dbo.backupmediafamily bmf on bmf.media_set_id = bs.media_set_id
where bs.database_name = 'DonacionesONG'
order by bs.backup_start_date;
go

declare @ruta_cola varchar(260) =
    '/backup/Log/DonacionesONG_taillog_' + convert(varchar(8), getdate(), 112) + '_'
    + replace(convert(varchar(5), getdate(), 108), ':', '') + '.trn';

backup log DonacionesONG to disk = @ruta_cola with no_truncate, checksum, stats = 25;

select @ruta_cola as archivo_cola_del_log;
go

select sysdatetime() as inicio_simulacro;

declare @full_id int, @full_ruta nvarchar(260);
select top 1 @full_id = bs.backup_set_id, @full_ruta = bmf.physical_device_name
from msdb.dbo.backupset bs
    inner join msdb.dbo.backupmediafamily bmf on bmf.media_set_id = bs.media_set_id
where bs.database_name = 'DonacionesONG' and bs.type = 'D' and bs.is_copy_only = 0
order by bs.backup_start_date desc;

declare @move nvarchar(max) = N'';
select @move = @move + N'move ''' + bf.logical_name + N''' to ''/var/opt/mssql/data/Rec_'
       + right(bf.physical_name, charindex('/', reverse(bf.physical_name)) - 1) + N''', '
from msdb.dbo.backupfile bf
where bf.backup_set_id = @full_id;

declare @sql nvarchar(max) =
    N'restore database DonacionesONG_Rec from disk = ''' + @full_ruta + N''' with '
    + @move + N'norecovery, stats = 25;';
print @sql;
exec sp_executesql @sql;

declare @dif_ruta nvarchar(260), @dif_fin datetime;
select top 1 @dif_ruta = bmf.physical_device_name, @dif_fin = bs.backup_finish_date
from msdb.dbo.backupset bs
    inner join msdb.dbo.backupmediafamily bmf on bmf.media_set_id = bs.media_set_id
where bs.database_name = 'DonacionesONG' and bs.type = 'I'
  and bs.backup_start_date > (select backup_finish_date from msdb.dbo.backupset where backup_set_id = @full_id)
order by bs.backup_start_date desc;

declare @ultimo_fin datetime = (select backup_finish_date from msdb.dbo.backupset where backup_set_id = @full_id);

if @dif_ruta is not null
begin
    set @sql = N'restore database DonacionesONG_Rec from disk = ''' + @dif_ruta + N''' with norecovery, stats = 25;';
    print @sql;
    exec sp_executesql @sql;
    set @ultimo_fin = @dif_fin;
end

declare @log_ruta nvarchar(260);
declare cur_logs cursor local fast_forward for
    select bmf.physical_device_name
    from msdb.dbo.backupset bs
        inner join msdb.dbo.backupmediafamily bmf on bmf.media_set_id = bs.media_set_id
    where bs.database_name = 'DonacionesONG' and bs.type = 'L'
      and bs.backup_finish_date > @ultimo_fin
    order by bs.backup_start_date;
open cur_logs;
fetch next from cur_logs into @log_ruta;
while @@fetch_status = 0
begin
    set @sql = N'restore log DonacionesONG_Rec from disk = ''' + @log_ruta + N''' with norecovery;';
    print @sql;
    exec sp_executesql @sql;
    fetch next from cur_logs into @log_ruta;
end
close cur_logs;
deallocate cur_logs;
go

restore database DonacionesONG_Rec with recovery;
go

select sysdatetime() as fin_simulacro;
go

dbcc checkdb('DonacionesONG_Rec') with no_infomsgs;
go

select count(*) as total_donaciones, max(fecha_donacion) as ultima_donacion
from DonacionesONG_Rec.finanzas.Donacion;
go

select name, state_desc, recovery_model_desc
from sys.databases
where name in ('DonacionesONG', 'DonacionesONG_Rec');
go

-- limpieza despues de tomar las capturas:
-- use master;
-- drop database donacionesong_rec;
