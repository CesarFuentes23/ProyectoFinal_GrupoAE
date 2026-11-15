-- script 05: respaldos y sql server agent
-- versión para sql server 2025 en contenedor docker.
-- requiere: sql server agent activo (mssql_agent_enabled=true) y las
-- carpetas /backup/full, /backup/diferencial y /backup/log dentro del
-- contenedor (volumen sqlserver2025_sqlserver_backup).
-- las notificaciones por correo requieren database mail
-- configurado; sin él, los jobs funcionan igual.

use master;
go

-- respaldo completo inicial manual y verificación

declare @ruta varchar(260) =
    '/backup/Full/DonacionesONG_full_' + convert(varchar(8), getdate(), 112) + '.bak';

backup database DonacionesONG
to disk = @ruta
with checksum, compression, stats = 10;

restore verifyonly
from disk = @ruta
with checksum;
go

-- operador para alertas

use msdb;
go

if not exists (select 1 from msdb.dbo.sysoperators where name = 'op_dba')
    exec msdb.dbo.sp_add_operator
        @name = N'op_dba',
        @email_address = N'equipo.abd.raices@correo.com';
go

-- job 1: respaldo completo semanal (domingo 02:00)

if exists (select 1 from msdb.dbo.sysjobs where name = N'Job_Respaldo_Full')
    exec msdb.dbo.sp_delete_job @job_name = N'Job_Respaldo_Full';
go

exec msdb.dbo.sp_add_job @job_name = N'Job_Respaldo_Full', @enabled = 1;

exec msdb.dbo.sp_add_jobstep
    @job_name = N'Job_Respaldo_Full',
    @step_name = N'Respaldar y verificar',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @on_success_action = 3,
    @command = N'
declare @ruta varchar(260) =
    ''/backup/Full/DonacionesONG_full_'' + convert(varchar(8), getdate(), 112) + ''.bak'';
backup database DonacionesONG to disk = @ruta with checksum, compression, stats = 10;
restore verifyonly from disk = @ruta with checksum;';

exec msdb.dbo.sp_add_jobstep
    @job_name = N'Job_Respaldo_Full',
    @step_name = N'Limpiar fulls de mas de 8 semanas',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @on_success_action = 1,
    @command = N'
declare @limite datetime = dateadd(week, -8, getdate());
exec master.sys.xp_delete_file 0, N''/backup/Full'', N''bak'', @limite, 0;';

exec msdb.dbo.sp_add_schedule
    @schedule_name = N'Domingo_0200',
    @freq_type = 8,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 020000;

exec msdb.dbo.sp_attach_schedule
    @job_name = N'Job_Respaldo_Full',
    @schedule_name = N'Domingo_0200';

exec msdb.dbo.sp_add_jobserver @job_name = N'Job_Respaldo_Full', @server_name = N'(local)';

exec msdb.dbo.sp_update_job
    @job_name = N'Job_Respaldo_Full',
    @notify_level_email = 2,
    @notify_email_operator_name = N'op_dba';
go

-- job 2: respaldo diferencial diario (lunes a sábado 02:00)

if exists (select 1 from msdb.dbo.sysjobs where name = N'Job_Respaldo_Diferencial')
    exec msdb.dbo.sp_delete_job @job_name = N'Job_Respaldo_Diferencial';
go

exec msdb.dbo.sp_add_job @job_name = N'Job_Respaldo_Diferencial', @enabled = 1;

exec msdb.dbo.sp_add_jobstep
    @job_name = N'Job_Respaldo_Diferencial',
    @step_name = N'Respaldar diferencial y verificar',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @on_success_action = 3,
    @command = N'
declare @ruta varchar(260) =
    ''/backup/Diferencial/DonacionesONG_diff_'' + convert(varchar(8), getdate(), 112) + ''.bak'';
backup database DonacionesONG to disk = @ruta with differential, checksum, compression, stats = 10;
restore verifyonly from disk = @ruta with checksum;';

exec msdb.dbo.sp_add_jobstep
    @job_name = N'Job_Respaldo_Diferencial',
    @step_name = N'Limpiar diferenciales de mas de 14 dias',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @on_success_action = 1,
    @command = N'
declare @limite datetime = dateadd(day, -14, getdate());
exec master.sys.xp_delete_file 0, N''/backup/Diferencial'', N''bak'', @limite, 0;';

exec msdb.dbo.sp_add_schedule
    @schedule_name = N'LunesASabado_0200',
    @freq_type = 8,
    @freq_interval = 126,
    @freq_recurrence_factor = 1,
    @active_start_time = 020000;

