-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- 01_ddl_turismouq.sql
-- Script DDL: creacion de las 14 entidades + 1 auxiliar (auditoria),
-- con PK, FK, CHECK, NOT NULL y UNIQUE segun las reglas de negocio
-- del enunciado (seccion 1).
--
-- IMPORTANTE: este script asume un esquema LIMPIO (sin estas tablas).
-- Si ya las habian creado antes y quieren empezar de cero, corran
-- PRIMERO el archivo 00_reset_turismouq.sql, y despues este.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. MUNICIPIO
-- Catalogo de los 12 municipios del Quindio donde opera la plataforma.
-- ---------------------------------------------------------------------
CREATE TABLE municipio (
    id_municipio  NUMBER        NOT NULL,
    nombre        VARCHAR2(60)  NOT NULL,
    CONSTRAINT municipio_pk PRIMARY KEY (id_municipio),
    CONSTRAINT municipio_uq_nombre UNIQUE (nombre)
);
COMMENT ON TABLE municipio IS 'Los 12 municipios del Quindio donde hay oferta de alojamiento.';


-- ---------------------------------------------------------------------
-- 2. TIPO_ALOJAMIENTO
-- Catalogo: finca cafetera, hotel, glamping, hostal, etc.
-- ---------------------------------------------------------------------
CREATE TABLE tipo_alojamiento (
    id_tipo_alojamiento  NUMBER        NOT NULL,
    nombre               VARCHAR2(60)  NOT NULL,
    CONSTRAINT tipo_alojamiento_pk PRIMARY KEY (id_tipo_alojamiento),
    CONSTRAINT tipo_alojamiento_uq_nombre UNIQUE (nombre)
);
COMMENT ON TABLE tipo_alojamiento IS 'Catalogo de tipos de alojamiento (finca cafetera, hotel, glamping, hostal...).';


-- ---------------------------------------------------------------------
-- 3. CLIENTE
-- Huespedes que hacen reservas. documento_identidad y correo son
-- unicos porque identifican a la persona de forma inequivoca.
-- ---------------------------------------------------------------------
CREATE TABLE cliente (
    id_cliente           NUMBER         NOT NULL,
    nombre               VARCHAR2(120)  NOT NULL,
    documento_identidad  VARCHAR2(20)   NOT NULL,
    correo               VARCHAR2(120),
    telefono             VARCHAR2(20),
    ciudad_origen        VARCHAR2(60),
    CONSTRAINT cliente_pk PRIMARY KEY (id_cliente),
    CONSTRAINT cliente_uq_documento UNIQUE (documento_identidad),
    CONSTRAINT cliente_uq_correo UNIQUE (correo)
);
COMMENT ON TABLE cliente IS 'Huespedes registrados en la plataforma.';


-- ---------------------------------------------------------------------
-- 4. TEMPORADA
-- Se definen por anio (Semana Santa 2025 != Semana Santa 2026).
-- CHECK sobre 'tipo' porque el enunciado especifica exactamente
-- alta/media/baja. CHECK de fechas para que el rango tenga sentido.
-- ---------------------------------------------------------------------
CREATE TABLE temporada (
    id_temporada   NUMBER        NOT NULL,
    nombre         VARCHAR2(60)  NOT NULL,
    tipo           VARCHAR2(10)  NOT NULL,
    fecha_inicio   DATE          NOT NULL,
    fecha_fin      DATE          NOT NULL,
    CONSTRAINT temporada_pk PRIMARY KEY (id_temporada),
    CONSTRAINT temporada_uq_nombre UNIQUE (nombre),
    CONSTRAINT temporada_ck_tipo CHECK (tipo IN ('Alta', 'Media', 'Baja')),
    CONSTRAINT temporada_ck_fechas CHECK (fecha_fin > fecha_inicio)
);
COMMENT ON TABLE temporada IS 'Temporadas definidas por anio, con su rango de fechas. Determinan la tarifa de cada habitacion.';


