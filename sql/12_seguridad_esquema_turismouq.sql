-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- Entrega 3 - Seguridad (parte del dueno del esquema)
-- 12_seguridad_esquema_turismouq.sql
-- Equipo: Daniela Munoz, Maria Jose Marmolejo, Santiago Ovalle
--
-- SE CORRE CON EL USUARIO DUENO DE LAS TABLAS (TURISMO_E2), con F5,
-- despues del script 11 (los roles ya deben existir).
--
-- Que puede hacer cada rol:
--
--   ROL_RECEPCION          Solo vistas, nunca tablas.
--                          - Consulta reservas y habitaciones.
--                          - Consulta clientes, registra clientes nuevos
--                            y corrige su correo o telefono.
--                          - Reserva y cobra con pkg_transacciones.
--
--   ROL_ADMIN_ALOJAMIENTO  Solo SU alojamiento, a traves de vistas que
--                          se filtran con el usuario conectado.
--                          - Ve sus habitaciones y cambia descripcion y
--                            capacidad.
--                          - Ve sus tarifas y cambia el precio (queda
--                            en la auditoria con su nombre).
--                          - Ve las reservas de su alojamiento.
--
--   ROL_GERENTE            Lectura de todo el negocio para analisis y la
--                          liquidacion mensual. No modifica nada. No ve
--                          los datos personales de los clientes.
--
--   ROL_AUDITOR            Lectura de lo que se controla: auditoria de
--                          tarifas, pagos, reservas y usuarios internos.
--                          No modifica nada ni ejecuta procesos.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Vistas de recepcion
-- ---------------------------------------------------------------------

-- Reservas con su cliente, alojamiento y habitacion (una fila por linea)
CREATE OR REPLACE VIEW v_recepcion_reservas AS
SELECT r.id_reserva,
       r.estado,
       rh.fecha_checkin,
       rh.fecha_checkout,
       rh.cantidad_huespedes,
       c.id_cliente,
       c.nombre               AS cliente,
       c.documento_identidad  AS documento,
       c.telefono,
       a.nombre_comercial     AS alojamiento,
       h.numero               AS habitacion
  FROM reserva r
  JOIN reserva_habitacion rh ON rh.id_reserva     = r.id_reserva
  JOIN cliente            c  ON c.id_cliente      = r.id_cliente
  JOIN habitacion         h  ON h.id_habitacion   = rh.id_habitacion
  JOIN alojamiento        a  ON a.id_alojamiento  = r.id_alojamiento
WITH READ ONLY;

-- Habitaciones para ofrecer (sin precios internos de nadie mas)
CREATE OR REPLACE VIEW v_recepcion_habitaciones AS
SELECT h.id_habitacion,
       a.nombre_comercial AS alojamiento,
       mu.nombre          AS municipio,
       ta.nombre          AS tipo_alojamiento,
       h.numero,
       h.tipo,
       h.capacidad_maxima
  FROM habitacion h
  JOIN alojamiento      a  ON a.id_alojamiento        = h.id_alojamiento
  JOIN municipio        mu ON mu.id_municipio         = a.id_municipio
  JOIN tipo_alojamiento ta ON ta.id_tipo_alojamiento  = a.id_tipo_alojamiento
WITH READ ONLY;

-- Clientes. Es de una sola tabla, asi que se puede insertar y
-- actualizar a traves de ella.
CREATE OR REPLACE VIEW v_recepcion_clientes AS
SELECT id_cliente, nombre, documento_identidad, correo, telefono, ciudad_origen
  FROM cliente;


-- ---------------------------------------------------------------------
-- 2. Vistas del administrador de alojamiento
-- Cada vista se filtra con el usuario de la sesion: busca en
-- USUARIO_SISTEMA el encargado cuyo nombre_usuario coincide con el
-- usuario de Oracle conectado y deja pasar solo su alojamiento.
-- Asi ENCARGADO1 ve el alojamiento 1, ENCARGADO7 veria el 7, etc.
-- El permiso de UPDATE se da solo sobre columnas que no deciden el
-- filtro (precio, descripcion, capacidad), asi que por la vista no se
-- puede pasar una fila a otro alojamiento.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_mis_habitaciones AS
SELECT h.id_habitacion, h.numero, h.tipo, h.capacidad_maxima,
       h.descripcion, h.id_alojamiento
  FROM habitacion h
 WHERE h.id_alojamiento IN (SELECT u.id_alojamiento
                              FROM usuario_sistema u
                             WHERE UPPER(u.nombre_usuario) = SYS_CONTEXT('USERENV', 'SESSION_USER')
                               AND u.rol = 'Encargado');

CREATE OR REPLACE VIEW v_mis_tarifas AS
SELECT t.id_tarifa, t.id_habitacion, t.id_temporada, t.precio_noche
  FROM tarifa t
 WHERE t.id_habitacion IN (SELECT h.id_habitacion
                             FROM habitacion h
                             JOIN usuario_sistema u ON u.id_alojamiento = h.id_alojamiento
                            WHERE UPPER(u.nombre_usuario) = SYS_CONTEXT('USERENV', 'SESSION_USER')
                              AND u.rol = 'Encargado');

