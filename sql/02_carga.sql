-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- 02_carga.sql
-- Equipo: Daniela Munoz, Maria Jose Marmolejo, Santiago Ovalle
--
-- Carga de datos. Requiere que 01_ddl.sql ya se haya ejecutado.
-- Ejecutar con F5 (Run Script). Tarda unos minutos por el volumen.
--
-- Version corregida segun la retroalimentacion de la Entrega 1:
--   * Volumen minimo: 60 alojamientos, >= 400 habitaciones, 3.000
--     clientes, 25.500 reservas, >= 25.000 pagos, >= 40.000 lineas de
--     RESERVA_SERVICIO y resenas para mas del 40 % de las completadas.
--   * Temporadas continuas del 1-ene-2024 al 15-ene-2027 (2024, 2025 y
--     2026 completos, cada anio con alta, media y baja).
--   * Reservas repartidas en 2024, 2025 y 2026 con estacionalidad real
--     (mas reservas en temporada alta, crecimiento anual).
--   * SIN SOLAPES: una habitacion nunca queda reservada dos veces en
--     la misma noche, y una reserva no repite habitacion.
--   * Asimetria: Armenia y Salento concentran la demanda; los hoteles
--     tienen 25 a 40 habitaciones y las fincas y glampings 3 a 5.
--   * DBMS_RANDOM.SEED fija la semilla: la carga sale IGUAL en
--     cualquier computador, asi las pruebas dan los mismos numeros.
-- =====================================================================

SET SERVEROUTPUT ON


-- ---------------------------------------------------------------------
-- 1. MUNICIPIO (12 municipios reales del Quindio)
-- ---------------------------------------------------------------------
INSERT INTO municipio (id_municipio, nombre) VALUES (1, 'Armenia');
INSERT INTO municipio (id_municipio, nombre) VALUES (2, 'Calarca');
INSERT INTO municipio (id_municipio, nombre) VALUES (3, 'Montenegro');
INSERT INTO municipio (id_municipio, nombre) VALUES (4, 'Quimbaya');
INSERT INTO municipio (id_municipio, nombre) VALUES (5, 'La Tebaida');
INSERT INTO municipio (id_municipio, nombre) VALUES (6, 'Circasia');
INSERT INTO municipio (id_municipio, nombre) VALUES (7, 'Salento');
INSERT INTO municipio (id_municipio, nombre) VALUES (8, 'Filandia');
INSERT INTO municipio (id_municipio, nombre) VALUES (9, 'Buenavista');
INSERT INTO municipio (id_municipio, nombre) VALUES (10, 'Cordoba');
INSERT INTO municipio (id_municipio, nombre) VALUES (11, 'Pijao');
INSERT INTO municipio (id_municipio, nombre) VALUES (12, 'Genova');

-- ---------------------------------------------------------------------
-- 2. TIPO_ALOJAMIENTO
-- ---------------------------------------------------------------------
INSERT INTO tipo_alojamiento (id_tipo_alojamiento, nombre) VALUES (1, 'Hotel');
INSERT INTO tipo_alojamiento (id_tipo_alojamiento, nombre) VALUES (2, 'Finca cafetera');
INSERT INTO tipo_alojamiento (id_tipo_alojamiento, nombre) VALUES (3, 'Glamping');
INSERT INTO tipo_alojamiento (id_tipo_alojamiento, nombre) VALUES (4, 'Hostal');
INSERT INTO tipo_alojamiento (id_tipo_alojamiento, nombre) VALUES (5, 'Cabanas');

