-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- 02_carga_turismouq.sql
-- Carga de datos. Los catalogos (municipio, tipo_alojamiento,
-- temporada, cliente) se insertan con INSERT directo porque son
-- datos reales/fijos. Alojamiento, habitacion, tarifa, reserva y
-- sus tablas relacionadas se generan con PL/SQL + DBMS_RANDOM para
-- lograr el volumen minimo y, sobre todo, la ASIMETRIA que pide el
-- enunciado: no todos los municipios ni todos los meses tienen la
-- misma cantidad de actividad.
--
-- Requiere que 01_ddl_turismouq.sql ya se haya ejecutado.
-- =====================================================================

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
-- Cubren de forma continua desde dic-2025 hasta ene-2027, sin huecos,
-- para que cualquier estadia dentro de 2026 caiga en alguna temporada.
-- ---------------------------------------------------------------------
INSERT INTO temporada VALUES (1, 'Diciembre-Enero 2025-2026', 'Alta',  DATE '2025-12-01', DATE '2026-01-15');
INSERT INTO temporada VALUES (2, 'Baja enero-marzo 2026',     'Baja',  DATE '2026-01-16', DATE '2026-03-25');
INSERT INTO temporada VALUES (3, 'Semana Santa 2026',         'Alta',  DATE '2026-03-26', DATE '2026-04-05');
INSERT INTO temporada VALUES (4, 'Media abril-mayo 2026',     'Media', DATE '2026-04-06', DATE '2026-05-31');
INSERT INTO temporada VALUES (5, 'Mitad de ano 2026',         'Alta',  DATE '2026-06-01', DATE '2026-07-31');
INSERT INTO temporada VALUES (6, 'Media agosto-octubre 2026', 'Media', DATE '2026-08-01', DATE '2026-10-10');
INSERT INTO temporada VALUES (7, 'Puente festivo octubre 2026','Alta', DATE '2026-10-11', DATE '2026-10-13');
INSERT INTO temporada VALUES (8, 'Baja octubre-noviembre 2026','Baja', DATE '2026-10-14', DATE '2026-11-30');
INSERT INTO temporada VALUES (9, 'Diciembre-Enero 2026-2027', 'Alta',  DATE '2026-12-01', DATE '2027-01-15');

COMMIT;

-- ---------------------------------------------------------------------
-- 4. ALOJAMIENTO + HABITACION + TARIFA (PL/SQL, generado)
-- Asimetria por municipio: Armenia (capital) y los municipios
-- turisticos (Salento, Filandia) concentran mas alojamientos;
-- municipios pequenos (Buenavista, Genova, Pijao) tienen pocos.
-- ---------------------------------------------------------------------
DECLARE
    -- cantidad de alojamientos por municipio (1..12), a proposito
    -- asimetrica: Armenia=10, Salento=8, Filandia=6, resto variable
    TYPE t_num_tab IS TABLE OF NUMBER;
    v_alojam_por_municipio t_num_tab := t_num_tab(10, 5, 4, 3, 2, 2, 8, 6, 1, 2, 2, 1);

    v_id_alojamiento   NUMBER := 1;
    v_id_habitacion    NUMBER := 1;
    v_id_tarifa        NUMBER := 1;
    v_tipo_alojam      NUMBER;
    v_num_habitaciones NUMBER;
    v_base_precio      NUMBER;
    v_mult_temporada   NUMBER;

    v_nombres_finca  t_num_tab;
