-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- Entrega 2 - Evidencia de pruebas
-- 07_pruebas_turismouq.sql
-- Equipo: Daniela Munoz, Maria Jose Marmolejo, Santiago Ovalle
--
-- Se corre DESPUES de 04, 05 y 06.
-- Como correrlo en Oracle SQL Developer:
--   * Primero ejecutar SET SERVEROUTPUT ON (abajo) con F5, para que los
--     bloques muestren sus mensajes en la pestana Script Output.
--   * Consultas SELECT: cursor dentro y Ctrl+Enter (pestana Query Result).
--   * Bloques BEGIN ... END: seleccionarlo completo, hasta la "/", y F5.
--   * Todo el script de una vez: F5 sin seleccionar nada.
--
-- Los bloques PL/SQL terminan en ROLLBACK, asi las pruebas no dejan
-- datos. Solo la prueba 7 hace COMMIT (la vista materializada solo ve
-- datos confirmados) y al final borra lo que creo.
-- Las fechas de prueba son de enero de 2027, donde la carga no tiene
-- reservas (y 2030 para "sin temporada").
-- La carga usa una semilla fija (DBMS_RANDOM.SEED), asi que los
-- resultados son los mismos en cualquier computador.
-- =====================================================================

SET SERVEROUTPUT ON


-- =====================================================================
-- PRUEBA 0: estado de los objetos (evidencia del paquete)
-- Todos deben estar VALID / ENABLED y user_errors debe salir vacio.
-- =====================================================================
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN ('PKG_RESERVAS', 'TRG_TARIFA_AUDITORIA', 'TRG_RH_SIN_SOLAPE',
                       'MV_OCUPACION_MENSUAL', 'RESERVA_HISTORICO')
 ORDER BY object_name, object_type;

SELECT procedure_name AS subprograma_publico
  FROM user_procedures
 WHERE object_name = 'PKG_RESERVAS' AND procedure_name IS NOT NULL
 ORDER BY subprograma_publico;

SELECT name, type, line, text FROM user_errors ORDER BY name, type, sequence;

SELECT trigger_name, trigger_type, triggering_event, table_name, status
  FROM user_triggers
 WHERE trigger_name IN ('TRG_TARIFA_AUDITORIA', 'TRG_RH_SIN_SOLAPE');

-- Estados que usa la carga (para leer bien las demas pruebas)
SELECT estado, COUNT(*) AS reservas FROM reserva GROUP BY estado ORDER BY estado;

-- Resultado esperado: PACKAGE y PACKAGE BODY VALID; 4 subprogramas
-- publicos; user_errors sin filas; 2 disparadores COMPOUND ENABLED.


-- =====================================================================
-- PRUEBA 1: fn_valor_estadia (noche por noche, varias temporadas)
-- Habitacion 1, del 2026-10-09 al 2026-10-15 = 6 noches que cruzan tres
-- temporadas: Media (9 y 10 oct), Alta del puente festivo (11, 12 y 13
-- oct) y Baja (14 oct). El 15 es el dia de salida y no se cobra.
-- =====================================================================

-- 1.a Detalle noche por noche, calculado a mano (sin la funcion)
SELECT n.noche, te.nombre AS temporada, te.tipo, t.precio_noche
  FROM (SELECT DATE '2026-10-09' + LEVEL - 1 AS noche
          FROM dual CONNECT BY LEVEL <= 6) n
  JOIN temporada te ON n.noche BETWEEN te.fecha_inicio AND te.fecha_fin
  JOIN tarifa t     ON t.id_temporada = te.id_temporada AND t.id_habitacion = 1
 ORDER BY n.noche;