-- ---------------------------------------------------------------------
-- 3. TEMPORADA
-- Se definen por anio (Semana Santa 2024, 2025 y 2026 son temporadas
-- distintas, con fechas distintas). Cubren sin huecos ni cruces desde
-- el 1-ene-2024 hasta el 15-ene-2027, asi toda noche de cualquier
-- estadia cae en exactamente una temporada.
-- Alta: Semana Santa, mitad de anio, puente festivo y diciembre-enero.
-- ---------------------------------------------------------------------
INSERT INTO temporada VALUES (1,  'Baja enero-marzo 2024',        'Baja',  DATE '2024-01-01', DATE '2024-03-23');
INSERT INTO temporada VALUES (2,  'Semana Santa 2024',            'Alta',  DATE '2024-03-24', DATE '2024-03-31');
INSERT INTO temporada VALUES (3,  'Media abril-mayo 2024',        'Media', DATE '2024-04-01', DATE '2024-05-31');
INSERT INTO temporada VALUES (4,  'Mitad de ano 2024',            'Alta',  DATE '2024-06-01', DATE '2024-07-31');
INSERT INTO temporada VALUES (5,  'Media agosto-septiembre 2024', 'Media', DATE '2024-08-01', DATE '2024-09-30');
INSERT INTO temporada VALUES (6,  'Baja octubre-noviembre 2024',  'Baja',  DATE '2024-10-01', DATE '2024-11-30');
INSERT INTO temporada VALUES (7,  'Diciembre-Enero 2024-2025',    'Alta',  DATE '2024-12-01', DATE '2025-01-15');
INSERT INTO temporada VALUES (8,  'Baja enero-abril 2025',        'Baja',  DATE '2025-01-16', DATE '2025-04-12');
INSERT INTO temporada VALUES (9,  'Semana Santa 2025',            'Alta',  DATE '2025-04-13', DATE '2025-04-20');
INSERT INTO temporada VALUES (10, 'Media abril-mayo 2025',        'Media', DATE '2025-04-21', DATE '2025-05-31');
INSERT INTO temporada VALUES (11, 'Mitad de ano 2025',            'Alta',  DATE '2025-06-01', DATE '2025-07-31');
INSERT INTO temporada VALUES (12, 'Media agosto-septiembre 2025', 'Media', DATE '2025-08-01', DATE '2025-09-30');
INSERT INTO temporada VALUES (13, 'Baja octubre-noviembre 2025',  'Baja',  DATE '2025-10-01', DATE '2025-11-30');
INSERT INTO temporada VALUES (14, 'Diciembre-Enero 2025-2026',    'Alta',  DATE '2025-12-01', DATE '2026-01-15');
INSERT INTO temporada VALUES (15, 'Baja enero-marzo 2026',        'Baja',  DATE '2026-01-16', DATE '2026-03-25');
INSERT INTO temporada VALUES (16, 'Semana Santa 2026',            'Alta',  DATE '2026-03-26', DATE '2026-04-05');
INSERT INTO temporada VALUES (17, 'Media abril-mayo 2026',        'Media', DATE '2026-04-06', DATE '2026-05-31');
INSERT INTO temporada VALUES (18, 'Mitad de ano 2026',            'Alta',  DATE '2026-06-01', DATE '2026-07-31');
INSERT INTO temporada VALUES (19, 'Media agosto-octubre 2026',    'Media', DATE '2026-08-01', DATE '2026-10-10');
INSERT INTO temporada VALUES (20, 'Puente festivo octubre 2026',  'Alta',  DATE '2026-10-11', DATE '2026-10-13');
INSERT INTO temporada VALUES (21, 'Baja octubre-noviembre 2026',  'Baja',  DATE '2026-10-14', DATE '2026-11-30');
INSERT INTO temporada VALUES (22, 'Diciembre-Enero 2026-2027',    'Alta',  DATE '2026-12-01', DATE '2027-01-15');

COMMIT;

-- ---------------------------------------------------------------------
-- 4. ALOJAMIENTO + HABITACION + TARIFA
-- 60 alojamientos repartidos de forma desigual: Armenia (capital) y
-- los municipios turisticos (Salento, Filandia) concentran la oferta;
-- Buenavista, Cordoba, Pijao y Genova tienen 2 cada uno.
-- El tipo rota Hotel, Finca, Glamping, Hostal, Cabanas (12 de cada uno)
-- y el numero de habitaciones depende del tipo:
--   Hotel 25-40, Hostal 8-15, Cabanas 4-8, Finca y Glamping 3-5.
-- TARIFA: una por cada habitacion x temporada (22 por habitacion). El
-- precio sale de un precio base por tipo de habitacion, un factor por
-- tipo de temporada y un alza de 6 % por anio. Cada alojamiento sube
-- distinto en temporada alta (factor aleatorio), no es un % fijo.
-- ---------------------------------------------------------------------
DECLARE
    TYPE t_num_tab IS TABLE OF NUMBER;
    TYPE t_temp_tab IS TABLE OF temporada%ROWTYPE;
    v_por_municipio t_num_tab := t_num_tab(13, 6, 5, 4, 3, 3, 10, 8, 2, 2, 2, 2);
    v_temps         t_temp_tab;
    v_id_aloj       NUMBER := 1;
    v_id_hab        NUMBER := 1;
    v_id_tarifa     NUMBER := 1;
    v_tipo          NUMBER;
    v_num_hab       NUMBER;
    v_r             NUMBER;
    v_tipo_hab      VARCHAR2(20);
    v_cap           NUMBER;
    v_base          NUMBER;
    v_mult          NUMBER;
    v_municipio     municipio.nombre%TYPE;
    v_prefijo       VARCHAR2(20);
    v_id_temp       NUMBER;
BEGIN
    DBMS_RANDOM.SEED(20261);
    SELECT * BULK COLLECT INTO v_temps FROM temporada ORDER BY id_temporada;
--
    FOR m IN 1 .. 12 LOOP
        SELECT nombre INTO v_municipio FROM municipio WHERE id_municipio = m;
        FOR a IN 1 .. v_por_municipio(m) LOOP
            v_tipo := MOD(v_id_aloj - 1, 5) + 1;
            v_prefijo := CASE v_tipo WHEN 1 THEN 'Hotel' WHEN 2 THEN 'Finca'
                                     WHEN 3 THEN 'Glamping' WHEN 4 THEN 'Hostal'
                                     ELSE 'Cabanas' END;
--
            INSERT INTO alojamiento (id_alojamiento, nombre_comercial, direccion,
                                     calificacion_estrellas, telefono_contacto,
                                     correo_contacto, id_municipio, id_tipo_alojamiento)
            VALUES (v_id_aloj,
                    v_prefijo || ' ' || v_municipio || ' ' || v_id_aloj,
                    'Vereda/Calle ' || TRUNC(DBMS_RANDOM.VALUE(1, 99)) || ', ' || v_municipio,
                    TRUNC(DBMS_RANDOM.VALUE(2, 6)),
                    '300' || TRUNC(DBMS_RANDOM.VALUE(1000000, 9999999)),
                    'contacto' || v_id_aloj || '@turismouq.co',
                    m, v_tipo);
