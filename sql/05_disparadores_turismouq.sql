-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- Entrega 2 - Capa PL/SQL
-- 05_disparadores_turismouq.sql
-- Equipo: Daniela Munoz, Maria Jose Marmolejo, Santiago Ovalle
--
-- Contenido:
--   1. TRG_TARIFA_AUDITORIA  auditoria de precios. Escribe UNA vez por
--                            sentencia (seccion AFTER STATEMENT).
--   2. TRG_RH_SIN_SOLAPE     impide que una habitacion se reserve dos
--                            veces en fechas que se cruzan. Valida CADA
--                            FILA (seccion BEFORE EACH ROW) y compara
--                            contra la tabla al cerrar la sentencia.
--
-- Por que son disparadores COMPUESTOS:
--   - Un disparador de sentencia "puro" (sin FOR EACH ROW) no tiene
--     :OLD ni :NEW, asi que no puede saber el precio anterior y el
--     nuevo, que es justo lo que pide la auditoria. El compuesto anota
--     cada fila en una coleccion y escribe la auditoria en la seccion
--     de sentencia, una sola vez.
--   - Un disparador de fila sobre RESERVA_HABITACION que consulta la
--     misma RESERVA_HABITACION da ORA-04091 (tabla mutante) en un
--     UPDATE o en un INSERT ... SELECT. El compuesto valida cada fila
--     en BEFORE EACH ROW y deja la consulta contra la tabla para
--     AFTER STATEMENT, cuando la tabla ya no esta mutando.
--
-- Codigos de error: -20010 (solape) y -20011 (fechas de la linea).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Auditoria de TARIFA (escritura a nivel de sentencia)
-- Registra un renglon en AUDITORIA_TARIFA por cada tarifa insertada o
-- cuyo precio cambie: quien (usuario de la sesion), cuando (SYSDATE),
-- precio anterior y precio nuevo. Si un UPDATE toca 9 tarifas se hace
-- una sola escritura al final de la sentencia, con 9 renglones, todos
-- con la misma fecha. Un UPDATE que deja el precio igual no audita.
-- Los DELETE no se auditan: AUDITORIA_TARIFA.id_tarifa es NOT NULL y
-- llave foranea, asi que no puede apuntar a una tarifa que ya no existe.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_tarifa_auditoria
FOR INSERT OR UPDATE OF precio_noche ON tarifa
COMPOUND TRIGGER
--
    TYPE t_cambio  IS RECORD (
        id_tarifa tarifa.id_tarifa%TYPE,
        anterior  tarifa.precio_noche%TYPE,
        nuevo     tarifa.precio_noche%TYPE
    );
    TYPE t_cambios IS TABLE OF t_cambio INDEX BY PLS_INTEGER;
    g_cambios t_cambios;
--
    -- Por cada fila afectada solo se anota el cambio
    AFTER EACH ROW IS
        v_n PLS_INTEGER;
    BEGIN
        IF INSERTING OR :OLD.precio_noche <> :NEW.precio_noche THEN
            v_n := g_cambios.COUNT + 1;
            g_cambios(v_n).id_tarifa := :NEW.id_tarifa;
            g_cambios(v_n).anterior  := :OLD.precio_noche;  -- NULL si es insert
            g_cambios(v_n).nuevo     := :NEW.precio_noche;
        END IF;
    END AFTER EACH ROW;
--
    -- Al terminar la sentencia se escribe todo de una vez
    AFTER STATEMENT IS
        v_base  NUMBER;
        v_ahora DATE := SYSDATE;
    BEGIN
        IF g_cambios.COUNT > 0 THEN
            SELECT NVL(MAX(id_auditoria), 0) INTO v_base FROM auditoria_tarifa;
            FOR i IN 1 .. g_cambios.COUNT LOOP
                INSERT INTO auditoria_tarifa (id_auditoria, usuario_bd,
                       fecha_cambio, precio_anterior, precio_nuevo, id_tarifa)
                VALUES (v_base + i,
                        SYS_CONTEXT('USERENV', 'SESSION_USER'),
                        v_ahora,
                        g_cambios(i).anterior,
                        g_cambios(i).nuevo,
                        g_cambios(i).id_tarifa);
            END LOOP;
        END IF;
    END AFTER STATEMENT;
--
END trg_tarifa_auditoria;
/