-- 1.b Suma a mano frente a la funcion
SELECT (SELECT SUM(t.precio_noche)
          FROM (SELECT DATE '2026-10-09' + LEVEL - 1 AS noche
                  FROM dual CONNECT BY LEVEL <= 6) n
          JOIN temporada te ON n.noche BETWEEN te.fecha_inicio AND te.fecha_fin
          JOIN tarifa t     ON t.id_temporada = te.id_temporada AND t.id_habitacion = 1) AS suma_a_mano,
       pkg_reservas.fn_valor_estadia(1, DATE '2026-10-09', DATE '2026-10-15') AS valor_funcion
  FROM dual;

-- Resultado esperado: 6 filas (9 y 10 en 'Media agosto-octubre 2026',
-- 11 a 13 en 'Puente festivo octubre 2026', 14 en 'Baja
-- octubre-noviembre 2026') y suma_a_mano = valor_funcion.
-- Resultado obtenido:

-- 1.c Casos de error de la funcion
BEGIN
    DBMS_OUTPUT.PUT_LINE(pkg_reservas.fn_valor_estadia(1, DATE '2026-10-15', DATE '2026-10-15'));
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Salida igual a entrada  -> ' || SQLERRM);
END;
/

BEGIN
    DBMS_OUTPUT.PUT_LINE(pkg_reservas.fn_valor_estadia(1, DATE '2030-02-01', DATE '2030-02-03'));
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Fechas sin temporada    -> ' || SQLERRM);
END;
/

BEGIN
    DBMS_OUTPUT.PUT_LINE(pkg_reservas.fn_valor_estadia(99999, DATE '2026-10-09', DATE '2026-10-15'));
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Habitacion inexistente  -> ' || SQLERRM);
END;
/

-- Resultado esperado: ORA-20001, ORA-20002 y ORA-20003.
-- Resultado obtenido:


-- =====================================================================
-- PRUEBA 2: sp_crear_reserva (caso feliz y cada validacion)
-- =====================================================================
DECLARE
    v_hab  habitacion.id_habitacion%TYPE;
    v_cap  habitacion.capacidad_maxima%TYPE;
    v_res  reserva.id_reserva%TYPE;
    v_res1 reserva.id_reserva%TYPE;
BEGIN
    SELECT id_habitacion, capacidad_maxima INTO v_hab, v_cap
      FROM (SELECT id_habitacion, capacidad_maxima FROM habitacion
             WHERE capacidad_maxima >= 2 ORDER BY id_habitacion)
     WHERE ROWNUM = 1;
    DBMS_OUTPUT.PUT_LINE('Habitacion de prueba: ' || v_hab || ' (capacidad ' || v_cap || ')');
--
    -- 1) reserva valida
    pkg_reservas.sp_crear_reserva(1, v_hab, DATE '2027-01-05', DATE '2027-01-08', 2, v_res1);
    DBMS_OUTPUT.PUT_LINE('1) Reserva valida -> id ' || v_res1);
--
    -- 2) misma habitacion, fechas que se cruzan (esperado -20006)
    BEGIN
        pkg_reservas.sp_crear_reserva(2, v_hab, DATE '2027-01-06', DATE '2027-01-09', 2, v_res);
        DBMS_OUTPUT.PUT_LINE('2) ERROR: se creo y no debia');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('2) Habitacion ocupada    -> ' || SQLERRM);
    END;
--
    -- 3) salida antes de la entrada (esperado -20001)
    BEGIN
        pkg_reservas.sp_crear_reserva(2, v_hab, DATE '2027-01-12', DATE '2027-01-10', 2, v_res);
        DBMS_OUTPUT.PUT_LINE('3) ERROR: se creo y no debia');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('3) Salida antes          -> ' || SQLERRM);
    END;
--
    -- 4) salida igual a la entrada (esperado -20001)
    BEGIN
        pkg_reservas.sp_crear_reserva(2, v_hab, DATE '2027-01-12', DATE '2027-01-12', 2, v_res);
        DBMS_OUTPUT.PUT_LINE('4) ERROR: se creo y no debia');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('4) Salida igual          -> ' || SQLERRM);
    END;
