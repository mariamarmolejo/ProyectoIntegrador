-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- Entrega 3 - Transacciones
-- 08_transacciones_turismouq.sql
-- Equipo: Daniela Munoz, Maria Jose Marmolejo, Santiago Ovalle
--
-- Se corre con el mismo usuario dueno de las tablas (TURISMO_E2),
-- despues de los scripts 01 a 07. F5 (Run Script) en SQL Developer.
--
-- Contenido:
--   1. Paquete PKG_TRANSACCIONES con sp_reservar_con_pago: registra la
--      reserva y su pago como una sola transaccion, con dos SAVEPOINT.
--      Trae tambien fn_cotizar, para que recepcion consulte el valor
--      de una estadia (recepcion solo recibe permiso sobre este
--      paquete, ver script 12).
--   2. Pruebas del procedimiento (pago bien, pago que falla, habitacion
--      ocupada).
--   3. Rollback parcial paso a paso, sin procedimiento (para el video).
--   4. Limpieza de los datos de prueba.
--
-- Codigos de error nuevos:
--   -20013  monto del pago invalido (cero, negativo o mayor que la estadia)
--   -20014  el pago no alcanza el anticipo minimo (40 % de la estadia)
--
-- Las pruebas usan enero de 2027, donde la carga no tiene reservas.
-- =====================================================================

SET SERVEROUTPUT ON


-- ---------------------------------------------------------------------
-- 1. Paquete PKG_TRANSACCIONES
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_transacciones AS
--
    -- Valor de una estadia, para que recepcion le diga al cliente cuanto
    -- cuesta antes de reservar (usa fn_valor_estadia de la Entrega 2).
    FUNCTION fn_cotizar (
        p_id_habitacion IN habitacion.id_habitacion%TYPE,
        p_checkin       IN DATE,
        p_checkout      IN DATE
    ) RETURN NUMBER;
--
    PROCEDURE sp_reservar_con_pago (
        p_id_cliente    IN  cliente.id_cliente%TYPE,
        p_id_habitacion IN  habitacion.id_habitacion%TYPE,
        p_checkin       IN  DATE,
        p_checkout      IN  DATE,
        p_huespedes     IN  NUMBER,
        p_monto         IN  pago.monto%TYPE,
        p_metodo        IN  pago.metodo%TYPE,
        p_id_reserva    OUT reserva.id_reserva%TYPE,
        p_resultado     OUT VARCHAR2
    );
--
END pkg_transacciones;
/


CREATE OR REPLACE PACKAGE BODY pkg_transacciones AS
--
    FUNCTION fn_cotizar (
        p_id_habitacion IN habitacion.id_habitacion%TYPE,
        p_checkin       IN DATE,
        p_checkout      IN DATE
    ) RETURN NUMBER IS
    BEGIN
        RETURN pkg_reservas.fn_valor_estadia(p_id_habitacion, p_checkin, p_checkout);
    END fn_cotizar;
--
    ------------------------------------------------------------------
    -- sp_reservar_con_pago
    -- Flujo de recepcion: el cliente reserva y paga en el mismo momento.
    --
    --   SAVEPOINT sp_inicio
    --   1) Bloquea la fila de la habitacion con SELECT ... FOR UPDATE.
    --      Si otra sesion esta reservando la misma habitacion, esta
    --      espera hasta que la otra termine (ver script 09).
    --   2) Crea la reserva y su linea con pkg_reservas.sp_crear_reserva,
    --      que valida fechas, cliente, capacidad, disponibilidad y
    --      tarifas. La reserva queda Pendiente.
    --   SAVEPOINT sp_reserva_creada
    --   3) Registra el pago y, si cubre el anticipo del 40 %, pasa la
    --      reserva a Confirmada.
    --   COMMIT
    --
    -- Si falla el pago (monto invalido, metodo que no existe, anticipo
    -- insuficiente) se hace ROLLBACK TO sp_reserva_creada: se deshace
    -- solo el pago y el cambio de estado, y la reserva se guarda
    -- Pendiente para que el cliente pague despues. Ese es el rollback
    -- parcial.
    -- Si falla la reserva (habitacion ocupada, fechas malas...) se hace
    -- ROLLBACK TO sp_inicio: no queda nada y el error sigue hacia
    -- arriba.
    -- Este procedimiento SI hace COMMIT, porque es la transaccion
    -- completa de recepcion.
    ------------------------------------------------------------------
    PROCEDURE sp_reservar_con_pago (
        p_id_cliente    IN  cliente.id_cliente%TYPE,
        p_id_habitacion IN  habitacion.id_habitacion%TYPE,
        p_checkin       IN  DATE,
        p_checkout      IN  DATE,
        p_huespedes     IN  NUMBER,
        p_monto         IN  pago.monto%TYPE,
        p_metodo        IN  pago.metodo%TYPE,
        p_id_reserva    OUT reserva.id_reserva%TYPE,
        p_resultado     OUT VARCHAR2
    ) IS
        v_bloqueo   habitacion.id_habitacion%TYPE;
        v_valor     NUMBER;
        v_anticipo  NUMBER;
        v_id_pago   pago.id_pago%TYPE;
    BEGIN
        SAVEPOINT sp_inicio;