--
            v_num_hab := CASE v_tipo
                             WHEN 1 THEN TRUNC(DBMS_RANDOM.VALUE(25, 41))
                             WHEN 4 THEN TRUNC(DBMS_RANDOM.VALUE(8, 16))
                             WHEN 5 THEN TRUNC(DBMS_RANDOM.VALUE(4, 9))
                             ELSE        TRUNC(DBMS_RANDOM.VALUE(3, 6))
                         END;
--
            FOR h IN 1 .. v_num_hab LOOP
                v_r := TRUNC(DBMS_RANDOM.VALUE(1, 4));
                v_tipo_hab := CASE v_tipo
                    WHEN 1 THEN CASE v_r WHEN 1 THEN 'Sencilla' WHEN 2 THEN 'Doble' ELSE 'Suite' END
                    WHEN 2 THEN CASE v_r WHEN 1 THEN 'Doble' WHEN 2 THEN 'Suite' ELSE 'Cabana' END
                    WHEN 3 THEN CASE v_r WHEN 3 THEN 'Cabana' ELSE 'Doble' END
                    WHEN 4 THEN CASE v_r WHEN 1 THEN 'Sencilla' ELSE 'Doble' END
                    ELSE 'Cabana'
                END;
                v_cap := CASE v_tipo_hab
                             WHEN 'Sencilla' THEN TRUNC(DBMS_RANDOM.VALUE(1, 3))
                             WHEN 'Doble'    THEN TRUNC(DBMS_RANDOM.VALUE(2, 4))
                             WHEN 'Suite'    THEN TRUNC(DBMS_RANDOM.VALUE(2, 5))
                             ELSE                 TRUNC(DBMS_RANDOM.VALUE(4, 9))
                         END;
--
                INSERT INTO habitacion (id_habitacion, numero, capacidad_maxima, tipo,
                                        descripcion, id_alojamiento)
                VALUES (v_id_hab, TO_CHAR(h), v_cap, v_tipo_hab,
                        'Habitacion tipo ' || v_tipo_hab || ' para ' || v_cap || ' personas',
                        v_id_aloj);
--
                v_base := CASE v_tipo_hab WHEN 'Sencilla' THEN 80000 WHEN 'Doble' THEN 130000
                                          WHEN 'Suite' THEN 220000 ELSE 300000 END
                          * CASE v_tipo WHEN 1 THEN 1.3 WHEN 3 THEN 1.2 WHEN 4 THEN 0.6 ELSE 1 END;
--
                FOR t IN 1 .. v_temps.COUNT LOOP
                    v_mult := CASE v_temps(t).tipo
                                  WHEN 'Alta'  THEN DBMS_RANDOM.VALUE(1.3, 1.9)
                                  WHEN 'Media' THEN DBMS_RANDOM.VALUE(1.0, 1.3)
                                  ELSE              DBMS_RANDOM.VALUE(0.7, 1.0)
                              END
                              * (1 + 0.06 * (EXTRACT(YEAR FROM v_temps(t).fecha_inicio) - 2024));
                    v_id_temp := v_temps(t).id_temporada;
                    INSERT INTO tarifa (id_tarifa, precio_noche, id_habitacion, id_temporada)
                    VALUES (v_id_tarifa, ROUND(v_base * v_mult, -3), v_id_hab, v_id_temp);
                    v_id_tarifa := v_id_tarifa + 1;
                END LOOP;
--
                v_id_hab := v_id_hab + 1;
            END LOOP;
--
            v_id_aloj := v_id_aloj + 1;
        END LOOP;
    END LOOP;
    COMMIT;
END;
/

-- ---------------------------------------------------------------------
-- 5. CLIENTE (3.000 clientes, ciudades de origen variadas)
-- ---------------------------------------------------------------------
DECLARE
    TYPE t_str_tab IS TABLE OF VARCHAR2(40);
    v_nombres   t_str_tab := t_str_tab('Juan','Maria','Carlos','Laura','Andres','Camila','Felipe',
                                       'Valentina','Diego','Isabella','Santiago','Daniela','Julian',
                                       'Natalia','Mateo','Paola','Ricardo','Simon','Sara','Alejandro');
    v_apellidos t_str_tab := t_str_tab('Gomez','Rodriguez','Martinez','Lopez','Garcia','Hernandez',
                                       'Perez','Sanchez','Ramirez','Torres','Flores','Rivera','Castro',
                                       'Ortiz','Reyes');
    v_ciudades  t_str_tab := t_str_tab('Bogota','Bogota','Bogota','Medellin','Medellin','Cali','Cali',
                                       'Pereira','Pereira','Manizales','Armenia','Ibague','Barranquilla',
                                       'Bucaramanga','Cartagena','Cucuta','Pasto','Neiva','Villavicencio',
                                       'Madrid','Nueva York','Ciudad de Mexico','Buenos Aires','Lima');
    v_nombre    VARCHAR2(120);
    v_ciudad    VARCHAR2(60);