--
    -- 5) mas huespedes que la capacidad (esperado -20005)
    BEGIN
        pkg_reservas.sp_crear_reserva(2, v_hab, DATE '2027-01-12', DATE '2027-01-14', v_cap + 1, v_res);
        DBMS_OUTPUT.PUT_LINE('5) ERROR: se creo y no debia');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('5) Capacidad excedida    -> ' || SQLERRM);
    END;
--
    -- 6) cero huespedes (esperado -20007)
    BEGIN
        pkg_reservas.sp_crear_reserva(2, v_hab, DATE '2027-01-12', DATE '2027-01-14', 0, v_res);
        DBMS_OUTPUT.PUT_LINE('6) ERROR: se creo y no debia');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('6) Sin huespedes         -> ' || SQLERRM);
    END;
--
    -- 7) habitacion que no existe (esperado -20003)
    BEGIN
        pkg_reservas.sp_crear_reserva(2, 99999, DATE '2027-01-12', DATE '2027-01-14', 2, v_res);
        DBMS_OUTPUT.PUT_LINE('7) ERROR: se creo y no debia');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('7) Habitacion inexistente-> ' || SQLERRM);
    END;
--
    -- 8) cliente que no existe (esperado -20004)
    BEGIN
        pkg_reservas.sp_crear_reserva(99999, v_hab, DATE '2027-01-12', DATE '2027-01-14', 2, v_res);
        DBMS_OUTPUT.PUT_LINE('8) ERROR: se creo y no debia');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('8) Cliente inexistente   -> ' || SQLERRM);
    END;
--
    -- 9) si la reserva 1) se cancela, la habitacion queda libre otra vez
    UPDATE reserva SET estado = 'Cancelada' WHERE id_reserva = v_res1;
    pkg_reservas.sp_crear_reserva(2, v_hab, DATE '2027-01-06', DATE '2027-01-09', 2, v_res);
    DBMS_OUTPUT.PUT_LINE('9) Tras cancelar la reserva ' || v_res1
        || ', las mismas fechas se reservaron en la ' || v_res);
--
    ROLLBACK;
END;
/

-- Resultado esperado: 1) y 9) crean reserva; 2) ORA-20006, 3) y 4)
-- ORA-20001, 5) ORA-20005, 6) ORA-20007, 7) ORA-20003, 8) ORA-20004.
-- Resultado obtenido:


-- =====================================================================
-- PRUEBA 3: disparador TRG_RH_SIN_SOLAPE (inserts y updates directos,
-- sin pasar por el procedimiento, para probar que el disparador solo
-- protege la tabla).
--   a) insert que se cruza con una reserva activa      -> ORA-20010
--   b) entrar el mismo dia que sale la otra            -> permitido
--   c) UPDATE que mueve esa linea encima de la otra     -> ORA-20010
--   d) INSERT de 2 filas que se cruzan entre si         -> ORA-20010
--   e) linea con salida = entrada                       -> ORA-20011
--   f) linea por fuera del rango de su reserva          -> ORA-20011
--   g) caso real: cruce con una reserva de la carga     -> ORA-20010
-- =====================================================================
DECLARE
    v_hab   habitacion.id_habitacion%TYPE;
    v_hab2  habitacion.id_habitacion%TYPE;
    v_aloj  habitacion.id_alojamiento%TYPE;
    v_aloj2 habitacion.id_alojamiento%TYPE;
    v_res   reserva.id_reserva%TYPE;
    v_res2  reserva.id_reserva%TYPE;
    v_id    reserva_habitacion.id_reserva_habitacion%TYPE;
    v_r_hab reserva_habitacion.id_habitacion%TYPE;
    v_r_in  DATE;
    v_r_out DATE;
    v_r_id  reserva.id_reserva%TYPE;