--
        -- 1) bloqueo de la habitacion
        BEGIN
            SELECT id_habitacion INTO v_bloqueo
              FROM habitacion
             WHERE id_habitacion = p_id_habitacion
               FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003,
                    'La habitacion ' || p_id_habitacion || ' no existe');
        END;
--
        -- 2) reserva + linea (todas las validaciones de la Entrega 2)
        pkg_reservas.sp_crear_reserva(p_id_cliente, p_id_habitacion,
                                      p_checkin, p_checkout,
                                      p_huespedes, p_id_reserva);
        v_valor    := pkg_reservas.fn_valor_estadia(p_id_habitacion, p_checkin, p_checkout);
        v_anticipo := ROUND(v_valor * 0.4);
--
        SAVEPOINT sp_reserva_creada;
--
        -- 3) pago
        BEGIN
            IF p_monto IS NULL OR p_monto <= 0 OR p_monto > v_valor THEN
                RAISE_APPLICATION_ERROR(-20013,
                    'Monto de pago invalido: ' || p_monto
                    || ' (la estadia vale ' || v_valor || ')');
            END IF;
--
            SELECT NVL(MAX(id_pago), 0) + 1 INTO v_id_pago FROM pago;
            INSERT INTO pago (id_pago, fecha_pago, monto, metodo, estado, id_reserva)
            VALUES (v_id_pago, SYSDATE, p_monto, p_metodo, 'Exitoso', p_id_reserva);
--
            -- se revisa despues del INSERT a proposito: si falla, el
            -- rollback parcial tiene que deshacer una fila que ya existe
            IF p_monto < v_anticipo THEN
                RAISE_APPLICATION_ERROR(-20014,
                    'El pago de ' || p_monto || ' no alcanza el anticipo minimo de '
                    || v_anticipo || ' (40 % de ' || v_valor || ')');
            END IF;
--
            UPDATE reserva
               SET estado = 'Confirmada'
             WHERE id_reserva = p_id_reserva;
--
            p_resultado := 'CONFIRMADA';
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK TO sp_reserva_creada;
                p_resultado := 'PENDIENTE - pago rechazado: ' || SUBSTR(SQLERRM, 1, 150);
        END;
--
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Reserva ' || p_id_reserva || ' -> ' || p_resultado);
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_inicio;
            RAISE;
    END sp_reservar_con_pago;
--
END pkg_transacciones;
/

-- Si algo no compila, este SELECT muestra el error con su linea:
SELECT name, type, line, text FROM user_errors
 WHERE name = 'PKG_TRANSACCIONES' ORDER BY type, sequence;

SELECT object_name, object_type, status FROM user_objects
 WHERE object_name = 'PKG_TRANSACCIONES';
-- Resultado: PACKAGE y PACKAGE BODY, los dos VALID


-- ---------------------------------------------------------------------
-- 2. Pruebas del procedimiento
-- ---------------------------------------------------------------------

-- Conteos antes de las pruebas
SELECT (SELECT COUNT(*) FROM reserva) AS reservas,
       (SELECT COUNT(*) FROM pago)    AS pagos
  FROM dual;
-- Resultado: 25500 | 36329

-- Prueba 1: todo bien. Habitacion 1, del 5 al 8 de enero de 2027,
-- paga la estadia completa.
DECLARE
    v_id   reserva.id_reserva%TYPE;
    v_res  VARCHAR2(300);
    v_val  NUMBER;
BEGIN
    v_val := pkg_reservas.fn_valor_estadia(1, DATE '2027-01-05', DATE '2027-01-08');
    pkg_transacciones.sp_reservar_con_pago(10, 1, DATE '2027-01-05', DATE '2027-01-08',
                                           1, v_val, 'PSE', v_id, v_res);
END;
/
-- Resultado: Reserva N -> CONFIRMADA

-- Prueba 2: el pago es el 10 % de la estadia, menos que el anticipo
-- minimo del 40 %.
-- La reserva se guarda Pendiente y el pago se deshace.
DECLARE
    v_id   reserva.id_reserva%TYPE;
    v_res  VARCHAR2(300);
    v_val  NUMBER;
BEGIN
    v_val := pkg_reservas.fn_valor_estadia(2, DATE '2027-01-05', DATE '2027-01-08');
    pkg_transacciones.sp_reservar_con_pago(20, 2, DATE '2027-01-05', DATE '2027-01-08',
                                           1, ROUND(v_val * 0.1), 'Efectivo', v_id, v_res);
END;
/
-- Resultado: Reserva N -> PENDIENTE - pago rechazado: ORA-20014 ...

-- Prueba 3: metodo de pago que no existe. El INSERT del pago choca con
-- el CHECK pago_ck_metodo (ORA-02290) y tambien se deshace solo el pago.
DECLARE
    v_id   reserva.id_reserva%TYPE;
    v_res  VARCHAR2(300);
    v_val  NUMBER;