BEGIN
    FOR m IN 1 .. 12 LOOP
        FOR a IN 1 .. v_alojam_por_municipio(m) LOOP

            -- tipo de alojamiento aleatorio (mas probabilidad de
            -- finca cafetera en municipios pequenos/rurales)
            v_tipo_alojam := TRUNC(DBMS_RANDOM.VALUE(1, 6));

            INSERT INTO alojamiento (
                id_alojamiento, nombre_comercial, direccion,
                calificacion_estrellas, telefono_contacto, correo_contacto,
                id_municipio, id_tipo_alojamiento
            ) VALUES (
                v_id_alojamiento,
                'Alojamiento ' || v_id_alojamiento,
                'Vereda/Calle ' || TRUNC(DBMS_RANDOM.VALUE(1, 99)) || ', municipio ' || m,
                TRUNC(DBMS_RANDOM.VALUE(2, 6)),               -- 2 a 5 estrellas
                '300' || TRUNC(DBMS_RANDOM.VALUE(1000000, 9999999)),
                'contacto' || v_id_alojamiento || '@turismouq.co',
                m,
                v_tipo_alojam
            );

            -- numero de habitaciones: los hoteles (tipo 1) tienen
            -- rangos mucho mas grandes que fincas/glampings/hostales
            IF v_tipo_alojam = 1 THEN
                v_num_habitaciones := TRUNC(DBMS_RANDOM.VALUE(15, 41));  -- hotel: 15-40
            ELSE
                v_num_habitaciones := TRUNC(DBMS_RANDOM.VALUE(3, 13));   -- resto: 3-12
            END IF;

            FOR h IN 1 .. v_num_habitaciones LOOP
                DECLARE
                    v_tipo_hab VARCHAR2(20);
                    v_capacidad NUMBER;
                    v_r NUMBER := TRUNC(DBMS_RANDOM.VALUE(1, 5));
                BEGIN
                    IF v_r = 1 THEN v_tipo_hab := 'Sencilla'; v_capacidad := TRUNC(DBMS_RANDOM.VALUE(1,3));
                    ELSIF v_r = 2 THEN v_tipo_hab := 'Doble';    v_capacidad := TRUNC(DBMS_RANDOM.VALUE(2,5));
                    ELSIF v_r = 3 THEN v_tipo_hab := 'Suite';    v_capacidad := TRUNC(DBMS_RANDOM.VALUE(2,5));
                    ELSE               v_tipo_hab := 'Cabana';   v_capacidad := TRUNC(DBMS_RANDOM.VALUE(4,9));
                    END IF;

                    INSERT INTO habitacion (
                        id_habitacion, numero, capacidad_maxima, tipo, descripcion, id_alojamiento
                    ) VALUES (
                        v_id_habitacion, TO_CHAR(h), v_capacidad, v_tipo_hab,
                        'Habitacion tipo ' || v_tipo_hab, v_id_alojamiento
                    );

                    -- precio base segun tipo de habitacion/alojamiento,
                    -- con variacion aleatoria realista
                    v_base_precio := CASE v_tipo_hab
                                        WHEN 'Sencilla' THEN 80000
                                        WHEN 'Doble'    THEN 130000
                                        WHEN 'Suite'    THEN 220000
                                        ELSE 300000  -- Cabana
                                      END * (CASE WHEN v_tipo_alojam = 1 THEN 1.3 ELSE 1 END);

                    -- una tarifa por cada temporada (9), con multiplicador
                    -- distinto segun el tipo de temporada: cada alojamiento
                    -- decide su propio incremento, no es un % fijo
                    FOR t IN 1 .. 9 LOOP
                        SELECT CASE tipo
                                 WHEN 'Alta'  THEN DBMS_RANDOM.VALUE(1.3, 1.9)
                                 WHEN 'Media' THEN DBMS_RANDOM.VALUE(1.0, 1.3)
                                 ELSE DBMS_RANDOM.VALUE(0.7, 1.0)
                               END
                          INTO v_mult_temporada
                          FROM temporada WHERE id_temporada = t;

                        INSERT INTO tarifa (id_tarifa, precio_noche, id_habitacion, id_temporada)
                        VALUES (v_id_tarifa, ROUND(v_base_precio * v_mult_temporada, -3), v_id_habitacion, t);

                        v_id_tarifa := v_id_tarifa + 1;
                    END LOOP;

                    v_id_habitacion := v_id_habitacion + 1;
                END;
            END LOOP;

            v_id_alojamiento := v_id_alojamiento + 1;
        END LOOP;
    END LOOP;
    COMMIT;
END;
/


