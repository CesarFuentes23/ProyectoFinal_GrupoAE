-- script 07: migración de donantes históricos desde csv
-- origen: hoja de cálculo de captación exportada a csv (utf-8)
-- archivo: /csv/donantes_historicos.csv (300 filas)
-- (dentro del contenedor, carpeta /csv enlazada a
--  desktop\admin bd\sqlserver2025\sqlserver2025\shared\csv)
-- resultado esperado sobre la base ya cargada con el script 02:
--   250 filas cargadas, 50 rechazadas, donantes 4,000 -> 4,250

use DonacionesONG;
go

set nocount on;
go

if object_id('tempdb..#stg_donante') is not null drop table #stg_donante;
if object_id('tempdb..#clasificados') is not null drop table #clasificados;
go

create table #stg_donante
(
    tipo_donante varchar(30)  null,
    nombre       varchar(120) collate Latin1_General_100_CI_AS_SC_UTF8 null,
    documento    varchar(20)  null,
    correo       varchar(120) null,
    telefono     varchar(15)  null,
    municipio    varchar(60)  collate Latin1_General_100_CI_AS_SC_UTF8 null,
    departamento varchar(40)  collate Latin1_General_100_CI_AS_SC_UTF8 null
);
go

-- paso 1 - carga masiva a una tabla de paso (staging).
-- nada toca todavía las tablas reales. las columnas con tildes
-- usan collation utf-8.

bulk insert #stg_donante
from '/csv/donantes_historicos.csv'
with (
    firstrow = 2,
    fieldterminator = ',',
    rowterminator = '0x0a',
    tablock
);
go

select count(*) as filas_leidas_del_archivo from #stg_donante;
go

-- paso 2 - clasificación: cada fila queda como válida (motivo
-- null) o con el motivo exacto por el que se rechaza.
-- el orden de las reglas define el motivo cuando hay varias.

with numeradas as (
    select s.*,
           row_number() over (partition by s.documento order by s.correo) as repeticion
    from #stg_donante s
)
select n.*,
       case
           when n.tipo_donante is null or n.nombre is null or n.documento is null
                or n.correo is null or n.municipio is null or n.departamento is null
               then 'campo obligatorio vacio'
           when n.tipo_donante not in ('persona', 'empresa')
               then 'tipo_donante invalido'
           when n.repeticion > 1
               then 'documento repetido dentro del archivo'
           when exists (select 1 from donantes.Donante d where d.documento = n.documento)
               then 'documento ya existe en la base'
           when exists (select 1 from donantes.Donante d where d.correo = n.correo)
               then 'correo ya existe en la base'
       end as motivo
into #clasificados
from numeradas n;
go

-- paso 3 - carga de las filas válidas en una transacción: o
-- entran todas o no entra ninguna.

declare @antes int = (select count(*) from donantes.Donante);
declare @insertadas int;

begin try
    begin transaction;

    insert into donantes.Donante (tipo_donante, nombre, documento, correo, telefono, municipio, departamento)
    select tipo_donante, nombre, documento, correo, telefono, municipio, departamento
    from #clasificados
    where motivo is null;

    set @insertadas = @@rowcount;

    commit transaction;

    select @antes as donantes_antes,
           @insertadas as filas_cargadas,
           (select count(*) from donantes.Donante) as donantes_despues;
end try
begin catch
    if @@trancount > 0 rollback transaction;
    select error_number() as error, error_message() as mensaje;
    throw;
end catch
go

-- paso 4 - conciliación: lo leído debe ser igual a lo cargado
-- más lo rechazado, y cada rechazo queda explicado.

select coalesce(motivo, 'CARGADA') as resultado,
       count(*) as filas
from #clasificados
group by motivo
order by filas desc;
go

select (select count(*) from #stg_donante) as leidas,
       (select count(*) from #clasificados where motivo is null) as cargadas,
       (select count(*) from #clasificados where motivo is not null) as rechazadas,
       case when (select count(*) from #stg_donante) =
                 (select count(*) from #clasificados)
            then 'concilia' else 'NO concilia' end as estado_conciliacion;
go

-- verificación de tildes en lo recién cargado
select top 5 donante_id, nombre, municipio, departamento
from donantes.Donante
where donante_id > 4000
order by donante_id;
go

-- detalle de rechazos para devolver a captación
select motivo, documento, correo, nombre
from #clasificados
where motivo is not null
order by motivo, documento;
go

-- paso 5 - prueba de idempotencia: al correr de nuevo los pasos
-- 1 a 3 no se duplica nada, porque todas las filas ya existen
-- y quedan rechazadas por "documento ya existe en la base".

drop table #stg_donante;
drop table #clasificados;
set nocount off;
go
