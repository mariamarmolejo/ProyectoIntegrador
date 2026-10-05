-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- 03_consultas_turismouq.sql
-- Las 7 consultas de analisis obligatorias de la Entrega 1.
-- Requiere que 01_ddl_turismouq.sql y 02_carga_turismouq.sql ya se
-- hayan ejecutado.
-- =====================================================================


----------------------------------------------------------------------
-- CONSULTA 1 - Ocupacion por municipio y mes (PIVOT)
-- Cuenta reservas (reserva_habitacion, porque eso es "ocupacion" real
-- de habitaciones) por municipio, cruzando los 12 meses del 2026 como
-- columnas.
----------------------------------------------------------------------
SELECT *
FROM (
    SELECT mu.nombre AS municipio,
           TO_CHAR(rh.fecha_checkin, 'MM') AS mes,
           rh.id_reserva_habitacion
    FROM reserva_habitacion rh
    JOIN habitacion h   ON h.id_habitacion = rh.id_habitacion
    JOIN alojamiento al ON al.id_alojamiento = h.id_alojamiento
    JOIN municipio mu   ON mu.id_municipio = al.id_municipio
    WHERE rh.fecha_checkin BETWEEN DATE '2026-01-01' AND DATE '2026-12-31'
)
PIVOT (
    COUNT(id_reserva_habitacion)
    FOR mes IN (
        '01' AS ene, '02' AS feb, '03' AS mar, '04' AS abr,
        '05' AS may, '06' AS jun, '07' AS jul, '08' AS ago,
        '09' AS sep, '10' AS oct, '11' AS nov, '12' AS dic
    )
)
ORDER BY municipio;
-- Justificacion: PIVOT convierte el mes (que esta como filas) en
-- columnas, una por cada mes del 2026, con el conteo de habitaciones
-- ocupadas (reserva_habitacion) como valor de cada celda. Se parte de
-- reserva_habitacion y no de reserva porque la "ocupacion" se mide en
-- habitaciones, no en reservas (una reserva puede ocupar varias).


----------------------------------------------------------------------
-- CONSULTA 2 - Ingresos por municipio, tipo de alojamiento y
-- temporada (ROLLUP + GROUPING)
-- El ingreso de una linea de reserva_habitacion se aproxima con la
-- tarifa vigente de esa habitacion en la temporada del checkin,
-- multiplicada por las noches (misma logica usada en la carga).
----------------------------------------------------------------------
SELECT CASE WHEN GROUPING(g_municipio) = 1 THEN 'TOTAL GENERAL' ELSE g_municipio END AS municipio,
       CASE WHEN GROUPING(g_municipio) = 1 THEN NULL
            WHEN GROUPING(g_tipo_alojamiento) = 1 THEN 'Subtotal municipio'
            ELSE g_tipo_alojamiento END AS tipo_alojamiento,
       CASE WHEN GROUPING(g_municipio) = 1 OR GROUPING(g_tipo_alojamiento) = 1 THEN NULL
            WHEN GROUPING(g_temporada) = 1 THEN 'Subtotal tipo'
            ELSE g_temporada END AS temporada,
       SUM(ingreso) AS ingreso_total
FROM (
    SELECT mu.nombre      AS g_municipio,
           ta.nombre      AS g_tipo_alojamiento,
           tmp.nombre     AS g_temporada,
           t.precio_noche * (rh.fecha_checkout - rh.fecha_checkin) AS ingreso
    FROM reserva_habitacion rh
    JOIN habitacion h    ON h.id_habitacion = rh.id_habitacion
    JOIN alojamiento al  ON al.id_alojamiento = h.id_alojamiento
    JOIN municipio mu    ON mu.id_municipio = al.id_municipio
    JOIN tipo_alojamiento ta ON ta.id_tipo_alojamiento = al.id_tipo_alojamiento
    JOIN tarifa t         ON t.id_habitacion = h.id_habitacion
    JOIN temporada tmp    ON tmp.id_temporada = t.id_temporada
                          AND rh.fecha_checkin BETWEEN tmp.fecha_inicio AND tmp.fecha_fin
)
GROUP BY ROLLUP(g_municipio, g_tipo_alojamiento, g_temporada)
ORDER BY GROUPING(g_municipio), g_municipio,
         GROUPING(g_tipo_alojamiento), g_tipo_alojamiento,
         GROUPING(g_temporada), g_temporada;
-- Justificacion: ROLLUP de 3 niveles (municipio -> tipo_alojamiento ->
-- temporada) genera el detalle mas los subtotales intermedios y el
-- total general, en una sola pasada. GROUPING() identifica cada nivel
-- para poner las etiquetas en vez de dejar NULL.