-- ---------------------------------------------------------------------
-- 5. ALOJAMIENTO
-- Pertenece a un municipio y a un tipo (relacion corregida: antes
-- estaba invertida en el modelo grafico -> aqui FK va en ALOJAMIENTO).
-- calificacion en estrellas la autoasigna el alojamiento (1 a 5).
-- ---------------------------------------------------------------------
CREATE TABLE alojamiento (
    id_alojamiento          NUMBER         NOT NULL,
    nombre_comercial        VARCHAR2(150)  NOT NULL,
    direccion               VARCHAR2(200),
    calificacion_estrellas  NUMBER(1)      NOT NULL,
    telefono_contacto       VARCHAR2(20),
    correo_contacto         VARCHAR2(120),
    id_municipio            NUMBER         NOT NULL,
    id_tipo_alojamiento     NUMBER         NOT NULL,
    CONSTRAINT alojamiento_pk PRIMARY KEY (id_alojamiento),
    CONSTRAINT alojamiento_fk_municipio FOREIGN KEY (id_municipio)
        REFERENCES municipio (id_municipio),
    CONSTRAINT alojamiento_fk_tipo FOREIGN KEY (id_tipo_alojamiento)
        REFERENCES tipo_alojamiento (id_tipo_alojamiento),
    CONSTRAINT alojamiento_ck_estrellas CHECK (calificacion_estrellas BETWEEN 1 AND 5)
);
COMMENT ON TABLE alojamiento IS 'Fincas cafeteras, hoteles, glampings y hostales ofertados en la plataforma.';


-- ---------------------------------------------------------------------
-- 6. HABITACION
-- Dos habitaciones del mismo alojamiento no pueden compartir numero
-- (UNIQUE compuesto). CHECK sobre el tipo segun el enunciado.
-- ---------------------------------------------------------------------
CREATE TABLE habitacion (
    id_habitacion      NUMBER        NOT NULL,
    numero             VARCHAR2(10)  NOT NULL,
    capacidad_maxima   NUMBER        NOT NULL,
    tipo               VARCHAR2(20)  NOT NULL,
    descripcion        VARCHAR2(300),
    id_alojamiento     NUMBER        NOT NULL,
    CONSTRAINT habitacion_pk PRIMARY KEY (id_habitacion),
    CONSTRAINT habitacion_fk_alojamiento FOREIGN KEY (id_alojamiento)
        REFERENCES alojamiento (id_alojamiento),
    CONSTRAINT habitacion_uq_numero UNIQUE (id_alojamiento, numero),
    CONSTRAINT habitacion_ck_capacidad CHECK (capacidad_maxima > 0),
    CONSTRAINT habitacion_ck_tipo CHECK (tipo IN ('Sencilla', 'Doble', 'Suite', 'Cabana'))
);
COMMENT ON TABLE habitacion IS 'Habitaciones que ofrece cada alojamiento. Numero unico dentro del mismo alojamiento.';


-- ---------------------------------------------------------------------
-- 7. TARIFA
-- Precio por noche de UNA habitacion en UNA temporada especifica.
-- UNIQUE compuesto: una habitacion no puede tener dos tarifas para
-- la misma temporada.
-- ---------------------------------------------------------------------
CREATE TABLE tarifa (
    id_tarifa       NUMBER  NOT NULL,
    precio_noche    NUMBER  NOT NULL,
    id_habitacion   NUMBER  NOT NULL,
    id_temporada    NUMBER  NOT NULL,
    CONSTRAINT tarifa_pk PRIMARY KEY (id_tarifa),
    CONSTRAINT tarifa_fk_habitacion FOREIGN KEY (id_habitacion)
        REFERENCES habitacion (id_habitacion),
    CONSTRAINT tarifa_fk_temporada FOREIGN KEY (id_temporada)
        REFERENCES temporada (id_temporada),
    CONSTRAINT tarifa_uq_hab_temp UNIQUE (id_habitacion, id_temporada),
    CONSTRAINT tarifa_ck_precio CHECK (precio_noche > 0)
);
COMMENT ON TABLE tarifa IS 'Precio por noche de cada habitacion, segun la temporada. No es un porcentaje fijo: cada alojamiento define su propio precio por temporada.';


