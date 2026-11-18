-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- Entrega 3 - Indices
-- 10_indices_turismouq.sql
-- Equipo: Daniela Munoz, Maria Jose Marmolejo, Santiago Ovalle
--
-- Mismo usuario dueno de las tablas. Se puede correr completo con F5,
-- pero para las capturas conviene ir consulta por consulta.
--
-- Tres consultas lentas y su indice:
--   Q1  disponibilidad de una habitacion  -> IX_RH_HAB_FECHAS (compuesto)
--   Q2  lineas de una reserva / liquidacion -> IX_RH_RESERVA (llave foranea)
--   Q3  buscar cliente por correo sin importar mayusculas
--                                         -> IX_CLIENTE_CORREO_UPPER (basado en funcion)
-- Y un caso donde el indice no ayuda:
--   Q4  reservas Completadas              -> IX_RESERVA_ESTADO
--
-- Como se mide cada consulta:
--   * EXPLAIN PLAN: el plan que el optimizador piensa usar y su costo.
--   * La consulta se ejecuta con el hint GATHER_PLAN_STATISTICS y luego
--     DBMS_XPLAN.DISPLAY_CURSOR(..., 'ALLSTATS LAST') muestra el plan
--     que de verdad uso, con A-Rows (filas reales), Buffers (bloques
--     leidos) y A-Time (tiempo real). Buffers es la medida principal:
--     no depende de si el computador esta ocupado.
--   Para DISPLAY_CURSOR el usuario necesita SELECT_CATALOG_ROLE (ver
--   README).
--
-- Cada consulta lleva una etiqueta de texto ('Q1_ANTES', 'Q1_DESPUES'...)
-- para encontrarla despues en V$SQL.
-- =====================================================================

SET SERVEROUTPUT ON


-- ---------------------------------------------------------------------
-- 0. Preparacion: si el script ya se habia corrido, se borran los
-- indices para que el "antes" sea de verdad sin indice. Luego se
-- actualizan las estadisticas de las tablas.
-- ---------------------------------------------------------------------
BEGIN
    FOR i IN (SELECT index_name FROM user_indexes
               WHERE index_name IN ('IX_RH_HAB_FECHAS', 'IX_RH_RESERVA',
                                    'IX_CLIENTE_CORREO_UPPER', 'IX_RESERVA_ESTADO')) LOOP
        EXECUTE IMMEDIATE 'DROP INDEX ' || i.index_name;
    END LOOP;
--
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'RESERVA');
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'RESERVA_HABITACION');
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'CLIENTE');
END;
/

-- Tamano de las tablas
SELECT table_name, num_rows, blocks
  FROM user_tables
 WHERE table_name IN ('RESERVA', 'RESERVA_HABITACION', 'CLIENTE')
 ORDER BY table_name;
-- Resultado: CLIENTE             3000 filas /  35 bloques
--            RESERVA            25500 filas / 244 bloques
--            RESERVA_HABITACION 33689 filas / 244 bloques


-- =====================================================================
-- Q1. Disponibilidad de una habitacion
-- Es la consulta que corren sp_crear_reserva y el disparador
-- TRG_RH_SIN_SOLAPE cada vez que alguien reserva. Habitacion 362,
-- del 15 al 20 de junio de 2026.
-- =====================================================================

-- ANTES
EXPLAIN PLAN SET STATEMENT_ID = 'Q1_ANTES' FOR
SELECT COUNT(*) AS cruces
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
 WHERE rh.id_habitacion = 362
   AND UPPER(r.estado) <> 'CANCELADA'
   AND rh.fecha_checkin  < DATE '2026-06-20'
   AND rh.fecha_checkout > DATE '2026-06-15';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q1_ANTES', 'TYPICAL'));
-- Plan obtenido: TABLE ACCESS FULL de RESERVA_HABITACION (lee la
-- tabla completa para quedarse con las lineas de una habitacion).
-- Costo: 76

