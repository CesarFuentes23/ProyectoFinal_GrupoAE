-- script 02: carga de datos de prueba
-- volúmenes del informe: 4,000 donantes - 25 campañas -
-- 60 proyectos - 90,000 donaciones - ~108,000 asignaciones -
-- 15,000 beneficiarios - 22,000 incorporaciones

use DonacionesONG;
go

set nocount on;
go

-- donantes (4,000; ~15 % empresas)

insert into donantes.Donante (tipo_donante, nombre, documento, correo, telefono, municipio, departamento, fecha_registro)
select
    case when s.value % 20 < 3 then 'empresa' else 'persona' end,
    case when s.value % 20 < 3 then
        case s.value % 5
            when 0 then 'Inversiones ' when 1 then 'Comercial ' when 2 then 'Distribuidora '
            when 3 then 'Grupo ' else 'Industrias '
        end +
        case (s.value / 10) % 10
            when 0 then 'Hernández' when 1 then 'Martínez' when 2 then 'López' when 3 then 'García'
            when 4 then 'Flores' when 5 then 'Ramírez' when 6 then 'Cruz' when 7 then 'Orellana'
            when 8 then 'Fuentes' else 'Castillo'
        end + ' S.A. de C.V.'
    else
        case s.value % 10
            when 0 then 'José' when 1 then 'María' when 2 then 'Carlos' when 3 then 'Ana'
            when 4 then 'Luis' when 5 then 'Carmen' when 6 then 'Jorge' when 7 then 'Sofía'
            when 8 then 'Miguel' else 'Lucía'
        end + ' ' +
        case (s.value / 10) % 10
            when 0 then 'Hernández' when 1 then 'Martínez' when 2 then 'López' when 3 then 'García'
            when 4 then 'Flores' when 5 then 'Ramírez' when 6 then 'Cruz' when 7 then 'Orellana'
            when 8 then 'Fuentes' else 'Castillo'
        end + ' ' +
        case (s.value / 100) % 10
            when 0 then 'Pérez' when 1 then 'Mejía' when 2 then 'Alvarado' when 3 then 'Campos'
            when 4 then 'Rivas' when 5 then 'Aguilar' when 6 then 'Molina' when 7 then 'Batres'
            when 8 then 'Zelaya' else 'Monterrosa'
        end
    end,
    case when s.value % 20 < 3
         then 'NIT-0614-' + right('000000' + cast(s.value as varchar(6)), 6)
         else 'DUI-' + right('00000000' + cast(s.value as varchar(8)), 8)
    end,
    'donante' + cast(s.value as varchar(6)) + '@correo.com',
    '7' + right('0000000' + cast(abs(checksum(newid())) % 10000000 as varchar(7)), 7),
    case s.value % 8
        when 0 then 'San Salvador' when 1 then 'Santa Tecla' when 2 then 'Colón' when 3 then 'Sonsonate'
        when 4 then 'Izalco' when 5 then 'Nahuizalco' when 6 then 'Apopa' else 'Soyapango'
    end,
    case s.value % 8
        when 0 then 'San Salvador' when 1 then 'La Libertad' when 2 then 'La Libertad' when 3 then 'Sonsonate'
        when 4 then 'Sonsonate' when 5 then 'Sonsonate' when 6 then 'San Salvador' else 'San Salvador'
    end,
    dateadd(day, s.value % 1095, '2023-01-01')
from generate_series(1, 4000) as s;
go

-- campañas (25)

insert into finanzas.Campania (nombre, meta_monto, fecha_inicio, fecha_fin)
select
    'Campaña ' + right('00' + cast(s.value as varchar(2)), 2) + ' - ' +
    case s.value % 5
        when 0 then 'Navideña' when 1 then 'Útiles Escolares' when 2 then 'Salud Comunitaria'
        when 3 then 'Vivienda Digna' else 'Canasta Solidaria'
    end + ' ' + cast(2024 + (s.value % 3) as varchar(4)),
    10000 + s.value * 2500,
    dateadd(day, (s.value - 1) * 40, '2024-01-10'),
    dateadd(day, (s.value - 1) * 40 + 45, '2024-01-10')
