

-- TEST 2

-- No necesitamos todos los datos de NEW_load.sql, solo insertaremos datos mínimos para probar el disparador. 
-- Si ya tienes datos cargados, puedes saltar esta parte o limpiar las tablas con:

DELETE FROM posts;
DELETE FROM loans;
DELETE FROM copies;
DELETE FROM users;
COMMIT;

-- hora, añadimos datos básicos para las pruebas.

-- Insertar un municipio (necesario para users y loans)
INSERT INTO municipalities (TOWN, PROVINCE, POPULATION)
VALUES ('Sotogris de San Guijuelo', 'Huelva', 1000);

-- Insertar un usuario particular (TYPE = 'P')
INSERT INTO users (USER_ID, ID_CARD, NAME, SURNAME1, BIRTHDATE, TOWN, PROVINCE, ADDRESS, PHONE, TYPE)
VALUES ('U0001', '12345678Z', 'Juan', 'Pérez', TO_DATE('1990-01-01', 'YYYY-MM-DD'), 'Sotogris de San Guijuelo ', 'Huelva', 'Calle Falsa 123', 600123456, 'P');

-- Insertar un usuario institucional (TYPE = 'L')
INSERT INTO users (USER_ID, ID_CARD, NAME, SURNAME1, BIRTHDATE, TOWN, PROVINCE, ADDRESS, PHONE, TYPE)
VALUES ('U0002', '87654321X', 'Biblioteca', 'Central', TO_DATE('2000-01-01', 'YYYY-MM-DD'), 'Sotogris de San Guijuelo ', 'Huelva', 'Avenida Principal 1', 600654321, 'L');

-- Insertar una copia de un libro
INSERT INTO copies (SIGNATURE, ISBN)
VALUES ('C0001','978-84-220-1887-2');

-- Insertar otra copia de un libro
INSERT INTO copies (SIGNATURE, ISBN)
VALUES ('C0002','978-84-220-1887-2');

-- Insertar un préstamo para U0001
INSERT INTO loans (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE, TIME)
VALUES ('C0001', 'U0001', TO_DATE('2024-11-11', 'YYYY-MM-DD'),'Sotogris de San Guijuelo', 'Huelva', 'L', 0);

-- Insertar un préstamo para U0002
INSERT INTO loans (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE, TIME)
VALUES ('C0001', 'U0002',  TO_DATE('2024-11-11', 'YYYY-MM-DD'),'Sotogris de San Guijuelo', 'Huelva', 'L', 0);

COMMIT;


-- Prueba 1: Usuario no institucional (P)
INSERT INTO posts (SIGNATURE, USER_ID, STOPDATE, POST_DATE, TEXT, LIKES, DISLIKES)
VALUES ('C0001', 'U0001', TO_DATE('2024-11-11', 'YYYY-MM-DD'), TO_DATE('2024-11-22', 'YYYY-MM-DD'), 'Post de prueba', 0, 0);

SELECT * FROM posts WHERE USER_ID = 'U0001';-- Se debería ver una fila

-- Prueba 2: Usuario institucional (L)
INSERT INTO posts (SIGNATURE, USER_ID, STOPDATE, POST_DATE, TEXT, LIKES, DISLIKES)
VALUES ('C0001', 'U0002', TO_DATE('2024-11-11', 'YYYY-MM-DD'), TO_DATE('2024-11-23', 'YYYY-MM-DD'), 'Post institucional', 0, 0);

SELECT * FROM posts WHERE USER_ID = 'U0002';-- No se debería ver ninguna fila

-- Prueba 3: Usuario inexistente
INSERT INTO posts (SIGNATURE, USER_ID, STOPDATE, POST_DATE, TEXT, LIKES, DISLIKES)
VALUES ('C0001', 'U9999', TO_DATE('2024-10-01', 'YYYY-MM-DD'), TO_DATE('2024-10-02', 'YYYY-MM-DD'), 'Post de usuario inexistente', 0, 0);

SELECT * FROM posts WHERE USER_ID = 'U9999';-- No se debería ver ninguna fila