SELECT /*+ GATHER_PLAN_STATISTICS */ 'Q1_ANTES' AS prueba, COUNT(*) AS cruces
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
 WHERE rh.id_habitacion = 362
   AND UPPER(r.estado) <> 'CANCELADA'
   AND rh.fecha_checkin  < DATE '2026-06-20'
   AND rh.fecha_checkout > DATE '2026-06-15';

SELECT t.plan_table_output
  FROM (SELECT sql_id, child_number FROM v$sql
         WHERE sql_text LIKE '%''Q1_ANTES'' AS prueba%'
           AND sql_text NOT LIKE '%v$sql%'
         ORDER BY last_active_time DESC
         FETCH FIRST 1 ROW ONLY) c,
       TABLE(DBMS_XPLAN.DISPLAY_CURSOR(c.sql_id, c.child_number, 'ALLSTATS LAST')) t;
-- Buffers: 206   A-Time: 0,01 s

-- Indice compuesto: primero la habitacion (igualdad) y despues las
-- fechas (rango). En ese orden Oracle salta directo a las lineas de la
-- habitacion y dentro de ellas ya estan ordenadas por fecha. La fecha
-- de salida va de tercera para que la condicion se pueda revisar en el
-- mismo indice sin ir a la tabla.
CREATE INDEX ix_rh_hab_fechas
    ON reserva_habitacion (id_habitacion, fecha_checkin, fecha_checkout);

-- DESPUES
EXPLAIN PLAN SET STATEMENT_ID = 'Q1_DESPUES' FOR
SELECT COUNT(*) AS cruces
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
 WHERE rh.id_habitacion = 362
   AND UPPER(r.estado) <> 'CANCELADA'
   AND rh.fecha_checkin  < DATE '2026-06-20'
   AND rh.fecha_checkout > DATE '2026-06-15';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q1_DESPUES', 'TYPICAL'));
-- Plan obtenido: INDEX RANGE SCAN de IX_RH_HAB_FECHAS.
-- Costo: 16

SELECT /*+ GATHER_PLAN_STATISTICS */ 'Q1_DESPUES' AS prueba, COUNT(*) AS cruces
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
 WHERE rh.id_habitacion = 362
   AND UPPER(r.estado) <> 'CANCELADA'
   AND rh.fecha_checkin  < DATE '2026-06-20'
   AND rh.fecha_checkout > DATE '2026-06-15';

SELECT t.plan_table_output
  FROM (SELECT sql_id, child_number FROM v$sql
         WHERE sql_text LIKE '%''Q1_DESPUES'' AS prueba%'
           AND sql_text NOT LIKE '%v$sql%'
         ORDER BY last_active_time DESC
         FETCH FIRST 1 ROW ONLY) c,
       TABLE(DBMS_XPLAN.DISPLAY_CURSOR(c.sql_id, c.child_number, 'ALLSTATS LAST')) t;
-- Buffers: 6   A-Time: 0,01 s


-- =====================================================================
-- Q2. Lineas de una reserva (y la liquidacion mensual)
-- RESERVA_HABITACION.id_reserva es llave foranea y Oracle no le crea
-- indice solo. El cursor de la liquidacion (script 04) busca las
-- lineas de cada reserva, una por una: sin indice, cada busqueda lee
-- la tabla completa. Por eso la liquidacion masiva tardaba minutos.
-- =====================================================================

-- ANTES
EXPLAIN PLAN SET STATEMENT_ID = 'Q2_ANTES' FOR
SELECT id_reserva_habitacion, id_habitacion, fecha_checkin, fecha_checkout
  FROM reserva_habitacion
 WHERE id_reserva = 15000;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q2_ANTES', 'TYPICAL'));
-- Plan obtenido: TABLE ACCESS FULL de RESERVA_HABITACION.  Costo: 69

SELECT /*+ GATHER_PLAN_STATISTICS */ 'Q2_ANTES' AS prueba,
       id_reserva_habitacion, id_habitacion, fecha_checkin, fecha_checkout
  FROM reserva_habitacion
 WHERE id_reserva = 15000;