BEGIN
    DBMS_RANDOM.SEED(20262);
    FOR i IN 1 .. 3000 LOOP
        v_nombre := v_nombres(TRUNC(DBMS_RANDOM.VALUE(1, v_nombres.COUNT + 1))) || ' '
                    || v_apellidos(TRUNC(DBMS_RANDOM.VALUE(1, v_apellidos.COUNT + 1)));
        v_ciudad := v_ciudades(TRUNC(DBMS_RANDOM.VALUE(1, v_ciudades.COUNT + 1)));
        INSERT INTO cliente (id_cliente, nombre, documento_identidad, correo, telefono, ciudad_origen)
        VALUES (i, v_nombre, TO_CHAR(1000000000 + i), 'cliente' || i || '@correo.com',
                '3' || TRUNC(DBMS_RANDOM.VALUE(100000000, 299999999)), v_ciudad);
    END LOOP;
    COMMIT;
END;
/

-- ---------------------------------------------------------------------
-- 6. SERVICIO (2 a 5 por alojamiento, sin nombres repetidos dentro del
-- mismo alojamiento; el desayuno de un hotel es distinto del de otro)
-- ---------------------------------------------------------------------
DECLARE
    TYPE t_str_tab IS TABLE OF VARCHAR2(60);
    TYPE t_num_tab IS TABLE OF NUMBER;
    v_nombres t_str_tab := t_str_tab('Desayuno incluido', 'Tour guiado cafetero',
                                     'Transporte al aeropuerto', 'Alquiler de bicicletas',
                                     'Spa y masajes', 'Cabalgata', 'Noche de fogata',
                                     'Decoracion especial');
    v_min     t_num_tab := t_num_tab(18000, 60000, 50000, 25000, 90000, 70000, 30000, 40000);
    v_max     t_num_tab := t_num_tab(35000, 120000, 90000, 45000, 180000, 110000, 50000, 80000);
    v_id      NUMBER := 1;
    v_num     NUMBER;
    v_ini     NUMBER;
    v_k       NUMBER;
    v_nombre  VARCHAR2(60);
    v_precio  NUMBER;
BEGIN
    DBMS_RANDOM.SEED(20263);
    FOR al IN (SELECT id_alojamiento FROM alojamiento ORDER BY id_alojamiento) LOOP
        v_num := TRUNC(DBMS_RANDOM.VALUE(2, 6));
        v_ini := TRUNC(DBMS_RANDOM.VALUE(0, 8));
        FOR s IN 0 .. v_num - 1 LOOP
            v_k := MOD(v_ini + s, 8) + 1;
            v_nombre := v_nombres(v_k);
            v_precio := ROUND(DBMS_RANDOM.VALUE(v_min(v_k), v_max(v_k)), -3);
            INSERT INTO servicio (id_servicio, nombre, descripcion, precio, id_alojamiento)
            VALUES (v_id, v_nombre, 'Servicio complementario ofrecido por el alojamiento.',
                    v_precio, al.id_alojamiento);
            v_id := v_id + 1;
        END LOOP;
    END LOOP;
    COMMIT;
END;
/

-- ---------------------------------------------------------------------
-- 7. RESERVA + RESERVA_HABITACION + RESERVA_SERVICIO + PAGO + RESENA
--
-- * Fecha de entrada: 2024 (25 %), 2025 (33 %), 2026 (42 %), y dentro
--   de cada anio se acepta un dia con probabilidad 1 si es temporada
--   alta, 0,45 si es media y 0,2 si es baja (estacionalidad real).
--   Ultima salida posible: 31-dic-2026.
-- * Alojamiento: 30 % de la demanda va a Armenia, 20 % a Salento y el
--   resto a cualquier alojamiento. Se sortea una HABITACION del grupo y
--   se toma su alojamiento, asi un hotel de 40 habitaciones recibe mas
--   reservas que una finca de 3.
-- * Disponibilidad: se lleva en memoria un mapa (habitacion, noche).
--   Solo se asignan habitaciones libres en todas las noches, de modo
--   que NO quedan solapes. Si el alojamiento esta lleno en esas
--   fechas, se sortea otra reserva.
-- * 75 % de reservas con 1 habitacion, 17 % con 2 y 8 % con 3. En
--   reservas de grupo, a veces una linea llega un dia despues (fechas
--   distintas dentro del rango general, seccion 1.3).
-- * Estado segun la fecha de corte 15-oct-2026: lo ya vivido queda
--   Completada (85 %) o Cancelada (15 %); lo futuro Confirmada (60 %),
--   Pendiente (30 %) o Cancelada (10 %); lo que esta en curso,
--   Confirmada.
-- * Valor de cada linea: noche por noche con la tarifa de su temporada.
-- * Servicios: 85 % de las reservas, de 1 a 4 servicios distintos del
--   mismo alojamiento, cantidad 1 a 3.
-- * Pagos: anticipo 40 % + saldo 60 %, o pago unico; saldo futuro queda
--   Pendiente; algunos intentos Fallido; cancelada con mas de 5 dias
--   de anticipacion recibe reembolso del 80 % (regla de cancelacion).
-- * Resena: 60 % de las completadas, calificaciones de 1 a 5.
-- ---------------------------------------------------------------------
DECLARE
    TYPE t_num_idx IS TABLE OF NUMBER       INDEX BY PLS_INTEGER;
    TYPE t_vc_idx  IS TABLE OF VARCHAR2(10) INDEX BY PLS_INTEGER;
    TYPE t_str_tab IS TABLE OF VARCHAR2(20);
