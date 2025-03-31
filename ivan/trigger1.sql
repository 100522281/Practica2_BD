


-- Trigger 
-- Trigger para Añadir una columna "número de lecturas" (lecturas) a la tabla ‘Libros’. Cuando
-- se presta un libro, se actualizará el número de lecturas
CREATE OR REPLACE TRIGGER update_lecturas
AFTER INSERT ON LOANS
FOR EACH ROW
DECLARE 
    v_title  VARCHAR2(255); 
    v_author VARCHAR2(255); 
BEGIN
    -- Obtener el título y autor del libro prestado desde la tabla COPIES
    BEGIN
        SELECT e.TITLE, e.AUTHOR
        INTO v_title, v_author
        FROM COPIES c
        JOIN EDITIONS e ON c.ISBN = e.ISBN
        WHERE c.SIGNATURE = :NEW.SIGNATURE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN; -- Salir si no se encuentra la copia o la edición
    END;

    -- Incrementar el número de lecturas en la tabla BOOKS
    UPDATE BOOKS
    SET LECTURAS = NVL(LECTURAS, 0) + 1
    WHERE TITLE = v_title
      AND AUTHOR = v_author;
END;
/


-- TESTS 3


-- Añadir columna LECTURAS a la tabla BOOKS
ALTER TABLE BOOKS ADD (LECTURAS NUMBER DEFAULT 0);


-- Hecho por Grok

-- Limpiar datos previos para las pruebas
DELETE FROM LOANS;
DELETE FROM COPIES;
DELETE FROM EDITIONS;
DELETE FROM BOOKS;
DELETE FROM USERS;
DELETE FROM MUNICIPALITIES;
DELETE FROM SERVICES;
COMMIT;



-- Insertar datos básicos para las pruebas
-- Municipio y servicio (necesario para LOANS)
INSERT INTO MUNICIPALITIES (TOWN, PROVINCE, POPULATION)
VALUES ('Sotogris de San Guijuelo', 'Huelva', 1000);

INSERT INTO SERVICES (TOWN, PROVINCE, BUS, TASKDATE, PASSPORT)
VALUES ('Sotogris de San Guijuelo', 'Huelva', 'BUS001', TO_DATE('2025-03-31', 'YYYY-MM-DD'), 'PASSPORT1');

-- Libro
INSERT INTO BOOKS (TITLE, AUTHOR, COUNTRY, LANGUAGE, PUB_DATE)
VALUES ('El Quijote', 'Miguel de Cervantes', 'España', 'Spanish', 1605);

-- Edición
INSERT INTO EDITIONS (ISBN, TITLE, AUTHOR, LANGUAGE, NATIONAL_LIB_ID)
VALUES ('978-84-220-1887-2', 'El Quijote', 'Miguel de Cervantes', 'Spanish', 'NATLIB001');

-- Copias
INSERT INTO COPIES (SIGNATURE, ISBN, CONDITION)
VALUES ('C0001', '978-84-220-1887-2', 'G');

INSERT INTO COPIES (SIGNATURE, ISBN, CONDITION)
VALUES ('C0002', '978-84-220-1887-2', 'G');

-- Usuario
INSERT INTO USERS (USER_ID, ID_CARD, NAME, SURNAME1, BIRTHDATE, TOWN, PROVINCE, ADDRESS, PHONE, TYPE)
VALUES ('U0001', '12345678Z', 'Ana', 'García', TO_DATE('1990-01-01', 'YYYY-MM-DD'), 'Madrid', 'Madrid', 'Calle Falsa 123', 600123456, 'P');

COMMIT;

-- Verificar estado inicial de LECTURAS
SELECT TITLE, AUTHOR, LECTURAS FROM BOOKS WHERE TITLE = 'El Quijote' AND AUTHOR = 'Miguel de Cervantes';
-- Resultado esperado: LECTURAS = 0



-- Prueba 1: Insertar un préstamo con copia válida
INSERT INTO LOANS (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE, TIME)
VALUES ('C0001', 'U0001', TO_DATE('2025-03-31', 'YYYY-MM-DD'), 'Madrid', 'Madrid', 'L', 0);
-- Verificar resultado
SELECT TITLE, AUTHOR, LECTURAS FROM BOOKS WHERE TITLE = 'El Quijote' AND AUTHOR = 'Miguel de Cervantes';
-- Resultado esperado: LECTURAS = 1



-- Prueba 2: Insertar un préstamo con copia inexistente
INSERT INTO LOANS (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE, TIME)
VALUES ('C9999', 'U0001', TO_DATE('2025-03-31', 'YYYY-MM-DD'), 'Madrid', 'Madrid', 'L', 0);
-- Verificar resultado
SELECT TITLE, AUTHOR, LECTURAS FROM BOOKS WHERE TITLE = 'El Quijote' AND AUTHOR = 'Miguel de Cervantes';
-- Resultado esperado: LECTURAS = 1 (sin cambios)



