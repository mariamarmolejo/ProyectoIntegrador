-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- Entrega 2 - Capa de almacenamiento
-- 06_tablespace_vista_materializada_turismouq.sql
-- Equipo: Daniela Munoz, Maria Jose Marmolejo, Santiago Ovalle
--
-- Contenido:
--   1. Tablespace propio para el historico de reservas
--   2. Tabla RESERVA_HISTORICO guardada en ese tablespace y su carga
--   3. Vista materializada MV_OCUPACION_MENSUAL y su politica de refresco
--
-- Requiere 04_paquete (la carga del historico usa fn_valor_estadia).
-- El usuario necesita CREATE TABLESPACE y CREATE MATERIALIZED VIEW.
-- Ejecutar con F5 (Run Script) en SQL Developer.
--
-- Para volver a correr este script desde cero (solo en pruebas):
--   DROP MATERIALIZED VIEW mv_ocupacion_mensual;
--   DROP TABLE reserva_historico PURGE;
--   DROP TABLESPACE ts_historial_reservas INCLUDING CONTENTS AND DATAFILES;
-- =====================================================================

SET SERVEROUTPUT ON


-- ---------------------------------------------------------------------
-- 1. Tablespace del historico
--
-- Justificacion: las reservas ya cerradas (Completada o Cancelada) no se
-- modifican, solo se consultan, y crecen sin parar con cada temporada.
-- Mezclarlas con las tablas operativas (reserva, tarifa, pago...) haria
-- que lo viejo ocupe el mismo espacio y el mismo respaldo que lo que se
-- usa todos los dias. En un tablespace aparte:
--   * el historico crece en su propio archivo (AUTOEXTEND hasta 1G) sin
--     tocar el espacio de las tablas operativas;
--   * se puede respaldar y restaurar por separado, con otra frecuencia;
--   * se puede poner en solo lectura (ALTER TABLESPACE ... READ ONLY) y
--     mover a un disco mas barato cuando el volumen lo pida;
--   * si se llena o se dana, las reservas del dia a dia siguen andando.
--
-- La ruta del archivo NO va escrita a mano: cambia en cada computador
-- (XE 21c, Free 23ai/26ai, Windows o Linux). El bloque la calcula:
--   a) si la base tiene DB_CREATE_FILE_DEST (archivos administrados por
--      Oracle) se crea sin ruta y Oracle elige el lugar;
--   b) si no, se usa la misma carpeta del datafile del tablespace por
--      defecto del usuario;
--   c) si no se puede leer el diccionario, se deja solo el nombre del
--      archivo y Oracle lo crea en su carpeta por defecto.
-- Las consultas al diccionario van con EXECUTE IMMEDIATE para que el
-- bloque compile aunque el usuario no tenga permiso de verlas.
-- El bloque imprime la sentencia que ejecuto (evidencia).
-- ---------------------------------------------------------------------
DECLARE
    v_omf     VARCHAR2(600);
    v_archivo VARCHAR2(600);
    v_dir     VARCHAR2(600);
    v_sql     VARCHAR2(2000);
    v_resto   CONSTANT VARCHAR2(200) :=
        ' SIZE 50M AUTOEXTEND ON NEXT 10M MAXSIZE 1G'
        || ' EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO';
BEGIN
    BEGIN
        EXECUTE IMMEDIATE
            'SELECT value FROM v$parameter WHERE name = ''db_create_file_dest'''
            INTO v_omf;
    EXCEPTION
        WHEN OTHERS THEN v_omf := NULL;
    END;
