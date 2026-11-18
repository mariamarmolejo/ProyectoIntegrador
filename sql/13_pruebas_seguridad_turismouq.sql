-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- Entrega 3 - Pruebas de seguridad
-- 13_pruebas_seguridad_turismouq.sql
-- Equipo: Daniela Munoz, Maria Jose Marmolejo, Santiago Ovalle
--
-- Este script NO se corre completo de una vez. Cada seccion se ejecuta
-- conectado como un usuario distinto: en SQL Developer se crea una
-- conexion por usuario (servicio XEPDB1 o FREEPDB1) y se ejecuta cada
-- sentencia con Ctrl+Enter.
--
-- Los objetos se nombran con el dueno adelante (TURISMO_E2.reserva),
-- porque los otros usuarios no tienen sinonimos. Si el dueno se llama
-- distinto, se cambia aqui y SQL Developer lo reemplaza en todo el
-- script:
DEFINE dueno = TURISMO_E2
--
-- Nota sobre los errores de privilegios: desde Oracle 23ai, cuando el
-- usuario ve el objeto pero le falta el privilegio, el error es
-- ORA-41900 (missing UPDATE / DELETE privilege). En versiones
-- anteriores el mismo caso daba ORA-01031 (privilegios insuficientes).
-- =====================================================================

SET SERVEROUTPUT ON


-- =====================================================================
-- 1. RECEPCION1 (clave Recepcion2026)
-- =====================================================================

-- Intenta leer la tabla directamente
SELECT * FROM &dueno..reserva WHERE ROWNUM <= 5;
-- Resultado: ORA-00942: la tabla o vista no existe
-- Oracle no dice "no tiene permiso": para quien no tiene ningun
-- privilegio sobre el objeto, el objeto simplemente no existe.

-- Por la vista si puede
SELECT id_reserva, estado, fecha_checkin, cliente, alojamiento, habitacion
  FROM &dueno..v_recepcion_reservas
 WHERE fecha_checkin = DATE '2026-06-15';
-- Resultado: las reservas que llegan ese dia

SELECT id_cliente, nombre, correo, telefono
  FROM &dueno..v_recepcion_clientes
 WHERE id_cliente = 2026;
-- Resultado: 2026 | ... | cliente2026@correo.com | ...

-- Corrige el telefono de un cliente (permitido)
UPDATE &dueno..v_recepcion_clientes SET telefono = '3001234567' WHERE id_cliente = 2026;
-- 1 fila actualizada
ROLLBACK;

-- Intenta cambiarle el nombre (no permitido: solo correo y telefono)
UPDATE &dueno..v_recepcion_clientes SET nombre = 'Otro nombre' WHERE id_cliente = 2026;
-- Resultado: ORA-41900: missing UPDATE privilege (solo tiene UPDATE
-- sobre correo y telefono)

-- Intenta borrar un cliente
DELETE FROM &dueno..v_recepcion_clientes WHERE id_cliente = 2026;
-- Resultado: ORA-41900: missing DELETE privilege

-- Cotiza y reserva con el paquete de transacciones
DECLARE
    v_valor NUMBER;
    v_id    NUMBER;
    v_res   VARCHAR2(300);
BEGIN
    v_valor := &dueno..pkg_transacciones.fn_cotizar(20, DATE '2027-01-05', DATE '2027-01-08');
    DBMS_OUTPUT.PUT_LINE('Valor de la estadia: ' || v_valor);
    &dueno..pkg_transacciones.sp_reservar_con_pago(15, 20, DATE '2027-01-05', DATE '2027-01-08',
                                                    1, v_valor, 'Tarjeta debito', v_id, v_res);
END;
/
-- Resultado: Valor de la estadia: 498000
--            Reserva 25501 -> CONFIRMADA
-- Recepcion creo una reserva y un pago sin tener permiso sobre RESERVA
-- ni sobre PAGO: el procedimiento corre con los permisos de su dueno.

-- Perfil (SESSIONS_PER_USER 2): con la hoja de RECEPCION1 abierta (1
-- sesion), se abre una hoja no compartida con Ctrl+Shift+N (2
-- sesiones) y despues otra mas con Ctrl+Shift+N (3).
-- Resultado en la tercera: ORA-02391 (se excedio el limite simultaneo
-- de SESSIONS_PER_USER). Se cierran las hojas extra antes de seguir.


-- =====================================================================
-- 2. ENCARGADO1 (clave Encargado2026) - administrador del alojamiento 1
-- =====================================================================

SELECT COUNT(*) AS habitaciones, MIN(id_alojamiento), MAX(id_alojamiento)
  FROM &dueno..v_mis_habitaciones;
-- Resultado: 36 habitaciones, todas del alojamiento 1

SELECT COUNT(*) AS tarifas FROM &dueno..v_mis_tarifas;
-- Resultado: 792 (36 habitaciones x 22 temporadas)

-- La tabla completa no la puede ver
SELECT COUNT(*) FROM &dueno..tarifa;
-- Resultado: ORA-00942: la tabla o vista no existe

-- Sube el precio de una de sus tarifas
UPDATE &dueno..v_mis_tarifas
   SET precio_noche = precio_noche + 5000
 WHERE id_tarifa = (SELECT MIN(id_tarifa) FROM &dueno..v_mis_tarifas);
-- 1 fila actualizada
COMMIT;

-- Intenta cambiar la tarifa de una habitacion que no es suya (la 700
-- es de otro alojamiento)
UPDATE &dueno..v_mis_tarifas
   SET precio_noche = 1
 WHERE id_habitacion = 700;
-- Resultado: 0 filas actualizadas. Para el, esas tarifas no existen.

-- Intenta pasar una tarifa a otra habitacion
UPDATE &dueno..v_mis_tarifas
   SET id_habitacion = 700
 WHERE id_tarifa = (SELECT MIN(id_tarifa) FROM &dueno..v_mis_tarifas);
-- Resultado: ORA-41900: missing UPDATE privilege (solo puede cambiar
-- el precio)

SELECT id_reserva, estado, fecha_checkin, cliente
  FROM &dueno..v_mis_reservas
 WHERE fecha_checkin >= DATE '2026-06-01'
 ORDER BY fecha_checkin
 FETCH FIRST 5 ROWS ONLY;
-- Resultado: reservas del alojamiento 1

-- Deja el precio como estaba
UPDATE &dueno..v_mis_tarifas
   SET precio_noche = precio_noche - 5000
 WHERE id_tarifa = (SELECT MIN(id_tarifa) FROM &dueno..v_mis_tarifas);
COMMIT;


-- =====================================================================
-- 3. GERENTE1 (clave Gerente2026)
-- =====================================================================

SELECT id_alojamiento, nombre_comercial, TO_CHAR(mes, 'YYYY-MM') AS mes, pct_ocupacion
  FROM &dueno..mv_ocupacion_mensual
 WHERE mes = DATE '2026-06-01'
 ORDER BY pct_ocupacion DESC
 FETCH FIRST 5 ROWS ONLY;
-- Resultado: los 5 alojamientos con mas ocupacion en junio de 2026

BEGIN
    &dueno..pkg_reservas.sp_liquidacion_mensual(1, 2026, 6);
END;
/
-- Resultado: la liquidacion del alojamiento 1 (la misma de la Entrega 2)

DELETE FROM &dueno..reserva WHERE id_reserva = 1;
-- Resultado: ORA-41900: missing DELETE privilege (ve RESERVA pero no
-- puede modificarla)

SELECT * FROM &dueno..cliente WHERE ROWNUM <= 5;
-- Resultado: ORA-00942 (no ve datos personales de clientes)


-- =====================================================================
-- 4. AUDITOR1 (clave Auditor2026)
-- =====================================================================

SELECT id_auditoria, usuario_bd, fecha_cambio, precio_anterior, precio_nuevo, id_tarifa
  FROM &dueno..auditoria_tarifa
 ORDER BY id_auditoria DESC
 FETCH FIRST 5 ROWS ONLY;
-- Resultado: los dos cambios de ENCARGADO1 (+5000 y -5000), con
-- USUARIO_BD = ENCARGADO1. El disparador de la Entrega 2 registra quien
-- hizo el cambio aunque lo haya hecho a traves de una vista.

UPDATE &dueno..pago SET monto = 1 WHERE id_pago = 1;
-- Resultado: ORA-41900: missing UPDATE privilege

BEGIN
    &dueno..pkg_reservas.sp_liquidacion_mensual(1, 2026, 6);
END;
/
-- Resultado: PLS-00201: el identificador 'TURISMO_E2.PKG_RESERVAS' se
-- debe declarar (el auditor no ejecuta procesos)


-- =====================================================================
-- 5. De vuelta con el DUENO (TURISMO_E2): se borra la reserva de prueba
-- que hizo recepcion
-- =====================================================================
DELETE FROM pago
 WHERE id_reserva IN (SELECT id_reserva FROM reserva WHERE fecha_checkin >= DATE '2027-01-01');
DELETE FROM reserva_habitacion
 WHERE id_reserva IN (SELECT id_reserva FROM reserva WHERE fecha_checkin >= DATE '2027-01-01');
DELETE FROM reserva
 WHERE fecha_checkin >= DATE '2027-01-01';
COMMIT;
