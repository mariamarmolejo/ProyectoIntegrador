# TurismoUQ · Proyecto integrador · Bases de Datos II · 2026-2

Equipo: Daniela Muñoz, María José Marmolejo, Santiago Ovalle.

## Orden de ejecución

Los scripts están en la carpeta `sql` y se corren en este orden, con F5 (Run Script) en Oracle SQL Developer, todos con el mismo usuario.

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