--
    c_base    CONSTANT DATE := DATE '2024-01-01';
    c_fin     CONSTANT DATE := DATE '2026-12-31';
    c_hoy     CONSTANT DATE := DATE '2026-10-15';
    c_total   CONSTANT PLS_INTEGER := 25500;
--
    g_ocup        t_num_idx;   -- clave (habitacion, noche) -> ocupada
    g_hab_ini     t_num_idx;   -- primera habitacion de cada alojamiento
    g_hab_fin     t_num_idx;   -- ultima habitacion de cada alojamiento
    g_aloj_de_hab t_num_idx;   -- alojamiento de cada habitacion
    g_cap         t_num_idx;   -- capacidad de cada habitacion
    g_srv_ini     t_num_idx;   -- primer servicio de cada alojamiento
    g_srv_fin     t_num_idx;   -- ultimo servicio de cada alojamiento
    g_srv_precio  t_num_idx;   -- precio de cada servicio
    g_tipo_dia    t_vc_idx;    -- tipo de temporada de cada dia
    g_habs        t_num_idx;   -- habitaciones asignadas a la reserva actual
--
    v_metodos     t_str_tab := t_str_tab('Tarjeta credito', 'Tarjeta debito', 'PSE',
                                         'Transferencia', 'Efectivo');
    v_comentarios t_str_tab := t_str_tab('Excelente', 'Muy buena', 'Buena', 'Regular', 'Mala');
--
    v_max_hab   NUMBER;
    v_id_res    NUMBER := 0;
    v_id_rh     NUMBER := 0;
    v_id_rs     NUMBER := 0;
    v_id_pago   NUMBER := 0;
    v_id_resena NUMBER := 0;
    v_intentos  NUMBER := 0;
    v_in        DATE;
    v_out       DATE;
    v_lin_in    DATE;
    v_h0        NUMBER;
    v_aloj      NUMBER;
    v_hab       NUMBER;
    v_n         NUMBER;
    v_quiere    NUMBER;
    v_nhabs     NUMBER;
    v_r         NUMBER;
    v_acepta    NUMBER;
    v_estado    VARCHAR2(15);
    v_val_lin   NUMBER;
    v_val_hab   NUMBER;
    v_val_serv  NUMBER;
    v_total     NUMBER;
    v_cant      NUMBER;
    v_srv       NUMBER;
    v_nsrv      NUMBER;
    v_ksrv      NUMBER;
    v_off       NUMBER;
    v_anticipo  NUMBER;
    v_cal       NUMBER;
    v_met       VARCHAR2(20);
    v_cliente   NUMBER;
    v_huesp     NUMBER;
    v_coment    VARCHAR2(60);
--
    FUNCTION clave (p_hab NUMBER, p_dia DATE) RETURN PLS_INTEGER IS
    BEGIN
        RETURN p_hab * 2000 + (p_dia - c_base);
    END;
--
    FUNCTION libre (p_hab NUMBER, p_in DATE, p_out DATE) RETURN BOOLEAN IS
    BEGIN
        FOR d IN 0 .. (p_out - p_in) - 1 LOOP
            IF g_ocup.EXISTS(clave(p_hab, p_in + d)) THEN
                RETURN FALSE;
            END IF;
        END LOOP;
        RETURN TRUE;
    END;
--
    PROCEDURE ocupar (p_hab NUMBER, p_in DATE, p_out DATE) IS
    BEGIN
        FOR d IN 0 .. (p_out - p_in) - 1 LOOP
            g_ocup(clave(p_hab, p_in + d)) := 1;
        END LOOP;
    END;
--
BEGIN
    DBMS_RANDOM.SEED(20264);
--
    -- datos de apoyo en memoria
    SELECT MAX(id_habitacion) INTO v_max_hab FROM habitacion;
    FOR h IN (SELECT id_habitacion, id_alojamiento, capacidad_maxima FROM habitacion) LOOP
        g_aloj_de_hab(h.id_habitacion) := h.id_alojamiento;
        g_cap(h.id_habitacion)         := h.capacidad_maxima;
    END LOOP;
    FOR a IN (SELECT id_alojamiento, MIN(id_habitacion) AS ini, MAX(id_habitacion) AS fin
                FROM habitacion GROUP BY id_alojamiento) LOOP
        g_hab_ini(a.id_alojamiento) := a.ini;
        g_hab_fin(a.id_alojamiento) := a.fin;
    END LOOP;
    FOR s IN (SELECT id_alojamiento, MIN(id_servicio) AS ini, MAX(id_servicio) AS fin
                FROM servicio GROUP BY id_alojamiento) LOOP
        g_srv_ini(s.id_alojamiento) := s.ini;
        g_srv_fin(s.id_alojamiento) := s.fin;
    END LOOP;
    FOR s IN (SELECT id_servicio, precio FROM servicio) LOOP
        g_srv_precio(s.id_servicio) := s.precio;
    END LOOP;
    FOR t IN (SELECT tipo, fecha_inicio, fecha_fin FROM temporada) LOOP
        FOR d IN 0 .. t.fecha_fin - t.fecha_inicio LOOP
            IF t.fecha_inicio + d BETWEEN c_base AND c_fin THEN
                g_tipo_dia(t.fecha_inicio + d - c_base) := t.tipo;
            END IF;
        END LOOP;
    END LOOP;