-- ---------------------------------------------------------------------
-- 5. CLIENTE (200 clientes, ciudades variadas)
-- ---------------------------------------------------------------------
DECLARE
    TYPE t_str_tab IS TABLE OF VARCHAR2(40);
    v_nombres  t_str_tab := t_str_tab('Juan','Maria','Carlos','Laura','Andres','Camila','Felipe','Valentina',
                                       'Diego','Isabella','Santiago','Daniela','Julian','Natalia','Mateo',
                                       'Paola','Ricardo','Simon','Sara','Alejandro');
    v_apellidos t_str_tab := t_str_tab('Gomez','Rodriguez','Martinez','Lopez','Garcia','Hernandez','Perez',
                                        'Sanchez','Ramirez','Torres','Flores','Rivera','Castro','Ortiz','Reyes');
    v_ciudades  t_str_tab := t_str_tab('Bogota','Medellin','Cali','Barranquilla','Bucaramanga','Pereira',
                                        'Manizales','Ibague','Cucuta','Pasto','Armenia','Cartagena');
BEGIN
    FOR i IN 1 .. 200 LOOP
        INSERT INTO cliente (id_cliente, nombre, documento_identidad, correo, telefono, ciudad_origen)
        VALUES (
            i,
            v_nombres(TRUNC(DBMS_RANDOM.VALUE(1, 21))) || ' ' || v_apellidos(TRUNC(DBMS_RANDOM.VALUE(1, 16))),
            TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(1000000000, 1099999999))),
            'cliente' || i || '@correo.com',
            '3' || TRUNC(DBMS_RANDOM.VALUE(100000000, 299999999)),
            v_ciudades(TRUNC(DBMS_RANDOM.VALUE(1, 13)))
        );
    END LOOP;
    COMMIT;
END;
/


-- ---------------------------------------------------------------------
-- 6. SERVICIO (2 a 5 servicios por alojamiento; nombres tipicos del
-- sector turistico. Debe ir ANTES de la seccion de reservas porque
-- RESERVA_SERVICIO depende de que ya existan servicios.)
-- ---------------------------------------------------------------------
DECLARE
    TYPE t_str_tab IS TABLE OF VARCHAR2(60);
    v_servicios t_str_tab := t_str_tab('Desayuno incluido', 'Tour guiado cafetero',
        'Transporte al aeropuerto', 'Alquiler de bicicletas', 'Spa y masajes',
        'Cabalgata', 'Noche de fogata', 'Decoracion especial');
    v_id_servicio NUMBER := 1;
    v_num_serv    NUMBER;
BEGIN
    FOR al IN (SELECT id_alojamiento FROM alojamiento) LOOP
        v_num_serv := TRUNC(DBMS_RANDOM.VALUE(2, 6));
        FOR s IN 1 .. v_num_serv LOOP
            INSERT INTO servicio (id_servicio, nombre, descripcion, precio, id_alojamiento)
            VALUES (
                v_id_servicio,
                v_servicios(TRUNC(DBMS_RANDOM.VALUE(1, 9))),
                'Servicio complementario ofrecido por el alojamiento.',
                ROUND(DBMS_RANDOM.VALUE(15000, 180000), -3),
                al.id_alojamiento
            );
            v_id_servicio := v_id_servicio + 1;
        END LOOP;
    END LOOP;
    COMMIT;
END;
/


-- ---------------------------------------------------------------------
-- 7. RESERVA + RESERVA_HABITACION + PAGO + RESERVA_SERVICIO + RESENA
-- Asimetria temporal: mas reservas en temporada alta que en baja.
-- Asimetria por alojamiento: algunos "populares" (los primeros 8 de
-- cada municipio turistico) concentran mas reservas que el resto.
-- ---------------------------------------------------------------------
DECLARE
    v_id_reserva            NUMBER := 1;
    v_id_reserva_habitacion NUMBER := 1;
    v_id_pago               NUMBER := 1;
    v_id_reserva_servicio   NUMBER := 1;
    v_id_resena             NUMBER := 1;

    v_total_reservas  NUMBER := 650;   -- volumen base de reservas
    v_id_alojamiento  NUMBER;
    v_id_cliente      NUMBER;
    v_checkin         DATE;
    v_checkout        DATE;
    v_estado          VARCHAR2(15);
    v_num_habs        NUMBER;
    v_id_habitacion   NUMBER;
    v_valor_noche      NUMBER;
    v_valor_estadia    NUMBER;
    v_hoy              DATE := DATE '2026-10-02';  -- fecha de corte "hoy" del semestre
    v_mes_peso         NUMBER;
    v_servicios_count  NUMBER;