BEGIN
    -- habitacion de capacidad >= 2 en un alojamiento con al menos 2
    -- habitaciones (el caso d usa una segunda habitacion del mismo)
    SELECT MIN(h.id_habitacion) INTO v_hab
      FROM habitacion h
     WHERE h.capacidad_maxima >= 2
       AND (SELECT COUNT(*) FROM habitacion h2
             WHERE h2.id_alojamiento = h.id_alojamiento) >= 2;
    SELECT id_alojamiento INTO v_aloj FROM habitacion WHERE id_habitacion = v_hab;
--
    -- reserva base: del 5 al 8 de enero de 2027
    pkg_reservas.sp_crear_reserva(1, v_hab, DATE '2027-01-05', DATE '2027-01-08', 2, v_res);
--
    -- segunda reserva (cabecera) del 7 al 10, insertada a mano
    SELECT MAX(id_reserva) + 1 INTO v_res2 FROM reserva;
    INSERT INTO reserva (id_reserva, fecha_checkin, fecha_checkout, estado, id_cliente, id_alojamiento)
    VALUES (v_res2, DATE '2027-01-07', DATE '2027-01-10', 'Confirmada', 2, v_aloj);
    SELECT MAX(id_reserva_habitacion) + 1 INTO v_id FROM reserva_habitacion;
--
    -- a) del 6 al 7 en la misma habitacion, dentro de la reserva base
    BEGIN
        INSERT INTO reserva_habitacion (id_reserva_habitacion, fecha_checkin, fecha_checkout,
                                        cantidad_huespedes, id_reserva, id_habitacion)
        VALUES (v_id, DATE '2027-01-06', DATE '2027-01-07', 1, v_res, v_hab);
        DBMS_OUTPUT.PUT_LINE('a) ERROR: el insert con cruce paso');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('a) Insert con cruce          -> ' || SQLERRM);
    END;
--
    -- b) del 8 al 10: entra el dia en que sale la reserva base
    INSERT INTO reserva_habitacion (id_reserva_habitacion, fecha_checkin, fecha_checkout,
                                    cantidad_huespedes, id_reserva, id_habitacion)
    VALUES (v_id, DATE '2027-01-08', DATE '2027-01-10', 1, v_res2, v_hab);
    DBMS_OUTPUT.PUT_LINE('b) Entrada el dia de salida  -> permitido (linea ' || v_id || ')');
--
    -- c) UPDATE: adelantar la linea b) al dia 7 la cruza con la base
    BEGIN
        UPDATE reserva_habitacion SET fecha_checkin = DATE '2027-01-07'
         WHERE id_reserva_habitacion = v_id;
        DBMS_OUTPUT.PUT_LINE('c) ERROR: el update con cruce paso');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('c) Update con cruce          -> ' || SQLERRM);
    END;
--
    -- d) un solo INSERT ... SELECT con 2 filas que se cruzan entre si
    --    (otra habitacion libre; con un disparador de fila simple esto
    --    daria ORA-04091 tabla mutante)
    SELECT MIN(id_habitacion) INTO v_hab2 FROM habitacion WHERE id_alojamiento = v_aloj AND id_habitacion <> v_hab;
    BEGIN
        INSERT INTO reserva_habitacion (id_reserva_habitacion, fecha_checkin, fecha_checkout,
                                        cantidad_huespedes, id_reserva, id_habitacion)
        SELECT v_id + 1, DATE '2027-01-07', DATE '2027-01-09', 1, v_res2, v_hab2 FROM dual
        UNION ALL
        SELECT v_id + 2, DATE '2027-01-08', DATE '2027-01-10', 1, v_res2, v_hab2 FROM dual;
        DBMS_OUTPUT.PUT_LINE('d) ERROR: el insert de 2 filas paso');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('d) 2 filas cruzadas          -> ' || SQLERRM);
    END;
