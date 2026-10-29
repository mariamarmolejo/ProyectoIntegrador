-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- Entrega 2 - Capa PL/SQL
-- 04_paquete_turismouq.sql
-- Equipo: Daniela Munoz, Maria Jose Marmolejo, Santiago Ovalle
--
-- Contenido: paquete PKG_RESERVAS con
--   * fn_valor_estadia        valor de una estadia noche por noche
--   * sp_crear_reserva        crea una reserva validando todo antes
--   * sp_liquidacion_mensual  liquidacion detallada de UN alojamiento
--                             en un mes (cursor explicito con parametros)
--   * sp_liquidacion_masiva   proceso masivo: liquida TODOS los
--                             alojamientos de un mes con el mismo cursor
--
-- Requiere haber corrido 01_ddl y 02_carga (esquema TURISMO).
-- Para ver los mensajes de DBMS_OUTPUT hay que abrir el panel de salida
-- de DBeaver (Ctrl+Shift+O).
--
-- Codigos de error que lanza el paquete (RAISE_APPLICATION_ERROR):
--   -20001  fechas invalidas (salida no posterior a la entrada)
--   -20002  hay noches sin tarifa para la habitacion
--   -20003  la habitacion no existe
--   -20004  el cliente no existe
--   -20005  se supera la capacidad maxima de la habitacion
--   -20006  la habitacion no esta disponible en esas fechas
--   -20007  cantidad de huespedes invalida
--   -20008  anio o mes invalido en la liquidacion
--   -20009  el alojamiento no existe
--   -20012  una noche cae en dos temporadas (temporadas solapadas)
-- (-20010 y -20011 los usan los disparadores del script 05)
--
-- Ingresos: siguiendo la retroalimentacion de la Entrega 1, la
-- liquidacion cuenta solo reservas Confirmada y Completada. Las
-- Pendiente y Cancelada no son ingreso.
-- Los estados se comparan con UPPER(...) para no depender de si la
-- carga los guardo como 'Completada' o 'COMPLETADA'.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Especificacion del paquete (lo que ven los demas)
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE pkg_reservas AS
--
    FUNCTION fn_valor_estadia (
        p_id_habitacion IN habitacion.id_habitacion%TYPE,
        p_checkin       IN DATE,
        p_checkout      IN DATE
    ) RETURN NUMBER;
--
    PROCEDURE sp_crear_reserva (
        p_id_cliente    IN  cliente.id_cliente%TYPE,
        p_id_habitacion IN  habitacion.id_habitacion%TYPE,
        p_checkin       IN  DATE,
        p_checkout      IN  DATE,
        p_huespedes     IN  NUMBER,
        p_id_reserva    OUT reserva.id_reserva%TYPE
    );
--
    PROCEDURE sp_liquidacion_mensual (
        p_id_alojamiento IN alojamiento.id_alojamiento%TYPE,
        p_anio           IN NUMBER,
        p_mes            IN NUMBER
    );
--
    PROCEDURE sp_liquidacion_masiva (
        p_anio IN NUMBER,
        p_mes  IN NUMBER
    );
--
END pkg_reservas;
/


-- ---------------------------------------------------------------------
-- Cuerpo del paquete
-- ---------------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY pkg_reservas AS
--
    ------------------------------------------------------------------
    -- Cursor explicito con parametros (privado del paquete)
    -- Reservas de un alojamiento cuyo check-in cae en [cp_desde,
    -- cp_hasta), con estado Confirmada o Completada. Para cada una
    -- trae el valor de sus habitaciones (noche por noche, con
    -- fn_valor_estadia) y el de sus servicios (cantidad x precio).
    -- Lo usan las dos liquidaciones, asi el calculo es uno solo.
    ------------------------------------------------------------------
    CURSOR c_reservas (
        cp_alojamiento IN NUMBER,
        cp_desde       IN DATE,
        cp_hasta       IN DATE
    ) IS
        SELECT r.id_reserva,
               r.estado,
               r.fecha_checkin,
               r.fecha_checkout,
               (SELECT NVL(SUM(fn_valor_estadia(rh.id_habitacion,
                                                rh.fecha_checkin,
                                                rh.fecha_checkout)), 0)
                  FROM reserva_habitacion rh
                 WHERE rh.id_reserva = r.id_reserva) AS valor_habitaciones,
               (SELECT NVL(SUM(rs.cantidad * s.precio), 0)
                  FROM reserva_servicio rs
                  JOIN servicio s ON s.id_servicio = rs.id_servicio
                 WHERE rs.id_reserva = r.id_reserva) AS valor_servicios
          FROM reserva r
         WHERE r.id_alojamiento = cp_alojamiento
           AND UPPER(r.estado) IN ('CONFIRMADA', 'COMPLETADA')
           AND r.fecha_checkin >= cp_desde
           AND r.fecha_checkin <  cp_hasta
         ORDER BY r.fecha_checkin, r.id_reserva;
