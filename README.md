# Proyecto de Cátedra: Administración de Bases de Datos

## Sistema de Donaciones de una ONG: Fundación Raíces Solidarias

Universidad Centroamericana José Simeón Cañas (UCA), ciclo 02-2026. Noviembre de 2026.

| Integrante | Carnet |
|---|---|
| Alejandra Paola Orellana | 00108225 |
| Diego Cruz | 00140725 |
| César Fuentes | 00118825 |
| Carlos Flores | 00079225 |

## 1. Contenido del repositorio

| Archivo | Descripción |
|---|---|
| `01_creacion_bd.sql` | Base, archivos, filegroups, esquemas y tablas |
| `02_carga_datos.sql` | Datos de prueba: 4,000 donantes y 90,000 donaciones |
| `03_seguridad.sql` | Logins, usuarios, roles, permisos y prueba de acceso denegado |
| `04_indices_y_consultas.sql` | Consultas antes, índices, consultas después y vistas para Power BI |
| `04b_medicion_consultas.sql` | Mediciones con `statistics io` y `statistics time` |
| `05_respaldos_agent.sql` | Respaldo full inicial y cuatro jobs del Agent |
| `06_recuperacion_desastre.sql` | Simulacro de recuperación en una base alterna |
| `07_migracion_csv.sql` | Migración de 300 donantes desde CSV |
| `datos/donantes_historicos.csv` | Archivo de origen de la migración |
| `Dashboard_Donaciones.pbix` | Dashboard de Power BI con tres gráficos |
| `Informe_Tecnico_ONG_Fase1.pdf` | Informe técnico |

## 2. Entorno

SQL Server 2025 Developer en un contenedor Docker llamado `sqlserver-2025`, puerto 1434, usuario `sa`. SSMS se conecta a `localhost,1434` con autenticación de SQL Server. El Agent debe estar activo (`MSSQL_AGENT_ENABLED=true`).

| Ruta en el contenedor | Uso |
|---|---|
| `/var/opt/mssql` | datos y log |
| `/backup` | volumen de respaldos, con las subcarpetas `Full`, `Diferencial` y `Log` |
| `/csv` | carpeta del equipo: aquí va `donantes_historicos.csv` y la subcarpeta `copia_externa` |

Crear las carpetas antes del script 05:

```
docker exec sqlserver-2025 mkdir -p /backup/Full /backup/Diferencial /backup/Log
docker exec sqlserver-2025 mkdir -p /csv/copia_externa
```

Si hace falta, dar permisos con `chmod -R 777` sobre esas rutas.

## 3. Orden de ejecución

| Paso | Script | Resultado esperado |
|---|---|---|
| 1 | `01_creacion_bd.sql` | Base `DonacionesONG` con 7 tablas |
| 2 | `02_carga_datos.sql` | Datos de prueba en menos de un minuto |
| 3 | `03_seguridad.sql` | Los dos Msg 229 son el resultado esperado |
| 4 | `04_indices_y_consultas.sql` y `04b_medicion_consultas.sql` | Medición antes y después de los índices |
| 5 | `05_respaldos_agent.sql` | Full inicial y cuatro jobs |
| 6 | `07_migracion_csv.sql` | 250 filas cargadas y 50 rechazadas |
| 7 | `06_recuperacion_desastre.sql` | Simulacro por bloques; al final, `drop database DonacionesONG_Rec;` |

**Antes de `Job_Copia_Externa`** ejecutar `dbcc traceon(3042, -1)`. Se pierde al reiniciar el servidor; sin ella el respaldo hacia `/csv` falla con el error 31.

**Si el script 06 falla con el error 4305**, falta un log en la cadena: tomar un full nuevo (`backup database` con `checksum` y `compression`), ejecutar el bloque de la cola del log y repetir.

Cerrar sin guardar las pestañas viejas de SSMS antes de abrir estos archivos, porque SSMS puede pisarlos con la versión anterior.

## 4. Credenciales de demostración

Cambiarlas antes de la defensa.

| Login | Contraseña |
|---|---|
| `login_direccion` | `Direccion#2026!` |
| `login_captacion` | `Captacion#2026!` |
| `login_finanzas` | `Finanzas#2026!` |
| `login_proyectos` | `Proyectos#2026!` |
| `login_powerbi` | `PowerBi#2026!` |

## 5. Power BI

1. Obtener datos, SQL Server, servidor `localhost,1434`, base `DonacionesONG`, credenciales de base de datos con `login_powerbi`.
2. Importar solo las tres vistas: `finanzas.vw_DetalleDonaciones`, `proyectos.vw_AvanceProyectos` y `finanzas.vw_RankingDonantes`.
3. Las medidas DAX están en la sección 8.2 del informe.

Página 1: tarjetas, recaudación mensual, cobertura por proyecto y segmentadores. Página 2: ranking de los 10 mayores donantes.