BEGIN
    FOR i IN 1 .. v_total_reservas LOOP
      DECLARE
          v_mi_reserva NUMBER := v_id_reserva;  -- ID fijo de ESTA vuelta
      BEGIN  -- bloque de seguridad: si ESTA reserva falla por algo
             -- imprevisto, se salta y se sigue con la siguiente, en
             -- vez de abortar las 650 de un solo golpe.
        v_id_reserva := v_id_reserva + 1;  -- avanza el contador YA,
             -- ANTES de cualquier INSERT, para que un fallo a medias
             -- nunca reutilice este mismo ID en la siguiente vuelta.

        -- --- fecha de checkin asimetrica: se favorecen los meses de
        -- temporada alta (dic-ene, semana santa, jun-jul) usando un
        -- peso mayor para esos rangos.
        v_mes_peso := TRUNC(DBMS_RANDOM.VALUE(1, 101));
        IF v_mes_peso <= 40 THEN
            -- 40% de las reservas caen en meses de temporada alta
            v_checkin := DATE '2026-06-01' + TRUNC(DBMS_RANDOM.VALUE(0, 61));  -- jun-jul
        ELSIF v_mes_peso <= 60 THEN
            v_checkin := DATE '2025-12-15' + TRUNC(DBMS_RANDOM.VALUE(0, 32));  -- dic-ene
        ELSE
            v_checkin := DATE '2026-01-16' + TRUNC(DBMS_RANDOM.VALUE(0, 320)); -- resto del anio
        END IF;

        v_checkout := v_checkin + TRUNC(DBMS_RANDOM.VALUE(1, 8));  -- estadia 1-7 noches

        -- --- alojamiento: distribucion asimetrica, favorece
        -- alojamientos de Armenia (1-10) y Salento (ids calculados
        -- segun el orden de insercion de la seccion 4: Armenia 1-10,
        -- Calarca 11-15, Montenegro 16-19, Quimbaya 20-22,
        -- La Tebaida 23-24, Circasia 25-26, Salento 27-34,
        -- Filandia 35-40, Buenavista 41, Cordoba 42-43, Pijao 44-45,
        -- Genova 46).
        IF DBMS_RANDOM.VALUE(0,1) < 0.55 THEN
            -- 55% de las reservas en Armenia o Salento (polos turisticos)
            IF DBMS_RANDOM.VALUE(0,1) < 0.5 THEN
                v_id_alojamiento := TRUNC(DBMS_RANDOM.VALUE(1, 11));   -- Armenia
            ELSE
                v_id_alojamiento := TRUNC(DBMS_RANDOM.VALUE(27, 35));  -- Salento
            END IF;
        ELSE
            v_id_alojamiento := TRUNC(DBMS_RANDOM.VALUE(1, 47));       -- cualquiera
        END IF;

        v_id_cliente := TRUNC(DBMS_RANDOM.VALUE(1, 201));

        -- --- estado: si el checkin ya paso respecto a "hoy", se
        -- reparte entre Completada/Cancelada; si es futuro, entre
        -- Pendiente/Confirmada.
        IF v_checkin < v_hoy THEN
            v_estado := CASE WHEN DBMS_RANDOM.VALUE(0,1) < 0.85 THEN 'Completada' ELSE 'Cancelada' END;
        ELSE
            v_estado := CASE WHEN DBMS_RANDOM.VALUE(0,1) < 0.6 THEN 'Confirmada' ELSE 'Pendiente' END;
        END IF;

        INSERT INTO reserva (id_reserva, fecha_checkin, fecha_checkout, estado, id_cliente, id_alojamiento)
        VALUES (v_mi_reserva, v_checkin, v_checkout, v_estado, v_id_cliente, v_id_alojamiento);

        -- --- 1 a 3 habitaciones por reserva (la mayoria, 1 sola)
        v_num_habs := CASE WHEN DBMS_RANDOM.VALUE(0,1) < 0.75 THEN 1
                            WHEN DBMS_RANDOM.VALUE(0,1) < 0.9  THEN 2
                            ELSE 3 END;

        v_valor_estadia := 0;

        FOR r IN 1 .. v_num_habs LOOP
            -- elegir una habitacion que pertenezca a ese alojamiento
            BEGIN
                SELECT id_habitacion INTO v_id_habitacion
                FROM (
                    SELECT id_habitacion FROM habitacion
                    WHERE id_alojamiento = v_id_alojamiento
                    ORDER BY DBMS_RANDOM.VALUE
                )
                WHERE ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    CONTINUE;
            END;

            INSERT INTO reserva_habitacion (
                id_reserva_habitacion, fecha_checkin, fecha_checkout,
                cantidad_huespedes, id_reserva, id_habitacion
            ) VALUES (
                v_id_reserva_habitacion, v_checkin, v_checkout,
                TRUNC(DBMS_RANDOM.VALUE(1, 5)), v_mi_reserva, v_id_habitacion
            );
            v_id_reserva_habitacion := v_id_reserva_habitacion + 1;

            -- acumular valor aproximado de la estadia para esta
            -- habitacion (tarifa de la temporada del checkin; es una
            -- aproximacion razonable para la carga de datos -- el
            -- calculo noche-a-noche exacto lo hace fn_valor_estadia
            -- en la Entrega 2)
            BEGIN
                SELECT t.precio_noche INTO v_valor_noche
                FROM tarifa t
                JOIN temporada tmp ON tmp.id_temporada = t.id_temporada
                WHERE t.id_habitacion = v_id_habitacion
                  AND v_checkin BETWEEN tmp.fecha_inicio AND tmp.fecha_fin
                  AND ROWNUM = 1;
                v_valor_estadia := v_valor_estadia + v_valor_noche * (v_checkout - v_checkin);
            EXCEPTION
                WHEN NO_DATA_FOUND THEN NULL;
            END;
        END LOOP;

        -- --- servicios opcionales (40% de las reservas incluyen 1-3)
        IF DBMS_RANDOM.VALUE(0,1) < 0.4 THEN
            v_servicios_count := TRUNC(DBMS_RANDOM.VALUE(1, 4));
            FOR s IN 1 .. v_servicios_count LOOP
                DECLARE
                    v_id_servicio NUMBER;
                BEGIN
                    SELECT id_servicio INTO v_id_servicio FROM (
                        SELECT id_servicio FROM servicio
                        WHERE id_alojamiento = v_id_alojamiento
                        ORDER BY DBMS_RANDOM.VALUE
                    ) WHERE ROWNUM = 1;

                    INSERT INTO reserva_servicio (id_reserva_servicio, cantidad, id_reserva, id_servicio)
                    VALUES (v_id_reserva_servicio, TRUNC(DBMS_RANDOM.VALUE(1,4)), v_mi_reserva, v_id_servicio);
                    v_id_reserva_servicio := v_id_reserva_servicio + 1;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN NULL;  -- este alojamiento no tiene servicios cargados
                    WHEN DUP_VAL_ON_INDEX THEN NULL;  -- esta reserva ya incluia ese mismo servicio, se omite
                END;
            END LOOP;
        END IF;

        -- --- pagos: si la reserva no esta Pendiente, al menos un
        -- pago; algunas en dos abonos.
        IF v_estado != 'Pendiente' AND v_valor_estadia > 0 THEN
            IF DBMS_RANDOM.VALUE(0,1) < 0.3 THEN
                -- dos abonos: 40% anticipo + 60% saldo
                INSERT INTO pago (id_pago, fecha_pago, monto, metodo, estado, id_reserva)
                VALUES (v_id_pago, v_checkin - 10, ROUND(v_valor_estadia * 0.4),
                        'Transferencia', 'Exitoso', v_mi_reserva);
                v_id_pago := v_id_pago + 1;
                INSERT INTO pago (id_pago, fecha_pago, monto, metodo, estado, id_reserva)
                VALUES (v_id_pago, v_checkin, ROUND(v_valor_estadia * 0.6),
                        'Tarjeta credito',
                        CASE WHEN v_estado = 'Cancelada' THEN 'Reembolsado' ELSE 'Exitoso' END,
                        v_mi_reserva);
                v_id_pago := v_id_pago + 1;
            ELSE
                INSERT INTO pago (id_pago, fecha_pago, monto, metodo, estado, id_reserva)
                VALUES (v_id_pago, v_checkin, ROUND(v_valor_estadia),
                        CASE TRUNC(DBMS_RANDOM.VALUE(1,5))
                            WHEN 1 THEN 'PSE' WHEN 2 THEN 'Tarjeta debito'
                            WHEN 3 THEN 'Transferencia' ELSE 'Efectivo' END,
                        CASE WHEN v_estado = 'Cancelada' THEN 'Reembolsado' ELSE 'Exitoso' END,
                        v_mi_reserva);
                v_id_pago := v_id_pago + 1;
            END IF;
        END IF;

        -- --- resena: solo reservas Completada, y no todas (65%)
        IF v_estado = 'Completada' AND DBMS_RANDOM.VALUE(0,1) < 0.65 THEN
            INSERT INTO resena (id_resena, calificacion, comentario, fecha_resena, id_reserva)
            VALUES (v_id_resena, TRUNC(DBMS_RANDOM.VALUE(2,6)),
                    'Estadia registrada en la plataforma.', v_checkout + 1, v_mi_reserva);
            v_id_resena := v_id_resena + 1;
        END IF;

      EXCEPTION
          WHEN OTHERS THEN
              NULL;  -- se salta esta reserva puntual y continua con la siguiente
      END;
    END LOOP;
    COMMIT;