--
--
    ------------------------------------------------------------------
    -- prc_rango_mes (privado)
    -- Valida anio y mes y devuelve el primer dia del mes y el primer
    -- dia del mes siguiente.
    ------------------------------------------------------------------
    PROCEDURE prc_rango_mes (
        p_anio  IN  NUMBER,
        p_mes   IN  NUMBER,
        o_desde OUT DATE,
        o_hasta OUT DATE
    ) IS
    BEGIN
        IF p_mes IS NULL OR p_mes NOT BETWEEN 1 AND 12 THEN
            RAISE_APPLICATION_ERROR(-20008, 'El mes debe estar entre 1 y 12');
        END IF;
        IF p_anio IS NULL OR p_anio NOT BETWEEN 2000 AND 2100 THEN
            RAISE_APPLICATION_ERROR(-20008, 'El anio debe estar entre 2000 y 2100');
        END IF;
--
        o_desde := TO_DATE(TO_CHAR(p_anio, 'FM0000') || '-'
                           || TO_CHAR(p_mes, 'FM00') || '-01', 'YYYY-MM-DD');
        o_hasta := ADD_MONTHS(o_desde, 1);
    END prc_rango_mes;
--
--
    ------------------------------------------------------------------
    -- fn_valor_estadia
    -- Regla 6: cada noche se cobra con la tarifa de la temporada en la
    -- que cae esa noche. Una noche es el dia que va desde el check-in
    -- (incluido) hasta el check-out (excluido): el dia de salida no se
    -- cobra.
    -- Se genera un dia por noche con CONNECT BY, cada dia se cruza con
    -- su temporada y de ahi con la tarifa de la habitacion, y se suman
    -- los precios. Asi una estadia que cruza dos o tres temporadas
    -- cobra cada noche con el precio que le toca.
    -- Controles:
    --   * si alguna noche no tiene tarifa se lanza -20002 en vez de
    --     devolver un valor incompleto;
    --   * si una misma noche cae en dos temporadas (temporadas mal
    --     cargadas que se pisan) se lanza -20012 en vez de cobrarla
    --     dos veces.
    ------------------------------------------------------------------
    FUNCTION fn_valor_estadia (
        p_id_habitacion IN habitacion.id_habitacion%TYPE,
        p_checkin       IN DATE,
        p_checkout      IN DATE
    ) RETURN NUMBER IS
        v_existe    NUMBER;
        v_noches    NUMBER;
        v_cubiertas NUMBER;
        v_filas     NUMBER;
        v_total     NUMBER;
    BEGIN
        IF p_checkin IS NULL OR p_checkout IS NULL
           OR TRUNC(p_checkout) <= TRUNC(p_checkin) THEN
            RAISE_APPLICATION_ERROR(-20001,
                'La fecha de salida debe ser posterior a la de entrada');
        END IF;
--
        SELECT COUNT(*) INTO v_existe
          FROM habitacion
         WHERE id_habitacion = p_id_habitacion;
        IF v_existe = 0 THEN
            RAISE_APPLICATION_ERROR(-20003,
                'La habitacion ' || p_id_habitacion || ' no existe');
        END IF;
--
        v_noches := TRUNC(p_checkout) - TRUNC(p_checkin);
--
        -- v_cubiertas: noches distintas que encontraron tarifa
        -- v_filas:     filas totales (si es mayor, alguna noche se repitio)
        SELECT COUNT(DISTINCT n.noche), COUNT(*), NVL(SUM(t.precio_noche), 0)
          INTO v_cubiertas, v_filas, v_total
          FROM (SELECT TRUNC(p_checkin) + LEVEL - 1 AS noche
                  FROM dual
               CONNECT BY LEVEL <= v_noches) n
          JOIN temporada te
            ON n.noche BETWEEN te.fecha_inicio AND te.fecha_fin
          JOIN tarifa t
            ON t.id_temporada  = te.id_temporada
           AND t.id_habitacion = p_id_habitacion;