from generate_series(1, 25) as s;
go

-- proyectos (60: 25 en ejecución, 30 finalizados,
--            3 planificados, 2 suspendidos)

insert into proyectos.Proyecto (nombre, tipo_proyecto, presupuesto, fecha_inicio, fecha_fin, estado, municipio, departamento, responsable)
select
    'Proyecto ' +
    case s.value % 4
        when 0 then 'Educación' when 1 then 'Salud' when 2 then 'Vivienda' else 'Alimentación'
    end + ' ' +
    case s.value % 8
        when 0 then 'San Salvador' when 1 then 'Santa Tecla' when 2 then 'Colón' when 3 then 'Sonsonate'
        when 4 then 'Izalco' when 5 then 'Nahuizalco' when 6 then 'Apopa' else 'Soyapango'
    end + ' ' + right('00' + cast(s.value as varchar(2)), 2),
    case s.value % 4
        when 0 then 'educacion' when 1 then 'salud' when 2 then 'vivienda' else 'alimentacion'
    end,
    400000 + (s.value * 53171) % 900000,
    dateadd(day, (s.value * 37) % 1000, '2023-06-01'),
    case when s.value <= 25 or s.value between 56 and 58 then null
         else dateadd(day, (s.value * 37) % 1000 + 365, '2023-06-01')
    end,
    case when s.value <= 25 then 'en_ejecucion'
         when s.value <= 55 then 'finalizado'
         when s.value <= 58 then 'planificado'
         else 'suspendido'
    end,
    case s.value % 8
        when 0 then 'San Salvador' when 1 then 'Santa Tecla' when 2 then 'Colón' when 3 then 'Sonsonate'
        when 4 then 'Izalco' when 5 then 'Nahuizalco' when 6 then 'Apopa' else 'Soyapango'
    end,
    case s.value % 8
        when 0 then 'San Salvador' when 1 then 'La Libertad' when 2 then 'La Libertad' when 3 then 'Sonsonate'
        when 4 then 'Sonsonate' when 5 then 'Sonsonate' when 6 then 'San Salvador' else 'San Salvador'
    end,
    case s.value % 6
        when 0 then 'Paola Orellana' when 1 then 'Diego Cruz' when 2 then 'César Fuentes'
        when 3 then 'Carlos Flores' when 4 then 'Marta Rivas' else 'Hugo Campos'
    end
from generate_series(1, 60) as s;
go

-- donaciones (90,000 entre 2024-01-01 y 2026-11-10;
--             ~90 % confirmadas, 6 % registradas, 4 % anuladas)

insert into finanzas.Donacion (donante_id, campania_id, fecha_donacion, monto, metodo_pago, estado, referencia)
select
    abs(checksum(newid())) % 4000 + 1,
    case when s.value % 5 < 3 then (s.value % 25) + 1 else null end,
    dateadd(minute, abs(checksum(newid())) % 1497600, '2024-01-01'),
    case when s.value % 10 = 0
         then round(500 + (abs(checksum(newid())) % 450000) / 100.0, 2)
         else round(5 + (abs(checksum(newid())) % 49500) / 100.0, 2)
    end,
    case s.value % 4
        when 0 then 'efectivo' when 1 then 'tarjeta' when 2 then 'transferencia' else 'cheque'
    end,
    case when s.value % 100 < 90 then 'confirmada'
         when s.value % 100 < 96 then 'registrada'
         else 'anulada'
    end,
    case when s.value % 4 in (1, 2) then 'REF-' + cast(100000 + s.value as varchar(10)) else null end
from generate_series(1, 90000) as s;
go

-- asignaciones de fondos (solo donaciones confirmadas;
--  60 % del monto a un proyecto y, en 1 de cada 3, 40 % a otro)