END;
/


-- ---------------------------------------------------------------------
-- 8. USUARIO_SISTEMA
-- 3 administradores (globales, sin alojamiento) + 1 encargado por
-- cada alojamiento (coherente con el CHECK de la tabla).
-- ---------------------------------------------------------------------
DECLARE
    v_id_usuario NUMBER := 1;
BEGIN
    FOR i IN 1 .. 3 LOOP
        INSERT INTO usuario_sistema (id_usuario, nombre, nombre_usuario, correo, rol, id_alojamiento)
        VALUES (v_id_usuario, 'Administrador ' || i, 'admin' || i, 'admin' || i || '@turismouq.co',
                'Administrador', NULL);
        v_id_usuario := v_id_usuario + 1;
    END LOOP;

    FOR al IN (SELECT id_alojamiento FROM alojamiento) LOOP
        INSERT INTO usuario_sistema (id_usuario, nombre, nombre_usuario, correo, rol, id_alojamiento)
        VALUES (v_id_usuario, 'Encargado alojamiento ' || al.id_alojamiento,
                'encargado' || al.id_alojamiento, 'encargado' || al.id_alojamiento || '@turismouq.co',
                'Encargado', al.id_alojamiento);
        v_id_usuario := v_id_usuario + 1;
    END LOOP;
    COMMIT;