--
        IF v_filas > v_cubiertas THEN
            RAISE_APPLICATION_ERROR(-20012,
                'Hay noches entre ' || TO_CHAR(p_checkin, 'YYYY-MM-DD') || ' y '
                || TO_CHAR(p_checkout, 'YYYY-MM-DD')
                || ' con dos precios a la vez (temporadas que se pisan o tarifa'
                || ' repetida); revise TEMPORADA y TARIFA');
        END IF;
--
        IF v_cubiertas <> v_noches THEN
            RAISE_APPLICATION_ERROR(-20002,
                'La habitacion ' || p_id_habitacion || ' no tiene tarifa para '
                || (v_noches - v_cubiertas) || ' de las ' || v_noches
                || ' noches pedidas');
        END IF;
--
        RETURN v_total;
    END fn_valor_estadia;
--
--
    ------------------------------------------------------------------
    -- sp_crear_reserva
    -- Valida en este orden: fechas, huespedes, habitacion, cliente,
    -- capacidad, disponibilidad y tarifas. Solo si todo pasa inserta
    -- la reserva (estado Pendiente) y su linea en RESERVA_HABITACION.
    -- No hace COMMIT: eso lo decide quien llama al procedimiento.
    -- Los ids se calculan con MAX+1 porque el DDL no definio secuencias.
    -- Una habitacion esta ocupada si otra reserva NO cancelada tiene un
    -- rango que se cruza: entrada_nueva < salida_vieja y
    -- salida_nueva > entrada_vieja (salir un dia y entrar otro el mismo
    -- dia no es cruce). Una reserva Pendiente tambien bloquea: si no,
    -- dos clientes podrian apartar la misma habitacion mientras pagan.
    ------------------------------------------------------------------
    PROCEDURE sp_crear_reserva (
        p_id_cliente    IN  cliente.id_cliente%TYPE,
        p_id_habitacion IN  habitacion.id_habitacion%TYPE,
        p_checkin       IN  DATE,
        p_checkout      IN  DATE,
        p_huespedes     IN  NUMBER,
        p_id_reserva    OUT reserva.id_reserva%TYPE
    ) IS
        v_capacidad      habitacion.capacidad_maxima%TYPE;
        v_id_alojamiento habitacion.id_alojamiento%TYPE;
        v_clientes       NUMBER;
        v_cruces         NUMBER;
        v_valor          NUMBER;
        v_id_rh          reserva_habitacion.id_reserva_habitacion%TYPE;
        v_ini            DATE := TRUNC(p_checkin);
        v_fin            DATE := TRUNC(p_checkout);
    BEGIN
        IF p_checkin IS NULL OR p_checkout IS NULL OR v_fin <= v_ini THEN
            RAISE_APPLICATION_ERROR(-20001,
                'La fecha de salida debe ser posterior a la de entrada');
        END IF;
--
        IF p_huespedes IS NULL OR p_huespedes < 1 THEN
            RAISE_APPLICATION_ERROR(-20007,
                'La reserva debe tener al menos un huesped');
        END IF;
--
        BEGIN
            SELECT capacidad_maxima, id_alojamiento
              INTO v_capacidad, v_id_alojamiento
              FROM habitacion
             WHERE id_habitacion = p_id_habitacion;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20003,
                    'La habitacion ' || p_id_habitacion || ' no existe');
        END;
--
        SELECT COUNT(*) INTO v_clientes
          FROM cliente
         WHERE id_cliente = p_id_cliente;
        IF v_clientes = 0 THEN
            RAISE_APPLICATION_ERROR(-20004,
                'El cliente ' || p_id_cliente || ' no existe');
        END IF;
--
        IF p_huespedes > v_capacidad THEN
            RAISE_APPLICATION_ERROR(-20005,
                'La habitacion ' || p_id_habitacion || ' admite maximo '
                || v_capacidad || ' huespedes y se pidieron ' || p_huespedes);
        END IF;
--
        SELECT COUNT(*) INTO v_cruces
          FROM reserva_habitacion rh
          JOIN reserva r ON r.id_reserva = rh.id_reserva
         WHERE rh.id_habitacion = p_id_habitacion
           AND UPPER(r.estado) <> 'CANCELADA'
           AND rh.fecha_checkin  < v_fin
           AND rh.fecha_checkout > v_ini;
        IF v_cruces > 0 THEN
            RAISE_APPLICATION_ERROR(-20006,
                'La habitacion ' || p_id_habitacion
                || ' no esta disponible entre ' || TO_CHAR(v_ini, 'YYYY-MM-DD')
                || ' y ' || TO_CHAR(v_fin, 'YYYY-MM-DD'));
        END IF;
