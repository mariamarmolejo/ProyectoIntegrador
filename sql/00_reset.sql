-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- 00_reset_turismouq.sql
--
-- Solo lo usan si YA habian corrido 01_ddl_turismouq.sql antes y
-- quieren empezar de cero sobre la MISMA conexion (por ejemplo,
-- porque cambiaron algo del modelo). Si nunca han corrido el DDL en
-- esta conexion, NO hace falta correr este archivo.
--
-- Son 15 sentencias DROP TABLE sueltas, sin PL/SQL ni bloques: cada
-- una se ejecuta y se evalua por separado, igual que cualquier
-- sentencia normal.
--
-- COMO EJECUTARLO: con "Run Script" (F5). Si alguna tabla no existe
-- todavia, esa linea especifica va a mostrar un error "ORA-00942:
-- la tabla o vista no existe" -- es normal y esperado, simplemente
-- le dan "Saltar" (o "Skip all" para que no les pregunte en cada
-- una) y el script sigue con las demas sin problema.
-- =====================================================================

DROP TABLE auditoria_tarifa CASCADE CONSTRAINTS PURGE;
DROP TABLE resena CASCADE CONSTRAINTS PURGE;
DROP TABLE reserva_servicio CASCADE CONSTRAINTS PURGE;
DROP TABLE pago CASCADE CONSTRAINTS PURGE;
DROP TABLE reserva_habitacion CASCADE CONSTRAINTS PURGE;
DROP TABLE reserva CASCADE CONSTRAINTS PURGE;
DROP TABLE usuario_sistema CASCADE CONSTRAINTS PURGE;
DROP TABLE servicio CASCADE CONSTRAINTS PURGE;
DROP TABLE tarifa CASCADE CONSTRAINTS PURGE;
DROP TABLE habitacion CASCADE CONSTRAINTS PURGE;
DROP TABLE alojamiento CASCADE CONSTRAINTS PURGE;
DROP TABLE temporada CASCADE CONSTRAINTS PURGE;
DROP TABLE cliente CASCADE CONSTRAINTS PURGE;
DROP TABLE tipo_alojamiento CASCADE CONSTRAINTS PURGE;
DROP TABLE municipio CASCADE CONSTRAINTS PURGE;

-- Verificacion: esta consulta debe devolver 0 filas si el reset
-- quedo completo.
SELECT table_name FROM user_tables
WHERE table_name IN (
    'MUNICIPIO','TIPO_ALOJAMIENTO','CLIENTE','TEMPORADA','ALOJAMIENTO',
    'HABITACION','TARIFA','SERVICIO','USUARIO_SISTEMA','RESERVA',
    'RESERVA_HABITACION','PAGO','RESERVA_SERVICIO','RESENA','AUDITORIA_TARIFA'
);