--
    WHILE v_id_res < c_total LOOP
        v_intentos := v_intentos + 1;
        IF v_intentos > 1000000 THEN
            RAISE_APPLICATION_ERROR(-20900, 'La carga no encontro habitaciones libres');
        END IF;
--
        -- 1) fecha de entrada con estacionalidad
        LOOP
            v_r := DBMS_RANDOM.VALUE(0, 1);
            IF v_r < 0.25 THEN
                v_in := DATE '2024-01-01' + TRUNC(DBMS_RANDOM.VALUE(0, 366));
            ELSIF v_r < 0.58 THEN
                v_in := DATE '2025-01-01' + TRUNC(DBMS_RANDOM.VALUE(0, 365));
            ELSE
                v_in := DATE '2026-01-01' + TRUNC(DBMS_RANDOM.VALUE(0, 358));
            END IF;
            v_acepta := CASE g_tipo_dia(v_in - c_base)
                            WHEN 'Alta' THEN 1 WHEN 'Media' THEN 0.45 ELSE 0.2 END;
            EXIT WHEN DBMS_RANDOM.VALUE(0, 1) < v_acepta;
        END LOOP;
        v_out := LEAST(v_in + TRUNC(DBMS_RANDOM.VALUE(1, 8)), c_fin);
--
        -- 2) alojamiento: se sortea una habitacion del grupo de demanda
        v_r := DBMS_RANDOM.VALUE(0, 1);
        IF v_r < 0.30 THEN
            v_h0 := TRUNC(DBMS_RANDOM.VALUE(g_hab_ini(1), g_hab_fin(13) + 1));    -- Armenia
        ELSIF v_r < 0.50 THEN
            v_h0 := TRUNC(DBMS_RANDOM.VALUE(g_hab_ini(35), g_hab_fin(44) + 1));   -- Salento
        ELSE
            v_h0 := TRUNC(DBMS_RANDOM.VALUE(1, v_max_hab + 1));
        END IF;
        v_aloj := g_aloj_de_hab(v_h0);
--
        -- 3) habitaciones libres del alojamiento en esas fechas
        v_r := DBMS_RANDOM.VALUE(0, 1);
        v_quiere := CASE WHEN v_r < 0.75 THEN 1 WHEN v_r < 0.92 THEN 2 ELSE 3 END;
        v_n := g_hab_fin(v_aloj) - g_hab_ini(v_aloj) + 1;
        v_nhabs := 0;
        g_habs.DELETE;
        FOR i IN 0 .. v_n - 1 LOOP
            EXIT WHEN v_nhabs = v_quiere;
            v_hab := g_hab_ini(v_aloj) + MOD(v_h0 - g_hab_ini(v_aloj) + i, v_n);
            IF libre(v_hab, v_in, v_out) THEN
                v_nhabs := v_nhabs + 1;
                g_habs(v_nhabs) := v_hab;
                ocupar(v_hab, v_in, v_out);
            END IF;
        END LOOP;
--
        IF v_nhabs > 0 THEN
            -- 4) estado segun la fecha de corte
            v_r := DBMS_RANDOM.VALUE(0, 1);
            IF v_out <= c_hoy THEN
                v_estado := CASE WHEN v_r < 0.85 THEN 'Completada' ELSE 'Cancelada' END;
            ELSIF v_in <= c_hoy THEN
                v_estado := 'Confirmada';
            ELSE
                v_estado := CASE WHEN v_r < 0.60 THEN 'Confirmada'
                                 WHEN v_r < 0.90 THEN 'Pendiente'
                                 ELSE 'Cancelada' END;
            END IF;
--
            v_cliente := TRUNC(DBMS_RANDOM.VALUE(1, 3001));
            v_id_res := v_id_res + 1;
            INSERT INTO reserva (id_reserva, fecha_checkin, fecha_checkout, estado,
                                 id_cliente, id_alojamiento)
            VALUES (v_id_res, v_in, v_out, v_estado, v_cliente, v_aloj);
--
            -- 5) lineas de habitacion, valoradas noche por noche
            v_val_hab := 0;
            FOR j IN 1 .. v_nhabs LOOP
                v_hab := g_habs(j);
                v_lin_in := v_in;
                IF j > 1 AND v_out - v_in > 1 AND DBMS_RANDOM.VALUE(0, 1) < 0.2 THEN
                    v_lin_in := v_in + 1;   -- esta persona del grupo llega un dia despues
                END IF;
--
                v_huesp := TRUNC(DBMS_RANDOM.VALUE(1, g_cap(v_hab) + 1));
                v_id_rh := v_id_rh + 1;
                INSERT INTO reserva_habitacion (id_reserva_habitacion, fecha_checkin,
                                                fecha_checkout, cantidad_huespedes,
                                                id_reserva, id_habitacion)
                VALUES (v_id_rh, v_lin_in, v_out,
                        v_huesp, v_id_res, v_hab);
--
                SELECT NVL(SUM(t.precio_noche), 0) INTO v_val_lin
                  FROM (SELECT v_lin_in + LEVEL - 1 AS noche
                          FROM dual CONNECT BY LEVEL <= v_out - v_lin_in) n
                  JOIN temporada te ON n.noche BETWEEN te.fecha_inicio AND te.fecha_fin
                  JOIN tarifa t     ON t.id_temporada = te.id_temporada
                                   AND t.id_habitacion = v_hab;
                v_val_hab := v_val_hab + v_val_lin;
            END LOOP;
