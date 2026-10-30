-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- 00_reset.sql
-- Equipo: Daniela Munoz, Maria Jose Marmolejo, Santiago Ovalle
--
-- OPCIONAL. Solo se usa para volver a empezar de cero en un usuario
-- donde YA se corrieron los scripts. En un usuario nuevo NO hace falta.
--
-- Borra primero los objetos de la Entrega 2 (vista materializada,
-- historico, paquete, tablespace) y despues las 15 tablas de la
-- Entrega 1 (los disparadores se borran junto con sus tablas).
--
-- COMO EJECUTARLO: con F5 (Run Script). Si un objeto no existe, esa
-- linea muestra un error (ORA-00942, ORA-04043, ORA-12003 o
-- ORA-00959): es normal, el script sigue con las demas.
-- =====================================================================

-- Entrega 2
DROP MATERIALIZED VIEW mv_ocupacion_mensual;
DROP TABLE reserva_historico PURGE;
DROP PACKAGE pkg_reservas;
DROP TABLESPACE ts_historial_reservas INCLUDING CONTENTS AND DATAFILES;

-- Entrega 1
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

-- Verificacion: debe devolver 0 filas
SELECT object_name, object_type
  FROM user_objects
 WHERE object_name IN (
    'MUNICIPIO','TIPO_ALOJAMIENTO','CLIENTE','TEMPORADA','ALOJAMIENTO',
    'HABITACION','TARIFA','SERVICIO','USUARIO_SISTEMA','RESERVA',
    'RESERVA_HABITACION','PAGO','RESERVA_SERVICIO','RESENA','AUDITORIA_TARIFA',
    'RESERVA_HISTORICO','MV_OCUPACION_MENSUAL','PKG_RESERVAS');