CREATE OR REPLACE VIEW v_mis_reservas AS
SELECT r.id_reserva, r.estado, r.fecha_checkin, r.fecha_checkout,
       c.nombre AS cliente, rh.id_habitacion, rh.cantidad_huespedes
  FROM reserva r
  JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
  JOIN cliente c             ON c.id_cliente  = r.id_cliente
 WHERE r.id_alojamiento IN (SELECT u.id_alojamiento
                              FROM usuario_sistema u
                             WHERE UPPER(u.nombre_usuario) = SYS_CONTEXT('USERENV', 'SESSION_USER')
                               AND u.rol = 'Encargado')
WITH READ ONLY;


-- ---------------------------------------------------------------------
-- 3. Permisos
-- ---------------------------------------------------------------------

-- RECEPCION: solo vistas y el paquete de transacciones
GRANT SELECT ON v_recepcion_reservas      TO rol_recepcion;
GRANT SELECT ON v_recepcion_habitaciones  TO rol_recepcion;
GRANT SELECT, INSERT ON v_recepcion_clientes TO rol_recepcion;
GRANT UPDATE (correo, telefono) ON v_recepcion_clientes TO rol_recepcion;
GRANT EXECUTE ON pkg_transacciones        TO rol_recepcion;

-- ADMINISTRADOR DE ALOJAMIENTO: sus vistas filtradas
GRANT SELECT ON v_mis_habitaciones TO rol_admin_alojamiento;
GRANT UPDATE (descripcion, capacidad_maxima) ON v_mis_habitaciones TO rol_admin_alojamiento;
GRANT SELECT ON v_mis_tarifas      TO rol_admin_alojamiento;
GRANT UPDATE (precio_noche) ON v_mis_tarifas TO rol_admin_alojamiento;
GRANT SELECT ON v_mis_reservas     TO rol_admin_alojamiento;
GRANT SELECT ON temporada          TO rol_admin_alojamiento;

-- GERENTE: lectura del negocio + liquidacion
GRANT SELECT ON municipio            TO rol_gerente;
GRANT SELECT ON tipo_alojamiento     TO rol_gerente;
GRANT SELECT ON alojamiento          TO rol_gerente;
GRANT SELECT ON habitacion           TO rol_gerente;
GRANT SELECT ON temporada            TO rol_gerente;
GRANT SELECT ON tarifa               TO rol_gerente;
GRANT SELECT ON servicio             TO rol_gerente;
GRANT SELECT ON reserva              TO rol_gerente;
GRANT SELECT ON reserva_habitacion   TO rol_gerente;
GRANT SELECT ON reserva_servicio     TO rol_gerente;
GRANT SELECT ON pago                 TO rol_gerente;
GRANT SELECT ON resena               TO rol_gerente;
GRANT SELECT ON mv_ocupacion_mensual TO rol_gerente;
GRANT SELECT ON reserva_historico    TO rol_gerente;
GRANT EXECUTE ON pkg_reservas        TO rol_gerente;

-- AUDITOR: lectura de lo que se controla
GRANT SELECT ON auditoria_tarifa  TO rol_auditor;
GRANT SELECT ON tarifa            TO rol_auditor;
GRANT SELECT ON pago              TO rol_auditor;
GRANT SELECT ON reserva           TO rol_auditor;
GRANT SELECT ON usuario_sistema   TO rol_auditor;
GRANT SELECT ON reserva_historico TO rol_auditor;


-- ---------------------------------------------------------------------
-- 4. Verificacion: permisos que dio el dueno, por rol
-- ---------------------------------------------------------------------
SELECT grantee, table_name AS objeto, privilege
  FROM user_tab_privs_made
 WHERE grantee LIKE 'ROL\_%' ESCAPE '\'
 ORDER BY grantee, table_name, privilege;

SELECT grantee, table_name AS objeto, column_name, privilege
  FROM user_col_privs_made
 WHERE grantee LIKE 'ROL\_%' ESCAPE '\'
 ORDER BY grantee, table_name, column_name;

-- Ningun permiso de ROL_RECEPCION sobre tablas: todo lo que aparece
-- para ese rol debe ser una vista o el paquete.
SELECT DISTINCT p.table_name AS objeto, o.object_type
  FROM user_tab_privs_made p
  JOIN user_objects o ON o.object_name = p.table_name
                     AND o.object_type IN ('TABLE', 'VIEW', 'PACKAGE')
 WHERE p.grantee = 'ROL_RECEPCION'
 ORDER BY o.object_type, p.table_name;
-- Resultado: PACKAGE PKG_TRANSACCIONES y tres VIEW. Ninguna TABLE.