-- ---------------------------------------------------------------------
-- 8. SERVICIO
-- Pertenece a UN alojamiento especifico (el desayuno del Hotel X no
-- es el mismo servicio que el desayuno del Hotel Y).
-- ---------------------------------------------------------------------
CREATE TABLE servicio (
    id_servicio      NUMBER        NOT NULL,
    nombre           VARCHAR2(100) NOT NULL,
    descripcion      VARCHAR2(300),
    precio           NUMBER        NOT NULL,
    id_alojamiento   NUMBER        NOT NULL,
    CONSTRAINT servicio_pk PRIMARY KEY (id_servicio),
    CONSTRAINT servicio_fk_alojamiento FOREIGN KEY (id_alojamiento)
        REFERENCES alojamiento (id_alojamiento),
    CONSTRAINT servicio_ck_precio CHECK (precio > 0)
);
COMMENT ON TABLE servicio IS 'Servicios complementarios ofrecidos por cada alojamiento (desayuno, tours, transporte, etc.), propios de ese alojamiento.';


-- ---------------------------------------------------------------------
-- 9. USUARIO_SISTEMA
-- Administradores (no dependen de un alojamiento) y encargados de
-- alojamiento (si dependen). El CHECK combinado obliga la coherencia:
-- Administrador -> id_alojamiento NULL; Encargado -> id_alojamiento NOT NULL.
-- ---------------------------------------------------------------------
CREATE TABLE usuario_sistema (
    id_usuario       NUMBER        NOT NULL,
    nombre           VARCHAR2(120) NOT NULL,
    nombre_usuario   VARCHAR2(40)  NOT NULL,
    correo           VARCHAR2(120) NOT NULL,
    rol              VARCHAR2(20)  NOT NULL,
    id_alojamiento   NUMBER,
    CONSTRAINT usuario_sistema_pk PRIMARY KEY (id_usuario),
    CONSTRAINT usuario_sistema_fk_alojamiento FOREIGN KEY (id_alojamiento)
        REFERENCES alojamiento (id_alojamiento),
    CONSTRAINT usuario_sistema_uq_usuario UNIQUE (nombre_usuario),
    CONSTRAINT usuario_sistema_uq_correo UNIQUE (correo),
    CONSTRAINT usuario_sistema_ck_rol CHECK (rol IN ('Administrador', 'Encargado')),
    CONSTRAINT usuario_sistema_ck_coherencia CHECK (
        (rol = 'Administrador' AND id_alojamiento IS NULL) OR
        (rol = 'Encargado'     AND id_alojamiento IS NOT NULL)
    )
);
COMMENT ON TABLE usuario_sistema IS 'Usuarios internos de la plataforma: administradores (globales) y encargados de un alojamiento especifico.';


-- ---------------------------------------------------------------------
-- 10. RESERVA
-- id_alojamiento se guarda de forma directa (aunque es derivable via
-- RESERVA_HABITACION -> HABITACION) para garantizar que todas las
-- habitaciones de una misma reserva pertenezcan al mismo alojamiento;
-- esa consistencia se valida con un trigger en la Entrega 2.
-- ---------------------------------------------------------------------
CREATE TABLE reserva (
    id_reserva       NUMBER       NOT NULL,
    fecha_checkin    DATE         NOT NULL,
    fecha_checkout   DATE         NOT NULL,
    estado           VARCHAR2(15) NOT NULL,
    id_cliente       NUMBER       NOT NULL,
    id_alojamiento   NUMBER       NOT NULL,
    CONSTRAINT reserva_pk PRIMARY KEY (id_reserva),
    CONSTRAINT reserva_fk_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente (id_cliente),
    CONSTRAINT reserva_fk_alojamiento FOREIGN KEY (id_alojamiento)
        REFERENCES alojamiento (id_alojamiento),
    CONSTRAINT reserva_ck_estado CHECK (estado IN ('Pendiente', 'Confirmada', 'Cancelada', 'Completada')),
    CONSTRAINT reserva_ck_fechas CHECK (fecha_checkout > fecha_checkin)
);
COMMENT ON TABLE reserva IS 'Reserva general de un cliente en un alojamiento. Puede incluir varias habitaciones (ver RESERVA_HABITACION).';