BEGIN
    v_val := pkg_reservas.fn_valor_estadia(3, DATE '2027-01-05', DATE '2027-01-08');
    pkg_transacciones.sp_reservar_con_pago(30, 3, DATE '2027-01-05', DATE '2027-01-08',
                                           1, v_val, 'Bitcoin', v_id, v_res);
END;
/
-- Resultado: Reserva N -> PENDIENTE - pago rechazado: ORA-02290 ...

-- Prueba 4: habitacion ocupada (la misma de la prueba 1, fechas que se
-- cruzan). Falla la reserva, asi que no se guarda nada.
DECLARE
    v_id   reserva.id_reserva%TYPE;
    v_res  VARCHAR2(300);
BEGIN
    pkg_transacciones.sp_reservar_con_pago(40, 1, DATE '2027-01-06', DATE '2027-01-09',
                                           1, 100000, 'PSE', v_id, v_res);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Prueba 4 -> ' || SQLERRM);
END;
/
-- Resultado: Prueba 4 -> ORA-20006: La habitacion 1 no esta disponible ...

-- Como quedaron las reservas de prueba
SELECT r.id_reserva, r.id_cliente, rh.id_habitacion, r.estado,
       (SELECT COUNT(*) FROM pago p WHERE p.id_reserva = r.id_reserva) AS pagos
  FROM reserva r
  JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
 WHERE r.fecha_checkin >= DATE '2027-01-01'
 ORDER BY r.id_reserva;
-- Resultado (3 filas):
--   cliente 10, habitacion 1, Confirmada, 1 pago
--   cliente 20, habitacion 2, Pendiente,  0 pagos
--   cliente 30, habitacion 3, Pendiente,  0 pagos
-- El cliente 40 no aparece: su reserva se deshizo completa.

SELECT (SELECT COUNT(*) FROM reserva) AS reservas,
       (SELECT COUNT(*) FROM pago)    AS pagos
  FROM dual;
-- Resultado: 25503 | 36330 (3 reservas mas y 1 pago mas)


-- ---------------------------------------------------------------------
-- 3. Rollback parcial paso a paso (cada sentencia con Ctrl+Enter)
-- Mismo flujo del procedimiento, pero a mano para ver cada momento.
-- ---------------------------------------------------------------------

-- Paso 1: se crea la reserva (habitacion 4, queda Pendiente)
DECLARE
    v_id reserva.id_reserva%TYPE;
BEGIN
    pkg_reservas.sp_crear_reserva(50, 4, DATE '2027-01-05', DATE '2027-01-08', 1, v_id);
END;
/

-- Paso 2
SAVEPOINT reserva_lista;

-- Paso 3: se registra el pago y se confirma la reserva
INSERT INTO pago (id_pago, fecha_pago, monto, metodo, estado, id_reserva)
VALUES ((SELECT MAX(id_pago) + 1 FROM pago), SYSDATE, 200000, 'Tarjeta credito',
        'Exitoso', (SELECT MAX(id_reserva) FROM reserva));

UPDATE reserva SET estado = 'Confirmada'
 WHERE id_reserva = (SELECT MAX(id_reserva) FROM reserva);

-- Paso 4: asi se ve dentro de la transaccion
SELECT r.id_reserva, r.estado,
       (SELECT COUNT(*) FROM pago p WHERE p.id_reserva = r.id_reserva) AS pagos
  FROM reserva r
 WHERE r.id_reserva = (SELECT MAX(id_reserva) FROM reserva);
-- Resultado: N | Confirmada | 1

-- Paso 5: se devuelve solo hasta el savepoint
ROLLBACK TO reserva_lista;

SELECT r.id_reserva, r.estado,
       (SELECT COUNT(*) FROM pago p WHERE p.id_reserva = r.id_reserva) AS pagos
  FROM reserva r
 WHERE r.id_reserva = (SELECT MAX(id_reserva) FROM reserva);
-- Resultado: N | Pendiente | 0
-- La reserva sigue ahi, el pago y la confirmacion se deshicieron.

-- Paso 6: ROLLBACK completo, tambien se va la reserva
ROLLBACK;

SELECT COUNT(*) AS reservas_enero_2027
  FROM reserva
 WHERE fecha_checkin >= DATE '2027-01-01';
-- Resultado: 3 (las de las pruebas 1 a 3, que si se confirmaron)


-- ---------------------------------------------------------------------
-- 4. Limpieza: se borran las reservas de prueba de enero de 2027
-- ---------------------------------------------------------------------
DELETE FROM pago
 WHERE id_reserva IN (SELECT id_reserva FROM reserva WHERE fecha_checkin >= DATE '2027-01-01');
DELETE FROM reserva_habitacion
 WHERE id_reserva IN (SELECT id_reserva FROM reserva WHERE fecha_checkin >= DATE '2027-01-01');
DELETE FROM reserva
 WHERE fecha_checkin >= DATE '2027-01-01';
COMMIT;

SELECT (SELECT COUNT(*) FROM reserva) AS reservas,
       (SELECT COUNT(*) FROM pago)    AS pagos
  FROM dual;
-- Resultado: 25500 | 36329, igual que al principio