SELECT t.plan_table_output
  FROM (SELECT sql_id, child_number FROM v$sql
         WHERE sql_text LIKE '%''Q2_ANTES'' AS prueba%'
           AND sql_text NOT LIKE '%v$sql%'
         ORDER BY last_active_time DESC
         FETCH FIRST 1 ROW ONLY) c,
       TABLE(DBMS_XPLAN.DISPLAY_CURSOR(c.sql_id, c.child_number, 'ALLSTATS LAST')) t;
-- Buffers: 204

-- Tiempo de la liquidacion de un alojamiento (alojamiento 1, junio 2026)
DECLARE
    v_ini NUMBER := DBMS_UTILITY.GET_TIME;
BEGIN
    pkg_reservas.sp_liquidacion_mensual(1, 2026, 6);
    DBMS_OUTPUT.PUT_LINE('Tiempo SIN indice: '
        || TO_CHAR((DBMS_UTILITY.GET_TIME - v_ini) / 100, 'FM990.00') || ' s');
END;
/
-- Tiempo SIN indice: 3,12 s

CREATE INDEX ix_rh_reserva ON reserva_habitacion (id_reserva);

-- DESPUES
EXPLAIN PLAN SET STATEMENT_ID = 'Q2_DESPUES' FOR
SELECT id_reserva_habitacion, id_habitacion, fecha_checkin, fecha_checkout
  FROM reserva_habitacion
 WHERE id_reserva = 15000;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q2_DESPUES', 'TYPICAL'));
-- Plan obtenido: INDEX RANGE SCAN de IX_RH_RESERVA y TABLE ACCESS BY
-- INDEX ROWID.  Costo: 2

SELECT /*+ GATHER_PLAN_STATISTICS */ 'Q2_DESPUES' AS prueba,
       id_reserva_habitacion, id_habitacion, fecha_checkin, fecha_checkout
  FROM reserva_habitacion
 WHERE id_reserva = 15000;

SELECT t.plan_table_output
  FROM (SELECT sql_id, child_number FROM v$sql
         WHERE sql_text LIKE '%''Q2_DESPUES'' AS prueba%'
           AND sql_text NOT LIKE '%v$sql%'
         ORDER BY last_active_time DESC
         FETCH FIRST 1 ROW ONLY) c,
       TABLE(DBMS_XPLAN.DISPLAY_CURSOR(c.sql_id, c.child_number, 'ALLSTATS LAST')) t;
-- Buffers: 5

DECLARE
    v_ini NUMBER := DBMS_UTILITY.GET_TIME;
BEGIN
    pkg_reservas.sp_liquidacion_mensual(1, 2026, 6);
    DBMS_OUTPUT.PUT_LINE('Tiempo CON indice: '
        || TO_CHAR((DBMS_UTILITY.GET_TIME - v_ini) / 100, 'FM990.00') || ' s');
END;
/
-- Tiempo CON indice: 0,04 s
-- El total de la liquidacion fue el mismo en las dos corridas
-- (260778000): el indice cambia la velocidad, no el resultado.


-- =====================================================================
-- Q3. Buscar un cliente por correo sin importar mayusculas
-- En recepcion el cliente dicta el correo y se escribe como salga
-- ('Cliente2026@Correo.com'). Para encontrarlo se compara con UPPER.
-- CLIENTE ya tiene un indice sobre correo (el de la restriccion
-- UNIQUE), pero guarda el correo tal cual, no en mayusculas, asi que
-- no sirve para UPPER(correo).
-- =====================================================================

-- ANTES
EXPLAIN PLAN SET STATEMENT_ID = 'Q3_ANTES' FOR
SELECT id_cliente, nombre, correo, telefono
  FROM cliente
 WHERE UPPER(correo) = UPPER('Cliente2026@Correo.com');

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q3_ANTES', 'TYPICAL'));
-- Plan obtenido: TABLE ACCESS FULL de CLIENTE (el indice de la UNIQUE
-- no aparece).  Costo: 11

SELECT /*+ GATHER_PLAN_STATISTICS */ 'Q3_ANTES' AS prueba,
       id_cliente, nombre, correo, telefono
  FROM cliente
 WHERE UPPER(correo) = UPPER('Cliente2026@Correo.com');