----------------------------------------------------------------------
-- CONSULTA 3 - Los 3 alojamientos de mayor ingreso dentro de cada
-- municipio (RANK con PARTITION BY)
----------------------------------------------------------------------
SELECT municipio, alojamiento, ingreso_total, posicion
FROM (
    SELECT mu.nombre AS municipio,
           al.nombre_comercial AS alojamiento,
           SUM(t.precio_noche * (rh.fecha_checkout - rh.fecha_checkin)) AS ingreso_total,
           RANK() OVER (
               PARTITION BY mu.nombre
               ORDER BY SUM(t.precio_noche * (rh.fecha_checkout - rh.fecha_checkin)) DESC
           ) AS posicion
    FROM reserva_habitacion rh
    JOIN habitacion h    ON h.id_habitacion = rh.id_habitacion
    JOIN alojamiento al  ON al.id_alojamiento = h.id_alojamiento
    JOIN municipio mu    ON mu.id_municipio = al.id_municipio
    JOIN tarifa t         ON t.id_habitacion = h.id_habitacion
    JOIN temporada tmp    ON tmp.id_temporada = t.id_temporada
                          AND rh.fecha_checkin BETWEEN tmp.fecha_inicio AND tmp.fecha_fin
    GROUP BY mu.nombre, al.id_alojamiento, al.nombre_comercial
)
WHERE posicion <= 3
ORDER BY municipio, posicion;
-- Justificacion: se agrupan los ingresos por alojamiento dentro de
-- cada municipio, y RANK() OVER (PARTITION BY municipio ...) numera
-- de mayor a menor ingreso dentro de cada particion. El filtro
-- posicion <= 3 va en la consulta externa porque la funcion de
-- ventana se evalua despues del WHERE/GROUP BY internos.


----------------------------------------------------------------------
-- CONSULTA 4 - Variacion de ingresos mes contra mes (LAG)
----------------------------------------------------------------------
SELECT mes,
       ingreso_mes,
       LAG(ingreso_mes) OVER (ORDER BY mes) AS ingreso_mes_anterior,
       ingreso_mes - LAG(ingreso_mes) OVER (ORDER BY mes) AS variacion_absoluta,
       ROUND(
           100 * (ingreso_mes - LAG(ingreso_mes) OVER (ORDER BY mes))
             / LAG(ingreso_mes) OVER (ORDER BY mes),
           2
       ) AS variacion_porcentual
FROM (
    SELECT TO_CHAR(rh.fecha_checkin, 'YYYY-MM') AS mes,
           SUM(t.precio_noche * (rh.fecha_checkout - rh.fecha_checkin)) AS ingreso_mes
    FROM reserva_habitacion rh
    JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
    JOIN tarifa t      ON t.id_habitacion = h.id_habitacion
    JOIN temporada tmp ON tmp.id_temporada = t.id_temporada
                       AND rh.fecha_checkin BETWEEN tmp.fecha_inicio AND tmp.fecha_fin
    GROUP BY TO_CHAR(rh.fecha_checkin, 'YYYY-MM')
)
ORDER BY mes;
-- Justificacion: se calcula primero el ingreso total por mes en la
-- subconsulta. LAG(ingreso_mes) OVER (ORDER BY mes) trae el valor de
-- la fila anterior (el mes previo) a la fila actual, lo que permite
-- calcular la variacion absoluta y porcentual sin un self-join.


----------------------------------------------------------------------
-- CONSULTA 5 - Consulta parametrizada (variables de enlace) -
-- Reservas y su valor aproximado dentro de un rango de fechas
----------------------------------------------------------------------
VARIABLE v_fecha_inicio VARCHAR2(10);
VARIABLE v_fecha_fin VARCHAR2(10);
EXEC :v_fecha_inicio := '2026-06-01';
EXEC :v_fecha_fin := '2026-07-31';

WITH reservas_rango AS (
    SELECT r.id_reserva,
           c.nombre AS cliente,
           al.nombre_comercial AS alojamiento,
           r.fecha_checkin,
           r.fecha_checkout,
           r.estado
    FROM reserva r
    JOIN cliente c
        ON c.id_cliente = r.id_cliente
    JOIN alojamiento al
        ON al.id_alojamiento = r.id_alojamiento
    WHERE r.fecha_checkin BETWEEN TO_DATE(:v_fecha_inicio, 'YYYY-MM-DD')
                              AND TO_DATE(:v_fecha_fin, 'YYYY-MM-DD')
),
valor_estadia AS (
    SELECT rh.id_reserva,
           SUM(t.precio_noche * (rh.fecha_checkout - rh.fecha_checkin)) AS valor_estadia
    FROM reserva_habitacion rh
    JOIN habitacion h
        ON h.id_habitacion = rh.id_habitacion
    JOIN tarifa t
        ON t.id_habitacion = h.id_habitacion
    JOIN temporada tmp
        ON tmp.id_temporada = t.id_temporada
       AND rh.fecha_checkin BETWEEN tmp.fecha_inicio AND tmp.fecha_fin
    GROUP BY rh.id_reserva
),
valor_servicios AS (
    SELECT rs.id_reserva,
           SUM(rs.cantidad * s.precio) AS valor_servicios
    FROM reserva_servicio rs
    JOIN servicio s
        ON s.id_servicio = rs.id_servicio
    GROUP BY rs.id_reserva
)
SELECT rr.id_reserva,
       rr.cliente,
       rr.alojamiento,
       rr.fecha_checkin,
       rr.fecha_checkout,
       rr.estado,
       NVL(ve.valor_estadia, 0) + NVL(vs.valor_servicios, 0) AS valor_aproximado
