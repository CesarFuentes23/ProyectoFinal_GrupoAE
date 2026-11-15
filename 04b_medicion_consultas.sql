-- script 04b: medición de las 3 consultas (usar antes y después)
-- ctrl+m activado; capturar messages y el plan de cada consulta.
-- antes: sin los 3 índices ix_ (si existen, borrarlos primero).
-- después: con los índices creados (sección b del script 04).

use DonacionesONG;
go

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