exec msdb.dbo.sp_attach_schedule
    @job_name = N'Job_Respaldo_Diferencial',
    @schedule_name = N'LunesASabado_0200';

exec msdb.dbo.sp_add_jobserver @job_name = N'Job_Respaldo_Diferencial', @server_name = N'(local)';

exec msdb.dbo.sp_update_job
    @job_name = N'Job_Respaldo_Diferencial',
    @notify_level_email = 2,
    @notify_email_operator_name = N'op_dba';
go

-- job 3: respaldo de log cada 30 minutos (inicia 00:15)

if exists (select 1 from msdb.dbo.sysjobs where name = N'Job_Respaldo_Log')
    exec msdb.dbo.sp_delete_job @job_name = N'Job_Respaldo_Log';
go

exec msdb.dbo.sp_add_job @job_name = N'Job_Respaldo_Log', @enabled = 1;

exec msdb.dbo.sp_add_jobstep
    @job_name = N'Job_Respaldo_Log',
    @step_name = N'Respaldar log',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @on_success_action = 3,
    @command = N'
declare @ruta varchar(260) =
    ''/backup/Log/DonacionesONG_log_'' + convert(varchar(8), getdate(), 112) + ''_''
    + replace(convert(varchar(5), getdate(), 108), '':'', '''') + ''.trn'';
backup log DonacionesONG to disk = @ruta with checksum, stats = 25;';

exec msdb.dbo.sp_add_jobstep
    @job_name = N'Job_Respaldo_Log',
    @step_name = N'Limpiar logs de mas de 14 dias',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @on_success_action = 1,
    @command = N'
declare @limite datetime = dateadd(day, -14, getdate());
exec master.sys.xp_delete_file 0, N''/backup/Log'', N''trn'', @limite, 0;';

exec msdb.dbo.sp_add_schedule
    @schedule_name = N'Cada30Min_Desde0015',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 30,
    @active_start_time = 001500;

exec msdb.dbo.sp_attach_schedule
    @job_name = N'Job_Respaldo_Log',
    @schedule_name = N'Cada30Min_Desde0015';

exec msdb.dbo.sp_add_jobserver @job_name = N'Job_Respaldo_Log', @server_name = N'(local)';

exec msdb.dbo.sp_update_job
    @job_name = N'Job_Respaldo_Log',
    @notify_level_email = 2,
    @notify_email_operator_name = N'op_dba';
go

-- job 4: copia externa semanal (domingo 04:00)
-- respaldo completo copy_only hacia /csv/copia_externa, carpeta del
-- contenedor enlazada a una carpeta del equipo anfitrión fuera del volumen de
-- docker (paso t-sql del agent)

if exists (select 1 from msdb.dbo.sysjobs where name = N'Job_Copia_Externa')
    exec msdb.dbo.sp_delete_job @job_name = N'Job_Copia_Externa';
go

exec msdb.dbo.sp_add_job @job_name = N'Job_Copia_Externa', @enabled = 1;

exec msdb.dbo.sp_add_jobstep
    @job_name = N'Job_Copia_Externa',
    @step_name = N'Respaldo completo hacia el destino externo',
    @subsystem = N'TSQL',
    @database_name = N'master',
    @on_success_action = 1,
    @command = N'
declare @ruta varchar(260) =
    ''/csv/copia_externa/DonacionesONG_externa_'' + convert(varchar(8), getdate(), 112) + ''.bak'';
backup database DonacionesONG to disk = @ruta with copy_only, checksum, compression, stats = 25;
restore verifyonly from disk = @ruta with checksum;';

exec msdb.dbo.sp_add_schedule
    @schedule_name = N'Domingo_0400',
    @freq_type = 8,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 040000;

exec msdb.dbo.sp_attach_schedule
    @job_name = N'Job_Copia_Externa',
    @schedule_name = N'Domingo_0400';

exec msdb.dbo.sp_add_jobserver @job_name = N'Job_Copia_Externa', @server_name = N'(local)';

exec msdb.dbo.sp_update_job
    @job_name = N'Job_Copia_Externa',
    @notify_level_email = 2,
    @notify_email_operator_name = N'op_dba';
go

-- prueba inmediata de los jobs (sin esperar al horario)

exec msdb.dbo.sp_start_job @job_name = N'Job_Respaldo_Log';
go

waitfor delay '00:00:10';

select j.name as job,
       h.run_date,
       h.run_time,
       case h.run_status when 1 then 'Correcto' when 0 then 'Fallido' else 'Otro' end as resultado
from msdb.dbo.sysjobhistory h
    inner join msdb.dbo.sysjobs j on j.job_id = h.job_id
where h.step_id = 0
order by h.run_date desc, h.run_time desc;
go