insert into finanzas.AsignacionFondos (donacion_id, proyecto_id, monto_asignado, fecha_asignacion)
select
    d.donacion_id,
    (d.donacion_id + 7) % 60 + 1,
    round(d.monto * 0.6, 2),
    cast(dateadd(day, 2, d.fecha_donacion) as date)
from finanzas.Donacion d
where d.estado = 'confirmada';
go

insert into finanzas.AsignacionFondos (donacion_id, proyecto_id, monto_asignado, fecha_asignacion)
select
    d.donacion_id,
    (d.donacion_id + 23) % 60 + 1,
    round(d.monto * 0.4, 2),
    cast(dateadd(day, 3, d.fecha_donacion) as date)
from finanzas.Donacion d
where d.estado = 'confirmada'
  and d.donacion_id % 3 = 0;
go

-- beneficiarios (15,000) e incorporaciones (~22,000)

insert into proyectos.Beneficiario (nombre, fecha_nacimiento, municipio, departamento, fecha_registro)
select
    case s.value % 10
        when 0 then 'Pedro' when 1 then 'Rosa' when 2 then 'Juan' when 3 then 'Elena'
        when 4 then 'Mario' when 5 then 'Silvia' when 6 then 'Óscar' when 7 then 'Claudia'
        when 8 then 'Raúl' else 'Patricia'
    end + ' ' +
    case (s.value / 10) % 10
        when 0 then 'Hernández' when 1 then 'Martínez' when 2 then 'López' when 3 then 'García'
        when 4 then 'Flores' when 5 then 'Ramírez' when 6 then 'Cruz' when 7 then 'Orellana'
        when 8 then 'Fuentes' else 'Castillo'
    end + ' ' +
    case (s.value / 100) % 10
        when 0 then 'Pérez' when 1 then 'Mejía' when 2 then 'Alvarado' when 3 then 'Campos'
        when 4 then 'Rivas' when 5 then 'Aguilar' when 6 then 'Molina' when 7 then 'Batres'
        when 8 then 'Zelaya' else 'Monterrosa'
    end,
    dateadd(day, abs(checksum(newid())) % 24000, '1952-01-01'),
    case s.value % 8
        when 0 then 'San Salvador' when 1 then 'Santa Tecla' when 2 then 'Colón' when 3 then 'Sonsonate'
        when 4 then 'Izalco' when 5 then 'Nahuizalco' when 6 then 'Apopa' else 'Soyapango'
    end,
    case s.value % 8
        when 0 then 'San Salvador' when 1 then 'La Libertad' when 2 then 'La Libertad' when 3 then 'Sonsonate'
        when 4 then 'Sonsonate' when 5 then 'Sonsonate' when 6 then 'San Salvador' else 'San Salvador'
    end,
    dateadd(day, s.value % 1300, '2023-01-15')
from generate_series(1, 15000) as s;
go

insert into proyectos.ProyectoBeneficiario (proyecto_id, beneficiario_id, fecha_incorporacion)
select
    b.beneficiario_id % 60 + 1,
    b.beneficiario_id,
    dateadd(day, b.beneficiario_id % 1000, '2023-07-01')
from proyectos.Beneficiario b;
go

insert into proyectos.ProyectoBeneficiario (proyecto_id, beneficiario_id, fecha_incorporacion)
select
    (b.beneficiario_id + 13) % 60 + 1,
    b.beneficiario_id,
    dateadd(day, b.beneficiario_id % 900, '2023-10-01')
from proyectos.Beneficiario b
where b.beneficiario_id <= 7000;
go

set nocount off;
go

select 'Donante' as tabla, count(*) as filas from donantes.Donante
union all select 'Campania', count(*) from finanzas.Campania
union all select 'Proyecto', count(*) from proyectos.Proyecto
union all select 'Donacion', count(*) from finanzas.Donacion
union all select 'AsignacionFondos', count(*) from finanzas.AsignacionFondos
union all select 'Beneficiario', count(*) from proyectos.Beneficiario
union all select 'ProyectoBeneficiario', count(*) from proyectos.ProyectoBeneficiario;
go