--
    -- e) salida igual a la entrada
    BEGIN
        INSERT INTO reserva_habitacion (id_reserva_habitacion, fecha_checkin, fecha_checkout,
                                        cantidad_huespedes, id_reserva, id_habitacion)
        VALUES (v_id + 3, DATE '2027-01-09', DATE '2027-01-09', 1, v_res2, v_hab2);
        DBMS_OUTPUT.PUT_LINE('e) ERROR: la linea sin noches paso');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('e) Salida igual a entrada    -> ' || SQLERRM);
    END;
--
    -- f) linea por fuera del rango de su reserva (reserva 7-10, linea 9-12)
    BEGIN
        INSERT INTO reserva_habitacion (id_reserva_habitacion, fecha_checkin, fecha_checkout,
                                        cantidad_huespedes, id_reserva, id_habitacion)
        VALUES (v_id + 3, DATE '2027-01-09', DATE '2027-01-12', 1, v_res2, v_hab2);
        DBMS_OUTPUT.PUT_LINE('f) ERROR: la linea fuera de rango paso');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('f) Fuera del rango           -> ' || SQLERRM);
    END;
--
    -- g) caso real: se toma una linea de una reserva Confirmada o
    --    Completada de la carga y se intenta ocupar la misma habitacion
    --    en las mismas fechas con una reserva nueva.
    SELECT id_reserva, id_habitacion, fecha_checkin, fecha_checkout
      INTO v_r_id, v_r_hab, v_r_in, v_r_out
      FROM (SELECT rh.id_reserva, rh.id_habitacion, rh.fecha_checkin, rh.fecha_checkout
              FROM reserva_habitacion rh
              JOIN reserva r ON r.id_reserva = rh.id_reserva
             WHERE UPPER(r.estado) IN ('CONFIRMADA', 'COMPLETADA')
             ORDER BY rh.id_reserva_habitacion)
     WHERE ROWNUM = 1;
    SELECT id_alojamiento INTO v_aloj2 FROM habitacion WHERE id_habitacion = v_r_hab;
    DBMS_OUTPUT.PUT_LINE('g) Reserva real ' || v_r_id || ': habitacion ' || v_r_hab
        || ' del ' || TO_CHAR(v_r_in, 'YYYY-MM-DD') || ' al ' || TO_CHAR(v_r_out, 'YYYY-MM-DD'));
    INSERT INTO reserva (id_reserva, fecha_checkin, fecha_checkout, estado, id_cliente, id_alojamiento)
    VALUES (v_res2 + 1, v_r_in, v_r_out, 'Confirmada', 2, v_aloj2);
    BEGIN
        INSERT INTO reserva_habitacion (id_reserva_habitacion, fecha_checkin, fecha_checkout,
                                        cantidad_huespedes, id_reserva, id_habitacion)
        VALUES (v_id + 4, v_r_in, v_r_out, 1, v_res2 + 1, v_r_hab);
        DBMS_OUTPUT.PUT_LINE('g) ERROR: el cruce con la reserva real paso');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('g) Cruce con reserva real    -> ' || SQLERRM);
    END;
--
    ROLLBACK;
END;
/

-- Resultado esperado: a), c), d), g) ORA-20010; b) permitido;
-- e) y f) ORA-20011.
-- Resultado obtenido:


-- =====================================================================
-- PRUEBA 4: disparador TRG_TARIFA_AUDITORIA (escritura por sentencia)
-- Un solo UPDATE sube 1000 a las 22 tarifas de la habitacion 1. Debe
-- quedar un renglon de auditoria por tarifa, todos con la misma fecha,
-- con usuario, precio anterior y precio nuevo. Un UPDATE que deja el
-- precio igual no debe auditar nada.
-- =====================================================================
DECLARE
    v_antes   NUMBER;
    v_despues NUMBER;
    v_max     NUMBER;
BEGIN
    SELECT COUNT(*), NVL(MAX(id_auditoria), 0) INTO v_antes, v_max FROM auditoria_tarifa;
--
    UPDATE tarifa SET precio_noche = precio_noche WHERE id_habitacion = 1;
    SELECT COUNT(*) INTO v_despues FROM auditoria_tarifa;
    DBMS_OUTPUT.PUT_LINE('UPDATE sin cambio de precio -> renglones nuevos: ' || (v_despues - v_antes));
