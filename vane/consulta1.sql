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

-- prueba negativa


--pruea negativa