--
        -- si falta alguna tarifa, esta llamada lanza el error -20002
        v_valor := fn_valor_estadia(p_id_habitacion, v_ini, v_fin);
--
        SELECT NVL(MAX(id_reserva), 0) + 1 INTO p_id_reserva FROM reserva;
        INSERT INTO reserva (id_reserva, fecha_checkin, fecha_checkout,
                             estado, id_cliente, id_alojamiento)
        VALUES (p_id_reserva, v_ini, v_fin, 'Pendiente',
                p_id_cliente, v_id_alojamiento);
--
        SELECT NVL(MAX(id_reserva_habitacion), 0) + 1 INTO v_id_rh
          FROM reserva_habitacion;
        INSERT INTO reserva_habitacion (id_reserva_habitacion, fecha_checkin,
                                        fecha_checkout, cantidad_huespedes,
                                        id_reserva, id_habitacion)
        VALUES (v_id_rh, v_ini, v_fin, p_huespedes,
                p_id_reserva, p_id_habitacion);
--
        DBMS_OUTPUT.PUT_LINE('Reserva ' || p_id_reserva || ' creada. Valor de '
            || 'la estadia: ' || TO_CHAR(v_valor, 'FM999999999990'));
    END sp_crear_reserva;
--
--
    ------------------------------------------------------------------
    -- sp_liquidacion_mensual
    -- Liquida un alojamiento en un mes, reserva por reserva. Cuenta
    -- las reservas Confirmada o Completada cuyo check-in cae en ese
    -- mes. El total de cada reserva es el valor de sus habitaciones
    -- (noche por noche) mas sus servicios (regla 7).
    -- Recorre el cursor c_reservas con OPEN / FETCH / CLOSE. Si algo
    -- falla a mitad del recorrido, el manejador cierra el cursor antes
    -- de propagar el error (el cursor es del paquete y, si quedara
    -- abierto, la siguiente llamada daria ORA-06511).
    ------------------------------------------------------------------
    PROCEDURE sp_liquidacion_mensual (
        p_id_alojamiento IN alojamiento.id_alojamiento%TYPE,
        p_anio           IN NUMBER,
        p_mes            IN NUMBER
    ) IS
        v_fila      c_reservas%ROWTYPE;
        v_nombre    alojamiento.nombre_comercial%TYPE;
        v_desde     DATE;
        v_hasta     DATE;
        v_cantidad  NUMBER := 0;
        v_tot_hab   NUMBER := 0;
        v_tot_serv  NUMBER := 0;
    BEGIN
        prc_rango_mes(p_anio, p_mes, v_desde, v_hasta);
--
        BEGIN
            SELECT nombre_comercial INTO v_nombre
              FROM alojamiento
             WHERE id_alojamiento = p_id_alojamiento;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20009,
                    'El alojamiento ' || p_id_alojamiento || ' no existe');
        END;
--
        DBMS_OUTPUT.PUT_LINE('Liquidacion ' || TO_CHAR(v_desde, 'YYYY-MM')
            || ' - ' || v_nombre || ' (alojamiento ' || p_id_alojamiento || ')');
        DBMS_OUTPUT.PUT_LINE('reserva | estado     | check-in   | check-out  |'
            || ' habitaciones | servicios | total');
--
        OPEN c_reservas(p_id_alojamiento, v_desde, v_hasta);
        LOOP
            FETCH c_reservas INTO v_fila;
            EXIT WHEN c_reservas%NOTFOUND;
--
            v_cantidad := v_cantidad + 1;
            v_tot_hab  := v_tot_hab  + v_fila.valor_habitaciones;
            v_tot_serv := v_tot_serv + v_fila.valor_servicios;
--
            DBMS_OUTPUT.PUT_LINE(
                LPAD(v_fila.id_reserva, 7) || ' | '
                || RPAD(v_fila.estado, 10) || ' | '
                || TO_CHAR(v_fila.fecha_checkin, 'YYYY-MM-DD') || ' | '
                || TO_CHAR(v_fila.fecha_checkout, 'YYYY-MM-DD') || ' | '
                || LPAD(TO_CHAR(v_fila.valor_habitaciones, 'FM999999999990'), 12) || ' | '
                || LPAD(TO_CHAR(v_fila.valor_servicios, 'FM999999999990'), 9) || ' | '
                || TO_CHAR(v_fila.valor_habitaciones + v_fila.valor_servicios,
                           'FM999999999990'));
        END LOOP;
        CLOSE c_reservas;