--
    UPDATE tarifa SET precio_noche = precio_noche + 1000 WHERE id_habitacion = 1;
    DBMS_OUTPUT.PUT_LINE('UPDATE con +1000 -> filas modificadas: ' || SQL%ROWCOUNT);
    SELECT COUNT(*) INTO v_despues FROM auditoria_tarifa;
    DBMS_OUTPUT.PUT_LINE('Renglones nuevos en auditoria_tarifa: ' || (v_despues - v_antes));
--
    DBMS_OUTPUT.PUT_LINE('id | quien | cuando | tarifa | anterior -> nuevo');
    FOR a IN (SELECT id_auditoria, usuario_bd,
                     TO_CHAR(fecha_cambio, 'YYYY-MM-DD HH24:MI:SS') AS cuando,
                     precio_anterior, precio_nuevo, id_tarifa
                FROM auditoria_tarifa
               WHERE id_auditoria > v_max
               ORDER BY id_auditoria) LOOP
        DBMS_OUTPUT.PUT_LINE(a.id_auditoria || ' | ' || a.usuario_bd || ' | ' || a.cuando
            || ' | ' || a.id_tarifa || ' | ' || a.precio_anterior || ' -> ' || a.precio_nuevo);
    END LOOP;
--
    ROLLBACK;
END;
/

-- Resultado esperado: 0 renglones con el UPDATE sin cambio; con el
-- de +1000, 22 filas modificadas (una tarifa por temporada) y 22
-- renglones, misma fecha y precio_nuevo = precio_anterior + 1000.
-- Resultado obtenido:


-- =====================================================================
-- PRUEBA 5: liquidacion mensual (cursor explicito con parametros)
-- Alojamiento 1, junio de 2026 (temporada alta). Cuenta reservas
-- Confirmada y Completada con check-in en junio.
-- =====================================================================
BEGIN
    pkg_reservas.sp_liquidacion_mensual(1, 2026, 6);
END;
/

-- 5.b Verificacion independiente (sin cursor y SIN la funcion): cada
-- noche se valora a mano con su temporada. "reservas" y "habitaciones"
-- deben coincidir con la liquidacion.
SELECT COUNT(DISTINCT r.id_reserva) AS reservas,
       SUM(t.precio_noche)          AS habitaciones
  FROM reserva r
  JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
  JOIN (SELECT LEVEL - 1 AS k FROM dual CONNECT BY LEVEL <= 366) d
    ON d.k < rh.fecha_checkout - rh.fecha_checkin
  JOIN temporada te ON rh.fecha_checkin + d.k BETWEEN te.fecha_inicio AND te.fecha_fin
  JOIN tarifa t     ON t.id_temporada = te.id_temporada AND t.id_habitacion = rh.id_habitacion
 WHERE r.id_alojamiento = 1
   AND UPPER(r.estado) IN ('CONFIRMADA', 'COMPLETADA')
   AND r.fecha_checkin >= DATE '2026-06-01' AND r.fecha_checkin < DATE '2026-07-01';

-- 5.c Servicios de esas mismas reservas: debe coincidir con "Servicios"
SELECT NVL(SUM(rs.cantidad * s.precio), 0) AS servicios
  FROM reserva r
  JOIN reserva_servicio rs ON rs.id_reserva = r.id_reserva
  JOIN servicio s          ON s.id_servicio = rs.id_servicio
 WHERE r.id_alojamiento = 1
   AND UPPER(r.estado) IN ('CONFIRMADA', 'COMPLETADA')
   AND r.fecha_checkin >= DATE '2026-06-01' AND r.fecha_checkin < DATE '2026-07-01';

-- 5.d Proceso masivo: todos los alojamientos de junio de 2026. La
-- linea del alojamiento 1 debe dar el mismo total que 5.a.
BEGIN
    pkg_reservas.sp_liquidacion_masiva(2026, 6);