--
    IF v_omf IS NOT NULL THEN
        v_sql := 'CREATE TABLESPACE ts_historial_reservas DATAFILE' || v_resto;
    ELSE
        BEGIN
            EXECUTE IMMEDIATE
                'SELECT file_name FROM dba_data_files'
                || ' WHERE tablespace_name = (SELECT default_tablespace FROM user_users)'
                || ' AND ROWNUM = 1'
                INTO v_archivo;
            -- carpeta = todo hasta la ultima barra (\ en Windows, / en Linux)
            v_dir := SUBSTR(v_archivo, 1,
                            GREATEST(INSTR(v_archivo, '\', -1), INSTR(v_archivo, '/', -1)));
        EXCEPTION
            WHEN OTHERS THEN v_dir := NULL;
        END;
--
        v_sql := 'CREATE TABLESPACE ts_historial_reservas DATAFILE '''
                 || v_dir || 'TS_HISTORIAL_RESERVAS01.DBF''' || v_resto;
    END IF;
--
    DBMS_OUTPUT.PUT_LINE('Ejecutando: ' || v_sql);
    BEGIN
        EXECUTE IMMEDIATE v_sql;
        DBMS_OUTPUT.PUT_LINE('Tablespace TS_HISTORIAL_RESERVAS creado.');
    EXCEPTION
        WHEN OTHERS THEN
            -- ORA-01543: ya existe (por ejemplo, de una corrida anterior)
            IF SQLCODE = -1543 THEN
                DBMS_OUTPUT.PUT_LINE('El tablespace TS_HISTORIAL_RESERVAS ya existe, se reutiliza.');
            ELSE
                RAISE;
            END IF;
    END;
--
    -- Cuota del usuario sobre el tablespace nuevo. Si el usuario ya
    -- tiene UNLIMITED TABLESPACE no hace falta; si no tiene permiso de
    -- ALTER USER, un administrador debe darla con:
    --   ALTER USER <usuario> QUOTA UNLIMITED ON ts_historial_reservas;
    BEGIN
        EXECUTE IMMEDIATE 'ALTER USER ' || SYS_CONTEXT('USERENV', 'SESSION_USER')
                          || ' QUOTA UNLIMITED ON ts_historial_reservas';
        DBMS_OUTPUT.PUT_LINE('Cuota asignada al usuario ' || SYS_CONTEXT('USERENV', 'SESSION_USER'));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Aviso, no se asigno cuota: ' || SQLERRM);
    END;
END;
/


-- ---------------------------------------------------------------------
-- 2. Tabla de historico
-- Guarda una copia de las reservas cerradas (Completada o Cancelada)
-- cuyo check-out es anterior a la fecha de corte, con el valor de sus
-- habitaciones calculado con la funcion del paquete. Tabla e indices
-- van en el tablespace nuevo. Es una copia: las reservas no se borran
-- de RESERVA porque PAGO, RESENA y RESERVA_SERVICIO las referencian.
-- valor_habitaciones queda NULL si alguna noche de la reserva no tenia
-- tarifa en la carga (dato a revisar, no se inventa un valor).
-- ---------------------------------------------------------------------
CREATE TABLE reserva_historico (
    id_reserva          NUMBER        NOT NULL,
    fecha_checkin       DATE          NOT NULL,
    fecha_checkout      DATE          NOT NULL,
    estado              VARCHAR2(15)  NOT NULL,
    id_cliente          NUMBER        NOT NULL,
    id_alojamiento      NUMBER        NOT NULL,
    valor_habitaciones  NUMBER,
    fecha_archivo       DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT reserva_historico_pk PRIMARY KEY (id_reserva)
        USING INDEX TABLESPACE ts_historial_reservas
)
TABLESPACE ts_historial_reservas;

CREATE INDEX reserva_historico_ix_aloj
    ON reserva_historico (id_alojamiento, fecha_checkin)
    TABLESPACE ts_historial_reservas;

-- Carga del historico. Se hace en un bucle para que una reserva sin
-- tarifa no tumbe toda la carga: se archiva con valor NULL y se cuenta.
DECLARE
    v_corte   CONSTANT DATE := DATE '2026-07-01';
    v_valor   NUMBER;
    v_total   NUMBER := 0;
    v_sin     NUMBER := 0;
BEGIN
    FOR r IN (SELECT id_reserva, fecha_checkin, fecha_checkout, estado,
                     id_cliente, id_alojamiento
                FROM reserva
               WHERE UPPER(estado) IN ('COMPLETADA', 'CANCELADA')
                 AND fecha_checkout < v_corte) LOOP
        BEGIN
            SELECT NVL(SUM(pkg_reservas.fn_valor_estadia(rh.id_habitacion,
                                                         rh.fecha_checkin,
                                                         rh.fecha_checkout)), 0)
              INTO v_valor
              FROM reserva_habitacion rh
             WHERE rh.id_reserva = r.id_reserva;
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE BETWEEN -20999 AND -20000 THEN
                    v_valor := NULL;
                    v_sin   := v_sin + 1;
                ELSE
                    RAISE;
                END IF;
        END;
--
        INSERT INTO reserva_historico (id_reserva, fecha_checkin, fecha_checkout,
                                       estado, id_cliente, id_alojamiento,
                                       valor_habitaciones)
        VALUES (r.id_reserva, r.fecha_checkin, r.fecha_checkout, r.estado,
                r.id_cliente, r.id_alojamiento, v_valor);
        v_total := v_total + 1;
    END LOOP;
--
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Reservas archivadas: ' || v_total
        || ' (sin tarifa completa, valor NULL: ' || v_sin || ')');
END;
/


-- ---------------------------------------------------------------------
-- 3. Vista materializada de ocupacion mensual
-- Una fila por alojamiento y mes: noches ocupadas, noches disponibles
-- (numero de habitaciones x dias del mes) y porcentaje de ocupacion.
--
-- Como se calcula:
--   * Noche ocupada = una habitacion en una noche cubierta por una
--     linea de RESERVA_HABITACION de una reserva Confirmada o
--     Completada (check-in incluido, check-out excluido). Pendiente y
--     Cancelada no cuentan, igual que en los ingresos.
--   * Cada linea se expande en sus noches con una tabla de numeros
--     0..365 (no con un calendario fijo), asi la vista sirve para
--     cualquier rango de fechas de la carga (2024, 2025, 2026...).
--   * Cada pareja habitacion-noche se cuenta UNA sola vez (DISTINCT):
--     si la carga trae lineas repetidas o solapadas, la ocupacion no
--     pasa del 100 %.
--   * Los meses salen del rango real de las reservas y se cruzan con
--     todos los alojamientos: un mes sin ventas aparece con 0 % en vez
--     de desaparecer.
--
-- Politica de refresco: COMPLETE, automatico, todos los dias a las
-- 2:00 a.m. (START WITH / NEXT).
--   * Es un reporte de gestion mensual, no una pantalla en tiempo real:
--     que tenga hasta un dia de atraso es aceptable.
--   * Calcularlo es caro (expande cada reserva en sus noches y agrupa),
--     asi que se hace de madrugada, cuando casi no hay reservas
--     entrando.
--   * No se usa FAST: exigiria registros de cambios (MV LOG) en
--     reserva, reserva_habitacion y habitacion, que se escribirian en
--     cada reserva nueva, y esta consulta (CONNECT BY, DISTINCT, LEFT
--     JOIN y agregaciones sobre varias tablas) no es apta para refresco
--     incremental. Pagar ese costo en cada escritura para un reporte
--     diario no se justifica.
--   * No se usa ON COMMIT por la misma razon: cada reserva confirmada
--     esperaria a que se recalcule toda la vista.
--   * Si se necesita el dato al instante (por ejemplo, antes de una
--     reunion) se refresca a mano con DBMS_MVIEW.REFRESH.
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_ocupacion_mensual
    BUILD IMMEDIATE
    REFRESH COMPLETE
    START WITH TRUNC(SYSDATE) + 1 + 2/24
    NEXT       TRUNC(SYSDATE) + 1 + 2/24
AS
SELECT a.id_alojamiento,
       a.nombre_comercial,
       mu.nombre                                            AS municipio,
       m.mes,
       NVL(o.noches_ocupadas, 0)                            AS noches_ocupadas,
       hc.num_habitaciones,
       hc.num_habitaciones * (LAST_DAY(m.mes) - m.mes + 1)  AS noches_disponibles,
       ROUND(100 * NVL(o.noches_ocupadas, 0)
             / (hc.num_habitaciones * (LAST_DAY(m.mes) - m.mes + 1)), 2) AS pct_ocupacion
  FROM alojamiento a
  JOIN municipio mu
    ON mu.id_municipio = a.id_municipio
  JOIN (SELECT id_alojamiento, COUNT(*) AS num_habitaciones
          FROM habitacion
         GROUP BY id_alojamiento) hc
    ON hc.id_alojamiento = a.id_alojamiento
 CROSS JOIN (SELECT ADD_MONTHS(lim.ini, LEVEL - 1) AS mes
               FROM (SELECT TRUNC(MIN(fecha_checkin), 'MM')      AS ini,
                            TRUNC(MAX(fecha_checkout) - 1, 'MM') AS fin
                       FROM reserva_habitacion) lim
            CONNECT BY LEVEL <= MONTHS_BETWEEN(lim.fin, lim.ini) + 1) m
  LEFT JOIN (SELECT n.id_alojamiento,
                    TRUNC(n.noche, 'MM') AS mes,
                    COUNT(*)             AS noches_ocupadas
               FROM (SELECT DISTINCT h.id_alojamiento,
                                     rh.id_habitacion,
                                     rh.fecha_checkin + d.k AS noche
                       FROM reserva_habitacion rh
                       JOIN reserva    r ON r.id_reserva    = rh.id_reserva
                       JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
                       JOIN (SELECT LEVEL - 1 AS k
                               FROM dual CONNECT BY LEVEL <= 366) d
                         ON d.k < rh.fecha_checkout - rh.fecha_checkin
                      WHERE UPPER(r.estado) IN ('CONFIRMADA', 'COMPLETADA')) n
              GROUP BY n.id_alojamiento, TRUNC(n.noche, 'MM')) o
    ON o.id_alojamiento = a.id_alojamiento
   AND o.mes            = m.mes;

-- Revision rapida
SELECT mview_name, refresh_mode, refresh_method, last_refresh_date
  FROM user_mviews
 WHERE mview_name = 'MV_OCUPACION_MENSUAL';

SELECT COUNT(*) AS filas, MIN(mes) AS primer_mes, MAX(mes) AS ultimo_mes,
       MAX(pct_ocupacion) AS max_pct
  FROM mv_ocupacion_mensual;
