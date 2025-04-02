WITH language_dividido AS (
    SELECT 
        e.TITLE, e.AUTHOR, e.ISBN,
        SUBSTR(e.LANGUAGE, 1, 3) AS lang1, -- Primer idioma (3 primeros caracteres de LANGUAGE)
        CASE 
            WHEN LENGTH(e.ALT_LANGUAGES) >= 3 THEN SUBSTR(e.ALT_LANGUAGES, 1, 3) 
            ELSE NULL
        END AS lang2, -- Segundo idioma
        CASE 
            WHEN LENGTH(e.ALT_LANGUAGES) >= 6 THEN SUBSTR(e.ALT_LANGUAGES, 4, 3) 
            ELSE NULL
        END AS lang3, -- Tercer idioma
        CASE 
            WHEN LENGTH(e.ALT_LANGUAGES) >= 9 THEN SUBSTR(e.ALT_LANGUAGES, 7, 3) 
            ELSE NULL
        END AS lang4 -- Cuarto idioma
    FROM Editions e
),
languages_por_edicion AS (
    SELECT TITLE, AUTHOR, ISBN, lang1 AS language FROM language_dividido WHERE lang1 IS NOT NULL
    UNION SELECT TITLE, AUTHOR, ISBN, lang2 FROM language_dividido WHERE lang2 IS NOT NULL
    UNION SELECT TITLE, AUTHOR, ISBN, lang3 FROM language_dividido WHERE lang3 IS NOT NULL
    UNION SELECT TITLE, AUTHOR, ISBN, lang4 FROM language_dividido WHERE lang4 IS NOT NULL -- metemos en una única columna todos los idiomas 
),
languages_contador AS (
    SELECT TITLE, AUTHOR, 
        COUNT(DISTINCT language) AS language_count
    FROM languages_por_edicion GROUP BY TITLE, AUTHOR 
    HAVING COUNT(DISTINCT language) >= 3 -- Solo libros con al menos 3 idiomas
),
libros_no_prestados AS (
    -- Identificar libros cuyas copias nunca han sido prestadas
    SELECT e.TITLE, e.AUTHOR FROM Editions e
    LEFT JOIN Copies c ON e.ISBN = c.ISBN
    LEFT JOIN Loans l ON c.SIGNATURE = l.SIGNATURE
    GROUP BY e.TITLE, e.AUTHOR HAVING COUNT(l.SIGNATURE) = 0 -- Libros sin préstamos
)
-- Seleccionar libros con al menos 3 idiomas y sin préstamos
SELECT lc.TITLE, lc.AUTHOR, lc.language_count FROM languages_contador lc
JOIN libros_no_prestados lnp ON lc.TITLE = lnp.TITLE AND lc.AUTHOR = lnp.AUTHOR 
ORDER BY lc.TITLE, lc.AUTHOR;


-- prueba positiva 
INSERT INTO BOOKS (TITLE, AUTHOR)
VALUES ('LibroPrueba1', 'AutorPrueba1');

INSERT INTO Editions (ISBN, TITLE, AUTHOR, LANGUAGE, ALT_LANGUAGES, NATIONAL_LIB_ID)
VALUES ('001-01-000001-0-1', 'LibroPrueba1', 'AutorPrueba1',
        'spa', 'engfreger', 'a0000001');

INSERT INTO Copies (Signature, ISBN)
VALUES ('PR002','001-01-000001-0-1');

COMMIT;

-- prueba negativa (libro prestado)
-- 1. Insertar un municipio en municipalities (ajustando población)
INSERT INTO municipalities (TOWN, PROVINCE, POPULATION)
VALUES ('Malaga', 'Andalucia', 57000);

-- 2. Insertar una ruta en routes
INSERT INTO routes (ROUTE_ID)
VALUES ('R0001');

-- 3. Insertar una parada en stops
INSERT INTO stops (TOWN, PROVINCE, ADDRESS, ROUTE_ID, STOPTIME)
VALUES ('Malaga', 'Andalucia', 'Calle Falsa 123', 'R0001', 600);

-- 4. Insertar un conductor en drivers
INSERT INTO drivers (PASSPORT, EMAIL, FULLNAME, BIRTHDATE, PHONE, ADDRESS, CONT_START, CONT_END)
VALUES ('PASSPORT001', 'conductor@ejemplo.com', 'Juan Perez', TO_DATE('1980-01-01', 'YYYY-MM-DD'), 123456789, 'Calle Falsa 123', TO_DATE('2020-01-01', 'YYYY-MM-DD'), NULL);