END;
/

-- 5.e Casos de error
BEGIN
    pkg_reservas.sp_liquidacion_mensual(1, 2026, 13);
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Mes 13          -> ' || SQLERRM);
END;
/

BEGIN
    pkg_reservas.sp_liquidacion_mensual(999, 2026, 6);
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Alojamiento 999 -> ' || SQLERRM);
END;
/

-- Resultado esperado: 5.b + 5.c = TOTAL A LIQUIDAR de 5.a; la linea
-- del alojamiento 1 en 5.d igual; ORA-20008 y ORA-20009.
-- Resultado obtenido:


-- =====================================================================
-- PRUEBA 6: tablespace del historico
-- =====================================================================
SELECT tablespace_name, status, contents, extent_management, segment_space_management
  FROM user_tablespaces
 WHERE tablespace_name = 'TS_HISTORIAL_RESERVAS';

SELECT segment_name, segment_type, tablespace_name, bytes / 1024 AS kb
  FROM user_segments
 WHERE tablespace_name = 'TS_HISTORIAL_RESERVAS'
 ORDER BY segment_type, segment_name;

SELECT table_name, tablespace_name FROM user_tables  WHERE table_name = 'RESERVA_HISTORICO';

SELECT index_name, tablespace_name FROM user_indexes WHERE table_name = 'RESERVA_HISTORICO';

-- Archivadas frente a las que cumplen el criterio en RESERVA (deben ser iguales)
SELECT (SELECT COUNT(*) FROM reserva_historico) AS archivadas,
       (SELECT COUNT(*) FROM reserva
         WHERE UPPER(estado) IN ('COMPLETADA', 'CANCELADA')
           AND fecha_checkout < DATE '2026-07-01') AS en_reserva,
       (SELECT COUNT(*) FROM reserva_historico WHERE valor_habitaciones IS NULL) AS sin_valor,
       (SELECT MIN(fecha_checkin)  FROM reserva_historico) AS desde,
       (SELECT MAX(fecha_checkout) FROM reserva_historico) AS hasta
  FROM dual;

-- Resultado esperado: el tablespace ONLINE, LOCAL, AUTO; la tabla y sus
-- 2 indices en TS_HISTORIAL_RESERVAS; archivadas = en_reserva.
-- Resultado obtenido:


-- =====================================================================
-- PRUEBA 7: vista materializada MV_OCUPACION_MENSUAL
-- =====================================================================

-- 7.a Datos de un alojamiento
SELECT id_alojamiento, nombre_comercial, municipio, TO_CHAR(mes, 'YYYY-MM') AS mes,
       noches_ocupadas, noches_disponibles, pct_ocupacion
  FROM mv_ocupacion_mensual
 WHERE id_alojamiento = 1
 ORDER BY mes;

-- 7.b Ninguna fila supera el 100 % y no hay porcentajes negativos
SELECT COUNT(*) AS filas, MIN(pct_ocupacion) AS min_pct, MAX(pct_ocupacion) AS max_pct
  FROM mv_ocupacion_mensual;

-- 7.c Comprobacion a mano de un mes (alojamiento 1, junio de 2026):
-- habitacion-noches distintas de reservas Confirmada/Completada.
-- Debe dar lo mismo que la vista para ese mes.
SELECT COUNT(*) AS noches_a_mano
  FROM (SELECT DISTINCT rh.id_habitacion, rh.fecha_checkin + d.k AS noche
          FROM reserva_habitacion rh
          JOIN reserva r    ON r.id_reserva    = rh.id_reserva
          JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
          JOIN (SELECT LEVEL - 1 AS k FROM dual CONNECT BY LEVEL <= 366) d
            ON d.k < rh.fecha_checkout - rh.fecha_checkin
         WHERE h.id_alojamiento = 1
           AND UPPER(r.estado) IN ('CONFIRMADA', 'COMPLETADA'))
 WHERE noche >= DATE '2026-06-01' AND noche < DATE '2026-07-01';