END;
/


-- ---------------------------------------------------------------------
-- VERIFICACION RAPIDA
-- ---------------------------------------------------------------------
SELECT 'municipio' tabla, COUNT(*) filas FROM municipio
UNION ALL SELECT 'tipo_alojamiento', COUNT(*) FROM tipo_alojamiento
UNION ALL SELECT 'temporada', COUNT(*) FROM temporada
UNION ALL SELECT 'alojamiento', COUNT(*) FROM alojamiento
UNION ALL SELECT 'habitacion', COUNT(*) FROM habitacion
UNION ALL SELECT 'tarifa', COUNT(*) FROM tarifa
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL SELECT 'servicio', COUNT(*) FROM servicio
UNION ALL SELECT 'reserva', COUNT(*) FROM reserva
UNION ALL SELECT 'reserva_habitacion', COUNT(*) FROM reserva_habitacion
UNION ALL SELECT 'reserva_servicio', COUNT(*) FROM reserva_servicio
UNION ALL SELECT 'pago', COUNT(*) FROM pago
UNION ALL SELECT 'resena', COUNT(*) FROM resena
UNION ALL SELECT 'usuario_sistema', COUNT(*) FROM usuario_sistema;

-- Asimetria por municipio (ver que NO es parejo)
SELECT mu.nombre, COUNT(*) num_reservas
FROM reserva r
JOIN alojamiento al ON al.id_alojamiento = r.id_alojamiento
JOIN municipio mu ON mu.id_municipio = al.id_municipio
GROUP BY mu.nombre
ORDER BY num_reservas DESC;


SELECT COUNT(*) FROM reserva;