-- ---------------------------------------------------------------------
-- 2. Sin solapes en RESERVA_HABITACION
-- Regla de disponibilidad: una habitacion no puede tener dos reservas
-- activas cuyas fechas se crucen. Hay cruce cuando
--     entrada_nueva < salida_otra  Y  salida_nueva > entrada_otra
-- (el dia de salida de una reserva si puede ser el de entrada de la
-- siguiente). Las reservas Cancelada no bloquean la habitacion.
--
-- BEFORE EACH ROW (se ejecuta por cada fila insertada o modificada):
--   * la salida de la linea debe ser posterior a su entrada;
--   * la linea debe quedar dentro del rango general de su reserva
--     (seccion 1.3: alguien del grupo puede llegar un dia despues,
--     pero no por fuera de las fechas de la reserva).
--   Estas dos reglas solo leen :NEW y la tabla RESERVA, que no es la
--   tabla del disparador, asi que no hay tabla mutante.
--   Ademas guarda la fila en la coleccion.
--
-- AFTER STATEMENT: compara cada fila guardada contra todas las demas
-- filas de la tabla. Asi tambien se detectan cruces entre filas de un
-- mismo INSERT de varias filas. Si hay cruce, el error deshace toda la
-- sentencia.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_rh_sin_solape
FOR INSERT OR UPDATE OF id_habitacion, fecha_checkin, fecha_checkout, id_reserva
ON reserva_habitacion
COMPOUND TRIGGER
--
    TYPE t_fila  IS RECORD (
        id_rh         reserva_habitacion.id_reserva_habitacion%TYPE,
        id_habitacion reserva_habitacion.id_habitacion%TYPE,
        checkin       reserva_habitacion.fecha_checkin%TYPE,
        checkout      reserva_habitacion.fecha_checkout%TYPE,
        id_reserva    reserva_habitacion.id_reserva%TYPE
    );
    TYPE t_filas IS TABLE OF t_fila INDEX BY PLS_INTEGER;
    g_filas t_filas;
--
    BEFORE EACH ROW IS
        v_n       PLS_INTEGER;
        v_r_ini   reserva.fecha_checkin%TYPE;
        v_r_fin   reserva.fecha_checkout%TYPE;
    BEGIN
        IF :NEW.fecha_checkout <= :NEW.fecha_checkin THEN
            RAISE_APPLICATION_ERROR(-20011,
                'Linea de reserva con salida ' || TO_CHAR(:NEW.fecha_checkout, 'YYYY-MM-DD')
                || ' no posterior a la entrada ' || TO_CHAR(:NEW.fecha_checkin, 'YYYY-MM-DD'));
        END IF;
--
        BEGIN
            SELECT fecha_checkin, fecha_checkout INTO v_r_ini, v_r_fin
              FROM reserva
             WHERE id_reserva = :NEW.id_reserva;
--
            IF :NEW.fecha_checkin < v_r_ini OR :NEW.fecha_checkout > v_r_fin THEN
                RAISE_APPLICATION_ERROR(-20011,
                    'La linea (' || TO_CHAR(:NEW.fecha_checkin, 'YYYY-MM-DD') || ' a '
                    || TO_CHAR(:NEW.fecha_checkout, 'YYYY-MM-DD')
                    || ') se sale del rango de la reserva ' || :NEW.id_reserva || ' ('
                    || TO_CHAR(v_r_ini, 'YYYY-MM-DD') || ' a '
                    || TO_CHAR(v_r_fin, 'YYYY-MM-DD') || ')');
            END IF;
        EXCEPTION
            -- si la reserva no existe, la llave foranea rechaza la fila
            WHEN NO_DATA_FOUND THEN NULL;
        END;
--
        v_n := g_filas.COUNT + 1;
        g_filas(v_n).id_rh         := :NEW.id_reserva_habitacion;
        g_filas(v_n).id_habitacion := :NEW.id_habitacion;
        g_filas(v_n).checkin       := :NEW.fecha_checkin;
        g_filas(v_n).checkout      := :NEW.fecha_checkout;
        g_filas(v_n).id_reserva    := :NEW.id_reserva;
    END BEFORE EACH ROW;
--
    AFTER STATEMENT IS
        v_estado  reserva.estado%TYPE;
        v_cruces  NUMBER;
    BEGIN
        FOR i IN 1 .. g_filas.COUNT LOOP
            SELECT estado INTO v_estado
              FROM reserva
             WHERE id_reserva = g_filas(i).id_reserva;
--
            -- una linea de una reserva cancelada no ocupa la habitacion
            IF UPPER(v_estado) <> 'CANCELADA' THEN
                SELECT COUNT(*) INTO v_cruces
                  FROM reserva_habitacion o
                  JOIN reserva ro ON ro.id_reserva = o.id_reserva
                 WHERE o.id_habitacion = g_filas(i).id_habitacion
                   AND o.id_reserva_habitacion <> g_filas(i).id_rh
                   AND UPPER(ro.estado) <> 'CANCELADA'
                   AND o.fecha_checkin  < g_filas(i).checkout
                   AND o.fecha_checkout > g_filas(i).checkin;
--
                IF v_cruces > 0 THEN
                    RAISE_APPLICATION_ERROR(-20010,
                        'La habitacion ' || g_filas(i).id_habitacion
                        || ' ya esta reservada entre '
                        || TO_CHAR(g_filas(i).checkin, 'YYYY-MM-DD') || ' y '
                        || TO_CHAR(g_filas(i).checkout, 'YYYY-MM-DD'));
                END IF;
            END IF;
        END LOOP;
    END AFTER STATEMENT;
--
END trg_rh_sin_solape;
/

-- Si algo no compila, este SELECT muestra el error con su linea:
SELECT name, type, line, text FROM user_errors ORDER BY name, type, sequence;

SELECT trigger_name, trigger_type, triggering_event, status
  FROM user_triggers
 WHERE trigger_name IN ('TRG_TARIFA_AUDITORIA', 'TRG_RH_SIN_SOLAPE');