--
            -- 6) servicios (distintos, del mismo alojamiento)
            v_val_serv := 0;
            IF DBMS_RANDOM.VALUE(0, 1) < 0.85 THEN
                v_nsrv := g_srv_fin(v_aloj) - g_srv_ini(v_aloj) + 1;
                v_ksrv := TRUNC(DBMS_RANDOM.VALUE(1, LEAST(4, v_nsrv) + 1));
                v_off  := TRUNC(DBMS_RANDOM.VALUE(0, v_nsrv));
                FOR s IN 0 .. v_ksrv - 1 LOOP
                    v_srv  := g_srv_ini(v_aloj) + MOD(v_off + s, v_nsrv);
                    v_cant := TRUNC(DBMS_RANDOM.VALUE(1, 4));
                    v_id_rs := v_id_rs + 1;
                    INSERT INTO reserva_servicio (id_reserva_servicio, cantidad, id_reserva, id_servicio)
                    VALUES (v_id_rs, v_cant, v_id_res, v_srv);
                    v_val_serv := v_val_serv + v_cant * g_srv_precio(v_srv);
                END LOOP;
            END IF;
--
            -- 7) pagos
            v_total    := v_val_hab + v_val_serv;
            v_anticipo := ROUND(v_total * 0.4);
            IF v_estado IN ('Completada', 'Confirmada') THEN
                IF DBMS_RANDOM.VALUE(0, 1) < 0.05 THEN
                    -- intento fallido previo
                    v_id_pago := v_id_pago + 1;
                    v_met := v_metodos(TRUNC(DBMS_RANDOM.VALUE(1, 6)));
                    INSERT INTO pago (id_pago, fecha_pago, monto, metodo, estado, id_reserva)
                    VALUES (v_id_pago, v_in - 12, v_anticipo, v_met, 'Fallido', v_id_res);
                END IF;
                IF DBMS_RANDOM.VALUE(0, 1) < 0.35 THEN
                    v_id_pago := v_id_pago + 1;
                    v_met := v_metodos(TRUNC(DBMS_RANDOM.VALUE(1, 6)));
                    INSERT INTO pago (id_pago, fecha_pago, monto, metodo, estado, id_reserva)
                    VALUES (v_id_pago, v_in - TRUNC(DBMS_RANDOM.VALUE(5, 31)), v_anticipo,
                            v_met, 'Exitoso', v_id_res);
                    v_id_pago := v_id_pago + 1;
                    v_met := v_metodos(TRUNC(DBMS_RANDOM.VALUE(1, 6)));
                    INSERT INTO pago (id_pago, fecha_pago, monto, metodo, estado, id_reserva)
                    VALUES (v_id_pago, v_in, v_total - v_anticipo, v_met,
                            CASE WHEN v_in > c_hoy THEN 'Pendiente' ELSE 'Exitoso' END, v_id_res);
                ELSE
                    v_id_pago := v_id_pago + 1;
                    v_met := v_metodos(TRUNC(DBMS_RANDOM.VALUE(1, 6)));
                    INSERT INTO pago (id_pago, fecha_pago, monto, metodo, estado, id_reserva)
                    VALUES (v_id_pago, v_in - TRUNC(DBMS_RANDOM.VALUE(0, 21)), v_total,
                            v_met, 'Exitoso', v_id_res);
                END IF;
            ELSIF v_estado = 'Pendiente' THEN
                IF DBMS_RANDOM.VALUE(0, 1) < 0.5 THEN
                    v_id_pago := v_id_pago + 1;
                    v_met := v_metodos(TRUNC(DBMS_RANDOM.VALUE(1, 6)));
                    INSERT INTO pago (id_pago, fecha_pago, monto, metodo, estado, id_reserva)
                    VALUES (v_id_pago, LEAST(v_in - 5, c_hoy), v_anticipo, v_met, 'Pendiente', v_id_res);
                END IF;
            ELSE  -- Cancelada: pago el anticipo; si cancelo con mas de 5 dias, reembolso del 80 %
                v_id_pago := v_id_pago + 1;
                v_met := v_metodos(TRUNC(DBMS_RANDOM.VALUE(1, 6)));
                INSERT INTO pago (id_pago, fecha_pago, monto, metodo, estado, id_reserva)
                VALUES (v_id_pago, v_in - TRUNC(DBMS_RANDOM.VALUE(10, 31)), v_anticipo,
                        v_met, 'Exitoso', v_id_res);
                IF DBMS_RANDOM.VALUE(0, 1) < 0.7 THEN
                    v_id_pago := v_id_pago + 1;
                    v_met := v_metodos(TRUNC(DBMS_RANDOM.VALUE(1, 6)));
                    INSERT INTO pago (id_pago, fecha_pago, monto, metodo, estado, id_reserva)
                    VALUES (v_id_pago, v_in - TRUNC(DBMS_RANDOM.VALUE(6, 10)), ROUND(v_anticipo * 0.8),
                            'Transferencia', 'Reembolsado', v_id_res);
                END IF;
            END IF;
