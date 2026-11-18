-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- Entrega 3 - Concurrencia
-- 09_concurrencia_turismouq.sql
-- Equipo: Daniela Munoz, Maria Jose Marmolejo, Santiago Ovalle
--
-- Dos recepcionistas intentan reservar la misma habitacion para las
-- mismas fechas al mismo tiempo.
--
-- Este script NO se corre con F5. Se necesitan dos sesiones:
--   Sesion A = la hoja normal de SQL Developer.
--   Sesion B = una hoja no compartida (Ctrl+Shift+N) del mismo usuario.
-- Encima de cada sentencia hay una linea -- [A] o -- [B] que dice en
-- que hoja se ejecuta; se ejecuta con Ctrl+Enter, en el orden en que
-- aparece. (La marca va en su propia linea para que el script tambien
-- funcione en SQL*Plus.) El autocommit debe estar
-- apagado (asi viene en SQL Developer).
--
-- Datos del experimento: habitacion 10, del 10 al 13 de enero de 2027
-- (en la carga no hay reservas en enero de 2027).
-- Las reservas de prueba usan ids altos (90001, 90002...) para no
-- chocar con nada; al final de cada escenario se borran.
-- =====================================================================


-- =====================================================================
-- ESCENARIO 1: sin bloqueo (como funcionaba antes)
-- Cada sesion revisa si la habitacion esta libre y, si lo esta,
-- inserta. Es lo que hacen sp_crear_reserva y el disparador de solape.
-- =====================================================================

-- A revisa disponibilidad
-- [A]
SELECT COUNT(*) AS cruces
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
 WHERE rh.id_habitacion = 10
   AND UPPER(r.estado) <> 'CANCELADA'
   AND rh.fecha_checkin  < DATE '2027-01-13'
   AND rh.fecha_checkout > DATE '2027-01-10';
-- Resultado: 0, esta libre

-- B revisa lo mismo
-- [B]
SELECT COUNT(*) AS cruces
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
 WHERE rh.id_habitacion = 10
   AND UPPER(r.estado) <> 'CANCELADA'
   AND rh.fecha_checkin  < DATE '2027-01-13'
   AND rh.fecha_checkout > DATE '2027-01-10';
-- Resultado: 0, tambien la ve libre

-- A reserva
-- [A]
INSERT INTO reserva (id_reserva, fecha_checkin, fecha_checkout, estado, id_cliente, id_alojamiento)
VALUES (90001, DATE '2027-01-10', DATE '2027-01-13', 'Pendiente', 101,
        (SELECT id_alojamiento FROM habitacion WHERE id_habitacion = 10));
-- [A]
INSERT INTO reserva_habitacion (id_reserva_habitacion, fecha_checkin, fecha_checkout,
                                cantidad_huespedes, id_reserva, id_habitacion)
VALUES (990001, DATE '2027-01-10', DATE '2027-01-13', 1, 90001, 10);
-- 1 fila insertada en cada una

-- B reserva la misma habitacion
-- [B]
INSERT INTO reserva (id_reserva, fecha_checkin, fecha_checkout, estado, id_cliente, id_alojamiento)
VALUES (90002, DATE '2027-01-10', DATE '2027-01-13', 'Pendiente', 202,
        (SELECT id_alojamiento FROM habitacion WHERE id_habitacion = 10));
-- [B]
INSERT INTO reserva_habitacion (id_reserva_habitacion, fecha_checkin, fecha_checkout,
                                cantidad_huespedes, id_reserva, id_habitacion)
VALUES (990002, DATE '2027-01-10', DATE '2027-01-13', 1, 90002, 10);
-- 1 fila insertada: B no espera y el disparador TRG_RH_SIN_SOLAPE no
-- la detiene, porque la linea de A todavia no esta confirmada y B no
-- la puede ver.

-- [A]
COMMIT;
-- [B]
COMMIT;

-- Resultado
-- [A]
SELECT rh.id_reserva_habitacion, rh.id_reserva, r.id_cliente, rh.id_habitacion,
       rh.fecha_checkin, rh.fecha_checkout, r.estado
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
 WHERE rh.id_habitacion = 10
   AND rh.fecha_checkin >= DATE '2027-01-01';
-- Resultado: 2 filas. La habitacion 10 quedo vendida dos veces para
-- las mismas noches. Ninguna sesion recibio error.

-- Limpieza del escenario 1
-- [A]
DELETE FROM reserva_habitacion WHERE id_reserva_habitacion IN (990001, 990002);
-- [A]
DELETE FROM reserva WHERE id_reserva IN (90001, 90002);
-- [A]
COMMIT;


-- =====================================================================
-- ESCENARIO 2: con SELECT ... FOR UPDATE (como queda ahora)
-- Antes de revisar disponibilidad, cada sesion bloquea la fila de la
-- habitacion. Es lo que hace pkg_transacciones.sp_reservar_con_pago
-- (script 08).
-- =====================================================================

-- A bloquea la habitacion
-- [A]
SELECT id_habitacion, numero
  FROM habitacion
 WHERE id_habitacion = 10
   FOR UPDATE;
-- 1 fila. Desde ahora A tiene la habitacion 10 apartada.