-- ---------------------------------------------------------------------
-- 11. RESERVA_HABITACION
-- Entidad asociativa RESERVA <-> HABITACION. Resuelve la decision de
-- diseno "reserva con varias habitaciones": cada linea puede tener
-- fechas levemente distintas dentro del rango general de la reserva.
-- ---------------------------------------------------------------------
CREATE TABLE reserva_habitacion (
    id_reserva_habitacion  NUMBER NOT NULL,
    fecha_checkin          DATE   NOT NULL,
    fecha_checkout         DATE   NOT NULL,
    cantidad_huespedes     NUMBER NOT NULL,
    id_reserva             NUMBER NOT NULL,
    id_habitacion          NUMBER NOT NULL,
    CONSTRAINT reserva_habitacion_pk PRIMARY KEY (id_reserva_habitacion),
    CONSTRAINT reserva_habitacion_fk_reserva FOREIGN KEY (id_reserva)
        REFERENCES reserva (id_reserva),
    CONSTRAINT reserva_habitacion_fk_habitacion FOREIGN KEY (id_habitacion)
        REFERENCES habitacion (id_habitacion),
    CONSTRAINT reserva_habitacion_ck_fechas CHECK (fecha_checkout > fecha_checkin),
    CONSTRAINT reserva_habitacion_ck_huespedes CHECK (cantidad_huespedes > 0)
);
COMMENT ON TABLE reserva_habitacion IS 'Cada habitacion incluida en una reserva, con sus propias fechas dentro del rango general y la cantidad de huespedes. Permite reservas de varias habitaciones a la vez.';


-- ---------------------------------------------------------------------
-- 12. PAGO
-- Una reserva puede tener varios pagos (abonos).
-- ---------------------------------------------------------------------
CREATE TABLE pago (
    id_pago         NUMBER       NOT NULL,
    fecha_pago      DATE         NOT NULL,
    monto           NUMBER       NOT NULL,
    metodo          VARCHAR2(20) NOT NULL,
    estado          VARCHAR2(15) NOT NULL,
    id_reserva      NUMBER       NOT NULL,
    CONSTRAINT pago_pk PRIMARY KEY (id_pago),
    CONSTRAINT pago_fk_reserva FOREIGN KEY (id_reserva)
        REFERENCES reserva (id_reserva),
    CONSTRAINT pago_ck_monto CHECK (monto > 0),
    CONSTRAINT pago_ck_metodo CHECK (metodo IN ('Tarjeta credito', 'Tarjeta debito', 'PSE', 'Transferencia', 'Efectivo')),
    CONSTRAINT pago_ck_estado CHECK (estado IN ('Exitoso', 'Fallido', 'Pendiente', 'Reembolsado'))
);
COMMENT ON TABLE pago IS 'Pagos/abonos asociados a una reserva. Una reserva esta pagada cuando la suma de sus pagos EXITOSOS cubre el valor total (estadia + servicios); ese total es calculado, no almacenado.';