-- Prueba 3: Insertar otro préstamo del mismo libro (misma edición, otra copia)
INSERT INTO LOANS (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE, TIME)
VALUES ('C0002', 'U0001', TO_DATE('2025-03-31', 'YYYY-MM-DD'), 'Madrid', 'Madrid', 'L', 0);
-- Verificar resultado
SELECT TITLE, AUTHOR, LECTURAS FROM BOOKS WHERE TITLE = 'El Quijote' AND AUTHOR = 'Miguel de Cervantes';
-- Resultado esperado: LECTURAS = 2

COMMIT;






-- Hecho por Deepseek

-- Preparar datos de prueba
-- Limpiar registros previos
DELETE FROM posts;
DELETE FROM loans;
DELETE FROM copies;
DELETE FROM editions;
DELETE FROM books;
DELETE FROM users;
COMMIT;

-- Insertar un municipio (requerido para users y loans)
INSERT INTO municipalities (TOWN, PROVINCE, POPULATION)
VALUES ('Madrid', 'Huelva', 3200000);

-- Insertar un usuario
INSERT INTO users (USER_ID, ID_CARD, NAME, SURNAME1, BIRTHDATE, TOWN, PROVINCE, ADDRESS, PHONE, TYPE)
VALUES ('U001', '12345678A', 'Ana', 'García', TO_DATE('1995-05-15', 'YYYY-MM-DD'), 'Madrid', 'Huelva', 'Calle Mayor 5', 600112233, 'P');

-- Insertar un libro en BOOKS
INSERT INTO books (TITLE, AUTHOR, COUNTRY, LANGUAGE, PUB_DATE)
VALUES ('Cien años de soledad', 'Gabriel García Márquez', 'Colombia', 'Español', 1967);

-- Insertar una edición en EDITIONS
INSERT INTO editions (ISBN, TITLE, AUTHOR, NATIONAL_LIB_ID)
VALUES ('978-1234-5678', 'Cien años de soledad', 'Gabriel García Márquez', 'LIB-001');

-- Insertar una copia en COPIES
INSERT INTO copies (SIGNATURE, ISBN, CONDITION)
VALUES ('C001', '978-1234-5678', 'G');

COMMIT;

-- Verificar estado inicial de LECTURAS
SELECT TITLE, AUTHOR, LECTURAS FROM BOOKS WHERE TITLE = 'Cien años de soledad';
-- Resultado esperado: LECTURAS = 0

---------------------------------------
-- Prueba 1: Caso normal
---------------------------------------
-- Insertar un préstamo válido
INSERT INTO loans (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE)
VALUES ('C001', 'U001', SYSDATE, 'Madrid', 'Huelva', 'L');

COMMIT;

-- Verificar LECTURAS después del préstamo
SELECT TITLE, AUTHOR, LECTURAS FROM BOOKS WHERE TITLE = 'Cien años de soledad';
-- Resultado esperado: LECTURAS = 1

---------------------------------------
-- Prueba 2: Copia inexistente
---------------------------------------
-- Intentar préstamo con SIGNATURE no registrada
INSERT INTO loans (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE)
VALUES ('C999', 'U001', SYSDATE, 'Madrid', 'Huelva', 'L');
-- Error esperado: ORA-02291 (violación de FK), pero el trigger NO debe actualizar LECTURAS

-- Verificar LECTURAS (debe seguir siendo 1)
SELECT TITLE, AUTHOR, LECTURAS FROM BOOKS;
-- Resultado esperado: LECTURAS = 1

---------------------------------------
-- Prueba 3: Múltiples préstamos
---------------------------------------
-- Insertar otro préstamo con la misma copia
INSERT INTO loans (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE)
VALUES ('C001', 'U001', SYSDATE + 1, 'Madrid', 'Huelva', 'L');

COMMIT;

-- Verificar LECTURAS
SELECT TITLE, AUTHOR, LECTURAS FROM BOOKS;
-- Resultado esperado: LECTURAS = 2

---------------------------------------
-- Prueba 4: Excepción (edición no encontrada)
---------------------------------------
-- Eliminar la edición asociada a la copia (simular error)
DELETE FROM editions WHERE ISBN = '978-1234-5678';
COMMIT;

-- Insertar préstamo (debería fallar silenciosamente)
INSERT INTO loans (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE)
VALUES ('C001', 'U001', SYSDATE + 2, 'Madrid', 'Huelva', 'L');

-- Verificar LECTURAS (no debe cambiar)
SELECT TITLE, AUTHOR, LECTURAS FROM BOOKS;
-- Resultado esperado: LECTURAS = 2 (no se actualiza porque no se encontró la edición)