-- A revisa disponibilidad
-- [A]
SELECT COUNT(*) AS cruces
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
 WHERE rh.id_habitacion = 10
   AND UPPER(r.estado) <> 'CANCELADA'
   AND rh.fecha_checkin  < DATE '2027-01-13'
   AND rh.fecha_checkout > DATE '2027-01-10';
-- Resultado: 0

-- B intenta bloquear la misma habitacion
-- [B]
SELECT id_habitacion, numero
  FROM habitacion
 WHERE id_habitacion = 10
   FOR UPDATE;
-- B se queda esperando (la hoja queda "ejecutando" y no devuelve nada).
-- AQUI VA LA CAPTURA DEL BLOQUEO.

-- Mientras B espera, desde A se puede ver quien bloquea a quien
-- (necesita SELECT_CATALOG_ROLE, que ya tiene el usuario):
-- [A]
SELECT sid, serial#, username, status, blocking_session, event
  FROM v$session
 WHERE username = USER;
-- Resultado: la sesion de B aparece con BLOCKING_SESSION = sid de A y
-- EVENT = 'enq: TX - row lock contention'.

-- A reserva y confirma
-- [A]
INSERT INTO reserva (id_reserva, fecha_checkin, fecha_checkout, estado, id_cliente, id_alojamiento)
VALUES (90003, DATE '2027-01-10', DATE '2027-01-13', 'Pendiente', 101,
        (SELECT id_alojamiento FROM habitacion WHERE id_habitacion = 10));
-- [A]
INSERT INTO reserva_habitacion (id_reserva_habitacion, fecha_checkin, fecha_checkout,
                                cantidad_huespedes, id_reserva, id_habitacion)
VALUES (990003, DATE '2027-01-10', DATE '2027-01-13', 1, 90003, 10);
-- [A]
COMMIT;
-- Apenas A hace COMMIT, B se libera y su SELECT ... FOR UPDATE devuelve
-- la fila de la habitacion 10.
-- En la prueba, B espero 8,65 s: desde que pidio la habitacion hasta
-- el COMMIT de A.

-- B revisa disponibilidad, ya con el bloqueo en la mano
-- [B]
SELECT COUNT(*) AS cruces
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
 WHERE rh.id_habitacion = 10
   AND UPPER(r.estado) <> 'CANCELADA'
   AND rh.fecha_checkin  < DATE '2027-01-13'
   AND rh.fecha_checkout > DATE '2027-01-10';
-- Resultado: 1. Ahora B si ve la reserva de A, asi que no reserva.

-- [B]
ROLLBACK;
-- B suelta la habitacion sin haber cambiado nada.

-- [A]
SELECT COUNT(*) AS lineas
  FROM reserva_habitacion
 WHERE id_habitacion = 10
   AND fecha_checkin >= DATE '2027-01-01';
-- Resultado: 1. Una sola reserva para esas noches.


-- ---------------------------------------------------------------------
-- Variante con NOWAIT: B no espera, recibe el error de una vez
-- ---------------------------------------------------------------------
-- [A]
SELECT id_habitacion FROM habitacion WHERE id_habitacion = 10 FOR UPDATE;
-- [B]
SELECT id_habitacion FROM habitacion WHERE id_habitacion = 10 FOR UPDATE NOWAIT;
-- Resultado en B: ORA-00054 (recurso ocupado y se pidio NOWAIT).
-- Asi recepcion puede decirle al cliente "esa habitacion la estan
-- reservando en este momento" en vez de dejar la pantalla congelada.
-- [A]
ROLLBACK;


-- ---------------------------------------------------------------------
-- Lo mismo con el procedimiento del script 08
-- La reserva 90003 de A ya ocupa la habitacion 10, asi que el
-- procedimiento la rechaza. Este bloque se ejecuta en [B].
-- ---------------------------------------------------------------------
DECLARE
    v_id   reserva.id_reserva%TYPE;
    v_res  VARCHAR2(300);
BEGIN
    pkg_transacciones.sp_reservar_con_pago(202, 10, DATE '2027-01-10', DATE '2027-01-13',
                                           1, 100000, 'PSE', v_id, v_res);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/
-- Resultado: ORA-20006: La habitacion 10 no esta disponible entre
-- 2027-01-10 y 2027-01-13


-- Limpieza del escenario 2
-- [A]
DELETE FROM reserva_habitacion WHERE id_reserva_habitacion = 990003;
-- [A]
DELETE FROM reserva WHERE id_reserva = 90003;
-- [A]
COMMIT;


-- ---------------------------------------------------------------------
-- Comparacion
--
-- Sin bloqueo: las dos sesiones leen "libre" al mismo tiempo, porque
-- en READ COMMITTED ninguna ve lo que la otra no ha confirmado. Las
-- dos insertan y la habitacion queda vendida dos veces. El disparador
-- tampoco lo evita: valida dentro de su propia sesion y no ve la fila
-- pendiente de la otra.
--
-- Con SELECT ... FOR UPDATE: la primera sesion que bloquea la
-- habitacion obliga a la segunda a esperar ANTES de revisar
-- disponibilidad. Cuando la segunda sigue, la primera ya confirmo y su
-- reserva es visible, entonces la segunda la encuentra y no reserva.
-- El costo es que la segunda espera; con NOWAIT no espera y recibe
-- ORA-00054. El bloqueo es solo de esa fila: dos sesiones reservando
-- habitaciones distintas no se estorban.
-- ---------------------------------------------------------------------
