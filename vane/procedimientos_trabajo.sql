CREATE OR REPLACE PACKAGE foundicu AS
	var_user_id CHAR(10);

	-- Procedimiento para insertar préstamo
    	PROCEDURE insertar_prestamo(p_signature IN copies.signature%TYPE);
	
	-- Procedimiento para insertar reserva
    	PROCEDURE insertar_reserva(p_isbn IN editions.isbn%TYPE, p_date IN DATE);
	
	-- Procedimiento para registrar devolución
    	PROCEDURE registrar_devolucion(p_signature IN loans.signature%TYPE);

	--Funcion y procedimiento para crear usuario
	FUNCTION usuario_actual RETURN CHAR;
	PROCEDURE crear_usuario(p_usuario IN CHAR);

END foundicu;
/

CREATE OR REPLACE PACKAGE BODY foundicu AS
------------------
--INSERTAR PRESTAMO
------------------
    PROCEDURE insertar_prestamo (p_signature copies.signature%TYPE) AS
        v_user_exists NUMBER;
        v_ban users.ban_up2%TYPE;
        v_town users.town%TYPE;
        v_province users.province%TYPE;
        v_loans_count NUMBER;
        v_reserva_exists NUMBER;
        v_copy_available NUMBER;
        v_copy_not_deregistered NUMBER;
        v_max_loans NUMBER := 2;
    BEGIN
        -- 1. Verificar que el usuario actual existe
        SELECT COUNT('x') INTO v_user_exists
        FROM users 
        WHERE user_id = foundicu.usuario_actual();

        IF v_user_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Error: el usuario actual no existe: ' || foundicu.usuario_actual());
        END IF;

        -- 2. Verificar si hay una reserva activa para este ejemplar
        SELECT COUNT('x')
        INTO v_reserva_exists
        FROM loans
        WHERE signature = p_signature
        AND user_id = foundicu.usuario_actual()
        AND type = 'R'
        AND stopdate = TRUNC(SYSDATE)
        AND return IS NULL;

        IF v_reserva_exists = 1 THEN
            -- Datos del usuario
            SELECT town, province
            INTO v_town, v_province
            FROM users
            WHERE user_id = foundicu.usuario_actual();

            -- Actualizamos la reserva a préstamo
            UPDATE loans
            SET type = 'L',
                town = v_town,
                province = v_province,
                stopdate = TRUNC(SYSDATE) + 14
            WHERE signature = p_signature
            AND user_id = foundicu.usuario_actual()
            AND type = 'R'
            AND stopdate = TRUNC(SYSDATE)
            AND return IS NULL;
        ELSE
            -- 4.1 Verificar copias disponibles
            SELECT COUNT('x')
            INTO v_copy_available
            FROM loans
            WHERE signature = p_signature
            AND type = 'L'
            AND return IS NULL
            AND (stopdate BETWEEN TRUNC(SYSDATE) AND TRUNC(SYSDATE) + 14
                 OR TRUNC(SYSDATE) BETWEEN stopdate - 14 AND stopdate);

            IF v_copy_available > 0 THEN
                RAISE_APPLICATION_ERROR(-20004, 'La copia no está disponible para préstamo en las próximas dos semanas.');
            END IF;

            -- 4.2 Verificar el límite de préstamos del usuario
            SELECT COUNT('x')
            INTO v_loans_count
            FROM loans
            WHERE user_id = foundicu.usuario_actual()
            AND (type = 'L' OR type = 'R')
            AND return IS NULL;

            IF v_loans_count >= v_max_loans THEN
                RAISE_APPLICATION_ERROR(-20005, 'El usuario ha alcanzado el límite de préstamos/reservas activos (' || v_max_loans || ').');
            END IF;

            -- 4.3 Verificar si el usuario está sancionado
            SELECT ban_up2 
            INTO v_ban
            FROM users
            WHERE user_id = foundicu.usuario_actual();

            IF v_ban IS NOT NULL AND v_ban >= TRUNC(SYSDATE) THEN
                RAISE_APPLICATION_ERROR(-20002, 'El usuario está sancionado y no puede realizar préstamos.');
            END IF;

            -- 4.4 Verificar si la copia está dada de baja (solo con deregistered)
            SELECT COUNT('x')
            INTO v_copy_not_deregistered
            FROM copies
            WHERE signature = p_signature
            AND deregistered IS NULL;

            IF v_copy_not_deregistered = 0 THEN
                RAISE_APPLICATION_ERROR(-20009, 'La copia está dada de baja (deregistered no es NULL).');
            END IF;

            -- 4.5 Insertar el préstamo
            SELECT town, province
            INTO v_town, v_province
            FROM users
            WHERE user_id = foundicu.usuario_actual();

            INSERT INTO loans (signature, user_id, stopdate, town, province, type, time, return)
            VALUES (p_signature, foundicu.usuario_actual(), TRUNC(SYSDATE) + 14, v_town, v_province, 'L', 0, NULL);
        END IF;

        -- Guardar los cambios
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Préstamo registrado exitosamente para el ejemplar: ' || p_signature);

    EXCEPTION
        WHEN OTHERS THEN 
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20006, 'Error al registrar el préstamo: ' || SQLERRM);
    END insertar_prestamo;