SELECT t.plan_table_output
  FROM (SELECT sql_id, child_number FROM v$sql
         WHERE sql_text LIKE '%''Q3_ANTES'' AS prueba%'
           AND sql_text NOT LIKE '%v$sql%'
         ORDER BY last_active_time DESC
         FETCH FIRST 1 ROW ONLY) c,
       TABLE(DBMS_XPLAN.DISPLAY_CURSOR(c.sql_id, c.child_number, 'ALLSTATS LAST')) t;
-- Buffers: 38

-- Indice basado en funcion: guarda UPPER(correo) ya calculado.
CREATE INDEX ix_cliente_correo_upper ON cliente (UPPER(correo));

-- Despues de un indice basado en funcion se recogen estadisticas: asi
-- el optimizador conoce la columna oculta que Oracle crea para guardar
-- UPPER(correo).
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'CLIENTE', method_opt => 'FOR ALL HIDDEN COLUMNS SIZE 1');
END;
/

-- DESPUES
EXPLAIN PLAN SET STATEMENT_ID = 'Q3_DESPUES' FOR
SELECT id_cliente, nombre, correo, telefono
  FROM cliente
 WHERE UPPER(correo) = UPPER('Cliente2026@Correo.com');

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q3_DESPUES', 'TYPICAL'));
-- Plan obtenido: INDEX RANGE SCAN de IX_CLIENTE_CORREO_UPPER.  Costo: 2

SELECT /*+ GATHER_PLAN_STATISTICS */ 'Q3_DESPUES' AS prueba,
       id_cliente, nombre, correo, telefono
  FROM cliente
 WHERE UPPER(correo) = UPPER('Cliente2026@Correo.com');

SELECT t.plan_table_output
  FROM (SELECT sql_id, child_number FROM v$sql
         WHERE sql_text LIKE '%''Q3_DESPUES'' AS prueba%'
           AND sql_text NOT LIKE '%v$sql%'
         ORDER BY last_active_time DESC
         FETCH FIRST 1 ROW ONLY) c,
       TABLE(DBMS_XPLAN.DISPLAY_CURSOR(c.sql_id, c.child_number, 'ALLSTATS LAST')) t;
-- Buffers: 4
-- Encuentra al cliente 2026 (cliente2026@correo.com).


-- =====================================================================
-- Q4. Caso donde el indice NO ayuda: reservas Completadas
-- ESTADO solo tiene 4 valores y casi todas las reservas estan
-- Completada. Un indice ahi parece buena idea ("se filtra mucho por
-- estado"), pero no sirve.
-- =====================================================================

SELECT estado, COUNT(*) AS reservas,
       ROUND(100 * RATIO_TO_REPORT(COUNT(*)) OVER (), 1) AS porcentaje
  FROM reserva
 GROUP BY estado
 ORDER BY reservas DESC;
-- Resultado: Completada 20081 (78,7 %), Cancelada 3654,
--            Confirmada 1229, Pendiente 536

CREATE INDEX ix_reserva_estado ON reserva (estado);

-- Con el indice creado, el optimizador NO lo usa
EXPLAIN PLAN SET STATEMENT_ID = 'Q4_LIBRE' FOR
SELECT COUNT(*) AS reservas, SUM(fecha_checkout - fecha_checkin) AS noches
  FROM reserva
 WHERE estado = 'Completada';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q4_LIBRE', 'TYPICAL'));
-- Plan obtenido: TABLE ACCESS FULL de RESERVA, aunque el indice existe.
-- Costo: 69

SELECT /*+ GATHER_PLAN_STATISTICS */ 'Q4_LIBRE' AS prueba,
       COUNT(*) AS reservas, SUM(fecha_checkout - fecha_checkin) AS noches
  FROM reserva
 WHERE estado = 'Completada';

SELECT t.plan_table_output
  FROM (SELECT sql_id, child_number FROM v$sql
         WHERE sql_text LIKE '%''Q4_LIBRE'' AS prueba%'
           AND sql_text NOT LIKE '%v$sql%'
         ORDER BY last_active_time DESC
         FETCH FIRST 1 ROW ONLY) c,
       TABLE(DBMS_XPLAN.DISPLAY_CURSOR(c.sql_id, c.child_number, 'ALLSTATS LAST')) t;
-- Buffers: 203

-- Obligandolo a usar el indice con un hint
EXPLAIN PLAN SET STATEMENT_ID = 'Q4_FORZADO' FOR
SELECT /*+ INDEX(r ix_reserva_estado) */
       COUNT(*) AS reservas, SUM(fecha_checkout - fecha_checkin) AS noches
  FROM reserva r
 WHERE estado = 'Completada';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, 'Q4_FORZADO', 'TYPICAL'));