FROM reservas_rango rr
LEFT JOIN valor_estadia ve
    ON ve.id_reserva = rr.id_reserva
LEFT JOIN valor_servicios vs
    ON vs.id_reserva = rr.id_reserva
ORDER BY rr.fecha_checkin, rr.id_reserva;
-- Justificacion: :v_fecha_inicio y :v_fecha_fin son variables de
-- enlace (bind variables) de SQL*Plus/SQL Developer. Permiten
-- reutilizar la misma consulta para cualquier rango de fechas sin
-- reescribir el SQL (y de paso, Oracle reutiliza el plan de
-- ejecucion en vez de parsear una consulta nueva cada vez).


----------------------------------------------------------------------
-- CONSULTA 6 - UNPIVOT -
-- A partir del resultado de ocupacion por mes (como en la consulta 1,
-- ya pivoteado), se regresa a formato de filas para poder sumar o
-- filtrar por mes facilmente.
----------------------------------------------------------------------
WITH base AS (
    SELECT mu.nombre AS municipio,
           TO_CHAR(rh.fecha_checkin, 'MM') AS mes,
           rh.id_reserva_habitacion
    FROM reserva_habitacion rh
    JOIN habitacion h   ON h.id_habitacion = rh.id_habitacion
    JOIN alojamiento al ON al.id_alojamiento = h.id_alojamiento
    JOIN municipio mu   ON mu.id_municipio = al.id_municipio
    WHERE rh.fecha_checkin BETWEEN DATE '2026-01-01' AND DATE '2026-12-31'
),
pivoteado AS (
    SELECT *
    FROM base
    PIVOT (
        COUNT(id_reserva_habitacion)
        FOR mes IN (
            '01' AS ene, '02' AS feb, '03' AS mar, '04' AS abr,
            '05' AS may, '06' AS jun, '07' AS jul, '08' AS ago,
            '09' AS sep, '10' AS oct, '11' AS nov, '12' AS dic
        )
    )
)
SELECT municipio, mes, ocupacion
FROM pivoteado
UNPIVOT (
    ocupacion FOR mes IN (
        ene AS 'Enero', feb AS 'Febrero', mar AS 'Marzo', abr AS 'Abril',
        may AS 'Mayo', jun AS 'Junio', jul AS 'Julio', ago AS 'Agosto',
        sep AS 'Septiembre', oct AS 'Octubre', nov AS 'Noviembre', dic AS 'Diciembre'
    )
)
ORDER BY municipio,
         CASE mes
             WHEN 'Enero' THEN 1
             WHEN 'Febrero' THEN 2
             WHEN 'Marzo' THEN 3
             WHEN 'Abril' THEN 4
             WHEN 'Mayo' THEN 5
             WHEN 'Junio' THEN 6
             WHEN 'Julio' THEN 7
             WHEN 'Agosto' THEN 8
             WHEN 'Septiembre' THEN 9
             WHEN 'Octubre' THEN 10
             WHEN 'Noviembre' THEN 11
             WHEN 'Diciembre' THEN 12
         END;
-- Justificacion: UNPIVOT hace lo inverso de PIVOT: toma columnas (los
-- 12 meses) y las convierte de vuelta en filas (columna "mes" +
-- columna "ocupacion"). Se usa aqui sobre el resultado pivoteado de
-- la consulta 1 para demostrar el par PIVOT/UNPIVOT de forma coherente.


----------------------------------------------------------------------
-- CONSULTA 7 - Libre: calificacion promedio vs. volumen de reservas
-- por alojamiento (oportunidad de negocio: alojamientos muy bien
-- calificados pero con pocas reservas -> potencial de crecimiento
-- si se promocionan mas).
----------------------------------------------------------------------
SELECT al.nombre_comercial AS alojamiento,
       mu.nombre AS municipio,
       ROUND(AVG(re.calificacion), 2) AS calificacion_promedio,
       COUNT(DISTINCT re.id_resena) AS num_resenas,
       COUNT(DISTINCT r.id_reserva) AS num_reservas
FROM alojamiento al
JOIN municipio mu ON mu.id_municipio = al.id_municipio
JOIN reserva r     ON r.id_alojamiento = al.id_alojamiento
LEFT JOIN resena re ON re.id_reserva = r.id_reserva
GROUP BY al.nombre_comercial, mu.nombre
HAVING AVG(re.calificacion) >= 4
ORDER BY calificacion_promedio DESC, num_reservas ASC;
-- Pregunta de negocio: "?que alojamientos estan muy bien calificados
-- (promedio >= 4) pero tienen relativamente pocas reservas?" -- son
-- candidatos a invertir en promocion, porque la calidad ya esta
-- validada por los huespedes pero la demanda todavia no la refleja.
-- Justificacion: LEFT JOIN con resena porque no todas las reservas
-- tienen resena (se promedia solo sobre las que si tienen, gracias a
-- que AVG ignora NULL). HAVING filtra alojamientos cuyo promedio es
-- alto; el ORDER BY deja primero los mejor calificados con menos
-- reservas, que es justo el patron que se queria encontrar.