-----------------------
--INSERTAR RESERVA
-----------------------
    PROCEDURE insertar_reserva (p_isbn editions.isbn%TYPE, p_date DATE) AS
        v_user_id NUMBER; 
        v_ban users.ban_up2%TYPE;
        v_town users.town%TYPE;
        v_province users.province%TYPE;
        v_loans_count NUMBER;
        v_signature copies.signature%TYPE;
        v_copy_available NUMBER;
        v_max_loans NUMBER := 2;
    BEGIN
        -- Buscar un usuario
        SELECT COUNT('x'), ban_up2, town, province
        INTO v_user_id, v_ban, v_town, v_province
        FROM users
        WHERE user_id = foundicu.usuario_actual();

        -- 1. Verificar si el usuario existe
        IF v_user_id = 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Error: el usuario actual no existe.');
        END IF;

        -- 2. Verificar si tiene cupo para reservar
        -- 2.1 Verificar si el usuario está sancionado
        IF v_ban IS NOT NULL AND v_ban >= TRUNC(SYSDATE) THEN
            DBMS_OUTPUT.PUT_LINE('El usuario seleccionado está sancionado.');
        END IF;

        -- 2.2 Verificar el límite de préstamos/reservas del usuario
        SELECT COUNT('x')
        INTO v_loans_count
        FROM loans
        WHERE user_id = foundicu.usuario_actual()
        AND (type = 'L' OR type = 'R')
        AND return IS NULL;

        IF v_loans_count >= v_max_loans THEN
            DBMS_OUTPUT.PUT_LINE('El usuario ha alcanzado el límite de préstamos/reservas activos (' || v_max_loans || ').');
        END IF;

        -- 3. Verificar la disponibilidad de una copia para el ISBN
        SELECT COUNT('x')
        INTO v_copy_available
        FROM copies c
        WHERE c.isbn = p_isbn
        AND c.deregistered IS NULL -- Solo verificamos que no esté dada de baja
        AND NOT EXISTS (
            SELECT 1
            FROM loans l
            WHERE l.signature = c.signature
            AND (l.type = 'L' OR l.type = 'R')
            AND l.return IS NULL
            AND (l.stopdate BETWEEN p_date AND p_date + 14
                 OR p_date BETWEEN l.stopdate - 14 AND l.stopdate)
        );

        IF v_copy_available = 0 THEN
            DBMS_OUTPUT.PUT_LINE('No hay copias disponibles para el ISBN ' || p_isbn || ' en el período solicitado.');
        END IF;

        -- Seleccionar una copia disponible
        SELECT signature
        INTO v_signature
        FROM copies c
        WHERE c.isbn = p_isbn
        AND c.deregistered IS NULL -- Solo verificamos que no esté dada de baja
        AND NOT EXISTS (
            SELECT 1
            FROM loans l
            WHERE l.signature = c.signature
            AND (l.type = 'L' OR l.type = 'R')
            AND l.return IS NULL
            AND (l.stopdate BETWEEN p_date AND p_date + 14
                 OR p_date BETWEEN l.stopdate - 14 AND l.stopdate)
        )
        AND ROWNUM = 1;

        -- Insertar la reserva
        INSERT INTO loans (signature, user_id, stopdate, town, province, type, time, return)
        VALUES (v_signature, foundicu.usuario_actual(), p_date, v_town, v_province, 'R', 0, NULL);

        -- Confirmar la transacción
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Reserva registrada exitosamente para el ISBN: ' || p_isbn || ' en la fecha: ' || TO_CHAR(p_date, 'DD-MON-YYYY') || ' para el usuario: ' || foundicu.usuario_actual());

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
----------------------
--REGISTRAR DEVOLUCIONN
----------------------

	PROCEDURE registrar_devolucion (p_signature loans.signature%TYPE) AS
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
        	SELECT COUNT('x') 
        	INTO v_user_exists 
        	FROM users 
        	WHERE user_id = v_user_id;

        	IF v_user_exists != 1 THEN
            		RAISE_APPLICATION_ERROR(-20033, 'El usuario no existe.');
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
        	WHEN OTHERS THEN ROLLBACK;
            	DBMS_OUTPUT.PUT_LINE('Error al registrar la devolución: ' || SQLERRM);
            	RAISE;
    END registrar_devolucion;

