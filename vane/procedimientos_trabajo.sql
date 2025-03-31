CREATE OR REPLACE PACKAGE foundicu AS
    -- Procedimiento para insertar préstamo
    PROCEDURE insertar_prestamo(
        p_signature IN CHAR,
    );

    -- Procedimiento para insertar reserva
    PROCEDURE insertar_reserva(
        p_isbn IN VARCHAR2,
        p_fecha IN DATE,
    );

    -- Procedimiento para registrar devolución
    PROCEDURE registrar_devolucion(
        p_signature IN CHAR,
    );

END foundicu;
/

CREATE OR REPLACE PACKAGE BODY foundicu AS

    ---------------------
    INSERTAR PRESTAMO
    ---------------------

    CREATE OR REPLACE PROCEDURE insertar_prestamo (p_signature copies.signature%TYPE) AS
        v_user_id users.user_id%TYPE; -- CHAR(10)
        v_ban users.ban_up2%TYPE;
        v_town users.town%TYPE;
        v_province users.province%TYPE;
        v_loans_count NUMBER; -- Para contar préstamos activos
        v_reserva_exists NUMBER; -- Para verificar si hay una reserva
        v_copy_available NUMBER; -- Para verificar si la copia está disponible
        v_copy_condition NUMBER; -- Para verificar el estado de la copia
        v_max_loans NUMBER := 2; -- Límite fijo de préstamos
    BEGIN
        -- 1. Verificar si hay una reserva activa para este ejemplar y obtener el user_id
        SELECT COUNT(*), MAX(user_id)
        INTO v_reserva_exists, v_user_id
        FROM loans
        WHERE signature = p_signature
        AND type = 'R' -- Reserva
        AND stopdate = TRUNC(SYSDATE) -- Fecha de hoy
        AND return IS NULL; -- Reserva activa

        IF v_reserva_exists > 1 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Error: múltiples reservas activas para el ejemplar en la fecha actual.');
        END IF;

        -- 2. Si no hay reserva, verificar disponibilidad de la copia para un préstamo directo
        IF v_reserva_exists = 0 THEN
            SELECT COUNT(*)
            INTO v_copy_available
            FROM loans
            WHERE signature = p_signature
            AND type = 'L' -- Préstamo
            AND return IS NULL -- Préstamo activo
            AND (stopdate BETWEEN TRUNC(SYSDATE) AND TRUNC(SYSDATE) + 14
                OR TRUNC(SYSDATE) BETWEEN stopdate - 14 AND stopdate); -- Solapamiento

            IF v_copy_available > 0 THEN
                RAISE_APPLICATION_ERROR(-20004, 'La copia no está disponible para préstamo en las próximas dos semanas.');
            END IF;
        END IF;

        -- 3. Si hay reserva, obtener información del usuario; si no, necesitamos user_id de otro modo
        IF v_reserva_exists = 1 THEN
            BEGIN
                SELECT ban_up2, town, province
                INTO v_ban, v_town, v_province
                FROM users
                WHERE user_id = v_user_id;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20001, 'El usuario asociado a la reserva (ID ' || v_user_id || ') no existe.');
            END;
        ELSE
            -- Si no hay reserva, necesitamos una forma alternativa de obtener el user_id
            -- En este caso, podrías lanzar una excepción o asumir un user_id por defecto (por ejemplo, un administrador)
            RAISE_APPLICATION_ERROR(-20003, 'No hay una reserva activa para este ejemplar con fecha de hoy. Proporcione un user_id para un préstamo directo.');
        END IF;

        -- 4. Verificar si el usuario está sancionado
        IF v_ban IS NOT NULL AND v_ban >= TRUNC(SYSDATE) THEN
            RAISE_APPLICATION_ERROR(-20002, 'El usuario está sancionado y no puede realizar préstamos.');
        END IF;

        -- 5. Verificar el estado de la copia (no dada de baja y en buen estado)
        SELECT COUNT(*)
        INTO v_copy_condition
        FROM copies
        WHERE signature = p_signature
        AND deregistered IS NULL
        AND condition NOT IN ('W', 'V', 'D'); -- Excluir copias desgastadas, muy desgastadas o dañadas

        IF v_copy_condition = 0 THEN
            RAISE_APPLICATION_ERROR(-20009, 'La copia está dada de baja o en mal estado.');
        END IF;

        -- 6. Verificar el límite de préstamos del usuario (incluyendo reservas)
        SELECT COUNT(*)
        INTO v_loans_count
        FROM loans
        WHERE user_id = v_user_id
        AND (type = 'L' OR type = 'R') -- Contar préstamos y reservas activos
        AND return IS NULL;

        IF v_loans_count >= v_max_loans THEN
            RAISE_APPLICATION_ERROR(-20005, 'El usuario ha alcanzado el límite de préstamos/reservas activos (' || v_max_loans || ').');
        END IF;

        -- 7. Marcar la reserva como usada si existe
        IF v_reserva_exists > 0 THEN
            UPDATE loans
            SET return = TRUNC(SYSDATE)
            WHERE signature = p_signature
            AND user_id = v_user_id
            AND type = 'R'
            AND stopdate = TRUNC(SYSDATE)
            AND return IS NULL;

            IF SQL%ROWCOUNT = 0 THEN
                RAISE_APPLICATION_ERROR(-20007, 'No se pudo actualizar la reserva.');
            END IF;
        END IF;

        -- 8. Insertar el préstamo
        INSERT INTO loans (signature, user_id, stopdate, town, province, type, time, return)
        VALUES (p_signature, v_user_id, TRUNC(SYSDATE) + 14, v_town, v_province, 'L', 0, NULL);

        -- 9. Confirmar la transacción
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Préstamo registrado exitosamente para el ejemplar: ' || p_signature);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20006, 'Error al registrar el préstamo: ' || SQLERRM);
    END insertar_prestamo;
    /

    -----------------------
    INSERTAR RESERVA
    -----------------------

    CREATE OR REPLACE PROCEDURE insertar_reserva (p_isbn editions.isbn%TYPE, p_date DATE) AS
        v_user_id users.user_id%TYPE; -- CHAR(10)
        v_ban users.ban_up2%TYPE;
        v_town users.town%TYPE;
        v_province users.province%TYPE;
        v_loans_count NUMBER; -- Para contar préstamos/reservas activos
        v_signature copies.signature%TYPE; -- Para almacenar la copia disponible
        v_copy_available NUMBER; -- Para verificar disponibilidad de copias
        v_max_loans NUMBER := 2; -- Límite fijo de reservas
    BEGIN
        -- Buscar un usuario con sitio disponible
        SELECT user_id, ban_up2, town, province
        INTO v_user_id, v_ban, v_town, v_province
        FROM users u
        WHERE NOT EXISTS (
            SELECT 1
            FROM loans l
            WHERE l.user_id = u.user_id
            AND (l.type = 'L' OR l.type = 'R')
            AND l.return IS NULL
            HAVING COUNT(*) >= v_max_loans
        )
        AND (v_ban IS NULL OR v_ban < TRUNC(SYSDATE))
        AND ROWNUM = 1; -- Seleccionar el primer usuario que cumpla

        -- Verificar si el usuario está sancionado (doble chequeo por seguridad)
        IF v_ban IS NOT NULL AND v_ban >= TRUNC(SYSDATE) THEN
            DBMS_OUTPUT.PUT_LINE('El usuario seleccionado está sancionado.');
        END IF;

        -- Verificar el límite de préstamos/reservas del usuario (confirmación)
        SELECT COUNT(*)
        INTO v_loans_count
        FROM loans
        WHERE user_id = v_user_id
        AND (type = 'L' OR type = 'R')
        AND return IS NULL;

        IF v_loans_count >= v_max_loans THEN
            DBMS_OUTPUT.PUT_LINE('El usuario ha alcanzado el límite de préstamos/reservas activos (' || v_max_loans || ').');
        END IF;

        -- 4. Verificar la disponibilidad de una copia para el ISBN
        SELECT COUNT(*)
        INTO v_copy_available
        FROM copies c
        WHERE c.isbn = p_isbn
        AND c.deregistered IS NULL
        AND c.condition NOT IN ('W', 'V', 'D') -- Copia en buen estado
        AND NOT EXISTS (
            SELECT 1
            FROM loans l
            WHERE l.signature = c.signature
                AND (l.type = 'L' OR l.type = 'R')
                AND l.return IS NULL
                AND (l.stopdate BETWEEN p_date AND p_date + 14
                    OR p_date BETWEEN l.stopdate - 14 AND l.stopdate) -- Solapamiento
        );

        IF v_copy_available = 0 THEN
            DBMS_OUTPUT.PUT_LINE('No hay copias disponibles para el ISBN ' || p_isbn || ' en el período solicitado.');
        END IF;

        -- Seleccionar una copia disponible
        SELECT signature
        INTO v_signature
        FROM copies c
        WHERE c.isbn = p_isbn
        AND c.deregistered IS NULL
        AND c.condition NOT IN ('W', 'V', 'D')
        AND NOT EXISTS (
            SELECT 1
            FROM loans l
            WHERE l.signature = c.signature
                AND (l.type = 'L' OR l.type = 'R')
                AND l.return IS NULL
                AND (l.stopdate BETWEEN p_date AND p_date + 14
                    OR p_date BETWEEN l.stopdate - 14 AND l.stopdate)
        )
        AND ROWNUM = 1; -- Tomar la primera copia disponible

        -- Insertar la reserva
        INSERT INTO loans (signature, user_id, stopdate, town, province, type, time, return)
        VALUES (v_signature, v_user_id, p_date, v_town, v_province, 'R', 0, NULL);

        -- Confirmar la transacción
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Reserva registrada exitosamente para el ISBN: ' || p_isbn || ' en la fecha: ' || TO_CHAR(p_date, 'DD-MON-YYYY') || ' para el usuario: ' || v_user_id);

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('No se encontró un usuario con sitio disponible o no hay copias disponibles para el ISBN ' || p_isbn || '.');
        WHEN TOO_MANY_ROWS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error: múltiples usuarios o copias coincidentes.');
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error al registrar la reserva: ' || SQLERRM);
    END insertar_reserva;
    /

    ------------------------
    REGISTRAR DEVOLUCIONN
    ------------------------
    CREATE OR REPLACE PROCEDURE registrar_devolucion (p_signature loans.signature%TYPE) AS
        v_user_id users.user_id%TYPE;
        v_user_exists NUMBER; -- Para verificar la existencia del usuario
    BEGIN
        -- 1. Buscar el usuario asociado al préstamo activo
        BEGIN
            SELECT user_id 
            INTO v_user_id 
            FROM loans 
            WHERE signature = p_signature 
            AND return IS NULL;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('No hay préstamos activos para esta copia.');
                RETURN;
        END;

        -- Validar si el usuario existe
        SELECT COUNT(*) 
        INTO v_user_exists 
        FROM users 
        WHERE user_id = v_user_id;

        IF v_user_exists != 1 THEN
            DBMS_OUTPUT.PUT_LINE('El usuario no existe.');
            RETURN;
        END IF;

        -- Registrar la devolución
        UPDATE loans
        SET return = SYSDATE
        WHERE signature = p_signature
            AND user_id = v_user_id
            AND return IS NULL;

        -- Confirmar la transacción
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Devolución registrada exitosamente.');

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error al registrar la devolución: ' || SQLERRM);
            RAISE;
    END registrar_devolucion;

END foundicu;
/