-- Plan: INDEX RANGE SCAN de IX_RESERVA_ESTADO + TABLE ACCESS BY INDEX
-- ROWID. Costo: 542 (8 veces el del FULL)

SELECT /*+ GATHER_PLAN_STATISTICS INDEX(r ix_reserva_estado) */ 'Q4_FORZADO' AS prueba,
       COUNT(*) AS reservas, SUM(fecha_checkout - fecha_checkin) AS noches
  FROM reserva r
 WHERE estado = 'Completada';

SELECT t.plan_table_output
  FROM (SELECT sql_id, child_number FROM v$sql
         WHERE sql_text LIKE '%''Q4_FORZADO'' AS prueba%'
           AND sql_text NOT LIKE '%v$sql%'
         ORDER BY last_active_time DESC
         FETCH FIRST 1 ROW ONLY) c,
       TABLE(DBMS_XPLAN.DISPLAY_CURSOR(c.sql_id, c.child_number, 'ALLSTATS LAST')) t;
-- Buffers: 217 (no ahorra nada: el FULL leyo 203)

-- Por que no ayuda:
-- La consulta trae el 78,7 % de las reservas, y esas reservas estan
-- repartidas por todos los bloques de la tabla. Aunque use el indice,
-- Oracle termina leyendo practicamente todos los bloques de RESERVA
-- (244) y encima los del indice: 217 buffers contra 203 del FULL. No
-- hay ningun ahorro. El optimizador lo sabe antes de ejecutar (costo
-- 542 con el indice contra 69 sin el) y por eso, si se le deja
-- decidir, ni lo usa. Un indice B-tree sirve cuando la condicion deja
-- pasar pocas filas; con una columna de 4 valores donde uno domina, no.
-- Ademas el indice no es gratis: cada INSERT de reserva y cada cambio
-- de estado (Pendiente -> Confirmada -> Completada) tiene que
-- actualizarlo. Tampoco conviene volverlo BITMAP: RESERVA recibe
-- reservas nuevas todo el tiempo y un bitmap bloquea muchas filas a la
-- vez en cada DML.
-- Como no aporta, se borra.
DROP INDEX ix_reserva_estado;


-- ---------------------------------------------------------------------
-- Indices que quedan
-- ---------------------------------------------------------------------
SELECT index_name, index_type, table_name
  FROM user_indexes
 WHERE index_name IN ('IX_RH_HAB_FECHAS', 'IX_RH_RESERVA', 'IX_CLIENTE_CORREO_UPPER')
 ORDER BY index_name;
-- Resultado:
--   IX_CLIENTE_CORREO_UPPER  FUNCTION-BASED NORMAL  CLIENTE
--   IX_RH_HAB_FECHAS         NORMAL                 RESERVA_HABITACION
--   IX_RH_RESERVA            NORMAL                 RESERVA_HABITACION

SELECT index_name, column_position, column_name
  FROM user_ind_columns
 WHERE index_name IN ('IX_RH_HAB_FECHAS', 'IX_RH_RESERVA', 'IX_CLIENTE_CORREO_UPPER')
 ORDER BY index_name, column_position;
-- En el indice basado en funcion la columna sale con un nombre interno
-- (SYS_NC...$); la expresion real se ve asi:
SELECT index_name, column_expression
  FROM user_ind_expressions
 WHERE index_name = 'IX_CLIENTE_CORREO_UPPER';
-- Resultado: IX_CLIENTE_CORREO_UPPER | UPPER("CORREO")