--------------
--CREAR USUARIO 
--------------
	PROCEDURE crear_usuario(p_usuario IN CHAR) IS
	BEGIN
		var_user_id := p_usuario;
	END crear_usuario;
	FUNCTION usuario_actual RETURN CHAR IS
	BEGIN
		RETURN var_user_id;
	END usuario_actual;
END foundicu;
/


-- Prueba de la creación del usuario
BEGIN
    -- Establecer el usuario actual
    foundicu.crear_usuario('U000000001');
    -- Verificar el usuario actual
    DBMS_OUTPUT.PUT_LINE('Usuario actual: ' || foundicu.usuario_actual());
END;
/

-- Prueba inserción de préstamo

-- Limpiar datos en el orden correcto
DELETE FROM loans;
DELETE FROM services;
DELETE FROM assign_bus;
DELETE FROM assign_drv;
DELETE FROM stops;
DELETE FROM users;
DELETE FROM bibuses;
DELETE FROM drivers;
DELETE FROM routes;
DELETE FROM copies;
DELETE FROM editions;
DELETE FROM books;
DELETE FROM municipalities;
COMMIT;

-- Insertar datos necesarios
INSERT INTO municipalities (TOWN, PROVINCE, POPULATION)
VALUES ('Malaga', 'Andalucia', 57000);

INSERT INTO users (USER_ID, ID_CARD, NAME, SURNAME1, SURNAME2, BIRTHDATE, TOWN, PROVINCE, ADDRESS, EMAIL, PHONE, TYPE, BAN_UP2)
VALUES ('0488743850', 'ID123456789', 'Ana', 'Gomez', 'Lopez', TO_DATE('1990-05-15', 'YYYY-MM-DD'), 'Malaga', 'Andalucia', 'Calle Falsa 123', 'ana@ejemplo.com', 987654321, 'L', NULL);

INSERT INTO routes (ROUTE_ID)
VALUES ('R0001');

INSERT INTO stops (TOWN, PROVINCE, ADDRESS, ROUTE_ID, STOPTIME)
VALUES ('Malaga', 'Andalucia', 'Calle Falsa 123', 'R0001', 600);