--
            -- 8) resena (solo completadas)
            IF v_estado = 'Completada' AND DBMS_RANDOM.VALUE(0, 1) < 0.60 THEN
                v_r := DBMS_RANDOM.VALUE(0, 1);
                v_cal := CASE WHEN v_r < 0.35 THEN 5 WHEN v_r < 0.65 THEN 4
                              WHEN v_r < 0.83 THEN 3 WHEN v_r < 0.93 THEN 2 ELSE 1 END;
                v_coment := v_comentarios(6 - v_cal) || ' estadia.';
                v_id_resena := v_id_resena + 1;
                INSERT INTO resena (id_resena, calificacion, comentario, fecha_resena, id_reserva)
                VALUES (v_id_resena, v_cal, v_coment,
                        v_out + TRUNC(DBMS_RANDOM.VALUE(1, 15)), v_id_res);
            END IF;
        END IF;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Reservas: ' || v_id_res || ' | lineas: ' || v_id_rh
        || ' | servicios: ' || v_id_rs || ' | pagos: ' || v_id_pago
        || ' | resenas: ' || v_id_resena || ' | intentos: ' || v_intentos);
END;
/

-- ---------------------------------------------------------------------
-- 8. USUARIO_SISTEMA
-- 3 administradores (globales, sin alojamiento) + 1 encargado por
-- cada alojamiento (coherente con el CHECK de la tabla). Hay
-- encargados de los 5 tipos de alojamiento.
-- ---------------------------------------------------------------------
DECLARE
    v_id NUMBER := 1;
BEGIN
    FOR i IN 1 .. 3 LOOP
        INSERT INTO usuario_sistema (id_usuario, nombre, nombre_usuario, correo, rol, id_alojamiento)
        VALUES (v_id, 'Administrador ' || i, 'admin' || i, 'admin' || i || '@turismouq.co',
                'Administrador', NULL);
        v_id := v_id + 1;
    END LOOP;
--
    FOR al IN (SELECT id_alojamiento FROM alojamiento ORDER BY id_alojamiento) LOOP
        INSERT INTO usuario_sistema (id_usuario, nombre, nombre_usuario, correo, rol, id_alojamiento)
        VALUES (v_id, 'Encargado alojamiento ' || al.id_alojamiento,
                'encargado' || al.id_alojamiento,
                'encargado' || al.id_alojamiento || '@turismouq.co',
                'Encargado', al.id_alojamiento);
        v_id := v_id + 1;
    END LOOP;
    COMMIT;
END;
/

-- ---------------------------------------------------------------------
-- VERIFICACION
-- ---------------------------------------------------------------------

-- Volumen por tabla frente al minimo del enunciado
SELECT 'municipio' AS tabla, COUNT(*) AS filas, 12 AS minimo FROM municipio
UNION ALL SELECT 'tipo_alojamiento',   COUNT(*), 4     FROM tipo_alojamiento
UNION ALL SELECT 'alojamiento',        COUNT(*), 60    FROM alojamiento
UNION ALL SELECT 'habitacion',         COUNT(*), 400   FROM habitacion
UNION ALL SELECT 'temporada',          COUNT(*), 6     FROM temporada
UNION ALL SELECT 'tarifa',             COUNT(*), NULL  FROM tarifa
UNION ALL SELECT 'cliente',            COUNT(*), 3000  FROM cliente
UNION ALL SELECT 'reserva',            COUNT(*), 25000 FROM reserva
UNION ALL SELECT 'reserva_habitacion', COUNT(*), 25000 FROM reserva_habitacion
UNION ALL SELECT 'pago',               COUNT(*), 25000 FROM pago
UNION ALL SELECT 'servicio',           COUNT(*), 30    FROM servicio
UNION ALL SELECT 'reserva_servicio',   COUNT(*), 40000 FROM reserva_servicio
UNION ALL SELECT 'resena',             COUNT(*), NULL  FROM resena
UNION ALL SELECT 'usuario_sistema',    COUNT(*), 10    FROM usuario_sistema;

-- Resenas sobre reservas completadas (debe ser >= 40 %)
SELECT ROUND(100 * (SELECT COUNT(*) FROM resena)
             / (SELECT COUNT(*) FROM reserva WHERE estado = 'Completada'), 1) AS pct_resenas
  FROM dual;

-- Solapes: debe dar 0
SELECT COUNT(*) AS pares_solapados
  FROM reserva_habitacion a
  JOIN reserva_habitacion b
    ON b.id_habitacion = a.id_habitacion
   AND b.id_reserva_habitacion > a.id_reserva_habitacion
   AND a.fecha_checkin  < b.fecha_checkout
   AND a.fecha_checkout > b.fecha_checkin;

-- Reservas por anio y estado (2024, 2025 y 2026)
SELECT EXTRACT(YEAR FROM fecha_checkin) AS anio, estado, COUNT(*) AS reservas
  FROM reserva
 GROUP BY EXTRACT(YEAR FROM fecha_checkin), estado
 ORDER BY anio, estado;

-- Asimetria por municipio
SELECT mu.nombre AS municipio, COUNT(DISTINCT al.id_alojamiento) AS alojamientos,
       COUNT(r.id_reserva) AS reservas
  FROM municipio mu
  JOIN alojamiento al ON al.id_municipio = mu.id_municipio
  LEFT JOIN reserva r ON r.id_alojamiento = al.id_alojamiento
 GROUP BY mu.nombre
 ORDER BY reservas DESC;
