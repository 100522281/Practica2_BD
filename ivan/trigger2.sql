


-- Trigger 2
-- Trigger para Evitar los "posts" de usuarios institucionales (bibliotecas municipales)

CREATE OR REPLACE TRIGGER prevent_institutional_posts
BEFORE INSERT ON posts
FOR EACH ROW
DECLARE
    v_user_type CHAR(1);
BEGIN
    -- Obtenemos el tipo de usuario asociado al USER_ID del nuevo post
    SELECT TYPE INTO v_user_type
    FROM users
    WHERE USER_ID = :NEW.USER_ID;
    
    -- Verificamos si el usuario es institucional (biblioteca municipal)
    -- 'L' es el tipo de usuario para bibliotecas municipales
    IF v_user_type = 'L' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Los usuarios institucionales (bibliotecas municipales) no pueden realizar publicaciones.');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- Si el USER_ID no existe en la tabla users, lanzar un error
        RAISE_APPLICATION_ERROR(-20002, 'El usuario especificado no existe en la base de datos.');
END;
/


-- TESTS 2

-- No necesitamos todos los datos de NEW_load.sql, solo insertaremos datos mínimos para probar el disparador. 

DELETE FROM posts;
DELETE FROM loans;
DELETE FROM copies;
DELETE FROM users;
COMMIT;

-- Añadimos datos básicos para las pruebas.

-- Insertamos un municipio (necesario para users y loans)
INSERT INTO municipalities (TOWN, PROVINCE, POPULATION)
VALUES ('Sotogris de San Guijuelo', 'Huelva', 1000);

-- Insertamos un usuario particular (TYPE = 'P')
INSERT INTO users (USER_ID, ID_CARD, NAME, SURNAME1, BIRTHDATE, TOWN, PROVINCE, ADDRESS, PHONE, TYPE)
VALUES ('U0001', '12345678Z', 'Juan', 'Pérez', TO_DATE('1990-01-01', 'YYYY-MM-DD'), 'Sotogris de San Guijuelo ', 'Huelva', 'Calle Falsa 123', 600123456, 'P');

-- Insertamos un usuario institucional (TYPE = 'L')
INSERT INTO users (USER_ID, ID_CARD, NAME, SURNAME1, BIRTHDATE, TOWN, PROVINCE, ADDRESS, PHONE, TYPE)
VALUES ('U0002', '87654321X', 'Biblioteca', 'Central', TO_DATE('2000-01-01', 'YYYY-MM-DD'), 'Sotogris de San Guijuelo ', 'Huelva', 'Avenida Principal 1', 600654321, 'L');

-- Insertamos una copia de un libro
INSERT INTO copies (SIGNATURE, ISBN)
VALUES ('C0001','978-84-220-1887-2');

-- Insertamos otra copia de un libro
INSERT INTO copies (SIGNATURE, ISBN)
VALUES ('C0002','978-84-220-1887-2');

-- Insertamos un préstamo para U0001
INSERT INTO loans (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE, TIME)
VALUES ('C0001', 'U0001', TO_DATE('2024-11-11', 'YYYY-MM-DD'),'Sotogris de San Guijuelo', 'Huelva', 'L', 0);

-- Insertamos un préstamo para U0002
INSERT INTO loans (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE, TIME)
VALUES ('C0001', 'U0002',  TO_DATE('2024-11-11', 'YYYY-MM-DD'),'Sotogris de San Guijuelo', 'Huelva', 'L', 0);

COMMIT;




-- Prueba 1: Usuario no institucional (P)
INSERT INTO posts (SIGNATURE, USER_ID, STOPDATE, POST_DATE, TEXT, LIKES, DISLIKES)
VALUES ('C0001', 'U0001', TO_DATE('2024-11-11', 'YYYY-MM-DD'), TO_DATE('2024-11-22', 'YYYY-MM-DD'), 'Post de prueba', 0, 0);
-- Verificamos resultado
SELECT * FROM posts WHERE USER_ID = 'U0001';
-- Resultado: Se debería ver una fila



-- Prueba 2: Usuario institucional (L)
INSERT INTO posts (SIGNATURE, USER_ID, STOPDATE, POST_DATE, TEXT, LIKES, DISLIKES)
VALUES ('C0001', 'U0002', TO_DATE('2024-11-11', 'YYYY-MM-DD'), TO_DATE('2024-11-23', 'YYYY-MM-DD'), 'Post institucional', 0, 0);
-- Verificamos resultado
SELECT * FROM posts WHERE USER_ID = 'U0002';
-- Resultado: No se debería ver ninguna fila



-- Prueba 3: Usuario inexistente
INSERT INTO posts (SIGNATURE, USER_ID, STOPDATE, POST_DATE, TEXT, LIKES, DISLIKES)
VALUES ('C0001', 'U9999', TO_DATE('2024-10-01', 'YYYY-MM-DD'), TO_DATE('2024-10-02', 'YYYY-MM-DD'), 'Post de usuario inexistente', 0, 0);
-- Verificamos resultado
SELECT * FROM posts WHERE USER_ID = 'U9999';
-- Resultado: No se debería ver ninguna fila