INSERT INTO drivers (PASSPORT, EMAIL, FULLNAME, BIRTHDATE, PHONE, ADDRESS, CONT_START, CONT_END)
VALUES ('PASSPORT001', 'conductor@ejemplo.com', 'Juan Perez', TO_DATE('1980-01-01', 'YYYY-MM-DD'), 123456789, 'Calle Falsa 123', TO_DATE('2020-01-01', 'YYYY-MM-DD'), NULL);

INSERT INTO bibuses (PLATE, LAST_ITV, NEXT_ITV)
VALUES ('BUS00001', TO_DATE('2024-01-01', 'YYYY-MM-DD'), TO_DATE('2025-06-01', 'YYYY-MM-DD'));

INSERT INTO assign_drv (PASSPORT, TASKDATE, ROUTE_ID)
VALUES ('PASSPORT001', TRUNC(SYSDATE) + 14, 'R0001');

INSERT INTO assign_bus (PLATE, TASKDATE, ROUTE_ID)
VALUES ('BUS00001', TRUNC(SYSDATE) + 14, 'R0001');

INSERT INTO services (TOWN, PROVINCE, BUS, TASKDATE, PASSPORT)
VALUES ('Malaga', 'Andalucia', 'BUS00001', TRUNC(SYSDATE) + 14, 'PASSPORT001');

INSERT INTO books (TITLE, AUTHOR, COUNTRY, LANGUAGE, PUB_DATE, ALT_TITLE, TOPIC, CONTENT, AWARDS)
VALUES ('Libro de Prueba', 'Autor Prueba', 'España', 'Spanish', 2020, NULL, 'Prueba', 'Contenido de prueba', NULL);

INSERT INTO editions (ISBN, TITLE, AUTHOR, LANGUAGE, ALT_LANGUAGES, EDITION, PUBLISHER, EXTENSION, SERIES, COPYRIGHT, PUB_PLACE, DIMENSIONS, PHY_FEATURES, MATERIALS, NOTES, NATIONAL_LIB_ID, URL)
VALUES ('1234567890', 'Libro de Prueba', 'Autor Prueba', 'Spanish', 'English,French', '1st Edition', 'Editorial Prueba', '200 pages', NULL, '2020', 'Madrid', '20x15 cm', 'Paperback', NULL, 'Notas de prueba', 'NLIB123', NULL);

INSERT INTO copies (SIGNATURE, ISBN, CONDITION, COMMENTS, DEREGISTERED)
VALUES ('CH068', '1234567890', 'G', 'Buen estado', NULL);

COMMIT;

-- Probar el procedimiento
BEGIN
    foundicu.crear_usuario('0488743850');
    foundicu.insertar_prestamo('CH068');
END;
/

-- Verificar el resultado
SELECT signature, user_id, stopdate, town, province, type, return
FROM loans
WHERE signature = 'CH068';

-------------------
prueba negativa, demasiados prestamos activos 
-------------------
DELETE FROM loans;
DELETE FROM services;
DELETE FROM assign_bus;
DELETE FROM assign_drv;
DELETE FROM stops;
DELETE FROM users;
DELETE FROM bibuses;
DELETE FROM drivers;
DELETE FROM routes;
DELETE FROM copies;
DELETE FROM editions;
DELETE FROM books;
DELETE FROM municipalities;
COMMIT;

-- Insertar datos necesarios
INSERT INTO municipalities (TOWN, PROVINCE, POPULATION)
VALUES ('Malaga', 'Andalucia', 57000);

INSERT INTO users (USER_ID, ID_CARD, NAME, SURNAME1, SURNAME2, BIRTHDATE, TOWN, PROVINCE, ADDRESS, EMAIL, PHONE, TYPE, BAN_UP2)
VALUES ('0488743850', 'ID123456789', 'Ana', 'Gomez', 'Lopez', TO_DATE('1990-05-15', 'YYYY-MM-DD'), 'Malaga', 'Andalucia', 'Calle Falsa 123', 'ana@ejemplo.com', 987654321, 'L', NULL);

INSERT INTO routes (ROUTE_ID)
VALUES ('R0001');