--
        IF v_cantidad = 0 THEN
            DBMS_OUTPUT.PUT_LINE('No hay reservas confirmadas o completadas en ese mes.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Reservas liquidadas: ' || v_cantidad);
            DBMS_OUTPUT.PUT_LINE('Habitaciones: ' || TO_CHAR(v_tot_hab, 'FM999999999990'));
            DBMS_OUTPUT.PUT_LINE('Servicios:    ' || TO_CHAR(v_tot_serv, 'FM999999999990'));
            DBMS_OUTPUT.PUT_LINE('TOTAL A LIQUIDAR: '
                || TO_CHAR(v_tot_hab + v_tot_serv, 'FM999999999990'));
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            IF c_reservas%ISOPEN THEN
                CLOSE c_reservas;
            END IF;
            RAISE;
    END sp_liquidacion_mensual;
--
--
    ------------------------------------------------------------------
    -- sp_liquidacion_masiva
    -- Proceso masivo: recorre TODOS los alojamientos (cursor
    -- c_alojamientos) y, para cada uno, abre el cursor con parametros
    -- c_reservas pasandole el alojamiento y el rango del mes. Imprime
    -- una linea resumen por alojamiento con movimiento y el total
    -- general del mes. Para un alojamiento, su linea da lo mismo que
    -- sp_liquidacion_mensual (se comprueba en el script 07).
    ------------------------------------------------------------------
    PROCEDURE sp_liquidacion_masiva (
        p_anio IN NUMBER,
        p_mes  IN NUMBER
    ) IS
        CURSOR c_alojamientos IS
            SELECT a.id_alojamiento, a.nombre_comercial
              FROM alojamiento a
             ORDER BY a.id_alojamiento;
--
        v_desde      DATE;
        v_hasta      DATE;
        v_cant       NUMBER;
        v_hab        NUMBER;
        v_serv       NUMBER;
        v_sin_mov    NUMBER := 0;
        v_con_mov    NUMBER := 0;
        v_gran_cant  NUMBER := 0;
        v_gran_total NUMBER := 0;
    BEGIN
        prc_rango_mes(p_anio, p_mes, v_desde, v_hasta);
--
        DBMS_OUTPUT.PUT_LINE('Liquidacion masiva ' || TO_CHAR(v_desde, 'YYYY-MM'));
        DBMS_OUTPUT.PUT_LINE('aloj | nombre                         | reservas |'
            || ' habitaciones |  servicios | total');
--
        FOR a IN c_alojamientos LOOP
            v_cant := 0;
            v_hab  := 0;
            v_serv := 0;
--
            FOR r IN c_reservas(a.id_alojamiento, v_desde, v_hasta) LOOP
                v_cant := v_cant + 1;
                v_hab  := v_hab  + r.valor_habitaciones;
                v_serv := v_serv + r.valor_servicios;
            END LOOP;
--
            IF v_cant = 0 THEN
                v_sin_mov := v_sin_mov + 1;
            ELSE
                v_con_mov    := v_con_mov + 1;
                v_gran_cant  := v_gran_cant + v_cant;
                v_gran_total := v_gran_total + v_hab + v_serv;
                DBMS_OUTPUT.PUT_LINE(
                    LPAD(a.id_alojamiento, 4) || ' | '
                    || RPAD(SUBSTR(a.nombre_comercial, 1, 30), 30) || ' | '
                    || LPAD(v_cant, 8) || ' | '
                    || LPAD(TO_CHAR(v_hab, 'FM999999999990'), 12) || ' | '
                    || LPAD(TO_CHAR(v_serv, 'FM999999999990'), 10) || ' | '
                    || TO_CHAR(v_hab + v_serv, 'FM999999999990'));
            END IF;
        END LOOP;
--
        DBMS_OUTPUT.PUT_LINE('Alojamientos con reservas: ' || v_con_mov
            || ' | sin reservas en el mes: ' || v_sin_mov);
        DBMS_OUTPUT.PUT_LINE('Reservas liquidadas: ' || v_gran_cant);
        DBMS_OUTPUT.PUT_LINE('TOTAL DEL MES: ' || TO_CHAR(v_gran_total, 'FM999999999990'));
    END sp_liquidacion_masiva;
--
END pkg_reservas;
/

-- Si algo no compila, este SELECT muestra el error con su linea:
SELECT name, type, line, text FROM user_errors ORDER BY name, type, sequence;

SELECT object_name, object_type, status FROM user_objects WHERE object_name = 'PKG_RESERVAS';
