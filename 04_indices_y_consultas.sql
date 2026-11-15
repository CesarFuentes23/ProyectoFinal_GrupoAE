-- script 04: consultas clave, medición, índices y vistas
-- metodología: ejecutar la sección a con el plan de ejecución
-- real activado (ctrl+m en ssms) y guardar capturas (antes);
-- ejecutar la sección b; repetir las consultas en la sección c
-- y guardar capturas (después); terminar con la sección d.

use DonacionesONG;
go

-- sección a - medición antes (sin índices no agrupados)

set statistics io on;
set statistics time on;
go

-- consulta 1: donaciones confirmadas de empresas, último trimestre
select d.nombre as donante,
       d.documento,
       c.nombre as campania,
       dn.fecha_donacion,
       dn.monto,
       dn.metodo_pago,
       dn.referencia
from finanzas.Donacion dn
    inner join donantes.Donante d on d.donante_id = dn.donante_id
    left join finanzas.Campania c on c.campania_id = dn.campania_id
where dn.estado = 'confirmada'
  and dn.fecha_donacion >= '2026-07-01'
  and dn.fecha_donacion <  '2026-10-01'
  and d.tipo_donante = 'empresa'
order by dn.monto desc;
go

-- consulta 2: cobertura presupuestaria de proyectos en ejecución
select p.nombre as proyecto,
       p.tipo_proyecto,
       p.departamento,
       p.presupuesto,
       sum(a.monto_asignado) as fondos_asignados,
       convert(decimal(5,2), sum(a.monto_asignado) * 100.0 / p.presupuesto) as cobertura_pct,
       count(distinct dn.donante_id) as donantes_distintos
from proyectos.Proyecto p
    inner join finanzas.AsignacionFondos a on a.proyecto_id = p.proyecto_id
    inner join finanzas.Donacion dn on dn.donacion_id = a.donacion_id
where p.estado = 'en_ejecucion'
  and dn.estado = 'confirmada'
group by p.proyecto_id, p.nombre, p.tipo_proyecto, p.departamento, p.presupuesto
having sum(a.monto_asignado) < p.presupuesto
order by cobertura_pct asc;
go

-- consulta 3: ranking anual de donantes con acumulado (pareto)
with totales as (
    select d.donante_id,
           d.nombre,
           d.tipo_donante,
           sum(dn.monto) as total_anual,
           count(*) as numero_donaciones
    from donantes.Donante d
        inner join finanzas.Donacion dn on dn.donante_id = d.donante_id
    where dn.estado = 'confirmada'
      and dn.fecha_donacion >= '2026-01-01'
      and dn.fecha_donacion <  '2027-01-01'
    group by d.donante_id, d.nombre, d.tipo_donante
)
select tipo_donante,
       rank() over (partition by tipo_donante order by total_anual desc) as posicion,
       nombre,
       numero_donaciones,
       total_anual,
       sum(total_anual) over (partition by tipo_donante
                              order by total_anual desc
                              rows unbounded preceding) as acumulado,
       convert(decimal(5,2),
               sum(total_anual) over (partition by tipo_donante
                                      order by total_anual desc
                                      rows unbounded preceding) * 100.0
               / sum(total_anual) over (partition by tipo_donante)) as pct_acumulado
from totales
order by tipo_donante, posicion;
go

set statistics io off;
set statistics time off;
go

-- sección b - creación de los índices no agrupados

create nonclustered index IX_Donacion_estado_fecha
on finanzas.Donacion (estado, fecha_donacion)
include (donante_id, campania_id, monto, metodo_pago, referencia)
on FG_Indices;
go

create nonclustered index IX_Asignacion_proyecto
on finanzas.AsignacionFondos (proyecto_id)
include (donacion_id, monto_asignado)
on FG_Indices;
go

create nonclustered index IX_Donacion_donante_fecha
on finanzas.Donacion (donante_id, fecha_donacion)
include (monto, estado)
on FG_Indices;
go

select i.name as indice,
       object_schema_name(i.object_id) + '.' + object_name(i.object_id) as tabla,
       f.name as filegroup_asignado
from sys.indexes i
    inner join sys.filegroups f on f.data_space_id = i.data_space_id
where i.name like 'IX_%'
  and object_schema_name(i.object_id) <> 'sys'
order by tabla, indice;
go

-- sección c - medición después
-- repetir aquí las tres consultas de la sección a con
-- statistics io, time y el plan real activado, y capturar.
-- (copiarlas tal cual; se omiten para no duplicar el script.)

-- sección d - vistas para power bi (trazabilidad del tablero)
-- las vistas no admiten order by; los filtros fijos de fecha y
-- tipo de la consulta 1 y el having de la 2 pasan a ser
-- segmentadores del tablero.

create or alter view finanzas.vw_DetalleDonaciones
as
select d.nombre as donante,
       d.documento,
       d.tipo_donante,
       d.departamento,
       c.nombre as campania,
       dn.fecha_donacion,
       dn.monto,
       dn.metodo_pago,
       dn.referencia
from finanzas.Donacion dn
    inner join donantes.Donante d on d.donante_id = dn.donante_id
    left join finanzas.Campania c on c.campania_id = dn.campania_id
where dn.estado = 'confirmada';
go

create or alter view proyectos.vw_AvanceProyectos
as
select p.nombre as proyecto,
       p.tipo_proyecto,
       p.departamento,
       p.presupuesto,
       sum(a.monto_asignado) as fondos_asignados,
       convert(decimal(5,2), sum(a.monto_asignado) * 100.0 / p.presupuesto) as cobertura_pct,
       count(distinct dn.donante_id) as donantes_distintos
from proyectos.Proyecto p
    inner join finanzas.AsignacionFondos a on a.proyecto_id = p.proyecto_id
    inner join finanzas.Donacion dn on dn.donacion_id = a.donacion_id
where p.estado = 'en_ejecucion'
  and dn.estado = 'confirmada'
group by p.proyecto_id, p.nombre, p.tipo_proyecto, p.departamento, p.presupuesto;
go

create or alter view finanzas.vw_RankingDonantes
as
with totales as (
    select d.donante_id,
           d.nombre,
           d.tipo_donante,
           sum(dn.monto) as total_anual,
           count(*) as numero_donaciones
    from donantes.Donante d
        inner join finanzas.Donacion dn on dn.donante_id = d.donante_id
    where dn.estado = 'confirmada'
      and dn.fecha_donacion >= '2026-01-01'
      and dn.fecha_donacion <  '2027-01-01'
    group by d.donante_id, d.nombre, d.tipo_donante
)
select tipo_donante,
       rank() over (partition by tipo_donante order by total_anual desc) as posicion,
       nombre,
       numero_donaciones,
       total_anual,
       sum(total_anual) over (partition by tipo_donante
                              order by total_anual desc
                              rows unbounded preceding) as acumulado,
       convert(decimal(5,2),
               sum(total_anual) over (partition by tipo_donante
                                      order by total_anual desc
                                      rows unbounded preceding) * 100.0
               / sum(total_anual) over (partition by tipo_donante)) as pct_acumulado
from totales;
go

select top 20 * from finanzas.vw_RankingDonantes order by tipo_donante, posicion;
go