INSERT INTO stops (TOWN, PROVINCE, ADDRESS, ROUTE_ID, STOPTIME)
VALUES ('Malaga', 'Andalucia', 'Calle Falsa 123', 'R0001', 600);

INSERT INTO drivers (PASSPORT, EMAIL, FULLNAME, BIRTHDATE, PHONE, ADDRESS, CONT_START, CONT_END)
VALUES ('PASSPORT001', 'conductor@ejemplo.com', 'Juan Perez', TO_DATE('1980-01-01', 'YYYY-MM-DD'), 123456789, 'Calle Falsa 123', TO_DATE('2020-01-01', 'YYYY-MM-DD'), NULL);

INSERT INTO bibuses (PLATE, LAST_ITV, NEXT_ITV)
VALUES ('BUS00001', TO_DATE('2024-01-01', 'YYYY-MM-DD'), TO_DATE('2025-06-01', 'YYYY-MM-DD'));

INSERT INTO assign_drv (PASSPORT, TASKDATE, ROUTE_ID)
VALUES ('PASSPORT001', TRUNC(SYSDATE) + 14, 'R0001');

INSERT INTO assign_bus (PLATE, TASKDATE, ROUTE_ID)
VALUES ('BUS00001', TRUNC(SYSDATE) + 14, 'R0001');

INSERT INTO services (TOWN, PROVINCE, BUS, TASKDATE, PASSPORT)
VALUES ('Malaga', 'Andalucia', 'BUS00001', TRUNC(SYSDATE) + 14, 'PASSPORT001');

INSERT INTO books (TITLE, AUTHOR, COUNTRY, LANGUAGE, PUB_DATE, ALT_TITLE, TOPIC, CONTENT, AWARDS)
VALUES ('Libro de Prueba', 'Autor Prueba', 'España', 'Spanish', 2020, NULL, 'Prueba', 'Contenido de prueba', NULL);

INSERT INTO editions (ISBN, TITLE, AUTHOR, LANGUAGE, ALT_LANGUAGES, EDITION, PUBLISHER, EXTENSION, SERIES, COPYRIGHT, PUB_PLACE, DIMENSIONS, PHY_FEATURES, MATERIALS, NOTES, NATIONAL_LIB_ID, URL)
VALUES ('1234567890', 'Libro de Prueba', 'Autor Prueba', 'Spanish', 'English,French', '1st Edition', 'Editorial Prueba', '200 pages', NULL, '2020', 'Madrid', '20x15 cm', 'Paperback', NULL, 'Notas de prueba', 'NLIB123', NULL);

INSERT INTO copies (SIGNATURE, ISBN, CONDITION, COMMENTS, DEREGISTERED)
VALUES ('CH068', '1234567890', 'G', 'Buen estado', NULL);
INSERT INTO copies (SIGNATURE, ISBN, CONDITION, COMMENTS, DEREGISTERED)
VALUES ('CH069', '1234567890', 'G', 'Buen estado', NULL);
INSERT INTO copies (SIGNATURE, ISBN, CONDITION, COMMENTS, DEREGISTERED)
VALUES ('CH070', '1234567890', 'G', 'Buen estado', NULL);


COMMIT;

-- Primer préstamo activo
INSERT INTO loans (signature, user_id, stopdate, town, province, type, time, return)
VALUES ('CH069', '0488743850', TRUNC(SYSDATE) + 14, 'Malaga', 'Andalucia', 'L', 0, NULL);

-- Segundo préstamo activo
INSERT INTO loans (signature, user_id, stopdate, town, province, type, time, return)
VALUES ('CH070', '0488743850', TRUNC(SYSDATE) + 14, 'Malaga', 'Andalucia', 'L', 0, NULL);

COMMIT;

BEGIN
    -- Establecer el usuario actual
    foundicu.crear_usuario('0488743850');
    -- Intentar insertar un nuevo préstamo
    foundicu.insertar_prestamo('CH068');
END;
/