-- 5. Insertar un autobús en bibuses
INSERT INTO bibuses (PLATE, LAST_ITV, NEXT_ITV)
VALUES ('BUS00001', TO_DATE('2024-01-01', 'YYYY-MM-DD'), TO_DATE('2025-06-01', 'YYYY-MM-DD'));

-- 6. Asignar el conductor a la ruta en assign_drv
INSERT INTO assign_drv (PASSPORT, TASKDATE, ROUTE_ID)
VALUES ('PASSPORT001', TO_DATE('2025-03-31', 'YYYY-MM-DD'), 'R0001');

-- 7. Asignar el autobús a la ruta en assign_bus
INSERT INTO assign_bus (PLATE, TASKDATE, ROUTE_ID)
VALUES ('BUS00001', TO_DATE('2025-03-31', 'YYYY-MM-DD'), 'R0001');

-- 8. Insertar el servicio en services (agregando ROUTE_ID si es necesario)
INSERT INTO services (TOWN, PROVINCE, BUS, TASKDATE, PASSPORT)
VALUES ('Malaga', 'Andalucia', 'BUS00001', TO_DATE('2025-03-31', 'YYYY-MM-DD'), 'PASSPORT001');

-- 9. Insertar un libro en books
INSERT INTO books (TITLE, AUTHOR, COUNTRY, LANGUAGE, PUB_DATE, ALT_TITLE, TOPIC, CONTENT, AWARDS)
VALUES ('Libro de Prueba', 'Autor Prueba', 'España', 'Spanish', 2020, NULL, 'Prueba', 'Contenido de prueba', NULL);

-- 10. Insertar una edición en editions
INSERT INTO editions (ISBN, TITLE, AUTHOR, LANGUAGE, ALT_LANGUAGES, EDITION, PUBLISHER, EXTENSION, SERIES, COPYRIGHT, PUB_PLACE, DIMENSIONS, PHY_FEATURES, MATERIALS, NOTES, NATIONAL_LIB_ID, URL)
VALUES ('1234567890', 'Libro de Prueba', 'Autor Prueba', 'Spanish', 'English,French', '1st Edition', 'Editorial Prueba', '200 pages', NULL, '2020', 'Madrid', '20x15 cm', 'Paperback', NULL, 'Notas de prueba', 'NLIB123', NULL);

-- 11. Insertar una copia en copies
INSERT INTO copies (SIGNATURE, ISBN, CONDITION, COMMENTS, DEREGISTERED)
VALUES ('CP001', '1234567890', 'G', 'Buen estado', NULL);

-- 12. Insertar un usuario en users
INSERT INTO users (USER_ID, ID_CARD, NAME, SURNAME1, SURNAME2, BIRTHDATE, TOWN, PROVINCE, ADDRESS, EMAIL, PHONE, TYPE, BAN_UP2)
VALUES ('U000000001', 'ID123456789', 'Ana', 'Gomez', 'Lopez', TO_DATE('1990-05-15', 'YYYY-MM-DD'), 'Malaga', 'Andalucia', 'Calle Falsa 123', 'ana@ejemplo.com', 987654321, 'L', NULL);

-- 13. Insertar el préstamo en loans
INSERT INTO loans (SIGNATURE, USER_ID, STOPDATE, TOWN, PROVINCE, TYPE, TIME, RETURN)
VALUES ('CP001', 'U000000001', TO_DATE('2025-03-31', 'YYYY-MM-DD'), 'Malaga', 'Andalucia', 'L', 60, NULL);

-- Commit para guardar los cambios
COMMIT;
--pruea negativa (número de idiomas incorrecto)
INSERT INTO BOOKS (TITLE, AUTHOR)
VALUES ('LibroPrueba1', 'AutorPrueba1');

INSERT INTO Editions (ISBN, TITLE, AUTHOR, LANGUAGE, ALT_LANGUAGES, NATIONAL_LIB_ID)
VALUES ('001-01-000001-0-1', 'LibroPrueba1', 'AutorPrueba1',
        'spa', 'eng', 'a0000001');

INSERT INTO Copies (Signature, ISBN)
VALUES ('PR002','001-01-000001-0-1');

COMMIT;
