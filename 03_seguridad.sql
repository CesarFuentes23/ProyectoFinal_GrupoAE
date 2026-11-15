-- script 03: seguridad y control de acceso
-- logins -> usuarios -> roles -> permisos por esquema
-- contraseñas de demostración: cambiarlas antes de la defensa

use master;
go

if suser_id('login_direccion') is not null drop login login_direccion;
if suser_id('login_captacion') is not null drop login login_captacion;
if suser_id('login_finanzas') is not null drop login login_finanzas;
if suser_id('login_proyectos') is not null drop login login_proyectos;
if suser_id('login_powerbi') is not null drop login login_powerbi;
go

create login login_direccion with password = 'Direccion#2026!', default_database = DonacionesONG;
create login login_captacion with password = 'Captacion#2026!', default_database = DonacionesONG;
create login login_finanzas  with password = 'Finanzas#2026!',  default_database = DonacionesONG;
create login login_proyectos with password = 'Proyectos#2026!', default_database = DonacionesONG;
create login login_powerbi   with password = 'PowerBi#2026!',   default_database = DonacionesONG;
go

use DonacionesONG;
go

create user usuario_direccion for login login_direccion;
create user usuario_captacion for login login_captacion;
create user usuario_finanzas  for login login_finanzas;
create user usuario_proyectos for login login_proyectos;
create user usuario_powerbi   for login login_powerbi;
go

create role rol_direccion;
create role rol_captacion;
create role rol_finanzas;
create role rol_proyectos;
create role rol_reportes;
go

alter role rol_direccion add member usuario_direccion;
alter role rol_captacion add member usuario_captacion;
alter role rol_finanzas  add member usuario_finanzas;
alter role rol_proyectos add member usuario_proyectos;
alter role rol_reportes  add member usuario_powerbi;
go

-- permisos por esquema (matriz de la sección 4.2 del informe)

grant select on schema::donantes  to rol_direccion;
grant select on schema::finanzas  to rol_direccion;
grant select on schema::proyectos to rol_direccion;

grant select, insert, update on schema::donantes to rol_captacion;
grant select, insert on schema::finanzas to rol_captacion;
grant select on schema::proyectos to rol_captacion;

grant select on schema::donantes to rol_finanzas;
grant select, insert, update on schema::finanzas to rol_finanzas;
grant select on schema::proyectos to rol_finanzas;

grant select, insert, update on schema::proyectos to rol_proyectos;
grant select on schema::finanzas to rol_proyectos;

grant select on schema::donantes  to rol_reportes;
grant select on schema::finanzas  to rol_reportes;
grant select on schema::proyectos to rol_reportes;
go

-- prohibición explícita: las donaciones se anulan, no se borran
deny delete on schema::finanzas to rol_finanzas;
go

-- demostración de revoke (mantenimiento de permisos)

grant update on schema::donantes to rol_reportes;
go
revoke update on schema::donantes from rol_reportes;
go

-- caso de prueba de acceso denegado (diapositiva 4)
-- error esperado: msg 229, permiso delete denegado sobre
-- el objeto 'donacion', esquema 'finanzas'

execute as user = 'usuario_captacion';
go

select suser_name() as login_actual, user_name() as usuario_actual;
go

delete from finanzas.Donacion
where donacion_id = 100;
go

revert;
go

-- contraste: usuario_finanzas tiene el deny explícito
execute as user = 'usuario_finanzas';
go

delete from finanzas.Donacion
where donacion_id = 100;
go

revert;
go

-- verificación de la matriz de permisos

select pr.name as rol,
       pe.state_desc as estado,
       pe.permission_name as permiso,
       schema_name(pe.major_id) as esquema
from sys.database_permissions pe
    inner join sys.database_principals pr on pr.principal_id = pe.grantee_principal_id
where pe.class_desc = 'SCHEMA'
order by pr.name, esquema, permiso;
go
