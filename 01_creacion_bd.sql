-- proyecto de cátedra abd - fundación raíces solidarias
-- script 01: creación de la base, archivos, filegroups,
--            esquemas y tablas
-- versión para sql server 2025 en contenedor docker:
--   datos: /var/opt/mssql/data   log: /var/opt/mssql/log
-- ambas viven en el volumen sqlserver2025_sqlserver_data.

use master;
go

if db_id('DonacionesONG') is not null
begin
    alter database DonacionesONG set single_user with rollback immediate;
    drop database DonacionesONG;
end
go

create database DonacionesONG
on primary
(
    name = 'DonacionesONG_sys',
    filename = '/var/opt/mssql/data/DonacionesONG_sys.mdf',
    size = 100MB,
    filegrowth = 64MB
),
filegroup FG_Datos
(
    name = 'DonacionesONG_datos',
    filename = '/var/opt/mssql/data/DonacionesONG_datos.ndf',
    size = 512MB,
    filegrowth = 128MB
),
filegroup FG_Indices
(
    name = 'DonacionesONG_indices',
    filename = '/var/opt/mssql/data/DonacionesONG_indices.ndf',
    size = 256MB,
    filegrowth = 64MB
)
log on
(
    name = 'DonacionesONG_log',
    filename = '/var/opt/mssql/log/DonacionesONG_log.ldf',
    size = 256MB,
    filegrowth = 128MB
);
go

alter database DonacionesONG modify filegroup FG_Datos default;
go

alter database DonacionesONG set recovery full;
go

use DonacionesONG;
go

create schema donantes;
go
create schema finanzas;
go
create schema proyectos;
go

-- tablas

create table donantes.Donante
(
    donante_id     int identity(1,1),
    tipo_donante   varchar(10)  not null,
    nombre         varchar(120) not null,
    documento      varchar(20)  not null,
    correo         varchar(120) not null,
    telefono       varchar(15)  null,
    municipio      varchar(60)  not null,
    departamento   varchar(40)  not null,
    fecha_registro date         not null constraint df_Donante_fecha default getdate(),
    activo         bit          not null constraint df_Donante_activo default 1,
    constraint pk_Donante primary key (donante_id),
    constraint uq_Donante_documento unique (documento),
    constraint uq_Donante_correo unique (correo),
    constraint ck_Donante_tipo check (tipo_donante in ('persona', 'empresa'))
);
go

create table finanzas.Campania
(
    campania_id  int identity(1,1),
    nombre       varchar(100)  not null,
    meta_monto   decimal(12,2) not null,
    fecha_inicio date          not null,
    fecha_fin    date          not null,
    constraint pk_Campania primary key (campania_id),
    constraint uq_Campania_nombre unique (nombre),
    constraint ck_Campania_meta check (meta_monto > 0),
    constraint ck_Campania_fechas check (fecha_fin >= fecha_inicio)
);
go

create table proyectos.Proyecto
(
    proyecto_id   int identity(1,1),
    nombre        varchar(120)  not null,
    tipo_proyecto varchar(15)   not null,
    presupuesto   decimal(12,2) not null,
    fecha_inicio  date          not null,
    fecha_fin     date          null,
    estado        varchar(15)   not null constraint df_Proyecto_estado default 'planificado',
    municipio     varchar(60)   not null,
    departamento  varchar(40)   not null,
    responsable   varchar(100)  not null,
    constraint pk_Proyecto primary key (proyecto_id),
    constraint uq_Proyecto_nombre unique (nombre),
    constraint ck_Proyecto_tipo check (tipo_proyecto in ('educacion', 'salud', 'vivienda', 'alimentacion')),
    constraint ck_Proyecto_presupuesto check (presupuesto > 0),
    constraint ck_Proyecto_estado check (estado in ('planificado', 'en_ejecucion', 'finalizado', 'suspendido'))
);
go

create table finanzas.Donacion
(
    donacion_id    int identity(1,1),
    donante_id     int           not null,
    campania_id    int           null,
    fecha_donacion datetime2(0)  not null constraint df_Donacion_fecha default sysdatetime(),
    monto          decimal(10,2) not null,
    metodo_pago    varchar(15)   not null,
    estado         varchar(12)   not null constraint df_Donacion_estado default 'registrada',
    referencia     varchar(40)   null,
    constraint pk_Donacion primary key (donacion_id),
    constraint fk_Donacion_Donante foreign key (donante_id) references donantes.Donante (donante_id),
    constraint fk_Donacion_Campania foreign key (campania_id) references finanzas.Campania (campania_id),
    constraint ck_Donacion_monto check (monto > 0),
    constraint ck_Donacion_metodo check (metodo_pago in ('efectivo', 'tarjeta', 'transferencia', 'cheque')),
    constraint ck_Donacion_estado check (estado in ('registrada', 'confirmada', 'anulada'))
);
go

create table finanzas.AsignacionFondos
(
    asignacion_id    int identity(1,1),
    donacion_id      int           not null,
    proyecto_id      int           not null,
    monto_asignado   decimal(10,2) not null,
    fecha_asignacion date          not null constraint df_Asignacion_fecha default getdate(),
    constraint pk_AsignacionFondos primary key (asignacion_id),
    constraint fk_Asignacion_Donacion foreign key (donacion_id) references finanzas.Donacion (donacion_id),
    constraint fk_Asignacion_Proyecto foreign key (proyecto_id) references proyectos.Proyecto (proyecto_id),
    constraint ck_Asignacion_monto check (monto_asignado > 0),
    constraint uq_Asignacion_donacion_proyecto unique (donacion_id, proyecto_id)
);
go

create table proyectos.Beneficiario
(
    beneficiario_id  int identity(1,1),
    nombre           varchar(120) not null,
    fecha_nacimiento date         not null,
    municipio        varchar(60)  not null,
    departamento     varchar(40)  not null,
    fecha_registro   date         not null constraint df_Beneficiario_fecha default getdate(),
    constraint pk_Beneficiario primary key (beneficiario_id)
);
go

create table proyectos.ProyectoBeneficiario
(
    proyecto_id         int  not null,
    beneficiario_id     int  not null,
    fecha_incorporacion date not null constraint df_PB_fecha default getdate(),
    constraint pk_ProyectoBeneficiario primary key (proyecto_id, beneficiario_id),
    constraint fk_PB_Proyecto foreign key (proyecto_id) references proyectos.Proyecto (proyecto_id),
    constraint fk_PB_Beneficiario foreign key (beneficiario_id) references proyectos.Beneficiario (beneficiario_id)
);
go

select s.name as esquema, t.name as tabla
from sys.tables t
    inner join sys.schemas s on s.schema_id = t.schema_id
order by s.name, t.name;
go
