# TurismoUQ · Proyecto integrador · Bases de Datos II · 2026-2

Equipo: Daniela Muñoz, María José Marmolejo, Santiago Ovalle.

## Orden de ejecución

Los scripts están en la carpeta `sql` y se corren en este orden, con F5 (Run Script) en Oracle SQL Developer, todos con el mismo usuario dueño de las tablas. Las excepciones son el 11, que se corre como SYSTEM, y el 09 y el 13, que se ejecutan sentencia por sentencia en varias sesiones (cada script explica cómo).

| # | Script | Entrega | Contenido |
|---|--------|---------|-----------|
| 00 | `00_reset.sql` | — | Opcional: borra todo para empezar de cero en un usuario ya usado |
| 01 | `01_ddl.sql` | 1 | 15 tablas con PK, FK, CHECK, NOT NULL y UNIQUE |
| 02 | `02_carga.sql` | 1 | Carga con el volumen mínimo, 2024-2026, sin solapes (semilla fija) |
| 03 | `03_consultas.sql` | 1 | 7 consultas de análisis |
| 04 | `04_paquete_turismouq.sql` | 2 | Paquete `PKG_RESERVAS`: `fn_valor_estadia`, `sp_crear_reserva`, cursor explícito con parámetros (`sp_liquidacion_mensual`, `sp_liquidacion_masiva`) |
| 05 | `05_disparadores_turismouq.sql` | 2 | `TRG_TARIFA_AUDITORIA` (auditoría por sentencia) y `TRG_RH_SIN_SOLAPE` (solape, por fila) |
| 06 | `06_tablespace_vista_materializada_turismouq.sql` | 2 | Tablespace `TS_HISTORIAL_RESERVAS`, tabla `RESERVA_HISTORICO` y vista materializada `MV_OCUPACION_MENSUAL` |
| 07 | `07_pruebas_turismouq.sql` | 2 | Pruebas de cada componente |
| 08 | `08_transacciones_turismouq.sql` | 3 | Paquete `PKG_TRANSACCIONES`: reserva + pago en una transacción con `SAVEPOINT`, pruebas y rollback parcial paso a paso |
| 09 | `09_concurrencia_turismouq.sql` | 3 | Experimento con dos sesiones (A y B): doble reserva sin bloqueo y solución con `SELECT ... FOR UPDATE` |
| 10 | `10_indices_turismouq.sql` | 3 | 3 consultas lentas con plan antes/después (índice compuesto, de llave foránea y basado en función) y un caso donde el índice no ayuda |
| 11 | `11_seguridad_dba_turismouq.sql` | 3 | **Como SYSTEM**: perfil `PERFIL_TURISMO`, 4 roles y 4 usuarios |
| 12 | `12_seguridad_esquema_turismouq.sql` | 3 | Vistas de recepción y del administrador de alojamiento, y `GRANT` por rol |
| 13 | `13_pruebas_seguridad_turismouq.sql` | 3 | Pruebas conectado como cada usuario |

## Usuario y privilegios

Como SYSTEM, conectado a la PDB (XEPDB1 o FREEPDB1):

```sql
CREATE USER turismo_e2 IDENTIFIED BY Turismo2026
  DEFAULT TABLESPACE users QUOTA UNLIMITED ON users;

GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
      CREATE PROCEDURE, CREATE TRIGGER, CREATE MATERIALIZED VIEW,
      CREATE TABLESPACE, DROP TABLESPACE, CREATE JOB,
      UNLIMITED TABLESPACE TO turismo_e2;

GRANT SELECT_CATALOG_ROLE TO turismo_e2;
```

El script 06 calcula solo la carpeta del datafile; no hay rutas escritas a mano.

## Pruebas (07) en SQL Developer

- Ejecutar primero `SET SERVEROUTPUT ON` con F5.
- Consultas SELECT: Ctrl+Enter (resultado en Query Result).
- Bloques BEGIN … END: seleccionarlos hasta la `/` y F5 (mensajes en Script Output).

## Entrega 3 en SQL Developer

- **09 (concurrencia):** sesión A en la hoja normal y sesión B en una hoja no compartida (Ctrl+Shift+N). Cada sentencia dice al final si va en `[A]` o en `[B]`.
- **10 (índices):** el usuario necesita `SELECT_CATALOG_ROLE` (ya está en el bloque de privilegios de arriba) para ver los planes reales con `DBMS_XPLAN.DISPLAY_CURSOR`.
- **11 (seguridad):** conectado como SYSTEM a la PDB. Crea los usuarios `RECEPCION1`, `ENCARGADO1`, `GERENTE1` y `AUDITOR1` (claves en el encabezado del script).
- **13 (pruebas de seguridad):** se crea una conexión por usuario. Si el dueño no se llama `TURISMO_E2`, se cambia el `DEFINE dueno` del inicio.