-- ---------------------------------------------------------------------
-- 13. RESERVA_SERVICIO
-- Entidad asociativa RESERVA <-> SERVICIO, con cantidad (ej: 2 tours
-- guiados para 2 personas del mismo grupo).
-- ---------------------------------------------------------------------
CREATE TABLE reserva_servicio (
    id_reserva_servicio  NUMBER NOT NULL,
    cantidad             NUMBER NOT NULL,
    id_reserva           NUMBER NOT NULL,
    id_servicio          NUMBER NOT NULL,
    CONSTRAINT reserva_servicio_pk PRIMARY KEY (id_reserva_servicio),
    CONSTRAINT reserva_servicio_fk_reserva FOREIGN KEY (id_reserva)
        REFERENCES reserva (id_reserva),
    CONSTRAINT reserva_servicio_fk_servicio FOREIGN KEY (id_servicio)
        REFERENCES servicio (id_servicio),
    CONSTRAINT reserva_servicio_uq_linea UNIQUE (id_reserva, id_servicio),
    CONSTRAINT reserva_servicio_ck_cantidad CHECK (cantidad > 0)
);
COMMENT ON TABLE reserva_servicio IS 'Servicios complementarios incluidos en una reserva, con la cantidad pedida de cada uno.';


-- ---------------------------------------------------------------------
-- 14. RESENA
-- Una resena por reserva como maximo (UNIQUE sobre id_reserva). La
-- regla "solo se puede resenar si la reserva quedo Completada" no se
-- puede expresar con un CHECK simple (depende del estado en OTRA
-- fila de OTRA tabla) -> se valida con trigger en la Entrega 2.
-- ---------------------------------------------------------------------
CREATE TABLE resena (
    id_resena       NUMBER       NOT NULL,
    calificacion    NUMBER(1)    NOT NULL,
    comentario      VARCHAR2(500),
    fecha_resena    DATE         NOT NULL,
    id_reserva      NUMBER       NOT NULL,
    CONSTRAINT resena_pk PRIMARY KEY (id_resena),
    CONSTRAINT resena_fk_reserva FOREIGN KEY (id_reserva)
        REFERENCES reserva (id_reserva),
    CONSTRAINT resena_uq_reserva UNIQUE (id_reserva),
    CONSTRAINT resena_ck_calificacion CHECK (calificacion BETWEEN 1 AND 5)
);
COMMENT ON TABLE resena IS 'Resena de una reserva ya completada (maximo una por reserva). La validacion de que la reserva este Completada se hace con trigger en la Entrega 2.';


-- ---------------------------------------------------------------------
-- 15. AUDITORIA_TARIFA (tabla auxiliar, se llenara via trigger en la
-- Entrega 2; se crea desde ya porque hace parte del modelo entregado).
-- ---------------------------------------------------------------------
CREATE TABLE auditoria_tarifa (
    id_auditoria      NUMBER        NOT NULL,
    usuario_bd        VARCHAR2(40)  NOT NULL,
    fecha_cambio      DATE          NOT NULL,
    precio_anterior   NUMBER,
    precio_nuevo      NUMBER,
    id_tarifa         NUMBER        NOT NULL,
    CONSTRAINT auditoria_tarifa_pk PRIMARY KEY (id_auditoria),
    CONSTRAINT auditoria_tarifa_fk_tarifa FOREIGN KEY (id_tarifa)
        REFERENCES tarifa (id_tarifa)
);
COMMENT ON TABLE auditoria_tarifa IS 'Historial de cambios de precio sobre TARIFA. Se llena mediante trigger (Entrega 2); en la Entrega 1 queda vacia.';


COMMIT;

-- ---------------------------------------------------------------------
-- Validacion de script
-- ---------------------------------------------------------------------

SELECT table_name FROM user_tables
WHERE table_name IN (
    'MUNICIPIO','TIPO_ALOJAMIENTO','CLIENTE','TEMPORADA','ALOJAMIENTO',
    'HABITACION','TARIFA','SERVICIO','USUARIO_SISTEMA','RESERVA',
    'RESERVA_HABITACION','PAGO','RESERVA_SERVICIO','RESENA','AUDITORIA_TARIFA'
)
ORDER BY table_name;