SELECT noches_ocupadas AS noches_vista
  FROM mv_ocupacion_mensual
 WHERE id_alojamiento = 1 AND mes = DATE '2026-06-01';

-- 7.d Uso para la gerencia: ocupacion por municipio y mes leida de la
-- vista (no recalcula nada)
SELECT municipio, TO_CHAR(mes, 'YYYY-MM') AS mes,
       SUM(noches_ocupadas) AS ocupadas, SUM(noches_disponibles) AS disponibles,
       ROUND(100 * SUM(noches_ocupadas) / SUM(noches_disponibles), 2) AS pct
  FROM mv_ocupacion_mensual
 GROUP BY municipio, mes
 ORDER BY municipio, mes;

-- Resultado obtenido (7.a a 7.d):


-- 7.e Refresco manual. Paso A: reserva de prueba de 3 noches en enero
-- de 2027, confirmada y con COMMIT (la vista solo ve lo confirmado).
DECLARE
    v_hab habitacion.id_habitacion%TYPE;
    v_res reserva.id_reserva%TYPE;
BEGIN
    SELECT MIN(id_habitacion) INTO v_hab FROM habitacion WHERE id_alojamiento = 1;
    pkg_reservas.sp_crear_reserva(1, v_hab, DATE '2027-01-05', DATE '2027-01-08', 1, v_res);
    UPDATE reserva SET estado = 'Confirmada' WHERE id_reserva = v_res;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Reserva de prueba ' || v_res || ' confirmada');
END;
/

-- Paso B: la vista todavia no la ve (sin filas para enero de 2027)
SELECT TO_CHAR(mes, 'YYYY-MM') AS mes, noches_ocupadas
  FROM mv_ocupacion_mensual WHERE id_alojamiento = 1 AND mes = DATE '2027-01-01';

-- Paso C: refresco manual completo
BEGIN
    DBMS_MVIEW.REFRESH('MV_OCUPACION_MENSUAL', 'C');
END;
/

-- Paso D: ahora si aparecen las 3 noches
SELECT TO_CHAR(mes, 'YYYY-MM') AS mes, noches_ocupadas, noches_disponibles, pct_ocupacion
  FROM mv_ocupacion_mensual WHERE id_alojamiento = 1 AND mes = DATE '2027-01-01';

-- Resultado esperado: B sin filas; D con noches_ocupadas = 3 y
-- pct = 3 / (habitaciones del alojamiento 1 x 31) x 100.
-- Resultado obtenido:


-- Paso E: limpieza de la reserva de prueba y refresco final
BEGIN
    DELETE FROM reserva_habitacion
     WHERE id_reserva IN (SELECT id_reserva FROM reserva
                           WHERE id_cliente = 1 AND id_alojamiento = 1
                             AND fecha_checkin  = DATE '2027-01-05'
                             AND fecha_checkout = DATE '2027-01-08');
    DELETE FROM reserva
     WHERE id_cliente = 1 AND id_alojamiento = 1
       AND fecha_checkin  = DATE '2027-01-05'
       AND fecha_checkout = DATE '2027-01-08';
    DBMS_OUTPUT.PUT_LINE('Reservas de prueba borradas: ' || SQL%ROWCOUNT);
    COMMIT;
    DBMS_MVIEW.REFRESH('MV_OCUPACION_MENSUAL', 'C');
END;
/

-- Estado final: metodo de refresco, ultima ejecucion y proxima
SELECT mview_name, refresh_mode, refresh_method, last_refresh_date, staleness
  FROM user_mviews WHERE mview_name = 'MV_OCUPACION_MENSUAL';

SELECT rname, next_date, interval
  FROM user_refresh WHERE rname = 'MV_OCUPACION_MENSUAL';

-- Resultado obtenido:
