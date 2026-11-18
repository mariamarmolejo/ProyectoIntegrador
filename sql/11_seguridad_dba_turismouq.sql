-- =====================================================================
-- PROYECTO INTEGRADOR - TurismoUQ - Bases de Datos II - 2026-2
-- Entrega 3 - Seguridad (parte del administrador)
-- 11_seguridad_dba_turismouq.sql
-- Equipo: Daniela Munoz, Maria Jose Marmolejo, Santiago Ovalle
--
-- SE CORRE COMO SYSTEM, conectado a la PDB (XEPDB1 o FREEPDB1), con F5.
-- Crear usuarios, roles y perfiles son privilegios de sistema que el
-- dueno de las tablas no tiene (ni debe tener). Los permisos sobre las
-- tablas y las vistas los da el dueno en el script 12.
--
-- Contenido:
--   1. Limpieza (si el script ya se habia corrido)
--   2. Perfil PERFIL_TURISMO con limites de sesion
--   3. Cuatro roles: recepcion, administrador de alojamiento, gerente
--      y auditor
--   4. Un usuario de prueba por rol, con el perfil
--
-- Usuarios (la clave es solo para la practica):
--   RECEPCION1  / Recepcion2026  -> ROL_RECEPCION
--   ENCARGADO1  / Encargado2026  -> ROL_ADMIN_ALOJAMIENTO
--                                   (es el encargado del alojamiento 1:
--                                   en USUARIO_SISTEMA existe
--                                   'encargado1' con id_alojamiento 1)
--   GERENTE1    / Gerente2026    -> ROL_GERENTE
--   AUDITOR1    / Auditor2026    -> ROL_AUDITOR
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Limpieza
-- ---------------------------------------------------------------------
BEGIN
    FOR u IN (SELECT username FROM dba_users
               WHERE username IN ('RECEPCION1', 'ENCARGADO1', 'GERENTE1', 'AUDITOR1')) LOOP
        EXECUTE IMMEDIATE 'DROP USER ' || u.username || ' CASCADE';
    END LOOP;
--
    FOR r IN (SELECT role FROM dba_roles
               WHERE role IN ('ROL_RECEPCION', 'ROL_ADMIN_ALOJAMIENTO',
                              'ROL_GERENTE', 'ROL_AUDITOR')) LOOP
        EXECUTE IMMEDIATE 'DROP ROLE ' || r.role;
    END LOOP;
--
    FOR p IN (SELECT DISTINCT profile FROM dba_profiles
               WHERE profile = 'PERFIL_TURISMO') LOOP
        EXECUTE IMMEDIATE 'DROP PROFILE ' || p.profile || ' CASCADE';
    END LOOP;
END;
/


-- ---------------------------------------------------------------------
-- 2. Perfil con limites de sesion
--   SESSIONS_PER_USER 2     maximo 2 sesiones abiertas a la vez por
--                           usuario (un recepcionista no deberia tener
--                           la cuenta abierta en 5 computadores)
--   IDLE_TIME 15            minutos sin actividad antes de cerrar la
--                           sesion (puesto de recepcion desatendido)
--   CONNECT_TIME 600        minutos maximos de una sesion (un turno)
--   FAILED_LOGIN_ATTEMPTS 3 intentos fallidos antes de bloquear la cuenta
--   PASSWORD_LOCK_TIME 1/24 la cuenta queda bloqueada 1 hora
--   PASSWORD_LIFE_TIME 90   la clave vence a los 90 dias
--   PASSWORD_GRACE_TIME 7   dias para cambiarla despues de vencida
-- ---------------------------------------------------------------------
CREATE PROFILE perfil_turismo LIMIT
    SESSIONS_PER_USER      2
    IDLE_TIME              15
    CONNECT_TIME           600
    FAILED_LOGIN_ATTEMPTS  3
    PASSWORD_LOCK_TIME     1/24
    PASSWORD_LIFE_TIME     90
    PASSWORD_GRACE_TIME    7;

-- Los limites de sesion solo se aplican si RESOURCE_LIMIT esta en TRUE
-- (es el valor por defecto desde Oracle 12c).
SELECT name, value FROM v$parameter WHERE name = 'resource_limit';
-- Resultado: resource_limit | TRUE


-- ---------------------------------------------------------------------
-- 3. Roles
-- Aqui solo se crean y se les da CREATE SESSION. Que puede ver y hacer
-- cada uno lo define el dueno del esquema en el script 12.
-- ---------------------------------------------------------------------
CREATE ROLE rol_recepcion;
CREATE ROLE rol_admin_alojamiento;
CREATE ROLE rol_gerente;
CREATE ROLE rol_auditor;

GRANT CREATE SESSION TO rol_recepcion;
GRANT CREATE SESSION TO rol_admin_alojamiento;
GRANT CREATE SESSION TO rol_gerente;
GRANT CREATE SESSION TO rol_auditor;


-- ---------------------------------------------------------------------
-- 4. Usuarios
-- Ninguno tiene cuota en tablespaces: no pueden crear tablas propias.
-- ---------------------------------------------------------------------
CREATE USER recepcion1 IDENTIFIED BY Recepcion2026 PROFILE perfil_turismo;
CREATE USER encargado1 IDENTIFIED BY Encargado2026 PROFILE perfil_turismo;
CREATE USER gerente1   IDENTIFIED BY Gerente2026   PROFILE perfil_turismo;
CREATE USER auditor1   IDENTIFIED BY Auditor2026   PROFILE perfil_turismo;

GRANT rol_recepcion         TO recepcion1;
GRANT rol_admin_alojamiento TO encargado1;
GRANT rol_gerente           TO gerente1;
GRANT rol_auditor           TO auditor1;


-- ---------------------------------------------------------------------
-- Verificacion
-- ---------------------------------------------------------------------
SELECT username, profile, account_status
  FROM dba_users
 WHERE username IN ('RECEPCION1', 'ENCARGADO1', 'GERENTE1', 'AUDITOR1')
 ORDER BY username;
-- Resultado: los 4 usuarios con PERFIL_TURISMO y OPEN

SELECT grantee, granted_role
  FROM dba_role_privs
 WHERE grantee IN ('RECEPCION1', 'ENCARGADO1', 'GERENTE1', 'AUDITOR1')
 ORDER BY grantee;
-- Resultado: un rol por usuario

SELECT resource_name, limit
  FROM dba_profiles
 WHERE profile = 'PERFIL_TURISMO'
   AND limit <> 'DEFAULT'
 ORDER BY resource_name;
-- Resultado: los 7 limites definidos arriba
